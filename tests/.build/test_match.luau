-- Ciclo de partida (etapa 5): lobby, READY, cuenta regresiva, inicio, resultados y vuelta.
-- Carga el GameServer real y lo hace avanzar frame a frame.
local M = require("./mocks")
local Config = require("./Config")
-- Estos bots no giran hacia los enemigos: prueban el flujo, no la puntería
Config.Camera.Mode = "TopDown"
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local MatchManager = require("./MatchManager")

local V = M.Vector3
local RunService = M.game:GetService("RunService")
local gameState = Remotes.GameState
local MatchCfg = Config.Match

-- Capturamos lo que el servidor les manda a los clientes
local notices = {}
Remotes.LobbyNotice.FireClient = function(_, player, msg)
	table.insert(notices, { player = player, msg = msg })
end
local summaries = {}
Remotes.RunEnded.FireClient = function(_, player, summary)
	summaries[player] = summary
end
local pendingChoices = {}
Remotes.SkillOffer.FireClient = function(_, player, offerId)
	table.insert(pendingChoices, { player = player, offerId = offerId })
end

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

local god = {}
local function tick(seconds)
	local dt = 1 / 30
	for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
		M.advance(dt)
		for p in god do
			local c = p.Character
			if c and PlayerData.get(p) and PlayerData.get(p).inMatch and not c:FindFirstChild("God") then
				local f = M.Instance.new("ForceField")
				f.Name = "God"
				f.Parent = c
			end
		end
		RunService.Heartbeat:Fire(dt)
		for _, ch in pendingChoices do
			Remotes.ChooseSkill.OnServerEvent:Fire(ch.player, ch.offerId, 1)
		end
		table.clear(pendingChoices)
	end
end
-- Las peticiones respetan el límite de frecuencia: esperamos un poquito entre cada una
local function request(p, action, arg)
	tick(MatchCfg.RequestCooldown + 0.05)
	Remotes.LobbyRequest.OnServerEvent:Fire(p, action, arg)
end
local function stateIs(s) return MatchManager.getState() == s end
local function inMatch(p) return PlayerData.get(p).inMatch end
local function lobbyZ(p) return p.Character.HumanoidRootPart.Position.Z end

-- Bot simple: si no hay enemigos a tiro, se acerca al más cercano
local function playUntil(states, maxSeconds, players)
	local t = 0
	while t < maxSeconds do
		tick(1)
		t += 1
		for _, p in players do
			local c = p.Character
			if c and PlayerData.get(p) and PlayerData.get(p).inMatch and PlayerData.get(p).life == "ALIVE" then
				local root = c.HumanoidRootPart
				local e, d = Enemies.nearest(root.Position)
				if e and d > Config.Player.AttackRange - 8 then
					local dir = e.part.Position - root.Position
					root.Position = root.Position + V.new(dir.X, 0, dir.Z).Unit * 8
				end
			end
		end
		if table.find(states, MatchManager.getState()) then
			return t
		end
	end
	return nil
end

print("Ciclo de partida")

local A = M.addPlayer("Ana")

test("1. al entrar: LOBBY, en la zona del lobby y sin oleadas", function()
	tick(3)
	eq(MatchManager.getState(), "LOBBY", "estado")
	eq(inMatch(A), false, "Ana no está en partida")
	assert(lobbyZ(A) > 300, "Ana debería estar en el lobby (Z > 300), está en " .. lobbyZ(A))
	eq(gameState:GetAttribute("Wave"), 0, "no arrancó ninguna oleada")
	eq(MatchManager.leader(), A, "Ana es la líder")
	eq(gameState:GetAttribute("SelectedChapter"), "forest", "capítulo inicial")
end)

test("1. solo: READY → cuenta de 5 s → PLAYING en la arena, oleada 1", function()
	request(A, "SetReady", true)
	eq(MatchManager.getState(), "STARTING", "estado")
	eq(A:GetAttribute("Ready"), true, "atributo Ready")
	tick(MatchCfg.CountdownTime - 1)
	eq(MatchManager.getState(), "STARTING", "todavía en cuenta")
	tick(1.2)
	eq(MatchManager.getState(), "PLAYING", "estado")
	eq(inMatch(A), true, "Ana en partida")
	assert(math.abs(lobbyZ(A)) < 60, "Ana debería estar en la arena")
	tick(1)
	eq(gameState:GetAttribute("Wave"), 1, "oleada")
	eq(gameState:GetAttribute("PartySize"), 1, "escalado para 1")
	eq(A:GetAttribute("Ready"), false, "Ready se limpia al empezar")
end)

