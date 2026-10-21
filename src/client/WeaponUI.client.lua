-- WeaponUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > WeaponUI
-- Elegir arma en el lobby (botón "Arma"): arco, espada, puños y las especiales. Solo muestra y
-- pide; el servidor (WeaponService) valida y la guarda en el perfil. La elegida llega en el
-- atributo "Weapon"; las especiales que tenés, en "OwnedWeapons" (las otras salen bloqueadas,
-- con el aviso de que se ganan en la Caja de Armas).
-- Maestría (Shared/Mastery.lua, atributo "Mastery"): cada carta muestra el nivel de su familia,
-- la barra hasta el próximo, el bono y lo que viene, con 🔒 en las habilidades bloqueadas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local Mastery = require(Shared:WaitForChild("Mastery"))
local Skills = require(Shared:WaitForChild("Skills"))
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
Theme.make("UISizeConstraint", { MaxSize = Vector2.new(math.max(760, #Weapons.List * 200), 500), Parent = window })
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

-- Texto que crece hacia abajo según lo que tenga (dentro de la lista de la carta)
local function flowText(parent: Instance, order: number, props: { [string]: any }): TextLabel
	local label = Theme.text(props)
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

-- Bloque de maestría de una carta (dentro de su lista, desde `order`)
local function masteryBlock(content: Instance, order: number, family: string, xp: number, isSpecial: boolean)
	local level = Mastery.levelOf(xp)
	local into, needed = Mastery.progress(xp)
	local title = Mastery.title(level)
	local tier = Mastery.tierColor(level) or Colors.GoldBright
	flowText(content, order, {
		Text = string.format("⭐ Maestría %d%s%s", level, if title then " · " .. title else "", if isSpecial then " (" .. Mastery.FamilyNames[family] .. ")" else ""),
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = tier,
	})
	local back = Theme.make("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(45, 40, 58),
		BorderSizePixel = 0,
		LayoutOrder = order + 1,
		Parent = content,
	}, { Theme.corner(3) })
	Theme.make("Frame", {
		Size = UDim2.fromScale(if needed > 0 then math.clamp(into / needed, 0, 1) else 1, 1),
		BackgroundColor3 = if level >= 3 then tier else Colors.Gold,
		BorderSizePixel = 0,
		Parent = back,
	}, { Theme.corner(3) })
	local damage, crit = Mastery.bonus(level)
	local lines = {}
	table.insert(lines, if needed > 0 then string.format("%d / %d XP", into, needed) else "¡Nivel máximo!")
	if damage > 0 or crit > 0 then
		table.insert(lines, string.format("Bono: +%d%% daño%s", math.floor(damage * 100 + 0.5), if crit > 0 then string.format(", +%d%% crítico", math.floor(crit * 100 + 0.5)) else ""))
	end
	-- Habilidades con candado de esta familia, de la más cercana a la más lejana
	local locks = {}
	for skillId, need in Mastery.Locks[family] or {} do
		table.insert(locks, { id = skillId, need = need })
	end
	table.sort(locks, function(a, b)
		return a.need < b.need
	end)
	for _, l in locks do
		local def = Skills.ById[l.id]
		local name = if def then def.Name else l.id
		if level >= l.need then
			table.insert(lines, "✔ " .. name .. " (desbloqueada)")
		else
			table.insert(lines, string.format("🔒 %s (nivel %d)", name, l.need))
		end
	end
	flowText(content, order + 2, { Text = table.concat(lines, "\n"), TextSize = 12, TextColor3 = Colors.TextMuted })
	return tier, level
end

local function refresh()
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local current = player:GetAttribute("Weapon") or Weapons.Default
	local ownedList = string.split(tostring(player:GetAttribute("OwnedWeapons") or ""), ",")
	local masteryXP = Mastery.decode(player:GetAttribute("Mastery"))
	for i, def in Weapons.List do
		local selected = def.Id == current
		local locked = def.Prize ~= nil and not table.find(ownedList, def.Id)
		local card = Theme.panel({ Size = UDim2.new(1 / #Weapons.List, -8, 1, 0), LayoutOrder = i, Parent = row })
		Theme.text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 40), Text = def.Icon, TextSize = 34, Parent = card })
		Theme.text({ Position = UDim2.fromOffset(4, 46), Size = UDim2.new(1, -8, 0, 24), Text = def.Name, Font = Theme.Fonts.Heading, TextSize = 18, TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = if selected then Colors.GoldBright else Colors.Text, Parent = card })
		-- Lo de la carta va en una lista que se desplaza si no entra (pantallas chicas)
		local content = Theme.make("ScrollingFrame", {
			Position = UDim2.fromOffset(10, 74),
			Size = UDim2.new(1, -16, 1, -74 - 54),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Colors.Gold,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = card,
		}, {
			Theme.make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
			Theme.make("UIPadding", { PaddingRight = UDim.new(0, 6) }),
		})
		flowText(content, 4, { Text = def.Description, TextSize = 13, TextColor3 = Colors.TextMuted })
		flowText(content, 5, { Text = statsLine(def), TextSize = 13, TextColor3 = Colors.Success })
		local family = def.Base or def.Id
		local tier, masteryLevel = masteryBlock(content, 1, family, masteryXP[family] or 0, def.Base ~= nil)
		-- Borde: dorado si está elegida; si no, el color de la especial o el de la maestría
		local border = if selected then Colors.GoldBright elseif def.Prize then def.Tint or Colors.Locked elseif masteryLevel >= 3 then tier else Colors.Locked
		Theme.stroke(border, if selected or def.Prize or masteryLevel >= 3 then 2.5 else 1).Parent = card
		local choose = Theme.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 36),
			Text = if locked then "🔒 Caja de Armas" elseif selected then "Equipada" else "Elegir",
			TextSize = if locked then 13 else 16,
			BackgroundColor3 = if selected or locked then Colors.Locked else Colors.Gold,
			Parent = card,
		})
		choose.Activated:Connect(function()
			if not selected and not locked then
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
player:GetAttributeChangedSignal("Mastery"):Connect(function()
	if gui.Enabled then
		refresh()
	end
end)
player:GetAttributeChangedSignal("OwnedWeapons"):Connect(function()
	if gui.Enabled then
		refresh()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		playerGui:SetAttribute("WeaponOpen", nil)
	end
end)
