-- SkinAura (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > SkinAura
-- Aura de cuerpo entero según el traje que tiene puesto cada jugador (atributo CrateLook del
-- personaje → Shared/SkinFx.Auras). Solo visual, lo dibuja cada cliente para todos.
-- No se ve en tu propia primera persona (taparía la vista) ni durante las cinemáticas propias.
-- Si el traje tiene aura, reemplaza al aura de cuerpo del arma (AnimeFx la saltea).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinFx = require(Shared:WaitForChild("SkinFx"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))

local player = Players.LocalPlayer
local low = FxQuality.isLow()
local TAG = "SkinAura"

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local PARTS = { "UpperTorso", "Torso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function seq(a: number, b: number, c: number?): NumberSequence
	if c then
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, b), NumberSequenceKeypoint.new(1, c) })
	end
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function makeEmitter(part: BasePart, layer: any, big: boolean): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = TAG
	local s = if big then 1.3 else 0.85
	local rate = (layer.Rate or 10) * (if big then 1 else 0.5) * (if low then 0.35 else 1)
	e.Rate = rate
	e.Color = ColorSequence.new(layer.A, layer.B)
	e.LightInfluence = 0
	if layer.Kind == "Flame" then
		e.Texture = FIRE
		e.LightEmission = 1
		e.Size = seq(1.2 * s, 0.2 * s)
		e.Transparency = seq(0.2, 1)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.Speed = NumberRange.new(1.5, 4)
		e.Acceleration = Vector3.new(0, 12, 0)
		e.SpreadAngle = Vector2.new(60, 60)
		e.RotSpeed = NumberRange.new(-90, 90)
	elseif layer.Kind == "Spark" then
		e.Texture = SPARK
		e.LightEmission = 1
		e.Size = seq(0, 0.35 * s, 0)
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 2, 0)
	elseif layer.Kind == "Smoke" then
		e.Texture = SMOKE
		e.LightEmission = 0
		e.Size = seq(1 * s, 3 * s)
		e.Transparency = seq(0.65, 1)
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.SpreadAngle = Vector2.new(60, 60)
		e.RotSpeed = NumberRange.new(-30, 30)
	elseif layer.Kind == "Holy" then
		e.Texture = SPARK
		e.LightEmission = 1
		e.Size = seq(0.2 * s, 0.6 * s, 0)
		e.Transparency = seq(0, 0.2, 1)
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(2, 4)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0, 3, 0)
	else -- Void: humo oscuro que entra hacia el cuerpo
		e.Texture = SMOKE
		e.LightEmission = 0.4
		e.Size = seq(2.5 * s, 0.4 * s)
		e.Transparency = seq(1, 0.35, 1)
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(-5, -3)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.RotSpeed = NumberRange.new(-60, 60)
	end
	e.Parent = part
	return e
end

local function clear(character: Model)
	for _, d in character:GetDescendants() do
		if d.Name == TAG then
			d:Destroy()
		end
	end
end

local function apply(character: Model, aura: any)
	clear(character)
	if not aura then
		return
	end
	for _, name in PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local big = name == "UpperTorso" or name == "Torso"
			makeEmitter(part, aura, big)
			if aura.Extra and (big or not low) then
				makeEmitter(part, aura.Extra, big)
			end
		end
	end
	-- Luz del color del traje en el torso (los de luz y fuego brillan)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and (aura.Kind == "Holy" or aura.Kind == "Flame") and not low then
		local light = Instance.new("PointLight")
		light.Name = TAG
		light.Color = aura.B
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = torso
	end
end

local current: { [Model]: string } = {}

local function wanted(p: Player, character: Model): string
	if p == player and ((player:GetAttribute("CameraView") == "FirstPerson" and player:GetAttribute("InMatch") == true) or player:GetAttribute("Cinematic") == true) then
		return ""
	end
	local id = character:GetAttribute("CrateLook")
	return if type(id) == "string" and SkinFx.aura(id) then id else ""
end

task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local character = p.Character
			if character then
				local want = wanted(p, character)
				if current[character] ~= want then
					current[character] = want
					apply(character, if want ~= "" then SkinFx.aura(want) else nil)
				end
			end
		end
		for character in current do
			if not character.Parent then
				current[character] = nil
			end
		end
		task.wait(0.5)
	end
end)
