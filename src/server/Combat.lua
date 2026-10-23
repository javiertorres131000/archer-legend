-- Combat (ModuleScript)
-- Ubicación: ServerScriptService > Server > Combat
-- Ataque según el arma (Shared/Weapons.lua) y Config.Player.FireMode:
--   · "Manual": el jugador aprieta para atacar y apunta con la mira (Remotes.AttackRequest:
--     apretado + dirección). El servidor valida y respeta la cadencia; mantener apretado sigue
--     atacando y un click durante la recarga queda en cola.
--   · "Auto": ataca solo al enemigo más cercano (lo de abajo).
--   · Arco: dispara al enemigo más cercano (en primera persona, dentro del cono de la mira).
--     Proyectiles simulados como matemática pura, críticos, rebotes y retroceso.
--   · Espada / puños: cuando un enemigo entra en alcance, golpe en arco que pega a todos los que
--     estén adentro (Combat.meleeSwing). Remotes.MeleeSwing avisa a los clientes para dibujarlo.
-- El cliente solo dibuja; el daño se decide acá.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Enemies = require(script.Parent.Enemies)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Weapons"))
local SkillEffects = require(script.Parent.SkillEffects)

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
	farDamage: number, -- Ojo del cazador: daño extra si el enemigo está lejos del dueño
	source: string, -- "arrow" (flecha de arco) | "wave" (onda de la espada) · SkillEffects
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
	keepColor: boolean?, -- usa su color aunque Config pida el color de peligro (bolas de fuego de jefes)
	visualSize: number?, -- se dibuja más grande que su hitbox
}

local EnemyProjCfg = Config.EnemyProjectile

local remotes
local half: Vector3 = Vector3.zero
local projectiles: { Projectile } = {}
local enemyProjectiles: { EnemyProjectile } = {}
local nextId = 0

-- Disparo manual: el cliente avisa si tiene el botón apretado y hacia dónde apunta.
-- Nunca se confía en nada más: el daño, la cadencia y el origen los pone el servidor.
function Combat.setTrigger(player: Player, holding: any, direction: any): boolean
	local state = PlayerData.get(player)
	if not state or not state.inMatch or state.life ~= "ALIVE" then
		return false
	end
	if type(holding) ~= "boolean" or typeof(direction) ~= "Vector3" then
		return false
	end
	-- Límite de frecuencia por segundo
	local clock = os.clock()
	if clock - (state.aimWindow or 0) >= 1 then
		state.aimWindow = clock
		state.aimMsgs = 0
	end
	state.aimMsgs = (state.aimMsgs or 0) + 1
	if state.aimMsgs > PlayerCfg.FireMessagesPerSecond then
		return false
	end
	-- Dirección: números reales, plana y de largo razonable
	if direction.X ~= direction.X or direction.Z ~= direction.Z or math.abs(direction.X) > 1.01 or math.abs(direction.Z) > 1.01 then
		return false
	end
	local dir = flat(direction)
	if dir.Magnitude < 0.1 or dir.Magnitude > 1.1 then
		return false
	end
	state.aimDir = dir.Unit
	if holding and not state.trigger then
		state.fireQueued = true -- un click corto también dispara, aunque llegue en la recarga
	end
	state.trigger = holding
	return true
end

function Combat.init(r, arenaHalf: Vector3)
	remotes = r
	half = arenaHalf
	SkillEffects.setRemotes(r)
	if r.AttackRequest then
		r.AttackRequest.OnServerEvent:Connect(Combat.setTrigger)
	end
end

