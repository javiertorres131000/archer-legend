-- SkillEffects (ModuleScript)
-- Ubicación: ServerScriptService > Server > SkillEffects
-- Efectos de las habilidades nuevas (Shared/Skills.lua) que no son un número de stats:
-- rayo en cadena, escudo de maná, esquiva, explosiones, ondas, anillo de flechas, poderes que
-- se disparan solos (flecha fantasma, danza de espadas, puño del dragón) y el tajo del dash.
-- Todo lo decide el servidor; los clientes solo dibujan lo que avisa Remotes.SkillFx:
--   (tipo, posición, a, b) · "Chain" (desde, hasta) · "Blast" (centro, radio) · "Wave"
--   (centro, radio) · "Blades" (centro del jugador, radio) · "Dragon" (origen, dirección)
--   · "Shield" (posición del jugador, encendido) · "Dodge" (posición)
--
-- Quién llama a quién:
--   Combat: init (le pasa Enemies y cómo disparar), hitMult/onHit en cada golpe, afterSwing,
--     afterVolley, intervalMult y update en cada cuadro.
--   PlayerLife.damage: incoming (esquiva, escudo, armadura, contraataque).
--   Run (al morir un enemigo): onKill (vampirismo y cadáver explosivo).
-- No requiere Enemies ni PlayerLife arriba (PlayerLife lo requiere a él): Enemies llega en init.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Weapons"))
local UltimateService = require(script.Parent.UltimateService)

local ProjCfg = Config.Projectile
local flat = PlayerData.flat

local SkillEffects = {}

local Enemies: any = nil
local remotes: any = nil
-- Lo que presta Combat: disparar una flecha del jugador con opciones y una ráfaga normal
local shoot: ((player: Player, stats: any, origin: Vector3, dir: Vector3, opts: any) -> ())? = nil
local volley: ((t: any, dir: Vector3) -> ())? = nil

function SkillEffects.setRemotes(r: any)
	remotes = r
end

function SkillEffects.init(r: any, enemies: any, shootFn: any, volleyFn: any)
	remotes = r or remotes
	Enemies = enemies
	shoot = shootFn
	volley = volleyFn
end

local function fx(kind: string, pos: Vector3, a: any, b: any)
	if remotes and remotes.SkillFx then
		remotes.SkillFx:FireAllClients(kind, pos, a, b)
	end
end

local function rollCrit(stats: any, amount: number): (number, boolean)
	local crit = math.random() < stats.critChance
	return if crit then amount * stats.critMultiplier else amount, crit
end

-- Daño en círculo a todos los vivos (salvo `skip`). kind: cómo se muestra el número.
local function blast(owner: Player, center: Vector3, radius: number, amount: number, kind: string, skip: any?)
	local c = flat(center)
	for _, e in table.clone(Enemies.list) do
		if e ~= skip and e.alive and not e.hidden and (flat(e.part.Position) - c).Magnitude <= radius + e.radius then
			Enemies.damage(e, amount, owner, kind)
		end
	end
end
SkillEffects.blast = blast

---------------------------------------------------------------------
-- Poderes de las armas especiales (campo Power en Shared/Weapons.lua)
-- Lo que se ve (fuego, rayos, esferas, grietas) ahora también hace daño de verdad:
--   Burn / Bleed: cada golpe quema / hace sangrar (fracción del golpe por segundo, 3 s)
--   Slow: cada golpe frena al enemigo
--   ChainChance: el golpe salta como rayo a ChainTargets enemigos cercanos (ChainMult del daño)
--   Finisher: el remate: el 3er tajo del combo (como SwingCombo del cliente) o cada Every golpes
--     Kind "Blast": explosión de radio Radius, Ahead studs adelante, Mult del daño
--     Kind "Strike": rayos que caen sobre Targets enemigos a menos de Range, Mult del daño
--     Kind "Eruption": el piso erupciona alrededor del jugador (Radius, Mult, quema con Burn)
--   StrikeEvery (arcos): cada N impactos cae un rayo con explosión (StrikeRadius, StrikeMult)
--   Rift (arcos): cada impacto abre una grieta que daña (DpsMult) y atrae (Pull) un rato
---------------------------------------------------------------------

