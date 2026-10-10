-- MenuTabs (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > MenuTabs
-- Pestañas de abajo de las pantallas del personaje (Equipo | Runas), como en Archero.
-- Qué pantalla está abierta lo dice el atributo "EquipmentTab" de PlayerGui (nil = ninguna);
-- cada pantalla se abre sola cuando ese atributo tiene su nombre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

local MenuTabs = {}

MenuTabs.Height = 52
MenuTabs.List = {
	{ Id = "Equipo", Icon = "🛡", Name = "Equipo" },
	{ Id = "Runas", Icon = "🔮", Name = "Runas" },
}

-- Barra de pestañas al pie de `window`, con `current` resaltada
function MenuTabs.new(window: GuiObject, current: string)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local bar = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -20, 0, MenuTabs.Height - 8),
		BackgroundTransparency = 1,
		Parent = window,
	})
	Theme.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = bar,
	})
	for _, tab in MenuTabs.List do
		local selected = tab.Id == current
		local button = Theme.make("TextButton", {
			Size = UDim2.new(1 / #MenuTabs.List, -8, 1, 0),
			BackgroundColor3 = if selected then Theme.Colors.Gold else Theme.Colors.PanelLight,
			AutoButtonColor = not selected,
			Font = Theme.Fonts.Bold,
			TextSize = 18,
			TextColor3 = if selected then Color3.fromRGB(40, 28, 10) else Theme.Colors.Text,
			Text = tab.Icon .. "  " .. tab.Name,
			Parent = bar,
		}, { Theme.corner(10), Theme.stroke(if selected then Theme.Colors.GoldBright else Theme.Colors.GoldDark, 1.5) })
		if not selected then
			button.Activated:Connect(function()
				playerGui:SetAttribute("EquipmentTab", tab.Id)
			end)
		end
	end
	return bar
end

return MenuTabs
