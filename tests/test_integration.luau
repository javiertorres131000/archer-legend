-- Partida completa sin pantalla: carga el GameServer real y lo hace avanzar frame a frame
-- con dos jugadores "bot" que se quedan quietos (disparan solos) y se acercan a los enemigos
-- lejanos. Comprueba que el juego avanza de oleada en oleada sin errores de Luau.
local M = require("./mocks")
local Config = require("./Config")
-- Estos bots no giran hacia los enemigos: prueban el flujo, no la puntería
Config.Camera.Mode = "TopDown"
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Arena = require("./Arena")

local V = M.Vector3
local RunService = M.game:GetService("RunService")
local gameState = Remotes.GameState

-- Los bots eligen siempre la primera habilidad apenas se la ofrecen
local pendingChoices = {}
Remotes.SkillOffer.FireClient = function(_, player, offerId)
	table.insert(pendingChoices, { player = player, offerId = offerId })
end
local runEnded = nil
Remotes.RunEnded.FireClient = function(_, _player, summary)
	runEnded = summary
end

require("./GameServer") -- arranca el servidor real
local MatchManager = require("./MatchManager")

local A = M.addPlayer("Ana")
local B = M.addPlayer("Beto")

-- Desde el lobby: los dos se ponen listos y esperan la cuenta regresiva
local function startMatch(chapterId)
	if chapterId then
		M.advance(1)
		Remotes.LobbyRequest.OnServerEvent:Fire(A, "SelectChapter", chapterId)
	end
	M.advance(1)
	Remotes.LobbyRequest.OnServerEvent:Fire(A, "SetReady", true)
	M.advance(1)
	Remotes.LobbyRequest.OnServerEvent:Fire(B, "SetReady", true)
	for _ = 1, 30 * (Config.Match.CountdownTime + 1) do
		M.advance(1 / 30)
		RunService.Heartbeat:Fire(1 / 30)
	end
end

local failed = 0
local function check(cond, msg)
	if cond then
		print("  ok   " .. msg)
	else
		failed += 1
		print("  FALLÓ " .. msg)
	end
end

-- Bot: si no hay enemigos a tiro, da un paso hacia el más cercano
local function botStep(p)
	local c = p.Character
	if not c or PlayerData.get(p).life ~= "ALIVE" then return end
	local root = c.HumanoidRootPart
	-- En el descanso, caminar a la puerta
	if gameState:GetAttribute("Phase") == "Break" and gameState:GetAttribute("DoorEnd") > 0 then
		local door = Arena.doorPosition()
		local to = V.new(door.X - root.Position.X, 0, door.Z - root.Position.Z)
		if to.Magnitude > 3 then
			root.Position = root.Position + to.Unit * math.min(16, to.Magnitude)
		end
		return
	end
	local e, d = Enemies.nearest(root.Position)
	if e and d > Config.Player.AttackRange - 8 then
		local dir = (e.part.Position - root.Position)
		dir = V.new(dir.X, 0, dir.Z).Unit
		root.Position = root.Position + dir * 8
	end
end

