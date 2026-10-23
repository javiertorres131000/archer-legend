--!strict
-- CrateModels (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > CrateModels
-- Arma las piezas 3D del sistema de cajas con Parts (sin assets): plataformas hexagonales,
-- antorchas, el cofre de cada caja y los premios (personajes, unidades y mascotas de bloques).
-- Lo usan el servidor (plaza del lobby) y el cliente (menú y animación de apertura).
--
-- Modelos propios: si existe ReplicatedStorage > CrateAssets > Prizes > <Id del premio>
-- (o > Crates > <Id de la caja>), se clona ese Model en vez del de bloques. Tiene que mirar
-- hacia -Z y apoyarse en el piso (su pivote abajo al centro); se le borran los scripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrateItems = require(script.Parent.CrateItems)
local CrateLooks = require(script.Parent.CrateLooks)

local C = Color3.fromRGB
local SQRT3 = math.sqrt(3)

local CrateModels = {}

export type Torch = { model: Model, light: PointLight, fire: Fire }

function CrateModels.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local part = CrateModels.part

local function neon(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = part(parent, name, size, cframe, color, Enum.Material.Neon)
	p.CastShadow = false
	return p
end

local function root(model: Model, cframe: CFrame): Part
	local r = part(model, "Root", Vector3.new(0.2, 0.2, 0.2), cframe, Color3.new(1, 1, 1))
	r.Transparency = 1
	model.PrimaryPart = r
	return r
end

---------------------------------------------------------------------
-- Formas
---------------------------------------------------------------------

-- Hexágono macizo de radio `radius` (al vértice) y alto `height`, con el centro de su cara de
-- arriba en `top`. Son 3 bloques girados 60°.
function CrateModels.hex(parent: Instance, name: string, top: CFrame, radius: number, height: number, color: Color3, material: Enum.Material?, collide: boolean?): { Part }
	local parts = {}
	local center = top * CFrame.new(0, -height / 2, 0)
	for i = 0, 2 do
		local p = part(parent, name, Vector3.new(radius, height, radius * SQRT3), center * CFrame.Angles(0, math.rad(60 * i), 0), color, material)
		p.CanCollide = collide == true
		p.CanQuery = collide == true
		table.insert(parts, p)
	end
	return parts
end

-- Borde de neón alrededor de un hexágono (6 barras sobre las aristas)
function CrateModels.hexRim(parent: Instance, top: CFrame, radius: number, thickness: number, height: number, color: Color3): { Part }
	local parts = {}
	local apothem = radius * SQRT3 / 2
	for k = 0, 5 do
		local phi = math.rad(30 + 60 * k)
		local dir = Vector3.new(math.cos(phi), 0, math.sin(phi))
		local pos = dir * (apothem - thickness / 2 + 0.05) + Vector3.new(0, height / 2 - 0.02, 0)
		local p = neon(parent, "Rim", Vector3.new(radius + thickness * 0.6, height, thickness), top * CFrame.lookAt(pos, pos + dir), color)
		table.insert(parts, p)
	end
	return parts
end

---------------------------------------------------------------------
-- Partículas
---------------------------------------------------------------------

-- Brasas que suben. rate = partículas por segundo
function CrateModels.embers(parent: Instance, color: Color3, rate: number, spread: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, C(255, 60, 20))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1.2, 2.6)
	e.Rate = rate
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(spread or 25, spread or 25)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

---------------------------------------------------------------------
-- Antorcha
---------------------------------------------------------------------

-- Antorcha parada en `base` (pie en el piso). height: alto del poste
function CrateModels.torch(parent: Instance, base: CFrame, height: number?): Torch
	local h = height or 6
	local model = Instance.new("Model")
	model.Name = "Torch"
	root(model, base)
	local pole = part(model, "Pole", Vector3.new(0.8, h, 0.8), base * CFrame.new(0, h / 2, 0), C(38, 30, 28), Enum.Material.Basalt)
	pole.CanCollide = true
	pole.CanQuery = true
	part(model, "Band", Vector3.new(1, 0.3, 1), base * CFrame.new(0, h * 0.35, 0), C(70, 50, 35), Enum.Material.Metal)
	part(model, "Bowl", Vector3.new(1.8, 0.6, 1.8), base * CFrame.new(0, h + 0.3, 0), C(55, 40, 32), Enum.Material.Metal)
	local coal = neon(model, "Coal", Vector3.new(1.3, 0.3, 1.3), base * CFrame.new(0, h + 0.65, 0), C(255, 110, 30))
	local fire = Instance.new("Fire")
	fire.Color = C(255, 120, 40)
	fire.SecondaryColor = C(255, 220, 90)
	fire.Size = 5
	fire.Heat = 9
	fire.Parent = coal
	local light = Instance.new("PointLight")
	light.Color = C(255, 140, 60)
	light.Range = 18
	light.Brightness = 2.4
	light.Shadows = true
	light.Parent = coal
	CrateModels.embers(coal, C(255, 190, 80), 4, 20)
	model.Parent = parent
	return { model = model, light = light, fire = fire }
end

---------------------------------------------------------------------
-- Cofre
---------------------------------------------------------------------

local function stripScripts(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

local function override(kind: string, id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("CrateAssets")
	local folder = assets and assets:FindFirstChild(kind)
	local found = folder and folder:FindFirstChild(id)
	if found and found:IsA("Model") then
		local clone = found:Clone()
		stripScripts(clone)
		return clone
	end
	return nil
end

-- Cofre de la caja: unos 4 x 3.6 x 3 studs, pivote abajo al centro, frente hacia -Z.
-- Tiene una pieza "Lid" (tapa) y piezas de neón "Glow" que la animación hace brillar.
function CrateModels.crate(def: { Id: string, Color: Color3, Dark: Color3 }): Model
	local custom = override("Crates", def.Id)
	if custom then
		return custom
	end
	local model = Instance.new("Model")
	model.Name = def.Id .. "Crate"
	local base = CFrame.new()
	root(model, base)
	local wood = Enum.Material.WoodPlanks
	local metal = Enum.Material.Metal
	local trim = def.Color:Lerp(C(255, 255, 255), 0.15)
	part(model, "Body", Vector3.new(4, 2, 2.8), base * CFrame.new(0, 1, 0), def.Dark, wood)
	local lid = part(model, "Lid", Vector3.new(4.1, 1.1, 2.9), base * CFrame.new(0, 2.55, 0), def.Dark, wood)
	part(model, "LidTop", Vector3.new(3.8, 0.45, 2.5), base * CFrame.new(0, 3.3, 0), def.Dark:Lerp(C(0, 0, 0), 0.15), wood).Parent = lid
	-- Bandas de metal y esquinas
	for _, x in { -1.35, 1.35 } do
		part(model, "Band", Vector3.new(0.35, 2.1, 2.95), base * CFrame.new(x, 1, 0), trim, metal)
		part(model, "Band", Vector3.new(0.35, 1.2, 3.05), base * CFrame.new(x, 2.55, 0), trim, metal).Parent = lid
	end
	for _, x in { -1.95, 1.95 } do
		for _, z in { -1.35, 1.35 } do
			part(model, "Corner", Vector3.new(0.35, 2.1, 0.35), base * CFrame.new(x, 1, z), trim:Lerp(C(0, 0, 0), 0.3), metal)
		end
	end
	-- Línea de neón entre la tapa y la caja, cerradura y gema
	neon(model, "Glow", Vector3.new(4.15, 0.14, 2.95), base * CFrame.new(0, 2.03, 0), def.Color)
	part(model, "Lock", Vector3.new(0.8, 0.9, 0.25), base * CFrame.new(0, 2.05, -1.5), trim, metal)
	neon(model, "Glow", Vector3.new(0.3, 0.35, 0.1), base * CFrame.new(0, 2.05, -1.65), def.Color)
	local gem = neon(lid, "Glow", Vector3.new(0.7, 0.35, 0.7), base * CFrame.new(0, 3.62, 0) * CFrame.Angles(0, math.rad(45), 0), def.Color)
	gem.Name = "Glow"
	return model
end

---------------------------------------------------------------------
-- Huevo de mascotas
---------------------------------------------------------------------

-- Huevo ornamentado (~3 x 4 studs), pivote abajo al centro, frente hacia -Z: cáscara oscura,
-- dos bandas de neón del color del huevo, zigzag dorado, gemas y corona arriba. Las piezas de
-- neón se llaman "Glow" (la animación las hace brillar). Modelo propio: CrateAssets > Crates > Id.
function CrateModels.egg(def: { Id: string, Color: Color3, Dark: Color3 }): Model
	local custom = override("Crates", def.Id)
	if custom then
		return custom
	end
	local model = Instance.new("Model")
	model.Name = def.Id
	local base = CFrame.new()
	root(model, base)
	local w, h = 3, 4 -- ancho y alto de la cáscara
	local shell = part(model, "Shell", Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), def.Dark, Enum.Material.SmoothPlastic)
	shell.Reflectance = 0.08
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	local gold = C(255, 200, 70)
	-- Ancho del huevo a una altura y (elipse)
	local function widthAt(y: number): number
		local k = (y - h / 2) / (h / 2)
		return w * math.sqrt(math.max(0, 1 - k * k))
	end
	-- Bandas de neón
	for _, y in { 1.25, 2.85 } do
		local d = widthAt(y) + 0.08
		local band = neon(model, "Glow", Vector3.new(0.16, d, d), base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), def.Color)
		band.Shape = Enum.PartType.Cylinder
	end
	-- Zigzag dorado alrededor del medio
	local r = widthAt(2) / 2 + 0.02
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local normal = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = normal * r + Vector3.new(0, 2.05, 0)
		local tilt = if i % 2 == 0 then 0.75 else -0.75
		part(model, "Zigzag", Vector3.new(0.12, 0.85, 0.08), base * CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, tilt), gold, Enum.Material.Metal)
	end
	-- Gemas sobre la banda de abajo
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local rr = widthAt(1.25) / 2 + 0.12
		local gem = neon(model, "Glow", Vector3.new(0.32, 0.32, 0.32), base * CFrame.new(math.cos(a) * rr, 1.25, math.sin(a) * rr), def.Color:Lerp(C(255, 255, 255), 0.3))
		gem.Shape = Enum.PartType.Ball
	end
	-- Corona dorada arriba
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local cf = base * CFrame.new(math.cos(a) * 0.55, h - 0.12, math.sin(a) * 0.55) * CFrame.Angles(0, -a, math.rad(15))
		part(model, "Crown", Vector3.new(0.18, 0.55, 0.18), cf, gold, Enum.Material.Metal)
	end
	local top = neon(model, "Glow", Vector3.new(0.35, 0.35, 0.35), base * CFrame.new(0, h + 0.12, 0), def.Color)
	top.Shape = Enum.PartType.Ball
	return model
