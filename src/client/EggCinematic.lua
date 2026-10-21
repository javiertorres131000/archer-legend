--!strict
-- EggCinematic (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > EggCinematic
-- Animación de abrir un huevo de mascotas (Crates.lua, Type = "Egg"). Solo visual y solo para
-- quien lo abre: la mascota ya la decidió el servidor (CrateService) antes de arrancar.
-- Es a pantalla completa (interfaz + vistas 3D del huevo y la mascota), así se ve igual en
-- cualquier lugar y cuesta poco en el celular. Secuencia (como un "summon" gacha):
--   1. Fundido a negro. Aparece el huevo ornamentado con el nombre arriba.
--   2. El huevo se sacude cada vez más fuerte, con destellos alrededor. Si lo que viene es Epic o
--      mejor, cartel "!! RARE SIGNAL DETECTED !!" (y desde Legendary, rayos y destellos arcoíris).
--   3. Se rompe: flash del color de la rareza y la cáscara vuela en pedazos.
--   4. Se abre una rendija de luz vertical que crece hasta ser una columna con rayos en estrella
--      y la SILUETA negra de la mascota adentro.
--   5. Reveal: flash, fondo del color de la rareza, anillo que se expande y la mascota pasa de
--      silueta a color, girando. Nombre, rareza, bono de daño y "Continue".
-- Al terminar (o si empieza una partida) se desconecta y borra todo.

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

local player = Players.LocalPlayer
local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local FREEZE = "EggCinematicFreeze"
local KIND_NAMES = { Unit = "Unidad", Pet = "Mascota", Character = "Personaje" }

export type Result = { Prize: string, Count: number?, New: boolean? }

local EggCinematic = {}

local playing = false

function EggCinematic.isPlaying(): boolean
	return playing
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

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function corner(parent: Instance, radius: UDim?)
	make("UICorner", { CornerRadius = radius or UDim.new(1, 0) }, parent)
end

local function screenScale(): number
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.4)
end

-- Vista 3D de un modelo (para el huevo y la mascota)
local function view(parent: Instance, model: Model, size: UDim2, fov: number): (ViewportFrame, Camera, number)
	local vf = make("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundTransparency = 1,
		Ambient = C(200, 190, 200),
		LightColor = C(255, 245, 235),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
	}, parent) :: ViewportFrame
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, vf)
	model:PivotTo(CFrame.new())
	model.Parent = vf
	local cam = make("Camera", { FieldOfView = fov }, vf) :: Camera
	vf.CurrentCamera = cam
	local height = math.max(CrateModels.height(model), 0.5)
	local distance = height * 0.62 / math.tan(math.rad(fov / 2))
	cam.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.5, -distance), Vector3.new(0, height * 0.5, 0))
	return vf, cam, height
end

