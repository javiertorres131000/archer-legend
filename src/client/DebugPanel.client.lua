-- DebugPanel (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > DebugPanel
-- Panel de prueba: F2 lo abre y lo cierra. Solo aparece si el servidor marcó al jugador con el
-- atributo "DebugAllowed" (Studio, o UserId en Config.Debug.Admins). Los botones solo piden: el
-- servidor (DebugCommands) vuelve a revisar el permiso y hace todo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("UITheme"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DebugCommand") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors

local gui = Theme.make("ScreenGui", { Name = "DebugPanel", ResetOnSpawn = false, DisplayOrder = 60, Enabled = false, Parent = playerGui })
local window = Theme.panel({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(340, 420),
	Parent = gui,
})
Theme.text({
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 24),
	Text = "🛠  PANEL DE PRUEBA  ·  F2",
	Font = Theme.Fonts.Heading,
	TextSize = 16,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})
local grid = Theme.make("Frame", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 1, -110), BackgroundTransparency = 1, Parent = window }, {
	Theme.make("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 36), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local output = Theme.text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -8),
	Size = UDim2.new(1, -24, 0, 66),
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Colors.TextMuted,
	Text = "Los comandos de partida solo andan jugando.",
	Parent = window,
})
-- Un botón Modal libera el mouse en primera persona mientras el panel está abierto
local modal = Theme.make("TextButton", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true, Parent = window })
local _ = modal

local function build(spec: string)
	grid:ClearAllChildren()
	Theme.make("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 36), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local order = 0
	for item in string.gmatch(spec, "[^;]+") do
		local id, label = string.match(item, "^([^=]+)=(.+)$")
		if id and label then
			order += 1
			local b = Theme.button({ Text = label, TextSize = 13, LayoutOrder = order, Parent = grid })
			b.Activated:Connect(function()
				remote:FireServer(id)
			end)
		end
	end
end

remote.OnClientEvent:Connect(function(ok, message)
	output.Text = tostring(message)
	output.TextColor3 = if ok then Colors.Success else Color3.fromRGB(255, 120, 110)
end)

local function setOpen(open: boolean)
	local spec = player:GetAttribute("DebugAllowed")
	gui.Enabled = open and type(spec) == "string"
	player:SetAttribute("PanelCursor", gui.Enabled or nil)
	if gui.Enabled then
		build(spec)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F2 then
		setOpen(not gui.Enabled)
	end
end)
player:GetAttributeChangedSignal("DebugAllowed"):Connect(function()
	if gui.Enabled then
		setOpen(true)
	end
end)
