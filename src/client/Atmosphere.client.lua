-- Atmosphere (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Atmosphere
-- Luz de la arena: de día, con un bloom suave y algo más de saturación, apenas teñida con el
-- color del capítulo. En el lobby vuelve la luz normal.
-- En la plaza de las cajas (y durante la animación de apertura, atributo "Cinematic" del
-- jugador) la luz es volcánica: cielo rojizo, niebla cálida y bloom (Config.Crates.Lighting).
-- Los cambios de Lighting hechos en el cliente son locales: cada jugador ve los suyos.
-- Valores en Config.Effects. En calidad baja no hay bloom ni rayos de sol.
-- Con Config.Effects.ArenaLighting = "Place" no toca nada: usa la luz armada en Studio (Lighting).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local CratePlazaLayout = require(Shared:WaitForChild("CratePlazaLayout"))
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer
local Fx = Config.Effects
local low = FxQuality.isLow()

-- Cómo estaba la luz (para volver en el lobby)
local saved = {
	ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
}

local bloom = Instance.new("BloomEffect")
bloom.Name = "ArenaBloom"
bloom.Enabled = false
bloom.Intensity = Fx.Bloom.Intensity
bloom.Size = Fx.Bloom.Size
bloom.Threshold = Fx.Bloom.Threshold
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Name = "ArenaColor"
color.Enabled = false
color.Saturation = Fx.Saturation
color.Contrast = Fx.Contrast
color.Parent = Lighting

-- Bruma a lo lejos: con el mapa grande da profundidad
local haze = Instance.new("Atmosphere")
haze.Name = "ArenaHaze"
haze.Density = 0
haze.Offset = 0.1
haze.Color = Color3.fromRGB(200, 215, 230)
haze.Decay = Color3.fromRGB(120, 140, 160)
haze.Glare = 0
haze.Haze = 1
haze.Parent = Lighting

local function currentChapter(): any
	return Chapters[gameState:GetAttribute("Chapter") or 1]
end

local function chapterAccent(): Color3
	local ch = currentChapter()
	return ch and ch.Accent or Color3.new(1, 1, 1)
end

-- Clima del capítulo (Chapters › Lighting.Weather): partículas en una caja que sigue a la cámara
local RunService = game:GetService("RunService")
local weatherPart: Part? = nil
local weatherConn: RBXScriptConnection? = nil

local function setWeather(kind: string?)
	if weatherConn then
		weatherConn:Disconnect()
		weatherConn = nil
	end
	if weatherPart then
		weatherPart:Destroy()
		weatherPart = nil
	end
	if not kind or low then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Weather"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(90, 1, 90)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.LightInfluence = 1
	if kind == "Snow" then
		e.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
		e.Size = NumberSequence.new(0.35)
		e.Rate = 140
		e.Lifetime = NumberRange.new(5, 7)
		e.Speed = NumberRange.new(6, 9)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(15, 15)
		e.Acceleration = Vector3.new(2, 0, 1)
		e.Transparency = NumberSequence.new(0.1)
	else -- "Sand": ráfagas de arena casi horizontales
		e.Color = ColorSequence.new(Color3.fromRGB(230, 195, 140))
		e.Size = NumberSequence.new(0.25)
		e.Rate = 180
		e.Lifetime = NumberRange.new(2, 3)
		e.Speed = NumberRange.new(25, 35)
		e.EmissionDirection = Enum.NormalId.Right
		e.SpreadAngle = Vector2.new(8, 25)
		e.Acceleration = Vector3.new(0, -3, 0)
		e.Transparency = NumberSequence.new(0.35)
	end
	e.Parent = part
	part.Parent = workspace
	weatherPart = part
	weatherConn = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and weatherPart then
			local p = camera.CFrame.Position
			weatherPart.CFrame = CFrame.new(p.X - (if kind == "Sand" then 40 else 0), p.Y + 25, p.Z)
		end
	end)
end

local plaza = if Config.Crates.Enabled then CratePlazaLayout.get() else nil
local Volcanic = Config.Crates.Lighting

-- ¿Está en la plaza de las cajas (o mirando la apertura de una)?
local function inVolcano(): boolean
	if player:GetAttribute("Cinematic") == true then
		return true
	end
	if not plaza or player:GetAttribute("InMatch") == true then
		return false
	end
	-- Con la Ciudadela, el patio de las cajas es parte del castillo: luz normal
	if workspace:FindFirstChild("Ciudadela") then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and CratePlazaLayout.contains(plaza, root.Position, 2)
end

local volcanic = false

