-- IceWorld (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > IceWorld
-- Todo lo del Glaciar Eterno que ve y siente cada jugador (solo mientras el mapa es "glacier",
-- atributo MapEvents de GameState):
--   · Resbalar: sobre hielo (y glaciar) acelerás, frenás y doblás despacio (Config.IceGrip). Sobre
--     nieve profunda caminás un poco más lento. Lo mueve este cliente porque es dueño de su
--     personaje (como el dash); la velocidad máxima la sigue poniendo el servidor (WalkSpeed).
--   · Ventisca (atributo Blizzard): aviso, viento que empuja, nieve horizontal y pantalla blanca.
--   · Frío (atributos Chill / Frozen del jugador, Server/Chill): escarcha en los bordes de la
--     pantalla, medidor de frío y bloque de hielo alrededor de quien queda congelado.
--   · Ambiente: polvo de diamante, nieve que barre el piso, aurora boreal, aliento que humea,
--     pisadas, destellos en los cristales, humo en las fogatas, niebla fría en los enemigos y
--     enemigos que estallan en trozos de hielo al morir.
-- Es solo visual salvo el resbalón y el empuje del viento (movimiento propio del personaje).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))

local player = Players.LocalPlayer
local gameState = ReplicatedStorage:WaitForChild("GameState")
local low = FxQuality.isLow()

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local ICE = Color3.fromRGB(190, 235, 255)
local FROST = Color3.fromRGB(150, 220, 255)

local grip = (Config :: any).IceGrip or {}
local chillCfg = (Config :: any).Chill or { MaxStacks = 5 }
local blizzardCfg = (((Config :: any).MapEvents or {}).glacier or {}).Blizzard or { WindPush = 8 }

local active = false
local clock = 0
local world: Folder? = nil -- todo lo que se crea mientras está activo (se borra al salir)
local conns: { RBXScriptConnection } = {}

-- Ventisca
local blizzardStart, blizzardEnd = 0, 0
local windDir = Vector3.new(1, 0, 0)
local blizzardK = 0 -- 0 a 1 (intensidad suavizada)

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------

local function newPart(name: string, size: Vector3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = parent
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function seq(a: number, b: number, c: number?): NumberSequence
	if c then
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, b), NumberSequenceKeypoint.new(1, c) })
	end
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------------
-- Pantalla: escarcha, medidor de frío, aviso y blanco de la ventisca
---------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "IceWorld"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Bordes de escarcha (un degradé en cada lado)
local frostEdges: { Frame } = {}
for i, spec in {
	{ UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), 90 },
	{ UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.68), -90 },
	{ UDim2.fromScale(0.26, 1), UDim2.fromScale(0, 0), 0 },
	{ UDim2.fromScale(0.26, 1), UDim2.fromScale(0.74, 0), 180 },
} do
	local f = Instance.new("Frame")
	f.Name = "Escarcha" .. i
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(215, 240, 255)
	f.BackgroundTransparency = 1
	f.Size = spec[1]
	f.Position = spec[2]
	local g = Instance.new("UIGradient")
	g.Rotation = spec[3]
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.65), NumberSequenceKeypoint.new(1, 1) })
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 210, 255))
	g.Parent = f
	f.Parent = gui
	table.insert(frostEdges, f)
end

-- Blanco de la ventisca
local whiteout = Instance.new("Frame")
whiteout.Name = "Ventisca"
whiteout.BorderSizePixel = 0
whiteout.Size = UDim2.fromScale(1, 1)
whiteout.BackgroundColor3 = Color3.fromRGB(15, 25, 45) -- la ventisca oscurece (antes blanqueaba y no se veía nada)
whiteout.BackgroundTransparency = 1
whiteout.ZIndex = 0
whiteout.Parent = gui

-- Medidor de frío
local meter = Instance.new("Frame")
meter.Name = "Frio"
meter.AnchorPoint = Vector2.new(0.5, 1)
meter.Position = UDim2.new(0.5, 0, 1, -118)
meter.Size = UDim2.fromOffset(190, 26)
meter.BackgroundTransparency = 1
meter.Visible = false
meter.Parent = gui
local meterLabel = Instance.new("TextLabel")
meterLabel.BackgroundTransparency = 1
meterLabel.Size = UDim2.fromOffset(60, 26)
meterLabel.Font = Enum.Font.GothamBlack
meterLabel.TextSize = 14
meterLabel.Text = "FRÍO"
meterLabel.TextColor3 = Color3.fromRGB(190, 235, 255)
meterLabel.TextStrokeTransparency = 0.4
meterLabel.Parent = meter
local pips: { Frame } = {}
for i = 1, chillCfg.MaxStacks do
	local pip = Instance.new("Frame")
	pip.Position = UDim2.fromOffset(60 + (i - 1) * 26, 5)
	pip.Size = UDim2.fromOffset(22, 16)
	pip.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
	pip.BackgroundTransparency = 0.3
	pip.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = pip
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(170, 225, 255)
	stroke.Transparency = 0.4
	stroke.Parent = pip
	pip.Parent = meter
	table.insert(pips, pip)
end

-- Cartel central (ventisca, congelado)
local banner = Instance.new("TextLabel")
banner.Name = "Aviso"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.24)
banner.Size = UDim2.fromScale(0.7, 0.07)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextColor3 = Color3.fromRGB(220, 245, 255)
banner.TextStrokeColor3 = Color3.fromRGB(20, 60, 110)
banner.TextStrokeTransparency = 0
banner.TextTransparency = 1
banner.Parent = gui

