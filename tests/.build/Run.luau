local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- Run (ModuleScript)
-- Ubicación: ServerScriptService > Server > Run
-- Una partida (corrida) en la arena: la prepara, la hace avanzar frame a frame y la limpia.
-- Reutiliza el motor de combate tal como estaba (Waves, Enemies, Combat, Hazards, Boss,
-- Progression, PlayerLife). Quién juega y cuándo empieza lo decide MatchManager.

local Remotes = require("./Remotes")
local Arena = require("./Arena")
local PlayerData = require("./PlayerData")
local PlayerLife = require("./PlayerLife")
local Enemies = require("./Enemies")
local Combat = require("./Combat")
local Hazards = require("./Hazards")
local Boss = require("./Boss")
local Progression = require("./Progression")
local Waves = require("./Waves")

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

local chapterIndex = 1
local result: Result? = nil
local lastPhase = "Waiting"
local active = false

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
	Arena.setTheme(ch.Floor, ch.Wall)
	-- Cada uno en su punto de la arena, con vida, XP y habilidades de partida en cero
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

	-- Al empezar el descanso: se levantan los derribados y vuelven los eliminados.
	if phase == "Break" and lastPhase ~= "Break" then
		PlayerLife.onBreak(Arena.spawnPoints(1)[1])
	end
	lastPhase = phase

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
function Run.cleanup()
	active = false
	result = nil
	clearWorld()
	PlayerLife.endMatch()
	Remotes.RunReset:FireAllClients()
end

return Run