test("8. no se pueden iniciar partidas duplicadas", function()
	local started = MatchManager.matchesStarted()
	request(A, "SetReady", true) -- ya está jugando: se rechaza
	MatchManager._forceStart() -- arranque directo: se ignora fuera de STARTING
	MatchManager._forceStart()
	tick(1)
	eq(MatchManager.matchesStarted(), started, "partidas iniciadas")
	eq(MatchManager.getState(), "PLAYING", "estado")
end)

test("un jugador que entra durante la partida espera en el lobby", function()
	local B = M.addPlayer("Beto")
	tick(1)
	eq(inMatch(B), false, "Beto no entra a la partida")
	assert(lobbyZ(B) > 300, "Beto en el lobby")
	notices = {}
	request(B, "SetReady", true)
	eq(B:GetAttribute("Ready"), false, "no puede ponerse listo")
	assert(#notices > 0, "debería recibir un aviso")
	eq(gameState:GetAttribute("PartySize"), 1, "la dificultad no cambia")
	M.removePlayer(B)
end)

test("6. derrota y regreso al lobby", function()
	local t = playUntil({ "RESULTS" }, 20 * 60, { A })
	assert(t, "la partida debería terminar")
	eq(summaries[A] and summaries[A].result, "Defeat", "resultado")
	eq(Enemies.aliveCount() >= 0, true, "")
	eq(MatchManager.getState(), "RESULTS", "muestra resultados")
	local waited = 0
	while MatchManager.getState() == "RESULTS" and waited < MatchCfg.ResultsTime + 2 do
		tick(0.1)
		waited += 0.1
	end
	eq(MatchManager.getState(), "RETURNING", "vuelve solo al terminar el tiempo")
	eq(Enemies.aliveCount(), 0, "enemigos limpios")
	eq(inMatch(A), false, "Ana fuera de la partida")
	assert(lobbyZ(A) > 300, "Ana en el lobby")
	tick(MatchCfg.ReturnDelay + 0.2)
	eq(MatchManager.getState(), "LOBBY", "estado")
	eq(gameState:GetAttribute("Level"), 1, "nivel reiniciado")
end)

local B = M.addPlayer("Beto")
M.moveTo(B, V.new(4, 3, 400))

test("2. dos jugadores: uno listo = PREPARING, los dos = STARTING", function()
	tick(1)
	request(A, "SetReady", true)
	eq(MatchManager.getState(), "PREPARING", "con 1 de 2")
	request(B, "SetReady", true)
	eq(MatchManager.getState(), "STARTING", "con 2 de 2")
end)

test("3. cancelar READY detiene la cuenta", function()
	tick(2)
	request(B, "SetReady", false)
	eq(MatchManager.getState(), "PREPARING", "estado")
	eq(gameState:GetAttribute("CountdownEnd"), 0, "cuenta cancelada")
	tick(MatchCfg.CountdownTime + 1)
	eq(MatchManager.getState(), "PREPARING", "no arranca solo")
	request(B, "SetReady", true)
	eq(MatchManager.getState(), "STARTING", "vuelve a contar")
end)

test("el capítulo bloqueado no se puede elegir; solo el líder elige", function()
	notices = {}
	request(B, "SelectChapter", "forest") -- Beto no es líder
	request(A, "SelectChapter", "ruins") -- bloqueado
	eq(gameState:GetAttribute("SelectedChapter"), "forest", "capítulo")
	eq(#notices, 2, "dos avisos")
	request(A, "SelectChapter", 123) -- tipo inválido: ignorado
	request(A, "Hackear", true) -- acción inexistente: ignorada
	eq(MatchManager.getState(), "STARTING", "nada cambió")
end)

test("4. desconexión durante la cuenta: sigue con quien queda", function()
	local C = M.addPlayer("Caro")
	tick(0.5)
	eq(MatchManager.getState(), "PREPARING", "un jugador nuevo sin listo cancela la cuenta")
	M.removePlayer(C)
	tick(0.1)
	eq(MatchManager.getState(), "STARTING", "al irse, los que quedan están listos")
	M.removePlayer(B)
	tick(0.1)
	eq(MatchManager.getState(), "STARTING", "sigue con Ana sola")
	tick(MatchCfg.CountdownTime + 0.5)
	eq(MatchManager.getState(), "PLAYING", "arranca")
	eq(gameState:GetAttribute("PartySize"), 1, "escalado para 1")
end)

test("5. victoria, desbloqueo del capítulo 2 y regreso al lobby", function()
	god[A] = true
	local t = playUntil({ "RESULTS" }, 30 * 60, { A })
	god[A] = nil
	assert(t, "debería terminar")
	eq(summaries[A].result, "Victory", "resultado")
	eq(A:GetAttribute("UnlockedChapters"), "forest,ruins", "capítulo 2 desbloqueado")
	-- Votar volver antes de tiempo se ignora; después, vuelve
	request(A, "ReturnToLobby")
	eq(MatchManager.getState(), "RESULTS", "muy pronto para volver")
	tick(MatchCfg.MinResultsTime)
	request(A, "ReturnToLobby")
	eq(MatchManager.getState(), "RETURNING", "volvió por voto")
	tick(MatchCfg.ReturnDelay + 0.2)
	eq(MatchManager.getState(), "LOBBY", "estado")
	assert(lobbyZ(A) > 300, "Ana en el lobby")
end)

test("7. segunda partida en el capítulo 2, desde cero", function()
	request(A, "SelectChapter", "ruins")
	eq(gameState:GetAttribute("SelectedChapter"), "ruins", "capítulo elegido")
	request(A, "SetReady", true)
	tick(MatchCfg.CountdownTime + 1.5)
	eq(MatchManager.getState(), "PLAYING", "estado")
	eq(gameState:GetAttribute("ChapterName"), "Ruinas Perdidas", "capítulo")
	eq(gameState:GetAttribute("Level"), 1, "nivel desde cero")
	eq(PlayerData.get(A).kills, 0, "estadísticas desde cero")
	eq(PlayerData.get(A).life, "ALIVE", "en pie")
end)

test("todos abandonan la partida: vuelve al lobby sin resultados", function()
	M.removePlayer(A)
	tick(0.5)
	assert(stateIs("RETURNING") or stateIs("LOBBY"), "estado " .. MatchManager.getState())
	tick(MatchCfg.ReturnDelay + 0.2)
	eq(MatchManager.getState(), "LOBBY", "estado")
	eq(Enemies.aliveCount(), 0, "arena limpia")
end)

test("líder: si se va, pasa al siguiente", function()
	local D = M.addPlayer("Dani")
	local E = M.addPlayer("Eli")
	tick(0.5)
	eq(MatchManager.leader(), D, "Dani líder")
	M.removePlayer(D)
	tick(0.1)
	eq(MatchManager.leader(), E, "Eli líder")
	M.removePlayer(E)
end)

test("equipo completo: el quinto no puede ponerse listo", function()
	local ps = {}
	for i = 1, 5 do table.insert(ps, M.addPlayer("P" .. i)) end
	tick(0.5)
	for i = 1, 4 do request(ps[i], "SetReady", true) end
	eq(MatchManager.getState(), "STARTING", "4 de 5 listos alcanza (equipo lleno)")
	request(ps[5], "SetReady", true)
	eq(ps[5]:GetAttribute("Ready"), false, "el quinto queda afuera")
	tick(MatchCfg.CountdownTime + 1)
	eq(MatchManager.getState(), "PLAYING", "arranca con 4")
	eq(gameState:GetAttribute("PartySize"), 4, "escalado para 4")
	eq(inMatch(ps[5]), false, "el quinto sigue en el lobby")
	for _, p in ps do M.removePlayer(p) end
	tick(MatchCfg.ReturnDelay + 1)
end)

test("en resultados, irse cuenta como voto para volver", function()
	local X = M.addPlayer("Xime")
	local Y = M.addPlayer("Yago")
	tick(0.5)
	request(X, "SetReady", true)
	request(Y, "SetReady", true)
	tick(MatchCfg.CountdownTime + 1)
	eq(MatchManager.getState(), "PLAYING", "arrancó con los dos")
	local t = playUntil({ "RESULTS" }, 20 * 60, { X, Y })
	assert(t, "debería terminar")
	tick(MatchCfg.MinResultsTime + 0.1)
	request(X, "ReturnToLobby")
	eq(MatchManager.getState(), "RESULTS", "falta el voto de Yago")
	M.removePlayer(Y)
	tick(0.1)
	eq(MatchManager.getState(), "RETURNING", "al irse Yago, vuelven")
	tick(MatchCfg.ReturnDelay + 0.2)
	eq(MatchManager.getState(), "LOBBY", "estado")
	M.removePlayer(X)
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then error("hay pruebas que fallaron") end
