-- Enemies (ModuleScript)
-- Ubicación: ServerScriptService > Server > Enemies
-- Registro de enemigos: los crea, les aplica daño y los mueve.
-- Qué hace cada enemigo lo decide EnemyAI a partir de su definición en Data > EnemyTypes.
-- Son Parts anclados movidos con BulkMoveTo (sin Humanoid ni física): barato aunque haya muchos.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local EnemyTypes = require(script.Parent.Data.EnemyTypes)
local PlayerData = require(script.Parent.PlayerData)
local Ground = require(script.Parent.Ground)
local ServerStorage = game:GetService("ServerStorage")
local PlayerLife = require(script.Parent.PlayerLife)
local EnemyAI = require(script.Parent.EnemyAI)

local EnemyCfg = Config.Enemy
local flat = PlayerData.flat

local BURN_COLOR = Color3.fromRGB(255, 120, 20)
local POISON_COLOR = Color3.fromRGB(110, 220, 60)
local PoisonCfg = Config.Poison

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
	poisonUntil: number,
	poisonFraction: number, -- fracción de la vida máxima por segundo
	poisonOwner: Player?,
	summoner: any?, -- enemigo que lo invocó
	isBoss: boolean,
	golden: boolean, -- enemigo dorado: brilla y suelta mucho botín
	model: Model?, -- modelo 3D pegado a la pieza (la pieza queda invisible)
	modelParts: { [BasePart]: number }?, -- partes del modelo y su transparencia original
	modelOffsets: { { part: BasePart, offset: CFrame } }?, -- dónde va cada parte respecto de la pieza
	showBar: boolean,
	ai: any, -- estado de EnemyAI
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
	if game:GetService("RunService"):IsStudio() then
		pcall(Enemies.reportModels) -- en Output: qué modelos de enemigos hay en ServerStorage
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
	local ok, model, modelParts, modelOffsets = pcall(Enemies.attachModel, part, typeId, def, size, height)
	if not ok then
		warn(string.format("[EnemyModels] %s: no se pudo poner el modelo: %s", typeId, tostring(model)))
		model, modelParts, modelOffsets = nil, nil, nil
		part.Transparency = 0
		local leftover = part:FindFirstChild("Model")
		if leftover then
			leftover:Destroy()
		end
	end

	local maxHealth = def.Health * healthMult
	local enemy: Enemy = {
		typeId = typeId,
		def = def,
		part = part,
		radius = size / 2,
		height = height,
		baseY = baseY,
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
		poisonUntil = 0,
		poisonFraction = 0,
		poisonOwner = nil,
		summoner = o.summoner,
		isBoss = def.Boss == true,
		golden = golden,
		model = model,
		modelParts = modelParts,
		modelOffsets = modelOffsets,
		showBar = showBar,
		ai = nil,
	}
	EnemyAI.setup(enemy)
	table.insert(Enemies.list, enemy)
	return enemy
end

---------------------------------------------------------------------
-- Modelos 3D de enemigos
---------------------------------------------------------------------

-- Busca el modelo de un tipo en todo ServerStorage (en EnemyModels o en cualquier carpeta, salvo Rooms).
-- Sirve un Model o una pieza suelta (MeshPart). Sin importar mayúsculas: primero el nombre exacto
-- ("GreenSlime"); si no, el nombre más largo con el que termine el Id ("Slime" sirve para GreenSlime,
-- RedSlime y KingSlime). Se resuelve una vez por tipo y se avisa en Output qué modelo usa.
local resolved: { [string]: Instance | false } = {}

-- Objetos "de arriba" de ServerStorage que pueden ser modelos de enemigos: sueltos o en una carpeta
-- (no las piezas de adentro de un modelo, ni las salas de Rooms). Un Model, una pieza (MeshPart,
-- Part, Unión) o cualquier cosa con piezas adentro.
local function modelCandidates(): { Instance }
	local list = {}
	for _, d in ServerStorage:GetDescendants() do
		local parent = d.Parent
		if d:IsA("Folder") or d:IsA("LuaSourceContainer") or not (parent == ServerStorage or (parent and parent:IsA("Folder"))) then
			continue
		end
		if d:FindFirstAncestor("Rooms") then
			continue
		end
		if d:IsA("BasePart") or d:FindFirstChildWhichIsA("BasePart", true) then
			table.insert(list, d)
		end
	end
	return list
end

