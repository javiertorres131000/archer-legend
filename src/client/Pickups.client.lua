-- Pickups (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Pickups
-- Dibuja los orbes de XP y adorna los cofres. Solo visual: quién junta qué lo decide el servidor
-- (Orbs.lua y Chests.lua).
--   · Orbes: bolitas neón que flotan (celeste, verde o violeta según cuánta XP dan). Cuando
--     alguien las junta, vuelan hacia esa persona.
--   · Cofres: luz dorada, un haz de luz hacia el cielo y un cartel visible desde lejos.
--     Al abrirse, explosión dorada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local orbsRemote = remotes:WaitForChild("Orbs") :: RemoteEvent
local chestOpened = remotes:WaitForChild("ChestOpened") :: RemoteEvent

local low = FxQuality.isLow()
local GOLD = Color3.fromRGB(255, 205, 70)

---------------------------------------------------------------------
-- Orbes
---------------------------------------------------------------------
type OrbVisual = {
	part: Part,
	base: Vector3,
	phase: number,
	target: Player?, -- volando hacia este jugador
	flyStart: number,
	from: Vector3,
}
local orbs: { [number]: OrbVisual } = {}
local folder = Instance.new("Folder")
folder.Name = "XPOrbs"
folder.Parent = workspace
local FLY_TIME = 0.25

local function orbLook(value: number): (Color3, number)
	if value >= 10 then
		return Color3.fromRGB(220, 90, 255), 1.4
	elseif value >= 4 then
		return Color3.fromRGB(90, 255, 140), 1.05
	end
	return Color3.fromRGB(90, 200, 255), 0.8
end

local function spawnOrb(id: number, pos: Vector3, value: number)
	local color, size = orbLook(value)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local base = pos + Vector3.new(0, 1.2, 0)
	part.Position = base
	part.Parent = folder
	orbs[id] = { part = part, base = base, phase = math.random() * 6, target = nil, flyStart = 0, from = base }
end

local function removeOrb(id: number)
	local o = orbs[id]
	if o then
		o.part:Destroy()
		orbs[id] = nil
	end
end

orbsRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.clear then
		for id in orbs do
			removeOrb(id)
		end
	end
	for _, s in payload.spawn or {} do
		if typeof(s[1]) == "number" and typeof(s[2]) == "Vector3" and typeof(s[3]) == "number" then
			spawnOrb(s[1], s[2], s[3])
		end
	end
	for _, t in payload.take or {} do
		local o = orbs[t[1]]
		if o then
			local who = if typeof(t[2]) == "number" then Players:GetPlayerByUserId(t[2]) else nil
			if who and who.Character then
				o.target = who
				o.flyStart = os.clock()
				o.from = o.part.Position
			else
				removeOrb(t[1])
			end
		end
	end
end)

---------------------------------------------------------------------
-- Cofres
---------------------------------------------------------------------
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarities"))
local RarityVisuals = require(script.Parent.RarityVisuals)
local function decorateChest(chest: Instance)
	if not chest:IsA("BasePart") then
		return
	end
	local rarity = chest:GetAttribute("Rarity") or "Common"
	local color = Rarities.color(rarity, os.clock())
	-- Tapa neón y brillo
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(chest.Size.X + 0.2, 0.5, chest.Size.Z + 0.2)
	lid.Material = Enum.Material.Neon
	lid.Color = color
	lid.Anchored = true
	lid.CanCollide = false
	lid.CanQuery = false
	lid.CanTouch = false
	lid.CFrame = chest.CFrame * CFrame.new(0, chest.Size.Y / 2, 0)
	lid.Parent = chest

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 4
	light.Parent = chest

	-- Haz de luz hacia el cielo, para encontrarlo desde cualquier lado
	local bottom = Instance.new("Attachment")
	bottom.Parent = chest
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 60, 0)
	top.Parent = chest
	local beam = Instance.new("Beam")
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Width0 = 2.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = chest

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(120, 34)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 400
	sign.Parent = chest
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.Text = "🎁 " .. Rarities.Names[rarity]:upper()
	RarityVisuals.bind(label, rarity)
	label.TextStrokeTransparency = 0
	label.Parent = sign
end

local chestsFolder = workspace:WaitForChild("Chests", 30)
if chestsFolder then
	chestsFolder.ChildAdded:Connect(decorateChest)
	for _, c in chestsFolder:GetChildren() do
		decorateChest(c)
	end
end

-- Explosión dorada al abrir
local burstAttachment = Instance.new("Attachment")
burstAttachment.Parent = workspace.Terrain
local burst = Instance.new("ParticleEmitter")
burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
burst.Rate = 0
burst.LightEmission = 1
burst.LightInfluence = 0
burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
burst.Speed = NumberRange.new(20, 45)
burst.SpreadAngle = Vector2.new(60, 60)
burst.EmissionDirection = Enum.NormalId.Top
burst.Lifetime = NumberRange.new(0.6, 1.2)
burst.Drag = 2
burst.Acceleration = Vector3.new(0, -40, 0)
burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
burst.Parent = burstAttachment

chestOpened.OnClientEvent:Connect(function(pos: Vector3, _opener, rarity)
	burst.Color = ColorSequence.new(Rarities.color(rarity or "Common", os.clock()))
	if typeof(pos) ~= "Vector3" then
		return
	end
	burstAttachment.WorldPosition = pos + Vector3.new(0, 1.5, 0)
	burst:Emit(if low then 40 else 120)
end)

---------------------------------------------------------------------
-- Animación
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for id, o in orbs do
		if o.target then
			local character = o.target.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local t = (now - o.flyStart) / FLY_TIME
			if not root or t >= 1 then
				removeOrb(id)
			else
				o.part.Position = o.from:Lerp((root :: BasePart).Position, t * t)
			end
		elseif not low then
			-- Flotan suavemente
			o.part.Position = o.base + Vector3.new(0, math.sin(now * 3 + o.phase) * 0.35, 0)
		end
	end
	-- Los cofres giran y flotan un poco (la tapa los acompaña)
	if chestsFolder then
		for _, chest in chestsFolder:GetChildren() do
			if chest:IsA("BasePart") then
				local lid = chest:FindFirstChild("Lid") :: BasePart?
				if chest:GetAttribute("Rarity") == "Mythic" then
					local color = Rarities.color("Mythic", now)
					if lid then lid.Color = color end
					local beam = chest:FindFirstChildOfClass("Beam")
					if beam then beam.Color = ColorSequence.new(color) end
				end
				if lid then
					lid.CFrame = chest.CFrame * CFrame.new(0, chest.Size.Y / 2 + 0.2 + math.sin(now * 4) * 0.15, 0)
				end
			end
		end
	end
end)