function EggCinematic.play(crate: Crates.Crate, result: Result, onDone: (() -> ())?)
	if playing then
		return
	end
	local prize = CrateItems.ById[result.Prize]
	if not prize then
		return
	end
	playing = true
	local rarity = CrateItems.rarity(prize.Rarity)
	local color = rarity.Color
	local tease = rarity.Order >= 4 -- Epic o mejor: "RARE SIGNAL"
	local big = rarity.Order >= CrateItems.BigRevealFrom -- Legendary o mejor: más fuerte
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local alive = true
	local finished = false
	local connections: { RBXScriptConnection } = {}
	local hiddenGuis: { ScreenGui } = {}
	local soundFolder = Instance.new("Folder")
	soundFolder.Name = "EggCinematicSounds"
	soundFolder.Parent = SoundService

	local function sound(name: string, pitch: number?, volume: number?)
		local def = (Sounds.List :: any)[name]
		if not def then
			return
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
	end

	local gui = make("ScreenGui", {
		Name = "EggCinematic",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	-- Todo va dentro de "stage" (se sacude entero en los golpes fuertes)
	local stage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui) :: Frame
	local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1 }, stage) :: Frame
	local bgGradient = make("UIGradient", {
		Color = ColorSequence.new(C(40, 16, 70), C(10, 6, 25)),
		Rotation = 90,
	}, bg) :: UIGradient
	local effects = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, stage) :: Frame
	local black = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 }, gui) :: Frame
	local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 40 }, gui) :: Frame
	stage.Visible = false

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

	local function cleanup()
		if not alive then
			return
		end
		alive = false
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
		soundFolder:Destroy()
		for _, g in hiddenGuis do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		freeze(false)
	end

	table.insert(connections, player:GetAttributeChangedSignal("InMatch"):Connect(function()
		if player:GetAttribute("InMatch") == true then
			cleanup()
			gui:Destroy()
			playing = false
		end
	end))

	local function pause(t: number): boolean
		task.wait(t)
		return alive
	end

	-- Animación de cada frame: huevo que se sacude, rayos que giran, mascota que gira
	local clock = 0
	local shakeEgg = 0 -- 0..1 sacudón del huevo
	local shakeStage = 0 -- sacudón de toda la pantalla (golpes fuertes)
	local egg: Model? = nil
	local eggCam: Camera? = nil
	local rays: Frame? = nil
	local pet: Model? = nil
	local petFrame: ViewportFrame? = nil
	local petSpin = 0
	local petBob = 0
	table.insert(connections, RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		if egg then
			local s = shakeEgg
			local t = clock * 26
			egg:PivotTo(CFrame.Angles(math.noise(t, 1.1) * 0.35 * s, clock * 0.8 + math.noise(t, 2.2) * 0.4 * s, math.noise(t, 3.3) * 0.45 * s) + Vector3.new(math.noise(t, 4.4) * 0.3 * s, math.abs(math.noise(t, 5.5)) * 0.25 * s, 0))
		end
		if rays then
			rays.Rotation += dt * 25
		end
		if pet then
			petSpin += dt * (if petBob > 0 then 0.9 else 0)
			pet:PivotTo(CFrame.Angles(0, petSpin, 0) + Vector3.new(0, math.sin(clock * 2.4) * 0.08 * petBob, 0))
		end
		shakeStage *= math.exp(-dt * 6)
		local k = shakeStage * 14
		stage.Position = UDim2.fromOffset(math.noise(clock * 30, 7) * k, math.noise(clock * 30, 9) * k)
	end))

	-- Destello que sale del centro y se desvanece (rombo)
	local function sparkle(col: Color3, spread: number, size: number)
		local s = screenScale()
		local a = math.random() * math.pi * 2
		local d = (0.12 + math.random() * spread)
		local spark = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(a) * d * 0.6, 0.5 + math.sin(a) * d),
			Size = UDim2.fromOffset(size * s, size * s),
			Rotation = 45,
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, effects) :: Frame
		local out = d + 0.08
		tween(spark, 0.7, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * out * 0.6, 0.5 + math.sin(a) * out),
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Rotation = 45 + math.random(-90, 90),
		})
		task.delay(0.75, function()
			spark:Destroy()
		end)
	end

	-- Rayo quebrado (líneas blancas) cerca del huevo
	local function lightning()
		local s = screenScale()
		local x = 0.5 + (math.random() - 0.5) * 0.35
		local y = 0.15
		for _ = 1, 6 do
			local nx = x + (math.random() - 0.5) * 0.06
			local ny = y + 0.06 + math.random() * 0.03
			local len = math.sqrt(((nx - x) * 16 / 9) ^ 2 + (ny - y) ^ 2)
			local seg = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((x + nx) / 2, (y + ny) / 2),
				Size = UDim2.new(0, 4 * s, len, 0),
				Rotation = math.deg(math.atan2(-(nx - x) * 16 / 9, ny - y)),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				ZIndex = 7,
			}, effects) :: Frame
			make("UIStroke", { Color = C(170, 230, 255), Thickness = 3 * s, Transparency = 0.3 }, seg)
			tween(seg, 0.35, { BackgroundTransparency = 1 })
			task.delay(0.36, function()
				seg:Destroy()
			end)
			x, y = nx, ny
		end
	end

	local function rainbow(t: number): Color3
		return Color3.fromHSV((t * 0.6) % 1, 0.55, 1)
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		tween(black, 0.3, { BackgroundTransparency = 0 })
		task.wait(0.35)
		cleanup()
		stage:Destroy()
		tween(black, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.45)
		gui:Destroy()
		playing = false
		if onDone then
			onDone()
		end
	end

	local function finalCard()
		local s = screenScale()
		local holder = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 40),
			Size = UDim2.fromOffset(760, 230),
			BackgroundTransparency = 1,
			ZIndex = 20,
		}, stage) :: Frame
		local scale = make("UIScale", { Scale = s * 0.9 }, holder) :: UIScale
		if result.New then
			local badge = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.fromOffset(96, 28),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundColor3 = C(255, 215, 70),
				Font = Enum.Font.GothamBlack,
				Text = "NEW!",
				TextSize = 18,
				TextColor3 = C(60, 30, 0),
				ZIndex = 21,
			}, holder)
			corner(badge)
		end
		local name = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 32),
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = CrateItems.upper(prize.Name),
			TextSize = 56,
			TextColor3 = WHITE,
			ZIndex = 21,
		}, holder) :: TextLabel
		make("UIStroke", { Color = color:Lerp(BLACK, 0.55), Thickness = 4 }, name)
		local bonus = (Config.Crates.PetDamageBonus :: any)[prize.Rarity] or 0
		local detail = if prize.Kind == "Pet"
			then string.format("+%d%% daño", math.floor(bonus * 100 + 0.5))
			else KIND_NAMES[prize.Kind] or prize.Kind
		local sub = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 96),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			RichText = true,
			Text = string.format('<font color="#%s">%s</font>  ·  %s  ·  x%d', color:ToHex(), string.upper(rarity.Name), detail, result.Count or 1),
			TextSize = 26,
			TextColor3 = WHITE,
			ZIndex = 21,
		}, holder) :: TextLabel
		make("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.3 }, sub)
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 142),
			Size = UDim2.fromOffset(240, 58),
			BackgroundColor3 = C(250, 246, 240),
			AutoButtonColor = false,
			Font = Enum.Font.GothamBlack,
			Text = "Continue",
			TextSize = 26,
			TextColor3 = C(30, 20, 20),
			ZIndex = 21,
		}, holder) :: TextButton
		corner(button, UDim.new(0, 14))
		make("UIStroke", { Color = color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
		table.insert(connections, button.Activated:Connect(function()
			task.spawn(finish)
		end))
		table.insert(connections, UserInputService.InputBegan:Connect(function(input)
			local k = input.KeyCode
			if k == Enum.KeyCode.Return or k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA then
				task.spawn(finish)
			end
		end))
		tween(holder, 0.45, { Position = UDim2.new(0.5, 0, 1, -24) }, Enum.EasingStyle.Back)
		-- La mascota sube y se achica un poco para dejar lugar al cartel
		if petFrame then
			tween(petFrame :: ViewportFrame, 0.45, { Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.42, 0.42) })
		end
		scale.Scale = s * 0.75
		tween(scale, 0.45, { Scale = s * 0.9 }, Enum.EasingStyle.Back)
		if prize.Rarity == "Secret" then
			table.insert(connections, RunService.RenderStepped:Connect(function()
				name.TextColor3 = WHITE:Lerp(CrateItems.color("Secret", os.clock()), 0.6)
			end))
		end
	end

	task.spawn(function()
		local s = screenScale()
		-- 1. Negro, se esconden las otras interfaces y aparece el huevo
		freeze(true)
		tween(black, 0.35, { BackgroundTransparency = 0 })
		if not pause(0.4) then return end
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		stage.Visible = true
		local title = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.06),
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = CrateItems.upper(crate.Name),
			TextSize = 52,
			TextColor3 = crate.Color,
			ZIndex = 10,
		}, stage) :: TextLabel
		make("UIStroke", { Color = crate.Color:Lerp(BLACK, 0.7), Thickness = 3 }, title)
		make("UIScale", { Scale = s }, title)
		local eggModel = CrateModels.egg(crate)
		local eggView, cam = view(stage, eggModel, UDim2.fromScale(0.62, 0.62), 32)
		eggView.ZIndex = 3
		egg = eggModel
		eggCam = cam
		local _ = eggCam
		local eggScale = make("UIScale", { Scale = 0.3 }, eggView) :: UIScale
		tween(eggScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(black, 0.45, { BackgroundTransparency = 1 })
		sound("CrateSting")
		if not pause(0.6) then return end

		-- 2. Se sacude cada vez más; el cartel si viene algo bueno
		local banner: TextLabel? = nil
		if tease then
			banner = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.16),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Text = "!! RARE SIGNAL DETECTED !!",
				TextSize = 34,
				TextColor3 = C(255, 220, 80),
				TextTransparency = 1,
				ZIndex = 10,
			}, stage) :: TextLabel
			make("UIStroke", { Color = C(90, 50, 0), Thickness = 3 }, banner :: TextLabel)
			make("UIScale", { Scale = s }, banner :: TextLabel)
		end
		local taps = if big then 6 else 4
		for i = 1, taps do
			local strength = i / taps
			shakeEgg = 0.35 + strength * 0.65
			sound("CrateTick", 0.8 + strength * 0.5, 1.2)
			for _ = 1, if big then 10 else 6 do
				sparkle(if big then rainbow(os.clock() + math.random()) else crate.Color:Lerp(WHITE, 0.4), 0.25, 14 + strength * 10)
			end
			if banner and i == 2 then
				tween(banner :: TextLabel, 0.2, { TextTransparency = 0 })
				sound("CrateSting", 1.4)
			end
			if banner then
				(banner :: TextLabel).TextColor3 = if big then rainbow(os.clock()) else C(255, 220, 80)
			end
			if big and i >= 3 then
				lightning()
				shakeStage = 0.6
			end
			if not pause(0.32) then return end
			shakeEgg = 0.15
			if not pause(0.22 - strength * 0.1) then return end
		end
		shakeEgg = 1
		bgGradient.Color = ColorSequence.new(color:Lerp(BLACK, 0.4), C(10, 6, 25))
		if not pause(0.45) then return end

		-- 3. Se rompe
		sound("CrateBoom")
		flash.BackgroundColor3 = color:Lerp(WHITE, 0.35)
		flash.BackgroundTransparency = 0
		tween(flash, 0.55, { BackgroundTransparency = 1 })
		shakeStage = if big then 1.5 else 0.8
		egg = nil
		eggView:Destroy()
		title:Destroy()
		if banner then
			(banner :: TextLabel):Destroy()
		end
		for _ = 1, 10 do
			local a = math.random() * math.pi * 2
			local shard = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(math.random(18, 40) * s, math.random(28, 60) * s),
				Rotation = math.random(0, 360),
				BackgroundColor3 = if math.random() < 0.6 then crate.Dark else C(255, 200, 70),
				BorderSizePixel = 0,
				ZIndex = 8,
			}, effects) :: Frame
			tween(shard, 0.8, {
				Position = UDim2.fromScale(0.5 + math.cos(a) * 0.55, 0.5 + math.sin(a) * 0.7),
				Rotation = shard.Rotation + math.random(-360, 360),
				BackgroundTransparency = 1,
			})
			task.delay(0.85, function()
				shard:Destroy()
			end)
		end
		bgGradient.Color = ColorSequence.new(C(30, 10, 60), C(5, 3, 15))
		if not pause(0.35) then return end

		-- 4. Rendija de luz que crece hasta columna, con la silueta adentro
		local beam = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 3, 0, 0),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, effects) :: Frame
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.6),
			}),
		}, beam)
		sound("CrateWhoosh", 1.2)
		tween(beam, 0.3, { Size = UDim2.new(0, 3, 1, 0) }, Enum.EasingStyle.Quart)
		if not pause(0.4) then return end
		-- Rayos en estrella detrás
		local rayHolder = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, effects) :: Frame
		-- Cada rayo es una línea que cruza el centro (gira sobre su propio centro = el centro de la pantalla)
		for i = 0, 7 do
			local ray = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(if i % 2 == 0 then 12 * s else 5 * s, 1800 * s),
				Rotation = i * 22.5,
				BackgroundColor3 = color:Lerp(WHITE, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, rayHolder) :: Frame
			make("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, ray)
			tween(ray, 0.4, { BackgroundTransparency = 0.35 })
		end
		rays = rayHolder
		tween(beam, 0.4, { Size = UDim2.new(0.18, 0, 1, 0) }, Enum.EasingStyle.Back)
		-- Silueta de la mascota (negra) dentro de la columna
		local petModel = CrateModels.prize(prize.Id)
		local petView = view(stage, petModel, UDim2.fromScale(0.5, 0.5), 32)
		petView.ZIndex = 6
		petView.ImageColor3 = BLACK
		pet = petModel
		petFrame = petView
		petSpin = 0 -- de frente a la cámara
		local petScale = make("UIScale", { Scale = 0.5 }, petView) :: UIScale
		tween(petScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		if not pause(if big then 1.3 else 0.9) then return end

		-- 5. Reveal
		flash.BackgroundColor3 = WHITE
		flash.BackgroundTransparency = 0
		tween(flash, 0.6, { BackgroundTransparency = 1 })
		sound("CrateReveal")
		if big then
			sound("CrateRevealBig")
			shakeStage = 1.4
		end
		bgGradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.15), color:Lerp(BLACK, 0.45))
		tween(beam, 0.5, { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0) })
		tween(petView, 0.5, { ImageColor3 = WHITE })
		tween(petScale, 0.4, { Scale = 1.15 }, Enum.EasingStyle.Back)
		petBob = 1
		for _, ray in rayHolder:GetChildren() do
			if ray:IsA("Frame") then
				ray.BackgroundColor3 = WHITE
			end
		end
		-- Anillos que se expanden
		for i = 0, (if big then 2 else 1) do
			task.delay(i * 0.18, function()
				if not alive then
					return
				end
				local ring = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.1, 0.1),
					BackgroundTransparency = 1,
					ZIndex = 5,
				}, effects) :: Frame
				make("UIAspectRatioConstraint", { AspectRatio = 1 }, ring)
				corner(ring)
				local stroke = make("UIStroke", { Color = WHITE, Thickness = 10 * s }, ring) :: UIStroke
				tween(ring, 0.9, { Size = UDim2.fromScale(0.9, 0.9) })
				tween(stroke, 0.9, { Transparency = 1, Thickness = 2 })
				task.delay(0.95, function()
					ring:Destroy()
				end)
			end)
		end
		-- Lluvia de destellos
		for _ = 1, if big then 40 else 22 do
			sparkle(if big then rainbow(math.random()) else color:Lerp(WHITE, 0.5), 0.45, 16)
		end
		if not pause(if big then 1 else 0.7) then return end
		finalCard()
	end)
end

return EggCinematic