end

---------------------------------------------------------------------
-- Premios de bloques
---------------------------------------------------------------------

local EYE = C(20, 20, 26)

local function eyes(model: Model, cf: CFrame, look: CrateItems.Look, gap: number, size: number)
	local color = if look.Neon and look.Accent then look.Accent else EYE
	for _, x in { -gap, gap } do
		local e = part(model, "Eye", Vector3.new(size, size * 1.2, 0.08), cf * CFrame.new(x, 0, 0), color, if look.Neon then Enum.Material.Neon else nil)
		e.CastShadow = false
	end
end

local function accent(look: CrateItems.Look, fallback: Color3): Color3
	return look.Accent or fallback
end

local function accMaterial(look: CrateItems.Look): Enum.Material
	return if look.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function has(look: CrateItems.Look, acc: string): boolean
	return look.Acc ~= nil and table.find(look.Acc, acc) ~= nil
end

local function aura(model: Model, at: CFrame, color: Color3)
	local p = part(model, "AuraCore", Vector3.new(0.2, 0.2, 0.2), at, color)
	p.Transparency = 1
	local e = CrateModels.embers(p, color, 10, 180)
	e.Name = "Aura"
	e.Speed = NumberRange.new(0.6, 1.6)
	e.Acceleration = Vector3.new(0, 1.2, 0)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 0.8
	light.Parent = p