local function flashBanner(text: string, seconds: number)
	banner.Text = text
	banner.TextTransparency = 1
	banner.TextStrokeTransparency = 1
	TweenService:Create(banner, TweenInfo.new(0.25), { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
	task.delay(seconds, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local nearestFireDist: number? = nil

-- Detalle del frío, debajo del medidor
local chillInfo = Instance.new("TextLabel")
chillInfo.BackgroundTransparency = 1
chillInfo.AnchorPoint = Vector2.new(0.5, 0)
chillInfo.Position = UDim2.new(0.5, 0, 1, 2)
chillInfo.Size = UDim2.fromOffset(320, 18)
chillInfo.Font = Enum.Font.GothamBold
chillInfo.TextSize = 13
chillInfo.TextColor3 = Color3.fromRGB(200, 235, 255)
chillInfo.TextStrokeTransparency = 0.3
chillInfo.Parent = meter

-- Cartel de mecánica nueva (aparece una vez por partida)
local tipCard = Instance.new("Frame")
tipCard.Name = "Mecanica"
tipCard.AnchorPoint = Vector2.new(0.5, 0)
tipCard.Position = UDim2.new(0.5, 0, 0, 120)
tipCard.Size = UDim2.fromOffset(520, 92)
tipCard.BackgroundColor3 = Color3.fromRGB(12, 22, 40)
tipCard.BackgroundTransparency = 0.15
tipCard.Visible = false
tipCard.Parent = gui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = tipCard
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 210, 255)
	stroke.Thickness = 2
	stroke.Parent = tipCard
end
local tipIcon = Instance.new("TextLabel")
tipIcon.BackgroundTransparency = 1
tipIcon.Position = UDim2.fromOffset(12, 10)
tipIcon.Size = UDim2.fromOffset(72, 72)
tipIcon.TextScaled = true
tipIcon.Font = Enum.Font.GothamBlack
tipIcon.Parent = tipCard
local tipTitle = Instance.new("TextLabel")
tipTitle.BackgroundTransparency = 1
tipTitle.Position = UDim2.fromOffset(96, 10)
tipTitle.Size = UDim2.new(1, -108, 0, 30)
tipTitle.Font = Enum.Font.GothamBlack
tipTitle.TextSize = 24
tipTitle.TextXAlignment = Enum.TextXAlignment.Left
tipTitle.TextColor3 = Color3.fromRGB(150, 225, 255)
tipTitle.Parent = tipCard
local tipText = Instance.new("TextLabel")
tipText.BackgroundTransparency = 1
tipText.Position = UDim2.fromOffset(96, 42)
tipText.Size = UDim2.new(1, -108, 0, 42)
tipText.Font = Enum.Font.GothamBold
tipText.TextSize = 16
tipText.TextWrapped = true
tipText.TextXAlignment = Enum.TextXAlignment.Left
tipText.TextYAlignment = Enum.TextYAlignment.Top
tipText.TextColor3 = Color3.fromRGB(235, 245, 255)
tipText.Parent = tipCard

local TIPS = {
	cold = { "❄️", "FRÍO", "Cada golpe que recibís te enfría y te frena. Con 5 quedás congelado. Las fogatas 🔥 te calientan." },
	icicles = { "🧊", "¡CARÁMBANOS!", "Caen del cielo donde estás parado. Si ves un círculo rojo en el piso, salí." },
	blizzard = { "🌨️", "VENTISCA", "Mirá la cuenta regresiva arriba. Cuando sopla, te empuja y te congela: corré a una fogata 🔥." },
}

local tipSeq = 0
local function showTip(key: string)
	local t = TIPS[key]
	if not t then
		return
	end
	tipSeq += 1
	local my = tipSeq
	tipIcon.Text, tipTitle.Text, tipText.Text = t[1], t[2], t[3]
	tipCard.Visible = true
	tipCard.Position = UDim2.new(0.5, 0, 0, 90)
	TweenService:Create(tipCard, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 120) }):Play()
	task.delay(6, function()
		if tipSeq == my then
			tipCard.Visible = false
		end
	end)
end

-- Cuenta regresiva de la ventisca
local stormBar = Instance.new("Frame")
stormBar.Name = "CuentaVentisca"
stormBar.AnchorPoint = Vector2.new(0.5, 0)
stormBar.Position = UDim2.new(0.5, 0, 0, 96)
stormBar.Size = UDim2.fromOffset(340, 26)
stormBar.BackgroundColor3 = Color3.fromRGB(12, 22, 40)
stormBar.BackgroundTransparency = 0.2
stormBar.Visible = false
stormBar.Parent = gui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = stormBar
end
local stormFill = Instance.new("Frame")
stormFill.BorderSizePixel = 0
stormFill.BackgroundColor3 = Color3.fromRGB(110, 200, 255)
stormFill.Size = UDim2.fromScale(0, 1)
stormFill.Parent = stormBar
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = stormFill
end
local stormText = Instance.new("TextLabel")
stormText.BackgroundTransparency = 1
stormText.Size = UDim2.fromScale(1, 1)
stormText.Font = Enum.Font.GothamBlack
stormText.TextSize = 15
stormText.TextColor3 = Color3.new(1, 1, 1)
stormText.TextStrokeTransparency = 0.3
stormText.ZIndex = 2
stormText.Parent = stormBar

local blizzardNext = 0
local function updateStormBar()
	local now = Workspace:GetServerTimeNow()
	local fire = if nearestFireDist then string.format("  ·  🔥 a %d m", math.floor(nearestFireDist + 0.5)) else ""
	if blizzardEnd > 0 and now >= blizzardStart and now < blizzardEnd then
		stormBar.Visible = true
		local left = blizzardEnd - now
		stormFill.BackgroundColor3 = Color3.fromRGB(255, 90, 110)
		stormFill.Size = UDim2.fromScale(math.clamp(left / math.max(blizzardEnd - blizzardStart, 0.1), 0, 1), 1)
		stormText.Text = string.format("🌨️ VENTISCA · %d s%s", math.ceil(left), fire)
		return
	end
	local startAt = if blizzardEnd > 0 and now < blizzardStart then blizzardStart else blizzardNext
	local left = startAt - now
	if startAt > 0 and left > 0 and left <= 15 then
		stormBar.Visible = true
		stormFill.BackgroundColor3 = Color3.fromRGB(110, 200, 255)
		stormFill.Size = UDim2.fromScale(1 - left / 15, 1)
		stormText.Text = string.format("VENTISCA en %d s%s", math.ceil(left), fire)
	else
		stormBar.Visible = false
	end
