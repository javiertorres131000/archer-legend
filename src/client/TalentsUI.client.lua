-- TalentsUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > TalentsUI
-- Árbol de talentos (se abre con el botón "Talentos" del lobby): núcleo arriba y tres ramas.
-- Solo dibuja y pide. Las reglas (conexión, puntos, oro, gemas) salen de Shared/Talents.lua, pero
-- quien decide es el servidor (TalentService), que responde con TalentState.
--
-- Estados de un nodo:  comprado (color de su rama, con brillo) · disponible (borde dorado que late)
--                      · bloqueado (gris). Tocá un nodo para ver el detalle y mejorarlo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Talents = require(Shared:WaitForChild("Talents"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local Theme = require(Shared:WaitForChild("UITheme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("TalentRequest") :: RemoteEvent
local talentState = remotes:WaitForChild("TalentState") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors

local CANVAS = Vector2.new(1000, 760)
local DETAILS_WIDTH = 290
local LOCKED = Color3.fromRGB(80, 76, 92)
local NODE_BG = Color3.fromRGB(28, 24, 38)

local icons = {}
for _, c in Currencies do
	icons[c.Id] = c.Icon
end

local levels: { [string]: number } = {}
local selected = "Core"

---------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------

local gui = Theme.make("ScreenGui", { Name = "TalentsUI", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false, IgnoreGuiInset = true, Parent = playerGui })
local backdrop = Theme.make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Modal = true,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.2,
	AutoButtonColor = false,
	Parent = gui,
})
local window = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.9), ClipsDescendants = true, Parent = backdrop })
Theme.make("UISizeConstraint", { MaxSize = Vector2.new(1240, 820), Parent = window })

Theme.text({
	Position = UDim2.fromOffset(18, 8),
	Size = UDim2.new(0, 320, 0, 34),
	Text = "⭐  ÁRBOL DE TALENTOS",
	Font = Theme.Fonts.Title,
	TextSize = 26,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})
local close = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(40, 32), Text = "×", Parent = window })

-- Barra de cuenta: nivel, XP, puntos, monedas, reiniciar
local bar = Theme.make("Frame", { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1, Parent = window })
local levelLabel = Theme.text({ Size = UDim2.fromOffset(92, 40), TextSize = 20, Font = Theme.Fonts.Heading, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar })
local xpBack = Theme.make("Frame", { Position = UDim2.fromOffset(94, 12), Size = UDim2.fromOffset(170, 16), BackgroundColor3 = Color3.fromRGB(40, 34, 52), BorderSizePixel = 0, Parent = bar }, { Theme.corner(8) })
local xpFill = Theme.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(190, 140, 255), BorderSizePixel = 0, Parent = xpBack }, { Theme.corner(8) })
local xpText = Theme.text({ Size = UDim2.fromScale(1, 1), TextSize = 11, Font = Theme.Fonts.Bold, ZIndex = 3, Parent = xpBack })
local pointsLabel = Theme.text({ Position = UDim2.fromOffset(276, 0), Size = UDim2.fromOffset(150, 40), TextSize = 18, Font = Theme.Fonts.Heading, TextColor3 = Colors.GoldBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar })
local wallet = Theme.text({ Position = UDim2.fromOffset(430, 0), Size = UDim2.new(1, -580, 0, 40), TextSize = 16, Font = Theme.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar })
local resetButton = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(140, 32), Text = "Reiniciar árbol", TextSize = 13, BackgroundColor3 = Color3.fromRGB(120, 50, 50), Parent = bar })

-- Cuerpo: árbol + detalle
local treeFrame = Theme.make("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 92),
	BackgroundColor3 = Color3.fromRGB(14, 12, 20),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollingDirection = Enum.ScrollingDirection.XY,
	ElasticBehavior = Enum.ElasticBehavior.Never,
	Parent = window,
}, { Theme.corner(10) })
local canvas = Theme.make("Frame", { Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y), BackgroundTransparency = 1, Parent = treeFrame })
local canvasScale = Theme.make("UIScale", { Parent = canvas })
local linesLayer = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = canvas })
local nodesLayer = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas })

