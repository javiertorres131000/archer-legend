--!strict
-- IceLooks (ModuleScript)
-- Ubicación: ServerScriptService > Server > IceLooks
-- Modelos de hielo armados por código para los enemigos del Glaciar que no tienen modelo propio
-- en ServerStorage > EnemyModels (si después se agrega uno con el mismo nombre, se usa ese).
-- Así no aparecen los muñecos genéricos de la carpeta "Todos".
-- EnemyVisuals los clona, escala a la altura del enemigo y suelda igual que cualquier modelo.
-- El frente de cada modelo es -Z.

local IceLooks = {}

local C = Color3.fromRGB
local ICE = C(175, 222, 250)
local DEEP = C(70, 135, 205)
local PALE = C(225, 242, 255)
local GLOW = C(90, 225, 255)
local EYE = C(150, 250, 255)
local DARK = C(20, 35, 60)

type Opts = { shape: Enum.PartType?, material: Enum.Material?, transparency: number?, reflect: number? }

local function p(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, o: Opts?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = (o and o.material) or Enum.Material.Ice
	part.Transparency = (o and o.transparency) or 0
	part.Reflectance = (o and o.reflect) or 0
	if o and o.shape then
		part.Shape = o.shape
	end
	part.Parent = model
	return part
end

local function neon(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3?, ball: boolean?): Part
	return p(model, name, size, cf, color or GLOW, { material = Enum.Material.Neon, shape = if ball then Enum.PartType.Ball else nil })
end

-- Punta de cristal (un bloque alargado girado 45°, con la punta más fina arriba)
local function spike(model: Model, base: Vector3, length: number, width: number, tilt: CFrame, color: Color3?)
	local cf = CFrame.new(base) * tilt * CFrame.new(0, length / 2, 0) * CFrame.Angles(0, math.rad(45), 0)
	p(model, "Punta", Vector3.new(width, length, width), cf, color or ICE, { transparency = 0.12, reflect = 0.1 })
	local tipCf = CFrame.new(base) * tilt * CFrame.new(0, length + width * 0.3, 0) * CFrame.Angles(0, math.rad(45), 0)
	p(model, "PuntaFina", Vector3.new(width * 0.5, width * 0.9, width * 0.5), tipCf, PALE, { transparency = 0.1 })
end

local function eyes(model: Model, y: number, z: number, gap: number, size: number)
	for s = -1, 1, 2 do
		neon(model, "Ojo", Vector3.one * size, CFrame.new(s * gap, y, z), EYE, true)
	end
end

local function sparkle(part: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Destellos"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), GLOW)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = rate
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = part
end

local function glow(part: BasePart, range: number)
	local l = Instance.new("PointLight")
	l.Color = GLOW
	l.Range = range
	l.Brightness = 1.4
	l.Parent = part
end

local A = CFrame.Angles
local R = math.rad

local builders: { [string]: (Model) -> () } = {}

-- Diablillo de escarcha (esqueleto de horda de hielo): agazapado, cuernos y garras
builders.FrostSkeleton = function(m)
	p(m, "Cuerpo", Vector3.new(2.2, 2.4, 2), CFrame.new(0, 2.2, 0) * A(R(-12), 0, 0), ICE, { shape = Enum.PartType.Ball, transparency = 0.08 })
	p(m, "Cabeza", Vector3.new(1.7, 1.3, 1.5), CFrame.new(0, 3.6, -0.5) * A(R(-10), 0, 0), PALE)
	eyes(m, 3.65, -1.25, 0.38, 0.32)
	neon(m, "Boca", Vector3.new(0.9, 0.12, 0.1), CFrame.new(0, 3.15, -1.25), GLOW)
	for s = -1, 1, 2 do
		spike(m, Vector3.new(s * 0.55, 4.1, -0.3), 1.5, 0.35, A(R(-35), 0, R(-s * 25)), PALE) -- cuernos
		spike(m, Vector3.new(s * 1.1, 2.6, -0.4), 1.9, 0.38, A(R(-120), 0, R(s * 20))) -- garras
		p(m, "Pierna", Vector3.new(0.7, 1.3, 0.8), CFrame.new(s * 0.6, 0.65, 0.1), DEEP, { material = Enum.Material.Glacier })
	end
	for i = -1, 1 do
		spike(m, Vector3.new(i * 0.6, 2.8, 0.8), 1.4, 0.4, A(R(30), 0, R(i * 15)), DEEP) -- púas en la espalda
	end
	sparkle(m:FindFirstChild("Cuerpo") :: BasePart, 1.5)
end

-- Guardián glacial (caballero pesado): bloque de glaciar con escudo de hielo y núcleo brillante
builders.FrostKnight = function(m)
	local torso = p(m, "Torso", Vector3.new(3.8, 3.2, 2.4), CFrame.new(0, 3.6, 0), DEEP, { material = Enum.Material.Glacier, reflect = 0.08 })
	p(m, "Placa", Vector3.new(3.2, 2.4, 0.4), CFrame.new(0, 3.8, -1.3), ICE, { transparency = 0.1 })
	local core = neon(m, "Nucleo", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 3.9, -1.55) * A(0, 0, R(45)))
	glow(core, 9)
	p(m, "Cabeza", Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, 5.8, -0.2), ICE, { transparency = 0.05 })
	neon(m, "Visor", Vector3.new(1.2, 0.18, 0.1), CFrame.new(0, 5.9, -1.02), EYE)
	for s = -1, 1, 2 do
		p(m, "Hombrera", Vector3.new(1.6, 1.2, 2.2), CFrame.new(s * 2.4, 5, 0) * A(0, 0, R(s * -15)), ICE, { transparency = 0.1 })
		spike(m, Vector3.new(s * 2.6, 5.4, 0), 1.8, 0.5, A(0, 0, R(s * -30)), PALE)
		p(m, "Pierna", Vector3.new(1.3, 2, 1.4), CFrame.new(s * 0.9, 1, 0), DEEP, { material = Enum.Material.Glacier })
	end
	-- Escudo (izquierda) y maza de hielo (derecha)
	p(m, "Escudo", Vector3.new(2.6, 3.4, 0.45), CFrame.new(-2.3, 3.2, -1.6) * A(0, R(20), 0), ICE, { transparency = 0.25, reflect = 0.2 })
	neon(m, "RunaEscudo", Vector3.new(0.6, 1.4, 0.1), CFrame.new(-2.3, 3.3, -1.88) * A(0, R(20), 0))
	p(m, "Mango", Vector3.new(0.35, 3, 0.35), CFrame.new(2.6, 2.6, -1) * A(R(-25), 0, 0), DARK, { material = Enum.Material.Metal })
	p(m, "Maza", Vector3.new(1.6, 1.6, 1.6), CFrame.new(2.6, 1.3, -1.7) * A(R(20), R(45), 0), PALE, { transparency = 0.1 })
	sparkle(torso, 2)