end

-- Qué te lastimó (atributo LastHurt = "causa|daño|hora"), arriba de la barra de vida
local hurtLabel = Instance.new("TextLabel")
hurtLabel.Name = "CausaDanio"
hurtLabel.AnchorPoint = Vector2.new(0.5, 1)
hurtLabel.Position = UDim2.new(0.5, 0, 1, -60)
hurtLabel.Size = UDim2.fromOffset(360, 24)
hurtLabel.BackgroundTransparency = 1
hurtLabel.Font = Enum.Font.GothamBlack
hurtLabel.TextSize = 18
hurtLabel.TextColor3 = Color3.fromRGB(255, 110, 120)
hurtLabel.TextStrokeTransparency = 0.2
hurtLabel.TextTransparency = 1
hurtLabel.Parent = gui
local hurtSeq = 0
local function showHurt()
	local v = player:GetAttribute("LastHurt")
	if type(v) ~= "string" then
		return
	end
	local parts = string.split(v, "|")
	hurtSeq += 1
	local my = hurtSeq
	hurtLabel.Text = string.format("%s  −%s", parts[1] or "Golpe", parts[2] or "?")
	hurtLabel.TextTransparency = 0
	hurtLabel.TextStrokeTransparency = 0.2
	task.delay(1.6, function()
		if hurtSeq == my then
			TweenService:Create(hurtLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local shownChill = 0
local function updateChillUi(dt: number)
	local chill = (player:GetAttribute("Chill") :: number?) or 0
	local frozen = player:GetAttribute("Frozen") == true
	local target = if frozen then 1 else chill
	shownChill += (target - shownChill) * math.min(1, dt * 6)
	local alpha = 1 - shownChill * 0.7 - blizzardK * 0.08
	for _, f in frostEdges do
		f.BackgroundTransparency = math.clamp(alpha, 0, 1)
	end
	local stacks = math.floor(chill * chillCfg.MaxStacks + 0.5)
	meter.Visible = stacks > 0 or frozen
	for i, pip in pips do
		local on = frozen or i <= stacks
		pip.BackgroundColor3 = if on then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(40, 60, 80)
		pip.BackgroundTransparency = if on then 0.05 else 0.3
	end
	meterLabel.Text = if frozen then "¡HIELO!" else "FRÍO"
	local fire = if nearestFireDist then string.format("  ·  🔥 a %d m", math.floor(nearestFireDist + 0.5)) else ""
	if frozen then
		chillInfo.Text = "¡CONGELADO! No te podés mover" .. fire
	elseif stacks >= chillCfg.MaxStacks - 1 then
		chillInfo.Text = "¡Te vas a congelar! Andá a una fogata" .. fire
		chillInfo.TextTransparency = if math.sin(clock * 10) > 0 then 0 else 0.5
	else
		chillInfo.TextTransparency = 0
		chillInfo.Text = string.format("Te frena %d%%%s", math.floor(stacks * (chillCfg.SlowPerStack or 0.09) * 100 + 0.5), fire)
	end
	whiteout.BackgroundTransparency = 1 - blizzardK * 0.3
end

---------------------------------------------------------------------
-- Luz: frío azulado, destellos, rayos de sol
---------------------------------------------------------------------

local function lightingOn(parent: Instance)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "IceWorldColor"
	cc.TintColor = Color3.fromRGB(215, 230, 255)
	cc.Saturation = -0.05
	cc.Contrast = 0.06
	cc.Brightness = 0
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "IceWorldBloom"
	bloom.Intensity = 0.55
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Enabled = false -- (pantalla demasiado brillante y pesada) el bloom del capítulo ya lo pone Atmosphere
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "IceWorldRays"
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Enabled = false
	rays.Parent = Lighting
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "IceWorldDepth"
	dof.FarIntensity = 0.18
	dof.FocusDistance = 70
	dof.InFocusRadius = 60
	dof.NearIntensity = 0
	dof.Enabled = false -- pesado en placas de video modestas
	dof.Parent = Lighting
	-- Se borran junto con el mundo
	for _, fx in { cc, bloom, rays, dof } do
		local tag = Instance.new("ObjectValue")
		tag.Name = "Efecto"
		tag.Value = fx
		tag.Parent = parent
	end
end

---------------------------------------------------------------------
-- Ambiente alrededor de la cámara
---------------------------------------------------------------------

local dustPart: Part? = nil
local driftPart: Part? = nil
local stormPart: Part? = nil
local storm: ParticleEmitter? = nil
local drift: ParticleEmitter? = nil

local function ambientOn(parent: Instance)
	-- Polvo de diamante: cristalitos que brillan en el aire
	dustPart = newPart("PolvoDeDiamante", Vector3.new(70, 30, 70), parent)
	emitter(dustPart :: Part, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), FROST),
		LightEmission = 1,
		LightInfluence = 0,
		Size = seq(0.04, 0.12, 0.03),
		Transparency = seq(1, 0, 1),
		Lifetime = NumberRange.new(2, 4),
		Rate = if low then 6 else 18,
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-90, 90),
	})
	-- Nieve que barre el piso con el viento
	driftPart = newPart("NieveBarrida", Vector3.new(110, 1, 110), parent)
	drift = emitter(driftPart :: Part, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(240, 248, 255)),
		LightInfluence = 0.6,
		Size = seq(1, 3),
		Transparency = seq(1, 0.88, 1),
		Lifetime = NumberRange.new(2, 3.5),
		Rate = if low then 3 else 8,
		Speed = NumberRange.new(0.5, 1.5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(6, 0.2, 2),
		RotSpeed = NumberRange.new(-20, 20),
	})
	-- Ventisca: nieve horizontal (apagada hasta que sopla)
	stormPart = newPart("Ventisca", Vector3.new(60, 30, 60), parent)
	storm = emitter(stormPart :: Part, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)),
		LightInfluence = 0.8,
		Size = seq(0.15, 0.3),
		Transparency = seq(0.3, 0.8),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 0,
		Speed = NumberRange.new(45, 70),
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(8, 8),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	local streak = emitter(stormPart :: Part, {
		Name = "Rafagas",
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
		LightInfluence = 0.5,
		Size = seq(5, 10),
		Transparency = seq(1, 0.9, 1),
		Lifetime = NumberRange.new(1, 1.8),
		Rate = 0,
		Speed = NumberRange.new(30, 45),
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(15, 15),
	})
	streak:SetAttribute("Rafaga", true)