end

local function halo(model: Model, center: CFrame, radius: number, color: Color3)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		neon(model, "Halo", Vector3.new(0.18, 0.12, radius * 0.7), center * CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))), color)
	end
end

local function wings(model: Model, back: CFrame, look: CrateItems.Look, span: number)
	local color = accent(look, look.Body)
	for _, side in { -1, 1 } do
		local cf = back * CFrame.new(side * span * 0.42, 0.3, 0) * CFrame.Angles(0, math.rad(-side * 28), math.rad(side * 18))
		part(model, "Wing", Vector3.new(span * 0.8, span * 0.55, 0.12), cf, color, accMaterial(look))
		part(model, "Wing", Vector3.new(span * 0.55, span * 0.3, 0.14), cf * CFrame.new(side * span * 0.2, span * 0.33, 0), color:Lerp(C(255, 255, 255), 0.25), accMaterial(look))
	end
end

local function weapon(model: Model, hand: CFrame, otherHand: CFrame, look: CrateItems.Look)
	local kind = look.Weapon
	local metal = C(200, 205, 215)
	local acc = accent(look, C(200, 160, 60))
	if kind == "Sword" then
		part(model, "Hilt", Vector3.new(0.25, 0.7, 0.25), hand * CFrame.new(0, 0, -0.35), C(70, 45, 30))
		part(model, "Guard", Vector3.new(0.9, 0.2, 0.25), hand * CFrame.new(0, 0.4, -0.35), acc, Enum.Material.Metal)
		part(model, "Blade", Vector3.new(0.2, 2.6, 0.12), hand * CFrame.new(0, 1.8, -0.35), if look.Neon then acc else metal, if look.Neon then Enum.Material.Neon else Enum.Material.Metal)
	elseif kind == "Spear" then
		part(model, "Shaft", Vector3.new(0.2, 5.5, 0.2), hand * CFrame.new(0, 1.4, -0.35), C(110, 75, 45), Enum.Material.Wood)
		part(model, "Tip", Vector3.new(0.35, 0.8, 0.15), hand * CFrame.new(0, 4.5, -0.35), metal, Enum.Material.Metal)
	elseif kind == "Staff" then
		part(model, "Shaft", Vector3.new(0.25, 4.8, 0.25), hand * CFrame.new(0, 1.2, -0.35), C(80, 55, 40), Enum.Material.Wood)
		local orb = neon(model, "Orb", Vector3.new(0.8, 0.8, 0.8), hand * CFrame.new(0, 3.9, -0.35), acc)
		orb.Shape = Enum.PartType.Ball
	elseif kind == "Bow" then
		local bowColor = C(120, 80, 45)
		for i = -2, 2 do
			local a = i * 0.32
			part(model, "Bow", Vector3.new(0.18, 0.75, 0.18), otherHand * CFrame.new(0, math.sin(a) * 1.9, -0.35 - math.cos(a) * 0.6 + 0.6) * CFrame.Angles(a, 0, 0), bowColor, Enum.Material.Wood)
		end
		neon(model, "String", Vector3.new(0.05, 3.5, 0.05), otherHand * CFrame.new(0, 0, 0.1), C(255, 250, 230))
	elseif kind == "Shield" then
		part(model, "Shield", Vector3.new(0.3, 2.2, 1.8), otherHand * CFrame.new(-0.3, 0.3, 0), acc, Enum.Material.Metal)
		part(model, "Boss", Vector3.new(0.35, 0.6, 0.6), otherHand * CFrame.new(-0.5, 0.3, 0), metal, Enum.Material.Metal)
		part(model, "Hilt", Vector3.new(0.25, 0.7, 0.25), hand * CFrame.new(0, 0, -0.35), C(70, 45, 30))
		part(model, "Blade", Vector3.new(0.2, 2.2, 0.12), hand * CFrame.new(0, 1.5, -0.35), metal, Enum.Material.Metal)
	end
