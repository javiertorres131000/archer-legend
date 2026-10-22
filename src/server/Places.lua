--!strict
-- Places (ModuleScript)
-- Ubicación: ServerScriptService > Server > Places
-- Qué rol cumple este servidor (Config.Places explica cómo se arma la experiencia):
--   "Lobby"   la Ciudadela: grupos, invitaciones, cola rápida (PartyService). Si se puede
--             teletransportar, los grupos viajan a una arena privada; si no (Studio, o sin
--             ArenaPlaceId), juegan en este mismo servidor.
--   "Arena"   el place de la arena publicado: recibe al grupo, juega y lo devuelve al lobby.
--   "Classic" solo para las pruebas automáticas: el lobby de antes (todo el servidor es un
--             equipo y MatchManager maneja los listos). Lo prende tests/mocks.luau con el
--             atributo TestClassicLobby de workspace (en el juego real no existe).
-- El rol se publica en el atributo PlaceRole de GameState para los clientes.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Role = "Lobby" | "Arena" | "Classic"

local Places = {}

local cached: Role? = nil

function Places.role(): Role
	if cached then
		return cached
	end
	local role: Role
	if workspace:GetAttribute("TestClassicLobby") == true then
		role = "Classic"
	elseif not RunService:IsStudio() and Config.Places.ArenaPlaceId ~= 0 and game.PlaceId == Config.Places.ArenaPlaceId then
		role = "Arena"
	else
		role = "Lobby"
	end
	cached = role
	return role
end

-- ¿Este servidor puede mandar grupos a otro place? (en Studio Roblox no teletransporta)
function Places.canTeleport(): boolean
	return not RunService:IsStudio() and Config.Places.ArenaPlaceId ~= 0
end

-- Para pruebas: forzar un rol
function Places._setRole(role: Role?)
	cached = role
end

return Places
