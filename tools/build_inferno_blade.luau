-- Arma el modelo de la Hoja Infernal con piezas y lo deja en el place:
--   ReplicatedStorage > WeaponModels > InfernoBlade        (arma en primera persona, WeaponFx)
--   ReplicatedStorage > CrateAssets > Prizes > InfernoBlade (cajas: animación e Index, CrateModels)
-- Uso: pegalo en la barra de comandos de Studio (View › Command Bar) y Enter. Reemplaza los que
-- haya. Después guardá/publicá el place (estos modelos viven en el place, no en src/).
--
-- Mismas convenciones que build_frost_katana.luau: punta hacia +Y, filo hacia +X, de canto
-- mirando a -Z, pivote abajo al centro, sin PrimaryPart. Unos 4.8 de largo.
-- Hoja ancha de doble filo, de acero negro con grietas de lava y filos al rojo.

local RS = game:GetService("ReplicatedStorage")
local C = Color3.fromRGB

local GRIP = C(40, 18, 14)
local WRAP = C(150, 30, 20)
local GOLD = C(210, 150, 50)
local STEEL = C(38, 30, 32)
local EDGE = C(255, 150, 50)
local LAVA = C(255, 90, 20)
local CORE = C(255, 230, 160)
local HORN = C(25, 18, 18)

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

-- Cuerno curvo de la guarda: tres tramos que se afinan y se doblan hacia arriba
local function horn(model, base, side)
	local pos = base
	local dir = Vector3.new(side, 0.15, 0).Unit
	local thick = 0.16
	for i = 1, 3 do
		local len = 0.24
		local cf = CFrame.lookAt(pos + dir * len / 2, pos + dir * len)
		part(model, "Horn", Vector3.new(thick, thick, len + 0.02), cf, HORN, Enum.Material.Slate)
		pos += dir * len
		dir = (dir + Vector3.new(0, 0.55, 0)).Unit
		thick *= 0.72
	end
	local tip = part(model, "HornTip", Vector3.new(thick, thick, 0.16), CFrame.lookAt(pos + dir * 0.08, pos + dir * 0.16), LAVA, Enum.Material.Neon)
	tip.Transparency = 0.1
end