end

-- Personaje o unidad de bloques (unos 5.3 studs de alto)
local function humanoidModel(model: Model, look: CrateItems.Look, big: boolean)
	local s = if big then 1.25 else 1
	local base = CFrame.new()
	local skin = look.Skin or C(255, 214, 170)
	local pants = look.Pants or look.Body:Lerp(C(0, 0, 0), 0.35)
	for _, x in { -0.5, 0.5 } do
		part(model, "Leg", Vector3.new(0.95, 2, 1) * s, base * CFrame.new(x * s, 1 * s, 0), pants)
	end
	part(model, "Torso", Vector3.new(2, 2, 1) * s, base * CFrame.new(0, 3 * s, 0), look.Body)
	if look.Accent then
		part(model, "Belt", Vector3.new(2.05, 0.28, 1.05) * s, base * CFrame.new(0, 2.15 * s, 0), look.Accent, accMaterial(look))
	end
	for _, x in { -1.5, 1.5 } do
		part(model, "Arm", Vector3.new(0.95, 2, 1) * s, base * CFrame.new(x * s, 3 * s, 0), look.Body:Lerp(C(0, 0, 0), 0.12))
		part(model, "Hand", Vector3.new(0.9, 0.4, 0.95) * s, base * CFrame.new(x * s, 1.9 * s, 0), skin)
	end
	local headY = 4.6 * s
	part(model, "Head", Vector3.new(1.25, 1.25, 1.25) * s, base * CFrame.new(0, headY, 0), skin)
	eyes(model, base * CFrame.new(0, headY + 0.08 * s, -0.63 * s), look, 0.26 * s, 0.2 * s)
	local headTop = headY + 0.63 * s

	if has(look, "Helmet") then
		part(model, "Helmet", Vector3.new(1.4, 0.55, 1.4) * s, base * CFrame.new(0, headTop + 0.05 * s, 0), C(150, 155, 170), Enum.Material.Metal)
		part(model, "Plume", Vector3.new(0.25, 0.5, 1) * s, base * CFrame.new(0, headTop + 0.5 * s, 0.1 * s), accent(look, C(200, 40, 40)), accMaterial(look))
	end
	if has(look, "Crown") then
		local gold = C(255, 205, 60)
		part(model, "Crown", Vector3.new(1.35, 0.3, 1.35) * s, base * CFrame.new(0, headTop + 0.15 * s, 0), gold, Enum.Material.Metal)
		for _, x in { -0.55, 0.55 } do
			for _, z in { -0.55, 0.55 } do
				part(model, "Spike", Vector3.new(0.25, 0.45, 0.25) * s, base * CFrame.new(x * s, headTop + 0.5 * s, z * s), gold, Enum.Material.Metal)
			end
		end
		neon(model, "Gem", Vector3.new(0.3, 0.3, 0.1) * s, base * CFrame.new(0, headTop + 0.15 * s, -0.7 * s), C(255, 50, 70))
	end
	if has(look, "WizardHat") then
		local hat = accent(look, look.Body)
		part(model, "Brim", Vector3.new(1.9, 0.15, 1.9) * s, base * CFrame.new(0, headTop + 0.05 * s, 0), look.Body)
		for i = 0, 3 do
			local w = (1.2 - i * 0.27) * s
			part(model, "Hat", Vector3.new(w, 0.45 * s, w), base * CFrame.new(0, headTop + (0.32 + i * 0.42) * s, (i * 0.08) * s), if i == 3 then hat else look.Body, if i == 3 then accMaterial(look) else nil)
		end
	end
	if has(look, "Horns") then
		for _, side in { -1, 1 } do
			local cf = base * CFrame.new(side * 0.55 * s, headTop + 0.25 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 25))
			part(model, "Horn", Vector3.new(0.3, 0.6, 0.3) * s, cf, C(40, 30, 30))
			neon(model, "HornTip", Vector3.new(0.2, 0.35, 0.2) * s, cf * CFrame.new(side * 0.12 * s, 0.45 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 15)), accent(look, C(255, 90, 20)))
		end
	end
	if has(look, "Halo") then
		halo(model, base * CFrame.new(0, headTop + 0.75 * s, 0), 0.75 * s, C(255, 240, 160))
	end
	if has(look, "Cape") then
		part(model, "Cape", Vector3.new(1.9, 2.8, 0.12) * s, base * CFrame.new(0, 2.75 * s, 0.6 * s) * CFrame.Angles(math.rad(-8), 0, 0), accent(look, C(150, 30, 40)), Enum.Material.Fabric)
	end
	if has(look, "Wings") then
		wings(model, base * CFrame.new(0, 3.3 * s, 0.75 * s), look, 3.6 * s)
	end
	if look.Weapon then
		weapon(model, base * CFrame.new(1.5 * s, 1.9 * s, 0), base * CFrame.new(-1.5 * s, 2.4 * s, 0), look)
	end
	if has(look, "Aura") then
		aura(model, base * CFrame.new(0, 3 * s, 0), accent(look, look.Body))
	end
