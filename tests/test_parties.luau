-- Grupos y cola rápida (PartyService) en el rol "Lobby" (la Ciudadela).
-- En Studio (sin teletransporte) un grupo listo juega en este mismo servidor; con
-- teletransporte (falso) se arma el viaje a la arena con los datos del grupo.
local M = require("./mocks")
M.workspace:SetAttribute("TestClassicLobby", false)
local Config = require("./Config")
Config.Crates.TestGold = 0
Config.Debug.UnlockAllChapters = true
Config.Camera.Mode = "TopDown"
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local MatchManager = require("./MatchManager")
local PartyService = require("./PartyService")
local Places = require("./Places")
local Teleporter = require("./Teleporter")

local RunService = M.game:GetService("RunService")
local MatchCfg = Config.Match
local PlaceCfg = Config.Places

local notices = {}
Remotes.LobbyNotice.FireClient = function(_, player, msg)
	table.insert(notices, { player = player, msg = msg })
end
local invitesSent = {}
Remotes.PartyInvite.FireClient = function(_, player, info)
	table.insert(invitesSent, { player = player, info = info })
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
	end
end
local function request(p, action, arg)
	tick(MatchCfg.RequestCooldown + 0.05)
	Remotes.LobbyRequest.OnServerEvent:Fire(p, action, arg)
end
local function lastInviteFor(p)
	for i = #invitesSent, 1, -1 do
		if invitesSent[i].player == p then
			return invitesSent[i].info
		end
	end
	return nil
end
local function invite(from, to)
	request(from, "Invite", to.UserId)
	local info = lastInviteFor(to)
	assert(info, "debería llegar la invitación")
	request(to, "AcceptInvite", info.PartyId)
end
local function sameParty(a, b)
	return a:GetAttribute("PartyId") ~= nil and a:GetAttribute("PartyId") == b:GetAttribute("PartyId")
end

print("Grupos y cola rápida")

local A = M.addPlayer("Ana")
local B = M.addPlayer("Beto")
local C = M.addPlayer("Caro")
tick(3)

test("rol Lobby y cada uno en su grupo solo", function()
	eq(Places.role(), "Lobby", "rol")
	eq(Remotes.GameState:GetAttribute("PlaceRole"), "Lobby", "PlaceRole publicado")
	eq(A:GetAttribute("PartySize"), 1, "Ana sola")
	eq(B:GetAttribute("PartySize"), 1, "Beto solo")
	eq(sameParty(A, B), false, "grupos distintos")
	eq(A:GetAttribute("PartyLeader"), A.UserId, "Ana líder de su grupo")
	eq(A:GetAttribute("PartyChapter"), "forest", "capítulo inicial")
end)

test("el listo de uno no mueve a otro grupo (servidor compartido)", function()
	request(B, "SetReady", true)
	eq(B:GetAttribute("Ready"), true, "Beto listo")
	assert((B:GetAttribute("PartyCountdownEnd") or 0) > 0, "Beto con cuenta")
	eq(A:GetAttribute("PartyCountdownEnd"), 0, "Ana sin cuenta")
	request(B, "SetReady", false)
	eq(B:GetAttribute("PartyCountdownEnd"), 0, "cuenta cancelada")
end)

test("invitar y aceptar: mismo grupo, Ana líder", function()
	invite(A, B)
	assert(sameParty(A, B), "Beto se sumó al grupo de Ana")
	eq(A:GetAttribute("PartySize"), 2, "tamaño")
	eq(B:GetAttribute("PartyLeader"), A.UserId, "líder")
end)

test("rechazar una invitación no cambia nada", function()
	request(A, "Invite", C.UserId)
	local info = lastInviteFor(C)
	assert(info, "invitación a Caro")
	request(C, "DeclineInvite", info.PartyId)
	eq(sameParty(A, C), false, "Caro sigue sola")
	-- la misma invitación ya no sirve
	request(C, "AcceptInvite", info.PartyId)
	eq(sameParty(A, C), false, "invitación usada")
end)

