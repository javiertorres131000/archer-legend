-- Ciclo de partida (etapa 5): lobby, READY, cuenta regresiva, inicio, resultados y vuelta.
-- Carga el GameServer real y lo hace avanzar frame a frame.
local M = require("./mocks")
local Config = require("./Config")
Config.Player.FireMode = "Auto" -- simula partidas: el jugador ataca solo
Config.Crates.TestGold = 0 -- sin las monedas de prueba de las cajas: se cuentan las del juego
-- Estos bots no giran hacia los enemigos: prueban el flujo, no la puntería
Config.Camera.Mode = "TopDown"
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local MatchManager = require("./MatchManager")
local Arena = require("./Arena")

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
				if gameState:GetAttribute("Phase") == "Break" and gameState:GetAttribute("DoorEnd") > 0 then
					-- descanso: todos a la puerta
					root.Position = Arena.doorPosition() + V.new(0, 3, 0)
				else
					local e, d = Enemies.nearest(root.Position)
					if e and d > Config.Player.AttackRange - 8 then
						local dir = e.part.Position - root.Position
						root.Position = root.Position + V.new(dir.X, 0, dir.Z).Unit * 8
					end
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
	-- Perder también da oro por las oleadas superadas, pero no gemas
	local s = summaries[A]
	eq(s.rewards.Gold or 0, s.wavesCleared * 10 + (if table.find(s.bossesKilled, "KingSlime") then 30 else 0), "oro por oleadas")
	eq(s.rewards.Gems, nil, "sin gemas al perder")
	eq(s.firstClear, false, "no es primera victoria")
	-- Botín de los enemigos: ya cobrado durante la partida y anotado en el resumen
	assert((s.loot.Gold or 0) > 0, "los enemigos soltaron oro")
	eq(A:GetAttribute("RunGold"), s.loot.Gold, "contador del HUD")
	eq(A:GetAttribute("Gold"), (s.rewards.Gold or 0) + s.loot.Gold, "oro en el perfil = recompensa + botín")
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
	eq(A:GetAttribute("UnlockedChapters"), "forest,ruins,tower,daily", "capítulo 2 desbloqueado (y los modos)")
	-- Recompensas: 10 oleadas × 10 + mini-jefe 30 + jefe 60 + victoria 100 = 290 de oro;
	-- gemas 5 + 50 por ser la primera victoria; piedras 1 + 2
	local r = summaries[A].rewards
	eq(r.Gold, 290, "oro")
	eq(r.Gems, 55, "gemas")
	eq(r.Stones, 3, "piedras")
	eq(summaries[A].firstClear, true, "primera victoria")
	assert(A:GetAttribute("Gems") >= 55, "gemas en el perfil")
	eq(A:GetAttribute("ChapterRecords"), "forest=1/10", "récord")
	-- Quedó guardado sin esperar al guardado automático
	local saved = M.dataStore.data["Player_" .. A.UserId].Data
	eq(saved.Currencies.Gems, A:GetAttribute("Gems"), "gemas guardadas")
	eq(saved.Chapters.ruins.Unlocked, true, "desbloqueo guardado")
	eq(saved.Stats.Victories, 1, "victorias")
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
	-- Con hordas, en el medio segundo de juego ya puede haber caído alguno: "desde cero" = pocas
	assert(PlayerData.get(A).kills <= 5, "estadísticas desde cero (bajas: " .. PlayerData.get(A).kills .. ")")
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