end

-- Mascota de 4 patas (unos 3 studs de alto)
local function petModel(model: Model, look: CrateItems.Look)
	local base = CFrame.new()
	local acc = accent(look, look.Body:Lerp(C(255, 255, 255), 0.4))
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.75, 0.75 } do
			part(model, "Leg", Vector3.new(0.45, 0.8, 0.45), base * CFrame.new(x, 0.4, z), look.Body:Lerp(C(0, 0, 0), 0.2))
		end
	end
	part(model, "Body", Vector3.new(1.6, 1.3, 2.5), base * CFrame.new(0, 1.45, 0), look.Body)
	part(model, "Belly", Vector3.new(1.3, 0.3, 1.8), base * CFrame.new(0, 0.82, 0), acc, accMaterial(look))
	local head = base * CFrame.new(0, 2.25, -1.35)
	part(model, "Head", Vector3.new(1.35, 1.25, 1.25), head, look.Body)
	part(model, "Snout", Vector3.new(0.7, 0.5, 0.45), head * CFrame.new(0, -0.25, -0.8), acc)
	part(model, "Nose", Vector3.new(0.25, 0.18, 0.1), head * CFrame.new(0, -0.12, -1.05), EYE)
	eyes(model, head * CFrame.new(0, 0.2, -0.64), look, 0.32, 0.2)
	if has(look, "Ears") then
		for _, x in { -0.42, 0.42 } do
			part(model, "Ear", Vector3.new(0.35, 0.55, 0.25), head * CFrame.new(x, 0.85, 0.1) * CFrame.Angles(0, 0, math.rad(x * -20)), look.Body)
			part(model, "EarIn", Vector3.new(0.18, 0.32, 0.05), head * CFrame.new(x, 0.82, -0.03) * CFrame.Angles(0, 0, math.rad(x * -20)), acc, accMaterial(look))
		end
	end
	if has(look, "LongEars") then
		for _, x in { -0.3, 0.3 } do
			part(model, "Ear", Vector3.new(0.3, 1.1, 0.22), head * CFrame.new(x, 1.1, 0.15) * CFrame.Angles(math.rad(-10), 0, math.rad(x * -25)), look.Body)
			part(model, "EarIn", Vector3.new(0.16, 0.8, 0.05), head * CFrame.new(x, 1.1, 0.03) * CFrame.Angles(math.rad(-10), 0, math.rad(x * -25)), acc)
		end
	end
	if has(look, "Snout") then
		part(model, "PigSnout", Vector3.new(0.75, 0.55, 0.25), head * CFrame.new(0, -0.15, -0.72), acc)
		for _, x in { -0.15, 0.15 } do
			part(model, "Nostril", Vector3.new(0.12, 0.18, 0.06), head * CFrame.new(x, -0.15, -0.86), EYE)
		end
	end
	if has(look, "Horn") then
		local hornColor = accent(look, C(255, 220, 120))
		for i = 0, 2 do
			local w = 0.26 - i * 0.07
			part(model, "Horn", Vector3.new(w, 0.32, w), head * CFrame.new(0, 0.75 + i * 0.25, -0.35 - i * 0.08) * CFrame.Angles(math.rad(-20), math.rad(i * 30), 0), hornColor, accMaterial(look))
		end
	end
	if has(look, "Horns") then
		for _, side in { -1, 1 } do
			local cf = head * CFrame.new(side * 0.45, 0.75, 0.2) * CFrame.Angles(math.rad(25), 0, math.rad(-side * 25))
			part(model, "Horn", Vector3.new(0.25, 0.55, 0.25), cf, C(60, 45, 40))
			part(model, "HornTip", Vector3.new(0.17, 0.3, 0.17), cf * CFrame.new(0, 0.4, 0), accent(look, C(255, 200, 80)), accMaterial(look))
		end
	end
	part(model, "Tail", Vector3.new(0.3, 0.3, 1.1), base * CFrame.new(0, 1.9, 1.55) * CFrame.Angles(math.rad(35), 0, 0), acc, accMaterial(look))
	if has(look, "Halo") then
		halo(model, head * CFrame.new(0, 1.15, 0), 0.6, C(255, 240, 160))
	end
	if has(look, "Wings") then
		wings(model, base * CFrame.new(0, 2, 0.2), look, 3)
	end
	if has(look, "Aura") then
		aura(model, base * CFrame.new(0, 1.5, 0), acc)
	end
