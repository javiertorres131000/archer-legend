-- Enemies (ModuleScript)
-- Ubicación: ServerScriptService > Server > Enemies
-- Registro de enemigos: los crea, les aplica daño y los mueve.
-- Qué hace cada enemigo lo decide EnemyAI a partir de su definición en Data > EnemyTypes.
-- Son Parts anclados movidos con BulkMoveTo (sin Humanoid ni física): barato aunque haya muchos.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local EnemyTypes = require(script.Parent.Data.EnemyTypes)
local PlayerData = require(script.Parent.PlayerData)
local Ground = require(script.Parent.Ground)
local PlayerLife = require(script.Parent.PlayerLife)
local EnemyAI = require(script.Parent.EnemyAI)
local EnemyVisuals = require(script.Parent.EnemyVisuals)
local Grab = require(script.Parent.Grab)

local EnemyCfg = Config.Enemy
local flat = PlayerData.flat

local BURN_COLOR = Color3.fromRGB(255, 120, 20)

export type Enemy = {
	typeId: string,
	def: any, -- entrada de EnemyTypes
	part: Part,
	radius: number,
	height: number,
	baseY: number, -- altura del centro cuando está en el piso (o flotando)
	color: Color3,
	maxHealth: number,
	health: number,
	healthMult: number, -- se hereda a sus invocaciones e hijos
	dmgMult: number, -- multiplica todo el daño que hace
	contactDamage: number,
	xp: number,
	lastContact: number,
	barGui: BillboardGui,
	bar: Frame,
	alive: boolean,
	hidden: boolean, -- enterrado: no se lo puede golpear ni apuntar
	burnUntil: number,
	burnDps: number,
	burnOwner: Player?,
	summoner: any?, -- enemigo que lo invocó
	isBoss: boolean,
	golden: boolean, -- enemigo dorado: brilla y suelta mucho botín
	showBar: boolean,
	ai: any, -- estado de EnemyAI
	visual: any, -- EnemyVisuals: modelo u ojos
	farFor: number, -- segundos seguidos lejos de todos (para reubicarlo)
	stunUntil: number?, -- aturdido (Uppercut): no se mueve ni pega hasta entonces
	grabbing: Player?, -- jugador que tiene agarrado (Grab)
	grabHits: { [Player]: number }?, -- daño recibido mientras agarra (quién lo salvó)
	grabLockUntil: number?, -- no puede volver a agarrar hasta entonces
	bobPhase: number?, -- voladores: fase del vaivén (cada uno a su ritmo)
}

export type SpawnOptions = { healthMult: number?, dmgMult: number?, summoner: Enemy?, golden: boolean? }

-- (enemigo, quién pegó, daño real hecho, si murió, tipo de daño: "hit" | "burn")
type DamageCallback = (Enemy, Player?, number, boolean, string) -> ()

local Enemies = {}
Enemies.list = {} :: { Enemy }

local half: Vector3 = Vector3.zero
local folder: Folder
local damagedCallback: DamageCallback? = nil
local pending: { { typeId: string, pos: Vector3, opts: SpawnOptions } } = {}

function Enemies.init(arenaHalf: Vector3, combat, hazards)
	half = arenaHalf
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	EnemyAI.init(Enemies, combat, hazards)
	Grab.setKnockback(Enemies.knockback)
	-- Si hay carpeta de modelos, avisa una vez cuáles faltan (los que faltan usan la figura)
	local ids = {}
	for id in EnemyTypes do
		table.insert(ids, id)
	end
	local missing = EnemyVisuals.missing(ids, function(id)
		return EnemyTypes[id].Shape
	end)
	if #missing > 0 and #missing < #ids then
		print("[EnemyVisuals] Tipos sin modelo (usan la figura): " .. table.concat(missing, ", "))
	end
end

-- Se llama cada vez que un enemigo recibe daño (para XP, estadísticas, etc.)
function Enemies.onDamaged(callback: DamageCallback)
	damagedCallback = callback
end

function Enemies.getHalf(): Vector3
	return half
end

-- Mantiene un punto dentro de la arena, dejando `margin` contra las paredes.
-- Voladores: vaivén suave para arriba y para abajo, cada uno con su fase (según su id)
function Enemies.flyBob(enemy: Enemy, now: number): number
	if not enemy.def.Float or enemy.def.Float <= 0 then
		return 0
	end
	local phase = enemy.bobPhase or 0
	return math.sin(now * (EnemyCfg.FlyBobSpeed or 2) + phase) * (EnemyCfg.FlyBob or 0)