end

-- Caballero boreal (capitán): esbelto, corona de cristal, capa translúcida y espada de luz
builders.FrostCaptain = function(m)
	local torso = p(m, "Torso", Vector3.new(2, 2.6, 1.3), CFrame.new(0, 4.1, 0), ICE, { transparency = 0.05, reflect = 0.15 })
	p(m, "Cintura", Vector3.new(1.4, 1, 1), CFrame.new(0, 2.5, 0), DEEP, { material = Enum.Material.Glacier })
	local core = neon(m, "Nucleo", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 4.3, -0.68) * A(0, 0, R(45)), C(170, 140, 255))
	glow(core, 8)
	p(m, "Cabeza", Vector3.new(1.1, 1.3, 1.1), CFrame.new(0, 6, 0), PALE)
	neon(m, "Visor", Vector3.new(0.8, 0.14, 0.1), CFrame.new(0, 6.05, -0.56), EYE)
	for i = -2, 2 do
		spike(m, Vector3.new(i * 0.28, 6.6, 0), 0.8 + (2 - math.abs(i)) * 0.45, 0.2, A(0, 0, R(-i * 14)), PALE) -- corona
	end
	for s = -1, 1, 2 do
		p(m, "Hombrera", Vector3.new(1, 0.6, 1.3), CFrame.new(s * 1.3, 5.3, 0) * A(0, 0, R(s * -20)), DEEP, { material = Enum.Material.Glacier })
		p(m, "Pierna", Vector3.new(0.6, 2, 0.7), CFrame.new(s * 0.45, 1, 0), DEEP, { material = Enum.Material.Glacier })
		p(m, "Brazo", Vector3.new(0.5, 2, 0.5), CFrame.new(s * 1.35, 4, -0.2), ICE)
	end
	p(m, "Capa", Vector3.new(2.4, 4.2, 0.2), CFrame.new(0, 3.5, 0.8) * A(R(10), 0, 0), C(120, 160, 255), { material = Enum.Material.Glass, transparency = 0.45 })
	-- Espada de luz helada
	p(m, "Empuñadura", Vector3.new(0.25, 0.9, 0.25), CFrame.new(1.4, 3, -0.6), DARK, { material = Enum.Material.Metal })
	neon(m, "Hoja", Vector3.new(0.18, 3.6, 0.45), CFrame.new(1.4, 1.2, -1.3) * A(R(-35), 0, 0), C(140, 230, 255))
	-- Halo partido detrás de la cabeza
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		p(m, "Halo", Vector3.new(0.25, 0.6, 0.25), CFrame.new(math.cos(a) * 1.1, 6.2 + math.sin(a) * 1.1, 0.7) * A(0, 0, a), GLOW, { material = Enum.Material.Neon })
	end
	sparkle(torso, 3)
