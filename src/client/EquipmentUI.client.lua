-- EquipmentUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > EquipmentUI
-- Pantalla de equipo estilo Archero: tu personaje con los 6 espacios alrededor, ataque y vida
-- arriba, y abajo la grilla del inventario. Tocás un objeto y aparece el detalle con
-- Equipar / Quitar, Reciclar, Mejorar y Fusionar (y arriba de la grilla, reciclar en lote las
-- rarezas bajas). Todo lo valida el servidor (Equipment.lua): esta
-- pantalla solo pide cosas por EquipmentRequest y se redibuja con lo que vuelve en EquipmentState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Defs = require(Shared:WaitForChild("EquipmentDefs"))
local BaseStats = require(Shared:WaitForChild("BaseStats"))
local Talents = require(Shared:WaitForChild("Talents"))
local RuneDefs = require(Shared:WaitForChild("RuneDefs"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local Theme = require(Shared:WaitForChild("UITheme"))
local Visuals = require(script.Parent.RarityVisuals)
local AvatarView = require(script.Parent.AvatarView)
local MenuTabs = require(script.Parent.MenuTabs)

local Colors, Fonts = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("EquipmentRequest") :: RemoteEvent

local inventory, equipped = {}, {}
-- Talentos y runas: también suben tus stats (llegan por TalentState y RuneState)
local talentLevels: { [string]: number } = {}
local runeOwned: { [string]: number }, runeActive: { string }, runeSlots = {}, {}, 1
local selectedUid: string? = nil
local sortBy = "Rarity" -- "Rarity" | "Slot"
local confirmFuse = false
local confirmRecycle = false

local function send(action: string, arg: any)
	request:FireServer(action, arg)
end

local function rank(item): number
	return Rarities.index(item.Rarity) or 1
end

local function findItem(uid: string?)
	for _, item in inventory do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end

local function percent(x: number): string
	return string.format("+%.1f%%", x * 100)
end

---------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------
local gui = make("ScreenGui", { Name = "EquipmentUI", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false, IgnoreGuiInset = true, Parent = playerGui })
local backdrop = make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", Modal = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, AutoButtonColor = false, Parent = gui })
local window = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.92), Parent = backdrop })
make("UISizeConstraint", { MaxSize = Vector2.new(1000, 760), Parent = window })

-- Barra superior: título, monedas y cerrar
local topBar = make("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = window })
text({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(0.4, 0, 0, 34), Text = "EQUIPO", Font = Fonts.Title, TextSize = 28, TextColor3 = Colors.GoldBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = topBar })
local moneyRow = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -62, 0, 8), Size = UDim2.new(0.6, -70, 0, 30), BackgroundTransparency = 1, Parent = topBar })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), Parent = moneyRow })
local moneyLabels = {}
for _, c in Currencies do
	if c.Id == "Gems" then
		continue -- el equipo solo usa oro y piedras
	end
	local chip = make("Frame", { Size = UDim2.fromOffset(120, 30), BackgroundColor3 = Colors.PanelLight, Parent = moneyRow }, { Theme.corner(15), Theme.stroke(Colors.GoldDark, 1) })
	moneyLabels[c.Id] = text({ Size = UDim2.fromScale(1, 1), Text = "", Font = Fonts.Bold, TextSize = 16, TextColor3 = c.Color, Parent = chip })
end
local function refreshMoney()
	for _, c in Currencies do
		local label = moneyLabels[c.Id]
		if label then
			label.Text = c.Icon .. " " .. tostring(player:GetAttribute(c.Id) or 0)
		end
	end
end
for _, c in Currencies do
	player:GetAttributeChangedSignal(c.Id):Connect(refreshMoney)
end
local close = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(40, 32), Text = "×", Parent = topBar })

