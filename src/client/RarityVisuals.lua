local Rarities = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rarities"))
local RunService = game:GetService("RunService")
local Visuals = {}
local rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 65)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 150)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 190, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 170)),
})
local animated = {}
function Visuals.bind(label, rarity)
	local old = label:FindFirstChild("RarityGradient")
	if old then old:Destroy() end
	label.TextColor3 = Rarities.color(rarity, os.clock())
	if rarity == "Mythic" then
		label.TextColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Name = "RarityGradient"
		gradient.Color = rainbow
		gradient.Parent = label
		animated[gradient] = true
	end
end
RunService.RenderStepped:Connect(function()
	for gradient in animated do
		if not gradient.Parent then animated[gradient] = nil
		else gradient.Rotation = os.clock() * 40 end
	end
end)
return Visuals
