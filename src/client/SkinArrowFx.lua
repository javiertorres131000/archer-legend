--!strict
-- SkinArrowFx (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > SkinArrowFx
-- Flechas con la skin del arquero (Shared/SkinFx): vara y punta del color de la skin, estela,
-- llamas y brasas en vuelo, una luz que la acompaña, chispazo al disparar y explosión al pegar.
-- Lo usa Client/ProjectileVisuals. Es solo visual: el daño lo decide el servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinFx = require(Shared:WaitForChild("SkinFx"))
local FxStyles = require(Shared:WaitForChild("FxStyles"))

local SkinArrowFx = {}

local FX_NAME = "SkinFx" -- adjunto de la flecha donde van las partículas y la luz
local MAX_LIGHTS = 6 -- luces de flechas a la vez (cada luz cuesta rendimiento)
local lights = 0

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "SkinArrowFx"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

-- Skin con flechas propias del dueño de la flecha (nil: flecha común)
function SkinArrowFx.forOwner(ownerUserId: number): SkinFx.Skin?
	if type(ownerUserId) ~= "number" or ownerUserId <= 0 then
		return nil
	end
	local player = Players:GetPlayerByUserId(ownerUserId)
	local _, skin = SkinFx.forCharacter(player and player.Character)
	if skin and skin.Arrow then
		return skin
	end
	return nil
end

-- Estela: color (de la punta a la cola), duración y ancho
function SkinArrowFx.trailStyle(skin: SkinFx.Skin): (ColorSequence, number, number)
	local arrow = skin.Arrow :: SkinFx.ArrowFx
	local c = skin.Colors
	local color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c.hot),
		ColorSequenceKeypoint.new(0.15, c.mid),
		ColorSequenceKeypoint.new(1, c.dark),
	})
	return color, arrow.TrailLife, arrow.TrailWidth
end

-- Textura del estilo (FxStyles). Las propias son flipbooks con contorno oscuro: van sin
-- LightEmission (si no, el contorno se vuelve transparente); las de respaldo se tiñen.
local function texture(e: ParticleEmitter, skin: SkinFx.Skin, key: string, tint: Color3)
	local arrow = skin.Arrow :: SkinFx.ArrowFx
	local tex, custom = FxStyles.texture(FxStyles.get(arrow.Style), key)
	e.Texture = tex
	e.LightInfluence = 0
	if custom then
		e.LightEmission = 0
		if key == "Flame" or key == "Smoke" then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	else
		e.LightEmission = 0.8
		e.Color = ColorSequence.new(tint)
	end
end

local function embers(parent: Instance, c: SkinFx.Palette, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Brasas"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Drag = 2
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(c.hot, c.mid)
	e.Size = NumberSequence.new(0.2, 0)
	e.Transparency = NumberSequence.new(0, 1)
	e.Parent = parent
	return e
end

local function flames(parent: Instance, skin: SkinFx.Skin, rate: number, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Llamas"
	texture(e, skin, "Flame", skin.Colors.mid)
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.22, 0.32)
	e.Speed = NumberRange.new(0, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9 * size),
		NumberSequenceKeypoint.new(1, 0.35 * size),
	})
	e.Rotation = NumberRange.new(-25, 25)
	e.Parent = parent
	return e
end

-- Saca los efectos de la skin de una flecha (antes de devolverla al pool o de reusarla)
function SkinArrowFx.clear(part: BasePart)
	local fx = part:FindFirstChild(FX_NAME)
	if fx then
		if fx:GetAttribute("HasLight") then
			lights = math.max(0, lights - 1)
		end
		fx:Destroy()
	end
end

