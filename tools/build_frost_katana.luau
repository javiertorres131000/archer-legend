-- Arma el modelo de la Katana de Escarcha con piezas y lo deja en el place:
--   ReplicatedStorage > WeaponModels > FrostKatana        (arma en primera persona, WeaponFx)
--   ReplicatedStorage > CrateAssets > Prizes > FrostKatana (cajas: animación e Index, CrateModels)
-- Uso: pegalo en la barra de comandos de Studio (View › Command Bar) y Enter. Reemplaza los que
-- haya. Después guardá/publicá el place (estos modelos viven en el place, no en src/).
--
-- Medidas en studs, punta hacia +Y, filo hacia +X, de canto mirando a -Z. Unos 4.6 de largo.
-- WeaponFx lo escala solo; para las cajas el pivote queda abajo al centro.

local RS = game:GetService("ReplicatedStorage")
local C = Color3.fromRGB

local HANDLE = C(18, 28, 58)
local WRAP = C(225, 240, 255)
local SILVER = C(200, 225, 245)
local ICE = C(165, 222, 255)
local EDGE = C(240, 252, 255)
local HAMON = C(120, 205, 255)
local SPINE = C(60, 110, 190)
local GROOVE = C(40, 80, 150)

local function part(model, name, size, cf, color, material, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Cristal de hielo: prisma de rombo (bloque girado 45° sobre su largo) con punta
local function crystal(model, base, dir, length, thick)
	dir = dir.Unit
	local cf = CFrame.lookAt(base + dir * length / 2, base + dir * length) * CFrame.Angles(0, 0, math.rad(45))
	local c = part(model, "Crystal", Vector3.new(thick, thick, length), cf, ICE, Enum.Material.Ice)
	c.Transparency = 0.12
	local tip = part(model, "CrystalTip", Vector3.new(thick * 0.55, thick * 0.55, length * 0.3), cf * CFrame.new(0, 0, -length * 0.6), EDGE, Enum.Material.Neon)
	tip.Transparency = 0.2
	return c
end

local function build()
	local m = Instance.new("Model")
	m.Name = "FrostKatana"

	-- Empuñadura
	part(m, "Pommel", Vector3.new(0.3, 0.14, 0.24), CFrame.new(0, 0.07, 0), SILVER, Enum.Material.Metal)
	part(m, "Handle", Vector3.new(0.26, 1.2, 0.2), CFrame.new(0, 0.74, 0), HANDLE, Enum.Material.Fabric)
	for i = 0, 5 do
		local y = 0.25 + i * 0.2
		for _, z in { -0.105, 0.105 } do
			part(m, "Wrap", Vector3.new(0.17, 0.17, 0.02), CFrame.new(0, y, z) * CFrame.Angles(0, 0, math.rad(45)), WRAP)
		end
	end
	part(m, "Collar", Vector3.new(0.3, 0.08, 0.24), CFrame.new(0, 1.38, 0), SILVER, Enum.Material.Metal)

	-- Guarda: disco de hielo con cristales hacia los costados
	part(m, "Guard", Vector3.new(0.1, 0.9, 0.9), CFrame.new(0, 1.47, 0) * CFrame.Angles(0, 0, math.rad(90)), SILVER, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	local rim = part(m, "GuardIce", Vector3.new(0.06, 0.98, 0.98), CFrame.new(0, 1.47, 0) * CFrame.Angles(0, 0, math.rad(90)), ICE, Enum.Material.Ice)
	rim.Shape = Enum.PartType.Cylinder
	rim.Transparency = 0.35
	local g = Vector3.new(0, 1.47, 0)
	crystal(m, g + Vector3.new(0.4, 0, 0), Vector3.new(1, 0.25, 0), 0.5, 0.13)
	crystal(m, g + Vector3.new(-0.4, 0, 0), Vector3.new(-1, 0.25, 0), 0.5, 0.13)
	crystal(m, g + Vector3.new(0.3, 0, 0.18), Vector3.new(0.8, 0.6, 0.3), 0.3, 0.09)
	crystal(m, g + Vector3.new(-0.3, 0, -0.18), Vector3.new(-0.8, 0.6, -0.3), 0.3, 0.09)
	part(m, "Collar", Vector3.new(0.3, 0.16, 0.12), CFrame.new(0, 1.6, 0), SILVER, Enum.Material.Metal)

	-- Hoja: tramos con curva hacia el lomo (-X); filo brillante, línea de temple y canal
	local segs, segLen, y0 = 5, 0.56, 1.68
	local last
	for i = 0, segs - 1 do
		local x = -0.012 * i * i
		local nx = -0.012 * (i + 1) * (i + 1)
		local tilt = math.atan2(nx - x, segLen)
		local width = 0.28 - i * 0.012
		local cf = CFrame.new((x + nx) / 2, y0 + segLen * (i + 0.5), 0) * CFrame.Angles(0, 0, -tilt)
		local blade = part(m, "Blade", Vector3.new(width, segLen + 0.02, 0.07), cf, ICE, Enum.Material.Ice)
		blade.CastShadow = false
		part(m, "Edge", Vector3.new(0.045, segLen + 0.02, 0.075), cf * CFrame.new(width / 2 - 0.02, 0, 0), EDGE, Enum.Material.Neon)
		part(m, "Hamon", Vector3.new(0.025, segLen + 0.02, 0.072), cf * CFrame.new(width / 2 - 0.08 + (i % 2) * 0.02, 0, 0), HAMON, Enum.Material.Neon)
		part(m, "Spine", Vector3.new(0.045, segLen + 0.02, 0.075), cf * CFrame.new(-width / 2 + 0.02, 0, 0), SPINE, Enum.Material.Metal)
		if i < segs - 1 then
			part(m, "Groove", Vector3.new(0.035, segLen + 0.02, 0.074), cf * CFrame.new(-width / 2 + 0.07, 0, 0), GROOVE, Enum.Material.Metal)
		end
		last = { cf = cf, width = width, tilt = tilt }
	end
	-- Punta (kissaki): cuña alta del lado del lomo que baja hacia el filo
	local tipH = 0.5
	local tipBase = last.cf * CFrame.new(0, segLen / 2 + tipH / 2, 0)
	local tip = part(m, "BladeTip", Vector3.new(0.07, tipH, last.width), tipBase * CFrame.Angles(0, math.rad(-90), 0), ICE, Enum.Material.Ice, "WedgePart")
	tip.CastShadow = false
	-- Filo de la punta: sigue la diagonal (del filo abajo al lomo arriba), corrido hacia adentro
	local w = last.width
	local diag = math.sqrt(w * w + tipH * tipH)
	local inward = Vector3.new(-tipH, -w, 0).Unit * 0.03
	local edgeTip = part(m, "EdgeTip", Vector3.new(0.05, diag, 0.075), tipBase * CFrame.new(inward) * CFrame.Angles(0, 0, math.atan2(w, tipH)), EDGE, Enum.Material.Neon)
	edgeTip.CastShadow = false

	-- Pieza invisible a lo largo de toda la hoja: de acá salen las llamas del aura (AnimeFx)
	local auraLen = segs * segLen + tipH
	local aura = part(m, "BladeAura", Vector3.new(0.24, auraLen, 0.05), CFrame.new(-0.12, y0 + auraLen / 2, 0), ICE)
	aura.Transparency = 1
	aura.CastShadow = false

	-- Escarcha: cristales que crecen del lomo cerca de la base
	for i, h in { 1.95, 2.35, 2.8 } do
		local x = -0.14 - 0.012 * ((h - y0) / segLen) ^ 2
		crystal(m, Vector3.new(x, h, 0), Vector3.new(-1, 0.9 + i * 0.2, (i % 2 == 0) and 0.25 or -0.25), 0.32 - i * 0.04, 0.09)
	end

	-- Brillo suave
	local glow = Instance.new("PointLight")
	glow.Color = HAMON
	glow.Range = 4
	glow.Brightness = 0.6
	glow.Parent = m:FindFirstChild("Blade")

	-- Sin PrimaryPart: con ella Roblox ignora WorldPivot (y el arma queda corrida de la mano)
	m.WorldPivot = CFrame.new(0, 0, 0) -- abajo al centro (las cajas lo apoyan ahí)
	return m
end

-- Arma en primera persona
local weaponModels = RS:FindFirstChild("WeaponModels")
if not weaponModels then
	weaponModels = Instance.new("Folder")
	weaponModels.Name = "WeaponModels"
	weaponModels.Parent = RS
end
local old = weaponModels:FindFirstChild("FrostKatana")
if old then old:Destroy() end
build().Parent = weaponModels

-- Premio de la caja (con chispas de hielo alrededor)
local assets = RS:FindFirstChild("CrateAssets") or Instance.new("Folder")
assets.Name = "CrateAssets"
assets.Parent = RS
local prizes = assets:FindFirstChild("Prizes") or Instance.new("Folder")
prizes.Name = "Prizes"
prizes.Parent = assets
old = prizes:FindFirstChild("FrostKatana")
if old then old:Destroy() end
local display = build()
local core = part(display, "AuraCore", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 2.8, 0), ICE)
core.Transparency = 1
local sparks = Instance.new("ParticleEmitter")
sparks.Name = "Frost"
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(C(170, 230, 255))
sparks.LightEmission = 1
sparks.Size = NumberSequence.new(0.25, 0)
sparks.Lifetime = NumberRange.new(0.8, 1.4)
sparks.Rate = 10
sparks.Speed = NumberRange.new(0.3, 1)
sparks.SpreadAngle = Vector2.new(180, 180)
sparks.Acceleration = Vector3.new(0, 0.6, 0)
sparks.Parent = core
local light = Instance.new("PointLight")
light.Color = ICE
light.Range = 8
light.Brightness = 1
light.Parent = core
display.Parent = prizes

print("[FrostKatana] modelo listo: WeaponModels.FrostKatana y CrateAssets.Prizes.FrostKatana")
