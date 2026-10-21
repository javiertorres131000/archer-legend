--!strict
-- CrateCinematic (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > CrateCinematic
-- Animación de apertura de una caja. Solo es visual y solo la ve quien abre: el premio ya lo
-- decidió el servidor (CrateService) antes de que esto arranque.
--
-- Secuencia (tiempos en Config.Crates.Cinematic):
--   1. Fundido a negro y el título "<NOMBRE> CRATE" con una línea brillante.
--   2. La cámara (Scriptable) pasa a una arena armada solo en este cliente: piso con lava,
--      pedestal hexagonal iluminado, arcos rojos, antorchas y brasas.
--   3. La caja cae sobre el pedestal, tiembla y brilla cada vez más y explota en un flash.
--   4. Los premios posibles aparecen en círculo, cada uno en su mini pedestal con un anillo
--      de neón del color de su rareza, y la cámara gira despacio alrededor.
--   5. Ruleta: se resaltan uno por uno, cada vez más lento, hasta frenar en el premio ganado.
--   6. El premio sube al pedestal central con un haz de luz y partículas de su color. Desde
--      Legendary (CrateItems.BigRevealFrom) el efecto es más fuerte y la cámara se sacude.
--   7. Nombre, rareza y botón "Continue" para volver a la cámara normal.
-- Al terminar (o si empieza una partida en el medio) se desconecta todo y se borra la arena.
-- El atributo "Cinematic" del jugador avisa a CameraController (no toca la cámara) y a
-- Atmosphere (luz volcánica) mientras dura.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Crates = require(Shared:WaitForChild("Crates"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local CrateModels = require(Shared:WaitForChild("CrateModels"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Cfg = Config.Crates.Cinematic
local player = Players.LocalPlayer
local part = CrateModels.part

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local LAVA = C(255, 90, 18)
local ARCH = C(92, 16, 14)
local ARCH_GLOW = C(255, 45, 30)
local BIND = "CrateCinematicCamera"
local FREEZE = "CrateCinematicFreeze"
local PEDESTAL_TOP = 3 -- alto del pedestal central

local KIND_NAMES = { Unit = "Unidad", Pet = "Mascota", Character = "Personaje", Weapon = "Arma" }

export type Result = { Prize: string, Count: number?, New: boolean? }

type Item = {
	id: string,
	model: Model,
	base: Vector3, -- dónde apoya los pies
	baseScale: number,
	lastScale: number,
	pop: number, -- 0..1 aparición
	pulse: number, -- resaltado de la ruleta (decae solo)
	sink: number, -- 0..1 se hunde (los que no ganaron)
	spin: number,
	color: Color3,
	rims: { Part },
	disc: Part,
	light: PointLight,
	label: BillboardGui,
}

local CrateCinematic = {}

local playing = false

function CrateCinematic.isPlaying(): boolean
	return playing
end

---------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function backOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function bounceOut(x: number): number
	local n1, d1 = 7.5625, 2.75
	if x < 1 / d1 then
		return n1 * x * x
	elseif x < 2 / d1 then
		x -= 1.5 / d1
		return n1 * x * x + 0.75
	elseif x < 2.5 / d1 then
		x -= 2.25 / d1
		return n1 * x * x + 0.9375
	end
	x -= 2.625 / d1
	return n1 * x * x + 0.984375
end

local function uiScale(): number
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.4)
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: UDim?)
	make("UICorner", { CornerRadius = radius or UDim.new(0, 10) }, parent)
end

---------------------------------------------------------------------
-- Arena (solo en este cliente)
---------------------------------------------------------------------

type Arena = {
	folder: Folder,
	top: Vector3, -- centro de la cara de arriba del pedestal
	pedestalRims: { Part },
	archGlows: { Part },
	torches: { CrateModels.Torch },
	spot: SpotLight,
}

local function buildArch(parent: Instance, base: CFrame, width: number, height: number)
	local r = width / 2
	for _, side in { -1, 1 } do
		part(parent, "ArchPillar", Vector3.new(3, height, 3), base * CFrame.new(side * r, height / 2, 0), ARCH, Enum.Material.Slate)
		part(parent, "ArchFoot", Vector3.new(4.4, 1.6, 4.4), base * CFrame.new(side * r, 0.8, 0), ARCH:Lerp(C(0, 0, 0), 0.4), Enum.Material.Basalt)
		local trim = part(parent, "ArchGlow", Vector3.new(0.4, height, 0.7), base * CFrame.new(side * (r - 1.6), height / 2, 0), ARCH_GLOW, Enum.Material.Neon)
		trim.CastShadow = false
	end
	local segments = 12
	local segLen = math.pi * r / segments + 0.45
	for k = 0, segments do
		local a = k / segments * math.pi
		local pos = Vector3.new(r * math.cos(a), height + r * math.sin(a), 0)
		part(parent, "ArchTop", Vector3.new(3, segLen, 3), base * CFrame.new(pos) * CFrame.Angles(0, 0, a), ARCH, Enum.Material.Slate)
		local inner = Vector3.new((r - 1.6) * math.cos(a), height + (r - 1.6) * math.sin(a), 0)
		local glow = part(parent, "ArchGlow", Vector3.new(0.4, segLen * 0.82, 0.7), base * CFrame.new(inner) * CFrame.Angles(0, 0, a), ARCH_GLOW, Enum.Material.Neon)
		glow.CastShadow = false
	end
end

local function buildArena(origin: Vector3, crate: Crates.Crate): Arena
	local folder = Instance.new("Folder")
	folder.Name = "CrateCinematicArena"
	local o = CFrame.new(origin)
	-- Piso de roca y lava
	part(folder, "Floor", Vector3.new(170, 2, 170), o * CFrame.new(0, -1, 0), C(78, 54, 48), Enum.Material.CrackedLava)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 29, 0.05, math.sin(a) * 29)
		local seg = part(folder, "LavaRing", Vector3.new(2.4, 0.1, 29 * math.pi * 2 / 24 + 0.3), o * CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))), LAVA, Enum.Material.Neon)
		seg.CastShadow = false
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 70, 0.05, math.sin(a) * 70)
		local sea = part(folder, "LavaSea", Vector3.new(28, 0.1, 70 * math.pi * 2 / 16 + 4), o * CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))), C(235, 70, 12), Enum.Material.Neon)
		sea.CastShadow = false
	end
	local rng = Random.new(77)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(9, 50)
		local pos = Vector3.new(math.cos(a) * d, 0.04, math.sin(a) * d)
		local dir = Vector3.new(math.cos(a + rng:NextNumber(-0.6, 0.6)), 0, math.sin(a + rng:NextNumber(-0.6, 0.6)))
		local crack = part(folder, "LavaCrack", Vector3.new(rng:NextNumber(0.3, 0.7), 0.08, rng:NextNumber(4, 10)), o * CFrame.lookAt(pos, pos + dir), LAVA, Enum.Material.Neon)
		crack.CastShadow = false
	end
	-- Pedestal central: tres escalones hexagonales con borde de neón del color de la caja
	local rims = {}
	local tiers = { { 6.6, 1 }, { 5, 1 }, { 3.7, 1 } }
	local y = 0
	for i, tier in tiers do
		y += tier[2]
		local top = o * CFrame.new(0, y, 0)
		CrateModels.hex(folder, "Pedestal", top, tier[1], tier[2], if i == 3 then C(40, 34, 40) else C(30, 24, 26), Enum.Material.Slate)
		for _, rim in CrateModels.hexRim(folder, top, tier[1], 0.4, 0.2, crate.Color:Lerp(C(0, 0, 0), 0.3)) do
			table.insert(rims, rim)
		end
	end
	-- Luz cenital
	local lamp = part(folder, "Lamp", Vector3.new(1, 1, 1), o * CFrame.new(0, 22, 0), WHITE)
	lamp.Transparency = 1
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 45
	spot.Range = 34
	spot.Brightness = 5
	spot.Color = C(255, 235, 215)
	spot.Shadows = true
	spot.Parent = lamp
	-- Arcos rojos alrededor (uno justo detrás del pedestal visto desde la cámara inicial)
	for i = 0, 5 do
		local a = -math.pi / 2 + i * math.pi / 3
		local pos = Vector3.new(math.cos(a) * 40, 0, math.sin(a) * 40)
		buildArch(folder, o * CFrame.lookAt(pos, Vector3.zero), 16, 20)
	end
	local archGlows = {}
	for _, d in folder:GetChildren() do
		if d.Name == "ArchGlow" then
			table.insert(archGlows, d :: Part)
		end
	end
	-- Antorchas a los costados de cada arco (fuera del recorrido de la cámara)
	local torches = {}
	for i = 0, 5 do
		for _, side in { -1, 1 } do
			local a = -math.pi / 2 + i * math.pi / 3 + side * 0.24
			table.insert(torches, CrateModels.torch(folder, o * CFrame.new(math.cos(a) * 38, 0, math.sin(a) * 38), 6))
		end
	end
	-- Brasas flotando por toda la arena
	local embers = part(folder, "Embers", Vector3.new(70, 1, 70), o * CFrame.new(0, 0.6, 0), WHITE)
	embers.Transparency = 1
	local e = CrateModels.embers(embers, C(255, 170, 70), 45, 15)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Lifetime = NumberRange.new(3, 6)
	e.Speed = NumberRange.new(1, 3)
	folder.Parent = workspace
	return {
		folder = folder,
		top = origin + Vector3.new(0, PEDESTAL_TOP, 0),
		pedestalRims = rims,
		archGlows = archGlows,
		torches = torches,
		spot = spot,
	}