-- Viste la flecha con la skin. low = calidad baja: solo colores (sin partículas ni luz).
function SkinArrowFx.decorate(part: BasePart, skin: SkinFx.Skin, low: boolean)
	SkinArrowFx.clear(part)
	local arrow = skin.Arrow :: SkinFx.ArrowFx
	part.Material = arrow.ShaftMaterial
	part.Color = arrow.Shaft
	local head = part:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.Material = Enum.Material.Neon
		head.Color = arrow.Tip
	end
	if low then
		return
	end
	local fx = Instance.new("Attachment")
	fx.Name = FX_NAME
	fx.Position = Vector3.new(0, 0, part.Size.Z * 0.25) -- un poco detrás del centro
	fx.Parent = part
	if arrow.Flames > 0 then
		flames(fx, skin, arrow.Flames, 1.4)
	end
	if arrow.Embers > 0 then
		embers(fx, skin.Colors, arrow.Embers)
	end
	if arrow.Light > 0 and lights < MAX_LIGHTS then
		lights += 1
		fx:SetAttribute("HasLight", true)
		local light = Instance.new("PointLight")
		light.Color = skin.Colors.mid
		light.Range = arrow.Light
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = fx
	end
end

-- Pieza invisible con partículas para un efecto suelto; se borra sola
local function holder(at: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Name = "SkinFxBurst"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	p.Parent = fxFolder()
	task.delay(life, function()
		p:Destroy()
	end)
	return p
end

-- Chispazo en el arco al disparar
function SkinArrowFx.launch(origin: Vector3, skin: SkinFx.Skin, low: boolean)
	local h = holder(origin, 1)
	local e = embers(h, skin.Colors, 0)
	e.Speed = NumberRange.new(4, 9)
	e.Acceleration = Vector3.zero
	e:Emit(if low then 4 else 10)
	if not low then
		local f = flames(h, skin, 0, 0.8)
		f.Speed = NumberRange.new(1, 3)
		f:Emit(3)
	end
end

-- Explosión al pegar (hit = true) o la flecha que se apaga sola al final de su alcance
function SkinArrowFx.impact(pos: Vector3, skin: SkinFx.Skin, hit: boolean, low: boolean)
	local arrow = skin.Arrow :: SkinFx.ArrowFx
	local c = skin.Colors
	local size = arrow.ImpactSize
	local h = holder(pos, 1.5)
	local sparks = embers(h, c, 0)
	sparks.Speed = NumberRange.new(6 * size, 16 * size)
	sparks.Acceleration = Vector3.new(0, -14, 0)
	sparks.Size = NumberSequence.new(0.28 * size, 0)
	if not hit then
		sparks:Emit(if low then 3 else 7)
		return
	end
	sparks:Emit(if low then 8 else 24)
	if low then
		return
	end
	local fire = flames(h, skin, 0, 2 * size)
	fire.Speed = NumberRange.new(3 * size, 7 * size)
	fire.Lifetime = NumberRange.new(0.35, 0.5)
	fire.Drag = 4
	fire:Emit(7)
	local ring = Instance.new("ParticleEmitter")
	ring.Name = "Anillo"
	texture(ring, skin, "Ring", c.hot)
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.3)
	ring.Size = NumberSequence.new(0.6 * size, 6 * size)
	ring.Transparency = NumberSequence.new(0, 1)
	ring.Parent = h
	ring:Emit(1)
	local star = Instance.new("ParticleEmitter")
	star.Name = "Destello"
	texture(star, skin, "Star", c.hot)
	star.Rate = 0
	star.Speed = NumberRange.new(0)
	star.Lifetime = NumberRange.new(0.14, 0.18)
	star.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * size),
		NumberSequenceKeypoint.new(0.3, 3 * size),
		NumberSequenceKeypoint.new(1, 0),
	})
	star.Rotation = NumberRange.new(0, 45)
	star.ZOffset = 2
	star.Parent = h
	star:Emit(1)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Humo"
	texture(smoke, skin, "Smoke", c.dark)
	smoke.Rate = 0
	smoke.Speed = NumberRange.new(1, 3)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Lifetime = NumberRange.new(0.6, 0.9)
	smoke.Size = NumberSequence.new(1.2 * size, 2.4 * size)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Parent = h
	smoke:Emit(2)
	if lights < MAX_LIGHTS then
		lights += 1
		local light = Instance.new("PointLight")
		light.Color = c.mid
		light.Range = 12 * size
		light.Brightness = 4
		light.Shadows = false
		light.Parent = h
		TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		task.delay(0.4, function()
			lights = math.max(0, lights - 1)
		end)
	end
end

return SkinArrowFx