type Rift = { pos: Vector3, untilT: number, tick: number, dps: number, radius: number, pull: number, color: Color3 }
type WeaponState = { combo: number, lastSwing: number, hits: number, rifts: { Rift } }
local weaponStates: { [Player]: WeaponState } = setmetatable({}, { __mode = "k" }) :: any
local COMBO_RESET = 1.2 -- igual que SwingCombo.RESET del cliente

local function wstate(p: Player): WeaponState
	local s = weaponStates[p]
	if not s then
		s = { combo = 0, lastSwing = 0, hits = 0, rifts = {} }
		weaponStates[p] = s
	end
	return s
end

local function powerOf(owner: Player?): any
	if not owner then
		return nil
	end
	local id = owner:GetAttribute("Weapon")
	local def = if type(id) == "string" then Weapons.ById[id] else nil
	return def and def.Power
end

-- Daño en área con quemadura opcional (fracción del golpe por segundo)
local function area(owner: Player, center: Vector3, radius: number, amount: number, burnFrac: number?)
	local c = flat(center)
	for _, e in table.clone(Enemies.list) do
		if e.alive and not e.hidden and (flat(e.part.Position) - c).Magnitude <= radius + e.radius then
			Enemies.damage(e, amount, owner, "crit")
			if burnFrac and e.alive then
				Enemies.applyBurn(e, amount * burnFrac, 3, owner)
			end
		end
	end
end

local function chainFrom(owner: Player, e: any, dealt: number, targets: number, mult: number, range: number)
	local from = e.part.Position
	local hit: { [any]: boolean } = { [e] = true }
	for _ = 1, targets do
		local n = Enemies.nearest(from, hit, range)
		if not n then
			break
		end
		hit[n] = true
		local to = n.part.Position
		fx("Chain", from, to)
		Enemies.damage(n, dealt * mult, owner, "hit")
		from = to
	end
end

local function weaponOnHit(owner: Player, e: any, dealt: number, source: string)
	local power = powerOf(owner)
	if not power or (source ~= "melee" and source ~= "arrow") then
		return
	end
	local pos = e.part.Position
	if e.alive then
		if power.Burn then
			Enemies.applyBurn(e, dealt * power.Burn, 3, owner)
		end
		if power.Bleed then
			Enemies.applyBurn(e, dealt * power.Bleed, 3, owner)
		end
		if power.Slow then
			e.slowUntil = os.clock() + 2
			e.slowAmount = math.max(e.slowAmount or 0, power.Slow)
		end
	end
	if power.ChainChance and math.random() < power.ChainChance then
		chainFrom(owner, e, dealt, power.ChainTargets or 2, power.ChainMult or 0.4, power.ChainRange or 14)
	end
	if source == "arrow" and power.StrikeEvery then
		local s = wstate(owner)
		s.hits += 1
		if s.hits % power.StrikeEvery == 0 then
			fx("Chain", pos + Vector3.new(0, 45, 0), pos)
			fx("Blast", pos, power.StrikeRadius, power.Color)
			area(owner, pos, power.StrikeRadius, dealt * power.StrikeMult)
		end
	end
	if source == "arrow" and power.Rift then
		local r = power.Rift
		local s = wstate(owner)
		if #s.rifts >= r.Max then
			table.remove(s.rifts, 1)
		end
		table.insert(s.rifts, { pos = flat(pos), untilT = os.clock() + r.Duration, tick = 0, dps = dealt * r.DpsMult, radius = r.Radius, pull = r.Pull, color = power.Color })
		fx("Blast", pos, r.Radius, power.Color)
	end
end