-- Nombres de las ramas, abajo
for branch, pos in { Attack = 155, Defense = 500, Utility = 800 } do
	local b = Talents.Branches[branch]
	Theme.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos, 728),
		Size = UDim2.fromOffset(220, 28),
		Text = string.upper(b.Name),
		TextSize = 18,
		Font = Theme.Fonts.Title,
		TextColor3 = b.Color,
		TextTransparency = 0.25,
		Parent = canvas,
	})
end

local details = Theme.panel({ Parent = window })
local dName = Theme.text({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 30), TextSize = 21, Font = Theme.Fonts.Heading, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, Parent = details })
local dKind = Theme.text({ Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 18), TextSize = 13, TextColor3 = Colors.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, Parent = details })
local dDesc = Theme.text({ Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 52), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
local dRank = Theme.text({ Position = UDim2.fromOffset(14, 118), Size = UDim2.new(1, -28, 0, 20), TextSize = 15, Font = Theme.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Left, Parent = details })
local dNow = Theme.text({ Position = UDim2.fromOffset(14, 140), Size = UDim2.new(1, -28, 0, 36), TextSize = 13, TextWrapped = true, TextColor3 = Colors.Success, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
local dCost = Theme.text({ Position = UDim2.fromOffset(14, 178), Size = UDim2.new(1, -28, 0, 40), TextSize = 14, TextWrapped = true, Font = Theme.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
local dReason = Theme.text({ Position = UDim2.fromOffset(14, 220), Size = UDim2.new(1, -28, 0, 36), TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 120, 110), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
local buyButton = Theme.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -44), Size = UDim2.new(1, -28, 0, 40), TextSize = 17, Parent = details })
local message = Theme.text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 32), TextSize = 12, TextWrapped = true, TextColor3 = Colors.TextMuted, Text = "", Parent = details })

---------------------------------------------------------------------
-- Dibujo
---------------------------------------------------------------------

local pulsing: { UIStroke } = {}

local function wallet_(): { [string]: number }
	return { Gold = player:GetAttribute("Gold") or 0, Gems = player:GetAttribute("Gems") or 0 }
end

local function accountLevel(): number
	return player:GetAttribute("AccountLevel") or 1
end

local function nodeState(def): string
	if (levels[def.Id] or 0) > 0 then
		return "owned"
	elseif Talents.reachable(levels, def) then
		return "open"
	end
	return "locked"
end

local function nodeSize(def): number
	return if def.Kind == "root" then 78 elseif def.Kind == "keystone" then 62 else 46
end

local function drawLine(a, b, color: Color3, transparency: number, thickness: number)
	local d = Vector2.new(b.X - a.X, b.Y - a.Y)
	Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(d.Magnitude, thickness),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = linesLayer,
	})
end

local function showDetails()
	local def = Talents.ById[selected] or Talents.List[1]
	local branch = Talents.Branches[def.Branch]
	local rank = levels[def.Id] or 0
	local check = Talents.check(levels, accountLevel(), wallet_(), def.Id)
	dName.Text = def.Icon .. "  " .. def.Name
	dName.TextColor3 = branch.Color
	dKind.Text = (if def.Kind == "keystone" then "Nodo clave" elseif def.Kind == "root" then "Núcleo" else "Nodo") .. " · " .. branch.Name
	dDesc.Text = def.Description
	dRank.Text = string.format("Rango %d / %d", rank, def.Max)
	local lines = {}
	if rank > 0 then
		table.insert(lines, "Ahora: " .. def.Bonus(rank))
	end
	if rank < def.Max then
		table.insert(lines, "Siguiente: " .. def.Bonus(rank + 1))
	end
	dNow.Text = table.concat(lines, "\n")
	if rank >= def.Max then
		dCost.Text = "Completo"
		dReason.Text = ""
	else
		local parts = { string.format("⭐ %d punto%s", check.points, if check.points == 1 then "" else "s"), string.format("%s %d", icons.Gold or "oro", check.gold) }
		if check.gems > 0 then
			table.insert(parts, string.format("%s %d", icons.Gems or "gemas", check.gems))
		end
		dCost.Text = "Costo: " .. table.concat(parts, "   ")
		dReason.Text = check.reason or ""
	end
	buyButton.Text = if rank >= def.Max then "Máximo" elseif rank == 0 then "Desbloquear" else "Mejorar"
	buyButton.Active = check.ok
	buyButton.BackgroundColor3 = if check.ok then Colors.Gold else Colors.Locked
