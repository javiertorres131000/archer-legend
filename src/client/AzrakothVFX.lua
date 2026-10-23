--!strict
-- AzrakothVFX (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > AzrakothVFX
-- Efectos de Azrakoth en cada pantalla (solo visual; el daño lo decide el servidor).
-- AzrakothAnimator los dispara con las marcas de cada animación (Hit, FX_Shockwave, Cast...).
--   · Siempre: brasas que suben, núcleo y ojos que laten, estela de fuego del espadón, halo.
--   · Por marca: onda expansiva, rocas, columna de fuego, círculos de invocación, rayo del halo,
--     estallido de fase, plumas, temblor de cámara y destellos de luz.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local VFX = {}

local FUEGO = Color3.fromRGB(255, 110, 25)
local BRASA = Color3.fromRGB(255, 200, 80)
local CARMESI = Color3.fromRGB(200, 20, 30)
local OSCURO = Color3.fromRGB(70, 0, 20)
local TEX_CHISPA = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FUEGO = "rbxasset://textures/particles/fire_main.dds"
local TEX_HUMO = "rbxasset://textures/particles/smoke_main.dds"

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "AzrakothFX"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function tween(obj: Instance, t: number, props: { [string]: any }, estilo: Enum.EasingStyle?)
	TweenService:Create(obj, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function pieza(size: Vector3, cf: CFrame, color: Color3, forma: Enum.PartType?, vida: number): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Shape = forma or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Parent = fxFolder()
	Debris:AddItem(p, vida)
	return p
end

local function emisor(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.LightEmission = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function luz(parent: Instance, color: Color3, rango: number, brillo: number, dura: number?)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, rango, brillo, false
	l.Parent = parent
	if dura then
		tween(l, dura, { Brightness = 0 })
		Debris:AddItem(l, dura + 0.1)
	end
	return l
end

local function ancla(pos: Vector3, vida: number): Part
	local p = pieza(Vector3.one * 0.2, CFrame.new(pos), FUEGO, nil, vida)
	p.Transparency = 1
	return p
end

-- ---------------------------------------------------------------------------------------------
-- Temblor de cámara (se suma después de la cámara del juego)
-- ---------------------------------------------------------------------------------------------
local temblor, temblorHasta = 0, 0
RunService:BindToRenderStep("AzrakothShake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	if now >= temblorHasta then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local k = temblor * (temblorHasta - now)
	cam.CFrame *= CFrame.new((math.noise(now * 25, 1) * k), (math.noise(now * 25, 2) * k), 0)
		* CFrame.Angles(0, 0, math.noise(now * 20, 3) * k * 0.02)
end)

local function sacudir(pos: Vector3, fuerza: number, dura: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local d = (cam.CFrame.Position - pos).Magnitude
	local f = fuerza * math.clamp(1 - d / 220, 0.15, 1)
	temblor = math.max(temblor * math.max(temblorHasta - os.clock(), 0), f / dura)
	temblorHasta = os.clock() + dura
end

local function destello(color: Color3, fuerza: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = color
	cc.Brightness = 0.25 * fuerza
	cc.Contrast = 0.2 * fuerza
	cc.Parent = Lighting
	tween(cc, 0.45, { Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
	Debris:AddItem(cc, 0.5)
end

-- ---------------------------------------------------------------------------------------------
-- Efectos sueltos
-- ---------------------------------------------------------------------------------------------
local function onda(pos: Vector3, radio: number, color: Color3, alto: number?)
	local cf = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local anillo = pieza(Vector3.new(alto or 1.2, 2, 2), cf, color, Enum.PartType.Cylinder, 0.8)
	tween(anillo, 0.6, { Size = Vector3.new(0.2, radio * 2, radio * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	local disco = pieza(Vector3.new(0.3, 2, 2), cf, BRASA, Enum.PartType.Cylinder, 0.5)
	disco.Transparency = 0.2
	tween(disco, 0.35, { Size = Vector3.new(0.1, radio * 1.2, radio * 1.2), Transparency = 1 })
end

local function rocas(pos: Vector3, cuantas: number, fuerza: number)
	for _ = 1, cuantas do
		local r = Instance.new("Part")
		r.Size = Vector3.new(math.random(8, 20) / 10, math.random(8, 20) / 10, math.random(8, 20) / 10)
		r.Material = Enum.Material.Basalt
		r.Color = Color3.fromRGB(35, 25, 25)
		r.CanCollide, r.CanQuery, r.CanTouch = false, false, false
		r.CFrame = CFrame.new(pos + Vector3.new(math.random(-3, 3), 1, math.random(-3, 3)))
		r.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(20, 38), math.random(-10, 10)) * fuerza
		r.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		r.Parent = fxFolder()
		local brillo = Instance.new("Fire")
		brillo.Size, brillo.Heat, brillo.Color, brillo.SecondaryColor = 2, 4, FUEGO, CARMESI
		brillo.Parent = r
		Debris:AddItem(r, 2.2)
	end
end

local function estallido(pos: Vector3, escala: number, color: Color3)
	local a = ancla(pos, 3)
	local chispas = emisor(a, {
		Texture = TEX_CHISPA, Color = ColorSequence.new(BRASA, color), Rate = 0,
		Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(20 * escala, 55 * escala),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -30, 0), Drag = 1.5,
		Size = NumberSequence.new(0.9 * escala, 0), Transparency = NumberSequence.new(0, 1),
	})
	chispas:Emit(math.floor(60 * escala))
	local fuego = emisor(a, {
		Texture = TEX_FUEGO, Color = ColorSequence.new(BRASA, CARMESI), Rate = 0,
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(8 * escala, 22 * escala),
		SpreadAngle = Vector2.new(180, 180), Drag = 3, RotSpeed = NumberRange.new(-180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6 * escala), NumberSequenceKeypoint.new(1, 1) }),
		Transparency = NumberSequence.new(0.1, 1),
	})
	fuego:Emit(math.floor(25 * escala))
	local humo = emisor(a, {
		Texture = TEX_HUMO, Color = ColorSequence.new(Color3.fromRGB(40, 15, 15)), Rate = 0, LightEmission = 0,
		Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(4, 12 * escala), SpreadAngle = Vector2.new(180, 40),
		Acceleration = Vector3.new(0, 4, 0), Size = NumberSequence.new(5 * escala, 12 * escala),
		Transparency = NumberSequence.new(0.4, 1),
	})
	humo:Emit(math.floor(14 * escala))
	luz(a, color, 40 * escala, 6, 0.6)
end

local function columna(pos: Vector3, alto: number, radio: number)
	local cf = CFrame.new(pos + Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local c = pieza(Vector3.new(alto, radio * 2, radio * 2), cf, FUEGO, Enum.PartType.Cylinder, 1.2)
	c.Transparency = 0.15
	tween(c, 1.0, { Size = Vector3.new(alto * 1.3, radio * 0.3, radio * 0.3), Transparency = 1 })
	local nucleo = pieza(Vector3.new(alto, radio, radio), cf, BRASA, Enum.PartType.Cylinder, 0.8)
	tween(nucleo, 0.6, { Size = Vector3.new(alto * 1.2, 0.2, 0.2), Transparency = 1 })
end

local function circulo(pos: Vector3, radio: number, color: Color3, dura: number)
	local cf = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local c = pieza(Vector3.new(0.2, 0.5, 0.5), cf, color, Enum.PartType.Cylinder, dura + 0.4)
	c.Transparency = 0.35
	tween(c, 0.35, { Size = Vector3.new(0.2, radio * 2, radio * 2) }, Enum.EasingStyle.Back)
	task.delay(dura, function()
		if c.Parent then
			tween(c, 0.35, { Transparency = 1 })
		end
	end)
	local a = ancla(pos, dura + 1)
	emisor(a, {
		Texture = TEX_CHISPA, Color = ColorSequence.new(color, OSCURO), Rate = 40,
		Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 6, 0), Size = NumberSequence.new(0.7, 0), Transparency = NumberSequence.new(0, 1),
	})
	task.delay(dura, function()
		for _, e in a:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
	end)
end

-- ---------------------------------------------------------------------------------------------
-- Por jefe
-- ---------------------------------------------------------------------------------------------
export type Boss = {
	hitbox: BasePart,
	look: Model,
	parts: { [string]: BasePart },
	scale: number,
	beam: Part?,
	beamUntil: number,
	espada: { ParticleEmitter },
	nucleo: PointLight?,
}

local function suelo(b: Boss): Vector3
	local p = b.hitbox.Position
	return Vector3.new(p.X, p.Y - b.hitbox.Size.Y / 2, p.Z)
end

local function frente(b: Boss, dist: number): Vector3
	local look = b.hitbox.CFrame.LookVector
	return suelo(b) + Vector3.new(look.X, 0, look.Z).Unit * dist
end

function VFX.setup(hitbox: BasePart, look: Model, scale: number): Boss
	local parts: { [string]: BasePart } = {}
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d.Name] = d
		end
	end
	local b: Boss = { hitbox = hitbox, look = look, parts = parts, scale = scale, beam = nil, beamUntil = 0, espada = {},
		nucleo = nil }
	-- brasas y ceniza que suben del cuerpo
	local pecho = parts.Chest
	if pecho then
		emisor(pecho, {
			Texture = TEX_CHISPA, Color = ColorSequence.new(BRASA, FUEGO), Rate = 14, Lifetime = NumberRange.new(1.5, 3),
			Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 5, 0),
			Size = NumberSequence.new(0.35 * scale + 0.1, 0), Transparency = NumberSequence.new(0, 1),
		})
		emisor(pecho, {
			Texture = TEX_HUMO, Color = ColorSequence.new(Color3.fromRGB(30, 10, 10)), LightEmission = 0, Rate = 4,
			Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(1, 3), Acceleration = Vector3.new(0, 3, 0),
			Size = NumberSequence.new(4 * scale + 1, 9 * scale + 2), Transparency = NumberSequence.new(0.7, 1),
		})
	end
	if parts.Core then
		b.nucleo = luz(parts.Core, FUEGO, 26 * scale + 6, 2.5)
	end
	if parts.Head then
		luz(parts.Head, CARMESI, 14 * scale + 4, 1.5)
	end
	if parts.Halo then
		luz(parts.Halo, CARMESI, 30 * scale + 6, 1.2)
	end
	-- estela y llamas del espadón (del mango a la punta, en ejes de la pieza)
	local sw = parts.Sword
	if sw then
		local mango = sw.PivotOffset.Position
		local dir = Vector3.new(1.8, -36.4, -3.3).Unit
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = mango + dir * 6 * scale
		a1.Position = mango + dir * 35 * scale
		a0.Parent, a1.Parent = sw, sw
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(BRASA, CARMESI)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Lifetime = 0.22
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.MinLength = 0.2
		trail.Parent = sw
		local medio = Instance.new("Attachment")
		medio.Position = mango + dir * 20 * scale
		medio.Parent = sw
		local llamas = emisor(medio, {
			Texture = TEX_FUEGO, Color = ColorSequence.new(BRASA, CARMESI), Rate = 25, Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(10, 10), Acceleration = Vector3.new(0, 8, 0),
			Size = NumberSequence.new(2.4 * scale + 0.4, 0.2), Transparency = NumberSequence.new(0.2, 1),
			RotSpeed = NumberRange.new(-90, 90), Shape = Enum.ParticleEmitterShape.Box,
		})
		b.espada = { llamas }
		luz(medio, FUEGO, 16 * scale + 4, 1.4)
	end
	return b
end

-- Pulso continuo (núcleo que late) y rayo del halo
function VFX.update(b: Boss, now: number)
	if b.nucleo then
		b.nucleo.Brightness = 2.2 + math.sin(now * 3) * 0.8
	end
	local beam = b.beam
	if beam then
		if now > b.beamUntil or not b.parts.Halo then
			beam:Destroy()
			b.beam = nil
		else
			local origen = b.parts.Halo.Position
			local destino = frente(b, 70 * b.scale + 25)
			local largo = (destino - origen).Magnitude
			beam.Size = Vector3.new(largo, 2.4 + math.sin(now * 40) * 0.4, 2.4 + math.sin(now * 40) * 0.4)
			beam.CFrame = CFrame.lookAt((origen + destino) / 2, destino) * CFrame.Angles(0, math.rad(90), 0)
			if math.random() < 0.35 then
				estallido(destino, 0.5, CARMESI)
			end
		end
	end
end

local function llamasEspada(b: Boss, rate: number, dura: number)
	for _, e in b.espada do
		e.Rate = rate
	end
	task.delay(dura, function()
		for _, e in b.espada do
			e.Rate = 25
		end
	end)
end

-- Marcas de las animaciones → efectos
function VFX.marca(b: Boss, nombre: string)
	local s = b.scale
	local p = b.parts
	if nombre == "FX_ChargeBlade" or nombre == "Telegraph" or nombre == "Telegraph3" or nombre == "Dive" then
		llamasEspada(b, 120, 1.6)
		if p.Sword then
			luz(p.Sword, FUEGO, 30 * s, 5, 1.4)
		end
	elseif nombre == "Hit" or nombre == "Hit1" or nombre == "Hit2" or nombre == "Hit3" then
		local pos = frente(b, 16 * s + 4)
		estallido(pos, 0.8 + s * 0.5, FUEGO)
		onda(pos, 12 * s + 6, FUEGO)
		sacudir(pos, 0.9, 0.35)
	elseif nombre == "FX_Shockwave" then
		local pos = frente(b, 16 * s + 4)
		onda(pos, 40 * s + 14, FUEGO, 2)
		onda(pos, 26 * s + 10, CARMESI, 1.4)
		rocas(pos, 10, 1)
		destello(Color3.fromRGB(255, 190, 150), 1)
	elseif nombre == "CameraShake" then
		sacudir(suelo(b), 2.2, 0.7)
	elseif nombre == "FX_FireColumn" or nombre == "FX_Crater" then
		local pos = suelo(b)
		columna(pos, 70 * s + 20, 8 * s + 3)
		onda(pos, 45 * s + 15, FUEGO, 2.5)
		rocas(pos, 14, 1.3)
		estallido(pos, 1.6, FUEGO)
		destello(Color3.fromRGB(255, 160, 120), 1.4)
	elseif nombre == "FX_LandingMarker" then
		circulo(suelo(b), 16 * s + 6, FUEGO, 2)
	elseif nombre == "FX_WingBurst" or nombre == "FX_WingBeat" or nombre == "FX_TakeOffDust" then
		for _, ala in { p.Wing_L_2, p.Wing_R_2 } do
			if ala then
				estallido(ala.Position, 0.9, CARMESI)
			end
		end
		onda(suelo(b), 30 * s + 10, CARMESI, 1)
		sacudir(suelo(b), 0.6, 0.4)
	elseif nombre == "FX_SummonCircles" or nombre == "Cast" then
		for i = 1, 5 do
			local ang = i / 5 * math.pi * 2
			circulo(suelo(b) + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (22 * s + 8), 5 * s + 3, CARMESI, 1.6)
		end
		if nombre == "Cast" then
			estallido(frente(b, 8 * s + 3), 1.1, CARMESI)
			sacudir(suelo(b), 1.2, 0.4)
		end
	elseif nombre == "Summon" or nombre == "FX_Portals" then
		for i = 1, 4 do
			local ang = i / 4 * math.pi * 2 + 0.4
			local pos = suelo(b) + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (18 * s + 8)
			circulo(pos, 4 * s + 3, OSCURO, 1.2)
			columna(pos, 18 * s + 6, 2 * s + 1)
		end
		onda(suelo(b), 30 * s + 10, CARMESI)
	elseif nombre == "FX_CorePulse" or nombre == "FX_CorePulse2" then
		if p.Core then
			estallido(p.Core.Position, 0.7, FUEGO)
			luz(p.Core, BRASA, 45 * s + 10, 8, 0.5)
		end
	elseif nombre == "FX_HaloSpinUp" or nombre == "FX_Runes" then
		if p.Halo then
			estallido(p.Halo.Position, 0.8, CARMESI)
			luz(p.Halo, CARMESI, 50 * s + 10, 6, 1.2)
		end
	elseif nombre == "BeamStart" then
		if not b.beam then
			local beam = pieza(Vector3.new(1, 3, 3), b.hitbox.CFrame, CARMESI, Enum.PartType.Cylinder, 6)
			beam.Transparency = 0.1
			local brillo = luz(beam, CARMESI, 30, 6)
			brillo.Shadows = false
			b.beam = beam
		end
		b.beamUntil = os.clock() + 3
		destello(Color3.fromRGB(255, 120, 120), 0.8)
	elseif nombre == "BeamEnd" then
		b.beamUntil = 0
	elseif nombre == "PhaseChange" or nombre == "FX_Burst" or nombre == "Roar" then
		local pos = p.Chest and p.Chest.Position or b.hitbox.Position
		estallido(pos, 2.2, FUEGO)
		onda(suelo(b), 60 * s + 20, FUEGO, 3)
		onda(suelo(b), 40 * s + 14, CARMESI, 2)
		destello(Color3.fromRGB(255, 120, 90), 1.8)
		sacudir(pos, 2.5, 1)
	elseif nombre == "FX_Implode" then
		if p.Core then
			luz(p.Core, CARMESI, 60 * s + 10, 10, 1.5)
		end
	elseif nombre == "FX_CoreCrack" then
		if p.Core then
			estallido(p.Core.Position, 1.2, FUEGO)
			luz(p.Core, BRASA, 60 * s + 10, 10, 1)
		end
		destello(Color3.fromRGB(255, 200, 160), 1.2)
		sacudir(b.hitbox.Position, 1.5, 0.6)
	elseif nombre == "FX_Knees" or nombre == "FX_SwordDrop" then
		onda(suelo(b), 30 * s + 10, Color3.fromRGB(120, 60, 40), 1.2)
		rocas(suelo(b), 8, 0.8)
		sacudir(suelo(b), 1.4, 0.5)
	elseif nombre == "FX_Collapse" then
		onda(suelo(b), 50 * s + 16, FUEGO, 2)
		rocas(suelo(b), 14, 1)
		estallido(suelo(b) + Vector3.new(0, 4, 0), 1.8, FUEGO)
		sacudir(suelo(b), 2.4, 0.9)
	elseif nombre == "Dead" then
		-- se apaga y se deshace en brasas
		local pos = p.Chest and p.Chest.Position or b.hitbox.Position
		estallido(pos, 2.4, CARMESI)
		columna(suelo(b), 60 * s + 20, 6 * s + 3)
		destello(Color3.fromRGB(255, 150, 120), 1.5)
		if b.nucleo then
			tween(b.nucleo, 0.6, { Brightness = 0 })
			b.nucleo = nil -- que el latido no la vuelva a prender
		end
		for _, d in b.look:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				tween(d, 0.7, { Transparency = 1 })
			elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
				(d :: any).Enabled = false
			end
		end
	elseif nombre == "Step_L" or nombre == "Step_R" then
		local pie = p[if nombre == "Step_L" then "Foot_L" else "Foot_R"]
		if pie then
			local pos = Vector3.new(pie.Position.X, suelo(b).Y, pie.Position.Z)
			onda(pos, 6 * s + 3, Color3.fromRGB(120, 60, 40), 0.6)
			sacudir(pos, 0.35, 0.25)
		end
	end
end

return VFX