local function weaponFinisher(t: any, dir: Vector3, damage: number)
	local power = powerOf(t.player)
	local f = power and power.Finisher
	if not f then
		return
	end
	local s = wstate(t.player)
	local now = os.clock()
	if now - s.lastSwing > COMBO_RESET then
		s.combo = 0
	end
	s.lastSwing = now
	s.combo += 1
	if s.combo < (f.Every or 3) then
		return
	end
	s.combo = 0
	local origin = t.root.Position
	if f.Kind == "Blast" then
		local center = origin + Vector3.new(dir.X, 0, dir.Z).Unit * (f.Ahead or 5)
		fx("Blast", center, f.Radius, power.Color)
		area(t.player, center, f.Radius, damage * f.Mult, power.Burn)
	elseif f.Kind == "Eruption" then
		fx("Wave", origin, f.Radius, power.Color)
		fx("Blast", origin, f.Radius * 0.6, power.Color)
		area(t.player, origin, f.Radius, damage * f.Mult, power.Burn)
	elseif f.Kind == "Strike" then
		local hit: { [any]: boolean } = {}
		for _ = 1, f.Targets do
			local e = Enemies.nearest(origin, hit, f.Range)
			if not e then
				break
			end
			hit[e] = true
			local pos = e.part.Position
			fx("Chain", pos + Vector3.new(0, 45, 0), pos)
			fx("Blast", pos, 4, power.Color)
			area(t.player, pos, 4, damage * f.Mult)
		end
	end
end

local function updateRifts(t: any, now: number)
	local s = weaponStates[t.player]
	if not s or #s.rifts == 0 then
		return
	end
	for i = #s.rifts, 1, -1 do
		local r = s.rifts[i]
		if now >= r.untilT then
			table.remove(s.rifts, i)
		elseif now >= r.tick then
			r.tick = now + 0.5
			for _, e in table.clone(Enemies.list) do
				if e.alive and not e.hidden then
					local offset = r.pos - flat(e.part.Position)
					if offset.Magnitude <= r.radius + e.radius then
						Enemies.damage(e, r.dps * 0.5, t.player, "hit")
						if e.alive and not e.isBoss and offset.Magnitude > 0.5 then
							Enemies.knockback(e, offset.Unit, math.min(offset.Magnitude, r.pull * 0.5)) -- la grieta los atrae
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Golpes
---------------------------------------------------------------------

-- Multiplicador de daño de un golpe ANTES de pegar. source: "melee" | "arrow"
function SkillEffects.hitMult(stats: any, e: any, source: string): number
	local mult = 1
	if (stats.firstStrike or 0) > 0 and e.health >= e.maxHealth then
		mult *= 1 + stats.firstStrike -- Primera sangre
	end
	return mult
end

-- Después de pegar (el enemigo puede haber muerto). dealt: daño de ese golpe.
function SkillEffects.onHit(owner: Player, stats: any, e: any, dealt: number, source: string, origin: Vector3?)
	local now = os.clock()
	local pos = e.part.Position
	if e.alive then
		-- Toque helado: lo frena
		if (stats.slowOnHit or 0) > 0 then
			e.slowUntil = now + 2
			e.slowAmount = math.max(e.slowAmount or 0, stats.slowOnHit)
		end
		-- Rompeguardias: recibe más daño de todos
		if (stats.armorBreak or 0) > 0 then
			e.vuln = math.min(stats.armorBreak * 5, (e.vuln or 0) + stats.armorBreak)
		end
		-- Herida profunda: sangra (usa la quemadura del enemigo)
		if (stats.bleed or 0) > 0 and source == "melee" then
			Enemies.applyBurn(e, dealt * stats.bleed, 3, owner)
		end
	end
	-- Flechas explosivas
	if source == "arrow" and (stats.explosiveArrow or 0) > 0 then
		local radius = 4 + (stats.explosiveRadiusBonus or 0)
		fx("Blast", pos, radius, Color3.fromRGB(255, 150, 60))
		blast(owner, pos, radius, dealt * stats.explosiveArrow, "hit", if e.alive then e else nil)
	end
	-- Rayo en cadena: salta a 3 enemigos cercanos
	if (stats.chainChance or 0) > 0 and math.random() < stats.chainChance then
		local from = pos
		local hit: { [any]: boolean } = { [e] = true }
		for _ = 1, 3 do
			local nextEnemy = Enemies.nearest(from, hit, 14)
			if not nextEnemy then
				break
			end
			hit[nextEnemy] = true
			local to = nextEnemy.part.Position
			fx("Chain", from, to)
			Enemies.damage(nextEnemy, dealt * 0.5, owner, "hit")
			from = to
		end
	end
	-- Poder del arma especial (fuego, sangrado, rayos, grietas...)
	weaponOnHit(owner, e, dealt, source)
	-- Cada golpe carga la definitiva del arma
	if source == "melee" or source == "arrow" then
		UltimateService.addCharge(owner)
	end