end

local function refresh()
	local level = accountLevel()
	local xp, need = player:GetAttribute("AccountXP") or 0, player:GetAttribute("AccountXPNeeded") or Talents.xpNeeded(level)
	levelLabel.Text = "Nivel " .. level
	xpFill.Size = UDim2.fromScale(math.clamp(xp / math.max(1, need), 0, 1), 1)
	xpText.Text = string.format("%d / %d XP", xp, need)
	local points = Talents.pointsForLevel(level) - Talents.spent(levels)
	pointsLabel.Text = string.format("⭐ %d punto%s", points, if points == 1 then "" else "s")
	local w = wallet_()
	wallet.Text = string.format("%s %d    %s %d", icons.Gold or "", w.Gold, icons.Gems or "", w.Gems)

	for _, layer in { linesLayer, nodesLayer } do
		layer:ClearAllChildren()
	end
	table.clear(pulsing)

	-- Líneas (debajo de los nodos)
	for _, def in Talents.List do
		for _, linkId in def.Links do
			local from = Talents.ById[linkId]
			if from then
				local color = Talents.Branches[def.Branch].Color
				local a, b = Vector2.new(from.X, from.Y), Vector2.new(def.X, def.Y)
				local ownedA, ownedB = (levels[from.Id] or 0) > 0, (levels[def.Id] or 0) > 0
				if ownedA and ownedB then
					drawLine(a, b, color, 0.75, 12) -- brillo
					drawLine(a, b, color, 0, 4)
				elseif ownedA then
					drawLine(a, b, Colors.GoldBright, 0.45, 3)
				else
					drawLine(a, b, LOCKED, 0.5, 3)
				end
			end
		end
	end

	-- Nodos
	for _, def in Talents.List do
		local state = nodeState(def)
		local color = Talents.Branches[def.Branch].Color
		local size = nodeSize(def)
		local rank = levels[def.Id] or 0
		local holder = Theme.make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(def.X, def.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 6,
			Parent = nodesLayer,
		})
		-- Brillo detrás de lo comprado
		if state == "owned" then
			Theme.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 18, 1, 18),
				BackgroundColor3 = color,
				BackgroundTransparency = 0.72,
				BorderSizePixel = 0,
				Rotation = if def.Kind == "keystone" then 45 else 0,
				ZIndex = 6,
				Parent = holder,
			}, { Theme.corner(if def.Kind == "keystone" then 10 else size) })
		end
		-- Forma: rombo para los nodos clave, círculo para el resto
		local shape = Theme.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if def.Kind == "keystone" then UDim2.fromScale(0.78, 0.78) else UDim2.fromScale(1, 1),
			Rotation = if def.Kind == "keystone" then 45 else 0,
			BackgroundColor3 = if state == "owned" then color:Lerp(NODE_BG, 0.55) else NODE_BG,
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = holder,
		}, { Theme.corner(if def.Kind == "keystone" then 8 else size) })
		local stroke = Theme.make("UIStroke", {
			Color = if state == "owned" then color elseif state == "open" then Colors.GoldBright else LOCKED,
			Thickness = if state == "owned" then 3 elseif state == "open" then 2.5 else 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = shape,
		})
		if state == "open" then
			table.insert(pulsing, stroke)
		end
		if def.Id == selected then
			-- Anillo de selección
			Theme.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 12, 1, 12),
				BackgroundTransparency = 1,
				ZIndex = 7,
				Parent = holder,
			}, {
				Theme.corner(size),
				Theme.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.15 }),
			})
		end
		Theme.text({
			Size = UDim2.fromScale(1, 1),
			Text = def.Icon,
			TextSize = math.floor(size * 0.5),
			TextTransparency = if state == "locked" then 0.55 else 0,
			ZIndex = 8,
			Parent = holder,
		})
		if def.Max > 1 or state ~= "owned" then
			Theme.text({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, if def.Kind == "keystone" then 2 else -4),
				Size = UDim2.fromOffset(48, 16),
				Text = string.format("%d/%d", rank, def.Max),
				TextSize = 12,
				Font = Theme.Fonts.Bold,
				TextColor3 = if rank >= def.Max then color elseif state == "locked" then LOCKED else Colors.Text,
				TextStrokeTransparency = 0.4,
				ZIndex = 9,
				Parent = holder,
			})
		end
		holder.Activated:Connect(function()
			selected = def.Id
			refresh()
		end)
	end
	showDetails()
