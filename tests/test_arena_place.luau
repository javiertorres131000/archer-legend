-- El place de la Arena: recibe al grupo teletransportado, espera a que lleguen, arranca solo
-- y al terminar devuelve a la Ciudadela a los que no eligieron OTRA.
local M = require("./mocks")
M.workspace:SetAttribute("TestClassicLobby", false)
local Config = require("./Config")
Config.Crates.TestGold = 0
Config.Debug.UnlockAllChapters = true
Config.Camera.Mode = "TopDown"
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local MatchManager = require("./MatchManager")
local Places = require("./Places")
local Teleporter = require("./Teleporter")

Places._setRole("Arena")

-- Datos de viaje falsos (por nombre) y viajes capturados
local joinData = {}
Teleporter.joinData = function(p)
	return joinData[p.Name]
end
local trips = {}
Teleporter._setFake(function(placeId, players, data, reserved)
	table.insert(trips, { placeId = placeId, players = table.clone(players), data = data, reserved = reserved })
	return true, nil
end)

local RunService = M.game:GetService("RunService")
local MatchCfg = Config.Match
local PlaceCfg = Config.Places
local gameState = Remotes.GameState
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
local function tick(seconds)
	local dt = 1 / 30
	for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
		M.advance(dt)
		RunService.Heartbeat:Fire(dt)
		for _, ch in pendingChoices do
			Remotes.ChooseSkill.OnServerEvent:Fire(ch.player, ch.offerId, 1)
		end
		table.clear(pendingChoices)
	end
end
local function request(p, action, arg)
	tick(MatchCfg.RequestCooldown + 0.05)
	Remotes.LobbyRequest.OnServerEvent:Fire(p, action, arg)
end
local function tripsOf(p)
	local n = 0
	for _, t in trips do
		if table.find(t.players, p) then n += 1 end
	end
	return n
end
local function untilState(s, maxSeconds)
	local t = 0
	while MatchManager.getState() ~= s and t < maxSeconds do
		tick(0.5)
		t += 0.5
	end
	return MatchManager.getState() == s
end

print("Place de la arena")

test("rol Arena publicado", function()
	eq(Places.role(), "Arena", "rol")
	eq(gameState:GetAttribute("PlaceRole"), "Arena", "PlaceRole")
end)

test("quien entra sin viaje vuelve a la Ciudadela", function()
	local X = M.addPlayer("Intruso", 900)
	tick(1)
	eq(tripsOf(X), 1, "viaje de vuelta")
	eq(trips[1].placeId, PlaceCfg.LobbyPlaceId, "al lobby")
	eq(trips[1].reserved, false, "servidor público")
	M.removePlayer(X)
	trips = {}
end)

local members = { 101, 102, 103 }
joinData.Ana = { chapter = "ruins", members = members, version = 1 }
joinData.Beto = { chapter = "ruins", members = members, version = 1 }
local A = M.addPlayer("Ana", 101)
local B

test("espera al grupo: con 1 de 3 no arranca", function()
	tick(3)
	eq(MatchManager.getState(), "LOBBY", "esperando")
	eq(gameState:GetAttribute("ArenaWaiting"), "1/3", "contador de llegada")
	eq(gameState:GetAttribute("SelectedChapter"), "ruins", "capítulo del viaje")
	B = M.addPlayer("Beto", 102)
	tick(3)
	eq(MatchManager.getState(), "LOBBY", "falta Caro")
	eq(gameState:GetAttribute("ArenaWaiting"), "2/3", "contador")
end)

test("si alguien no llega, arranca igual al pasar el tiempo máximo", function()
	assert(untilState("STARTING", PlaceCfg.ArenaWaitMax + 2), "debería arrancar la cuenta")
	eq(A:GetAttribute("Ready"), true, "Ana lista sola")
	eq(B:GetAttribute("Ready"), true, "Beto listo solo")
	assert(untilState("PLAYING", PlaceCfg.ArenaCountdown + 2), "debería empezar la partida")
	eq(PlayerData.get(A).inMatch, true, "Ana jugando")
	eq(PlayerData.get(B).inMatch, true, "Beto jugando")
	eq(#trips, 0, "nadie volvió")
end)

test("al terminar: OTRA se queda y arranca solo, el resto vuelve a la Ciudadela", function()
	assert(untilState("RESULTS", 20 * 60), "la partida debería terminar")
	tick(MatchCfg.MinResultsTime)
	request(A, "PlayAgain")
	request(B, "ReturnToLobby")
	eq(MatchManager.getState(), "RETURNING", "votaron los dos")
	-- Ana es la única esperada: apenas vuelven, arranca sola la cuenta corta
	assert(untilState("STARTING", MatchCfg.ReturnDelay + 3), "cuenta de la revancha: " .. MatchManager.getState())
	eq(tripsOf(B), 1, "Beto vuelve a la Ciudadela")
	eq(tripsOf(A), 0, "Ana se queda")
	eq(B:GetAttribute("Ready"), false, "Beto no queda listo")
	assert(untilState("PLAYING", PlaceCfg.ArenaCountdown + 2), "revancha")
	eq(PlayerData.get(A).inMatch, true, "Ana jugando otra vez")
	eq(PlayerData.get(B).inMatch, false, "Beto (yéndose) no entra a la revancha")
	eq(gameState:GetAttribute("PartySize"), 1, "escalado para 1")
end)

print(string.format("%d ok, %d fallaron", passed, failed))
if failed > 0 then
	error("fallaron pruebas de la arena")
end