end

function Enemies.clampFlat(pos: Vector3, margin: number): Vector3
	return Vector3.new(math.clamp(pos.X, -half.X + margin, half.X - margin), 0, math.clamp(pos.Z, -half.Z + margin, half.Z - margin))
end

function Enemies.aliveCount(): number
	local n = #pending
	for _, e in Enemies.list do
		if e.alive then
			n += 1
		end
	end
	return n
end

-- Cuántas invocaciones de tipo typeId tiene vivas este enemigo.
function Enemies.countSummoned(summoner: Enemy, typeId: string): number
	local n = 0
	for _, e in Enemies.list do
		if e.alive and e.summoner == summoner and e.typeId == typeId then
			n += 1
		end
	end
	for _, p in pending do
		if p.opts.summoner == summoner and p.typeId == typeId then
			n += 1
		end
	end
	return n
end

local function createHealthBar(parent: BasePart, width: number, height: number): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(math.max(40, width * 12), 6)
	gui.StudsOffset = Vector3.new(0, height / 2 + 1, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return gui, fill
end

-- Un punto en una dirección dada (ángulo en radianes, en el plano) alrededor de `anchor`, a la
-- distancia de aparición, con un poco de desvío al azar. Si por ahí no hay lugar (pared,
-- otro jugador cerca), cualquier punto válido.
function Enemies.findSpawnPositionAt(targets: { PlayerData.Target }, anchor: PlayerData.Target, angle: number): Vector3?
	local margin = Config.Arena.SpawnMargin
	local maxX = half.X - margin
	local maxZ = half.Z - margin
	local around = flat(anchor.root.Position)
	for _ = 1, 8 do
		local a = angle + math.rad((math.random() - 0.5) * 50)
		local dist = EnemyCfg.MinSpawnDistance + math.random() * (EnemyCfg.MaxSpawnDistance - EnemyCfg.MinSpawnDistance)
		local pos = around + Vector3.new(math.cos(a), 0, math.sin(a)) * dist
		pos = Vector3.new(math.clamp(pos.X, -maxX, maxX), 0, math.clamp(pos.Z, -maxZ, maxZ))
		local ok = true
		for _, t in targets do
			if (flat(t.root.Position) - pos).Magnitude < EnemyCfg.MinSpawnDistance then
				ok = false
				break
			end
		end
		if ok then
			return pos
		end
	end
	return Enemies.findSpawnPosition(targets)
end

-- Un punto a una distancia razonable de algún jugador (ni encima ni del otro lado del mapa),
-- dentro del mapa y lejos de todos los demás jugadores.
function Enemies.findSpawnPosition(targets: { PlayerData.Target }): Vector3?
	local margin = Config.Arena.SpawnMargin
	local maxX = half.X - margin
	local maxZ = half.Z - margin
	for _ = 1, 16 do
		local pos
		if #targets > 0 then
			local around = flat(targets[math.random(1, #targets)].root.Position)
			local angle = math.random() * math.pi * 2
			local dist = EnemyCfg.MinSpawnDistance + math.random() * (EnemyCfg.MaxSpawnDistance - EnemyCfg.MinSpawnDistance)
			pos = around + Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
			pos = Vector3.new(math.clamp(pos.X, -maxX, maxX), 0, math.clamp(pos.Z, -maxZ, maxZ))
		else
			pos = Vector3.new(math.random() * 2 * maxX - maxX, 0, math.random() * 2 * maxZ - maxZ)
		end
		local ok = true
		for _, t in targets do
			if (flat(t.root.Position) - pos).Magnitude < EnemyCfg.MinSpawnDistance then
				ok = false
				break
			end
		end
		if ok then
			return pos
		end
	end
	return nil
end

-- Crea un enemigo ya mismo. pos: punto en el piso (Y se ignora).
function Enemies.spawn(typeId: string, pos: Vector3, opts: SpawnOptions?): Enemy
	local def = EnemyTypes[typeId]
	assert(def, "Tipo de enemigo desconocido: " .. tostring(typeId))
	local o = opts or {}
	local golden = o.golden == true and not def.Boss
	local healthMult = (o.healthMult or 1) * (if golden then Config.Frenzy.GoldenHealthMult else 1)
	local dmgMult = o.dmgMult or 1

	local size = def.Size or 3
	local height = def.Height or size
	local baseY = height / 2 + (def.Float or 0)
	local start = Enemies.clampFlat(pos, size / 2)

	local part = Instance.new("Part")
	part.Name = typeId
	part:SetAttribute("ThreatRole", def.Role or (if def.Boss then "Boss" else "Horde"))
	if def.Role == "Elite" then part:SetAttribute("Elite", true) end
	if def.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * size
	else
		part.Size = Vector3.new(size, height, size)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	local color = if golden then Color3.fromRGB(255, 200, 40) else def.Color
	part.Color = color
	part.Material = if def.Boss or golden then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(start.X, Ground.y(start.X, start.Z) + baseY, start.Z)
	local barGui, bar = createHealthBar(part, size, height)
	local showBar = def.Boss == true or golden or def.Role == "Elite" or EnemyCfg.HealthBars == "All"
	barGui.Enabled = showBar
	if def.Role == "Elite" then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, -18)
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Text = "ÉLITE"
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Parent = barGui
	end
	if golden then
		part.Name = "Golden" .. typeId
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 3
		light.Parent = part
	end
	part.Parent = folder

	local maxHealth = def.Health * healthMult
	local enemy: Enemy = {
		typeId = typeId,
		def = def,
		part = part,
		radius = size / 2,
		height = height,
		baseY = baseY,
		bobPhase = math.random() * math.pi * 2,
		color = color,
		maxHealth = maxHealth,
		health = maxHealth,
		healthMult = healthMult,
		dmgMult = dmgMult,
		contactDamage = (def.ContactDamage or 0) * dmgMult,
		xp = def.XP or 1,
		lastContact = 0,
		barGui = barGui,
		bar = bar,
		alive = true,
		hidden = false,
		burnUntil = 0,
		burnDps = 0,
		burnOwner = nil,
		summoner = o.summoner,
		isBoss = def.Boss == true,
		golden = golden,
		showBar = showBar,
		ai = nil,
		visual = nil,
		farFor = 0,
	}
	EnemyVisuals.attach(enemy)
	EnemyAI.setup(enemy)
	table.insert(Enemies.list, enemy)
	return enemy
end

-- Crea un enemigo al principio del próximo frame (seguro de usar mientras se recorre la lista).
function Enemies.queueSpawn(typeId: string, pos: Vector3, opts: SpawnOptions?)
	if Enemies.aliveCount() >= EnemyCfg.MaxAlive then return end
	table.insert(pending, { typeId = typeId, pos = pos, opts = opts or {} })
end

-- Empuja al enemigo en esa dirección (retroceso al recibir un flechazo).
function Enemies.knockback(enemy: Enemy, dir: Vector3, distance: number)
	if not enemy.alive or enemy.hidden or enemy.grabbing or distance <= 0 or dir.Magnitude < 0.01 then
		return -- el que te tiene agarrado no se despega por los golpes
	end
	local push = Vector3.new(dir.X, 0, dir.Z).Unit * distance
	local pos = Enemies.clampFlat(enemy.part.Position + push, enemy.radius)
	-- La orientación la vuelve a fijar Enemies.update en el próximo frame
	enemy.part.CFrame = CFrame.new(Vector3.new(pos.X, Ground.y(pos.X, pos.Z) + enemy.baseY, pos.Z))
end

-- Enterrado: invisible, no recibe golpes y no lo apunta nadie.
function Enemies.setHidden(enemy: Enemy, hidden: boolean)
	enemy.hidden = hidden
	EnemyVisuals.setTransparency(enemy, if hidden then 1 else 0)
	enemy.part:SetAttribute("Hidden", hidden or nil) -- el indicador del cliente se esconde
	enemy.barGui.Enabled = enemy.showBar and not hidden
end

-- Transparencia (0 visible · 0.5 teletransportándose · 1 invisible), con modelo u ojos incluidos.
function Enemies.setTransparency(enemy: Enemy, t: number)
	EnemyVisuals.setTransparency(enemy, t)
end

-- attacker: el jugador que hizo el daño (para estadísticas). Puede ser nil.
-- kind: "hit" (flecha) o "burn" (quemadura); solo cambia cómo se muestra el número.
function Enemies.damage(enemy: Enemy, amount: number, attacker: Player?, kind: string?)
	if not enemy.alive or enemy.hidden or amount <= 0 then
		return
	end
	local dealt = math.min(amount, enemy.health)
	-- Mientras agarra a alguien: quién le pega (para saber quién lo salvó)
	if enemy.grabbing and attacker and enemy.grabHits then
		enemy.grabHits[attacker] = (enemy.grabHits[attacker] or 0) + dealt
	end
	enemy.health -= amount
	enemy.bar.Size = UDim2.fromScale(math.max(enemy.health, 0) / enemy.maxHealth, 1)
	local killed = enemy.health <= 0
	if killed then
		enemy.alive = false
		local pos = enemy.part.Position
		EnemyAI.cleanup(enemy)
		enemy.part:Destroy()

		-- Se divide al morir (slimes, calaveras...)
		local split = enemy.def.OnDeath and enemy.def.OnDeath.Split
		if split then
			for i = 1, split.Count do
				local angle = math.rad(i * 360 / split.Count + math.random(0, 40))
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (enemy.radius + 1)
				Enemies.queueSpawn(split.Type, pos + offset, {
					healthMult = enemy.healthMult,
					dmgMult = enemy.dmgMult,
				})
			end
		end
	end
	if damagedCallback then
		damagedCallback(enemy, attacker, dealt, killed, kind or "hit")
	end
end

function Enemies.applyBurn(enemy: Enemy, dps: number, duration: number, owner: Player?)
	if not enemy.alive or enemy.hidden then
		return
	end
	enemy.burnUntil = os.clock() + duration
	enemy.burnDps = math.max(enemy.burnDps, dps)
	enemy.burnOwner = owner
	enemy.part.Color = BURN_COLOR
end

-- Color "normal" del enemigo (el de su tipo, o naranja si se está quemando).
function Enemies.baseColor(enemy: Enemy): Color3
	return if enemy.burnDps > 0 then BURN_COLOR else enemy.color
end

-- Enemigo vivo y visible más cercano a pos. exclude: enemigos a ignorar. maxDist: opcional.
function Enemies.nearest(pos: Vector3, exclude: { [Enemy]: boolean }?, maxDist: number?): (Enemy?, number)
	local best, bestDist = nil, maxDist or math.huge
	local p = flat(pos)
	for _, e in Enemies.list do
		if e.alive and not e.hidden and not (exclude and exclude[e]) then
			local d = (flat(e.part.Position) - p).Magnitude
			if d < bestDist then
				best, bestDist = e, d
			end
		end
	end
	return best, bestDist
end

function Enemies.clear()
	for _, e in Enemies.list do
		if e.alive then
			e.alive = false
			EnemyAI.cleanup(e)
			e.part:Destroy()
		end
	end
	table.clear(Enemies.list)
	table.clear(pending)
end

local function nearestTarget(pos: Vector3, targets: { PlayerData.Target }): (PlayerData.Target?, number)
	local best, bestDist = nil, math.huge
	for _, t in targets do
		local d = (flat(t.root.Position) - flat(pos)).Magnitude
		if d < bestDist then
			best, bestDist = t, d
		end
	end
	return best, bestDist
end

-- frozen = true cuando todos los jugadores están eligiendo habilidad (pausa).
function Enemies.update(dt: number, targets: { PlayerData.Target }, now: number, frozen: boolean)
	-- Crear los que quedaron en cola (divisiones, invocaciones)
	if #pending > 0 then
		local batch = pending
		pending = {}
		for _, p in batch do
			Enemies.spawn(p.typeId, p.pos, p.opts)
		end
	end

	-- Sacar de la lista los que murieron
	for i = #Enemies.list, 1, -1 do
		if not Enemies.list[i].alive then
			table.remove(Enemies.list, i)
		end
	end
	if frozen then
		return
	end

	-- Quemaduras (pueden matar, por eso se procesan antes de mover)
	for _, e in Enemies.list do
		if e.alive and e.burnDps > 0 then
			if now >= e.burnUntil then
				e.burnDps = 0
				e.part.Color = e.color
			else
				Enemies.damage(e, e.burnDps * dt, e.burnOwner, "burn")
			end
		end
	end

	-- Grilla espacial: la separación sólo compara celdas vecinas.
	local cellSize, maxRadius = 12, 0
	local grid = {}
	for _, e in Enemies.list do
		if e.alive and not e.hidden then
			maxRadius = math.max(maxRadius, e.radius)
			local x, z = math.floor(e.part.Position.X / cellSize), math.floor(e.part.Position.Z / cellSize)
			local key = x .. ":" .. z
			grid[key] = grid[key] or {}
			table.insert(grid[key], e)
		end
	end
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	for _, e in Enemies.list do
		if not e.alive then
			continue
		end
		local pos = flat(e.part.Position)

		-- Muy lejos de todos por un rato (deambula, se quedó quieto, el equipo se fue): reaparece
		-- a una distancia normal de alguien. Así nunca hay que salir a buscar al último.
		if #targets > 0 and not e.hidden then
			local _, far = nearestTarget(pos, targets)
			local still = e.def.Move ~= nil and e.def.Move.Type == "Still"
			if far > (if still then EnemyCfg.StillLeashDistance else EnemyCfg.LeashDistance) then
				e.farFor += dt
				if e.farFor >= EnemyCfg.LeashTime then
					e.farFor = 0
					local spot = Enemies.findSpawnPosition(targets)
					if spot then
						pos = Enemies.clampFlat(spot, e.radius)
						e.part.CFrame = CFrame.new(pos.X, Ground.y(pos.X, pos.Z) + e.baseY, pos.Z)
					end
				end
			else
				e.farFor = 0
			end
		end

		-- La IA decide adónde ir, hacia dónde mirar y si se separa de los demás.
		-- Aturdido: se queda quieto.
		local stunned = e.stunUntil ~= nil and now < e.stunUntil
		local desired, facing, separate
		local holding = if e.grabbing then Grab.holdPosition(e) else nil
		if holding then
			-- Tiene a alguien agarrado: se queda pegado a él, mirándolo
			local victim = (e.grabbing :: Player).Character
			local victimRoot = victim and victim:FindFirstChild("HumanoidRootPart") :: BasePart?
			desired, separate = holding, false
			facing = if victimRoot then flat(victimRoot.Position - holding) else nil
			if facing and facing.Magnitude < 0.01 then
				facing = nil
			end
		elseif stunned then
			desired, facing, separate = pos, nil, false
		else
			desired, facing, separate = EnemyAI.step(e, dt, targets)
		end

		if separate then
			local push = Vector3.zero
			local cx, cz = math.floor(pos.X / cellSize), math.floor(pos.Z / cellSize)
			local cells = math.ceil((e.radius + maxRadius + EnemyCfg.SeparationPadding) / cellSize)
			for x = cx - cells, cx + cells do
			for z = cz - cells, cz + cells do
			for _, other in grid[x .. ":" .. z] or {} do
				if other ~= e and other.alive and not other.hidden then
					local away = pos - flat(other.part.Position)
					local d = away.Magnitude
					local minDist = e.radius + other.radius + EnemyCfg.SeparationPadding
					if d > 0.01 and d < minDist then
						push += away.Unit * (minDist - d) * 4
					end
				end
			end
			end
			end
			desired += push * dt
		end

		local newPos = Enemies.clampFlat(desired, e.radius)
		-- Caminan sobre el relieve: la altura sale del piso en ese punto
		local y = Ground.y(newPos.X, newPos.Z) + e.baseY + (e.ai.yOffset or 0) + Enemies.flyBob(e, now)
		local look = if facing and facing.Magnitude > 0.01 then facing.Unit else e.part.CFrame.LookVector
		local center = Vector3.new(newPos.X, y, newPos.Z)
		table.insert(parts, e.part)
		table.insert(cframes, CFrame.lookAt(center, center + Vector3.new(look.X, 0, look.Z)))
		EnemyVisuals.sync(e)

		-- Daño por contacto
		if not e.hidden and not stunned and e.contactDamage > 0 then
			local target, dist = nearestTarget(newPos, targets)
			-- Con relieve: no pega a alguien que está arriba de una meseta (o abajo)
			local sameLevel = target ~= nil and math.abs(target.root.Position.Y - y) <= e.height / 2 + 4
			if target and sameLevel and dist <= e.radius + 1.5 and now - e.lastContact >= EnemyCfg.ContactCooldown then
				e.lastContact = now
				PlayerLife.damage(target, e.contactDamage)
			end
		end
	end

	-- Mover todos de una vez es mucho más barato que asignar CFrame uno por uno.
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return Enemies
