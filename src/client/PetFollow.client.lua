--!strict
-- PetFollow (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > PetFollow
-- Dibuja la mascota equipada de cada jugador (atributo "EquippedPet" del Player, lo pone el
-- servidor en CrateEquip) flotando a su lado y siguiéndolo. Es solo visual y local: cada
-- pantalla arma sus propias copias, así que no le cuesta nada al servidor ni a la red.
-- Ajustes en Config.Crates.Pet (alto, posición, velocidad, vaivén).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local CrateModels = require(Shared:WaitForChild("CrateModels"))

local Cfg = Config.Crates.Pet

type Pet = { id: string, model: Model, pos: Vector3?, phase: number }

local folder = Instance.new("Folder")
folder.Name = "CratePets"
folder.Parent = workspace

local pets: { [Player]: Pet } = {}
local watchers: { [Player]: RBXScriptConnection } = {}

local function remove(player: Player)
	local pet = pets[player]
	if pet then
		pet.model:Destroy()
		pets[player] = nil
	end
end

local function refresh(player: Player)
	local id = player:GetAttribute("EquippedPet")
	local current = pets[player]
	if current and current.id == id then
		return
	end
	remove(player)
	if type(id) ~= "string" or not CrateItems.ById[id] then
		return
	end
	local model = CrateModels.prize(id)
	local height = math.max(CrateModels.height(model), 0.5)
	model:ScaleTo(Cfg.Height / height)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.Name = player.Name .. "_Pet"
	model.Parent = folder
	pets[player] = { id = id, model = model, pos = nil, phase = math.random() * math.pi * 2 }
end

local function watch(player: Player)
	watchers[player] = player:GetAttributeChangedSignal("EquippedPet"):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
	remove(player)
	local conn = watchers[player]
	if conn then
		conn:Disconnect()
		watchers[player] = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * Cfg.FollowSpeed)
	for player, pet in pets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local base = root.CFrame
		local target = (base * CFrame.new(Cfg.Offset)).Position + Vector3.new(0, math.sin(now * 2.4 + pet.phase) * Cfg.BobHeight, 0)
		-- Lejos (teletransporte, cambio de sala): aparece directamente al lado
		local prev = pet.pos
		local pos: Vector3 = target
		if prev and (prev - target).Magnitude <= 40 then
			pos = prev:Lerp(target, alpha)
		end
		pet.pos = pos
		local look = base.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local cf = if flat.Magnitude > 0.01 then CFrame.lookAt(pos, pos + flat) else CFrame.new(pos)
		pet.model:PivotTo(cf)
	end
end)
