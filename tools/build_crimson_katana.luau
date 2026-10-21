-- Arma el modelo de la Katana Carmesí con piezas y lo deja en el place:
--   ReplicatedStorage > WeaponModels > CrimsonKatana        (arma en primera persona, WeaponFx)
--   ReplicatedStorage > CrateAssets > Prizes > CrimsonKatana (cajas: animación e Index, CrateModels)
-- Uso: pegalo en la barra de comandos de Studio (View › Command Bar) y Enter. Reemplaza los que
-- haya. Después guardá/publicá el place (estos modelos viven en el place, no en src/).
--
-- Mismas convenciones que build_frost_katana.luau: punta hacia +Y, filo hacia +X, de canto
-- mirando a -Z, pivote abajo al centro, sin PrimaryPart. Unos 4.8 de largo.
-- Hoja curva de acero negro con el filo rojo brillante y vetas de energía; guarda cuadrada
-- negra con una gema roja; empuñadura con atado rojo y negro.

local RS = game:GetService("ReplicatedStorage")
local C = Color3.fromRGB

local HANDLE = C(16, 12, 14)
local WRAP = C(170, 10, 30)
local GUARD = C(28, 22, 26)
local GEM = C(255, 30, 55)
local STEEL = C(26, 22, 26)
local EDGE = C(255, 60, 75)
local VEIN = C(220, 15, 40)
local SPINE = C(60, 50, 56)

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

local function build()
	local m = Instance.new("Model")
	m.Name = "CrimsonKatana"

	-- Empuñadura: atado en rombos rojos sobre mango negro
	part(m, "Pommel", Vector3.new(0.3, 0.14, 0.24), CFrame.new(0, 0.07, 0), GUARD, Enum.Material.Metal)
	part(m, "PommelGem", Vector3.new(0.1, 0.1, 0.26), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(45)), GEM, Enum.Material.Neon)
	part(m, "Handle", Vector3.new(0.26, 1.25, 0.2), CFrame.new(0, 0.77, 0), HANDLE, Enum.Material.Fabric)
	for i = 0, 5 do
		local y = 0.27 + i * 0.2
		for _, z in { -0.105, 0.105 } do
			part(m, "Wrap", Vector3.new(0.17, 0.17, 0.02), CFrame.new(0, y, z) * CFrame.Angles(0, 0, math.rad(45)), WRAP)
		end
	end
	part(m, "Collar", Vector3.new(0.3, 0.08, 0.24), CFrame.new(0, 1.43, 0), SPINE, Enum.Material.Metal)

	-- Guarda cuadrada con esquinas cortadas y una gema roja al centro
	part(m, "Guard", Vector3.new(0.86, 0.1, 0.62), CFrame.new(0, 1.51, 0), GUARD, Enum.Material.Metal)
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			part(m, "GuardCorner", Vector3.new(0.16, 0.11, 0.16), CFrame.new(sx * 0.4, 1.51, sz * 0.28) * CFrame.Angles(0, math.rad(45), 0), VEIN, Enum.Material.Neon)
		end
	end
	part(m, "GuardGem", Vector3.new(0.16, 0.16, 0.66), CFrame.new(0, 1.51, 0) * CFrame.Angles(0, 0, math.rad(45)), GEM, Enum.Material.Neon)
	part(m, "Collar", Vector3.new(0.3, 0.14, 0.12), CFrame.new(0, 1.63, 0), SPINE, Enum.Material.Metal)

	-- Hoja: tramos con curva hacia el lomo (-X); acero negro, filo rojo y vetas de energía
	local segs, segLen, y0 = 5, 0.58, 1.7
	local last
	for i = 0, segs - 1 do
		local x = -0.013 * i * i
		local nx = -0.013 * (i + 1) * (i + 1)
		local tilt = math.atan2(nx - x, segLen)
		local width = 0.3 - i * 0.012
		local cf = CFrame.new((x + nx) / 2, y0 + segLen * (i + 0.5), 0) * CFrame.Angles(0, 0, -tilt)
		local blade = part(m, "Blade", Vector3.new(width, segLen + 0.02, 0.07), cf, STEEL, Enum.Material.Metal)
		blade.CastShadow = false
		part(m, "Edge", Vector3.new(0.05, segLen + 0.02, 0.075), cf * CFrame.new(width / 2 - 0.022, 0, 0), EDGE, Enum.Material.Neon)
		part(m, "Spine", Vector3.new(0.04, segLen + 0.02, 0.075), cf * CFrame.new(-width / 2 + 0.02, 0, 0), SPINE, Enum.Material.Metal)
		-- Veta de energía en zigzag por el medio de la hoja
		local zig = if i % 2 == 0 then 0.035 else -0.035
		part(m, "Vein", Vector3.new(0.03, segLen * 0.9, 0.074), cf * CFrame.new(zig, 0, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 6 else -6)), VEIN, Enum.Material.Neon)
		last = { cf = cf, width = width }
	end
	-- Punta: cuña alta del lado del lomo que baja hacia el filo
	local tipH = 0.55
	local tipBase = last.cf * CFrame.new(0, segLen / 2 + tipH / 2, 0)
	local tip = part(m, "BladeTip", Vector3.new(0.07, tipH, last.width), tipBase * CFrame.Angles(0, math.rad(-90), 0), STEEL, Enum.Material.Metal, "WedgePart")
	tip.CastShadow = false
	local w = last.width
	local diag = math.sqrt(w * w + tipH * tipH)
	local inward = Vector3.new(-tipH, -w, 0).Unit * 0.03
	part(m, "EdgeTip", Vector3.new(0.05, diag, 0.075), tipBase * CFrame.new(inward) * CFrame.Angles(0, 0, math.atan2(w, tipH)), EDGE, Enum.Material.Neon)

	-- Pieza invisible a lo largo de toda la hoja: de acá salen las llamas del aura (AnimeFx)
	local auraLen = segs * segLen + tipH
	local aura = part(m, "BladeAura", Vector3.new(0.26, auraLen, 0.05), CFrame.new(-0.12, y0 + auraLen / 2, 0), VEIN)
	aura.Transparency = 1
	aura.CastShadow = false

	-- Brillo rojo
	local glow = Instance.new("PointLight")
	glow.Color = GEM
	glow.Range = 4
	glow.Brightness = 0.8
	glow.Parent = m:FindFirstChild("Blade")

	m.WorldPivot = CFrame.new(0, 0, 0) -- abajo al centro; sin PrimaryPart
	return m
