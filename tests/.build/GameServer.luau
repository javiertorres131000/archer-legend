local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- GameServer (Script)
-- Ubicación: ServerScriptService > Server > GameServer
-- Punto de entrada del servidor. Solo conecta las piezas:
--   Lobby        zona segura donde se aparece y se prepara la partida
--   Run          una partida en la arena (reutiliza todo el motor de combate)
--   MatchManager ciclo LOBBY → PREPARING → STARTING → PLAYING → RESULTS → RETURNING
--   PlayerData / PlayerLife   estado y ciclo de vida de cada jugador

local RunService = game:GetService("RunService")

local Lobby = require("./Lobby")
local Run = require("./Run")
local MatchManager = require("./MatchManager")
local PlayerData = require("./PlayerData")
local PlayerLife = require("./PlayerLife")

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

return {}