-- Cielo del volcán: mientras dura, se guardan aparte los Sky y las otras Atmosphere del place
-- (si hay dos Atmosphere Roblox usa una sola, y un skybox oscuro taparía el atardecer rojizo).
-- Al salir vuelven a Lighting tal cual estaban. Todo es local: no cambia el place.
local stashed: { Instance } = {}
local volcanicSky: Sky? = nil

local function swapSky(on: boolean)
	if on and not volcanicSky then
		for _, c in Lighting:GetChildren() do
			if c:IsA("Sky") or (c:IsA("Atmosphere") and c ~= haze) then
				table.insert(stashed, c)
				c.Parent = nil
			end
		end
		local sky = Instance.new("Sky")
		sky.Name = "VolcanicSky"
		sky.CelestialBodiesShown = false
		sky.StarCount = 0
		sky.Parent = Lighting
		volcanicSky = sky
	elseif not on and volcanicSky then
		volcanicSky:Destroy()
		volcanicSky = nil
		for _, c in stashed do
			c.Parent = Lighting
		end
		table.clear(stashed)
	end
end

local function apply()
	volcanic = inVolcano()
	swapSky(volcanic)
	if volcanic then
		setWeather(nil)
		local info = TweenInfo.new(1.2)
		haze.Parent = Lighting
		bloom.Enabled = not low
		bloom.Intensity = Volcanic.BloomIntensity
		bloom.Size = Volcanic.BloomSize
		bloom.Threshold = Volcanic.BloomThreshold
		color.Enabled = true
		color.TintColor = Volcanic.Tint
		color.Saturation = Volcanic.Saturation
		color.Contrast = Volcanic.Contrast
		TweenService:Create(haze, info, {
			Density = Volcanic.HazeDensity,
			Color = Volcanic.HazeColor,
			Decay = Volcanic.HazeDecay,
			Glare = Volcanic.HazeGlare,
			Haze = Volcanic.Haze,
		}):Play()
		TweenService:Create(Lighting, info, {
			ClockTime = Volcanic.ClockTime,
			Ambient = Volcanic.Ambient,
			OutdoorAmbient = Volcanic.OutdoorAmbient,
			Brightness = Volcanic.Brightness,
		}):Play()
		return
	end
	-- Fuera del volcán: los valores de siempre
	bloom.Intensity = Fx.Bloom.Intensity
	bloom.Size = Fx.Bloom.Size
	bloom.Threshold = Fx.Bloom.Threshold
	color.Saturation = Fx.Saturation
	color.Contrast = Fx.Contrast
	haze.Color = Color3.fromRGB(200, 215, 230)
	haze.Decay = Color3.fromRGB(120, 140, 160)
	haze.Glare = 0
	haze.Haze = 1
	-- Con "Place" manda la luz armada en Studio (Lighting): no se toca nada
	if Fx.ArenaLighting == "Place" then
		bloom.Enabled = false
		color.Enabled = false
		haze.Parent = nil
		return
	end
	local inMatch = player:GetAttribute("InMatch") == true
	local info = TweenInfo.new(0.8)
	if inMatch then
		-- Luz propia del capítulo (Glaciar, Desierto...) o la de siempre
		local ch = currentChapter()
		local L = ch and ch.Lighting or {}
		bloom.Enabled = not low
		color.Enabled = true
		if L.HazeColor then
			haze.Color = L.HazeColor
			haze.Decay = L.HazeColor:Lerp(Color3.new(0, 0, 0), 0.3)
		end
		TweenService:Create(haze, info, { Density = L.HazeDensity or Fx.Haze }):Play()
		color.TintColor = Color3.new(1, 1, 1):Lerp(chapterAccent(), Fx.TintStrength)
		TweenService:Create(Lighting, info, {
			ClockTime = L.ClockTime or Fx.ArenaClockTime,
			Ambient = L.Ambient or Fx.ArenaAmbient,
			OutdoorAmbient = L.Ambient or Fx.ArenaAmbient,
			Brightness = L.Brightness or Fx.ArenaBrightness,
		}):Play()
		setWeather(L.Weather)
	else
		setWeather(nil)
		bloom.Enabled = false
		color.Enabled = false
		TweenService:Create(haze, info, { Density = 0 }):Play()
		TweenService:Create(Lighting, info, saved):Play()
	end
end

player:GetAttributeChangedSignal("InMatch"):Connect(apply)
player:GetAttributeChangedSignal("Cinematic"):Connect(apply)
-- Entrar o salir de la plaza (se revisa 4 veces por segundo)
task.spawn(function()
	while true do
		task.wait(0.25)
		if inVolcano() ~= volcanic then
			apply()
		end
	end
end)
gameState:GetAttributeChangedSignal("Chapter"):Connect(apply)
apply()