end

-- Garra helada (atrapador): cangrejo de hielo con pinzas enormes
builders.FrostGrabber = function(m)
	local body = p(m, "Caparazon", Vector3.new(4, 1.6, 3.2), CFrame.new(0, 1.7, 0.2), ICE, { shape = Enum.PartType.Ball, transparency = 0.1, reflect = 0.1 })
	p(m, "Vientre", Vector3.new(3.4, 1, 2.6), CFrame.new(0, 1.2, 0.2), DEEP, { shape = Enum.PartType.Ball, material = Enum.Material.Glacier })
	for i = -1, 1 do
		spike(m, Vector3.new(i * 1, 2.3, 0.5), 1.2, 0.4, A(R(15), 0, R(-i * 20)), PALE)
	end
	for s = -1, 1, 2 do
		-- Ojos en tallos
		p(m, "Tallo", Vector3.new(0.18, 0.8, 0.18), CFrame.new(s * 0.5, 2.6, -1.1), DEEP)
		neon(m, "Ojo", Vector3.one * 0.38, CFrame.new(s * 0.5, 3.05, -1.1), EYE, true)
		-- Patas
		for k = 0, 2 do
			p(m, "Pata", Vector3.new(0.3, 1.9, 0.3), CFrame.new(s * (1.9 + k * 0.1), 0.9, -0.6 + k * 0.9) * A(0, 0, R(s * 40)), DEEP, { material = Enum.Material.Glacier })
		end
		-- Pinzas
		p(m, "Brazo", Vector3.new(0.5, 0.5, 1.8), CFrame.new(s * 1.6, 1.8, -1.8) * A(0, R(-s * 20), 0), ICE)
		p(m, "Pinza", Vector3.new(1.1, 0.5, 1.6), CFrame.new(s * 1.9, 2, -3) * A(R(15), R(-s * 10), 0), PALE, { transparency = 0.05 })
		p(m, "Pinza", Vector3.new(0.9, 0.4, 1.3), CFrame.new(s * 1.9, 1.5, -2.9) * A(R(-15), R(-s * 10), 0), ICE)
	end
	sparkle(body, 2)
end

-- Centinela de escarcha (arquero): cristal flotante con un gran ojo y fragmentos que lo rodean
builders.IceArcher = function(m)
	local body = p(m, "Cristal", Vector3.new(1.8, 3.4, 1.8), CFrame.new(0, 3, 0) * A(0, R(45), 0), ICE, { transparency = 0.15, reflect = 0.2 })
	p(m, "PuntaSup", Vector3.new(1.1, 1.2, 1.1), CFrame.new(0, 5.1, 0) * A(0, R(45), 0), PALE, { transparency = 0.1 })
	p(m, "PuntaInf", Vector3.new(1, 1.2, 1), CFrame.new(0, 0.9, 0) * A(0, R(45), 0), DEEP, { material = Enum.Material.Glacier })
	p(m, "Parpado", Vector3.new(1.3, 1.3, 0.3), CFrame.new(0, 3.3, -1.15), DARK, { shape = Enum.PartType.Ball })
	local eye = neon(m, "Ojo", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 3.3, -1.3), EYE, true)
	glow(eye, 8)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 1.8, 3 + math.sin(a * 2) * 0.6, math.sin(a) * 1.8)
		p(m, "Fragmento", Vector3.new(0.5, 1.1, 0.5), CFrame.new(pos) * A(R(20), a, R(30)), PALE, { transparency = 0.1 })
	end
	p(m, "Anillo", Vector3.new(0.15, 3.2, 3.2), CFrame.new(0, 3, 0.4) * A(0, R(90), 0), GLOW, { material = Enum.Material.Neon, shape = Enum.PartType.Cylinder, transparency = 0.55 })
	sparkle(body, 3)