end

local function updateAmbient()
	local p = camPos()
	local root = myRoot()
	local ground = if root then root.Position.Y - 3 else p.Y - 6
	if dustPart then
		dustPart.CFrame = CFrame.new(p)
	end
	if driftPart then
		driftPart.CFrame = CFrame.new(p.X, ground, p.Z)
	end
	if drift then
		local w = windDir * (6 + blizzardK * 30)
		drift.Acceleration = Vector3.new(w.X, 0.2, w.Z)
		drift.Rate = (if low then 3 else 8) * (1 + blizzardK * 1.5)
	end
	if stormPart then
		-- La caja se pone contra el viento para que la nieve cruce la pantalla
		local origin = p - windDir * 25 + Vector3.new(0, 4, 0)
		stormPart.CFrame = CFrame.lookAt(origin, origin + windDir)
	end
	if storm then
		storm.Rate = blizzardK * (if low then 90 else 260)
		local streak = stormPart and stormPart:FindFirstChild("Rafagas") :: ParticleEmitter?
		if streak then
			streak.Rate = blizzardK * (if low then 2 else 6)
		end
	end
end

---------------------------------------------------------------------
-- Aurora boreal (cintas de luz en el cielo)
---------------------------------------------------------------------

local auroraBeams: { Beam } = {}

local function auroraOn(parent: Instance)
	if low then
		return
	end
	local colors = {
		ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 170)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 210, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 110, 255)) }),
		ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 140, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 255)) }),
		ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 255, 140)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)) }),
	}
	for i = 1, 3 do
		local a = math.rad(25 + i * 40)
		local center = Vector3.new(math.cos(a) * 320, 170 + i * 18, math.sin(a) * 320)
		local side = Vector3.new(-math.sin(a), 0, math.cos(a)) * 220
		local anchor = newPart("Aurora" .. i, Vector3.one, parent)
		anchor.Position = center
		local a0 = Instance.new("Attachment")
		a0.WorldPosition = center - side
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.WorldPosition = center + side
		a1.Parent = anchor
		-- Dos cintas por aurora: una ancha y suave, otra fina y brillante
		for k = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Color = colors[i]
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Texture = SMOKE
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.TextureSpeed = 0.05 * k
			beam.Width0 = if k == 1 then 90 else 35
			beam.Width1 = if k == 1 then 70 else 25
			beam.Segments = 40
			beam.FaceCamera = true
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, if k == 1 then 0.6 else 0.4),
				NumberSequenceKeypoint.new(0.5, if k == 1 then 0.5 else 0.25),
				NumberSequenceKeypoint.new(0.8, if k == 1 then 0.62 else 0.4),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam:SetAttribute("Fase", i * 1.7 + k)
			beam.Parent = anchor
			table.insert(auroraBeams, beam)
		end
	end
end

local function updateAurora()
	for _, beam in auroraBeams do
		local f = (beam:GetAttribute("Fase") :: number?) or 0
		beam.CurveSize0 = math.sin(clock * 0.25 + f) * 60
		beam.CurveSize1 = math.cos(clock * 0.2 + f * 1.3) * 60
	end
end

---------------------------------------------------------------------
-- Personajes: aliento, pisadas, bloque de hielo al congelarse
---------------------------------------------------------------------

local breath: { [Model]: ParticleEmitter } = {}
local iceBlocks: { [Player]: Part } = {}
local stepPuff: ParticleEmitter? = nil
local skid: ParticleEmitter? = nil
local nextBreath = 0

local function breathFor(character: Model): ParticleEmitter?
	local e = breath[character]
	if e and e.Parent then
		return e
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head or not world then
		return nil
	end
	local att = Instance.new("Attachment")
	att.Name = "Aliento"
	att.Position = Vector3.new(0, -0.15, -0.65)
	att.Parent = head
	e = emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(245, 250, 255)),
		LightInfluence = 0.7,
		Size = seq(0.2, 1.1),
		Transparency = seq(0.55, 1),
		Lifetime = NumberRange.new(0.7, 1.1),
		Rate = 0,
		Speed = NumberRange.new(1.5, 2.5),
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 0.8, 0),
	})
	breath[character] = e
	return e
end

local function feetFx(root: BasePart)
	if stepPuff and stepPuff.Parent and stepPuff.Parent.Parent == root then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "PisadasHielo"
	att.Position = Vector3.new(0, -2.9, 0)
	att.Parent = root
	stepPuff = emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(245, 250, 255)),
		LightInfluence = 0.8,
		Size = seq(0.6, 2),
		Transparency = seq(0.45, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 0,
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -4, 0),
	})
	skid = emitter(att, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), FROST),
		LightEmission = 1,
		Size = seq(0.25, 0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Rate = 0,
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(70, 20),
		Acceleration = Vector3.new(0, -20, 0),
	})
