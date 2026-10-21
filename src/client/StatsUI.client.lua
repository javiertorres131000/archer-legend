-- StatsUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > StatsUI
-- Panel de stats: cuánto suma cada sistema (base → equipo → talentos → runas) y, en partida,
-- las stats de ahora (con habilidades y objetos). Lo calcula el servidor (StatsBreakdown).
--   Lobby: botón "Stats". Partida: tecla Tab (o el botón 📊 en celular). No pausa nada.
-- Cada columna es el total acumulado; en verde lo que cambió respecto de la columna anterior.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("UITheme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("StatsRequest") :: RemoteEvent
local statsState = remotes:WaitForChild("StatsState") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors

local LABEL_W = 178
local COL_W = 72
local ROW_H = 22

local gui = Theme.make("ScreenGui", { Name = "StatsUI", ResetOnSpawn = false, DisplayOrder = 35, Parent = playerGui })
local window = Theme.panel({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(LABEL_W + 5 * COL_W + 24, 120),
	Visible = false,
	Parent = gui,
})
local title = Theme.text({
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -60, 0, 26),
	Text = "📊  STATS",
	Font = Theme.Fonts.Heading,
	TextSize = 18,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})
local close = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(30, 26), Text = "×", TextSize = 16, Parent = window })
local tableFrame = Theme.make("Frame", { Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 1, -50), BackgroundTransparency = 1, Parent = window })
local hint = Theme.text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -4),
	Size = UDim2.new(1, -24, 0, 16),
	TextSize = 11,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})

-- Botón táctil para la partida (en PC está la tecla Tab)
local touchButton = Theme.button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.3, 0),
	Size = UDim2.fromOffset(44, 44),
	Text = "📊",
	TextSize = 22,
	Visible = false,
	Parent = gui,
})

local function format(kind: string, v: any): string
	if kind == "bool" then
		return if v then "Sí" else "—"
	elseif type(v) ~= "number" then
		return "—"
	elseif kind == "pct" then
		return string.format("%g%%", math.floor(v * 1000 + 0.5) / 10)
	elseif kind == "mult" then
		return string.format("×%.2f", v)
	elseif kind == "rate" then
		return string.format("%.2f", 1 / math.max(v, 0.01))
	elseif kind == "sec" then
		return string.format("%.1fs", v)
	end
	return if math.abs(v - math.floor(v)) < 0.05 then tostring(math.floor(v + 0.5)) else string.format("%.1f", v)
end

local function same(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-4
	end
	return a == b
end

local function render(data)
	tableFrame:ClearAllChildren()
	local columns, values = data.columns, data.values
	-- Encabezados
	for c, name in columns do
		Theme.text({
			Position = UDim2.fromOffset(LABEL_W + (c - 1) * COL_W, 0),
			Size = UDim2.fromOffset(COL_W, ROW_H),
			Text = name,
			Font = Theme.Fonts.Bold,
			TextSize = 13,
			TextColor3 = if name == "Ahora" then Colors.GoldBright else Colors.TextMuted,
			Parent = tableFrame,
		})
	end
	local y = ROW_H + 2
	for _, row in data.rows do
		-- Se oculta lo que vale lo mismo en todas las columnas y es cero / no
		local first = values[1][row.key]
		local all = true
		for c = 2, #values do
			if not same(values[c][row.key], first) then
				all = false
				break
			end
		end
		if all and (first == 0 or first == false or first == nil) then
			continue
		end
		Theme.text({
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(LABEL_W, ROW_H),
			Text = row.label,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = tableFrame,
		})
		for c = 1, #values do
			local v = values[c][row.key]
			local changed = c > 1 and not same(v, values[c - 1][row.key])
			Theme.text({
				Position = UDim2.fromOffset(LABEL_W + (c - 1) * COL_W, y),
				Size = UDim2.fromOffset(COL_W, ROW_H),
				Text = format(row.kind, v),
				Font = if changed then Theme.Fonts.Bold else Theme.Fonts.Body,
				TextSize = 13,
				TextColor3 = if changed then Colors.Success else Colors.Text,
				Parent = tableFrame,
			})
		end
		y += ROW_H
	end
	window.Size = UDim2.fromOffset(LABEL_W + #columns * COL_W + 24, y + 38 + 26)
	hint.Text = if data.inMatch
		then "Tab para cerrar · Ahora = con habilidades y objetos de la partida"
		else "Cada columna suma la anterior · en verde, lo que cambia"
end

statsState.OnClientEvent:Connect(function(data)
	if typeof(data) == "table" and data.rows and data.values then
		render(data)
	end
end)

local function setOpen(open: boolean)
	window.Visible = open
	if open then
		title.Text = if player:GetAttribute("InMatch") then "📊  STATS DE LA PARTIDA" else "📊  STATS"
		request:FireServer()
	end
end

local function toggle()
	playerGui:SetAttribute("StatsOpen", not window.Visible or nil)
end

close.Activated:Connect(function()
	playerGui:SetAttribute("StatsOpen", nil)
end)
touchButton.Activated:Connect(toggle)
playerGui:GetAttributeChangedSignal("StatsOpen"):Connect(function()
	setOpen(playerGui:GetAttribute("StatsOpen") == true)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Tab and player:GetAttribute("InMatch") then
		toggle()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	local inMatch = player:GetAttribute("InMatch") == true
	touchButton.Visible = inMatch and UserInputService.TouchEnabled
	playerGui:SetAttribute("StatsOpen", nil) -- al entrar o salir de la partida se cierra
end)

-- En partida, mientras está abierto, se actualiza solo (el servidor limita a 2 pedidos por segundo)
task.spawn(function()
	while true do
		task.wait(1)
		if window.Visible and player:GetAttribute("InMatch") then
			request:FireServer()
		end
	end
end)