-- Héroe (arriba o a la izquierda) e inventario (abajo o a la derecha); ver layout()
local hero = make("Frame", { BackgroundColor3 = Color3.fromRGB(58, 46, 30), Parent = window }, {
	Theme.corner(12),
	Theme.stroke(Colors.GoldDark, 1.5),
	Theme.gradient(Color3.fromRGB(255, 236, 190), Color3.fromRGB(150, 120, 80)),
})
local bag = make("Frame", { BackgroundColor3 = Colors.PanelLight, Parent = window }, { Theme.corner(12), Theme.stroke(Colors.GoldDark, 1.5) })

---------------------------------------------------------------------
-- Héroe: personaje en 3D, 6 espacios, ataque y vida
---------------------------------------------------------------------
-- El personaje va en el hueco entre las dos columnas de espacios (lo ubica layoutHero)
local STATS_HEIGHT = 96 -- lugar que ocupa abajo la barra de ataque y vida
local SIDE_PAD, GAP = 12, 10
local avatarView = AvatarView.new(hero)
local viewport = avatarView.frame
local refreshAvatar = avatarView.refresh

-- Espacios: 3 a la izquierda y 3 a la derecha, como en Archero (tamaño en layoutHero)
local slotButtons = {}
local columns = {}
local function slotColumn(slots: { string }, left: boolean)
	local column = make("Frame", {
		AnchorPoint = Vector2.new(if left then 0 else 1, 0),
		Position = UDim2.new(if left then 0 else 1, if left then SIDE_PAD else -SIDE_PAD, 0, 10),
		Size = UDim2.new(0, 80, 1, -STATS_HEIGHT - 10),
		BackgroundTransparency = 1,
		Parent = hero,
	})
	local list = make("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = column })
	table.insert(columns, { frame = column, list = list })
	for i, slot in slots do
		local button = make("TextButton", {
			Size = UDim2.fromOffset(80, 80),
			BackgroundColor3 = Colors.Panel,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = i,
			Parent = column,
		}, { Theme.corner(10) })
		local stroke = Theme.stroke(Colors.GoldDark, 2)
		stroke.Parent = button
		local icon = text({ Size = UDim2.fromScale(1, 0.75), Text = Defs.SlotIcons[slot], TextScaled = true, Parent = button })
		make("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingLeft = UDim.new(0.15, 0), PaddingRight = UDim.new(0.15, 0), Parent = icon })
		local level = text({ Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.26), Text = "", Font = Fonts.Bold, TextScaled = true, TextStrokeTransparency = 0.3, Parent = button })
		slotButtons[slot] = { button = button, stroke = stroke, icon = icon, level = level }
	end
end
slotColumn({ "Weapon", "Helmet", "Armor" }, true)
slotColumn({ "Ring", "Amulet", "Boots" }, false)

-- Tamaño de los espacios según el lugar, y el personaje en el hueco del medio (sin pisarse)
local function layoutHero()
	local size = hero.AbsoluteSize
	local available = size.Y - STATS_HEIGHT - 10
	local gap = math.clamp(math.floor(available * 0.04), 4, 12)
	local slot = math.floor(math.clamp(math.min((available - gap * 2) / 3, size.X * 0.2), 40, 110))
	for _, c in columns do
		c.frame.Size = UDim2.new(0, slot, 1, -STATS_HEIGHT - 10)
		c.list.Padding = UDim.new(0, gap)
		for _, b in c.frame:GetChildren() do
			if b:IsA("GuiButton") then
				b.Size = UDim2.fromOffset(slot, slot)
			end
		end
	end
	local side = SIDE_PAD + slot + GAP
	viewport.Position = UDim2.fromOffset(side, 10)
	viewport.Size = UDim2.new(1, -side * 2, 1, -STATS_HEIGHT - 10)
end
hero:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutHero)

