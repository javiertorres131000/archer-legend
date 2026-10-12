-- EnemyAI (ModuleScript)
-- Ubicación: ServerScriptService > Server > EnemyAI
-- Cerebro de todos los enemigos y jefes, armado con comportamientos reutilizables.
--
-- Cada enemigo tiene un movimiento (Move) y una lista de ataques (Attacks), definidos como
-- datos en Data > EnemyTypes. Los jefes además tienen fases (Phases) que cambian según su vida.
--
-- Ciclo de un enemigo:
--   Move  -> se mueve según su comportamiento hasta que tiene un ataque listo y a rango
--   Windup -> aviso: parpadea en blanco (y salta, se entierra o marca el piso, según el ataque)
--   Active -> ejecuta el ataque
--   Recover -> pausa corta y vuelve a Move (o encadena otro ataque si tiene "Then")
--
-- Para que no sea predecible: el ataque se elige al azar entre los disponibles (nunca el
-- mismo dos veces seguidas si hay otro), y casi cualquier número puede ser un rango {min, max}.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)

local EnemyCfg = Config.Enemy
local flat = PlayerData.flat

local FLASH = Color3.new(1, 1, 1)
local AIM_COLOR = Color3.fromRGB(255, 40, 40)

-- Módulos que se inyectan en init (evita dependencias circulares con Enemies)
local Enemies
local Combat
local Hazards

local EnemyAI = {}

function EnemyAI.init(enemies, combat, hazards)
	Enemies = enemies
	Combat = combat
	Hazards = hazards
end

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------

-- Valor de un parámetro: un número, o un rango {min, max} que se sortea cada vez.
local function R(v: any, default: number?): number
	if v == nil then
		return default or 0
	end
	if type(v) == "table" then
		return v[1] + math.random() * (v[2] - v[1])
	end
	return v
end

-- Igual que R pero entero (para cantidades: Count, Bursts, Repeats).
local function RI(v: any, default: number?): number
	if type(v) == "table" then
		return math.random(v[1], v[2])
	end
	return math.floor(R(v, default) + 0.5)
end

