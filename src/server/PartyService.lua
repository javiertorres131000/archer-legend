--!strict
-- PartyService (ModuleScript)
-- Ubicación: ServerScriptService > Server > PartyService
-- Grupos del lobby (rol "Lobby" de Server/Places). Cada jugador está siempre en un grupo (al
-- entrar, uno propio). Hasta Config.Match.MaxPartySize por grupo.
--   · Invitar: el que invita manda ("Invite", UserId); al invitado le llega Remotes.PartyInvite
--     y responde ("AcceptInvite", Id del grupo) o ("DeclineInvite", Id). Vencen en InviteTime.
--   · ("LeaveParty"): queda solo. ("Kick", UserId): solo el líder.
--   · ("SelectChapter", Id): solo el líder; todos tienen que tenerlo desbloqueado.
--   · ("SetReady", bool): cuando todos están listos, cuenta regresiva y salen a jugar.
--   · ("Queue", bool): cola rápida (solo el líder, grupo incompleto). Junta grupos que buscan el
--     mismo capítulo hasta completar; si en QueueMaxWait no se llenó, sale igual.
-- Salir a jugar: si se puede teletransportar (Places.canTeleport) viajan a una arena privada
-- (Teleporter.toArena); si no, la partida se juega en este servidor (MatchManager.startWith).
-- Todo lo publica en atributos de cada Player para el cliente (LobbyUI):
--   PartyId, PartyLeader (UserId), PartyChapter, PartyCountdownEnd (hora del servidor, 0 = no),
--   InQueue, QueueSince (hora del servidor) y Ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Modes = require(Shared:WaitForChild("Modes"))
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Profiles = require(script.Parent.Profiles)
local ChapterUnlocks = require(script.Parent.ChapterUnlocks)
local MatchManager = require(script.Parent.MatchManager)
local Places = require(script.Parent.Places)
local Teleporter = require(script.Parent.Teleporter)

local MatchCfg = Config.Match
local PlaceCfg = Config.Places

export type Party = {
	Id: string,
	Leader: Player,
	Members: { Player },
	Chapter: string,
	Ready: { [Player]: boolean },
	Again: { [Player]: boolean }, -- listos por OTRA (cuenta corta)
	CountdownEnd: number, -- 0 = sin cuenta
	Queued: boolean,
	QueueSince: number,
	Launching: boolean,
	Group: { Party }?, -- grupos que salen juntos (armado por la cola rápida)
	Pending: { Party }?, -- salida esperando que se libere la arena (partida local)
}

local PartyService = {}

local parties: { [string]: Party } = {}
local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { [string]: { from: Player, expires: number } } } = {}
local lastRequest: { [Player]: number } = {}
local nextId = 0
local tickAccum = 0
local publishLater: (Party) -> ()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, message: string)
	Remotes.LobbyNotice:FireClient(player, message)
end

local function isChapter(id: string): boolean
	for _, ch in Chapters do
		if ch.Id == id then
			return true
		end
	end
	return Modes.ById[id] ~= nil
end

---------------------------------------------------------------------
-- Publicar
---------------------------------------------------------------------

