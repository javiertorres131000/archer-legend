-- Atmosphere (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Atmosphere
-- Luz de la arena: de día, con un bloom suave y algo más de saturación, apenas teñida con el
-- color del capítulo. En el lobby vuelve la luz normal.
-- Los cambios de Lighting hechos en el cliente son locales: cada jugador ve los suyos.
-- Valores en Config.Effects. En calidad baja no hay bloom ni rayos de sol.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))
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

local function chapterAccent(): Color3
	local ch = Chapters[gameState:GetAttribute("Chapter") or 1]
	return ch and ch.Accent or Color3.new(1, 1, 1)
end

local function apply()
	local inMatch = player:GetAttribute("InMatch") == true
	local info = TweenInfo.new(0.8)
	if inMatch then
		bloom.Enabled = not low
		color.Enabled = true
		TweenService:Create(haze, info, { Density = Fx.Haze }):Play()
		color.TintColor = Color3.new(1, 1, 1):Lerp(chapterAccent(), Fx.TintStrength)
		TweenService:Create(Lighting, info, {
			ClockTime = Fx.ArenaClockTime,
			Ambient = Fx.ArenaAmbient,
			OutdoorAmbient = Fx.ArenaAmbient,
			Brightness = Fx.ArenaBrightness,
		}):Play()
	else
		bloom.Enabled = false
		color.Enabled = false
		TweenService:Create(haze, info, { Density = 0 }):Play()
		TweenService:Create(Lighting, info, saved):Play()
	end
end

player:GetAttributeChangedSignal("InMatch"):Connect(apply)
gameState:GetAttributeChangedSignal("Chapter"):Connect(apply)
apply()