test("la invitación vence", function()
	request(A, "Invite", C.UserId)
	local info = lastInviteFor(C)
	tick(PlaceCfg.InviteTime + 1)
	request(C, "AcceptInvite", info.PartyId)
	eq(sameParty(A, C), false, "Caro sigue sola")
end)

test("solo el líder cambia el capítulo y eso limpia los listos", function()
	request(B, "SelectChapter", "ruins")
	eq(A:GetAttribute("PartyChapter"), "forest", "Beto no puede")
	request(B, "SetReady", true)
	eq(B:GetAttribute("Ready"), true, "Beto listo")
	request(A, "SelectChapter", "ruins")
	eq(B:GetAttribute("PartyChapter"), "ruins", "capítulo del grupo")
	eq(B:GetAttribute("Ready"), false, "listos reiniciados")
	request(A, "SelectChapter", "forest")
end)

test("expulsar y salir del grupo", function()
	request(B, "Kick", A.UserId)
	assert(sameParty(A, B), "Beto no puede expulsar")
	request(A, "Kick", B.UserId)
	eq(sameParty(A, B), false, "Beto expulsado")
	eq(B:GetAttribute("PartySize"), 1, "Beto solo")
	invite(A, B)
	assert(sameParty(A, B), "vuelve")
	request(B, "LeaveParty")
	eq(sameParty(A, B), false, "Beto salió")
	eq(A:GetAttribute("PartySize"), 1, "Ana sola")
end)

test("grupo listo → cuenta → partida local solo con el grupo (Studio)", function()
	invite(A, B)
	request(A, "SetReady", true)
	eq(A:GetAttribute("PartyCountdownEnd"), 0, "falta Beto")
	request(B, "SetReady", true)
	assert(A:GetAttribute("PartyCountdownEnd") > 0, "cuenta del grupo")
	tick(MatchCfg.CountdownTime + 1)
	eq(PlayerData.get(A).inMatch, true, "Ana jugando")
	eq(PlayerData.get(B).inMatch, true, "Beto jugando")
	eq(PlayerData.get(C).inMatch, false, "Caro (otro grupo) en la ciudadela")
	eq(MatchManager.isFree(), false, "arena ocupada")
end)

test("con la arena local ocupada, otro grupo espera y sale cuando se libera", function()
	notices = {}
	request(C, "SetReady", true)
	tick(MatchCfg.CountdownTime + 1)
	eq(PlayerData.get(C).inMatch, false, "Caro espera")
	local told = false
	for _, n in notices do
		if n.player == C then told = true end
	end
	assert(told, "Caro recibe un aviso")
	-- terminan los otros: se van del servidor
	M.removePlayer(A)
	M.removePlayer(B)
	local waited = 0
	while not PlayerData.get(C).inMatch and waited < 90 do
		tick(0.5)
		waited += 0.5
	end
	eq(PlayerData.get(C).inMatch, true, "Caro jugando al liberarse la arena")
	M.removePlayer(C)
	local w = 0
	while not MatchManager.isFree() and w < 60 do
		tick(0.5)
		w += 0.5
	end
	assert(MatchManager.isFree(), "arena libre al irse todos")
end)

-- Desde acá, con teletransporte (falso)
local trips = {}
M.isStudio = false
PlaceCfg.ArenaPlaceId = 999
Teleporter._setFake(function(placeId, players, data, reserved)
	table.insert(trips, { placeId = placeId, players = table.clone(players), data = data, reserved = reserved })
	return true, nil
end)

local D = M.addPlayer("Dani")
local E = M.addPlayer("Eli")
local F = M.addPlayer("Fede")
tick(3)

