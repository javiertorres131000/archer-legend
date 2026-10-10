-- Avisos por rareza y lista de objetos temporales. Cola limitada para no tapar el combate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("RunItems"))
local Skills = require(Shared:WaitForChild("Skills"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Theme = require(Shared:WaitForChild("UITheme"))
local Visuals = require(script.Parent.RarityVisuals)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local gui = Theme.make("ScreenGui", { Name = "RewardNotices", ResetOnSpawn = false, DisplayOrder = 25, Parent = player:WaitForChild("PlayerGui") })
local toast = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.new(0.8, 0, 0, 70), Visible = false, Parent = gui })
Theme.make("UISizeConstraint", { MaxSize = Vector2.new(480, 70), Parent = toast })
local title = Theme.text({ Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 5), TextSize = 21, TextScaled = true, Parent = toast })
local subtitle = Theme.text({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 39), TextSize = 15, Parent = toast })
local bag = Theme.text({ RichText = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0.3, 0), Size = UDim2.new(0.3, 0, 0, 190), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = gui })
local owned, queue = {}, {}
local showing = false
local function notice(name, rarity, source)
	if #queue < 12 then table.insert(queue, { name, rarity, source }) end
	if showing then return end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			local entry = table.remove(queue, 1)
			title.Text = entry[1]
			subtitle.Text = entry[3] .. " · " .. (Rarities.Names[entry[2]] or entry[2])
			Visuals.bind(title, entry[2]); Visuals.bind(subtitle, entry[2])
			toast.Visible = true
			task.wait(2)
			toast.Visible = false
		end
		showing = false
	end)
end
local function refresh()
	local lines = { "OBJETOS DE ESTA PARTIDA" }
	for _, def in Items.List do
		if owned[def.Id] then table.insert(lines, string.format('<font color="#%s">%s ×%d</font>', Rarities.color(def.Rarity, os.clock()):ToHex(), def.Name, owned[def.Id])) end
	end
	bag.Text = table.concat(lines, "\n")
	bag.Visible = player:GetAttribute("InMatch") == true and next(owned) ~= nil
end
remotes:WaitForChild("ItemGranted").OnClientEvent:Connect(function(id, stacks)
	local def = Items.ById[id]
	if not def then return end
	owned[id] = stacks
	refresh()
	notice(def.Name .. " ×" .. stacks, def.Rarity, "Objeto temporal")
end)
remotes:WaitForChild("SkillGranted").OnClientEvent:Connect(function(id, stacks)
	local def = Skills.ById[id]
	if def then notice(def.Name .. " ×" .. stacks, def.Rarity, "Habilidad") end
end)
remotes:WaitForChild("RewardNotice").OnClientEvent:Connect(notice)
remotes:WaitForChild("RunReset").OnClientEvent:Connect(function() table.clear(owned); table.clear(queue); toast.Visible = false; refresh() end)
player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
local rarityTimer = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	if not bag.Visible or not owned.Prism then return end
	rarityTimer += dt
	if rarityTimer >= 0.1 then rarityTimer = 0; refresh() end
end)