end

-- Acomoda árbol y detalle según el tamaño de la ventana (en pantallas angostas el detalle va abajo).
local function layout()
	local size = window.AbsoluteSize
	local narrow = size.X < 760
	if narrow then
		treeFrame.Size = UDim2.new(1, -20, 1, -92 - 356)
		details.Position = UDim2.new(0, 10, 1, -350)
		details.Size = UDim2.new(1, -20, 0, 340)
	else
		treeFrame.Size = UDim2.new(1, -DETAILS_WIDTH - 30, 1, -102)
		details.Position = UDim2.new(1, -DETAILS_WIDTH - 10, 0, 92)
		details.Size = UDim2.new(0, DETAILS_WIDTH, 1, -102)
	end
	wallet.Visible = size.X >= 700
	-- El árbol entra entero si hay lugar; si no, se puede desplazar
	local view = treeFrame.AbsoluteSize
	local scale = math.clamp(math.min(view.X / CANVAS.X, view.Y / CANVAS.Y), 0.6, 1.25)
	canvasScale.Scale = scale
	local scaled = Vector2.new(math.ceil(CANVAS.X * scale), math.ceil(CANVAS.Y * scale))
	treeFrame.CanvasSize = UDim2.fromOffset(scaled.X, scaled.Y)
	-- Centrado cuando sobra lugar
	canvas.Position = UDim2.fromOffset(math.max(0, (view.X - scaled.X) // 2), math.max(0, (view.Y - scaled.Y) // 2))
end
window:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
treeFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

-- Borde de los disponibles que late
RunService.RenderStepped:Connect(function()
	if not gui.Enabled or #pulsing == 0 then
		return
	end
	local t = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 4))
	for _, stroke in pulsing do
		stroke.Transparency = t
	end
end)

---------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------

buyButton.Activated:Connect(function()
	if buyButton.Active then
		request:FireServer("Buy", selected)
	end
end)

local resetUntil = 0
resetButton.Activated:Connect(function()
	if os.clock() < resetUntil then
		resetUntil = 0
		resetButton.Text = "Reiniciar árbol"
		request:FireServer("Reset")
	else
		resetUntil = os.clock() + 3
		resetButton.Text = "¿Seguro? (el oro no vuelve)"
		task.delay(3.1, function()
			if os.clock() >= resetUntil then
				resetButton.Text = "Reiniciar árbol"
			end
		end)
	end
end)

talentState.OnClientEvent:Connect(function(newLevels, notice)
	if typeof(newLevels) == "table" then
		levels = newLevels
	end
	if typeof(notice) == "string" then
		message.Text = notice
		message.TextColor3 = if string.sub(notice, 1, 3) == "✔" then Colors.Success else Colors.GoldBright
	end
	if gui.Enabled then
		refresh()
	end
end)

local function setOpen(open: boolean)
	gui.Enabled = open and player:GetAttribute("InMatch") ~= true
	if gui.Enabled then
		request:FireServer("Get")
		layout()
		refresh()
	end
end

close.Activated:Connect(function()
	playerGui:SetAttribute("TalentsOpen", nil)
end)
playerGui:GetAttributeChangedSignal("TalentsOpen"):Connect(function()
	setOpen(playerGui:GetAttribute("TalentsOpen") == true)
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		playerGui:SetAttribute("TalentsOpen", nil)
	end
end)
for _, attr in { "Gold", "Gems", "AccountLevel", "AccountXP", "TalentPoints" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end