end

---------------------------------------------------------------------
-- Muertes
---------------------------------------------------------------------

function SkillEffects.onKill(attacker: Player?, enemy: any, kind: string?, pos: Vector3)
	if not attacker then
		return
	end
	local state = PlayerData.get(attacker)
	if not state or not state.inMatch then
		return
	end
	local stats = state.stats
	-- Vampirismo
	if (stats.lifeOnKill or 0) > 0 then
		local humanoid = attacker.Character and attacker.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and state.life == "ALIVE" then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + stats.lifeOnKill)
		end
	end
	-- Cadáver explosivo (una explosión no hace explotar a otra: sin reacciones infinitas)
	if (stats.explodeOnKill or 0) > 0 and kind ~= "blast" then
		local radius = stats.explodeRadius or 6
		fx("Blast", pos, radius, Color3.fromRGB(255, 110, 70))
		blast(attacker, pos, radius, stats.damage * stats.explodeOnKill, "blast")
	end
end

---------------------------------------------------------------------
-- Daño recibido
---------------------------------------------------------------------

-- Devuelve el daño que realmente entra (0 = lo esquivó o lo bloqueó).
function SkillEffects.incoming(target: any, amount: number): number
	local state = target.state
	local stats = state.stats
	local now = os.clock()
	local pos = target.root.Position
	if (stats.dodge or 0) > 0 and math.random() < math.min(0.6, stats.dodge) then
		fx("Dodge", pos)
		return 0
	end
	if (stats.shieldInterval or 0) > 0 then
		state.shieldReadyAt = state.shieldReadyAt or 0
		if now >= (state.shieldReadyAt :: number) then
			state.shieldReadyAt = now + stats.shieldInterval
			target.player:SetAttribute("ShieldReadyAt", workspace:GetServerTimeNow() + stats.shieldInterval)
			fx("Shield", pos, false)
			return 0
		end
	end
	if (stats.riposte or 0) > 0 then
		state.riposteReady = true -- Contraataque: el próximo tajo pega más
	end
	return amount * (stats.damageTaken or 1)
end

---------------------------------------------------------------------
-- Ataques
---------------------------------------------------------------------

-- Multiplica el tiempo entre ataques (menos = más rápido)
function SkillEffects.intervalMult(t: any): number
	local stats = t.state.stats
	local mult = 1
	if (stats.stillSpeed or 0) > 0 then
		local v = t.root.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude < 2 then
			mult /= 1 + stats.stillSpeed -- Pulso firme
		end
	end
	if (stats.adrenaline or 0) > 0 and t.humanoid.Health < t.humanoid.MaxHealth * 0.5 then
		mult /= 1 + stats.adrenaline -- Adrenalina
	end
	return mult
end

-- Daño extra de un tajo entero (contraataque). Lo consume.
function SkillEffects.swingMult(state: any): number
	if state.riposteReady and (state.stats.riposte or 0) > 0 then
		state.riposteReady = false
		return 1 + state.stats.riposte
	end
	return 1
end

-- ¿Este golpe de puños pega dos veces?
function SkillEffects.doubleHit(stats: any): boolean
	return (stats.doubleHit or 0) > 0 and math.random() < stats.doubleHit
end

-- Después de cada tajo o golpe (cuerpo a cuerpo). damage: daño base del golpe.
function SkillEffects.afterSwing(t: any, dir: Vector3, damage: number)
	weaponFinisher(t, dir, damage) -- remate del arma especial (3er tajo)
	local state = t.state
	local stats = state.stats
	local attacks = state.attacks or 0
	-- Onda cortante: proyectil que atraviesa todo
	if (stats.slashWaveEvery or 0) > 0 and attacks % stats.slashWaveEvery == 0 and shoot then
		shoot(t.player, stats, t.root.Position, dir, { damage = damage * 0.8, pierce = 999, size = 3.5, wave = true })
	end
	-- Golpe sísmico
	if (stats.shockEvery or 0) > 0 and attacks % stats.shockEvery == 0 then
		local radius = stats.shockRadius or 8
		fx("Wave", t.root.Position, radius, Color3.fromRGB(255, 190, 110))
		blast(t.player, t.root.Position, radius, damage, "hit")
	end