end

-- Slime: cubo gelatinoso con un núcleo
local function slimeModel(model: Model, look: CrateItems.Look)
	local base = CFrame.new()
	local body = part(model, "Body", Vector3.new(2.4, 1.9, 2.4), base * CFrame.new(0, 0.95, 0), look.Body, Enum.Material.Glass)
	body.Transparency = 0.25
	part(model, "Core", Vector3.new(1, 0.9, 1), base * CFrame.new(0, 0.9, 0.1), accent(look, look.Body), Enum.Material.SmoothPlastic)
	part(model, "Top", Vector3.new(1.8, 0.4, 1.8), base * CFrame.new(0, 2.05, 0), look.Body, Enum.Material.Glass).Transparency = 0.25
	eyes(model, base * CFrame.new(0, 1.25, -1.22), look, 0.4, 0.3)
	part(model, "Mouth", Vector3.new(0.5, 0.12, 0.06), base * CFrame.new(0, 0.85, -1.22), EYE)
end

-- Ave (gallina, fénix)
local function birdModel(model: Model, look: CrateItems.Look)
	local base = CFrame.new()
	local acc = accent(look, C(230, 60, 50))
	for _, x in { -0.35, 0.35 } do
		part(model, "Leg", Vector3.new(0.18, 0.7, 0.18), base * CFrame.new(x, 0.35, 0), C(240, 180, 50))
		part(model, "Foot", Vector3.new(0.4, 0.1, 0.5), base * CFrame.new(x, 0.05, -0.15), C(240, 180, 50))
	end
	part(model, "Body", Vector3.new(1.5, 1.4, 1.9), base * CFrame.new(0, 1.4, 0.1), look.Body)
	local head = base * CFrame.new(0, 2.45, -0.55)
	part(model, "Head", Vector3.new(1, 1, 1), head, look.Body)
	part(model, "Beak", Vector3.new(0.4, 0.3, 0.45), head * CFrame.new(0, -0.05, -0.68), C(250, 190, 50))
	part(model, "Comb", Vector3.new(0.2, 0.45, 0.65), head * CFrame.new(0, 0.7, 0), acc, accMaterial(look))
	eyes(model, head * CFrame.new(0, 0.12, -0.51), look, 0.25, 0.16)
	part(model, "Tail", Vector3.new(0.9, 0.9, 0.3), base * CFrame.new(0, 1.9, 1.15) * CFrame.Angles(math.rad(-25), 0, 0), acc, accMaterial(look))
	if has(look, "Wings") then
		wings(model, base * CFrame.new(0, 1.8, 0.4), look, 3.4)
	else
		for _, x in { -0.8, 0.8 } do
			part(model, "Wing", Vector3.new(0.18, 0.9, 1.3), base * CFrame.new(x, 1.45, 0.15), look.Body:Lerp(C(0, 0, 0), 0.08))
		end
	end
	if has(look, "Aura") then
		aura(model, base * CFrame.new(0, 1.5, 0), acc)
	end