end

-- Espectro de hielo: túnica rasgada translúcida, cara vacía y ojos brillantes
builders.IceWraith = function(m)
	local robe = p(m, "Tunica", Vector3.new(2.6, 3.6, 2.4), CFrame.new(0, 2.6, 0), C(200, 230, 255), { material = Enum.Material.Glass, transparency = 0.35 })
	p(m, "Capucha", Vector3.new(2, 1.9, 2), CFrame.new(0, 4.9, 0.1), C(215, 238, 255), { material = Enum.Material.Glass, transparency = 0.25, shape = Enum.PartType.Ball })
	p(m, "Cara", Vector3.new(1.3, 1.3, 0.5), CFrame.new(0, 4.8, -0.75), DARK, { shape = Enum.PartType.Ball })
	eyes(m, 4.9, -1.02, 0.28, 0.28)
	for i = 0, 6 do -- jirones de hielo colgando
		local a = i / 7 * math.pi * 2
		spike(m, Vector3.new(math.cos(a) * 1.1, 1, math.sin(a) * 1.1), 1.4 + (i % 2) * 0.6, 0.35, A(R(180), 0, R(math.cos(a) * 12)), PALE)
	end
	for s = -1, 1, 2 do
		p(m, "Manga", Vector3.new(0.7, 2.4, 0.7), CFrame.new(s * 1.5, 3.4, -0.6) * A(R(-40), 0, R(s * 15)), C(200, 230, 255), { material = Enum.Material.Glass, transparency = 0.35 })
		spike(m, Vector3.new(s * 1.7, 2.6, -1.4), 1, 0.25, A(R(-110), 0, 0), GLOW)
	end
	for i = -1, 1 do
		spike(m, Vector3.new(i * 0.45, 5.6, 0.2), 0.9 + (1 - math.abs(i)) * 0.5, 0.22, A(R(-10), 0, R(-i * 18)), PALE)
	end
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Niebla"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(C(225, 242, 255))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	mist.Lifetime = NumberRange.new(0.8, 1.3)
	mist.Rate = 6
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = robe
	sparkle(robe, 2)
end

-- Trozo de slime helado: bola de hielo con núcleo brillante y púas
builders.IceSlimeling = function(m)
	local ball = p(m, "Cuerpo", Vector3.new(2, 1.7, 2), CFrame.new(0, 0.85, 0), ICE, { shape = Enum.PartType.Ball, transparency = 0.3, reflect = 0.15 })
	neon(m, "Nucleo", Vector3.one * 0.8, CFrame.new(0, 0.85, 0), GLOW, true)
	eyes(m, 1.1, -0.9, 0.35, 0.28)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		spike(m, Vector3.new(math.cos(a) * 0.5, 1.5, math.sin(a) * 0.5), 0.7, 0.25, A(R(math.sin(a) * 25), 0, R(-math.cos(a) * 25)), PALE)
	end
	sparkle(ball, 1)
end

local cache: { [string]: Model } = {}

-- Modelo de hielo para este tipo (o nil si no hay diseño)
function IceLooks.template(typeId: string): Model?
	local cached = cache[typeId]
	if cached then
		return cached
	end
	local build = builders[typeId]
	if not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = typeId
	build(model)
	model:SetAttribute("IceLook", true)
	cache[typeId] = model
	return model
end

function IceLooks.has(typeId: string): boolean
	return builders[typeId] ~= nil
end

return IceLooks
