-- Runes (ModuleScript)
-- Ubicación: ServerScriptService > Server > Runes
-- Runas permanentes del perfil (definiciones en Shared > RuneDefs):
--   · Se consiguen como botín de jefes (RuneDefs.BossDropChance), una garantizada al ganar un
--     capítulo por primera vez, y abriendo el cofre de runas con gemas desde la pantalla de Runas.
--   · Repetidas: suben de nivel la de colección; si ya está al máximo (o es especial) dan piedras.
--   · Las especiales se ponen en los espacios activos que tengas abiertos.
-- El cliente pide por RuneRequest y recibe el estado por RuneState. Todo se valida acá.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Defs = require(Shared:WaitForChild("RuneDefs"))
local Config = require(Shared:WaitForChild("Config"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)

local Runes = {}
local remotes
local lastRequest: { [Player]: number } = {}

-- Espacios activos abiertos según los capítulos ganados
function Runes.slots(player: Player): number
	local data = Profiles.get(player)
	if not data then
		return 1
	end
	return Defs.unlockedSlots(function(chapterId)
		local rec = data.Chapters[chapterId]
		return rec ~= nil and rec.Clears > 0
	end)
end

-- Manda el estado al jugador. justGot: Id de la runa recién conseguida (la pantalla la resalta).
function Runes.publish(player: Player, message: string?, justGot: string?)
	local data = Profiles.get(player)
	if not data or not remotes then
		return
	end
	remotes.RuneState:FireClient(player, data.Runes.Owned, data.Runes.Active, Runes.slots(player), message, justGot)
end

-- Da una runa. Devuelve "New" | "LevelUp" | "Duplicate" (o nil si no se pudo).
function Runes.grant(player: Player, id: string, source: string?): string?
	local data = Profiles.get(player)
	local def = Defs.ById[id]
	if not data or not def then
		return nil
	end
	local owned = data.Runes.Owned
	local level = owned[id]
	local result, label
	if not level then
		owned[id] = 1
		result, label = "New", "Runa nueva"
	elseif def.Kind == "Collection" and level < Defs.MaxLevel then
		owned[id] = level + 1
		result, label = "LevelUp", string.format("Runa Nv. %d", level + 1)
	else
		Profiles.addCurrency(player, "Stones", Defs.DuplicateStones)
		result, label = "Duplicate", string.format("Repetida: +%d piedras", Defs.DuplicateStones)
	end
	if remotes then
		remotes.RewardNotice:FireClient(player, def.Name, def.Rarity, if source then source .. " · " .. label else label)
	end
	Runes.publish(player, nil, id)
	Profiles.saveSoon(player)
	return result
end

function Runes.grantRandom(player: Player, specialChance: number, source: string?): string?
	return Runes.grant(player, Defs.roll(specialChance), source)
end

-- Un jefe o mini-jefe murió: cada participante tiene su chance de runa
function Runes.onBossKilled(players: { Player })
	for _, p in players do
		if math.random() < Defs.BossDropChance then
			Runes.grantRandom(p, Defs.ChestSpecialChance, "Botín de jefe")
		end
	end
end

-- Primera victoria en un capítulo: runa garantizada (y puede abrir un espacio activo nuevo)
function Runes.onFirstClear(player: Player)
	Runes.grantRandom(player, Defs.ChestSpecialChance, "Primera victoria")
end

-- Al empezar la partida, sobre las stats nuevas
function Runes.apply(player: Player, stats: PlayerData.Stats)
	local data = Profiles.get(player)
	if data then
		Defs.apply(stats, data.Runes.Owned, data.Runes.Active, Runes.slots(player))
	end
end

function Runes.request(player: Player, action: any, arg: any, arg2: any): (boolean, string?)
	local data = Profiles.get(player)
	if not data then
		return false, "El perfil sigue cargando."
	end
	if action == "Get" then
		Runes.publish(player)
		return true
	end
	local state = PlayerData.get(player)
	if not state or state.inMatch or player:GetAttribute("Ready") or player:GetAttribute("InMatch") then
		return false, "Cancelá LISTO y volvé al lobby para cambiar tus runas."
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.25 then
		return false, "Esperá un momento."
	end
	lastRequest[player] = now

	local active = data.Runes.Active
	if action == "Equip" then
		local slot, id = arg, arg2
		local def = type(id) == "string" and Defs.ById[id]
		if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Runes.slots(player) then
			return false, "Ese espacio todavía está bloqueado."
		end
		if not def or def.Kind ~= "Special" or not data.Runes.Owned[id] then
			return false, "No tenés esa runa especial."
		end
		-- Si ya estaba en otro espacio, se mueve
		for i = 1, Defs.ActiveSlots do
			if active[i] == id then
				active[i] = ""
			end
		end
		active[slot] = id
	elseif action == "Unequip" then
		if type(arg) ~= "number" or arg % 1 ~= 0 or arg < 1 or arg > Defs.ActiveSlots then
			return false, "Petición de runas inválida."
		end
		active[arg] = ""
	elseif action == "OpenChest" then
		-- Sin yields entre el cobro y la entrega
		if not Profiles.addCurrency(player, "Gems", -Defs.ChestCost) then
			return false, string.format("Necesitás %d gemas para abrir el cofre.", Defs.ChestCost)
		end
		Runes.grantRandom(player, Defs.ChestSpecialChance, "Cofre de runas")
		return true
	else
		return false, "Petición de runas inválida."
	end
	Runes.publish(player, "Runas actualizadas")
	Profiles.saveSoon(player)
	return true
end

function Runes.init(r)
	remotes = r
	Profiles.onLoaded(function(player, data)
		-- Pruebas en Studio: gemas para abrir cofres de runas (Config.Debug.TestGems)
		local testGems = Config.Debug.TestGems or 0
		if testGems > 0 and RunService:IsStudio() and data.Currencies.Gems < testGems then
			Profiles.addCurrency(player, "Gems", testGems - data.Currencies.Gems)
		end
		Runes.publish(player)
	end)
	r.RuneRequest.OnServerEvent:Connect(function(player, action, arg, arg2)
		if type(action) ~= "string" then
			return
		end
		local ok, message = Runes.request(player, action, arg, arg2)
		if not ok then
			Runes.publish(player, message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Runes