test("cola rápida: arma un grupo con dos jugadores sueltos del mismo capítulo", function()
	request(D, "Queue", true)
	eq(D:GetAttribute("InQueue"), true, "Dani en cola")
	request(E, "Queue", true)
	eq(E:GetAttribute("InQueue"), true, "Eli en cola")
	-- al pasar el tiempo máximo de espera sale el grupo aunque no esté lleno
	tick(PlaceCfg.QueueMaxWait + PlaceCfg.QueueStartDelay + 1.5)
	eq(#trips, 1, "un viaje")
	local trip = trips[1]
	eq(trip.placeId, 999, "a la arena")
	eq(trip.reserved, true, "servidor privado")
	eq(#trip.players, 2, "los dos juntos")
	eq(trip.data.chapter, "forest", "capítulo")
	eq(#trip.data.members, 2, "miembros en los datos")
	eq(D:GetAttribute("InQueue"), false, "fuera de la cola")
	eq(D:GetAttribute("Traveling"), "Arena", "viajando")
end)

test("cola con capítulos distintos no se mezcla", function()
	trips = {}
	D:SetAttribute("Traveling", nil)
	E:SetAttribute("Traveling", nil)
	request(D, "SelectChapter", "ruins")
	request(D, "Queue", true)
	request(F, "Queue", true)
	tick(1)
	eq(D:GetAttribute("PartyCountdownEnd"), 0, "sin grupo todavía")
	-- cancelar la cola
	request(F, "Queue", false)
	eq(F:GetAttribute("InQueue"), false, "Fede salió de la cola")
	request(D, "Queue", false)
	tick(PlaceCfg.QueueMaxWait + 2)
	eq(#trips, 0, "nadie viajó")
end)

test("si uno cancela en la cuenta del grupo armado, el otro vuelve a la cola", function()
	trips = {}
	request(D, "SelectChapter", "forest")
	request(D, "Queue", true)
	request(F, "Queue", true)
	tick(PlaceCfg.QueueMaxWait + 0.5)
	assert((D:GetAttribute("PartyCountdownEnd") or 0) > 0, "grupo armado")
	request(F, "SetReady", false)
	eq(F:GetAttribute("PartyCountdownEnd"), 0, "Fede canceló")
	eq(D:GetAttribute("InQueue"), true, "Dani de nuevo en la cola")
	-- conserva su lugar: como ya esperó el máximo, sale aunque sea sola
	tick(PlaceCfg.QueueStartDelay + 1.5)
	eq(#trips, 1, "un viaje")
	eq(#trips[1].players, 1, "solo Dani (Fede canceló)")
	eq(trips[1].players[1], D, "Dani")
	eq(F:GetAttribute("Traveling"), nil, "Fede se queda")
	D:SetAttribute("Traveling", nil)
end)

test("grupo propio con teletransporte: viaja todo el grupo junto", function()
	trips = {}
	invite(D, F)
	request(D, "SetReady", true)
	request(F, "SetReady", true)
	tick(MatchCfg.CountdownTime + 1)
	eq(#trips, 1, "un viaje")
	eq(#trips[1].players, 2, "los dos")
	eq(F:GetAttribute("Ready"), false, "listos limpios después de salir")
end)

test("si el viaje falla, avisa y el grupo queda en la ciudadela", function()
	trips = {}
	D:SetAttribute("Traveling", nil)
	F:SetAttribute("Traveling", nil)
	Teleporter._setFake(function() return false, "falló" end)
	notices = {}
	request(D, "SetReady", true)
	request(F, "SetReady", true)
	tick(MatchCfg.CountdownTime + 1)
	eq(D:GetAttribute("Traveling"), nil, "no viaja")
	eq(D:GetAttribute("PartyCountdownEnd"), 0, "cuenta cortada")
	local told = false
	for _, n in notices do
		if n.player == D then told = true end
	end
	assert(told, "avisa")
end)

test("salir del servidor deja al resto del grupo con nuevo líder", function()
	M.removePlayer(D)
	tick(1)
	eq(F:GetAttribute("PartyLeader"), F.UserId, "Fede líder")
	eq(F:GetAttribute("PartySize"), 1, "solo Fede")
	eq(PartyService.partyOf(D), nil, "Dani sin grupo")
end)

print(string.format("%d ok, %d fallaron", passed, failed))
if failed > 0 then
	error("fallaron pruebas de grupos")
end