end

-- Arma especial: katana parada con la punta para arriba (unos 5.7 studs), hoja curva que brilla.
-- Body = metal de empuñadura y guarda · Accent = color de la hoja
local function weaponPrize(model: Model, look: CrateItems.Look)
	local metal = look.Body
	local blade = accent(look, C(220, 230, 240))
	local bladeMat = accMaterial(look)
	part(model, "Pommel", Vector3.new(0.38, 0.3, 0.38), CFrame.new(0, 0.3, 0), metal, Enum.Material.Metal)
	part(model, "Grip", Vector3.new(0.28, 1.3, 0.28), CFrame.new(0, 1.1, 0), C(22, 24, 34), Enum.Material.Fabric)
	for i = 0, 3 do
		-- cruces del encordado de la empuñadura
		part(model, "Wrap", Vector3.new(0.32, 0.08, 0.32), CFrame.new(0, 0.6 + i * 0.3, 0) * CFrame.Angles(0, math.rad(45), 0), metal, Enum.Material.Metal)
	end
	local guard = part(model, "Guard", Vector3.new(0.14, 1.05, 1.05), CFrame.new(0, 1.85, 0) * CFrame.Angles(0, 0, math.rad(90)), metal, Enum.Material.Metal)
	guard.Shape = Enum.PartType.Cylinder
	-- Hoja en tramos, cada uno un poco más corrido y girado: queda curva como una katana
	local seg, y, x = 0.62, 1.95, 0
	for i = 0, 5 do
		local bend = 0.035 * (i + 1)
		local width = if i == 5 then 0.17 else 0.3
		local cf = CFrame.new(x + bend / 2, y + seg / 2, 0) * CFrame.Angles(0, 0, -bend * 0.9)
		local b = part(model, "Blade", Vector3.new(width, seg + 0.04, 0.08), cf, blade, bladeMat)
		b.CastShadow = false
		neon(model, "Edge", Vector3.new(0.06, seg + 0.04, 0.09), cf * CFrame.new(width / 2, 0, 0), C(245, 252, 255))
		x += bend
		y += seg
	end
	if has(look, "Aura") then
		aura(model, CFrame.new(x / 2, 3.6, 0), blade)
	end