end

-- Chispas de un solo disparo (Emit) en `at`
local function burst(parent: Instance, at: Vector3, color: Color3, count: number, speed: number, size: number): Part
	local p = part(parent, "Burst", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), WHITE)
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(WHITE, color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.6, 1.4)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2.5
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	return p
end

---------------------------------------------------------------------
-- La animación
---------------------------------------------------------------------

function CrateCinematic.play(crate: Crates.Crate, result: Result, onDone: (() -> ())?)
	if playing then
		return
	end
	local prize = CrateItems.ById[result.Prize]
	if not prize then
		return
	end
	playing = true
	local rarity = CrateItems.rarity(prize.Rarity)
	local big = rarity.Order >= CrateItems.BigRevealFrom
	local camera = workspace.CurrentCamera
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local origin = Cfg.Origin

	local alive = true
	local finished = false
	local connections: { RBXScriptConnection } = {}
	local hiddenGuis: { ScreenGui } = {}
	local items: { Item } = {}
	local arena: Arena? = nil
	local soundFolder = Instance.new("Folder")
	soundFolder.Name = "CrateCinematicSounds"
	soundFolder.Parent = SoundService

	local function sound(name: string, pitch: number?, volume: number?): Sound?
		local def = (Sounds.List :: any)[name]
		if not def then
			return nil
		end
		local s = Instance.new("Sound")
		s.SoundId = def.Id
		s.Volume = def.Volume * (Sounds.MasterVolume or 1) * (volume or 1)
		s.PlaybackSpeed = def.Pitch * (pitch or 1)
		s.Parent = soundFolder
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
		return s
	end

	-- Que el personaje no camine ni salte mientras mira: se "tragan" las acciones de movimiento
	local function freeze(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority(FREEZE, function()
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 50,
				Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
				Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight,
				Enum.PlayerActions.CharacterJump, Enum.KeyCode.Thumbstick1)
		else
			ContextActionService:UnbindAction(FREEZE)
		end
	end

	-- Interfaz propia de la animación
	local gui = make("ScreenGui", {
		Name = "CrateCinematic",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	local black = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, gui) :: Frame
	local flash = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, gui) :: Frame
	local vignette = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, gui) :: Frame
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.25, 1),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
	}, vignette)

	-- Cámara
	local camMode = "none" -- "fixed" | "orbit" | "focus"
	local camCF = camera.CFrame
	local fixedCF = camera.CFrame
	local focusCF = camera.CFrame
	local orbitAngle = math.pi / 2
	local orbitRadius = 28
	local orbitHeight = 10
	local camSharp = 6
	local fov = 70
	local shake = 0 -- golpes (decae solo)
	local shakeHold = 0 -- temblor sostenido
	local clock = 0

	local function cleanup()
		if not alive then
			return
		end
		alive = false
		RunService:UnbindFromRenderStep(BIND)
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		if arena then
			arena.folder:Destroy()
			arena = nil
		end
		table.clear(items)
		soundFolder:Destroy()
		for _, g in hiddenGuis do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.FieldOfView = 70
		player:SetAttribute("Cinematic", nil)
		freeze(false)
	end

	-- Si empieza una partida en el medio, se corta sin más
	table.insert(connections, player:GetAttributeChangedSignal("InMatch"):Connect(function()
		if player:GetAttribute("InMatch") == true then
			cleanup()
			gui:Destroy()
			playing = false
		end
	end))

	-- Espera que se corta si la animación terminó
	local function pause(t: number): boolean
		task.wait(t)
		return alive
	end

	-- Corre fn(alpha) durante `duration` segundos (alpha de 0 a 1). Bloquea hasta terminar.
	local function over(duration: number, fn: (number) -> ()): boolean
		local start = os.clock()
		while alive do
			local a = math.min((os.clock() - start) / duration, 1)
			fn(a)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		return alive
	end

	-- Cámara y premios, cada frame
	local function onFrame(dt: number)
		clock += dt
		local target = camCF
		if camMode == "fixed" then
			target = fixedCF
		elseif camMode == "orbit" then
			orbitAngle += math.rad(Cfg.OrbitSpeed) * dt
			local pos = origin + Vector3.new(math.cos(orbitAngle) * orbitRadius, orbitHeight, math.sin(orbitAngle) * orbitRadius)
			target = CFrame.lookAt(pos, origin + Vector3.new(0, 2.5, 0))
		elseif camMode == "focus" then
			target = focusCF
		end
		camCF = camCF:Lerp(target, 1 - math.exp(-dt * camSharp))
		shake *= math.exp(-dt * 5)
		local s = shake + shakeHold
		local n1 = math.noise(clock * 18, 1.3)
		local n2 = math.noise(clock * 18, 7.1)
		local n3 = math.noise(clock * 18, 13.7)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camCF * CFrame.new(n1 * s * 0.35, n2 * s * 0.35, 0) * CFrame.Angles(n2 * s * 0.025, n3 * s * 0.025, n1 * s * 0.02)
		camera.FieldOfView += (fov - camera.FieldOfView) * (1 - math.exp(-dt * 4))
		-- Premios: miran a la cámara, laten al resaltarse, se hunden al perder
		local camPos = camCF.Position
		for _, it in items do
			if it.model.Parent then
				it.pulse *= math.exp(-dt * 4.5)
				local pos = it.base + Vector3.new(0, it.pulse * 0.7 - it.sink * 7, 0)
				local face = Vector3.new(camPos.X, pos.Y, camPos.Z)
				local cf = if (face - pos).Magnitude > 0.01 then CFrame.lookAt(pos, face) else CFrame.new(pos)
				local scale = math.max(it.baseScale * backOut(math.clamp(it.pop, 0, 1)) * (1 + it.pulse * 0.18), 0.01)
				if math.abs(scale - it.lastScale) > 0.002 then
					it.model:ScaleTo(scale)
					it.lastScale = scale
				end
				it.model:PivotTo(cf * CFrame.Angles(0, it.spin, 0))
				local ring = it.color:Lerp(WHITE, math.clamp(it.pulse, 0, 1) * 0.75)
				for _, rim in it.rims do
					rim.Color = ring
				end
				it.disc.Color = ring
				it.disc.Transparency = 0.55 - it.pulse * 0.4
				it.light.Brightness = 0.7 + it.pulse * 5
			end
		end
	end

	-- Continuar: fundido a negro, limpiar todo y volver a la cámara normal
	local function finish()
		if finished then
			return
		end
		finished = true
		tween(black, 0.35, { BackgroundTransparency = 0 })
		task.wait(0.4)
		cleanup()
		for _, child in gui:GetChildren() do
			if child ~= black then
				child:Destroy()
			end
		end
		tween(black, 0.45, { BackgroundTransparency = 1 })
		task.wait(0.5)
		gui:Destroy()
		playing = false
		if onDone then
			onDone()
		end
	end

	local function finalCard()
		local holder = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -30),
			Size = UDim2.fromOffset(760, 250),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, gui) :: Frame
		local scale = make("UIScale", { Scale = uiScale() * 0.9 }, holder) :: UIScale
		local color = rarity.Color
		local y = 0
		if result.New then
			local badge = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.fromOffset(96, 28),
				BackgroundColor3 = C(255, 215, 70),
				Font = Enum.Font.GothamBlack,
				Text = "NEW!",
				TextSize = 18,
				TextColor3 = C(60, 30, 0),
				ZIndex = 11,
			}, holder)
			corner(badge, UDim.new(1, 0))
		end
		y = 32
		local name = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = CrateItems.upper(prize.Name),
			TextSize = 58,
			TextColor3 = color,
			ZIndex = 11,
		}, holder) :: TextLabel
		make("UIStroke", { Color = C(10, 5, 5), Thickness = 3 }, name)
		local sub = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y + 66),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			RichText = true,
			Text = string.format('%s  <font color="#d8d2cc">·  %s  ·  x%d</font>', string.upper(rarity.Name), KIND_NAMES[prize.Kind] or prize.Kind, result.Count or 1),
			TextSize = 26,
			TextColor3 = color,
			ZIndex = 11,
		}, holder) :: TextLabel
		make("UIStroke", { Color = C(10, 5, 5), Thickness = 2 }, sub)
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y + 116),
			Size = UDim2.fromOffset(240, 58),
			BackgroundColor3 = C(250, 246, 240),
			AutoButtonColor = false,
			Font = Enum.Font.GothamBlack,
			Text = "Continue",
			TextSize = 26,
			TextColor3 = C(30, 20, 20),
			ZIndex = 11,
		}, holder) :: TextButton
		corner(button, UDim.new(0, 14))
		make("UIStroke", { Color = color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
		local bscale = make("UIScale", {}, button) :: UIScale
		table.insert(connections, button.MouseEnter:Connect(function()
			tween(bscale, 0.12, { Scale = 1.06 })
		end))
		table.insert(connections, button.MouseLeave:Connect(function()
			tween(bscale, 0.12, { Scale = 1 })
		end))
		table.insert(connections, button.Activated:Connect(function()
			task.spawn(finish)
		end))
		-- (sin mirar "processed": ESPACIO está tomado por el freno de movimiento)
		table.insert(connections, UserInputService.InputBegan:Connect(function(input)
			local k = input.KeyCode
			if k == Enum.KeyCode.Return or k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA then
				task.spawn(finish)
			end
		end))
		-- Entra desde abajo
		holder.Position = UDim2.new(0.5, 0, 1, 40)
		scale.Scale = uiScale() * 0.8
		tween(holder, 0.45, { Position = UDim2.new(0.5, 0, 1, -30) }, Enum.EasingStyle.Back)
		tween(scale, 0.45, { Scale = uiScale() * 0.9 }, Enum.EasingStyle.Back)
		-- Secret: el nombre cambia de color
		if prize.Rarity == "Secret" then
			table.insert(connections, RunService.RenderStepped:Connect(function()
				local c = CrateItems.color("Secret", os.clock())
				name.TextColor3 = c
			end))
		end
	end

	-- Secuencia principal
	task.spawn(function()
		-- 1. Negro y título
		player:SetAttribute("Cinematic", true)
		freeze(true)
		tween(black, 0.45, { BackgroundTransparency = 0 })
		if not pause(0.5) then return end
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		local title = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = CrateItems.upper(crate.Name),
			TextSize = 72,
			TextColor3 = crate.Color,
			TextTransparency = 1,
			ZIndex = 60,
		}, gui) :: TextLabel
		local titleStroke = make("UIStroke", { Color = crate.Color:Lerp(C(0, 0, 0), 0.6), Thickness = 2, Transparency = 1 }, title) :: UIStroke
		local titleScale = make("UIScale", { Scale = uiScale() * 1.25 }, title) :: UIScale
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.45, 56),
			Size = UDim2.fromOffset(0, 3),
			BackgroundColor3 = crate.Color:Lerp(WHITE, 0.4),
			BorderSizePixel = 0,
			ZIndex = 61,
		}, gui) :: Frame
		local lineGlow = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.45, 56),
			Size = UDim2.fromOffset(0, 14),
			BackgroundColor3 = crate.Color,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			ZIndex = 60,
		}, gui) :: Frame
		corner(lineGlow, UDim.new(1, 0))
		for _, f in { line, lineGlow } do
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, f)
		end
		sound("CrateSting")
		tween(title, 0.4, { TextTransparency = 0 })
		tween(titleStroke, 0.4, { Transparency = 0.2 })
		tween(titleScale, 0.6, { Scale = uiScale() }, Enum.EasingStyle.Back)
		local lineWidth = 620 * uiScale()
		tween(line, 0.6, { Size = UDim2.fromOffset(lineWidth, 3) }, Enum.EasingStyle.Quart)
		tween(lineGlow, 0.7, { Size = UDim2.fromOffset(lineWidth * 1.05, 14) }, Enum.EasingStyle.Quart)

		-- 2. La arena se arma mientras está negro
		local built = buildArena(origin, crate)
		arena = built
		local top = built.top
		fixedCF = CFrame.lookAt(origin + Vector3.new(0, 8, 23), top + Vector3.new(0, 1.8, 0))
		camCF = fixedCF
		camMode = "fixed"
		fov = 70
		camera.FieldOfView = 70
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, onFrame)
		if not pause(1.3) then return end
		tween(title, 0.35, { TextTransparency = 1 })
		tween(titleStroke, 0.35, { Transparency = 1 })
		tween(line, 0.35, { BackgroundTransparency = 1 })
		tween(lineGlow, 0.35, { BackgroundTransparency = 1 })
		tween(black, 0.7, { BackgroundTransparency = 1 })
		tween(vignette, 0.7, { BackgroundTransparency = 0 })
		if not pause(0.35) then return end
		title:Destroy()
		line:Destroy()
		lineGlow:Destroy()

		-- 3. Cae la caja
		local chest = CrateModels.crate(crate)
		chest:ScaleTo(1.3)
		local rest = CFrame.lookAt(top, top + Vector3.new(0, 0, 1)) -- de frente a la cámara
		chest:PivotTo(rest * CFrame.new(0, 16, 0))
		chest.Parent = built.folder
		local glowParts: { BasePart } = {}
		for _, d in chest:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Glow" then
				table.insert(glowParts, d)
			end
		end
		local chestLight = Instance.new("PointLight")
		chestLight.Color = crate.Color
		chestLight.Range = 10
		chestLight.Brightness = 1
		chestLight.Parent = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart", true)
		if not over(0.55, function(a)
			chest:PivotTo(rest * CFrame.new(0, 16 * (1 - bounceOut(a)), 0))
		end) then return end
		sound("CrateThud")
		shake = 0.8
		burst(built.folder, top, C(150, 120, 100), 25, 10, 0.5)

		-- 4. Tiembla y brilla cada vez más
		if not pause(0.35) then return end
		local sparkPart = part(built.folder, "Sparks", Vector3.new(4, 3, 3), rest * CFrame.new(0, 2.4, 0), WHITE)
		sparkPart.Transparency = 1
		local sparks = CrateModels.embers(sparkPart, crate.Color:Lerp(WHITE, 0.4), 0, 60)
		sparks.Speed = NumberRange.new(4, 10)
		local tension = sound("CrateTension")
		if tension then
			tension.Looped = true
		end
		local startCF = fixedCF
		local closeCF = CFrame.lookAt(origin + Vector3.new(0, 6.5, 15), top + Vector3.new(0, 2, 0))
		if not over(Cfg.ShakeTime, function(a)
			local i = a ^ 1.6
			local t = os.clock() * 31
			local jitter = CFrame.new(math.noise(t, 1) * 0.3 * i, math.abs(math.noise(t, 5)) * 0.25 * i, math.noise(t, 9) * 0.3 * i)
				* CFrame.Angles(math.noise(t, 2) * 0.16 * i, math.noise(t, 4) * 0.1 * i, math.noise(t, 6) * 0.16 * i)
			chest:PivotTo(rest * jitter)
			chestLight.Brightness = 1 + 11 * i
			chestLight.Range = 10 + 24 * i
			for _, g in glowParts do
				g.Color = crate.Color:Lerp(WHITE, i * 0.75)
			end
			sparks.Rate = 4 + 110 * i
			if tension then
				tension.PlaybackSpeed = 0.6 + 1.2 * i
				tension.Volume = (0.3 + 0.5 * i) * (Sounds.MasterVolume or 1)
			end
			shakeHold = 0.45 * i
			fixedCF = startCF:Lerp(closeCF, a * a)
			fov = 70 - 10 * a
		end) then return end

		-- Explota
		if tension then
			tension:Destroy()
		end
		shakeHold = 0
		shake = 2.2
		sound("CrateBoom")
		flash.BackgroundColor3 = WHITE
		flash.BackgroundTransparency = 0
		tween(flash, 0.9, { BackgroundTransparency = 1 })
		burst(built.folder, top + Vector3.new(0, 2, 0), crate.Color, 140, 45, 1)
		burst(built.folder, top + Vector3.new(0, 2, 0), C(255, 140, 40), 60, 25, 1.6)
		local wave = part(built.folder, "Shockwave", Vector3.new(0.2, 2, 2), CFrame.new(top + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), crate.Color, Enum.Material.Neon)
		wave.Shape = Enum.PartType.Cylinder
		wave.CastShadow = false
		tween(wave, 0.7, { Size = Vector3.new(0.2, 46, 46), Transparency = 1 })
		-- Astillas que salen volando
		local debris = {}
		local rng = Random.new()
		for _ = 1, 12 do
			local d = part(built.folder, "Debris", Vector3.new(rng:NextNumber(0.4, 1.2), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.8, 2)), CFrame.new(top + Vector3.new(0, 2, 0)), if rng:NextNumber() < 0.7 then crate.Dark else crate.Color, Enum.Material.WoodPlanks)
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.5, 1.4), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(14, 26)
			table.insert(debris, { part = d, vel = dir, spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)) })
		end
		chest:Destroy()
		sparkPart:Destroy()
		local boomLight = Instance.new("PointLight")
		boomLight.Color = crate.Color
		boomLight.Range = 40
		boomLight.Brightness = 14
		boomLight.Parent = wave
		task.spawn(function()
			local last = os.clock()
			over(1.4, function(a)
				local now = os.clock()
				local dt = now - last
				last = now
				for _, d in debris do
					d.vel += Vector3.new(0, -50 * dt, 0)
					local cf = d.part.CFrame
					d.part.CFrame = (cf + d.vel * dt) * CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt)
					d.part.Transparency = math.max(0, (a - 0.6) / 0.4)
				end
				boomLight.Brightness = 14 * (1 - a)
			end)
			for _, d in debris do
				d.part:Destroy()
			end
		end)

		-- 5. Los premios posibles, en círculo
		if not pause(0.45) then return end
		local rates = Crates.rates(crate)
		local pool: { string } = {}
		for _, r in rates do
			table.insert(pool, r.Prize)
		end
		local found = table.find(pool, prize.Id)
		if not found then
			table.insert(pool, prize.Id)
		end
		local winnerIndex: number = found or #pool
		local n = #pool
		local radius = math.max(12, n * 1.9)
		orbitRadius = radius + 14
		orbitHeight = 9
		-- La cámara arranca la órbita desde donde está
		local rel = camCF.Position - origin
		orbitAngle = math.atan2(rel.Z, rel.X)
		camSharp = 2.2
		camMode = "orbit"
		fov = 68
		local startAngle = orbitAngle -- el primero queda de frente a la cámara
		for i, id in pool do
			local def = CrateItems.ById[id]
			local r = CrateItems.rarity(def.Rarity)
			local a = startAngle + (i - 1) / n * math.pi * 2
			local base = origin + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			local pedTop = CFrame.new(base + Vector3.new(0, 1, 0))
			CrateModels.hex(built.folder, "MiniPedestal", pedTop, 2.4, 1, C(32, 26, 30), Enum.Material.Slate)
			local ringColor = r.Color:Lerp(C(0, 0, 0), 0.15)
			local rims = CrateModels.hexRim(built.folder, pedTop, 2.4, 0.3, 0.2, ringColor)
			local disc = part(built.folder, "Disc", Vector3.new(0.1, 3.6, 3.6), pedTop * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)), r.Color, Enum.Material.Neon)
			disc.Shape = Enum.PartType.Cylinder
			disc.Transparency = 0.55
			disc.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = r.Color
			light.Range = 8
			light.Brightness = 0.7
			light.Parent = disc
			local model = CrateModels.prize(id)
			local height = math.max(CrateModels.height(model), 0.5)
			local baseScale = 4.4 / height
			model:ScaleTo(0.01)
			model:PivotTo(pedTop)
			model.Parent = built.folder
			-- El cartel va en una pieza sin girar (el disco está girado y movería el desplazamiento)
			local labelAnchor = part(built.folder, "LabelAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(base + Vector3.new(0, 1, 0)), WHITE)
			labelAnchor.Transparency = 1
			local label = make("BillboardGui", {
				Size = UDim2.fromOffset(170, 28),
				StudsOffsetWorldSpace = Vector3.new(0, 6.2, 0),
				LightInfluence = 0,
				MaxDistance = 200,
			}, labelAnchor) :: BillboardGui
			make("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Text = def.Name,
				TextSize = 18,
				TextColor3 = r.Color,
				TextStrokeTransparency = 0.3,
			}, label)
			local it: Item = {
				id = id,
				model = model,
				base = base + Vector3.new(0, 1, 0),
				baseScale = baseScale,
				lastScale = 0.01,
				pop = 0,
				pulse = 0,
				sink = 0,
				spin = 0,
				color = ringColor,
				rims = rims,
				disc = disc,
				light = light,
				label = label,
			}
			table.insert(items, it)
			sound("CratePop", 0.9 + i * 0.07)
			task.spawn(over, 0.4, function(x)
				it.pop = x
			end)
			if not pause(0.09) then return end
		end
		if not pause(0.7) then return end

		-- 6. Ruleta: cada vez más lento hasta frenar en el ganador
		local needle = part(built.folder, "Needle", Vector3.new(0.35, 0.15, radius - 3.5), CFrame.new(top), WHITE, Enum.Material.Neon)
		needle.CastShadow = false
		local steps = Cfg.RouletteLaps * n + ((winnerIndex - 1) % n)
		for k = 0, steps do
			local idx = (k % n) + 1
			local it = items[idx]
			it.pulse = 1
			local target = Vector3.new(it.base.X, top.Y + 0.1, it.base.Z)
			local from = Vector3.new(top.X, top.Y + 0.1, top.Z)
			local dir = target - from
			needle.CFrame = CFrame.lookAt(from + dir.Unit * (1.75 + (radius - 3.5) / 2), target)
			needle.Color = it.color:Lerp(WHITE, 0.4)
			local progress = k / math.max(steps, 1)
			sound("CrateTick", 0.9 + progress * 0.5)
			if k < steps then
				local delay = Cfg.RouletteFast + (Cfg.RouletteSlow - Cfg.RouletteFast) * progress ^ 3
				if not pause(delay) then return end
			end
		end
		local winner = items[winnerIndex]
		-- El ganador queda encendido un instante (suspenso)
		for _ = 1, 3 do
			winner.pulse = 1
			if not pause(0.16) then return end
		end
		needle:Destroy()

		-- 7. Reveal
		for _, it in items do
			if it ~= winner then
				it.label.Enabled = false
				local dark = it.color:Lerp(C(0, 0, 0), 0.75)
				task.spawn(over, 0.6, function(x)
					it.sink = x
					it.light.Brightness = 0.7 * (1 - x)
					it.color = it.color:Lerp(dark, x)
				end)
			end
		end
		winner.label.Enabled = false
		sound("CrateWhoosh")
		local startBase = winner.base
		local endBase = top
		local winScale = winner.baseScale * 1.5
		local fromScale = winner.baseScale
		local toCam = Vector3.new(camCF.Position.X - origin.X, 0, camCF.Position.Z - origin.Z)
		local camDir = if toCam.Magnitude > 0.01 then toCam.Unit else Vector3.new(0, 0, 1)
		focusCF = CFrame.lookAt(origin + camDir * 17 + Vector3.new(0, 5.5, 0), top + Vector3.new(0, 1.6, 0))
		camSharp = 2.6
		camMode = "focus"
		fov = 62
		if not over(0.9, function(x)
			local e = 1 - (1 - x) ^ 3
			winner.base = startBase:Lerp(endBase, e) + Vector3.new(0, math.sin(math.pi * x) * 5, 0)
			winner.baseScale = fromScale + (winScale - fromScale) * e
			winner.pulse = math.max(winner.pulse, 0.3)
		end) then return end
		winner.base = endBase
		winner.baseScale = winScale
		-- Haz de luz y partículas del color de la rareza
		local color = rarity.Color
		local beamWidth = if big then 7 else 4
		local beam = part(built.folder, "Beam", Vector3.new(220, 0.2, 0.2), CFrame.new(top + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon)
		beam.Shape = Enum.PartType.Cylinder
		beam.Transparency = 0.45
		beam.CastShadow = false
		local core = part(built.folder, "BeamCore", Vector3.new(220, 0.1, 0.1), beam.CFrame, WHITE, Enum.Material.Neon)
		core.Shape = Enum.PartType.Cylinder
		core.Transparency = 0.35
		core.CastShadow = false
		tween(beam, 0.35, { Size = Vector3.new(220, beamWidth, beamWidth) }, Enum.EasingStyle.Back)
		tween(core, 0.35, { Size = Vector3.new(220, beamWidth * 0.35, beamWidth * 0.35) }, Enum.EasingStyle.Back)
		-- Después del golpe el haz se aclara y se ensancha: que se vea el premio adentro
		task.delay(0.7, function()
			if alive and beam.Parent then
				tween(beam, 0.8, { Transparency = 0.82, Size = Vector3.new(220, beamWidth * 1.6, beamWidth * 1.6) })
				tween(core, 0.8, { Transparency = 0.95 })
			end
		end)
		local beamLight = Instance.new("PointLight")
		beamLight.Color = color
		beamLight.Range = if big then 45 else 28
		beamLight.Brightness = if big then 9 else 5
		beamLight.Parent = core
		local glowPart = part(built.folder, "RevealGlow", Vector3.new(4, 1, 4), CFrame.new(top + Vector3.new(0, 0.5, 0)), WHITE)
		glowPart.Transparency = 1
		local rise = CrateModels.embers(glowPart, color, if big then 120 else 50, 20)
		rise.Speed = NumberRange.new(6, if big then 18 else 12)
		rise.Lifetime = NumberRange.new(1.2, 2.4)
		rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if big then 0.6 else 0.4), NumberSequenceKeypoint.new(1, 0) })
		burst(built.folder, top + Vector3.new(0, 2.5, 0), color, if big then 220 else 90, if big then 50 else 30, if big then 1.4 else 0.9)
		for _, rim in built.pedestalRims do
			rim.Color = color:Lerp(C(0, 0, 0), 0.3)
		end
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = if big then 0.1 else 0.55
		tween(flash, if big then 1.1 else 0.6, { BackgroundTransparency = 1 })
		sound("CrateReveal")
		if big then
			sound("CrateRevealBig")
			shake = 3
			for w = 0, 1 do
				task.delay(w * 0.18, function()
					if not alive or not arena then
						return
					end
					local ring = part(arena.folder, "Shockwave", Vector3.new(0.2, 3, 3), CFrame.new(top + Vector3.new(0, 0.3 + w, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon)
					ring.Shape = Enum.PartType.Cylinder
					ring.CastShadow = false
					tween(ring, 0.9, { Size = Vector3.new(0.2, 70, 70), Transparency = 1 })
				end)
			end
			for _, torch in built.torches do
				tween(torch.light, 0.4, { Brightness = 5, Range = 26, Color = color })
				torch.fire.Size = 9
				torch.fire.Color = color
			end
			for _, g in built.archGlows do
				tween(g, 0.6, { Color = color })
			end
			tween(built.spot, 0.4, { Color = color, Brightness = 8 })
		else
			shake = 0.6
		end
		-- El premio gira despacio sobre el pedestal
		table.insert(connections, RunService.RenderStepped:Connect(function(dt: number)
			winner.spin += dt * 0.9
		end))
		if not pause(if big then 1.1 else 0.8) then return end
		finalCard()
	end)
end

return CrateCinematic
