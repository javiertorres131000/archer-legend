-- Combat (ModuleScript)
-- Ubicación: ServerScriptService > Server > Combat
-- Disparo automático (caminando, o solo quieto si Config.Player.ShootWhileMoving = false)
-- y proyectiles simulados como matemática pura. Críticos y retroceso de los enemigos.
-- Apuntado por jugador: "Auto" elige al enemigo más cercano, "Manual" tira hacia donde mira.
-- El cliente solo dibuja las flechas; el daño se decide acá.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Enemies = require(script.Parent.Enemies)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)

local PlayerCfg = Config.Player
local ProjCfg = Config.Projectile
local flat = PlayerData.flat

local Combat = {}

type Projectile = {
	id: number,
	owner: Player,
	pos: Vector3,
	dir: Vector3,
	age: number,
	damage: number,
	critChance: number,
	critMultiplier: number,
	pierce: number,
	bounces: number,
	burn: boolean,
	hit: { [Enemies.Enemy]: boolean }, -- enemigos ya golpeados (no se repiten)
}

-- Proyectil enemigo: golpea jugadores. Se mueve por tramos rectos (origin + dir * speed * segAge),
-- con un vaivén lateral opcional (zigzag). Un rebote o una vuelta empieza un tramo nuevo.
type EnemyProjectile = {
	id: number,
	origin: Vector3,
	dir: Vector3,
	pos: Vector3,
	speed: number,
	damage: number,
	radius: number,
	lifetime: number,
	age: number, -- edad total
	segAge: number, -- edad del tramo actual
	bounces: number, -- rebotes en paredes que le quedan
	zigAmp: number,
	zigFreq: number,
	returnAfter: number?, -- vuelve hacia quien lo tiró (guadañas)
	shooter: any?,
}

export type EnemyProjectileOptions = {
	speed: number?,
	damage: number?,
	size: number?,
	color: Color3?,
	lifetime: number?,
	bounces: number?,
	zigAmp: number?,
	zigFreq: number?,
	returnAfter: number?,
}

local EnemyProjCfg = Config.EnemyProjectile

local remotes
local half: Vector3 = Vector3.zero
local projectiles: { Projectile } = {}
local enemyProjectiles: { EnemyProjectile } = {}
local nextId = 0

function Combat.init(r, arenaHalf: Vector3)
	remotes = r
	half = arenaHalf
	r.SetAimMode.OnServerEvent:Connect(PlayerData.setAimMode)
end