-- Ataque, vida y conjuntos (abajo del héroe)
local statsBar = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, STATS_HEIGHT - 18), BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.15, Parent = hero }, { Theme.corner(10) })
local attackLabel = text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.5, -12, 0, 30), Font = Fonts.Bold, TextSize = 22, TextColor3 = Colors.GoldBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = statsBar })
local healthLabel = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.new(0.5, -12, 0, 30), Font = Fonts.Bold, TextSize = 22, TextColor3 = Color3.fromRGB(255, 120, 120), TextXAlignment = Enum.TextXAlignment.Right, Parent = statsBar })
local extraLabel = text({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 20), TextSize = 13, TextColor3 = Colors.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, Parent = statsBar })
local setsLabel = text({ Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 20), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = statsBar })

-- Aviso del servidor ("Equipo actualizado", "Faltan oro o piedras"...)
local toast = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.5, 0, 0, 22), Text = "", Font = Fonts.Bold, TextSize = 14, TextColor3 = Colors.GoldBright, TextStrokeTransparency = 0.4, ZIndex = 5, Parent = hero })
local toastToken = 0
local function showToast(message: string?)
	toastToken += 1
	local token = toastToken
	toast.Text = message or ""
	task.delay(3, function()
		if toastToken == token then
			toast.Text = ""
		end
	end)
end

---------------------------------------------------------------------
-- Inventario: grilla ordenable
---------------------------------------------------------------------
local bagTitle = text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.5, 0, 0, 32), Font = Fonts.Heading, TextSize = 20, TextColor3 = Colors.GoldBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = bag })
local sortButton = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(150, 32), TextSize = 15, Parent = bag })
-- Reciclar en lote (solo comunes y poco comunes, nunca lo equipado). Doble toque para confirmar.
local bulkButtons = {}
for i, rarity in Defs.BulkRecycle do
	local button = Theme.button({ Position = UDim2.new((i - 1) / #Defs.BulkRecycle, 10, 0, 44), Size = UDim2.new(1 / #Defs.BulkRecycle, -16, 0, 32), TextSize = 14, Parent = bag })
	local confirmUntil = 0
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			send("RecycleRarity", rarity)
		else
			confirmUntil = os.clock() + 3
			button.Text = "¿Seguro? Tocá de nuevo"
		end
	end)
	bulkButtons[rarity] = button
end
local grid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 84),
	Size = UDim2.new(1, -16, 1, -92),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = bag,
})
make("UIGridLayout", { CellSize = UDim2.fromOffset(84, 84), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = grid })
local emptyLabel = text({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 100), Text = "No tenés objetos sin equipar. Conseguí más jugando partidas.", TextSize = 15, TextColor3 = Colors.TextMuted, TextWrapped = true, Visible = false, Parent = bag })

-- Tarjeta de un objeto: fondo del color de la rareza, ícono del espacio y nivel
local function itemCard(item, parent: Instance, order: number)
	local def = Defs.ById[item.Id]
	local color = Rarities.Colors[item.Rarity] or Rarities.Colors.Common
	local card = make("TextButton", {
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45),
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.corner(10), Theme.gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) })
	local stroke = Theme.stroke(color, if item.Uid == selectedUid then 3 else 2)
	stroke.Parent = card
	if item.Rarity == "Mythic" then
		stroke.Color = Color3.new(1, 1, 1)
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 120, 200), Color3.fromRGB(110, 200, 255)), Rotation = 45, Parent = stroke })
	end
	local icon = text({ Position = UDim2.fromScale(0.15, 0.06), Size = UDim2.fromScale(0.7, 0.62), Text = Defs.SlotIcons[def.Slot], TextScaled = true, Parent = card })
	icon.ZIndex = 2
	text({ Position = UDim2.fromScale(0, 0.68), Size = UDim2.fromScale(1, 0.3), Text = "Nv." .. item.Level, Font = Fonts.Bold, TextScaled = true, TextStrokeTransparency = 0.2, Parent = card })
	-- Letra del conjunto arriba a la izquierda
	text({ Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(18, 16), Text = string.sub(Defs.SetNames[def.Set] or "", 1, 1), Font = Fonts.Bold, TextSize = 13, TextColor3 = Colors.GoldBright, TextStrokeTransparency = 0.2, Parent = card })
	return card
