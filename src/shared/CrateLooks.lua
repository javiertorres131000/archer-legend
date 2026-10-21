--!strict
-- CrateLooks (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > CrateLooks
-- Trajes detallados de los premios de personaje: piezas (armadura, mallas, alas...) pegadas al
-- cuerpo, color y material de la piel y partículas. Un premio con traje acá se ve así:
--   · en tu avatar al equiparlo (CrateEquip, avatar R15: las piezas se sueldan a cada segmento)
--   · en el Index y en la animación de apertura (CrateModels, sobre el modelo de bloques)
-- Los premios sin traje usan el aspecto simple de CrateItems (Look).
--
-- CÓMO AGREGAR UN TRAJE: una entrada con el Id del premio. Cada pieza:
--   { Seg = "Torso" | "Head" | "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg",
--     Name, Size, Color, Material, CF = posición respecto del centro de ese segmento,
--     Transparency?, Light? = { Color, Range, Brightness }, Face? = true, Shape?,
--     Mesh? = nombre de una MeshPart en ReplicatedStorage > CrateAssets > Looks > <MeshFolder>,
--     Glow? = { Tint, Strength } (brillo de la máscara de lava de la malla),
--     Fx? = { { Kind = "Flames" | "Embers" | "Smoke", Rate, Size? } },
--     Sway? = { Kind = "Wing" | "Cape", Pivot, Side? } (balanceo en el avatar, lo anima LavaSkinFx) }
-- Las medidas son las de un cuerpo de bloques clásico (R6): torso 2x2x1, brazos y piernas
-- 1x2x1 (CF relativo al centro del miembro entero) y cabeza ~1.2. Face = true: la pieza va
-- pegada al frente de la cara (su Z se calcula sola según la cabeza).
-- Tags para el cliente (LavaSkinFx): "LavaGlow" (brillo/luz que late, atributo GlowBase) y
-- "LavaSway" (Welds de alas y capa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local CrateLooks = {}

export type LookPart = {
	Seg: string,
	Name: string,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	CF: CFrame,
	Transparency: number?,
	Light: { Color: Color3, Range: number, Brightness: number }?,
	Face: boolean?,
	Shape: (Enum.PartType | "Wedge")?,
	Mesh: string?,
	Glow: { Tint: Color3, Strength: number }?,
	Fx: { { Kind: string, Rate: number, Size: number? } }?,
	Sway: { Kind: string, Pivot: Vector3, Side: number? }?,
}
export type Look = {
	Skin: Color3, -- color de todo el cuerpo
	SkinMaterial: Enum.Material,
	Parts: { LookPart },
	Embers: { Colors: { Color3 }, Rate: number }?, -- brasas que salen del pecho
	MeshFolder: string?, -- carpeta en ReplicatedStorage > CrateAssets > Looks con las mallas
}

local C = Color3.fromRGB

---------------------------------------------------------------------
-- Demonio Ígneo: armadura de mallas (MeshParts con textura, relieve y brillo de lava)
-- Las mallas están en ReplicatedStorage > CrateAssets > Looks > FireDemon (viven en el place,
-- no en el repo). Cada pieza se clona y se pega al segmento indicado.
-- (El traje anterior, con Parts, quedó en ServerStorage > CrateLooks_backup.)
---------------------------------------------------------------------
do
	local lava = C(255, 91, 13)
	local gold = C(255, 119, 22)
	local obsidian = C(23, 17, 24)
	local armorGlow = { Tint = C(255, 75, 15), Strength = 2.2 }
	local wingGlow = { Tint = C(255, 45, 10), Strength = 1.3 }
	local warmLight = { Color = C(255, 80, 20), Range = 6, Brightness = 1 }
	local chestLight = { Color = C(255, 80, 20), Range = 8, Brightness = 1 }
	type FxList = { { Kind: string, Rate: number, Size: number? } }
	local wingFx: FxList = { { Kind = "Flames", Rate = 18, Size = 0.9 }, { Kind = "Embers", Rate = 6 } }
	local shoulderFx: FxList = { { Kind = "Embers", Rate = 4 }, { Kind = "Smoke", Rate = 1.5, Size = 0.4 } }

	local function mesh(seg: string, name: string, cf: CFrame, extra: { [string]: any }?): LookPart
		local def: { [string]: any } = {
			Seg = seg,
			Name = name,
			Mesh = name,
			Size = Vector3.one,
			Color = obsidian,
			Material = Enum.Material.SmoothPlastic,
			CF = cf,
			Glow = armorGlow,
		}
		if extra then
			for k, v in extra do
				def[k] = v
			end
		end
		return def :: any
	end

	CrateLooks.FireDemon = {
		Skin = obsidian,
		SkinMaterial = Enum.Material.Slate,
		MeshFolder = "FireDemon",
		Parts = {
			mesh("Head", "Mascara", CFrame.new(0, 0.86, 0), { Fx = { { Kind = "Flames", Rate = 8, Size = 0.5 } }, Light = warmLight }),
			mesh("Torso", "Torso", CFrame.new(0, 0.05, 0), { Fx = { { Kind = "Embers", Rate = 5 }, { Kind = "Smoke", Rate = 3, Size = 0.7 } }, Light = chestLight }),
			mesh("Torso", "Capa", CFrame.new(0, -0.9, 0.85), { Sway = { Kind = "Cape", Pivot = Vector3.new(0, 1.85, -0.2) } }),
			mesh("Torso", "Ala_L", CFrame.new(-2.2, 1.2, 1.1), { Glow = wingGlow, Sway = { Kind = "Wing", Pivot = Vector3.new(1.6, 0.8, -0.3), Side = 1 }, Fx = wingFx }),
			mesh("Torso", "Ala_R", CFrame.new(2.2, 1.2, 1.1), { Glow = wingGlow, Sway = { Kind = "Wing", Pivot = Vector3.new(-1.6, 0.8, -0.3), Side = -1 }, Fx = wingFx }),
			mesh("Torso", "Taparrabos", CFrame.new(0, -1.55, -0.55)),
			mesh("LeftArm", "Hombrera_L", CFrame.new(0, 0.55, 0), { Fx = shoulderFx }),
			mesh("RightArm", "Hombrera_R", CFrame.new(0, 0.55, 0), { Fx = shoulderFx }),
			mesh("LeftArm", "Brazal_L", CFrame.new(0, -0.45, 0)),
			mesh("RightArm", "Brazal_R", CFrame.new(0, -0.45, 0)),
			mesh("LeftLeg", "Greba_L", CFrame.new(0, -0.5, 0)),
			mesh("RightLeg", "Greba_R", CFrame.new(0, -0.5, 0)),
		},
		Embers = { Colors = { lava, gold }, Rate = 6 },
	} :: Look
end

---------------------------------------------------------------------
-- Armar un traje sobre un cuerpo
---------------------------------------------------------------------

-- Dónde está cada segmento "clásico" en este cuerpo: devuelve (pieza a la que se pega,
-- CFrame del centro del segmento como si fuera de bloques clásico).
type Resolver = (seg: string, offsetY: number) -> (BasePart?, CFrame?)

local function find(model: Instance, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- Avatar R15: el miembro clásico de 2 studs se reparte en 3 piezas (de arriba abajo). Cada pieza
-- del traje se suelda a la que le toca por altura, así acompaña la animación.
local function r15(character: Model): Resolver
	return function(seg: string, offsetY: number): (BasePart?, CFrame?)
		if seg == "Head" then
			local head = find(character, "Head")
			return head, if head then head.CFrame else nil
		elseif seg == "Torso" then
			local upper = find(character, "UpperTorso")
			if not upper then
				return nil, nil
			end
			return upper, upper.CFrame * CFrame.new(0, upper.Size.Y / 2 - 1, 0)
		end
		local side = if string.sub(seg, 1, 4) == "Left" then "Left" else "Right"
		local limb = if string.find(seg, "Arm") then "Arm" else "Leg"
		local upper = find(character, side .. "Upper" .. limb)
		if not upper then
			return nil, nil
		end
		local center = upper.CFrame * CFrame.new(0, upper.Size.Y / 2 - 1, 0)
		local partName = if offsetY >= 0.2 then side .. "Upper" .. limb
			elseif offsetY > -0.75 then side .. "Lower" .. limb
			else side .. (if limb == "Arm" then "Hand" else "Foot")
		return find(character, partName) or upper, center
	end
end

-- Modelo de bloques de CrateModels (Torso, Head, Arm, Leg; izquierda = X negativa)
local function blocky(model: Model): Resolver
	local root = model.PrimaryPart
	local origin = if root then root.CFrame else model:GetPivot()
	return function(seg: string, _offsetY: number): (BasePart?, CFrame?)
		if seg == "Head" or seg == "Torso" then
			local p = find(model, seg)
			return p, if p then p.CFrame else nil
		end
		local wantLeft = string.sub(seg, 1, 4) == "Left"
		local name = if string.find(seg, "Arm") then "Arm" else "Leg"
		for _, c in model:GetChildren() do
			if c:IsA("BasePart") and c.Name == name then
				local x = origin:PointToObjectSpace(c.Position).X
				if (x < 0) == wantLeft then
					return c, c.CFrame
				end
			end
		end
		return nil, nil
	end
end

-- Partículas de una pieza: llamas, brasas o humo
local function addFx(part: BasePart, fx: { Kind: string, Rate: number, Size: number? })
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = fx.Rate
	if fx.Kind == "Flames" then
		local s = fx.Size or 0.6
		e.Name = "FxLlamas"
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Lifetime = NumberRange.new(0.35, 0.7)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 170, 60)),
			ColorSequenceKeypoint.new(0.5, C(255, 70, 15)),
			ColorSequenceKeypoint.new(1, C(120, 10, 5)),
		})
		e.Size = NumberSequence.new(s, 0)
		e.Transparency = NumberSequence.new(0.3, 1)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
	elseif fx.Kind == "Smoke" then
		local s = fx.Size or 0.6
		e.Name = "FxHumo"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightEmission = 0
		e.LightInfluence = 1
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(0.4, 1)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.Color = ColorSequence.new(C(40, 25, 22), C(15, 10, 10))
		e.Size = NumberSequence.new(s, s * 2.5)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-30, 30)
	else
		e.Name = "FxBrasas"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(0, 3, 0)
		e.Color = ColorSequence.new(C(255, 200, 80), C(255, 40, 10))
		e.Size = NumberSequence.new(fx.Size or 0.18, 0)
		e.Transparency = NumberSequence.new(0, 1)
		e.RotSpeed = NumberRange.new(-120, 120)
	end
	e.Parent = part