test("OTRA: quedás listo solo; si todos los listos vienen de OTRA, cuenta corta", function()
	local Z = M.addPlayer("Zoe")
	local W = M.addPlayer("Walter")
	tick(0.5)
	request(Z, "PlayAgain") -- en el lobby no hace nada
	eq(Z:GetAttribute("Ready"), false, "OTRA fuera de resultados se ignora")
	request(Z, "SetReady", true)
	request(W, "SetReady", true)
	tick(MatchCfg.CountdownTime + 1)
	eq(MatchManager.getState(), "PLAYING", "arrancó")
	local t = playUntil({ "RESULTS" }, 20 * 60, { Z, W })
	assert(t, "debería terminar")
	-- Resumen: récord y progreso de la cuenta para la barra "te faltan X"
	local s = summaries[Z]
	eq(s.bestWaveBefore, 0, "primera partida: sin récord previo")
	eq(s.newRecord, s.wavesCleared > 0, "récord nuevo si pasó alguna oleada")
	assert(s.account and s.account.needed > 0 and s.account.xp < s.account.needed, "progreso de cuenta")
	eq(s.account.level, Z:GetAttribute("AccountLevel"), "nivel de cuenta")
	request(Z, "PlayAgain")
	eq(MatchManager.getState(), "RESULTS", "muy pronto: se ignora")
	tick(MatchCfg.MinResultsTime)
	request(Z, "PlayAgain")
	eq(MatchManager.getState(), "RESULTS", "falta Walter")
	request(W, "ReturnToLobby")
	eq(MatchManager.getState(), "RETURNING", "los dos votaron")
	tick(MatchCfg.ReturnDelay + 0.2)
	eq(MatchManager.getState(), "PREPARING", "Zoe lista sola, Walter no")
	eq(Z:GetAttribute("Ready"), true, "Zoe quedó lista por OTRA")
	eq(W:GetAttribute("Ready"), false, "Walter no")
	-- Walter se pone listo a mano: cuenta normal
	request(W, "SetReady", true)
	eq(MatchManager.getState(), "STARTING", "todos listos")
	local left = gameState:GetAttribute("CountdownEnd") - M.workspace:GetServerTimeNow()
	assert(left > MatchCfg.AgainCountdownTime + 0.5, "cuenta normal: " .. left)
	-- Walter cancela y se va: queda solo Zoe (de OTRA) → cuenta corta
	request(W, "SetReady", false)
	M.removePlayer(W)
	tick(0.1)
	eq(MatchManager.getState(), "STARTING", "Zoe sola lista")
	left = gameState:GetAttribute("CountdownEnd") - M.workspace:GetServerTimeNow()
	assert(left <= MatchCfg.AgainCountdownTime + 0.01, "cuenta corta: " .. left)
	tick(MatchCfg.AgainCountdownTime + 0.5)
	eq(MatchManager.getState(), "PLAYING", "arrancó otra")
	M.removePlayer(Z)
	tick(MatchCfg.ReturnDelay + 1)
	eq(MatchManager.getState(), "LOBBY", "vuelve al lobby")
end)

test("Ana vuelve a entrar otro día: conserva capítulos, monedas y récords", function()
	local saved = M.dataStore.data["Player_" .. A.UserId]
	eq(saved.Lock, nil, "al irse soltó el perfil")
	local Ana = M.addPlayer("Ana", A.UserId)
	tick(0.5)
	eq(Ana:GetAttribute("ProfileStatus"), "Ready", "perfil cargado")
	eq(Ana:GetAttribute("UnlockedChapters"), "forest,ruins,tower,daily", "capítulos")
	assert(Ana:GetAttribute("Gems") >= 55, "gemas")
	assert(string.find(Ana:GetAttribute("ChapterRecords"), "forest=1/10", 1, true), "récord")
	M.removePlayer(Ana)
end)

test("mientras carga el perfil no se puede poner listo; si DataStore falla, juega sin guardar", function()
	local Z
	notices = {}
	M.dataStore.onCall = function()
		-- Pide "listo" a mitad de la carga
		local loading = M.playerList[#M.playerList] -- Zoe (todavía no volvió addPlayer)
		Remotes.LobbyRequest.OnServerEvent:Fire(loading, "SetReady", true)
		error("502: se colgó (simulado)")
	end
	Z = M.addPlayer("Zoe")
	M.dataStore.onCall = nil
	eq(Z:GetAttribute("Ready"), false, "no quedó listo durante la carga")
	assert(#notices > 0 and string.find(notices[1].msg, "Cargando", 1, true), "aviso de carga: " .. tostring(notices[1] and notices[1].msg))
	tick(0.5)
	eq(Z:GetAttribute("ProfileStatus"), "Offline", "sin DataStore juega igual")
	request(Z, "SetReady", true)
	eq(Z:GetAttribute("Ready"), true, "con el perfil temporal ya puede")
	request(Z, "SetReady", false)
	M.removePlayer(Z)
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then error("hay pruebas que fallaron") end