local function rotate(dir: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(dir)
end

local function dirTo(from: Vector3, to: Vector3): Vector3
	local d = flat(to - from)
	return if d.Magnitude > 0.01 then d.Unit else Vector3.zAxis
end

local function randomSign(): number
	return if math.random() < 0.5 then -1 else 1
end

local function nearestTarget(pos: Vector3, targets: { PlayerData.Target }): (PlayerData.Target?, number)
	local best, bestDist = nil, math.huge
	for _, t in targets do
		local d = (flat(t.root.Position) - pos).Magnitude
		if d < bestDist then
			best, bestDist = t, d
		end
	end
	return best, bestDist
end

local function randomTarget(targets: { PlayerData.Target }): PlayerData.Target?
	return if #targets > 0 then targets[math.random(#targets)] else nil
end

-- Ángulo con signo (grados) para girar de `from` a `to` en el plano.
local function signedAngle(from: Vector3, to: Vector3): number
	local cross = from.Z * to.X - from.X * to.Z
	local dot = from.X * to.X + from.Z * to.Z
	return math.deg(math.atan2(cross, dot))
end

local function addPart(ctx, part: BasePart)
	ctx.parts = ctx.parts or {}
	table.insert(ctx.parts, part)
end

local function clearParts(ctx)
	if ctx and ctx.parts then
		for _, p in ctx.parts do
			p:Destroy()
		end
		ctx.parts = nil
	end
end

-- Dispara un proyectil enemigo con los parámetros del ataque.
local function shoot(e, a, origin: Vector3, dir: Vector3, speed: number?)
	Combat.fireEnemyProjectile(origin, dir, {
		speed = speed or R(a.Speed, Config.EnemyProjectile.Speed),
		damage = R(a.Damage, Config.EnemyProjectile.Damage) * e.dmgMult,
		size = a.Size,
		color = a.Color,
		lifetime = a.Lifetime,
		bounces = a.Bounces,
		zigAmp = a.Zigzag and a.Zigzag.Amp,
		zigFreq = a.Zigzag and a.Zigzag.Freq,
		returnAfter = a.Return,
	}, e)
end

---------------------------------------------------------------------
-- Ataques. Cada uno puede tener:
--   prepare(e, a, ctx, target)  al empezar el aviso (marcas en el piso, etc.)
--   begin(e, a, ctx, target)     al terminar el aviso
--   update(e, a, ctx, dt, targets, target) -> (posición nueva?, terminado)
---------------------------------------------------------------------
local Attacks = {}

-- Embestida: marca una franja y carga en línea recta. Golpea una vez a cada jugador.
Attacks.Dash = {
	prepare = function(e, a, ctx, target)
		local pos = flat(e.part.Position)
		ctx.dir = dirTo(pos, target.root.Position)
		ctx.dist = R(a.Distance, 20)
		addPart(ctx, Hazards.strip(pos, ctx.dir, ctx.dist + e.radius, e.radius * 2))
		e.ai.facing = ctx.dir
	end,
	begin = function(_e, _a, ctx)
		ctx.travelled = 0
		ctx.hit = {}
	end,
	update = function(e, a, ctx, dt, targets)
		local pos = flat(e.part.Position)
		local step = math.min(R(a.Speed, 55) * dt, ctx.dist - ctx.travelled)
		ctx.travelled += step
		local wanted = pos + ctx.dir * step
		local newPos = Enemies.clampFlat(wanted, e.radius)
		-- Si la pared lo frenó, termina la embestida
		local blocked = (wanted - newPos).Magnitude > 0.05
		for _, t in targets do
			if not ctx.hit[t.player] and (flat(t.root.Position) - newPos).Magnitude <= e.radius + 1.5 then
				ctx.hit[t.player] = true
				PlayerLife.damage(t, R(a.Damage, 15) * e.dmgMult)
			end
		end
		return newPos, blocked or ctx.travelled >= ctx.dist
	end,
}

-- Disparo. Pattern:
--   "Aimed"  (por defecto) hacia el jugador; con Count > 1 sale en abanico de Spread grados
--   "Radial" Count proyectiles en círculo; Rotate gira el círculo en cada ráfaga
--   "Random" Count proyectiles en direcciones al azar
-- Bursts ráfagas separadas por BurstDelay. SpeedSeq = velocidad distinta por ráfaga.
Attacks.Shoot = {
	prepare = function(e, a, ctx, target)
		local pos = flat(e.part.Position)
		ctx.aim = dirTo(pos, target.root.Position)
		e.ai.facing = ctx.aim
		if a.AimLine then
			addPart(ctx, Hazards.strip(pos, ctx.aim, 60, 0.35, AIM_COLOR, 0.4))
		end
	end,
	begin = function(_e, a, ctx)
		clearParts(ctx)
		ctx.bursts = RI(a.Bursts, 1)
		ctx.index = 0
		ctx.timer = 0
		ctx.offset = math.random() * 360
		ctx.rotSign = randomSign()
		ctx.rotate = R(a.Rotate, 0) -- grados que gira el círculo en cada ráfaga
	end,
	update = function(e, a, ctx, dt, _targets, target)
		local pos = flat(e.part.Position)
		ctx.timer -= dt
		if ctx.timer > 0 then
			return pos, false
		end
		ctx.index += 1
		local speed = if a.SpeedSeq then a.SpeedSeq[ctx.index] or a.SpeedSeq[#a.SpeedSeq] else nil
		local count = RI(a.Count, 1)
		local pattern = a.Pattern or "Aimed"

		if pattern == "Radial" then
			local start = ctx.offset + (ctx.index - 1) * ctx.rotate * ctx.rotSign
			for i = 0, count - 1 do
				shoot(e, a, pos, rotate(Vector3.zAxis, start + i * 360 / count), speed)
			end
		elseif pattern == "Random" then
			for _ = 1, count do
				shoot(e, a, pos, rotate(Vector3.zAxis, math.random() * 360), speed)
			end
		else
			-- Primera ráfaga: hacia donde apuntó en el aviso. Las siguientes reapuntan (salvo Track = false).
			local aim = ctx.aim
			if ctx.index > 1 and a.Track ~= false and target then
				aim = dirTo(pos, target.root.Position)
			end
			local jitter = a.Jitter or 0
			aim = rotate(aim, (math.random() * 2 - 1) * jitter)
			e.ai.facing = aim
			local spread = a.Spread or 0
			for i = 1, count do
				local angle = if count == 1 then 0 else -spread / 2 + (i - 1) * spread / (count - 1)
				shoot(e, a, pos, rotate(aim, angle), speed)
			end
		end

		ctx.bursts -= 1
		ctx.timer = R(a.BurstDelay, 0.3)
		return pos, ctx.bursts <= 0
	end,
}

-- Ataque de área: círculos rojos que se llenan y después dañan.
--   Target = "Player" (alrededor de jugadores, con Scatter de dispersión), "Self" (alrededor
--   del enemigo, un pisotón) o "Random" (en cualquier lugar de la arena).
--   Zone = { Duration, Dps } deja el piso dañando después del impacto (fuego, veneno).
Attacks.Area = {
	begin = function(_e, a, ctx)
		ctx.bursts = RI(a.Bursts, 1)
		ctx.timer = 0
	end,
	update = function(e, a, ctx, dt, targets)
		local pos = flat(e.part.Position)
		ctx.timer -= dt
		if ctx.timer > 0 then
			return pos, false
		end
		local count = RI(a.Count, 1)
		local half = Enemies.getHalf()
		local zone = nil
		if a.Zone then
			zone = { Duration = R(a.Zone.Duration, 3), Dps = R(a.Zone.Dps, 8) * e.dmgMult, Color = a.Zone.Color }
		end
		for i = 1, count do
			local radius = R(a.Radius, 3)
			local point
			local mode = a.Target or "Player"
			if mode == "Self" then
				point = pos
			elseif mode == "Random" then
				point = Vector3.new((math.random() * 2 - 1) * (half.X - radius), 0, (math.random() * 2 - 1) * (half.Z - radius))
			else
				-- En coop reparte los impactos entre los jugadores
				local t = randomTarget(targets)
				if not t then
					break
				end
				local scatter = if i == 1 and a.FirstExact then 0 else R(a.Scatter, 0)
				local angle = math.random() * math.pi * 2
				point = flat(t.root.Position) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * scatter * math.random()
			end
			point = Enemies.clampFlat(point, 1)
			Hazards.warn(point, radius, R(a.Delay, 1), R(a.Damage, 15) * e.dmgMult, zone, a.WarnColor)
		end
		ctx.bursts -= 1
		ctx.timer = R(a.BurstDelay, 0.5)
		return pos, ctx.bursts <= 0
	end,
}

-- Aliento: chorro de proyectiles cortos en cono durante Duration segundos.
-- Gira hacia el jugador a TurnRate grados/s, o da vueltas si tiene Spin (grados/s).
Attacks.Breath = {
	begin = function(e, a, ctx, target)
		local pos = flat(e.part.Position)
		ctx.timeLeft = R(a.Duration, 1.2)
		ctx.fireTimer = 0
		ctx.aim = if target then dirTo(pos, target.root.Position) else e.part.CFrame.LookVector
		ctx.spinSign = randomSign()
	end,
	update = function(e, a, ctx, dt, _targets, target)
		local pos = flat(e.part.Position)
		ctx.timeLeft -= dt
		if a.Spin then
			ctx.aim = rotate(ctx.aim, a.Spin * dt * ctx.spinSign)
		elseif target then
			local want = dirTo(pos, target.root.Position)
			local diff = signedAngle(ctx.aim, want)
			local maxTurn = (a.TurnRate or 90) * dt
			ctx.aim = rotate(ctx.aim, math.clamp(diff, -maxTurn, maxTurn))
		end
		e.ai.facing = ctx.aim
		ctx.fireTimer -= dt
		while ctx.fireTimer <= 0 do
			ctx.fireTimer += a.Rate or 0.08
			local spread = a.Spread or 30
			shoot(e, a, pos, rotate(ctx.aim, (math.random() - 0.5) * spread))
		end
		return pos, ctx.timeLeft <= 0
	end,
}

-- Teletransporte: marca el destino durante el aviso y aparece ahí.
Attacks.Teleport = {
	prepare = function(e, a, ctx, target)
		local center = flat(target.root.Position)
		local dest = center
		for _ = 1, 8 do
			local angle = math.random() * math.pi * 2
			local d = R(a.Distance, 14)
			dest = Enemies.clampFlat(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * d, e.radius + 2)
			if (dest - center).Magnitude >= 6 then
				break
			end
		end
		ctx.dest = dest
		Hazards.marker(dest, e.radius + 1, R(a.Telegraph, EnemyCfg.DefaultTelegraph) + 0.1)
		Enemies.setTransparency(e, 0.5)
	end,
	update = function(e, _a, ctx)
		Enemies.setTransparency(e, 0)
		return ctx.dest, true
	end,
}

-- Enterrarse: se hunde, viaja bajo tierra y reaparece cerca de un jugador.
Attacks.Burrow = {
	begin = function(e, a, ctx, target)
		Enemies.setHidden(e, true)
		ctx.timeLeft = R(a.Duration, 1.8)
		local center = if target then flat(target.root.Position) else flat(e.part.Position)
		local angle = math.random() * math.pi * 2
		ctx.dest = Enemies.clampFlat(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * R(a.Emerge, 9), e.radius + 1)
		ctx.marked = false
	end,
	update = function(e, _a, ctx, dt)
		ctx.timeLeft -= dt
		if not ctx.marked and ctx.timeLeft <= 0.7 then
			ctx.marked = true
			Hazards.marker(ctx.dest, e.radius + 1, 0.8, Color3.fromRGB(150, 100, 60))
		end
		if ctx.timeLeft <= 0 then
			e.ai.yOffset = 0
			Enemies.setHidden(e, false)
			return ctx.dest, true
		end
		return flat(e.part.Position), false
	end,
}

-- Invocar: crea Count enemigos de tipo Spawn alrededor. Max limita cuántos puede tener vivos.
Attacks.Summon = {
	update = function(e, a, _ctx)
		local pos = flat(e.part.Position)
		local room = (a.Max or math.huge) - Enemies.countSummoned(e, a.Spawn)
		local count = math.min(RI(a.Count, 2), room)
		local base = math.random() * 360
		for i = 1, count do
			local dir = rotate(Vector3.zAxis, base + i * 360 / count)
			Enemies.queueSpawn(a.Spawn, pos + dir * (e.radius + 3), {
				healthMult = e.healthMult * (a.HealthMult or 1),
				dmgMult = e.dmgMult,
				summoner = e,
			})
			Hazards.marker(pos + dir * (e.radius + 3), 1.5, 0.4)
		end
		return pos, true
	end,
}

---------------------------------------------------------------------
-- Movimientos. Devuelven una velocidad (studs/s) en el plano.
---------------------------------------------------------------------
local Moves = {}

-- Persigue al jugador más cercano.
Moves.Chase = function(e, m, pos, target, dist)
	if dist <= e.radius + 1 then
		return Vector3.zero
	end
	return dirTo(pos, target.root.Position) * R(m.Speed, 8)
end

-- A saltitos: se impulsa Hop segundos hacia el jugador (desviado hasta Wobble grados) y para Pause.
Moves.Erratic = function(e, m, pos, target, _dist, dt)
	local mv = e.ai.mv
	mv.timer = (mv.timer or 0) - dt
	if mv.timer <= 0 then
		mv.moving = not mv.moving
		if mv.moving then
			mv.timer = R(m.Hop, 0.5)
			local wobble = m.Wobble or 60
			mv.dir = rotate(dirTo(pos, target.root.Position), (math.random() * 2 - 1) * wobble)
		else
			mv.timer = R(m.Pause, 0.5)
		end
	end
	return if mv.moving then mv.dir * R(m.Speed, 12) else Vector3.zero
end

-- Mantiene distancia: se acerca si está lejos, se aleja si está cerca y si no, se mueve de costado.
Moves.Keep = function(e, m, pos, target, dist, dt)
	local mv = e.ai.mv
	local toTarget = dirTo(pos, target.root.Position)
	local speed = R(m.Speed, 8)
	if dist < (m.Min or 12) then
		return -toTarget * speed
	elseif dist > (m.Max or 24) then
		return toTarget * speed
	end
	mv.flip = (mv.flip or 0) - dt
	if mv.flip <= 0 then
		mv.flip = 1 + math.random() * 1.5
		mv.sign = if math.random() < 0.25 then 0 else randomSign()
	end
	return Vector3.new(-toTarget.Z, 0, toTarget.X) * (mv.sign or 0) * speed * 0.6
end

-- Deambula: cambia de rumbo cada tanto, a veces hacia el jugador.
Moves.Wander = function(e, m, pos, target, _dist, dt)
	local mv = e.ai.mv
	mv.timer = (mv.timer or 0) - dt
	if mv.timer <= 0 or not mv.dir then
		mv.timer = 1 + math.random() * 1.5
		if math.random() < 0.45 then
			mv.dir = dirTo(pos, target.root.Position)
		else
			mv.dir = rotate(Vector3.zAxis, math.random() * 360)
		end
	end
	return mv.dir * R(m.Speed, 8)
end

-- Quieto (plantas, torretas).
Moves.Still = function()
	return Vector3.zero
end

---------------------------------------------------------------------
-- Máquina de estados
---------------------------------------------------------------------

local function phasesOf(def)
	return def.Phases or { { Above = 0, Move = def.Move, Attacks = def.Attacks or {}, Rest = def.Rest } }
end

function EnemyAI.setup(e)
	local phases = phasesOf(e.def)
	local cooldowns = {}
	for _, phase in phases do
		for _, a in phase.Attacks or {} do
			-- Arrancan desfasados para que un grupo del mismo tipo no ataque sincronizado
			cooldowns[a] = if e.isBoss then 0 else R(a.Cooldown, 2) * (0.3 + math.random() * 0.7)
		end
	end
	e.ai = {
		phases = phases,
		phase = 1,
		cooldowns = cooldowns,
		rest = if e.isBoss then 1.5 else math.random() * 0.8,
		state = "Move",
		timer = 0,
		attack = nil,
		ctx = nil,
		last = nil,
		repeatsLeft = 0,
		yOffset = 0,
		facing = nil,
		mv = {},
		trailTimer = 0,
	}
end

function EnemyAI.cleanup(e)
	if e.ai then
		clearParts(e.ai.ctx)
	end
end

-- Fase actual según la vida: la primera cuyo umbral "Above" esté por debajo de la vida actual.
local function currentPhase(e): number
	local frac = e.health / e.maxHealth
	for i, phase in e.ai.phases do
		if frac > (phase.Above or 0) then
			return i
		end
	end
	return #e.ai.phases
end

function EnemyAI.phaseIndex(e): number
	return e.ai.phase
end

local function pickAttack(e, phase, dist: number)
	local ai = e.ai
	local candidates = {}
	local total = 0
	for _, a in phase.Attacks or {} do
		if ai.cooldowns[a] <= 0 and dist <= (a.Range or math.huge) and dist >= (a.MinRange or 0) then
			local ok = true
			if a.Type == "Summon" and Enemies.countSummoned(e, a.Spawn) >= (a.Max or math.huge) then
				ok = false
			end
			if ok then
				table.insert(candidates, a)
			end
		end
	end
	-- No repetir el último ataque si hay otra opción
	if #candidates > 1 then
		for i, a in candidates do
			if a == ai.last then
				table.remove(candidates, i)
				break
			end
		end
	end
	for _, a in candidates do
		total += a.Weight or 1
	end
	local roll = math.random() * total
	for _, a in candidates do
		roll -= a.Weight or 1
		if roll <= 0 then
			return a
		end
	end
	return nil
end

local function startAttack(e, a, target, isRepeat: boolean?)
	local ai = e.ai
	ai.attack = a
	ai.ctx = {}
	ai.state = "Windup"
	local telegraph = if isRepeat then R(a.RepeatTelegraph, 0.35) else R(a.Telegraph, EnemyCfg.DefaultTelegraph)
	ai.timer = telegraph
	ai.windup = telegraph
	if not isRepeat then
		ai.last = a
		ai.cooldowns[a] = R(a.Cooldown, 0)
		ai.repeatsLeft = RI(a.Repeats, 1) - 1
	end
	ai.facing = dirTo(flat(e.part.Position), target.root.Position)
	local handler = Attacks[a.Type]
	assert(handler, "Tipo de ataque desconocido: " .. tostring(a.Type))
	if handler.prepare then
		handler.prepare(e, a, ai.ctx, target)
	end
end

local function finishAttack(e, phase, target)
	local ai = e.ai
	local a = ai.attack
	clearParts(ai.ctx)
	e.part.Color = Enemies.baseColor(e)
	ai.yOffset = 0

	if target and ai.repeatsLeft > 0 then
		ai.repeatsLeft -= 1
		startAttack(e, a, target, true)
		return
	end
	if target and a.Then then
		startAttack(e, a.Then, target)
		return
	end
	ai.state = "Recover"
	ai.timer = R(a.Recover, 0.25)
	ai.rest = if a.ChainRest then R(a.ChainRest) else R(phase.Rest, EnemyCfg.DefaultRest)
	ai.attack = nil
	ai.ctx = nil
end

-- Un paso de la IA. Devuelve (posición deseada en el plano, dirección a mirar, si se separa de otros).
function EnemyAI.step(e, dt: number, targets: { PlayerData.Target }): (Vector3, Vector3?, boolean)
	local ai = e.ai
	local pos = flat(e.part.Position)

	ai.phase = currentPhase(e)
	local phase = ai.phases[ai.phase]
	for a, t in ai.cooldowns do
		ai.cooldowns[a] = t - dt
	end

	local target, dist = nearestTarget(pos, targets)

	if ai.state == "Move" then
		local m = phase.Move
		local vel = Vector3.zero
		if target and m and Moves[m.Type] then
			vel = Moves[m.Type](e, m, pos, target, dist, dt)
		end

		-- Rastro peligroso (arañas)
		local trail = e.def.Trail
		if trail and vel.Magnitude > 0.1 then
			ai.trailTimer -= dt
			if ai.trailTimer <= 0 then
				ai.trailTimer = R(trail.Interval, 0.6)
				Hazards.zone(pos, R(trail.Radius, 2), R(trail.Duration, 3), R(trail.Dps, 8) * e.dmgMult, trail.Color)
			end
		end

		ai.rest -= dt
		if target and ai.rest <= 0 then
			local a = pickAttack(e, phase, dist)
			if a then
				startAttack(e, a, target)
				return pos, ai.facing, false
			end
		end

		local facing = if vel.Magnitude > 0.1 and m and m.Type ~= "Keep" then vel.Unit elseif target then dirTo(pos, target.root.Position) else nil
		return pos + vel * dt, facing, m ~= nil and m.Type ~= "Still"
	elseif ai.state == "Windup" then
		local a = ai.attack
		ai.timer -= dt
		local progress = if ai.windup > 0 then 1 - math.max(ai.timer, 0) / ai.windup else 1
		-- Parpadeo blanco: el aviso universal de "va a atacar"
		local blink = 0.5 + 0.5 * math.sin(os.clock() * 30)
		e.part.Color = Enemies.baseColor(e):Lerp(FLASH, blink * 0.8)
		if a.Jump then
			ai.yOffset = math.sin(progress * math.pi) * (a.JumpHeight or 3)
		elseif a.Type == "Burrow" then
			ai.yOffset = -e.height * progress
		end
		-- Algunos ataques siguen al jugador con la mirada mientras avisan
		if target and (a.Type == "Breath" or a.Type == "Area" or a.Type == "Summon") then
			ai.facing = dirTo(pos, target.root.Position)
		end
		if ai.timer <= 0 then
			e.part.Color = Enemies.baseColor(e)
			if a.Type ~= "Burrow" then
				ai.yOffset = 0
			end
			ai.state = "Active"
			local handler = Attacks[a.Type]
			if handler.begin then
				handler.begin(e, a, ai.ctx, target)
			end
		end
		return pos, ai.facing, false
	elseif ai.state == "Active" then
		local a = ai.attack
		local newPos, done = Attacks[a.Type].update(e, a, ai.ctx, dt, targets, target)
		if done then
			finishAttack(e, phase, target)
		end
		return newPos or pos, ai.facing, false
	else -- Recover
		ai.timer -= dt
		if ai.timer <= 0 then
			ai.state = "Move"
		end
		return pos, ai.facing, false
	end
end

return EnemyAI