end

local function setIceBlock(p: Player, on: boolean)
	local block = iceBlocks[p]
	if on then
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or block or not world then
			return
		end
		block = Instance.new("Part")
		block.Name = "BloqueDeHielo"
		block.Anchored = false
		block.CanCollide = false
		block.CanQuery = false
		block.CanTouch = false
		block.Massless = true
		block.Material = Enum.Material.Glass
		block.Color = Color3.fromRGB(170, 225, 255)
		block.Transparency = 1
		block.Reflectance = 0.2
		block.Size = Vector3.new(4.6, 6.4, 4.6)
		block.CFrame = root.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = block
		weld.Part1 = root
		weld.Parent = block
		local glow = Instance.new("PointLight")
		glow.Color = FROST
		glow.Range = 10
		glow.Brightness = 1.5
		glow.Parent = block
		emitter(block, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(230, 245, 255)),
			Size = seq(1, 3),
			Transparency = seq(0.6, 1),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 6,
			Speed = NumberRange.new(0.5, 1),
			SpreadAngle = Vector2.new(180, 180),
		})
		block.Parent = world
		iceBlocks[p] = block
		TweenService:Create(block, TweenInfo.new(0.15), { Transparency = 0.35 }):Play()
		if p == player then
			flashBanner("¡CONGELADO!", 1.2)
		end
	elseif block then
		iceBlocks[p] = nil
		-- Se rompe
		local pos = block.Position
		local burst = newPart("HieloRoto", Vector3.one, world)
		burst.Position = pos
		local e = emitter(burst, {
			Texture = SPARK,
			Color = ColorSequence.new(ICE, Color3.new(1, 1, 1)),
			LightEmission = 0.8,
			Size = seq(0.6, 0),
			Lifetime = NumberRange.new(0.4, 0.8),
			Rate = 0,
			Speed = NumberRange.new(12, 22),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -35, 0),
		})
		e:Emit(40)
		Debris:AddItem(burst, 1)
		block:Destroy()
	end
end

local function updateCharacters(dt: number)
	local now = clock
	local doBreath = now >= nextBreath
	if doBreath then
		nextBreath = now + 1.7
	end
	local cam = camPos()
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			if doBreath and (root.Position - cam).Magnitude < 70 then
				local e = breathFor(character)
				if e then
					task.delay(math.random() * 0.6, function()
						if e.Parent then
							e:Emit(4)
						end
					end)
				end
			end
			setIceBlock(p, p:GetAttribute("Frozen") == true)
		end
	end
	-- Pisadas propias (el material del piso solo se conoce bien en el personaje propio)
	local character = player.Character
	local root = myRoot()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		feetFx(root)
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local mat = humanoid.FloorMaterial
		if stepPuff then
			stepPuff.Rate = if mat == Enum.Material.Snow and speed > 3 then speed * 0.8 else 0
		end
		if skid then
			local turning = humanoid.MoveDirection.Magnitude > 0.1 and v.Magnitude > 4
				and Vector3.new(v.X, 0, v.Z).Unit:Dot(humanoid.MoveDirection) < 0.6
			local onIce = mat == Enum.Material.Ice or mat == Enum.Material.Glacier
			skid.Rate = if onIce and (turning or speed > 6) then (if turning then 60 else 12) else 0
		end
	end
end

---------------------------------------------------------------------
-- Enemigos de hielo: niebla fría y estallido de hielo al morir
---------------------------------------------------------------------

local shardsAlive = 0

local function frostAura(part: Instance)
	if not part:IsA("BasePart") or low or not world then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "AuraHelada"
	att.Parent = part
	emitter(att, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(215, 240, 255)),
		LightInfluence = 0.6,
		Size = seq(1, 2.6),
		Transparency = seq(0.82, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 1.5,
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -1.5, 0),
	})
	emitter(att, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.new(1, 1, 1), FROST),
		LightEmission = 1,
		Size = seq(0.18, 0),
		Lifetime = NumberRange.new(0.5, 1),
		Rate = 2,
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
	})
end

local function shatter(part: Instance)
	if not part:IsA("BasePart") or not world then
		return
	end
	local pos = part.Position
	if (pos - camPos()).Magnitude > 120 then
		return
	end
	local big = part:GetAttribute("ThreatRole") == "Boss"
	local count = if low then 3 else (if big then 18 else 7)
	for _ = 1, count do
		if shardsAlive > 60 then
			break
		end
		local s = Instance.new("Part")
		s.Name = "TrozoDeHielo"
		local size = (if big then 1.8 else 0.8) * (0.6 + math.random() * 0.8)
		s.Size = Vector3.new(size, size * 1.4, size * 0.8)
		s.Material = Enum.Material.Ice
		s.Color = ICE
		s.Transparency = 0.2
		s.CanQuery = false
		s.CanTouch = false
		s.CanCollide = true
		s.Massless = true
		s.CFrame = CFrame.new(pos + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5) * 2) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		s.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, 14 + math.random() * 16, (math.random() - 0.5) * 30)
		s.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		s.Parent = world
		shardsAlive += 1
		TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		task.delay(1.3, function()
			shardsAlive -= 1
			s:Destroy()
		end)
	end
	local burst = newPart("Escarcha", Vector3.one, world)
	burst.Position = pos
	local e = emitter(burst, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.new(1, 1, 1), FROST),
		LightEmission = 1,
		Size = seq(if big then 1 else 0.5, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 0,
		Speed = NumberRange.new(8, 18),
		SpreadAngle = Vector2.new(180, 180),
	})
	local mist = emitter(burst, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(230, 245, 255)),
		Size = seq(1.5, if big then 12 else 5),
		Transparency = seq(0.5, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 0,
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(180, 180),
	})
	e:Emit(if big then 60 else 20)
	mist:Emit(if big then 14 else 5)
	Debris:AddItem(burst, 1.2)
