local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local FxQuality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FxQuality"))
local active = 0
local limit = if FxQuality.isLow() then 12 else 30

-- Meteorito: aviso rojo en el piso, la roca cae en diagonal y explota al llegar (fallTime segundos)
local function meteor(pos: Vector3, radius: number, fallTime: number)
	local function fxPart(props)
		local part = Instance.new("Part")
		part.Name = "ItemFX"
		part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		for k, v in props do (part :: any)[k] = v end
		part.Parent = workspace
		return part
	end
	local ground = pos - Vector3.new(0, 1.9, 0)
	local warning = fxPart({
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 40), Transparency = 0.7,
		Size = Vector3.new(0.15, radius * 2, radius * 2), CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2),
	})
	TweenService:Create(warning, TweenInfo.new(fallTime), { Transparency = 0.35 }):Play()
	local start = pos + Vector3.new(18, 55, -10)
	local rock = fxPart({
		Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 30),
		Size = Vector3.one * 3.5, CFrame = CFrame.new(start),
	})
	if not FxQuality.isLow() then
		local fire = Instance.new("Fire")
		fire.Size = 8; fire.Heat = 15
		fire.Parent = rock
	end
	TweenService:Create(rock, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(ground) }):Play()
	task.delay(fallTime, function()
		rock:Destroy()
		warning:Destroy()
		local blast = fxPart({
			Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 60), Transparency = 0.2,
			Size = Vector3.one * 2, CFrame = CFrame.new(ground),
		})
		TweenService:Create(blast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
		Debris:AddItem(blast, 0.4)
	end)
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemEffect").OnClientEvent:Connect(function(kind, origin, radius, destination)
	if kind == "meteor" then
		meteor(origin, radius, destination) -- (el 4º dato es el tiempo de caída)
		return
	end
	if active >= limit then return end
	active += 1
	local part = Instance.new("Part")
	part.Name = "ItemFX"
	part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
	part.Material = Enum.Material.Neon
	-- "bolt": rayo de la mejora Tormenta (más grueso y brillante que la cadena de "lightning")
	local bolt = kind == "bolt"
	part.Color = if bolt then Color3.fromRGB(200, 235, 255) elseif kind == "lightning" then Color3.fromRGB(80, 210, 255) else Color3.fromRGB(255, 180, 65)
	part.Transparency = if bolt then 0.1 else 0.6
	if destination then
		local length = (destination - origin).Magnitude
		local width = if bolt then 0.55 else 0.2
		part.Size = Vector3.new(width, width, math.max(0.1, length))
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
