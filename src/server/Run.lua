-- Run (ModuleScript)
-- Ubicación: ServerScriptService > Server > Run
-- Una partida (corrida) en la arena: la prepara, la hace avanzar frame a frame y la limpia.
-- Reutiliza el motor de combate tal como estaba (Waves, Enemies, Combat, Hazards, Boss,
-- Progression, PlayerLife). Quién juega y cuándo empieza lo decide MatchManager.

local Remotes = require(script.Parent.Remotes)
local Arena = require(script.Parent.Arena)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local Enemies = require(script.Parent.Enemies)
local Combat = require(script.Parent.Combat)
local Hazards = require(script.Parent.Hazards)
local Boss = require(script.Parent.Boss)
local Progression = require(script.Parent.Progression)
local Waves = require(script.Parent.Waves)

export type Result = "Victory" | "Defeat" | "Abandoned"

export type PlayerSummary = { name: string, kills: number, damage: number, revives: number, downs: number }

export type Summary = {
	result: string,
	chapter: number,
	chapterName: string,
	nextText: string,
	wave: number,
	totalWaves: number,
	level: number,
	time: number,
	partySize: number,
	players: { PlayerSummary },
}

local Run = {}

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local RoomCfg = Config.Rooms

local chapterIndex = 1
local result: Result? = nil
local lastPhase = "Waiting"
local active = false

-- Salas y puerta (entre oleadas, con Config.Waves.UseDoors)
local roomIndex = 1
local doorOpenedAt = 0
local enteringUntil: number? = nil -- mientras llega a la sala nueva, la oleada todavía no arranca

-- Arma el motor de combate (una sola vez, al arrancar el servidor).
function Run.init()
	Arena.build()
	Hazards.init()
	Combat.init(Remotes, Arena.Half)
	Enemies.init(Arena.Half, Combat, Hazards)
	Boss.init(Remotes.GameState)
	Progression.init(Remotes, Remotes.GameState)

	-- Cada golpe suma a las estadísticas del jugador; cada muerte, XP al equipo.
	Enemies.onDamaged(function(enemy, attacker, dealt, killed)
		local state = attacker and PlayerData.get(attacker)
		if state then
			state.damageDealt += dealt
			if killed then
				state.kills += 1
			end
		end
		if killed then
			Progression.addXP(enemy.xp)
		end
	end)

	Waves.init(Remotes.GameState, function()
		result = "Victory"
	end, PlayerLife.partySize, function(_partySize, scale)
		Progression.setXPScale(scale.XP)
	end)
	Waves.setChapter(1)
end

-- Deja la arena vacía y todo en cero (sirve antes de empezar y al terminar).
local function clearWorld()
	Enemies.clear()
	Hazards.clear()
	Combat.clear()
	Boss.update()
	Waves.reset()
	Progression.reset()
	PlayerData.resetStats()
end