end

-- Arma en primera persona
local weaponModels = RS:FindFirstChild("WeaponModels")
if not weaponModels then
	weaponModels = Instance.new("Folder")
	weaponModels.Name = "WeaponModels"
	weaponModels.Parent = RS
end
local old = weaponModels:FindFirstChild("CrimsonKatana")
if old then old:Destroy() end
local fp = build()
fp:SetAttribute("Rotation", Vector3.new(0, 180, 0)) -- filo a la izquierda, como la de escarcha
fp.Parent = weaponModels

-- Premio de la caja (con chispas rojas que suben)
local assets = RS:FindFirstChild("CrateAssets") or Instance.new("Folder")
assets.Name = "CrateAssets"
assets.Parent = RS
local prizes = assets:FindFirstChild("Prizes") or Instance.new("Folder")
prizes.Name = "Prizes"
prizes.Parent = assets
old = prizes:FindFirstChild("CrimsonKatana")
if old then old:Destroy() end
local display = build()
local core = part(display, "AuraCore", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 2.9, 0), GEM)
core.Transparency = 1
local sparks = Instance.new("ParticleEmitter")
sparks.Name = "Crimson"
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(C(255, 90, 100), C(160, 0, 20))
sparks.LightEmission = 1
sparks.Size = NumberSequence.new(0.25, 0)
sparks.Lifetime = NumberRange.new(0.8, 1.4)
sparks.Rate = 12
sparks.Speed = NumberRange.new(0.4, 1.2)
sparks.SpreadAngle = Vector2.new(180, 180)
sparks.Acceleration = Vector3.new(0, 0.8, 0)
sparks.Parent = core
local light = Instance.new("PointLight")
light.Color = GEM
light.Range = 8
light.Brightness = 1.2
light.Parent = core
display.Parent = prizes

print("[CrimsonKatana] modelo listo: WeaponModels.CrimsonKatana y CrateAssets.Prizes.CrimsonKatana")
