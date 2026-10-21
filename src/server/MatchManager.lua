--!strict
-- MatchManager (ModuleScript)
-- Ubicación: ServerScriptService > Server > MatchManager
-- Ciclo de partida del servidor (una partida por servidor). Es el ÚNICO que cambia de estado:
--
--   LOBBY ──alguien listo──> PREPARING ──todos listos──> STARTING (cuenta regresiva)
--     ^                        ^   │                         │  alguien cancela / entra uno nuevo
--     │                        └───┴─────────────────────────┘
--     │                                                      │ termina la cuenta
--     │                                                      v
--   RETURNING <──tiempo o todos votan── RESULTS <──victoria/derrota── PLAYING
--     (también PLAYING ──se fueron todos──> RETURNING)
--
-- Botón OTRA (acción "PlayAgain" en RESULTS): cuenta como voto para volver y, al llegar al
-- lobby, el jugador queda listo solo con el mismo capítulo. Si todos los listos vienen de OTRA,
-- la cuenta regresiva es la corta (Config.Match.AgainCountdownTime).
--
-- Los clientes solo PIDEN cosas por Remotes.LobbyRequest (listo, elegir capítulo, volver);
-- el servidor valida tipo, estado, permisos y frecuencia, y publica el resultado en
-- atributos (GameState y cada Player) que los clientes leen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local ChapterUnlocks = require(script.Parent.ChapterUnlocks)
local Profiles = require(script.Parent.Profiles)
local Rewards = require(script.Parent.Rewards)
local Runes = require(script.Parent.Runes)
local Run = require(script.Parent.Run)
local RunLog = require(script.Parent.RunLog)
local MissionService = require(script.Parent.MissionService)

local MatchCfg = Config.Match

export type MatchState = "LOBBY" | "PREPARING" | "STARTING" | "PLAYING" | "RESULTS" | "RETURNING"

local MatchManager = {}

local gameState = Remotes.GameState
local state: MatchState = "LOBBY"
local stateSince = 0 -- os.clock() al entrar al estado actual
local readyAt: { [Player]: number } = {} -- quién está listo y desde cuándo (orden de llegada)
local joinOrder: { Player } = {} -- para elegir líder: el que más tiempo lleva en el lobby
local lastRequest: { [Player]: number } = {}
local returnVotes: { [Player]: boolean } = {}
local againVotes: { [Player]: boolean } = {} -- apretaron OTRA en los resultados
local againReady: { [Player]: boolean } = {} -- quedaron listos solos por OTRA
local selectedChapter: string = Chapters[1].Id
local leader: Player? = nil
local matchesStarted = 0 -- para las pruebas: cuántas partidas arrancaron

local function now(): number
	return os.clock()
end

local function setState(newState: MatchState)
	state = newState
	stateSince = now()
	gameState:SetAttribute("MatchState", newState)
end

local function notify(player: Player, message: string)
	Remotes.LobbyNotice:FireClient(player, message)
end

-- Jugadores que están en el lobby (no participan de una partida en curso)
local function lobbyPlayers(): { Player }
	local list = {}
	for _, p in joinOrder do
		local s = PlayerData.get(p)
		if s and not s.inMatch then
			table.insert(list, p)
		end
	end
	return list
end

local function readyCount(): number
	local n = 0
	for _ in readyAt do
		n += 1
	end
	return n
end

local function setReady(player: Player, value: boolean)
	if value then
		readyAt[player] = readyAt[player] or now()
	else
		readyAt[player] = nil
		againReady[player] = nil
	end
	player:SetAttribute("Ready", value)
end

local function clearAllReady()
	for p in readyAt do
		p:SetAttribute("Ready", false)
	end
	table.clear(readyAt)
	table.clear(againReady)
end

local function updateLeader()
	local candidates = lobbyPlayers()
	local newLeader = candidates[1] or joinOrder[1]
	if newLeader ~= leader then
		leader = newLeader
	end
	gameState:SetAttribute("LeaderId", if leader then leader.UserId else 0)
end