local function publish(party: Party)
	for _, p in party.Members do
		p:SetAttribute("PartyId", party.Id)
		p:SetAttribute("PartyLeader", party.Leader.UserId)
		p:SetAttribute("PartyChapter", party.Chapter)
		p:SetAttribute("PartyCountdownEnd", party.CountdownEnd)
		p:SetAttribute("InQueue", party.Queued)
		p:SetAttribute("QueueSince", if party.Queued then party.QueueSince else 0)
		p:SetAttribute("Ready", party.Ready[p] == true)
		p:SetAttribute("PartySize", #party.Members)
	end
end

-- (se define abajo de publish; breakGroup la usa)
publishLater = function(party: Party)
	publish(party)
end

local function newParty(leader: Player, chapter: string?): Party
	nextId += 1
	local party: Party = {
		Id = "P" .. nextId,
		Leader = leader,
		Members = { leader },
		Chapter = chapter or Chapters[1].Id,
		Ready = {},
		Again = {},
		CountdownEnd = 0,
		Queued = false,
		QueueSince = 0,
		Launching = false,
		Group = nil,
		Pending = nil,
	}
	parties[party.Id] = party
	partyOf[leader] = party
	return party
end

-- Deshace un grupo armado por la cola: los otros vuelven a la cola (sin perder su lugar)
local function breakGroup(party: Party)
	local group = party.Group
	if not group then
		return
	end
	for _, g in group do
		g.Group = nil
		g.Pending = nil
		if g ~= party and parties[g.Id] and not g.Launching then
			g.CountdownEnd = 0
			table.clear(g.Ready)
			g.Queued = true
			publishLater(g)
		end
	end
end

-- Cambió algo del grupo: nadie queda listo, sin cuenta ni cola
local function resetReady(party: Party)
	breakGroup(party)
	table.clear(party.Ready)
	table.clear(party.Again)
	party.CountdownEnd = 0
	party.Queued = false
	party.Pending = nil
end

-- El capítulo tiene que servirle a todos: si no, vuelve al 1
local function ensureChapter(party: Party)
	if not ChapterUnlocks.partyCanPlay(party.Members, party.Chapter) then
		party.Chapter = Chapters[1].Id
	end
end

local function removeFromParty(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	breakGroup(party)
	local i = table.find(party.Members, player)
	if i then
		table.remove(party.Members, i)
	end
	party.Ready[player] = nil
	party.Again[player] = nil
	if #party.Members == 0 then
		parties[party.Id] = nil
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	party.CountdownEnd = 0
	publish(party)
end

local function soloParty(player: Player, chapter: string?)
	removeFromParty(player)
	local party = newParty(player, chapter)
	ensureChapter(party)
	publish(party)
	return party
end

---------------------------------------------------------------------
-- Salir a jugar
---------------------------------------------------------------------

local function launch(group: { Party })
	local players: { Player } = {}
	local chapter = group[1].Chapter
	for _, party in group do
		party.Launching = true
		party.CountdownEnd = 0
		for _, p in party.Members do
			if p.Parent then
				table.insert(players, p)
			end
		end
	end
	local function done(ok: boolean, message: string?)
		for _, party in group do
			party.Launching = false
			if ok then
				resetReady(party)
			else
				party.CountdownEnd = 0
			end
			if parties[party.Id] then
				publish(party)
			end
		end
		if not ok and message then
			for _, p in players do
				notify(p, message)
			end
		end
	end
	if #players == 0 then
		done(false, nil)
		return
	end
	if Places.canTeleport() then
		task.spawn(function()
			local ok = Teleporter.toArena(players, chapter)
			done(ok, if ok then nil else "No se pudo viajar a la arena. Probá de nuevo.")
		end)
	else
		local ok, why = MatchManager.startWith(players, chapter)
		if ok then
			done(true, nil)
		else
			-- Arena ocupada (partida local): quedan esperando y salen apenas se libere
			for _, party in group do
				party.Launching = false
				party.Pending = group
			end
			for _, p in players do
				notify(p, why or "No se pudo empezar.")
			end
		end
	end
end

local function allReady(party: Party): boolean
	if #party.Members == 0 then
		return false
	end
	for _, p in party.Members do
		if not party.Ready[p] then
			return false
		end
	end
	return true
end

local function refreshCountdown(party: Party)
	if party.Launching or party.Queued then
		return
	end
	if allReady(party) then
		if party.CountdownEnd == 0 then
			local quick = true
			for _, p in party.Members do
				if not party.Again[p] then
					quick = false
				end
			end
			party.CountdownEnd = serverNow() + (if quick then MatchCfg.AgainCountdownTime else MatchCfg.CountdownTime)
		end
	else
		party.CountdownEnd = 0
	end
	publish(party)
end

-- Cola rápida: arma grupos por capítulo, de los que más esperan primero
local function matchmake()
	local byChapter: { [string]: { Party } } = {}
	for _, party in parties do
		if party.Queued and not party.Launching and party.CountdownEnd == 0 then
			byChapter[party.Chapter] = byChapter[party.Chapter] or {}
			table.insert(byChapter[party.Chapter], party)
		end
	end
	for _, list in byChapter do
		table.sort(list, function(a, b)
			return a.QueueSince < b.QueueSince
		end)
		local group: { Party } = {}
		local count = 0
		for _, party in list do
			if count + #party.Members <= MatchCfg.MaxPartySize then
				table.insert(group, party)
				count += #party.Members
			end
		end
		if #group == 0 then
			continue
		end
		local waited = serverNow() - group[1].QueueSince
		if count >= MatchCfg.MaxPartySize or waited >= PlaceCfg.QueueMaxWait then
			-- Grupo armado: todos listos, cuenta corta y salen juntos (cada grupo sigue siendo el suyo)
			local startAt = serverNow() + PlaceCfg.QueueStartDelay
			for _, party in group do
				party.Queued = false
				party.CountdownEnd = startAt
				party.Pending = nil
				party.Group = group
				for _, p in party.Members do
					party.Ready[p] = true
				end
				publish(party)
				for _, p in party.Members do
					notify(p, string.format("¡Grupo armado (%d/%d)! Salen en %d s.", count, MatchCfg.MaxPartySize, PlaceCfg.QueueStartDelay))
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Pedidos
---------------------------------------------------------------------

local function canAct(player: Player): boolean
	local s = PlayerData.get(player)
	return s ~= nil and not s.inMatch and player:GetAttribute("Traveling") == nil
end

local function handle(player: Player, action: any, arg: any)
	if typeof(action) ~= "string" then
		return
	end
	local t = os.clock()
	if t - (lastRequest[player] or -math.huge) < MatchCfg.RequestCooldown then
		return
	end
	lastRequest[player] = t
	local party = partyOf[player]
	if not party or not canAct(player) then
		return
	end
	if party.Launching then
		return
	end

	if action == "SetReady" then
		if typeof(arg) ~= "boolean" or party.Queued then
			return
		end
		if arg and not Profiles.isLoaded(player) then
			notify(player, "Cargando tu perfil… probá en un segundo.")
			return
		end
		if arg and not ChapterUnlocks.isUnlocked(player, party.Chapter) then
			notify(player, "Todavía no desbloqueaste ese capítulo.")
			return
		end
		party.Ready[player] = if arg then true else nil
		if not arg then
			party.Again[player] = nil
			breakGroup(party)
			party.Pending = nil
		end
		refreshCountdown(party)
	elseif action == "SelectChapter" then
		if typeof(arg) ~= "string" or #arg > 32 or not isChapter(arg) then
			return
		end
		if party.Leader ~= player then
			notify(player, "Solo el líder del grupo elige el capítulo.")
			return
		end
		if not ChapterUnlocks.partyCanPlay(party.Members, arg) then
			notify(player, "Ese capítulo está bloqueado para alguien del grupo.")
			return
		end
		if arg ~= party.Chapter then
			party.Chapter = arg
			resetReady(party)
			publish(party)
		end
	elseif action == "Queue" then
		if typeof(arg) ~= "boolean" then
			return
		end
		if party.Leader ~= player then
			notify(player, "Solo el líder del grupo busca partida.")
			return
		end
		if arg then
			if #party.Members >= MatchCfg.MaxPartySize then
				notify(player, "Tu grupo ya está completo: apretá JUGAR.")
				return
			end
			for _, p in party.Members do
				if not Profiles.isLoaded(p) then
					notify(player, "Esperá a que cargue el perfil de todos.")
					return
				end
			end
			if not ChapterUnlocks.partyCanPlay(party.Members, party.Chapter) then
				notify(player, "Ese capítulo está bloqueado para alguien del grupo.")
				return
			end
			table.clear(party.Ready)
			party.CountdownEnd = 0
			party.Queued = true
			party.QueueSince = serverNow()
		else
			party.Queued = false
		end
		publish(party)
	elseif action == "Invite" then
		if typeof(arg) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(arg)
		if not target or target == player or partyOf[target] == party then
			return
		end
		if #party.Members >= MatchCfg.MaxPartySize then
			notify(player, "Tu grupo está completo.")
			return
		end
		if not canAct(target) then
			notify(player, target.DisplayName .. " está jugando una partida.")
			return
		end
		invites[target] = invites[target] or {}
		invites[target][party.Id] = { from = player, expires = serverNow() + PlaceCfg.InviteTime }
		Remotes.PartyInvite:FireClient(target, {
			PartyId = party.Id,
			From = player.DisplayName,
			FromId = player.UserId,
			Chapter = party.Chapter,
			Size = #party.Members,
			Expires = serverNow() + PlaceCfg.InviteTime,
		})
		notify(player, "Invitaste a " .. target.DisplayName .. ".")
	elseif action == "AcceptInvite" or action == "DeclineInvite" then
		if typeof(arg) ~= "string" then
			return
		end
		local mine = invites[player]
		local invite = mine and mine[arg]
		if not invite then
			return
		end
		mine[arg] = nil
		local target = parties[arg]
		if action == "DeclineInvite" then
			if invite.from.Parent then
				notify(invite.from, player.DisplayName .. " rechazó la invitación.")
			end
			return
		end
		if invite.expires < serverNow() or not target then
			notify(player, "La invitación venció.")
			return
		end
		if #target.Members >= MatchCfg.MaxPartySize or target.Launching then
			notify(player, "Ese grupo ya está completo o saliendo.")
			return
		end
		removeFromParty(player)
		table.insert(target.Members, player)
		partyOf[player] = target
		resetReady(target)
		ensureChapter(target)
		publish(target)
		for _, p in target.Members do
			notify(p, player.DisplayName .. " se sumó al grupo.")
		end
	elseif action == "LeaveParty" then
		if #party.Members <= 1 then
			return
		end
		local others = party.Members
		soloParty(player, party.Chapter)
		for _, p in others do
			if p ~= player then
				notify(p, player.DisplayName .. " dejó el grupo.")
			end
		end
	elseif action == "Kick" then
		if typeof(arg) ~= "number" or party.Leader ~= player then
			return
		end
		local target = Players:GetPlayerByUserId(arg)
		if not target or partyOf[target] ~= party or target == player then
			return
		end
		soloParty(target, party.Chapter)
		notify(target, "El líder te sacó del grupo.")
		resetReady(party)
		publish(party)
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

function PartyService.init()
	if Places.role() ~= "Lobby" then
		return
	end
	Remotes.LobbyRequest.OnServerEvent:Connect(handle)
	-- Volvieron de una partida local: los de OTRA quedan listos (cuenta corta)
	MatchManager.onReturned(function(again: { Player })
		for _, p in again do
			local party = partyOf[p]
			if party and canAct(p) and ChapterUnlocks.isUnlocked(p, party.Chapter) then
				party.Ready[p] = true
				party.Again[p] = true
			end
		end
		for _, party in parties do
			refreshCountdown(party)
		end
	end)
end

function PartyService.onPlayerAdded(player: Player)
	if Places.role() ~= "Lobby" then
		return
	end
	soloParty(player, nil)
end

function PartyService.onProfileLoaded(player: Player)
	local party = partyOf[player]
	if party then
		ensureChapter(party)
		publish(party)
	end
end

function PartyService.onPlayerRemoving(player: Player)
	local party = partyOf[player]
	invites[player] = nil
	lastRequest[player] = nil
	if not party then
		return
	end
	local others = {}
	for _, p in party.Members do
		if p ~= player then
			table.insert(others, p)
		end
	end
	removeFromParty(player)
	if parties[party.Id] and not party.Launching then
		-- Se fue alguien (y no por el viaje): nadie queda listo
		if player:GetAttribute("Traveling") == nil then
			resetReady(party)
			publish(party)
			for _, p in others do
				notify(p, player.DisplayName .. " se fue.")
			end
		end
	end
end

-- Un frame del servidor: cuentas regresivas, cola y grupos esperando la arena
function PartyService.update(dt: number)
	if Places.role() ~= "Lobby" then
		return
	end
	tickAccum += dt
	if tickAccum < 0.25 then
		return
	end
	tickAccum = 0
	local t = serverNow()
	local launched: { [Party]: boolean } = {}
	for _, party in parties do
		if launched[party] or party.Launching then
			continue
		end
		if party.Pending then
			-- Esperando que se libere la arena (partida local)
			if MatchManager.isFree() then
				local group = party.Pending :: { Party }
				for _, g in group do
					launched[g] = true
					g.Pending = nil
					g.Group = nil
				end
				launch(group)
			end
		elseif party.CountdownEnd > 0 and t >= party.CountdownEnd then
			local group = party.Group or { party }
			for _, g in group do
				launched[g] = true
				g.Group = nil
			end
			launch(group)
		end
	end
	matchmake()
end

-- Para pruebas
function PartyService.partyOf(player: Player): Party?
	return partyOf[player]
end

PartyService._handle = handle

return PartyService