end

---------------------------------------------------------------------
-- Ataques de los enemigos: destello helado al disparar y estacas de hielo al caer un área
---------------------------------------------------------------------

local muzzleBudget = 0

local function muzzleBurst(origin: Vector3, dir: Vector3)
	if not world or (origin - camPos()).Magnitude > 140 then
		return
	end
	muzzleBudget += 1
	if muzzleBudget > 25 then
		return -- muchos disparos a la vez: no saturar
	end
	task.delay(0.5, function()
		muzzleBudget -= 1
	end)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local holder = newPart("DisparoHelado", Vector3.one, world)
	holder.CFrame = CFrame.lookAt(origin, origin + look)
	-- Anillo de escarcha que se abre hacia adelante
	local ring = Instance.new("Part")
	ring.Name = "Anillo"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 220, 255)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 1.2, 1.2)
	ring.CFrame = CFrame.lookAt(origin + look * 1.2, origin + look * 3) * CFrame.Angles(0, math.rad(90), 0)
	ring.Transparency = 0.1
	ring.Parent = world
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.new(0.15, 5, 5), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
	local shards = emitter(holder, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 210, 255)),
		LightEmission = 1,
		Size = seq(0.45, 0),
		Lifetime = NumberRange.new(0.25, 0.5),
		Rate = 0,
		Speed = NumberRange.new(10, 22),
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(25, 25),
	})
	local puff = emitter(holder, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
		Size = seq(0.8, 3),
		Transparency = seq(0.45, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Rate = 0,
		Speed = NumberRange.new(3, 6),
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(35, 35),
	})
	shards:Emit(if low then 6 else 16)
	puff:Emit(if low then 2 else 5)
	if not low then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(120, 210, 255)
		light.Range = 10
		light.Brightness = 4
		light.Parent = holder
		TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	end
	Debris:AddItem(holder, 0.8)
end

-- Al terminar un aviso de área: estacas de hielo que brotan del piso y se rompen
local function iceEruption(pos: Vector3, radius: number)
	if not world or (pos - camPos()).Magnitude > 160 then
		return
	end
	local count = if low then 3 else math.clamp(math.floor(radius * 1.4), 4, 12)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.5
		local d = if i == 1 then 0 else radius * (0.3 + math.random() * 0.6)
		local base = pos + Vector3.new(math.cos(a) * d, -0.5, math.sin(a) * d)
		local h = (if i == 1 then 1.6 else 1) * (2 + math.random() * 2.5) * math.max(1, radius / 4)
		local s = Instance.new("Part")
		s.Name = "EstacaDeHielo"
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.Material = Enum.Material.Ice
		s.Color = Color3.fromRGB(175, 225, 255)
		s.Transparency = 0.15
		s.Reflectance = 0.15
		local w = h * 0.28
		s.Size = Vector3.new(w, 0.2, w)
		local tilt = CFrame.Angles(math.rad(math.random(-25, 25)), math.random() * 6, math.rad(math.random(-25, 25)))
		s.CFrame = CFrame.new(base) * tilt
		s.Parent = world
		TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(base) * tilt * CFrame.new(0, h / 2, 0),
		}):Play()
		task.delay(0.7 + math.random() * 0.3, function()
			TweenService:Create(s, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(w * 0.6, h * 0.6, w * 0.6) }):Play()
		end)
		Debris:AddItem(s, 1.3)
	end
	local holder = newPart("Estallido", Vector3.one, world)
	holder.Position = pos + Vector3.new(0, 0.5, 0)
	emitter(holder, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 215, 255)),
		LightEmission = 1,
		Size = seq(0.6, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 0,
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -35, 0),
	}):Emit(if low then 8 else 26)
	emitter(holder, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(230, 245, 255)),
		Size = seq(2, radius * 1.6),
		Transparency = seq(0.4, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 0,
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(80, 10),
	}):Emit(if low then 3 else 8)
	Debris:AddItem(holder, 1.2)
end

local function watchWarning(inst: Instance)
	if not inst:GetAttribute("Warning") then
		return
	end
	local endsAt = inst:GetAttribute("EndsAt")
	local radius = inst:GetAttribute("Radius")
	if type(endsAt) ~= "number" or type(radius) ~= "number" or not inst:IsA("BasePart") then
		return
	end
	local pos = (inst :: BasePart).Position
	task.delay(math.max(0, endsAt - Workspace:GetServerTimeNow()), function()
		if active then
			iceEruption(pos, radius)
		end
	end)
end

---------------------------------------------------------------------
-- Decoración: destellos en cristales y humo en fogatas
---------------------------------------------------------------------

-- Marcador fijo de cada fogata: ícono y distancia que se ven siempre, a través de todo, y una
-- columna de luz naranja. Si tenés frío, late para que vayas.
local fogatas: { { gui: BillboardGui, label: TextLabel, core: BasePart } } = {}

local function markCampfire(core: BasePart)
	if core:FindFirstChild("MarcaFogata") then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "MarcaFogata"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 10000
	bb.Size = UDim2.fromOffset(70, 62)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	bb.ResetOnSpawn = false
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 40)
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.Text = "🔥"
	icon.Parent = bb
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, 40)
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 190, 90)
	label.TextStrokeTransparency = 0.2
	label.Text = ""
	label.Parent = bb
	bb.Adornee = core
	bb.Parent = core
	-- Columna de luz que se ve de lejos
	local a0 = Instance.new("Attachment")
	a0.Name = "ColumnaBase"
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Name = "ColumnaTope"
	a1.Position = Vector3.new(0, 70, 0)
	a1.Parent = core
	local beam = Instance.new("Beam")
	beam.Name = "Columna"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 220, 120))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 2.2
	beam.Width1 = 0.6
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = core
	table.insert(fogatas, { gui = bb, label = label, core = core })