local function describe(d: Instance): string
	local pieces = if d:IsA("BasePart") then 1 else 0
	local kinds = {}
	for _, x in d:GetDescendants() do
		if x:IsA("BasePart") then
			pieces += 1
			kinds[x.ClassName] = true
		end
	end
	if d:IsA("BasePart") then
		kinds[d.ClassName] = true
	end
	local names = {}
	for k in kinds do
		table.insert(names, k)
	end
	table.sort(names)
	return string.format("%s (%s, %d pieza%s: %s)", d:GetFullName(), d.ClassName, pieces, if pieces == 1 then "" else "s", table.concat(names, ", "))
end

-- Escribe en Output qué modelos de enemigos encontró (solo en Studio, al arrancar)
function Enemies.reportModels()
	local list = modelCandidates()
	if #list == 0 then
		print("[EnemyModels] No hay modelos de enemigos en ServerStorage")
		return
	end
	print(string.format("[EnemyModels] %d posible(s) modelo(s) en ServerStorage:", #list))
	for _, d in list do
		print("    " .. describe(d))
	end
end

local function findModel(typeId: string): Instance?
	local cached = resolved[typeId]
	if cached ~= nil then
		return cached or nil
	end
	local id = string.lower(typeId)
	local exact, best = nil, nil
	local duplicates = 0
	for _, d in modelCandidates() do
		local name = string.lower(d.Name)
		if name == id then
			duplicates += 1
			-- Si hay más de uno con el mismo nombre, el que tiene más piezas (el viejo suele ser una bola)
			if not exact or #d:GetDescendants() > #exact:GetDescendants() then
				exact = d
			end
		elseif #name >= 3 and #name < #id and string.sub(id, -#name) == name and (not best or #name > #best.Name) then
			best = d
		end
	end
	if duplicates > 1 then
		warn(string.format("[EnemyModels] Hay %d objetos llamados %s en ServerStorage: dejá uno solo", duplicates, typeId))
	end
	local found = exact or best
	resolved[typeId] = found or false
	if found then
		print(string.format("[EnemyModels] %s usa %s", typeId, describe(found)))
	end
	return found
end

-- Pega una copia del modelo a la pieza del enemigo. La pieza sigue moviéndose y recibiendo flechas
-- (invisible); el modelo la sigue soldado. Los colores de estado se ven con un Highlight.
function Enemies.attachModel(part: BasePart, typeId: string, def: any, size: number, height: number): (Model?, { [BasePart]: number }?, { { part: BasePart, offset: CFrame } }?)
	local source = findModel(typeId)
	if not source then
		return nil, nil
	end
	local copy = source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		-- Una pieza suelta (MeshPart...) u otro objeto con piezas: se mete en un Model
		model = Instance.new("Model")
		copy.Parent = model
		if copy:IsA("BasePart") then
			model.PrimaryPart = copy
		end
	end
	-- Sin scripts ni Humanoid (los modelos de la Caja de herramientas pueden traer de todo)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	local _, extent = model:GetBoundingBox()
	if extent.Y <= 0 then
		warn(string.format("[EnemyModels] %s: el modelo %s no tiene piezas visibles", typeId, source.Name))
		model:Destroy()
		return nil, nil
	end
	-- Del tamaño del enemigo: que entre en su ancho (Size) y su alto (Height)
	local fit = math.min(size / math.max(extent.X, extent.Z, 0.01), height / extent.Y)
	model:ScaleTo(model:GetScale() * fit * (EnemyCfg.ModelScale or 1))
	-- Apoyado en la base de la pieza, mirando hacia donde mira el enemigo (-Z del modelo = frente)
	local box, ext = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local offset = pivot.Position - (box.Position - Vector3.new(0, ext.Y / 2, 0))
	local bottom = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
	model:PivotTo(CFrame.new(bottom + offset) * pivot.Rotation)
	-- Todas las partes ancladas: Enemies.update las mueve junto con la pieza en el mismo BulkMoveTo
	-- (las soldaduras no siguen a una pieza movida con BulkMoveTo)
	local parts: { [BasePart]: number } = {}
	local offsets: { { part: BasePart, offset: CFrame } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d] = d.Transparency
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			table.insert(offsets, { part = d, offset = part.CFrame:ToObjectSpace(d.CFrame) })
		end
	end
	model.Name = "Model"
	model.Parent = part
	part.Transparency = 1
	-- Tinte de estado: el color de la pieza (quemado, veneno, aturdido...) pinta el modelo
	local tint = Instance.new("Highlight")
	tint.Name = "ModelTint"
	tint.Adornee = model
	tint.DepthMode = Enum.HighlightDepthMode.Occluded
	tint.FillTransparency = 0.45
	tint.OutlineTransparency = 1
	tint.Parent = part
	local natural = def.Color
	local function updateTint()
		tint.Enabled = part.Color ~= natural
		tint.FillColor = part.Color
	end
	part:GetPropertyChangedSignal("Color"):Connect(updateTint)
	updateTint()
	return model, parts, offsets
end

-- Transparencia del enemigo (enterrado, teletransportándose). Con modelo, la pieza sigue invisible.
function Enemies.setTransparency(enemy: Enemy, t: number)
	if enemy.modelParts then
		for p, original in enemy.modelParts do
			p.Transparency = original + (1 - original) * t
		end
	else
		enemy.part.Transparency = t
	end
end

-- Crea un enemigo al principio del próximo frame (seguro de usar mientras se recorre la lista).
function Enemies.queueSpawn(typeId: string, pos: Vector3, opts: SpawnOptions?)
	if Enemies.aliveCount() >= EnemyCfg.MaxAlive then return end
	table.insert(pending, { typeId = typeId, pos = pos, opts = opts or {} })
end

-- Empuja al enemigo en esa dirección (retroceso al recibir un flechazo).
function Enemies.knockback(enemy: Enemy, dir: Vector3, distance: number)
	if not enemy.alive or enemy.hidden or distance <= 0 or dir.Magnitude < 0.01 then
		return
	end
	local push = Vector3.new(dir.X, 0, dir.Z).Unit * distance
	local pos = Enemies.clampFlat(enemy.part.Position + push, enemy.radius)
	-- La orientación la vuelve a fijar Enemies.update en el próximo frame
	enemy.part.CFrame = CFrame.new(Vector3.new(pos.X, Ground.y(pos.X, pos.Z) + enemy.baseY, pos.Z))
	if enemy.modelOffsets then
		for _, m in enemy.modelOffsets do
			m.part.CFrame = enemy.part.CFrame * m.offset
		end
	end
end

-- Enterrado: invisible, no recibe golpes y no lo apunta nadie.
function Enemies.setHidden(enemy: Enemy, hidden: boolean)
	enemy.hidden = hidden
	Enemies.setTransparency(enemy, if hidden then 1 else 0)
	enemy.barGui.Enabled = enemy.showBar and not hidden
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

-- Veneno: quita `fraction` de la vida máxima por segundo durante `duration` (se renueva al pegar).
-- Se queda con el más fuerte si dos jugadores lo envenenan.
function Enemies.applyPoison(enemy: Enemy, fraction: number, duration: number, owner: Player?)
	if not enemy.alive or enemy.hidden or fraction <= 0 then
		return
	end
	enemy.poisonUntil = os.clock() + duration
	if fraction >= enemy.poisonFraction then
		enemy.poisonFraction = fraction
		enemy.poisonOwner = owner
	end
	enemy.part.Color = Enemies.baseColor(enemy)
end

-- Color "normal" del enemigo: el de su tipo, naranja si se quema o verde si está envenenado.
function Enemies.baseColor(enemy: Enemy): Color3
	if enemy.burnDps > 0 then
		return BURN_COLOR
	end
	return if enemy.poisonFraction > 0 then POISON_COLOR else enemy.color
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
		if e.alive and e.poisonFraction > 0 then
			if now >= e.poisonUntil then
				e.poisonFraction = 0
				e.part.Color = Enemies.baseColor(e)
			else
				local mult = if e.isBoss then PoisonCfg.BossMult else 1
				Enemies.damage(e, e.maxHealth * e.poisonFraction * mult * dt, e.poisonOwner, "poison")
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

		-- La IA decide adónde ir, hacia dónde mirar y si se separa de los demás.
		local desired, facing, separate = EnemyAI.step(e, dt, targets)

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
		local y = Ground.y(newPos.X, newPos.Z) + e.baseY + (e.ai.yOffset or 0)
		local look = if facing and facing.Magnitude > 0.01 then facing.Unit else e.part.CFrame.LookVector
		local center = Vector3.new(newPos.X, y, newPos.Z)
		local cf = CFrame.lookAt(center, center + Vector3.new(look.X, 0, look.Z))
		table.insert(parts, e.part)
		table.insert(cframes, cf)
		-- El modelo 3D se mueve junto con la pieza
		if e.modelOffsets then
			for _, m in e.modelOffsets do
				table.insert(parts, m.part)
				table.insert(cframes, cf * m.offset)
			end
		end

		-- Daño por contacto
		if not e.hidden and e.contactDamage > 0 then
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