end

-- Después de cada ráfaga de flechas
function SkillEffects.afterVolley(t: any, dir: Vector3, isEcho: boolean?)
	local state = t.state
	local stats = state.stats
	-- Disparo doble: la misma ráfaga otra vez enseguida
	if stats.doubleShot and not isEcho and volley then
		task.delay(0.12, function()
			if state.inMatch and state.life == "ALIVE" and t.root.Parent then
				(volley :: any)(t, dir, true)
			end
		end)
	end
	-- Anillo de flechas
	if (stats.ringEvery or 0) > 0 and not isEcho and (state.attacks or 0) % stats.ringEvery == 0 and shoot then
		for i = 0, 11 do
			local a = math.rad(i * 30)
			shoot(t.player, stats, t.root.Position, Vector3.new(math.sin(a), 0, math.cos(a)), {})
		end
	end
end

---------------------------------------------------------------------
-- Poderes que se disparan solos y el tajo del dash (cada cuadro)
---------------------------------------------------------------------

function SkillEffects.update(t: any, now: number)
	updateRifts(t, os.clock()) -- grietas del Arco del Vacío
	local state = t.state
	local stats = state.stats
	local origin = t.root.Position
	-- Flecha fantasma
	if stats.phantomArrow and shoot then
		if now >= (state.nextPhantom or 0) then
			local target = Enemies.nearest(origin, nil, 60)
			if target then
				state.nextPhantom = now + (stats.phantomInterval or 3)
				local dir = flat(target.part.Position - origin)
				if dir.Magnitude > 0.01 then
					shoot(t.player, stats, origin, dir.Unit, { damage = stats.damage * 2.5, pierce = 999, size = 3, ghost = true })
				end
			end
		end
	end
	-- Danza de espadas: cada 0,4 s, corte a los que estén a menos de 8 studs
	if stats.bladeDance and now >= (state.nextDance or 0) then
		state.nextDance = now + 0.4
		local any = false
		for _, e in Enemies.list do
			if e.alive and not e.hidden and (flat(e.part.Position) - flat(origin)).Magnitude <= 8 + e.radius then
				any = true
				break
			end
		end
		if any then
			fx("Blades", origin, 8)
			blast(t.player, origin, 8, stats.damage * 0.5, "hit")
		end
	end
	-- Puño del dragón: onda en cono de 20 studs hacia el enemigo más cercano
	if stats.dragonFist then
		if (state.nextDragon or 0) == 0 then
			state.nextDragon = now + 12
		elseif now >= (state.nextDragon :: number) then
			local target = Enemies.nearest(origin, nil, 20)
			if target then
				state.nextDragon = now + 12
				local dir = flat(target.part.Position - origin)
				dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zAxis
				fx("Dragon", origin, dir, 20)
				local minDot = math.cos(math.rad(35))
				for _, e in table.clone(Enemies.list) do
					if e.alive and not e.hidden then
						local offset = flat(e.part.Position - origin)
						local d = offset.Magnitude
						if d <= 20 + e.radius and (d < 1 or offset.Unit:Dot(dir) >= minDot) then
							local amount, crit = rollCrit(stats, stats.damage * 5)
							Enemies.damage(e, amount, t.player, if crit then "crit" else "hit")
							if e.alive and not e.isBoss then
								Enemies.knockback(e, dir, 8)
							end
						end
					end
				end
			end
		end
	end
	-- Tajo veloz: durante el dash corta a los que atraviesa (una vez por dash)
	if (stats.dashSlash or 0) > 0 and now < (state.dashUntil or 0) then
		if state.dashSlashId ~= state.dashUntil then
			state.dashSlashId = state.dashUntil
			state.dashHit = {}
		end
		for _, e in table.clone(Enemies.list) do
			if e.alive and not e.hidden and not state.dashHit[e] and (flat(e.part.Position) - flat(origin)).Magnitude <= 3.5 + e.radius then
				state.dashHit[e] = true
				local amount, crit = rollCrit(stats, stats.damage * stats.dashSlash)
				fx("Blast", e.part.Position, 2, Color3.fromRGB(220, 240, 255))
				Enemies.damage(e, amount, t.player, if crit then "crit" else "hit")
			end
		end
	end
end

return SkillEffects