end

-- Modelo de un premio: pivote en los pies, mirando hacia -Z.
function CrateModels.prize(prizeId: string): Model
	local custom = override("Prizes", prizeId)
	if custom then
		return custom
	end
	local def = CrateItems.ById[prizeId]
	local model = Instance.new("Model")
	model.Name = prizeId
	root(model, CFrame.new())
	if not def then
		part(model, "Unknown", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), C(80, 80, 90))
		return model
	end
	local look = def.Look
	if def.Kind == "Weapon" then
		if prizeId == "VoidBow" or prizeId == "CelestialBow" then
			local bow = require(script.Parent.SpecialBowModels).build(prizeId)
			local box, size = bow:GetBoundingBox()
			bow:PivotTo(bow:GetPivot() + Vector3.new(0, size.Y / 2 - box.Position.Y + 0.2, 0))
			for _, child in bow:GetChildren() do child.Parent = model end
			bow:Destroy()
		else
			weaponPrize(model, look)
		end
	elseif def.Kind == "Pet" then
		if look.Shape == "Slime" then
			slimeModel(model, look)
		elseif look.Shape == "Bird" then
			birdModel(model, look)
		else
			petModel(model, look)
		end
	elseif CrateLooks.has(def.Id) then
		-- Traje detallado (CrateLooks): cuerpo liso y encima las piezas del traje
		humanoidModel(model, { Body = look.Body, Skin = look.Skin, Pants = look.Pants }, false)
		for _, d in model:GetChildren() do
			if d.Name == "Eye" then
				d:Destroy()
			end
		end
		CrateLooks.applyToBlocky(def.Id, model)
	else
		if CrateLooks.has(def.Id) then
			-- Traje detallado (CrateLooks): cuerpo liso y encima las piezas del traje
			humanoidModel(model, { Body = look.Body, Skin = look.Skin, Pants = look.Pants }, false)
			for _, d in model:GetChildren() do
				if d.Name == "Eye" then
					d:Destroy()
				end
			end
			CrateLooks.applyToBlocky(def.Id, model)
		else
			humanoidModel(model, look, def.Id == "LavaGolem")
		end
	end
	return model
end

-- Alto aproximado de un modelo armado acá (para encuadrar la cámara)
function CrateModels.height(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y
end

return CrateModels
