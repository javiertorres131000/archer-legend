--!strict
-- Teleporter (ModuleScript)
-- Ubicación: ServerScriptService > Server > Teleporter
-- Viajes entre la Ciudadela y la Arena (TeleportService). Solo el servidor teletransporta.
--   · toArena(jugadores, capítulo): reserva un servidor privado de la arena y manda al grupo
--     junto, con los datos del viaje (capítulo y quiénes son). Reintenta si falla.
--   · toLobby(jugadores): de vuelta a la Ciudadela (servidor público, el grupo junto).
--   · joinData(jugador): los datos con los que llegó (en la arena: capítulo y grupo).
-- Mientras viaja, el jugador tiene el atributo Traveling = "Arena" o "Lobby" (el cliente
-- muestra la pantalla de viaje, TravelScreen). Si el viaje falla del todo, vuelve a nil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Cfg = Config.Places

local Teleporter = {}

export type TravelData = { chapter: string, members: { number }, origin: string?, version: number }

local service: TeleportService? = nil
local function teleportService(): TeleportService
	if not service then
		service = game:GetService("TeleportService") :: TeleportService
		-- Si un viaje no arranca, se avisa (el reintento lo hace quien llamó)
		pcall(function()
			(service :: TeleportService).TeleportInitFailed:Connect(function(player: Player, result, message)
				warn(string.format("[Teleporter] No se pudo teletransportar a %s: %s %s", player.Name, tostring(result), tostring(message)))
				player:SetAttribute("Traveling", nil)
			end)
		end)
	end
	return service :: TeleportService
end

-- Para pruebas: reemplazar el teletransporte real. f(placeId, jugadores, datos, reservado) -> ok, error
local fake: ((number, { Player }, any, boolean) -> (boolean, string?))? = nil
function Teleporter._setFake(f: ((number, { Player }, any, boolean) -> (boolean, string?))?)
	fake = f
end

local function send(placeId: number, players: { Player }, data: any, reserved: boolean): (boolean, string?)
	if fake then
		return fake(placeId, players, data, reserved)
	end
	local ts = teleportService()
	local lastErr: string? = nil
	for attempt = 1, Cfg.TeleportRetries do
		local ok, err = pcall(function()
			local options = Instance.new("TeleportOptions")
			if reserved then
				options.ReservedServerAccessCode = ts:ReserveServer(placeId)
			end
			if data then
				options:SetTeleportData(data)
			end
			ts:TeleportAsync(placeId, players, options)
		end)
		if ok then
			return true, nil
		end
		lastErr = tostring(err)
		warn("[Teleporter] Intento " .. attempt .. " falló:", lastErr)
		task.wait(1.5 * attempt)
		-- solo los que siguen en el servidor
		local still = {}
		for _, p in players do
			if p.Parent == Players then
				table.insert(still, p)
			end
		end
		players = still
		if #players == 0 then
			return true, nil
		end
	end
	return false, lastErr
end

local function mark(players: { Player }, where: string?)
	for _, p in players do
		p:SetAttribute("Traveling", where)
	end
end

-- Manda al grupo a una arena privada. Devuelve si arrancó el viaje.
function Teleporter.toArena(players: { Player }, chapterId: string): (boolean, string?)
	local members = {}
	for _, p in players do
		table.insert(members, p.UserId)
	end
	local data: TravelData = { chapter = chapterId, members = members, origin = game.JobId, version = 1 }
	mark(players, "Arena")
	local ok, err = send(Cfg.ArenaPlaceId, players, data, true)
	if not ok then
		mark(players, nil)
	end
	return ok, err
end

-- De vuelta a la Ciudadela, todos juntos.
function Teleporter.toLobby(players: { Player }): (boolean, string?)
	mark(players, "Lobby")
	local ok, err = send(Cfg.LobbyPlaceId, players, { returning = true, version = 1 }, false)
	if not ok then
		mark(players, nil)
	end
	return ok, err
end

-- Datos con los que llegó el jugador (nil si no viene de un viaje nuestro)
function Teleporter.joinData(player: Player): TravelData?
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(join) ~= "table" then
		return nil
	end
	local data = (join :: any).TeleportData
	if type(data) ~= "table" or type(data.chapter) ~= "string" or type(data.members) ~= "table" then
		return nil
	end
	return data :: TravelData
end

return Teleporter
