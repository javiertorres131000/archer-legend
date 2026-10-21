-- WeaponUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > WeaponUI
-- Elegir arma en el lobby (botón "Arma"): arco, espada o puños. Solo muestra y pide; el servidor
-- (WeaponService) valida y la guarda en el perfil. La elegida llega en el atributo "Weapon".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local Theme = require(Shared:WaitForChild("UITheme"))
local request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponRequest") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors

local gui = Theme.make("ScreenGui", { Name = "WeaponUI", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false, Parent = playerGui })
local backdrop = Theme.make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Modal = true,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.25,
	AutoButtonColor = false,
	Parent = gui,
})
local window = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.8), Parent = backdrop })
Theme.make("UISizeConstraint", { MaxSize = Vector2.new(760, 380), Parent = window })
Theme.text({
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -90, 0, 34),
	Text = "⚔️  ELEGÍ TU ARMA",
	Font = Theme.Fonts.Title,
	TextSize = 26,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})
local close = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(40, 32), Text = "×", Parent = window })
local row = Theme.make("Frame", { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 1, -72), BackgroundTransparency = 1, Parent = window }, {
	Theme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function statsLine(def): string
	local parts = { string.format("Daño ×%.2g", def.DamageMult) }
	table.insert(parts, string.format("Velocidad ×%.2g", 1 / def.IntervalMult))
	if def.Kind == "Melee" then
		table.insert(parts, string.format("Alcance %d · Arco %d°", def.Range, def.Arc))
	else
		table.insert(parts, "A distancia")
	end
	return table.concat(parts, "\n")
end

local function refresh()
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local current = player:GetAttribute("Weapon") or Weapons.Default
	for i, def in Weapons.List do
		local selected = def.Id == current
		local card = Theme.panel({ Size = UDim2.new(1 / #Weapons.List, -8, 1, 0), LayoutOrder = i, Parent = row })
		Theme.stroke(if selected then Colors.GoldBright else Colors.Locked, if selected then 2.5 else 1).Parent = card
		Theme.text({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 56), Text = def.Icon, TextSize = 46, Parent = card })
		Theme.text({ Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 26), Text = def.Name, Font = Theme.Fonts.Heading, TextSize = 20, TextColor3 = if selected then Colors.GoldBright else Colors.Text, Parent = card })
		Theme.text({ Position = UDim2.fromOffset(10, 98), Size = UDim2.new(1, -20, 0, 70), Text = def.Description, TextSize = 13, TextWrapped = true, TextColor3 = Colors.TextMuted, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		Theme.text({ Position = UDim2.fromOffset(10, 170), Size = UDim2.new(1, -20, 0, 54), Text = statsLine(def), TextSize = 13, TextWrapped = true, TextColor3 = Colors.Success, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		local choose = Theme.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 36),
			Text = if selected then "Equipada" else "Elegir",
			TextSize = 16,
			BackgroundColor3 = if selected then Colors.Locked else Colors.Gold,
			Parent = card,
		})
		choose.Activated:Connect(function()
			if not selected then
				request:FireServer("Select", def.Id)
			end
		end)
	end
end

local function setOpen(open: boolean)
	gui.Enabled = open and player:GetAttribute("InMatch") ~= true
	if gui.Enabled then
		refresh()
	end
end

close.Activated:Connect(function()
	playerGui:SetAttribute("WeaponOpen", nil)
end)
playerGui:GetAttributeChangedSignal("WeaponOpen"):Connect(function()
	setOpen(playerGui:GetAttribute("WeaponOpen") == true)
end)
player:GetAttributeChangedSignal("Weapon"):Connect(function()
	if gui.Enabled then
		refresh()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		playerGui:SetAttribute("WeaponOpen", nil)
	end
end)