end

local function updateCampfires()
	local root = myRoot()
	local cold = ((player:GetAttribute("Chill") :: number?) or 0) > 0 or player:GetAttribute("Frozen") == true or blizzardK > 0.05
	local pulse = if cold then 1 + math.sin(clock * 6) * 0.18 else 1
	local nearest, best = nil, math.huge
	nearestFireDist = nil
	for i = #fogatas, 1, -1 do
		local f = fogatas[i]
		if not f.core.Parent then
			table.remove(fogatas, i)
		elseif root then
			local d = (f.core.Position - root.Position).Magnitude
			f.label.Text = string.format("%d m", math.floor(d + 0.5))
			f.gui.Size = UDim2.fromOffset(70 * pulse, 62 * pulse)
			if d < best then
				nearest, best = f, d
			end
			nearestFireDist = best
		end
	end
	-- La más cercana, más grande cuando tenés frío
	for _, f in fogatas do
		local big = cold and f == nearest
		f.gui.Size = UDim2.fromOffset((if big then 92 else 64) * pulse, (if big then 80 else 58) * pulse)
		f.label.TextColor3 = if big then Color3.fromRGB(255, 240, 150) else Color3.fromRGB(255, 190, 90)
	end
end

local function decorate(inst: Instance)
	if not world then
		return
	end
	if inst:IsA("BasePart") and (inst.Name == "IceCrystal" or inst.Name == "IcePillar") and not low then
		if inst:FindFirstChild("Destellos") then
			return
		end
		local e = emitter(inst, {
			Name = "Destellos",
			Texture = SPARK,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 215, 255)),
			LightEmission = 1,
			Size = seq(0, 0.45, 0),
			Lifetime = NumberRange.new(0.4, 0.8),
			Rate = 1.2,
			Speed = NumberRange.new(0, 0),
		})
		e:SetAttribute("IceWorld", true)
	elseif inst:IsA("Model") and inst:GetAttribute("Warm") then
		local core = inst:FindFirstChild("Brasa")
		if core and core:IsA("BasePart") then
			markCampfire(core)
		end
		if core and not core:FindFirstChild("Humo") then
			local e = emitter(core, {
				Name = "Humo",
				Texture = SMOKE,
				Color = ColorSequence.new(Color3.fromRGB(90, 85, 85), Color3.fromRGB(180, 180, 185)),
				Size = seq(1.5, 7),
				Transparency = seq(0.5, 1),
				Lifetime = NumberRange.new(3, 5),
				Rate = if low then 3 else 8,
				Speed = NumberRange.new(3, 5),
				SpreadAngle = Vector2.new(10, 10),
				Acceleration = Vector3.new(1.5, 1, 0.5),
			})
			e:SetAttribute("IceWorld", true)
		end
	end
end

---------------------------------------------------------------------
-- Resbalar y viento (movimiento propio)
---------------------------------------------------------------------

local slideVel: Vector3? = nil
local slopeParams = RaycastParams.new()
slopeParams.FilterType = Enum.RaycastFilterType.Include
slopeParams.FilterDescendantsInstances = { Workspace.Terrain }

-- ¿Está en una pendiente? (ahí se camina normal: si no, no se pueden subir rampas ni lomas)
local function onSlope(root: BasePart): boolean
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), slopeParams)
	return hit ~= nil and hit.Normal.Y < 0.96
end

local function onPreSimulation(dt: number)
	if not active then
		slideVel = nil
		return
	end
	local character = player.Character
	local root = myRoot()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or player:GetAttribute("Grabbed") or player:GetAttribute("Cinematic") then
		slideVel = nil
		return
	end
	local cur = root.AssemblyLinearVelocity
	local flatCur = Vector3.new(cur.X, 0, cur.Z)
	local mat = humanoid.FloorMaterial
	local inAir = mat == Enum.Material.Air
	-- Dash, empujones o retroceso: se respetan y el resbalón sigue desde ahí
	if flatCur.Magnitude > humanoid.WalkSpeed * 1.6 + 4 then
		slideVel = flatCur
		return
	end
	if player:GetAttribute("Frozen") then
		slideVel = Vector3.zero
		root.AssemblyLinearVelocity = Vector3.new(0, cur.Y, 0)
		return
	end
	local wind = windDir * (blizzardCfg.WindPush or 8) * blizzardK
	local g = grip[mat.Name]
	if g and onSlope(root) then
		g = nil -- en subidas y bajadas no se resbala
	end
	if inAir then
		-- En el aire no se toca (salvo el viento)
		if blizzardK > 0.01 then
			root.AssemblyLinearVelocity = cur + wind * dt * 3
		end
		slideVel = flatCur
		return
	end
	-- En pendiente o sin hielo y sin viento: no se toca nada, camina el Humanoid normal
	if type(g) ~= "number" and blizzardK < 0.01 then
		slideVel = nil
		return
	end
	local speed = humanoid.WalkSpeed * (if mat == Enum.Material.Snow and type(g) == "number" then (grip.SnowSpeed or 1) else 1)
	local desired = humanoid.MoveDirection * speed
	if type(g) ~= "number" then
		g = 30 -- normal: casi instantáneo
	end
	local v = slideVel or flatCur
	v = v:Lerp(desired, 1 - math.exp(-(g :: number) * dt))
	slideVel = v
	local final = v + wind
	root.AssemblyLinearVelocity = Vector3.new(final.X, cur.Y, final.Z)
