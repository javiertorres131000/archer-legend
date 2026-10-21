--!strict
-- WeaponService (ModuleScript)
-- Ubicación: ServerScriptService > Server > WeaponService
-- Arma del jugador (catálogo en Shared/Weapons.lua). Se guarda en el perfil (Data.Weapon) y se
-- aplica al empezar cada partida (stats.weapon). La publica en el atributo "Weapon" del jugador.
--
-- El cliente pide ("Select", Id) por Remotes.WeaponRequest. El servidor valida: perfil cargado,
-- en el lobby (no listo ni en partida), frecuencia e Id existente.

local Players = game:GetService("Players")
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Weapons"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)

local WeaponService = {}

local lastRequest: { [Player]: number } = {}

local function publish(player: Player)
	local data = Profiles.get(player)
	player:SetAttribute("Weapon", if data then data.Weapon else Weapons.Default)
end

-- Cambia el arma. Devuelve (ok, mensaje).
function WeaponService.select(player: Player, id: any): (boolean, string)
	local data = Profiles.get(player)
	if not data then
		return false, "El perfil sigue cargando."
	end
	local state = PlayerData.get(player)
	if not state or state.inMatch or player:GetAttribute("Ready") == true then
		return false, "Cancelá LISTO para cambiar de arma."
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.25 then
		return false, "Esperá un momento."
	end
	lastRequest[player] = now
	local def = if type(id) == "string" then Weapons.ById[id] else nil
	if not def then
		return false, "Arma inválida."
	end
	data.Weapon = def.Id
	publish(player)
	Profiles.saveSoon(player)
	return true, def.Name .. " equipada"
end

-- Al empezar la partida
function WeaponService.apply(player: Player, stats: any)
	local data = Profiles.get(player)
	stats.weapon = if data then Weapons.get(data.Weapon).Id else Weapons.Default
end

function WeaponService.init(remotes: any)
	Profiles.onLoaded(function(player)
		publish(player)
	end)
	remotes.WeaponRequest.OnServerEvent:Connect(function(player: Player, action: any, id: any)
		if action == "Select" then
			local ok, message = WeaponService.select(player, id)
			remotes.LobbyNotice:FireClient(player, (if ok then "✔ " else "") .. message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return WeaponService
