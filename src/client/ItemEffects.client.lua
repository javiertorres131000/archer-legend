local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local FxQuality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FxQuality"))
local active = 0
local limit = if FxQuality.isLow() then 12 else 30
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemEffect").OnClientEvent:Connect(function(kind, origin, radius, destination)
	if active >= limit then return end
	active += 1
	local part = Instance.new("Part")
	part.Name = "ItemFX"
	part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = if kind == "lightning" then Color3.fromRGB(80, 210, 255) else Color3.fromRGB(255, 180, 65)
	part.Transparency = 0.6
	if destination then
		local length = (destination - origin).Magnitude
		part.Size = Vector3.new(0.2, 0.2, math.max(0.1, length))
		part.CFrame = CFrame.lookAt((origin + destination) / 2, destination)
	else
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.12, radius * 2, radius * 2)
		part.CFrame = CFrame.new(origin - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	part.Parent = workspace
	TweenService:Create(part, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.3)
	task.delay(0.3, function() active -= 1 end)
end)