end

---------------------------------------------------------------------
-- Detalle de un objeto (ventana encima)
---------------------------------------------------------------------
local detailShade = make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, AutoButtonColor = false, Visible = false, ZIndex = 10, Parent = window })
make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = detailShade })
-- Active: tocar dentro del detalle no llega al fondo (que lo cierra)
local detail = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 330), Active = true, ZIndex = 11, Parent = detailShade })
local function z(inst)
	inst.ZIndex = 12
	return inst
end
local detailIcon = z(make("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(72, 72), Parent = detail }, { Theme.corner(10) }))
local detailIconText = z(text({ Size = UDim2.fromScale(1, 1), TextScaled = true, Parent = detailIcon }))
make("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), Parent = detailIconText })
local detailName = z(text({ Position = UDim2.fromOffset(100, 14), Size = UDim2.new(1, -116, 0, 28), Font = Fonts.Bold, TextSize = 20, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail }))
local detailSub = z(text({ Position = UDim2.fromOffset(100, 44), Size = UDim2.new(1, -116, 0, 44), TextSize = 14, TextWrapped = true, TextColor3 = Colors.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail }))
local detailBody = z(text({ Position = UDim2.fromOffset(16, 98), Size = UDim2.new(1, -32, 0, 104), TextSize = 15, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail }))
local equipButton = z(Theme.button({ Position = UDim2.new(0, 16, 1, -116), Size = UDim2.new(0.5, -20, 0, 40), Text = "Equipar", TextSize = 18, Parent = detail }))
local recycleButton = z(Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -116), Size = UDim2.new(0.5, -20, 0, 40), TextSize = 14, TextWrapped = true, Parent = detail }))
local upgradeButton = z(Theme.button({ Position = UDim2.new(0, 16, 1, -66), Size = UDim2.new(0.5, -20, 0, 50), TextSize = 14, TextWrapped = true, Parent = detail }))
local fuseButton = z(Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -66), Size = UDim2.new(0.5, -20, 0, 50), TextSize = 14, TextWrapped = true, Parent = detail }))
local detailClose = z(Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(32, 28), Text = "×", TextSize = 20, Parent = detail }))
for _, b in { equipButton, recycleButton, upgradeButton, fuseButton, detailClose } do
	for _, d in b:GetChildren() do
		if d:IsA("GuiObject") then
			d.ZIndex = 12
		end
	end
end

local function setEnabled(button: TextButton, on: boolean)
	button.Active = on
	button.BackgroundColor3 = if on then Colors.Gold else Colors.Locked
	button.TextColor3 = if on then Color3.fromRGB(30, 22, 10) else Colors.TextMuted
end

-- Las 3 piezas para fusionar: este objeto + otras 2 iguales (mismo tipo y rareza)
local function fuseCandidates(item): { string }
	local list = { item.Uid }
	for _, other in inventory do
		if #list < 3 and other.Uid ~= item.Uid and other.Id == item.Id and other.Rarity == item.Rarity then
			table.insert(list, other.Uid)
		end
	end
	return list
end

local function closeDetail()
	selectedUid = nil
	confirmFuse = false
	confirmRecycle = false
	detailShade.Visible = false
end