local function rotateFlat(dir: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(dir)
end

-- Opciones de un proyectil del jugador (habilidades): damage (en vez del daño normal), pierce,
-- size (se ve más grande), wave (onda de la espada: no rebota ni explota), ghost (fantasma)
export type ShotOptions = { damage: number?, pierce: number?, size: number?, wave: boolean?, ghost: boolean? }

-- giant: Tiro cargado (flecha gigante: triple de daño y atraviesa todo). O una tabla de opciones.
local function spawnProjectile(player: Player, stats: PlayerData.Stats, origin: Vector3, dir: Vector3, giant: any?)
	local o: ShotOptions = if type(giant) == "table" then giant else {}
	local isGiant = giant == true
	local weapon = Weapons.get(stats.weaponId or stats.weapon)
	local damageMult = if weapon.Kind == "Ranged" then weapon.DamageMult else 1
	nextId += 1
	table.insert(projectiles, {
		id = nextId,
		owner = player,
		pos = origin,
		dir = dir,
		age = 0,
		damage = (o.damage or stats.damage * (if isGiant then 3 else 1)) * damageMult,
		critChance = stats.critChance,
		critMultiplier = stats.critMultiplier,
		pierce = o.pierce or (if isGiant then 999 else stats.pierce),
		bounces = if isGiant or o.wave or o.ghost then 0 else stats.ricochet,
		burn = stats.burn,
		farDamage = stats.farDamage or 0,
		source = if o.wave then "wave" else "arrow",
		hit = {},
	})
	local style = if isGiant then { size = 3 } elseif o.size or o.wave or o.ghost then { size = o.size, wave = o.wave, ghost = o.ghost } else nil
	if weapon.Kind == "Ranged" and weapon.Fx then
		style = style or {}
		style.weaponId = weapon.Id -- conservar el estilo aunque el dueño salga o cambie de arma
	end
	remotes.ProjectileFired:FireAllClients(nextId, origin, dir, ProjCfg.Speed, ProjCfg.Lifetime, player.UserId, style)
end

-- Una "ráfaga": flechas paralelas al frente + pares diagonales.
-- echo: es la repetición del Disparo doble (no cuenta como otro disparo)
local function fireVolley(target: PlayerData.Target, dir: Vector3, echo: boolean?)
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

	-- Flecha trasera (si son 2, se abren un poco)
	for i = 1, stats.backArrows or 0 do
		local spread = if (stats.backArrows or 0) > 1 then (i - (stats.backArrows + 1) / 2) * 12 else 0
		spawnProjectile(target.player, stats, origin, rotateFlat(-dir, spread))
	end

	-- Tiro cargado: cada N disparos, además, una flecha gigante
	local state = target.state
	if echo then
		return
	end
	state.attacks = (state.attacks or 0) + 1
	local weapon = Weapons.get(stats.weaponId or stats.weapon)
	if weapon.PiercingEvery and state.attacks % weapon.PiercingEvery == 0 then
		spawnProjectile(target.player, stats, origin, dir, { pierce = 999, size = 1.5 })
	end
	if (stats.chargedEvery or 0) > 0 and state.attacks % stats.chargedEvery == 0 then
		spawnProjectile(target.player, stats, origin, dir, true)
	end
	SkillEffects.afterVolley(target, dir) -- disparo doble, anillo de flechas
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

export type SwingOptions = {
	arc: number?, -- fuerza el arco (Torbellino: 360)
	uppercut: boolean?, -- lanza lejos y aturde
	now: number?,
}

-- Golpe cuerpo a cuerpo: pega a todos los enemigos dentro del arco frente al jugador.
-- Suma las habilidades del arma (hoja ancha/larga, ejecución, sed de sangre, combo, uppercut).
-- Devuelve cuántos golpeó.
-- Robo de vida curado en la ventana del último segundo, por jugador (tope de Config.Melee)
local lifestealWindow: { [any]: { start: number, healed: number } } = setmetatable({}, { __mode = "k" }) :: any

function Combat.meleeSwing(t: PlayerData.Target, dir: Vector3, weapon: any, opts: SwingOptions?): number
	local o = opts or {}
	local now = o.now or os.clock()
	local state = t.state
	local stats = state.stats
	local bonus = Weapons.MeleeBonus
	local range = weapon.Range + (stats.meleeRange or 0)
	local arc = o.arc or math.min(360, weapon.Arc + (stats.meleeArc or 0) + stats.diagonalPairs * bonus.DiagonalArc)
	if now < (state.burstUntil or 0) then
		arc = math.max(arc, 120) -- Ráfaga de mil puños
	end
	local minDot = math.cos(math.rad(arc / 2))
	-- Combo: se corta si pasó mucho desde el último golpe que pegó
	if now - (state.lastHitAt or 0) > 1.5 then
		state.combo = 0
	end
	local comboMult = 1 + math.min((state.combo or 0) * (stats.comboStep or 0), 0.5)
	local damage = stats.damage * weapon.DamageMult * comboMult
		* (1 + stats.frontArrows * bonus.FrontArrow + (stats.pierce + stats.ricochet) * bonus.PierceRicochet)
	local baseDamage = damage
	damage *= SkillEffects.swingMult(state) -- Contraataque
	local origin = flat(t.root.Position)
	local hits = 0
	local dealtTotal = 0
	local bossDealt = 0 -- parte del daño que fue a jefes (rinde menos robo de vida)
	for _, e in table.clone(Enemies.list) do
		if not e.alive or e.hidden then
			continue
		end
		local offset = flat(e.part.Position) - origin
		local d = offset.Magnitude
		if d > range + e.radius then
			continue
		end
		if d > e.radius + 1 and offset.Unit:Dot(dir) < minDot then
			continue
		end
		hits += 1
		local dealt = damage
		if (stats.executeBonus or 0) > 0 and e.health / e.maxHealth < 0.3 then
			dealt *= 1 + stats.executeBonus -- Ejecución
		end
		if stats.burn then
			Enemies.applyBurn(e, dealt * ProjCfg.BurnFraction * (1 + (stats.burnBonus or 0)), ProjCfg.BurnDuration, t.player)
		end
		dealt *= SkillEffects.hitMult(stats, e, "melee")
		local crit = math.random() < stats.critChance
		local amount = if crit then dealt * stats.critMultiplier else dealt
		Enemies.damage(e, amount, t.player, if crit then "crit" else "hit")
		dealtTotal += amount
		if e.isBoss then
			bossDealt += amount
		end
		-- Doble golpe (puños): pega otra vez
		if e.alive and SkillEffects.doubleHit(stats) then
			Enemies.damage(e, amount, t.player, if crit then "crit" else "hit")
			dealtTotal += amount
		end
		SkillEffects.onHit(t.player, stats, e, amount, "melee", origin)
		if not e.alive then
			-- Sed de sangre
			if (stats.healOnKill or 0) > 0 and t.humanoid.Health > 0 then
				t.humanoid.Health = math.min(t.humanoid.MaxHealth, t.humanoid.Health + stats.healOnKill)
			end
		elseif not e.isBoss then
			local push = if d > 0.01 then offset.Unit else dir
			local strength = Config.Frenzy.Knockback * weapon.Knockback * (if crit then 1.5 else 1)
			if o.uppercut then
				strength *= 3
				e.stunUntil = now + 0.5 -- Uppercut: aturdido
			end
			Enemies.knockback(e, push, strength)
		end
	end
	if hits > 0 then
		state.combo = (state.combo or 0) + 1
		state.lastHitAt = now
	end
	-- Robo de vida del cuerpo a cuerpo (Config.Melee.Lifesteal)
	local MeleeCfg = Config.Melee
	-- Con tope por segundo (LifestealMaxPerSecond) y la mitad contra jefes (LifestealBossMult).
	if MeleeCfg and dealtTotal > 0 and t.humanoid.Health > 0 and state.life == "ALIVE" then
		local efectivo = (dealtTotal - bossDealt) + bossDealt * (MeleeCfg.LifestealBossMult or 1)
		local cura = efectivo * MeleeCfg.Lifesteal
		local tope = MeleeCfg.LifestealMaxPerSecond
		if tope then
			local b = lifestealWindow[t.player]
			if not b or now - b.start >= 1 then
				b = { start = now, healed = 0 }
				lifestealWindow[t.player] = b
			end
			cura = math.min(cura, math.max(0, t.humanoid.MaxHealth * tope - b.healed))
			b.healed += cura
		end
		t.humanoid.Health = math.min(t.humanoid.MaxHealth, t.humanoid.Health + cura)
	end
	-- La espada corta los disparos enemigos que estén en el arco del tajo
	if MeleeCfg and MeleeCfg.SwordCutsProjectiles and Weapons.baseOf(weapon.Id) == "Sword" then
		for i = #enemyProjectiles, 1, -1 do
			local p = enemyProjectiles[i]
			local offset = flat(p.pos) - origin
			local d = offset.Magnitude
			if d <= range + p.radius + 1 and (d < 2 or offset.Unit:Dot(dir) >= minDot) then
				table.remove(enemyProjectiles, i)
				if remotes then
					remotes.ProjectileEnded:FireAllClients(p.id) -- el cliente lo hace estallar en chispas
				end
			end
		end
	end
	if remotes then
		remotes.MeleeSwing:FireAllClients(t.player.UserId, t.root.Position, dir, range, arc, weapon.Id)
	end
	SkillEffects.afterSwing(t, dir, baseDamage) -- onda cortante, golpe sísmico
	return hits
end

-- Poderes que se disparan solos cada tanto (las legendarias de cada arma).
local POWER_INTERVAL = { Bow = 6, Sword = 8, Fists = 10 }

local function fx(kind: string, owner: Player, pos: Vector3, radius: number)
	if remotes then
		remotes.MeleeSwing:FireAllClients(owner.UserId, pos, Vector3.zAxis, radius, 360, kind)
	end
end

local function updatePowers(t: PlayerData.Target, now: number)
	local state = t.state
	local stats = state.stats
	local active = (stats.weapon == "Bow" and stats.arrowRain)
		or (stats.weapon == "Sword" and stats.judgment)
		or (stats.weapon == "Fists" and stats.thousandFists)
	if not active then
		return
	end
	local interval = POWER_INTERVAL[stats.weapon] or 8
	if (state.nextPower or 0) == 0 then
		state.nextPower = now + interval
		return
	end
	if now < state.nextPower then
		return
	end
	local origin = t.root.Position
	if stats.weapon == "Bow" then
		-- Lluvia de flechas: hasta 8 enemigos cercanos
		local hit = 0
		for _, e in table.clone(Enemies.list) do
			if hit >= 8 then
				break
			end
			if e.alive and not e.hidden and (flat(e.part.Position) - flat(origin)).Magnitude <= 45 then
				hit += 1
				local crit = math.random() < stats.critChance
				fx("Rain", t.player, e.part.Position, 2)
				Enemies.damage(e, stats.damage * 1.5 * (if crit then stats.critMultiplier else 1), t.player, if crit then "crit" else "hit")
			end
		end
		if hit == 0 then
			return -- sin enemigos cerca: espera al próximo cuadro
		end
	elseif stats.weapon == "Sword" then
		-- Juicio: una espada gigante sobre el enemigo más cercano, aplasta en círculo
		local target = Enemies.nearest(origin, nil, 30)
		if not target then
			return
		end
		local center = flat(target.part.Position)
		local radius = 10
		fx("Judgment", t.player, target.part.Position, radius)
		local sword = Weapons.get(stats.weaponId or "Sword") -- con una espada especial, su daño
		for _, e in table.clone(Enemies.list) do
			if e.alive and not e.hidden and (flat(e.part.Position) - center).Magnitude <= radius + e.radius then
				Enemies.damage(e, stats.damage * sword.DamageMult * 3, t.player, "crit")
			end
		end
	else
		-- Ráfaga de mil puños: 2 s a velocidad triple
		state.burstUntil = now + 2
		fx("Burst", t.player, origin, 6)
	end
	state.nextPower = now + interval
end

local function updateAttacks(targets: { PlayerData.Target }, now: number)
	for _, t in targets do
		local state = t.state
		-- No ataca mientras elige habilidad.
		if state.currentOffer and Config.Progression.PauseWhileChoosing then
			continue
		end
		-- Agarrado (Grab): no ataca hasta que lo suelten
		if state.grabbed then
			continue
		end
		updatePowers(t, now)
		SkillEffects.update(t, now) -- poderes de las habilidades nuevas
		local weapon = Weapons.get(state.stats.weaponId or state.stats.weapon) -- especial: sus números
		local interval = state.stats.attackInterval * weapon.IntervalMult * SkillEffects.intervalMult(t)
		if now < (state.burstUntil or 0) then
			interval /= 3 -- Ráfaga de mil puños
		end
		if now - state.lastShot < interval then
			continue
		end
		if PlayerCfg.FireMode == "Manual" then
			local dir = state.aimDir
			if not dir or not (state.trigger or state.fireQueued) then
				continue
			end
			state.fireQueued = false
			state.lastShot = now
			if weapon.Kind == "Melee" then
				state.attacks = (state.attacks or 0) + 1
				local stats = state.stats
				Combat.meleeSwing(t, dir, weapon, {
					now = now,
					arc = if (stats.whirlEvery or 0) > 0 and state.attacks % stats.whirlEvery == 0 then 360 else nil,
					uppercut = (stats.uppercutEvery or 0) > 0 and state.attacks % stats.uppercutEvery == 0,
				})
			else
				fireVolley(t, dir)
			end
			continue
		end
		if weapon.Kind == "Melee" then
			-- El más cercano en alcance, en cualquier dirección (el golpe gira hacia él)
			local reach = weapon.Range + (state.stats.meleeRange or 0)
			local enemy = Enemies.nearest(t.root.Position, nil, reach + 8)
			local offset = enemy and flat(enemy.part.Position - t.root.Position)
			if enemy and offset and offset.Magnitude <= reach + enemy.radius then
				state.lastShot = now
				local dir = Vector3.zAxis
				if offset.Magnitude > 0.01 then
					dir = offset.Unit
				else
					local look = flat(t.root.CFrame.LookVector) -- encima del enemigo: hacia donde mira
					if look.Magnitude > 0.01 then
						dir = look.Unit
					end
				end
				state.attacks = (state.attacks or 0) + 1
				local stats = state.stats
				Combat.meleeSwing(t, dir, weapon, {
					now = now,
					arc = if (stats.whirlEvery or 0) > 0 and state.attacks % stats.whirlEvery == 0 then 360 else nil, -- Torbellino
					uppercut = (stats.uppercutEvery or 0) > 0 and state.attacks % stats.uppercutEvery == 0,
				})
			end
		else
			local enemy = pickTarget(t)
			local dir = enemy and flat(enemy.part.Position - t.root.Position).Unit
			if dir then
				state.lastShot = now
				fireVolley(t, dir)
			end
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
				-- Bonus de quemadura del conjunto Brasas (si el dueño sigue en el juego)
				local ownerState = PlayerData.get(p.owner)
				local burnBonus = if ownerState then ownerState.stats.burnBonus or 0 else 0
				Enemies.applyBurn(e, p.damage * ProjCfg.BurnFraction * (1 + burnBonus), ProjCfg.BurnDuration, p.owner)
			end
			-- Crítico: se sortea en cada impacto
			local crit = math.random() < p.critChance
			local damage = if crit then p.damage * p.critMultiplier else p.damage
			local ownerStats = PlayerData.get(p.owner)
			local skillStats = ownerStats and ownerStats.stats
			if skillStats then
				damage *= SkillEffects.hitMult(skillStats, e, p.source) -- Primera sangre
			end
			-- Ojo del cazador: más daño si el enemigo está lejos del arquero
			if p.farDamage > 0 then
				local ownerRoot = p.owner.Character and p.owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if ownerRoot and (flat(ownerRoot.Position) - flat(e.part.Position)).Magnitude > 30 then
					damage *= 1 + p.farDamage
				end
			end
			Enemies.damage(e, damage, p.owner, if crit then "crit" else "hit")
			if skillStats then
				SkillEffects.onHit(p.owner, skillStats, e, damage, p.source, p.pos)
			end
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
		size = o.visualSize or size,
		color = if EnemyProjCfg.UseDangerColor and not o.keepColor then EnemyProjCfg.Color else (o.color or EnemyProjCfg.Color),
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
				PlayerLife.damage(t, p.damage, "Disparo")
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

-- Las habilidades nuevas disparan flechas y ondas con las mismas funciones (SkillEffects)
SkillEffects.init(nil, Enemies, spawnProjectile, fireVolley)

return Combat
