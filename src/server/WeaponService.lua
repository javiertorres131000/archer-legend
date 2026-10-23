--!strict
-- WeaponService (ModuleScript)
-- Ubicación: ServerScriptService > Server > WeaponService
-- Arma del jugador (catálogo en Shared/Weapons.lua). Se guarda en el perfil (Data.Weapon) y se
-- aplica al empezar cada partida (stats.weapon). La publica en el atributo "Weapon" del jugador.
--
-- El cliente pide ("Select", Id) por Remotes.WeaponRequest. El servidor valida: perfil cargado,
-- en el lobby (no listo ni en partida), frecuencia, Id existente y, si es un arma especial, que
-- tengas su premio de la caja de armas (Data.Crates.Owned[def.Prize]).
--
-- Armas especiales: en la partida juegan como su arma Base (stats.weapon = "Sword", así salen
-- las habilidades de espada) y stats.weaponId guarda la especial (sus números y sus efectos).
-- Atributos del Player:
--   Weapon          Id del arma elegida
--   OwnedWeapons    especiales que tenés, separadas por coma (para el menú "Arma")
--   EquippedWeapon  la especial elegida, o "" (para el Index de las cajas)

local Players = game:GetService("Players")
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Weapons"))
local CrateItems = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CrateItems"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)

local WeaponService = {}

local lastRequest: { [Player]: number } = {}

-- ¿Puede usar esta arma? (las comunes siempre; las especiales si tiene el premio)
function WeaponService.owns(data: any, def: any): boolean
	if not def then
		return false
	end
	if not def.Prize or Config.Debug.UnlockAllWeapons then
		return true
	end
	return data ~= nil and ((data.Crates.Owned[def.Prize] :: number?) or 0) > 0
end

-- Arma que de verdad usa: si la guardada es una especial que ya no tiene, su base
local function current(data: any): any
	local def = Weapons.get(if data then data.Weapon else nil)
	if not WeaponService.owns(data, def) then
		def = Weapons.get(def.Base or Weapons.Default)
	end
	return def
end

function WeaponService.publish(player: Player)
	local data = Profiles.get(player)
	local def = current(data)
	if data and data.Weapon ~= def.Id then
		data.Weapon = def.Id
	end
	player:SetAttribute("Weapon", def.Id)
	player:SetAttribute("EquippedWeapon", if def.Prize then def.Id else "")
	local owned = {}
	for _, w in Weapons.List do
		if w.Prize and WeaponService.owns(data, w) then
			table.insert(owned, w.Id)
		end
	end
	player:SetAttribute("OwnedWeapons", table.concat(owned, ","))
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
	if not WeaponService.owns(data, def) then
		local prize = CrateItems.ById[def.Prize]
		if prize and prize.Kind ~= "Weapon" then
			return false, "Todavía no tenés esa arma: viene con el skin " .. prize.Name .. "."
		end
		return false, "Todavía no tenés esa arma: sale en la Caja de Armas."
	end
	data.Weapon = def.Id
	WeaponService.publish(player)
	Profiles.saveSoon(player)
	return true, def.Name .. " equipada"
end

-- Al empezar la partida
function WeaponService.apply(player: Player, stats: any)
	local def = current(Profiles.get(player))
	stats.weapon = def.Base or def.Id
	stats.weaponId = def.Id
end

function WeaponService.init(remotes: any)
	Profiles.onLoaded(function(player)
		WeaponService.publish(player)
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