local function rotateFlat(dir: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(dir)
end

local function spawnProjectile(player: Player, stats: PlayerData.Stats, origin: Vector3, dir: Vector3)
	nextId += 1
	table.insert(projectiles, {
		id = nextId,
		owner = player,
		pos = origin,
		dir = dir,
		age = 0,
		damage = stats.damage,
		critChance = stats.critChance,
		critMultiplier = stats.critMultiplier,
		pierce = stats.pierce,
		bounces = stats.ricochet,
		burn = stats.burn,
		hit = {},
	})
	remotes.ProjectileFired:FireAllClients(nextId, origin, dir, ProjCfg.Speed, ProjCfg.Lifetime, player.UserId)
end

-- Una "ráfaga": flechas paralelas al frente + pares diagonales.
local function fireVolley(target: PlayerData.Target, dir: Vector3)
	local stats = target.state.stats
	local origin = target.root.Position
	local right = dir:Cross(Vector3.yAxis).Unit

	local count = 1 + stats.frontArrows
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * ProjCfg.FrontSpacing
		spawnProjectile(target.player, stats, origin + right * offset, dir)
	end

	for pair = 1, stats.diagonalPairs do
		local angle = ProjCfg.DiagonalAngles[pair] or ProjCfg.DiagonalAngles[#ProjCfg.DiagonalAngles]
		spawnProjectile(target.player, stats, origin, rotateFlat(dir, angle))
		spawnProjectile(target.player, stats, origin, rotateFlat(dir, -angle))
	end
end

-- Enemigo más cercano a tiro. En primera persona, solo los que están delante del jugador
-- (el personaje gira con la cámara y eso se replica al servidor, que mira hacia dónde apunta).
local function pickTarget(t: PlayerData.Target)
	if Config.Camera.Mode ~= "FirstPerson" then
		return Enemies.nearest(t.root.Position, nil, PlayerCfg.AttackRange)
	end
	local look = flat(t.root.CFrame.LookVector)
	if look.Magnitude < 0.01 then
		return nil
	end
	look = look.Unit
	local minDot = math.cos(math.rad(PlayerCfg.AimConeFirstPerson / 2))
	local origin = flat(t.root.Position)
	local best, bestDist = nil, PlayerCfg.AttackRange
	for _, e in Enemies.list do
		if e.alive and not e.hidden then
			local offset = flat(e.part.Position) - origin
			local d = offset.Magnitude
			if d <= bestDist and (d < 0.01 or offset.Unit:Dot(look) >= minDot) then
				best, bestDist = e, d
			end
		end
	end
	return best
end

-- Apuntado manual: hacia donde mira el personaje (gira con la cámara en primera y tercera persona).
-- Solo si queda algún enemigo, para no tirar flechas al aire en los descansos.
local function manualDirection(t: PlayerData.Target): Vector3?
	local anyEnemy = false
	for _, e in Enemies.list do
		if e.alive and not e.hidden then
			anyEnemy = true
			break
		end
	end
	local look = flat(t.root.CFrame.LookVector)
	if not anyEnemy or look.Magnitude < 0.01 then
		return nil
	end
	return look.Unit
end

local function updateAttacks(targets: { PlayerData.Target }, now: number)
	for _, t in targets do
		local state = t.state
		-- No dispara mientras elige habilidad.
		if state.currentOffer and Config.Progression.PauseWhileChoosing then
			continue
		end
		-- Regla de Archero (opcional): solo dispara si está quieto.
		if
			not PlayerCfg.ShootWhileMoving
			and flat(t.root.AssemblyLinearVelocity).Magnitude > PlayerCfg.StillThreshold
		then
			continue
		end
		if now - state.lastShot < state.stats.attackInterval then
			continue
		end
		local dir: Vector3? = nil
		if state.aimMode == "Manual" then
			dir = manualDirection(t)
		else
			local enemy = pickTarget(t)
			dir = enemy and flat(enemy.part.Position - t.root.Position).Unit
		end
		if dir then
			state.lastShot = now
			fireVolley(t, dir)
		end
	end
end

local function updateProjectiles(dt: number, allowDamage: boolean)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		p.pos += p.dir * ProjCfg.Speed * dt
		p.age += dt

		local ended = false
		for _, e in Enemies.list do
			if not allowDamage then break end
			if not e.alive or e.hidden or p.hit[e] then
				continue
			end
			if (flat(e.part.Position) - flat(p.pos)).Magnitude > ProjCfg.Radius + e.radius then
				continue
			end

			p.hit[e] = true
			-- El fuego se aplica antes del golpe, por si el golpe lo mata.
			if p.burn then
				Enemies.applyBurn(e, p.damage * ProjCfg.BurnFraction * (1 + ((PlayerData.get(p.owner) and PlayerData.get(p.owner).stats.burnBonus) or 0)), ProjCfg.BurnDuration, p.owner)
			end
			-- Crítico: se sortea en cada impacto
			local crit = math.random() < p.critChance
			local damage = if crit then p.damage * p.critMultiplier else p.damage
			Enemies.damage(e, damage, p.owner, if crit then "crit" else "hit")
			-- Retroceso (los jefes no se mueven)
			if e.alive and not e.isBoss then
				Enemies.knockback(e, p.dir, Config.Frenzy.Knockback * (if crit then 2 else 1))
			end

			-- Rebote: busca otro enemigo cercano que no haya golpeado
			local redirected = false
			if p.bounces > 0 then
				local nextEnemy = Enemies.nearest(p.pos, p.hit, ProjCfg.RicochetRange)
				if nextEnemy then
					p.bounces -= 1
					p.dir = flat(nextEnemy.part.Position - p.pos).Unit
					p.age = 0
					redirected = true
					remotes.ProjectileRedirected:FireAllClients(p.id, p.pos, p.dir, ProjCfg.Lifetime)
				end
			end

			-- Si no rebotó, atraviesa (si puede) o termina
			if not redirected then
				if p.pierce > 0 then
					p.pierce -= 1
				else
					ended = true
				end
			end
			break -- como mucho un impacto por frame
		end

		local outOfBounds = math.abs(p.pos.X) > half.X or math.abs(p.pos.Z) > half.Z
		if ended or outOfBounds or p.age >= ProjCfg.Lifetime then
			table.remove(projectiles, i)
			remotes.ProjectileEnded:FireAllClients(p.id)
		end
	end
end

-- Dispara un proyectil enemigo. dir debe estar en el plano XZ. shooter: el enemigo que lo tiró.
function Combat.fireEnemyProjectile(origin: Vector3, dir: Vector3, opts: EnemyProjectileOptions?, shooter: any?)
	local o = opts or {}
	local size = o.size or EnemyProjCfg.Size
	nextId += 1
	local start = Vector3.new(origin.X, size / 2 + 0.5, origin.Z)
	local p: EnemyProjectile = {
		id = nextId,
		origin = start,
		dir = dir,
		pos = start,
		speed = o.speed or EnemyProjCfg.Speed,
		damage = o.damage or EnemyProjCfg.Damage,
		radius = math.max(EnemyProjCfg.Radius, size / 2),
		lifetime = o.lifetime or EnemyProjCfg.Lifetime,
		age = 0,
		segAge = 0,
		bounces = o.bounces or 0,
		zigAmp = o.zigAmp or 0,
		zigFreq = o.zigFreq or 0,
		returnAfter = o.returnAfter,
		shooter = shooter,
	}
	table.insert(enemyProjectiles, p)
	-- ownerUserId = 0 le indica al cliente que es enemigo. El estilo le dice cómo dibujarlo.
	remotes.ProjectileFired:FireAllClients(p.id, start, dir, p.speed, p.lifetime, 0, {
		size = size,
		color = if EnemyProjCfg.UseDangerColor then EnemyProjCfg.Color else (o.color or EnemyProjCfg.Color),
		zigAmp = p.zigAmp,
		zigFreq = p.zigFreq,
	})
end

-- Posición del proyectil según su tramo (el cliente usa exactamente la misma cuenta).
local function enemyProjectilePos(p: EnemyProjectile): Vector3
	local pos = p.origin + p.dir * p.speed * p.segAge
	if p.zigAmp > 0 then
		local side = Vector3.new(-p.dir.Z, 0, p.dir.X)
		pos += side * p.zigAmp * math.sin(p.segAge * p.zigFreq)
	end
	return pos
end

-- Empieza un tramo nuevo desde la posición actual y avisa a los clientes.
local function redirect(p: EnemyProjectile, newDir: Vector3)
	p.origin = p.pos
	p.dir = newDir
	p.segAge = 0
	remotes.ProjectileRedirected:FireAllClients(p.id, p.pos, newDir, p.lifetime - p.age)
end

local function updateEnemyProjectiles(dt: number, targets: { PlayerData.Target })
	for i = #enemyProjectiles, 1, -1 do
		local p = enemyProjectiles[i]
		p.age += dt
		p.segAge += dt
		p.pos = enemyProjectilePos(p)

		-- Boomerang: a mitad de camino vuelve hacia quien lo tiró
		if p.returnAfter and p.age >= p.returnAfter then
			p.returnAfter = nil
			local back = -p.dir
			if p.shooter and p.shooter.alive then
				local to = flat(p.shooter.part.Position - p.pos)
				if to.Magnitude > 0.1 then
					back = to.Unit
				end
			end
			redirect(p, back)
		end

		-- Rebote en paredes
		local outX = math.abs(p.pos.X) > half.X
		local outZ = math.abs(p.pos.Z) > half.Z
		if (outX or outZ) and p.bounces > 0 then
			p.bounces -= 1
			p.pos = Vector3.new(math.clamp(p.pos.X, -half.X, half.X), p.pos.Y, math.clamp(p.pos.Z, -half.Z, half.Z))
			local d = p.dir
			redirect(p, Vector3.new(if outX then -d.X else d.X, 0, if outZ then -d.Z else d.Z))
			outX, outZ = false, false
		end

		local hit = false
		local hitRadius = p.radius + EnemyProjCfg.PlayerHitRadius
		for _, t in targets do
			if (flat(t.root.Position) - flat(p.pos)).Magnitude <= hitRadius then
				-- PlayerLife respeta escudos (aparición, eligiendo habilidad, recién revivido)
				PlayerLife.damage(t, p.damage)
				hit = true
				break
			end
		end

		if hit or outX or outZ or p.age >= p.lifetime then
			table.remove(enemyProjectiles, i)
			remotes.ProjectileEnded:FireAllClients(p.id)
		end
	end
end

function Combat.update(dt: number, targets: { PlayerData.Target }, now: number, frozen: boolean)
	if not frozen then
		updateAttacks(targets, now)
	end
	-- Los proyectiles en vuelo terminan su recorrido aunque el juego esté en pausa.
	updateProjectiles(dt, not frozen)
	updateEnemyProjectiles(dt, if frozen then {} else targets)
end

function Combat.count(): number
	return #projectiles + #enemyProjectiles
end

function Combat.clear()
	for _, p in projectiles do
		remotes.ProjectileEnded:FireAllClients(p.id)
	end
	for _, p in enemyProjectiles do
		remotes.ProjectileEnded:FireAllClients(p.id)
	end
	table.clear(projectiles)
	table.clear(enemyProjectiles)
end

return Combat
