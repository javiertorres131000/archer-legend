-- WaveEvents (ModuleScript)
-- Ubicación: ServerScriptService > Server > WaveEvents
-- Lo que pasa DENTRO de una oleada además de los enemigos normales (números en Config.Events):
--
--   · Élites: algunos enemigos comunes de la oleada salen potenciados con un rasgo (Veloz,
--     Blindado, Furioso, Gigante). Al morir sueltan un cofre (Chests.dropAt).
--   · Momento horda: a mitad de algunas oleadas, una avalancha de enemigos débiles desde todos
--     lados. Mientras queden, la oleada no termina. Superarla da premio al equipo.
--   · Metas de equipo: una por oleada, compartida. "Maten N en T s", "Maten al élite marcado",
--     "Abran N cofres", "Nadie cae". Cumplirla da premio al equipo; si no, no pasa nada.
--
-- Waves la llama al empezar cada oleada (onWaveStart), en cada aparición (takeElite), cada frame
-- de oleada (update) y al terminar (onWaveEnd). Run le avisa las muertes y los cofres abiertos,
-- y entrega los premios (hooks de init).
--
-- El cliente (EventsHud, Sfx) lee atributos de GameState:
--   HordeState ""|"incoming"|"active"|"cleared" · HordeLeft
--   GoalState ""|"active"|"done"|"failed" · GoalId · GoalText · GoalProgress · GoalTarget · GoalTimeLeft
--   EliteAnnounce "rasgo|enemigo|n" (cambia con cada élite que aparece)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EnemyTypes = require(script.Parent.Data.EnemyTypes)
local Enemies = require(script.Parent.Enemies)
local Chests = require(script.Parent.Chests)
local PlayerData = require(script.Parent.PlayerData)

local Cfg = Config.Events

export type WaveInfo = {
	wave: number, -- oleada (o piso)
	localWave: number, -- oleada dentro del capítulo (torre: dentro del tramo)
	chapter: any,
	queueSize: number,
	countScale: number, -- escalado de cantidad por jugadores
	bossWave: boolean,
	healthMult: number,
	dmgMult: number,
}
export type Goal = {
	id: string,
	text: string,
	progress: number,
	target: number,
	timeLeft: number?, -- nil = hasta que termine la oleada
	state: string, -- "active" | "done" | "failed"
	enemy: any?, -- élite marcado (meta "Elite")
}
export type Hooks = {
	onHordeCleared: (pos: Vector3?) -> (),
	onGoalDone: (goal: Goal, pos: Vector3?) -> (),
}

local WaveEvents = {}

local gameState: Instance? = nil
local hooks: Hooks = { onHordeCleared = function() end, onGoalDone = function() end }

local info: WaveInfo? = nil
local elapsed = 0
-- Élites
local eliteAt: { number } = {} -- tamaños de la cola en los que sale un élite (de mayor a menor)
local eliteSerial = 0
-- Horda
local hordeAt: number? = nil -- segundos de oleada en que arranca (nil = esta oleada no hay)
local hordeState = ""
local hordeToSpawn = 0
local hordeTimer = 0
local hordeTypes: { string } = {}
local lastKillPos: Vector3? = nil
-- Meta de equipo
local goalAt: number? = nil
local goal: Goal? = nil
local lastGoalId: string? = nil
local downsAtStart = 0

local function set(name: string, value: any)
	if gameState then
		gameState:SetAttribute(name, value)
	end
end

local function publishGoal()
	local g = goal
	set("GoalState", if g then g.state else "")
	set("GoalId", if g then g.id else "")
	set("GoalText", if g then g.text else "")
	set("GoalProgress", if g then g.progress else 0)
	set("GoalTarget", if g then g.target else 0)
	set("GoalTimeLeft", if g and g.timeLeft then math.max(0, math.ceil(g.timeLeft)) else -1)
end

local function hordeAlive(): number
	local n = 0
	for _, e in Enemies.list do
		if e.alive and e.horde then
			n += 1
		end
	end
	return n
