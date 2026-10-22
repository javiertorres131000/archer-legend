-- Mecánicas del mapa (MapEvents): las grietas de lava del Bosque dañan a jugadores y enemigos.
-- (Los árboles que caen se prueban en Studio: necesitan modelos y física de verdad.)
local M = require("./mocks")
local Config = require("./Config")
Config.Crates.TestGold = 0
Config.Camera.Mode = "TopDown"
local Lava = Config.MapEvents.forest.LavaVents
Lava.Offset = { 0, 0 } -- la grieta sale justo debajo del jugador
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local MatchManager = require("./MatchManager")
local MapEvents = require("./MapEvents")
local Enemies = require("./Enemies")

local RunService = M.game:GetService("RunService")
local MatchCfg = Config.Match

require("./GameServer")

local passed, failed = 0, 0
local function test(name, f)
	local ok, err = pcall(f)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FALLÓ " .. name .. "\n         " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end
local function tick(seconds)
	local dt = 1 / 30
	for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
		M.advance(dt)
		RunService.Heartbeat:Fire(dt)
	end
end

print("Mecánicas del mapa")

local A = M.addPlayer("Ana")
tick(3)
Remotes.LobbyRequest.OnServerEvent:Fire(A, "SetReady", true)
tick(MatchCfg.CountdownTime + 1.5)

test("el Bosque activa sus mecánicas", function()
	eq(MatchManager.getState(), "PLAYING", "partida")
	eq(Remotes.GameState:GetAttribute("MapEvents"), "forest", "tema con eventos")
end)

test("grieta de lava: aviso, erupción y daño a jugador y enemigo", function()
	local targets = PlayerData.getAliveTargets()
	eq(#targets, 1, "Ana en pie")
	local root = targets[1].root
	-- un enemigo justo al lado de Ana
	local enemy
	local waited = 0
	while not enemy and waited < 20 do
		tick(0.5)
		waited += 0.5
		for _, e in Enemies.list do
			if e.alive and not e.isBoss then enemy = e break end
		end
	end
	assert(enemy, "debería haber algún enemigo")
	local hpBefore = enemy.health
	local playerBefore = targets[1].humanoid.Health
	MapEvents._forceVents(targets)
	local vents = MapEvents._pending()
	eq(vents, Lava.Count, "grietas avisadas")
	-- quietos los dos en el centro de la grieta hasta que erupciona
	local t = 0
	while t < Lava.Warn + 0.2 do
		enemy.part.Position = root.Position
		tick(1 / 30)
		t += 1 / 30
	end
	eq((MapEvents._pending()), 0, "ya erupcionaron")
	assert(not enemy.alive or enemy.health < hpBefore, "el enemigo recibió daño")
	assert(targets[1].humanoid.Health < playerBefore, "Ana recibió daño")
end)

test("en el descanso no aparecen eventos nuevos", function()
	MapEvents.update(1 / 30, PlayerData.getAliveTargets(), "Break")
	MapEvents.update(30, PlayerData.getAliveTargets(), "Break")
	eq((MapEvents._pending()), 0, "sin grietas")
end)

print(string.format("%d ok, %d fallaron", passed, failed))
if failed > 0 then
	error("fallaron pruebas de mecánicas del mapa")
end