-- Empieza una partida en el capítulo `index` con estos participantes.
function Run.start(index: number, participants: { Player })
	clearWorld()
	chapterIndex = index
	result = nil
	lastPhase = "Waiting"
	active = true
	Waves.setChapter(chapterIndex)
	local ch = Waves.chapterInfo(chapterIndex)
	roomIndex = 1
	enteringUntil = nil
	Arena.closeDoor()
	Arena.buildRoom(ch, roomIndex)
	Remotes.GameState:SetAttribute("RoomIndex", roomIndex)
	-- Cada uno en su punto de la entrada, con vida, XP y habilidades de partida en cero
	PlayerLife.beginMatch(participants, Arena.spawnPoints(#participants))
end

function Run.isActive(): boolean
	return active
end

function Run.chapterIndex(): number
	return chapterIndex
end

-- Un frame de partida. Devuelve el resultado cuando termina (y nil mientras sigue).
function Run.step(dt: number): Result?
	if not active then
		return nil
	end
	if #PlayerLife.participants() == 0 then
		return "Abandoned" -- se fueron todos los participantes
	end
	if result then
		return result
	end

	local now = os.clock()
	local targets = PlayerData.getAliveTargets()
	local phase = Waves.phase()

	-- Derrota: nadie queda en pie (los derribados no pueden rescatarse entre sí).
	if phase == "Wave" and PlayerLife.noneActive() then
		result = "Defeat"
		return result
	end

	-- Al empezar el descanso: se levantan los derribados, vuelven los eliminados y se abre la puerta.
	if phase == "Break" and lastPhase ~= "Break" then
		PlayerLife.onBreak(Arena.spawnPoints(1)[1])
		if Config.Waves.UseDoors then
			Arena.openDoor()
			doorOpenedAt = now
			Remotes.GameState:SetAttribute("DoorEnd", workspace:GetServerTimeNow() + RoomCfg.DoorTimeout)
		end
	end
	lastPhase = phase
	if phase == "Break" and Config.Waves.UseDoors then
		Run.updateDoor(now, targets)
	end

	Progression.update(now)
	local frozen = Progression.allChoosing(targets)
	if not frozen then
		PlayerLife.update(dt)
	end
	Waves.update(dt, targets, frozen)
	Enemies.update(dt, targets, now, frozen)
	Combat.update(dt, targets, now, frozen)
	if not frozen then
		Hazards.update(dt, targets)
	end
	Boss.update()
	return result
end

-- Durante los resultados: el combate está detenido, solo terminan los proyectiles en vuelo.
function Run.frozenStep(dt: number)
	Combat.update(dt, PlayerData.getAliveTargets(), os.clock(), true)
end

-- Fija el resultado y detiene las oleadas.
function Run.finish(final: Result)
	result = final
	if final ~= "Abandoned" then
		Waves.finish(final)
	end
end

function Run.summary(final: Result): Summary
	local players = {}
	for _, player in PlayerLife.participants() do
		local state = PlayerData.get(player)
		if state then
			table.insert(players, {
				name = player.DisplayName,
				kills = state.kills,
				damage = math.floor(state.damageDealt),
				revives = state.revives,
				downs = state.downs,
			})
		end
	end
	table.sort(players, function(a, b)
		return a.damage > b.damage
	end)

	local ch = Waves.chapterInfo(chapterIndex)
	local nextText
	if final == "Victory" then
		local nextInfo = Waves.chapterInfo(chapterIndex + 1)
		nextText = if nextInfo
			then string.format("¡Desbloqueaste el Capítulo %d · %s!", chapterIndex + 1, nextInfo.Name)
			else "¡Completaste todos los capítulos!"
	else
		nextText = "Preparate y volvé a intentarlo desde el lobby"
	end

	return {
		result = final,
		chapter = chapterIndex,
		chapterName = ch.Name,
		nextText = nextText,
		wave = Waves.current(),
		totalWaves = ch.Waves,
		level = Progression.level(),
		time = math.floor(Waves.elapsed()),
		partySize = PlayerLife.partySize(),
		players = players,
	}
end

-- Termina todo: arena limpia y participantes de vuelta al lobby.
-- Puerta abierta: espera a que entren todos los que están en pie (o a que se acabe el tiempo)
-- y después lleva al equipo a la sala siguiente.
function Run.updateDoor(now: number, targets)
	if enteringUntil then
		if now >= enteringUntil then
			enteringUntil = nil
			Waves.nextWave(targets)
		end
		return
	end
	local inside = 0
	for _, t in targets do
		if Arena.inDoorZone(t.root.Position) then
			inside += 1
		end
	end
	Remotes.GameState:SetAttribute("DoorInside", inside)
	Remotes.GameState:SetAttribute("DoorNeeded", #targets)
	local everyone = #targets > 0 and inside == #targets
	if everyone or now - doorOpenedAt >= RoomCfg.DoorTimeout then
		-- A la sala siguiente: nueva decoración y todos en la entrada
		Arena.closeDoor()
		Combat.clear()
		Hazards.clear()
		roomIndex += 1
		Arena.buildRoom(Waves.chapterInfo(chapterIndex), roomIndex)
		Remotes.GameState:SetAttribute("RoomIndex", roomIndex)
		Remotes.GameState:SetAttribute("DoorEnd", 0)
		local points = Arena.spawnPoints(#targets)
		for i, t in targets do
			local character = t.player.Character
			if character then
				character:PivotTo(points[i])
			end
		end
		enteringUntil = now + RoomCfg.EnterDelay
	end
end

function Run.roomIndex(): number
	return roomIndex
end

function Run.cleanup()
	active = false
	result = nil
	enteringUntil = nil
	Arena.closeDoor()
	Remotes.GameState:SetAttribute("DoorEnd", 0)
	clearWorld()
	PlayerLife.endMatch()
	Remotes.RunReset:FireAllClients()
end

return Run