local function build()
	local m = Instance.new("Model")
	m.Name = "InfernoBlade"

	-- Empuñadura
	part(m, "Pommel", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	part(m, "PommelGem", Vector3.new(0.12, 0.12, 0.28), CFrame.new(0, 0.1, 0), LAVA, Enum.Material.Neon)
	part(m, "Handle", Vector3.new(0.24, 1.15, 0.2), CFrame.new(0, 0.78, 0), GRIP, Enum.Material.Fabric)
	for i = 0, 4 do
		part(m, "Wrap", Vector3.new(0.27, 0.07, 0.23), CFrame.new(0, 0.34 + i * 0.22, 0) * CFrame.Angles(0, 0, math.rad(-12)), WRAP, Enum.Material.Fabric)
	end

	-- Guarda dorada con cuernos y una gema de lava al centro
	part(m, "Guard", Vector3.new(0.95, 0.18, 0.3), CFrame.new(0, 1.43, 0), GOLD, Enum.Material.Metal)
	part(m, "GuardGem", Vector3.new(0.18, 0.18, 0.34), CFrame.new(0, 1.43, 0) * CFrame.Angles(0, 0, math.rad(45)), LAVA, Enum.Material.Neon)
	horn(m, Vector3.new(0.45, 1.45, 0), 1)
	horn(m, Vector3.new(-0.45, 1.45, 0), -1)

	-- Hoja ancha y recta: cuerpo negro, filos al rojo a los dos lados, grieta de lava al centro
	local y0, len, width = 1.52, 2.9, 0.42
	local body = CFrame.new(0, y0 + len / 2, 0)
	local blade = part(m, "Blade", Vector3.new(width, len, 0.08), body, STEEL, Enum.Material.Metal)
	blade.CastShadow = false
	for _, side in { 1, -1 } do
		part(m, "Edge", Vector3.new(0.05, len, 0.085), body * CFrame.new(side * (width / 2 - 0.02), 0, 0), EDGE, Enum.Material.Neon)
	end
	-- Grieta en zigzag por el centro de la hoja
	local cy = y0 + 0.15
	local x = 0
	for i = 1, 7 do
		local h = 0.36
		local nx = if i % 2 == 0 then 0.05 else -0.05
		local a = Vector3.new(x, cy, 0)
		local b = Vector3.new(nx, cy + h, 0)
		local mid = (a + b) / 2
		local tilt = math.atan2(b.X - a.X, b.Y - a.Y)
		part(m, "Crack", Vector3.new(0.05, (b - a).Magnitude + 0.02, 0.09), CFrame.new(mid) * CFrame.Angles(0, 0, -tilt), LAVA, Enum.Material.Neon)
		x, cy = nx, cy + h
	end
	-- Ramas de la grieta
	for i, y in { 1.95, 2.6, 3.3 } do
		local s = if i % 2 == 0 then 1 else -1
		part(m, "Crack", Vector3.new(0.035, 0.22, 0.09), CFrame.new(s * 0.08, y, 0) * CFrame.Angles(0, 0, math.rad(-50 * s)), LAVA, Enum.Material.Neon)
	end
	part(m, "Fuller", Vector3.new(0.03, len * 0.7, 0.088), body * CFrame.new(0, -len * 0.1, 0), CORE, Enum.Material.Neon).Transparency = 0.5

	-- Punta: dos cuñas espejadas que cierran en el centro, con los filos siguiendo la diagonal
	local tipH = 0.6
	local top = y0 + len
	for _, side in { 1, -1 } do
		local cf = CFrame.new(side * width / 4, top + tipH / 2, 0) * CFrame.Angles(0, if side > 0 then math.rad(90) else math.rad(-90), 0)
		local w = part(m, "BladeTip", Vector3.new(0.08, tipH, width / 2), cf, STEEL, Enum.Material.Metal, "WedgePart")
		w.CastShadow = false
		local diag = math.sqrt((width / 2) ^ 2 + tipH ^ 2)
		part(
			m,
			"EdgeTip",
			Vector3.new(0.045, diag, 0.085),
			CFrame.new(side * width / 4, top + tipH / 2, 0) * CFrame.Angles(0, 0, side * math.atan2(width / 2, tipH)),
			EDGE,
			Enum.Material.Neon
		)
	end

	-- Pieza invisible a lo largo de toda la hoja: de acá salen las llamas del aura (AnimeFx)
	local auraLen = len + tipH
	local aura = part(m, "BladeAura", Vector3.new(0.3, auraLen, 0.05), CFrame.new(0, y0 + auraLen / 2, 0), LAVA)
	aura.Transparency = 1
	aura.CastShadow = false

	-- Brillo cálido
	local glow = Instance.new("PointLight")
	glow.Color = LAVA
	glow.Range = 4
	glow.Brightness = 0.8
	glow.Parent = blade

	-- Sin PrimaryPart: con ella Roblox ignora WorldPivot (y el arma queda corrida de la mano)
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

-- Arma en primera persona
local weaponModels = RS:FindFirstChild("WeaponModels")
if not weaponModels then
	weaponModels = Instance.new("Folder")
	weaponModels.Name = "WeaponModels"
	weaponModels.Parent = RS
end
local old = weaponModels:FindFirstChild("InfernoBlade")
if old then old:Destroy() end
local fp = build()
fp:SetAttribute("Rotation", Vector3.new(0, 180, 0))
fp.Parent = weaponModels

-- Premio de la caja (con brasas que suben)
local assets = RS:FindFirstChild("CrateAssets") or Instance.new("Folder")
assets.Name = "CrateAssets"
assets.Parent = RS
local prizes = assets:FindFirstChild("Prizes") or Instance.new("Folder")
prizes.Name = "Prizes"
prizes.Parent = assets
old = prizes:FindFirstChild("InfernoBlade")
if old then old:Destroy() end
local display = build()
local core = part(display, "AuraCore", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 2.9, 0), LAVA)
core.Transparency = 1
local embers = Instance.new("ParticleEmitter")
embers.Name = "Embers"
embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
embers.Color = ColorSequence.new(C(255, 200, 90), C(255, 60, 20))
embers.LightEmission = 1
embers.Size = NumberSequence.new(0.25, 0)
embers.Lifetime = NumberRange.new(0.8, 1.4)
embers.Rate = 12
embers.Speed = NumberRange.new(0.5, 1.4)
embers.SpreadAngle = Vector2.new(60, 60)
embers.EmissionDirection = Enum.NormalId.Top
embers.Acceleration = Vector3.new(0, 1.2, 0)
embers.Parent = core
local light = Instance.new("PointLight")
light.Color = LAVA
light.Range = 8
light.Brightness = 1.2
light.Parent = core
display.Parent = prizes

print("[InfernoBlade] modelo listo: WeaponModels.InfernoBlade y CrateAssets.Prizes.InfernoBlade")