end

local function meshTemplate(folderName: string?, name: string): MeshPart?
	local assets = ReplicatedStorage:FindFirstChild("CrateAssets")
	local looks = assets and assets:FindFirstChild("Looks")
	local folder = looks and folderName and looks:FindFirstChild(folderName)
	local t = folder and folder:FindFirstChild(name)
	return if t and t:IsA("MeshPart") then t else nil
end

local function weldTo(base: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
end

-- Pieza de malla (clonada de CrateAssets > Looks): brillo, luz, partículas y balanceo
local function buildMesh(look: Look, def: LookPart, folder: Instance, base: BasePart, cf: CFrame, weld: boolean)
	local template = meshTemplate(look.MeshFolder, def.Mesh :: string)
	if not template then
		return
	end
	local m = template:Clone()
	m.Name = def.Name
	m.Transparency = def.Transparency or 0
	m.CanCollide = false
	m.CanTouch = false
	m.CanQuery = false
	m.Massless = true
	m.CFrame = cf
	m.Anchored = not weld
	if weld and def.Sway then
		-- Weld (no WeldConstraint) para que el cliente (LavaSkinFx) la pueda balancear
		local w = Instance.new("Weld")
		w.Name = "SwayWeld"
		w.Part0 = base
		w.Part1 = m
		w.C0 = base.CFrame:ToObjectSpace(m.CFrame)
		w:SetAttribute("Kind", def.Sway.Kind)
		w:SetAttribute("Pivot", def.Sway.Pivot)
		w:SetAttribute("Side", def.Sway.Side or 0)
		CollectionService:AddTag(w, "LavaSway")
		w.Parent = m
	elseif weld then
		weldTo(base, m)
	end
	local sa = m:FindFirstChildOfClass("SurfaceAppearance")
	if sa and def.Glow then
		sa.EmissiveTint = def.Glow.Tint
		sa.EmissiveStrength = def.Glow.Strength
		-- LavaSkinFx (cliente) hace latir el brillo alrededor de este valor
		sa:SetAttribute("GlowBase", def.Glow.Strength)
		CollectionService:AddTag(sa, "LavaGlow")
	end
	if def.Light then
		local light = Instance.new("PointLight")
		light.Color = def.Light.Color
		light.Range = def.Light.Range
		light.Brightness = def.Light.Brightness
		light:SetAttribute("GlowBase", def.Light.Brightness)
		CollectionService:AddTag(light, "LavaGlow")
		light.Parent = m
	end
	if def.Fx then
		for _, fx in def.Fx do
			addFx(m, fx)
		end
	end
	m.Parent = folder
end

local function build(look: Look, folder: Instance, resolve: Resolver, weld: boolean)
	for _, def in look.Parts do
		local base, center = resolve(def.Seg, def.CF.Position.Y)
		if not base or not center then
			continue
		end
		local cf = def.CF
		if def.Face then
			-- Pegada al frente de la cabeza, apenas afuera
			cf = CFrame.new(cf.Position.X, cf.Position.Y, -base.Size.Z / 2 - def.Size.Z / 2 + 0.02) * cf.Rotation
		end
		if def.Mesh then
			buildMesh(look, def, folder, base, center * cf, weld)
			continue
		end
		local p: BasePart
		if def.Shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = def.Shape or Enum.PartType.Block
			p = part
		end
		p.Name = def.Name
		p.Size = def.Size
		p.Color = def.Color
		p.Material = def.Material
		p.Transparency = def.Transparency or 0
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = def.Material ~= Enum.Material.Neon
		p.CFrame = center * cf
		p.Anchored = not weld
		if weld then
			weldTo(base, p)
		end
		if def.Light then
			local light = Instance.new("PointLight")
			light.Color = def.Light.Color
			light.Range = def.Light.Range
			light.Brightness = def.Light.Brightness
			light.Parent = p
		end
		p.Parent = folder
	end
	if look.Embers then
		local torso, center = resolve("Torso", 0)
		if torso and center then
			local emitterPart = Instance.new("Part")
			emitterPart.Name = "Brasas"
			emitterPart.Size = Vector3.new(0.2, 0.2, 0.2)
			emitterPart.Transparency = 1
			emitterPart.CanCollide = false
			emitterPart.CanTouch = false
			emitterPart.CanQuery = false
			emitterPart.Massless = true
			emitterPart.CFrame = center * CFrame.new(0, 0, 0.6)
			emitterPart.Anchored = not weld
			if weld then
				weldTo(torso, emitterPart)
			end
			local colors = look.Embers.Colors
			local e = Instance.new("ParticleEmitter")
			e.Name = "Brasas"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = look.Embers.Rate
			e.Lifetime = NumberRange.new(0.4, 1)
			e.Speed = NumberRange.new(0.5, 2)
			e.SpreadAngle = Vector2.new(45, 45)
			e.Color = ColorSequence.new(colors[1], colors[#colors])
			e.Size = NumberSequence.new(0.14, 0)
			e.LightEmission = 0.8
			e.Parent = emitterPart
			emitterPart.Parent = folder
		end
	end
end

-- Pone el traje en un avatar R15 (soldado, sigue las animaciones). Devuelve la carpeta creada.
function CrateLooks.applyToCharacter(prizeId: string, character: Model): Folder?
	local look = (CrateLooks :: any)[prizeId] :: Look?
	if type(look) ~= "table" then
		return nil
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = look.Skin
			d.Material = look.SkinMaterial
		end
	end
	local existing = character:FindFirstChild("CrateLook")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CrateLook"
	build(look, folder, r15(character), true)
	folder.Parent = character
	return folder
end

-- Saca el traje: borra las piezas y devuelve el material de plástico al cuerpo (el color lo
-- vuelve a poner la HumanoidDescription original)
function CrateLooks.removeFromCharacter(character: Model)
	local existing = character:FindFirstChild("CrateLook")
	if existing then
		existing:Destroy()
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Material = Enum.Material.Plastic
		end
	end
end

-- Pone el traje en un modelo de bloques de CrateModels (piezas ancladas, para vistas previas)
function CrateLooks.applyToBlocky(prizeId: string, model: Model)
	local look = (CrateLooks :: any)[prizeId] :: Look?
	if type(look) ~= "table" then
		return
	end
	for _, name in { "Torso", "Head", "Arm", "Leg", "Hand" } do
		for _, c in model:GetChildren() do
			if c:IsA("BasePart") and c.Name == name then
				c.Color = look.Skin
				c.Material = look.SkinMaterial
			end
		end
	end
	build(look, model, blocky(model), false)
end

function CrateLooks.has(prizeId: string): boolean
	return type((CrateLooks :: any)[prizeId]) == "table"
end

return CrateLooks
