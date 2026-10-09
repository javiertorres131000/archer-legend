-- Enemies (ModuleScript)
-- Ubicación: ServerScriptService > Server > Enemies
-- Registro de enemigos: los crea, les aplica daño y los mueve.
-- Qué hace cada enemigo lo decide EnemyAI a partir de su definición en Data > EnemyTypes.
-- Son Parts anclados movidos con BulkMoveTo (sin Humanoid ni física): barato aunque haya muchos.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local EnemyTypes = require(script.Parent.Data.EnemyTypes)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local EnemyAI = require(script.Parent.EnemyAI)

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
	ai: any, -- estado de EnemyAI
}

export type SpawnOptions = { healthMult: number?, dmgMult: number?, summoner: Enemy? }

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
end

-- Se llama cada vez que un enemigo recibe daño (para XP, estadísticas, etc.)
function Enemies.onDamaged(callback: DamageCallback)
	damagedCallback = callback
end

function Enemies.getHalf(): Vector3
	return half
end

-- Mantiene un punto dentro de la arena, dejando `margin` contra las paredes.
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

function Enemies.findSpawnPosition(targets: { PlayerData.Target }): Vector3?
	local margin = Config.Arena.SpawnMargin
	local maxX = half.X - margin
	local maxZ = half.Z - margin
	for _ = 1, 12 do
		local pos = Vector3.new(math.random() * 2 * maxX - maxX, 0, math.random() * 2 * maxZ - maxZ)
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
	local healthMult = o.healthMult or 1
	local dmgMult = o.dmgMult or 1

	local size = def.Size or 3
	local height = def.Height or size
	local baseY = height / 2 + (def.Float or 0)
	local start = Enemies.clampFlat(pos, size / 2)

	local part = Instance.new("Part")
	part.Name = typeId
	if def.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * size
	else
		part.Size = Vector3.new(size, height, size)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Color = def.Color
	part.Material = if def.Boss then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(start.X, baseY, start.Z)
	local barGui, bar = createHealthBar(part, size, height)
	part.Parent = folder

	local maxHealth = def.Health * healthMult
	local enemy: Enemy = {
		typeId = typeId,
		def = def,
		part = part,
		radius = size / 2,
		height = height,
		baseY = baseY,
		color = def.Color,
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
		ai = nil,
	}
	EnemyAI.setup(enemy)
	table.insert(Enemies.list, enemy)
	return enemy
end

-- Crea un enemigo al principio del próximo frame (seguro de usar mientras se recorre la lista).
function Enemies.queueSpawn(typeId: string, pos: Vector3, opts: SpawnOptions?)
	table.insert(pending, { typeId = typeId, pos = pos, opts = opts or {} })
end

-- Enterrado: invisible, no recibe golpes y no lo apunta nadie.
function Enemies.setHidden(enemy: Enemy, hidden: boolean)
	enemy.hidden = hidden
	enemy.part.Transparency = if hidden then 1 else 0
	enemy.barGui.Enabled = not hidden
end

-- attacker: el jugador que hizo el daño (para estadísticas). Puede ser nil.
-- kind: "hit" (flecha) o "burn" (quemadura); solo cambia cómo se muestra el número.
function Enemies.damage(enemy: Enemy, amount: number, attacker: Player?, kind: string?)
	if not enemy.alive or enemy.hidden or amount <= 0 then
		return
	end
	local dealt = math.min(amount, enemy.health)
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

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	for _, e in Enemies.list do
		if not e.alive then
			continue
		end
		local pos = flat(e.part.Position)

		-- La IA decide adónde ir, hacia dónde mirar y si se separa de los demás.
		local desired, facing, separate = EnemyAI.step(e, dt, targets)

		if separate then
			local push = Vector3.zero
			for _, other in Enemies.list do
				if other ~= e and other.alive and not other.hidden then
					local away = pos - flat(other.part.Position)
					local d = away.Magnitude
					local minDist = e.radius + other.radius + EnemyCfg.SeparationPadding
					if d > 0.01 and d < minDist then
						push += away.Unit * (minDist - d) * 4
					end
				end
			end
			desired += push * dt
		end

		local newPos = Enemies.clampFlat(desired, e.radius)
		local y = e.baseY + (e.ai.yOffset or 0)
		local look = if facing and facing.Magnitude > 0.01 then facing.Unit else e.part.CFrame.LookVector
		local center = Vector3.new(newPos.X, y, newPos.Z)
		table.insert(parts, e.part)
		table.insert(cframes, CFrame.lookAt(center, center + Vector3.new(look.X, 0, look.Z)))

		-- Daño por contacto
		if not e.hidden and e.contactDamage > 0 then
			local target, dist = nearestTarget(newPos, targets)
			if target and dist <= e.radius + 1.5 and now - e.lastContact >= EnemyCfg.ContactCooldown then
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