local function refreshDetail()
	local item = findItem(selectedUid)
	local def = item and Defs.ById[item.Id]
	if not item or not def then
		closeDetail()
		return
	end
	local color = Rarities.Colors[item.Rarity] or Rarities.Colors.Common
	detailIcon.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.4)
	detailIconText.Text = Defs.SlotIcons[def.Slot]
	detailName.Text = def.Name
	Visuals.bind(detailName, item.Rarity)
	detailSub.Text = string.format("%s · %s · Nivel %d/%d", Rarities.Names[item.Rarity], Defs.SlotNames[def.Slot], item.Level, Defs.MaxLevel)

	local isEquipped = equipped[def.Slot] == item.Uid
	local now = Defs.itemBonus(item, rank(item))
	local lines = { string.format("<b>%s %s</b>", percent(now), Defs.StatNames[def.Stat]) }
	if item.Level < Defs.MaxLevel then
		local nextLevel = Defs.itemBonus({ Id = item.Id, Level = item.Level + 1 }, rank(item))
		table.insert(lines, string.format("<font color=\"#9be59b\">Próximo nivel: %s</font>", percent(nextLevel)))
	end
	local current = findItem(equipped[def.Slot])
	if not isEquipped and current then
		local diff = now - (if Defs.ById[current.Id].Stat == def.Stat then Defs.itemBonus(current, rank(current)) else 0)
		table.insert(lines, string.format("Equipado ahora: %s (%s)", Defs.ById[current.Id].Name, if diff >= 0 then percent(diff) else string.format("%.1f%%", diff * 100)))
	end
	local texts = Defs.SetBonusText[def.Set] or {}
	table.insert(lines, string.format("Conjunto %s: 3 piezas %s · 6 piezas %s", Defs.SetNames[def.Set] or def.Set, texts[3] or "", texts[6] or ""))
	detailBody.Text = table.concat(lines, "\n")

	equipButton.Text = if isEquipped then "Quitar" else "Equipar"
	setEnabled(equipButton, true)

	if isEquipped then
		recycleButton.Text = "Equipado"
		setEnabled(recycleButton, false)
	elseif confirmRecycle then
		recycleButton.Text = "¿Reciclar? Tocá de nuevo"
		setEnabled(recycleButton, true)
	else
		local recycleGold, recycleStones = Defs.recycleValue(item, rank(item))
		recycleButton.Text = "♻ +" .. recycleGold .. " 💰" .. (if recycleStones > 0 then " +" .. recycleStones .. " 🔷" else "")
		setEnabled(recycleButton, true)
	end

	local gold, stones = Defs.cost(item)
	if item.Level >= Defs.MaxLevel then
		upgradeButton.Text = "Nivel máximo"
		setEnabled(upgradeButton, false)
	else
		upgradeButton.Text = string.format("Mejorar\n💰 %d · 🔷 %d", gold, stones)
		setEnabled(upgradeButton, (player:GetAttribute("Gold") or 0) >= gold and (player:GetAttribute("Stones") or 0) >= stones)
	end

	local candidates = fuseCandidates(item)
	if item.Rarity == Rarities.Order[#Rarities.Order] then
		fuseButton.Text = "Rareza máxima"
		setEnabled(fuseButton, false)
	elseif confirmFuse then
		fuseButton.Text = "¿Confirmar?\nusa 3 piezas"
		setEnabled(fuseButton, true)
	else
		fuseButton.Text = string.format("Fusionar %d/3\n→ %s", #candidates, Rarities.Names[Rarities.Order[rank(item) + 1]])
		setEnabled(fuseButton, #candidates == 3)
	end
end

local function openDetail(uid: string)
	selectedUid = uid
	confirmFuse = false
	confirmRecycle = false
	detailShade.Visible = true
	Theme.popIn(detail)
	refreshDetail()
end

equipButton.Activated:Connect(function()
	local item = findItem(selectedUid)
	if not item then
		return
	end
	local slot = Defs.ById[item.Id].Slot
	if equipped[slot] == item.Uid then
		send("Unequip", slot)
	else
		send("Equip", item.Uid)
	end
	closeDetail()
end)
upgradeButton.Activated:Connect(function()
	if upgradeButton.Active and selectedUid then
		send("Upgrade", selectedUid)
	end
end)
fuseButton.Activated:Connect(function()
	local item = findItem(selectedUid)
	if not fuseButton.Active or not item then
		return
	end
	if not confirmFuse then
		confirmFuse = true
		refreshDetail()
	else
		confirmFuse = false
		send("Fuse", fuseCandidates(item))
	end
end)
recycleButton.Activated:Connect(function()
	if not recycleButton.Active or not selectedUid then
		return
	end
	if not confirmRecycle then
		confirmRecycle = true
		refreshDetail()
	else
		send("Recycle", selectedUid)
		closeDetail()
	end
end)
detailClose.Activated:Connect(closeDetail)
detailShade.Activated:Connect(closeDetail)

---------------------------------------------------------------------
-- Redibujar todo
---------------------------------------------------------------------
local function refresh()
	refreshMoney()

	-- Espacios
	for _, slot in Defs.Slots do
		local ui = slotButtons[slot]
		local item = findItem(equipped[slot])
		if item then
			local color = Rarities.Colors[item.Rarity] or Rarities.Colors.Common
			ui.button.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45)
			ui.stroke.Color = color
			ui.icon.TextTransparency = 0
			ui.level.Text = "Nv." .. item.Level
		else
			ui.button.BackgroundColor3 = Colors.Panel
			ui.stroke.Color = Colors.GoldDark
			ui.icon.TextTransparency = 0.7
			ui.level.Text = Defs.SlotNames[slot]
		end
	end

	-- Ataque, vida y el resto de bonificaciones
	-- Stats con las que empezás la partida: mismo cálculo y orden que el servidor (Run.start)
	local _, sets = Defs.summary(inventory, equipped, Rarities.index)
	local base = BaseStats.new()
	local final = BaseStats.new()
	Defs.apply(final, inventory, equipped, Rarities.index)
	for _, def in Talents.List do
		local level = talentLevels[def.Id] or 0
		if level > 0 then
			def.Apply(final, math.min(level, def.Max))
		end
	end
	RuneDefs.apply(final, runeOwned, runeActive, runeSlots)
	local function gain(stat: string): string
		local diff = math.floor(final[stat] + 0.5) - math.floor(base[stat] + 0.5)
		return if diff > 0 then string.format(" (+%d)", diff) else ""
	end
	attackLabel.Text = string.format("⚔ Ataque %d%s", math.floor(final.damage + 0.5), gain("damage"))
	healthLabel.Text = string.format("❤ Vida %d%s", math.floor(final.maxHealth + 0.5), gain("maxHealth"))
	extraLabel.Text = string.format(
		"Crítico %.1f%% · Daño crítico ×%.2f · Disparo cada %.2f s · Velocidad %.1f · Imán %.1f",
		final.critChance * 100,
		final.critMultiplier,
		final.attackInterval,
		final.walkSpeed,
		final.pickupRadius
	)
	local setTexts = {}
	for id, name in Defs.SetNames do
		local count = sets[id] or 0
		local hex = if count >= 3 then "#f6d07a" else "#a0968a"
		table.insert(setTexts, string.format("<font color=\"%s\">%s %d/6</font>", hex, name, count))
	end
	table.sort(setTexts)
	setsLabel.Text = "Conjuntos: " .. table.concat(setTexts, " · ")

	-- Grilla: lo que no está equipado
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local isEquipped = {}
	for _, uid in equipped do
		isEquipped[uid] = true
	end
	local bagItems = {}
	for _, item in inventory do
		if not isEquipped[item.Uid] and Defs.ById[item.Id] then
			table.insert(bagItems, item)
		end
	end
	local slotOrder = {}
	for i, slot in Defs.Slots do
		slotOrder[slot] = i
	end
	table.sort(bagItems, function(a, b)
		local sa, sb = slotOrder[Defs.ById[a.Id].Slot], slotOrder[Defs.ById[b.Id].Slot]
		if sortBy == "Slot" and sa ~= sb then
			return sa < sb
		end
		if rank(a) ~= rank(b) then
			return rank(a) > rank(b)
		end
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		if sa ~= sb then
			return sa < sb
		end
		return a.Uid < b.Uid
	end)
	for i, item in bagItems do
		local card = itemCard(item, grid, i)
		card.Activated:Connect(function()
			openDetail(item.Uid)
		end)
	end
	emptyLabel.Visible = #bagItems == 0
	for rarity, button in bulkButtons do
		local count = 0
		for _, item in bagItems do
			if item.Rarity == rarity then
				count += 1
			end
		end
		button.Text = "♻ " .. Rarities.Names[rarity] .. " (" .. count .. ")"
		setEnabled(button, count > 0)
	end
	bagTitle.Text = string.format("Inventario %d/%d", #inventory, Defs.MaxInventory)
	sortButton.Text = if sortBy == "Rarity" then "Orden: rareza" else "Orden: tipo"

	if detailShade.Visible then
		refreshDetail()
	end
end

for slot, ui in slotButtons do
	ui.button.Activated:Connect(function()
		local uid = equipped[slot]
		if findItem(uid) then
			openDetail(uid)
		else
			showToast("Elegí un objeto de " .. string.lower(Defs.SlotNames[slot]) .. " del inventario para equiparlo.")
		end
	end)
end
sortButton.Activated:Connect(function()
	sortBy = if sortBy == "Rarity" then "Slot" else "Rarity"
	refresh()
end)

---------------------------------------------------------------------
-- Distribución: en pantallas anchas lado a lado, en angostas uno arriba del otro
---------------------------------------------------------------------
local function layout()
	local size = window.AbsoluteSize
	local top, pad = 50, 10
	local bottom = pad + MenuTabs.Height -- lugar para las pestañas de abajo
	if size.X > size.Y * 1.25 then
		local heroWidth = math.floor((size.X - pad * 3) * 0.48)
		hero.Position = UDim2.fromOffset(pad, top)
		hero.Size = UDim2.new(0, heroWidth, 1, -top - bottom)
		bag.Position = UDim2.fromOffset(pad * 2 + heroWidth, top)
		bag.Size = UDim2.new(1, -heroWidth - pad * 3, 1, -top - bottom)
	else
		local heroHeight = math.floor((size.Y - top - pad - bottom) * 0.55)
		hero.Position = UDim2.fromOffset(pad, top)
		hero.Size = UDim2.new(1, -pad * 2, 0, heroHeight)
		bag.Position = UDim2.fromOffset(pad, top + heroHeight + pad)
		bag.Size = UDim2.new(1, -pad * 2, 1, -top - heroHeight - pad - bottom)
	end
	layoutHero()
end
window:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

---------------------------------------------------------------------
MenuTabs.new(window, "Equipo")

---------------------------------------------------------------------
-- Abrir y cerrar (el botón Equipo del lobby y las pestañas ponen EquipmentTab = "Equipo")
---------------------------------------------------------------------
local function closeWindow()
	gui.Enabled = false
	closeDetail()
	playerGui:SetAttribute("EquipmentTab", nil)
end
close.Activated:Connect(closeWindow)

remotes:WaitForChild("TalentState").OnClientEvent:Connect(function(levels)
	talentLevels = if type(levels) == "table" then levels else {}
	if gui.Enabled then
		refresh()
	end
end)
remotes:WaitForChild("RuneState").OnClientEvent:Connect(function(owned, active, slots)
	runeOwned, runeActive, runeSlots = owned or {}, active or {}, slots or 1
	if gui.Enabled then
		refresh()
	end
end)

remotes:WaitForChild("EquipmentState").OnClientEvent:Connect(function(items, slots, notice)
	inventory, equipped = items or {}, slots or {}
	if notice then
		showToast(notice)
	end
	refresh()
end)
playerGui:GetAttributeChangedSignal("EquipmentTab"):Connect(function()
	gui.Enabled = playerGui:GetAttribute("EquipmentTab") == "Equipo" and player:GetAttribute("InMatch") ~= true
	if gui.Enabled then
		send("Get")
		-- Talentos y runas al día para calcular las stats
		remotes.TalentRequest:FireServer("Get")
		remotes.RuneRequest:FireServer("Get")
		refreshAvatar()
		refresh()
		layout()
		Theme.popIn(window)
	else
		closeDetail()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		closeWindow()
	end
end)