local function simulate(seconds, opts)
	local dt = 1 / 30
	local stats = { phases = {}, wavesSeen = {}, bosses = {}, maxEnemies = 0, downs = 0, maxRoom = 1, maxBreak = 0 }
	local breakTime = 0
	local lastPhase = nil
	for frame = 1, math.floor(seconds / dt) do
		M.advance(dt)
		if opts.god then
			for _, p in { A, B } do
				local c = p.Character
				if c and not c:FindFirstChild("God") then
					local f = M.Instance.new("ForceField")
					f.Name = "God"
					f.Parent = c
				end
			end
		end
		RunService.Heartbeat:Fire(dt)
		for _, ch in pendingChoices do
			Remotes.ChooseSkill.OnServerEvent:Fire(ch.player, ch.offerId, 1)
		end
		table.clear(pendingChoices)
		if frame % 60 == 0 then
			botStep(A)
			botStep(B)
		end
		local phase = gameState:GetAttribute("Phase")
		if phase ~= lastPhase then
			table.insert(stats.phases, phase)
			lastPhase = phase
		end
		stats.wavesSeen[gameState:GetAttribute("Wave")] = true
		stats.maxRoom = math.max(stats.maxRoom, gameState:GetAttribute("RoomIndex"))
		if phase == "Break" then
			breakTime += dt
			stats.maxBreak = math.max(stats.maxBreak, breakTime)
		else
			breakTime = 0
		end
		local boss = gameState:GetAttribute("BossName")
		if boss and boss ~= "" then stats.bosses[boss] = true end
		stats.maxEnemies = math.max(stats.maxEnemies, #Enemies.list)
		if opts.untilPhase and phase == opts.untilPhase then
			stats.seconds = frame * dt
			break
		end
	end
	return stats
end

print("Partida 1: capítulo 1 completo con jugadores invulnerables")
startMatch()
check(MatchManager.getState() == "PLAYING", "la partida arrancó desde el lobby")
local s = simulate(30 * 60, { god = true, untilPhase = "Victory" })
local waves = 0
for w in s.wavesSeen do if w > 0 then waves += 1 end end
print(string.format("  oleadas jugadas: %d · tiempo simulado: %s s · enemigos simultáneos máx: %d",
	waves, tostring(s.seconds and math.floor(s.seconds)), s.maxEnemies))
local bossNames = {}
for b in s.bosses do table.insert(bossNames, b) end
table.sort(bossNames)
print("  jefes vistos: " .. table.concat(bossNames, ", "))
check(waves == 10, "se jugaron las 10 oleadas")
check(s.maxRoom == 10, "cruzaron 9 puertas: sala " .. s.maxRoom)
check(s.maxBreak < Config.Rooms.DoorTimeout, string.format("pasaron por la puerta sin esperar el límite (descanso máx %.1f s)", s.maxBreak))
check(s.bosses["Rey Slime"] == true, "apareció el mini-jefe (oleada 5)")
check(s.bosses["Guardián Treant"] == true, "apareció el jefe (oleada 10)")
check(runEnded ~= nil and runEnded.result == "Victory", "terminó en victoria con resumen")
check(gameState:GetAttribute("Level") > 1, "el equipo subió de nivel (" .. tostring(gameState:GetAttribute("Level")) .. ")")
check(gameState:GetAttribute("PartySize") == 2, "la dificultad se escaló para 2 jugadores")

print("Vuelta al lobby y segunda partida en el capítulo 2")
runEnded = nil
simulate(Config.Match.ResultsTime + Config.Match.ReturnDelay + 2, { god = true })
check(MatchManager.getState() == "LOBBY", "volvieron al lobby")
check(not PlayerData.get(A).inMatch and not PlayerData.get(B).inMatch, "nadie quedó en partida")
check(PlayerData.get(A).life == "ALIVE" and PlayerData.get(B).life == "ALIVE", "todos en pie")
startMatch("ruins")
check(gameState:GetAttribute("Chapter") == 2, "la segunda partida es en el capítulo 2")

print("Partida 2: capítulo 2 con daño real hasta que termine")
for _, p in { A, B } do
	local g = p.Character and p.Character:FindFirstChild("God")
	if g then g:Destroy() end
end
local downsBefore = 0
local s2 = simulate(20 * 60, { god = false, untilPhase = "Defeat" })
local downs = PlayerData.get(A).downs + PlayerData.get(B).downs
print(string.format("  fases: %s", table.concat(s2.phases, " > ")))
print(string.format("  derribos: %d", downs - downsBefore))
check(runEnded ~= nil, "la partida terminó (victoria o derrota) con resumen")
if runEnded then
	print(string.format("  resultado: %s en la oleada %d", runEnded.result, runEnded.wave))
end

print(string.format("\n%d fallas", failed))
if failed > 0 then error("hay pruebas que fallaron") end