local function chapterById(id: string): (any, number?)
	for i, ch in Chapters do
		if ch.Id == id then
			return ch, i
		end
	end
	return nil, nil
end

local function setChapter(id: string)
	selectedChapter = id
	gameState:SetAttribute("SelectedChapter", id)
end

-- Si el capítulo elegido dejó de servirle al grupo (entró alguien que no lo tiene), vuelve al 1.
local function ensurePlayableChapter()
	local group = lobbyPlayers()
	if #group > 0 and not ChapterUnlocks.partyCanPlay(group, selectedChapter) then
		setChapter(Chapters[1].Id)
	end
end

---------------------------------------------------------------------
-- Transiciones
---------------------------------------------------------------------

-- Recalcula LOBBY / PREPARING / STARTING según quién está listo.
local function refreshPreparation()
	if state ~= "LOBBY" and state ~= "PREPARING" and state ~= "STARTING" then
		return
	end
	local group = lobbyPlayers()
	local ready = readyCount()
	local allReady = ready > 0 and (ready == #group or ready >= MatchCfg.MaxPartySize)

	if ready == 0 then
		if state ~= "LOBBY" then
			setState("LOBBY")
		end
	elseif allReady then
		if state ~= "STARTING" then
			setState("STARTING")
			-- Todos vienen de OTRA: cuenta corta
			local quick = true
			for p in readyAt do
				if not againReady[p] then
					quick = false
				end
			end
			local countdown = if quick then MatchCfg.AgainCountdownTime or MatchCfg.CountdownTime else MatchCfg.CountdownTime
			gameState:SetAttribute("CountdownEnd", workspace:GetServerTimeNow() + countdown)
		end
	elseif state ~= "PREPARING" then
		-- Si estaba en cuenta regresiva y alguien canceló o entró uno nuevo, se cancela
		setState("PREPARING")
	end
	if state ~= "STARTING" then
		gameState:SetAttribute("CountdownEnd", 0)
	end
end

local function startMatch()
	-- Guardas contra partidas duplicadas: solo desde STARTING y una sola vez
	if state ~= "STARTING" or Run.isActive() then
		return
	end
	-- Participantes: los listos, por orden de llegada, hasta el máximo
	local ordered = {}
	for p, t in readyAt do
		if p.Parent then
			table.insert(ordered, { player = p, t = t })
		end
	end
	table.sort(ordered, function(a, b)
		return a.t < b.t
	end)
	local participants = {}
	for i = 1, math.min(#ordered, MatchCfg.MaxPartySize) do
		table.insert(participants, ordered[i].player)
	end
	if #participants == 0 then
		setState("LOBBY")
		return
	end

	local _, index = chapterById(selectedChapter)
	if not index or not ChapterUnlocks.partyCanPlay(participants, selectedChapter) then
		for _, p in participants do
			notify(p, "Ese capítulo no está disponible para todo el equipo.")
		end
		setChapter(Chapters[1].Id)
		clearAllReady()
		setState("LOBBY")
		return
	end

	clearAllReady()
	table.clear(returnVotes)
	matchesStarted += 1
	setState("PLAYING")
	gameState:SetAttribute("CountdownEnd", 0)
	Run.start(index, participants)
end

local function enterResults(result: Run.Result)
	Run.finish(result)
	local summary = Run.summary(result)
	local chapter = chapterById(selectedChapter)
	setState("RESULTS")
	gameState:SetAttribute("ResultsEnd", workspace:GetServerTimeNow() + MatchCfg.ResultsTime)
	for _, p in PlayerLife.participants() do
		-- Recompensas de cada uno (las calcula el servidor con lo que pasó en la partida)
		local personal = table.clone(summary) :: any
		local stats = PlayerData.get(p)
		local granted = chapter
			and Rewards.grant(p, chapter, {
				result = result,
				wavesCleared = summary.wavesCleared,
				bossesKilled = summary.bossesKilled,
				kills = if stats then stats.kills else 0,
			})
		personal.rewards = if granted then granted.amounts else nil -- nil: perfil sin cargar
		personal.firstClear = granted ~= nil and granted.firstClear
		personal.accountXP = if granted then granted.accountXP else 0 -- XP de cuenta (árbol de talentos)
		personal.levelsGained = if granted then granted.levelsGained else 0
		personal.bestWaveBefore = if granted then granted.bestWaveBefore else 0
		personal.newRecord = granted ~= nil and granted.newRecord
		personal.account = if granted then granted.account else nil -- barra "te faltan X"
		personal.loot = if stats then table.clone(stats.runLoot) else {} -- botín juntado (ya cobrado)
		if result == "Victory" then
			ChapterUnlocks.onChapterCleared(p, selectedChapter)
		end
		if personal.firstClear then
			Runes.onFirstClear(p) -- runa garantizada (y quizás un espacio activo nuevo)
		end
		ChapterUnlocks.publish(p) -- récords nuevos para el lobby
		-- Misiones diarias y semanales (con números del servidor)
		if stats then
			MissionService.onRunEnded(p, {
				kills = stats.kills,
				weapon = stats.stats.weapon,
				wavesCleared = summary.wavesCleared,
				bosses = #summary.bossesKilled,
				victory = result == "Victory",
				finished = result ~= "Abandoned",
				chests = stats.chests,
				gold = stats.runLoot.Gold or 0,
			})
		end
		Profiles.saveSoon(p) -- guardar ya: no esperar al guardado automático
		Remotes.RunEnded:FireClient(p, personal)
		RunLog.record(RunLog.entry(p, summary, personal, stats)) -- para balancear (Config.RunLog)
	end
	RunLog.flush()
end

-- Al llegar al lobby: los que apretaron OTRA quedan listos solos (si pueden jugar ese capítulo)
local function applyAgainVotes()
	for p in againVotes do
		local s = PlayerData.get(p)
		if p.Parent and s and not s.inMatch and Profiles.isLoaded(p)
			and ChapterUnlocks.isUnlocked(p, selectedChapter) and readyCount() < MatchCfg.MaxPartySize then
			setReady(p, true)
			againReady[p] = true
		end
	end
	table.clear(againVotes)
end

local function enterReturning()
	setState("RETURNING")
	gameState:SetAttribute("ResultsEnd", 0)
	table.clear(returnVotes)
	Run.cleanup() -- arena vacía y participantes de vuelta en el lobby
end

---------------------------------------------------------------------
-- Peticiones de los clientes
---------------------------------------------------------------------

local function allVotedReturn(): boolean
	local participants = PlayerLife.participants()
	if #participants == 0 then
		return true
	end
	for _, p in participants do
		if not returnVotes[p] then
			return false
		end
	end
	return true
end

local function handleRequest(player: Player, action: any, arg: any)
	-- Tipo y frecuencia: un cliente no puede inundar al servidor
	if typeof(action) ~= "string" then
		return
	end
	local t = now()
	if t - (lastRequest[player] or -math.huge) < MatchCfg.RequestCooldown then
		return
	end
	lastRequest[player] = t
	local s = PlayerData.get(player)
	if not s then
		return
	end

	if action == "SetReady" then
		if typeof(arg) ~= "boolean" then
			return
		end
		if s.inMatch or (state ~= "LOBBY" and state ~= "PREPARING" and state ~= "STARTING") then
			notify(player, "Hay una partida en curso. Vas a poder sumarte a la siguiente.")
			return
		end
		if arg and not readyAt[player] and readyCount() >= MatchCfg.MaxPartySize then
			notify(player, "El equipo ya está completo.")
			return
		end
		if arg and not Profiles.isLoaded(player) then
			notify(player, "Cargando tu perfil… probá en un segundo.")
			return
		end
		if arg and not ChapterUnlocks.isUnlocked(player, selectedChapter) then
			notify(player, "Todavía no desbloqueaste ese capítulo.")
			return
		end
		setReady(player, arg)
		refreshPreparation()
	elseif action == "SelectChapter" then
		if typeof(arg) ~= "string" or #arg > 32 then
			return
		end
		if state ~= "LOBBY" and state ~= "PREPARING" and state ~= "STARTING" then
			return
		end
		if player ~= leader then
			notify(player, "Solo el líder del equipo elige el capítulo.")
			return
		end
		if not chapterById(arg) then
			return
		end
		if not ChapterUnlocks.partyCanPlay(lobbyPlayers(), arg) then
			notify(player, "Ese capítulo está bloqueado para alguien del equipo.")
			return
		end
		if arg ~= selectedChapter then
			setChapter(arg)
			-- Cambió el destino: todos confirman de nuevo
			clearAllReady()
			refreshPreparation()
		end
	elseif action == "ReturnToLobby" or action == "PlayAgain" then
		if state ~= "RESULTS" or not s.inMatch then
			return
		end
		if now() - stateSince < MatchCfg.MinResultsTime then
			return
		end
		if action == "PlayAgain" then
			againVotes[player] = true
		end
		returnVotes[player] = true
		if allVotedReturn() then
			enterReturning()
		end
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

function MatchManager.init()
	setState("LOBBY")
	setChapter(selectedChapter)
	gameState:SetAttribute("CountdownEnd", 0)
	gameState:SetAttribute("ResultsEnd", 0)
	gameState:SetAttribute("LeaderId", 0)
	Remotes.LobbyRequest.OnServerEvent:Connect(handleRequest)
end

function MatchManager.onPlayerAdded(player: Player)
	table.insert(joinOrder, player)
	ChapterUnlocks.onPlayerAdded(player)
	player:SetAttribute("Ready", false)
	updateLeader()
	ensurePlayableChapter()
	-- Un jugador nuevo sin "listo" cancela una cuenta regresiva en curso
	refreshPreparation()
end

-- Su perfil terminó de cargar: ya puede tener más capítulos desbloqueados.
function MatchManager.onProfileLoaded(player: Player)
	ChapterUnlocks.refresh(player)
	ensurePlayableChapter()
end

function MatchManager.onPlayerRemoving(player: Player)
	-- En resultados, irse cuenta como voto para volver (así no se traba la espera)
	if state == "RESULTS" then
		returnVotes[player] = true
		if allVotedReturn() then
			enterReturning()
		end
	end
	readyAt[player] = nil
	returnVotes[player] = nil
	againVotes[player] = nil
	againReady[player] = nil
	lastRequest[player] = nil
	local i = table.find(joinOrder, player)
	if i then
		table.remove(joinOrder, i)
	end
	ChapterUnlocks.onPlayerRemoving(player)
	updateLeader()
	-- Si se fue alguien durante la cuenta, sigue si los que quedan están todos listos
	refreshPreparation()
end

-- Un frame del servidor.
function MatchManager.update(dt: number)
	if state == "STARTING" then
		local countdownEnd = gameState:GetAttribute("CountdownEnd") :: number?
		if countdownEnd and workspace:GetServerTimeNow() >= countdownEnd then
			startMatch()
		end
	elseif state == "PLAYING" then
		local result: Run.Result? = Run.step(dt)
		if result == "Abandoned" then
			Run.finish("Abandoned")
			enterReturning()
		elseif result == "Victory" or result == "Defeat" then
			enterResults(result)
		end
	elseif state == "RESULTS" then
		Run.frozenStep(dt)
		local resultsEnd = gameState:GetAttribute("ResultsEnd") :: number?
		if resultsEnd and workspace:GetServerTimeNow() >= resultsEnd then
			enterReturning()
		end
	elseif state == "RETURNING" then
		if now() - stateSince >= MatchCfg.ReturnDelay then
			setState("LOBBY")
			updateLeader()
			ensurePlayableChapter()
			applyAgainVotes() -- OTRA: listos solos
			refreshPreparation()
		end
	end
end

-- Para pruebas y diagnóstico
function MatchManager.getState(): MatchState
	return state
end

function MatchManager.matchesStarted(): number
	return matchesStarted
end

function MatchManager.leader(): Player?
	return leader
end

-- Para pruebas: intenta arrancar la partida directamente (debe ignorarse fuera de STARTING).
MatchManager._forceStart = startMatch

return MatchManager