end

local function publishHorde()
	set("HordeState", hordeState)
	set("HordeLeft", hordeToSpawn + hordeAlive())
end

local function totalDowns(): number
	local n = 0
	for _, state in PlayerData.all() do
		if state.inMatch then
			n += state.downs or 0
		end
	end
	return n
end

local function randomAffix(): any
	local list = Cfg.Elite.Affixes
	return list[math.random(1, #list)]
end

local function announceElite(enemy: any)
	eliteSerial += 1
	set("EliteAnnounce", string.format("%s|%s|%d", enemy.eliteName or "", enemy.def.Name or enemy.typeId, eliteSerial))
end

-- Un tipo de la cola puede ser élite si es común (ni jefe ni élite de por sí)
local function canBeElite(typeId: string): boolean
	local def = EnemyTypes[typeId]
	return def ~= nil and not def.Boss and def.Role ~= "Elite"
end

-- Punto en un anillo alrededor de un jugador
local function ringPoint(targets: { PlayerData.Target }, angle: number, distance: number): Vector3?
	if #targets == 0 then
		return nil
	end
	local anchor = targets[math.random(1, #targets)].root.Position
	return anchor + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

function WaveEvents.init(state: Instance, newHooks: Hooks)
	gameState = state
	hooks = newHooks
	WaveEvents.reset()
end

function WaveEvents.reset()
	info = nil
	elapsed = 0
	table.clear(eliteAt)
	hordeAt, hordeState, hordeToSpawn, hordeTimer = nil, "", 0, 0
	table.clear(hordeTypes)
	goalAt, goal, lastGoalId = nil, nil, nil
	lastKillPos = nil
	publishHorde()
	publishGoal()
end

-- Cuántos élites tiene la oleada n (dentro del capítulo)
function WaveEvents.eliteCount(n: number): number
	local e = Cfg.Elite
	if n < e.FromWave then
		return 0
	end
	return math.min(e.Max, e.PerWave + n // e.ExtraEvery)
end

-- Tipos comunes que ya pueden salir en la oleada n, del más barato al más caro
local function availableTypes(chapter: any, n: number): { string }
	local list = {}
	for _, entry in chapter.Pool do
		local def = EnemyTypes[entry.Type]
		if def and not def.Boss and def.Role ~= "Elite" and entry.From <= n and (not entry.To or entry.To >= n) then
			table.insert(list, entry.Type)
		end
	end
	table.sort(list, function(a, b)
		local ca, cb = EnemyTypes[a].Cost or 1, EnemyTypes[b].Cost or 1
		return if ca == cb then a < b else ca < cb
	end)
	return list
end

-- Los dos tipos más baratos que ya pueden salir en la oleada n (para la horda)
function WaveEvents.hordeTypes(chapter: any, n: number): { string }
	local list = availableTypes(chapter, n)
	return { list[1], list[2] or list[1] }
end

function WaveEvents.onWaveStart(newInfo: WaveInfo)
	info = newInfo
	elapsed = 0
	local n = newInfo.localWave
	-- Élites: en qué momentos de la cola salen (repartidos al azar)
	table.clear(eliteAt)
	local count = math.min(WaveEvents.eliteCount(n), newInfo.queueSize)
	local slots = {}
	for i = 1, newInfo.queueSize do
		slots[i] = i
	end
	for _ = 1, count do
		table.insert(eliteAt, table.remove(slots, math.random(1, #slots)))
	end
	table.sort(eliteAt, function(a, b)
		return a > b
	end)
	-- Horda: ¿hay esta oleada? (nunca en la del jefe)
	local h = Cfg.Horde
	hordeAt = nil
	hordeState, hordeToSpawn = "", 0
	if n >= h.FromWave and not newInfo.bossWave and math.random() < h.Chance then
		hordeAt = h.StartAfter[1] + math.random() * (h.StartAfter[2] - h.StartAfter[1])
		hordeTypes = WaveEvents.hordeTypes(newInfo.chapter, n)
	end
	-- Meta de equipo
	goal = nil
	goalAt = if n >= Cfg.Goals.FromWave then Cfg.Goals.Delay else nil
	publishHorde()
	publishGoal()
end

-- Waves, en cada aparición de la cola: ¿este sale élite? remaining = tamaño de la cola antes
-- de sacarlo. Devuelve el rasgo, o nil.
function WaveEvents.takeElite(typeId: string, remaining: number): any?
	local at = eliteAt[1]
	if not at or remaining > at or not canBeElite(typeId) then
		return nil
	end
	table.remove(eliteAt, 1)
	return randomAffix()
end

-- Waves avisa que apareció un élite (para el cartel del HUD)
function WaveEvents.onEliteSpawned(enemy: any)
	announceElite(enemy)
end

local function startGoal(targets: { PlayerData.Target })
	local g = Cfg.Goals
	local scale = if info then info.countScale else 1
	local options = { "Kills", "Elite", "Chests", "NoDown" }
	if lastGoalId then
		table.remove(options, table.find(options, lastGoalId) :: number)
	end
	local id = options[math.random(1, #options)]
	lastGoalId = id
	if id == "Kills" then
		local n = math.max(10, math.floor(g.Kills.Count * scale + 0.5))
		goal = { id = id, text = string.format("Maten %d enemigos entre todos en %d s", n, g.Kills.Time), progress = 0, target = n, timeLeft = g.Kills.Time, state = "active" }
	elseif id == "Elite" then
		local pos = ringPoint(targets, math.random() * math.pi * 2, 28)
		local chapter = if info then info.chapter else nil
		local types = if chapter then availableTypes(chapter, if info then info.localWave else 1) else {}
		local typeId = types[#types] -- el más fuerte que ya sale
		if not pos or not typeId then
			goal = nil
			return
		end
		local enemy = Enemies.spawn(typeId, pos, {
			healthMult = if info then info.healthMult else 1,
			dmgMult = if info then info.dmgMult else 1,
			elite = randomAffix(),
		})
		enemy.goalTarget = true
		enemy.part:SetAttribute("GoalTarget", true)
		announceElite(enemy)
		goal = { id = id, text = string.format("Maten al élite marcado en %d s", g.Elite.Time), progress = 0, target = 1, timeLeft = g.Elite.Time, state = "active", enemy = enemy }
	elseif id == "Chests" then
		goal = { id = id, text = string.format("Abran %d cofres en esta oleada", g.Chests.Count), progress = 0, target = g.Chests.Count, timeLeft = nil, state = "active" }
	else
		downsAtStart = totalDowns()
		goal = { id = id, text = "Que nadie caiga en esta oleada", progress = 0, target = 1, timeLeft = nil, state = "active" }
	end
	publishGoal()
end

local function finishGoal(success: boolean, pos: Vector3?)
	local g = goal
	if not g or g.state ~= "active" then
		return
	end
	g.state = if success then "done" else "failed"
	if success then
		g.progress = g.target
	end
	publishGoal()
	if success then
		hooks.onGoalDone(g, pos)
	end
end

-- Cada frame de oleada (no corre en pausa)
function WaveEvents.update(dt: number, targets: { PlayerData.Target })
	if not info then
		return
	end
	elapsed += dt
	-- Horda
	local h = Cfg.Horde
	if hordeAt and elapsed >= hordeAt and hordeState == "" then
		hordeState = "active"
		hordeToSpawn = math.max(h.Burst, math.floor(h.Count * info.countScale + 0.5))
		hordeTimer = 0
		publishHorde()
	end
	if hordeState == "active" then
		if hordeToSpawn > 0 then
			hordeTimer -= dt
			local room = Config.Enemy.MaxAlive - Enemies.aliveCount()
			if hordeTimer <= 0 and room > 0 and #targets > 0 then
				hordeTimer = h.BurstEvery
				local count = math.min(h.Burst, hordeToSpawn, room)
				local base = math.random() * math.pi * 2
				for i = 1, count do
					local angle = base + (i - 1) * math.pi * 2 / count + (math.random() - 0.5) * 0.3
					local pos = ringPoint(targets, angle, h.Distance + math.random() * 6)
					if pos then
						Enemies.spawn(hordeTypes[(i % #hordeTypes) + 1], pos, {
							healthMult = info.healthMult * h.HealthMult,
							dmgMult = info.dmgMult,
							horde = true,
						})
					end
				end
				hordeToSpawn -= count
			end
		end
		local left = hordeToSpawn + hordeAlive()
		set("HordeLeft", left)
		if left == 0 then
			hordeState = "cleared"
			publishHorde()
			hooks.onHordeCleared(lastKillPos)
		end
	end
	-- Meta de equipo
	if goalAt and elapsed >= goalAt and not goal then
		goalAt = nil
		startGoal(targets)
	end
	local g = goal
	if g and g.state == "active" then
		if g.timeLeft then
			local before = math.ceil(g.timeLeft)
			g.timeLeft -= dt
			if g.timeLeft <= 0 then
				finishGoal(false)
			elseif math.ceil(g.timeLeft) ~= before then
				set("GoalTimeLeft", math.ceil(g.timeLeft))
			end
		end
		if g.id == "NoDown" and g.state == "active" and totalDowns() > downsAtStart then
			finishGoal(false)
		end
	end
end

-- Horda que todavía falta aparecer (la oleada no termina mientras haya)
function WaveEvents.pending(): number
	return if hordeState == "active" then hordeToSpawn else 0
end

-- Una muerte (Run)
function WaveEvents.onKill(enemy: any, pos: Vector3)
	lastKillPos = pos
	if enemy.elite then
		Chests.dropAt(pos, Chests.rollAtLeast(Cfg.Elite.ChestMinRarity))
	end
	local g = goal
	if g and g.state == "active" then
		if g.id == "Kills" then
			g.progress += 1
			set("GoalProgress", g.progress)
			if g.progress >= g.target then
				finishGoal(true, pos)
			end
		elseif g.id == "Elite" and enemy == g.enemy then
			finishGoal(true, pos)
		end
	end
end

-- Un cofre abierto (Run, desde Chests.onOpened)
function WaveEvents.onChestOpened(pos: Vector3)
	local g = goal
	if g and g.state == "active" and g.id == "Chests" then
		g.progress += 1
		set("GoalProgress", g.progress)
		if g.progress >= g.target then
			finishGoal(true, pos)
		end
	end
end

-- Terminó la oleada (antes del descanso o de la victoria)
function WaveEvents.onWaveEnd()
	local g = goal
	if g and g.state == "active" then
		if g.id == "NoDown" then
			finishGoal(totalDowns() == downsAtStart)
		else
			finishGoal(false)
		end
	end
	goalAt = nil
	hordeAt = nil
	if hordeState == "active" then
		hordeState = ""
		hordeToSpawn = 0
		publishHorde()
	end
	table.clear(eliteAt)
end

-- Panel de prueba (saltar oleada): lo que falta de la horda se cancela
function WaveEvents.debugSkip()
	hordeToSpawn = 0
end

-- Panel de prueba: arrancar ya la horda o una meta
function WaveEvents.debugHorde(chapter: any)
	if not info then
		return
	end
	hordeTypes = WaveEvents.hordeTypes(chapter, info.localWave)
	hordeAt = elapsed
	hordeState = ""
end

function WaveEvents.debugGoal(targets: { PlayerData.Target })
	if not info then
		return
	end
	goal = nil
	goalAt = nil
	startGoal(targets)
end

function WaveEvents.goal(): Goal?
	return goal
end

function WaveEvents.hordeState(): string
	return hordeState
end

return WaveEvents
