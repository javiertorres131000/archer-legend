-- GameServer (Script)
-- Ubicación: ServerScriptService > Server > GameServer
-- Punto de entrada del servidor. Solo conecta las piezas:
--   Lobby        zona segura donde se aparece y se prepara la partida
--   Run          una partida en la arena (reutiliza todo el motor de combate)
--   MatchManager ciclo LOBBY → PREPARING → STARTING → PLAYING → RESULTS → RETURNING
--   PlayerData / PlayerLife   estado y ciclo de vida de cada jugador

local RunService = game:GetService("RunService")

local Lobby = require(script.Parent.Lobby)
local Run = require(script.Parent.Run)
local MatchManager = require(script.Parent.MatchManager)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)

Run.init() -- arena y motor de combate (borra el Baseplate y el spawn de la plantilla)
Lobby.build() -- después de la arena: el único SpawnLocation del juego es el del lobby
PlayerLife.init()
MatchManager.init()

PlayerData.init(function(player)
	PlayerLife.onPlayerAdded(player) -- aparece en el lobby
	MatchManager.onPlayerAdded(player)
end, function(player)
	MatchManager.onPlayerRemoving(player)
	PlayerLife.onPlayerRemoving(player)
end)

RunService.Heartbeat:Connect(function(dt)
	MatchManager.update(dt)
end)