end

---------------------------------------------------------------------
-- Ventisca (atributo Blizzard = "inicio|fin|dirX|dirZ")
---------------------------------------------------------------------

local warned = false
local function readBlizzardNext()
	local v = gameState:GetAttribute("BlizzardNext")
	blizzardNext = if type(v) == "number" then v else 0
end

local function readBlizzard()
	local v = gameState:GetAttribute("Blizzard")
	if type(v) ~= "string" or v == "" then
		blizzardStart, blizzardEnd = 0, 0
		return
	end
	local parts = string.split(v, "|")
	blizzardStart = tonumber(parts[1]) or 0
	blizzardEnd = tonumber(parts[2]) or 0
	local dx, dz = tonumber(parts[3]) or 1, tonumber(parts[4]) or 0
	local d = Vector3.new(dx, 0, dz)
	windDir = if d.Magnitude > 0.01 then d.Unit else Vector3.new(1, 0, 0)
	warned = false
end

local function updateBlizzard(dt: number)
	local now = Workspace:GetServerTimeNow()
	local target = 0
	if blizzardEnd > 0 then
		if now < blizzardStart then
			if not warned and active then
				warned = true
				flashBanner("¡VENTISCA! Corré a una fogata 🔥", 2.4)
			end
		elseif now < blizzardEnd then
			target = 1
		end
	end
	blizzardK += (target - blizzardK) * math.min(1, dt * (if target > blizzardK then 1.2 else 0.8))
	if blizzardK < 0.001 then
		blizzardK = 0
	end
end

---------------------------------------------------------------------
-- Encender / apagar
---------------------------------------------------------------------

local function turnOff()
	active = false
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	for p in iceBlocks do
		setIceBlock(p, false)
	end
	if world then
		for _, tag in world:GetChildren() do
			if tag:IsA("ObjectValue") and tag.Value then
				tag.Value:Destroy()
			end
		end
		world:Destroy()
		world = nil
	end
	for character, e in breath do
		if e.Parent then
			(e.Parent :: Instance):Destroy()
		end
	end
	table.clear(breath)
	table.clear(auroraBeams)
	table.clear(fogatas)
	if stepPuff and stepPuff.Parent then
		(stepPuff.Parent :: Instance):Destroy()
	end
	stepPuff, skid = nil, nil
	dustPart, driftPart, stormPart, storm, drift = nil, nil, nil, nil, nil
	blizzardK = 0
	gui.Enabled = false
end

local function turnOn()
	if active then
		return
	end
	active = true
	local folder = Instance.new("Folder")
	folder.Name = "IceWorld"
	folder.Parent = Workspace
	world = folder
	gui.Enabled = true
	lightingOn(folder)
	ambientOn(folder)
	auroraOn(folder)
	readBlizzard()
	readBlizzardNext()
	-- Decoración del mapa (cristales y fogatas)
	task.spawn(function()
		local n = 0
		for _, inst in Workspace:GetDescendants() do
			if not active then
				return
			end
			if inst.Name == "IceCrystal" or inst.Name == "IcePillar" or (inst:IsA("Model") and inst.Name == "Fogata") then
				decorate(inst)
				n += 1
				if n % 40 == 0 then
					task.wait()
				end
			end
		end
	end)
	table.insert(conns, Workspace.DescendantAdded:Connect(function(inst)
		if inst.Name == "Fogata" or inst.Name == "IceCrystal" or inst.Name == "IcePillar" then
			task.defer(decorate, inst)
		end
	end))
	-- Avisos de área (Hazards): estacas de hielo al caer
	local hazards = Workspace:FindFirstChild("Hazards")
	if hazards then
		table.insert(conns, hazards.DescendantAdded:Connect(function(inst)
			task.defer(watchWarning, inst) -- los atributos se ponen apenas después de crearlo
		end))
	end
	-- Enemigos
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		for _, e in enemies:GetChildren() do
			frostAura(e)
		end
		table.insert(conns, enemies.ChildAdded:Connect(frostAura))
		table.insert(conns, enemies.ChildRemoved:Connect(shatter))
	end
end

local function refresh()
	local on = gameState:GetAttribute("MapEvents") == "glacier" and player:GetAttribute("InMatch") == true
	if on then
		turnOn()
	else
		turnOff()
	end
end

gameState:GetAttributeChangedSignal("MapEvents"):Connect(refresh)
gameState:GetAttributeChangedSignal("Blizzard"):Connect(readBlizzard)
gameState:GetAttributeChangedSignal("BlizzardNext"):Connect(readBlizzardNext)
gameState:GetAttributeChangedSignal("GlacierTip"):Connect(function()
	local v = gameState:GetAttribute("GlacierTip")
	if active and type(v) == "string" and v ~= "" then
		local parts = string.split(v, "|")
		local at = tonumber(parts[2]) or 0
		if Workspace:GetServerTimeNow() - at < 5 then
			showTip(parts[1])
		end
	end
end)
player:GetAttributeChangedSignal("LastHurt"):Connect(function()
	if active then
		showHurt()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
refresh()

RunService.PreSimulation:Connect(onPreSimulation)
-- Cada disparo enemigo (ownerUserId 0) sale con un destello helado
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ProjectileFired").OnClientEvent:Connect(function(_id, origin, dir, _speed, _life, ownerUserId)
	if active and ownerUserId == 0 and typeof(origin) == "Vector3" and typeof(dir) == "Vector3" then
		muzzleBurst(origin, dir)
	end
end)
RunService.RenderStepped:Connect(function(dt)
	if not active then
		return
	end
	clock += dt
	updateBlizzard(dt)
	updateAmbient()
	updateAurora()
	updateCharacters(dt)
	updateChillUi(dt)
	updateCampfires()
	updateStormBar()
end)
