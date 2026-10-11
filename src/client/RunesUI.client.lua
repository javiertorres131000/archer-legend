-- RunesUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > RunesUI
-- Pantalla de Runas estilo Archero 2: tu personaje en 3D en el medio, las 12 runas de colección
-- alrededor (6 por lado) y abajo los 3 espacios de runas especiales. Tocás una runa y aparece
-- el detalle; tocás un espacio y elegís qué especial poner. Arriba, el cofre de runas (gemas).
-- Todo lo valida el servidor (Runes.lua): esta pantalla pide por RuneRequest y se redibuja con RuneState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared:WaitForChild("RuneDefs"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Theme = require(Shared:WaitForChild("UITheme"))
local Visuals = require(script.Parent.RarityVisuals)
local AvatarView = require(script.Parent.AvatarView)
local MenuTabs = require(script.Parent.MenuTabs)

local Colors, Fonts = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("RuneRequest") :: RemoteEvent

local owned: { [string]: number } = {}
local active: { string } = {}
local openSlots = 1

local PURPLE = Color3.fromRGB(46, 30, 72)
local PURPLE_DARK = Color3.fromRGB(26, 18, 42)

local function send(action: string, a: any?, b: any?)
	request:FireServer(action, a, b)
end

local function rarityColor(rarity: string): Color3
	return Rarities.Colors[rarity] or Rarities.Colors.Common
end

local function chapterName(id: string): string
	for _, ch in Chapters do
		if ch.Id == id then
			return ch.Name
		end
	end
	return id
end

---------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------
local gui = make("ScreenGui", { Name = "RunesUI", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false, IgnoreGuiInset = true, Parent = playerGui })
local backdrop = make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", Modal = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, AutoButtonColor = false, Parent = gui })
local window = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.92), Parent = backdrop })
make("UISizeConstraint", { MaxSize = Vector2.new(1000, 760), Parent = window })

-- Barra superior: título, monedas y cerrar
local topBar = make("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = window })
text({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(0.4, 0, 0, 34), Text = "RUNAS", Font = Fonts.Title, TextSize = 28, TextColor3 = Colors.GoldBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = topBar })
local moneyRow = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -62, 0, 8), Size = UDim2.new(0.6, -70, 0, 30), BackgroundTransparency = 1, Parent = topBar })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), Parent = moneyRow })
local moneyLabels = {}
for _, c in Currencies do
	if c.Id == "Gold" then
		continue -- las runas usan gemas (cofre) y dan piedras (repetidas)
	end
	local chip = make("Frame", { Size = UDim2.fromOffset(110, 30), BackgroundColor3 = Colors.PanelLight, Parent = moneyRow }, { Theme.corner(15), Theme.stroke(Colors.GoldDark, 1) })
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

-- Tablero violeta con el personaje, el anillo de runas y los espacios
local board = make("Frame", {
	Position = UDim2.fromOffset(10, 50),
	Size = UDim2.new(1, -20, 1, -50 - 10 - MenuTabs.Height),
	BackgroundColor3 = PURPLE,
	ClipsDescendants = true,
	Parent = window,
}, { Theme.corner(12), Theme.stroke(Color3.fromRGB(110, 80, 160), 1.5), Theme.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 110, 140)) })
-- Círculo de fondo detrás del personaje
local halo = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = PURPLE_DARK, BackgroundTransparency = 0.35, Parent = board }, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = halo })

local avatarView = AvatarView.new(board)
local viewport = avatarView.frame

-- Botones de arriba del tablero: resumen (i) y cofre
local infoButton = Theme.button({ Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(36, 36), Text = "i", TextSize = 22, ZIndex = 3, Parent = board })
local chestButton = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(190, 36), TextSize = 15, ZIndex = 3, Parent = board })

-- Aviso del servidor
local toast = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.5, 0, 0, 22), Text = "", Font = Fonts.Bold, TextSize = 15, TextColor3 = Colors.GoldBright, TextStrokeTransparency = 0.3, ZIndex = 4, Parent = board })
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
-- Runas de colección (anillo alrededor del personaje)
---------------------------------------------------------------------
local badges: { [string]: any } = {}
local openDetail: (string) -> ()

for _, def in Defs.Collection do
	local button = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Text = "", AutoButtonColor = true, ZIndex = 2, Parent = board })
	make("UICorner", { CornerRadius = UDim.new(0.32, 0), Parent = button })
	local stroke = Theme.stroke(rarityColor(def.Rarity), 3)
	stroke.Parent = button
	local gradient = make("UIGradient", { Rotation = 90, Parent = button })
	local icon = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.62, 0.62), Text = def.Icon, TextScaled = true, ZIndex = 3, Parent = button })
	-- Con imagen subida (RuneDefs.Images) se ve la imagen en vez del emoji
	local image = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		BackgroundTransparency = 1,
		Image = def.Image,
		ScaleType = Enum.ScaleType.Crop,
		Visible = def.Image ~= "",
		ZIndex = 2,
		Parent = button,
	}, { make("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
	icon.Visible = def.Image == ""
	local level = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromScale(0.9, 0.26), Text = "", Font = Fonts.Bold, TextScaled = true, TextStrokeTransparency = 0.2, ZIndex = 3, Parent = button })
	local scale = make("UIScale", { Parent = button })
	badges[def.Id] = { button = button, stroke = stroke, gradient = gradient, icon = icon, image = image, level = level, scale = scale }
	button.Activated:Connect(function()
		openDetail(def.Id)
	end)
end

---------------------------------------------------------------------
-- Espacios de runas especiales (rombos de abajo)
---------------------------------------------------------------------
local slots = {}
local openSlotPicker: (number) -> ()
for i = 1, Defs.ActiveSlots do
	local button = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Text = "", BackgroundTransparency = 1, ZIndex = 2, Parent = board })
	-- El rombo es un cuadrado girado; el ícono va encima sin girar
	local diamond = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), Rotation = 45, BackgroundColor3 = PURPLE_DARK, ZIndex = 2, Parent = button }, { Theme.corner(10) })
	local stroke = Theme.stroke(Color3.fromRGB(110, 80, 160), 3)
	stroke.Parent = diamond
	local icon = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), TextScaled = true, ZIndex = 3, Parent = button })
	local caption = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1.6, 0, 0, 16), TextSize = 12, TextColor3 = Colors.TextMuted, TextStrokeTransparency = 0.5, ZIndex = 3, Parent = button })
	slots[i] = { button = button, diamond = diamond, stroke = stroke, icon = icon, caption = caption }
	button.Activated:Connect(function()
		openSlotPicker(i)
	end)
end

---------------------------------------------------------------------
-- Distribución: 6 runas por lado (4 afuera en arco + 2 adentro), personaje al medio
---------------------------------------------------------------------
local function layoutBoard()
	local w, h = board.AbsoluteSize.X, board.AbsoluteSize.Y
	if w < 1 or h < 1 then
		return
	end
	local diamondSize = math.floor(math.clamp(math.min(w, h) * 0.17, 56, 104))
	local ringTop, ringBottom = 54, h - diamondSize - 14
	local ringH = ringBottom - ringTop
	local s = math.floor(math.clamp(math.min(ringH / 4.3, w * 0.1), 40, 86))
	local gap = math.max(10, math.floor(s * 0.25) + 2)
	local pad = 12
	local step = (ringH - s) / 3
	local outerX = pad + s / 2
	local innerX = outerX + s + gap
	local positions = {}
	for k = 0, 3 do
		local bump = if k == 0 or k == 3 then s * 0.25 else 0 -- los extremos se curvan hacia adentro
		table.insert(positions, Vector2.new(outerX + bump, ringTop + s / 2 + k * step))
	end
	table.insert(positions, Vector2.new(innerX, ringTop + s / 2 + step * 0.5))
	table.insert(positions, Vector2.new(innerX, ringTop + s / 2 + step * 2.5))
	for i, def in Defs.Collection do
		local side = if i <= 6 then 1 else 2
		local pos = positions[(i - 1) % 6 + 1]
		local x = if side == 1 then pos.X else w - pos.X
		local b = badges[def.Id].button
		b.Position = UDim2.fromOffset(x, pos.Y)
		b.Size = UDim2.fromOffset(s, s)
	end
	-- Personaje en el hueco del medio
	local sideWidth = innerX + s / 2 + 8
	local avatarW = math.max(60, w - sideWidth * 2)
	viewport.Position = UDim2.fromOffset(sideWidth, ringTop - 10)
	viewport.Size = UDim2.fromOffset(avatarW, ringH + 4)
	halo.Position = UDim2.fromOffset(w / 2, ringTop + ringH / 2)
	halo.Size = UDim2.fromOffset(math.min(avatarW, ringH) * 0.95, math.min(avatarW, ringH) * 0.95)
	-- Rombos abajo al centro
	for i, slot in slots do
		local x = w / 2 + (i - (Defs.ActiveSlots + 1) / 2) * diamondSize * 1.15
		slot.button.Position = UDim2.fromOffset(x, h - diamondSize / 2 - 14)
		slot.button.Size = UDim2.fromOffset(diamondSize, diamondSize)
	end
end
board:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBoard)

---------------------------------------------------------------------
-- Ventana de detalle (runa, elegir especial, resumen)
---------------------------------------------------------------------
local shade = make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, AutoButtonColor = false, Visible = false, ZIndex = 10, Parent = window })
make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = shade })
-- Active: tocar dentro del detalle no llega al fondo (que lo cierra)
local panel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 360), Active = true, ZIndex = 11, Parent = shade })
local panelTitle = text({ Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -70, 0, 30), Font = Fonts.Bold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = panel })
local panelSub = text({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 20), TextSize = 14, TextColor3 = Colors.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = panel })
local panelBody = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 74),
	Size = UDim2.new(1, -24, 1, -86),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 12,
	Parent = panel,
})
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panelBody })
local panelClose = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(32, 28), Text = "×", TextSize = 20, ZIndex = 12, Parent = panel })

local function closePanel()
	shade.Visible = false
end
panelClose.Activated:Connect(closePanel)
shade.Activated:Connect(closePanel)

local function openPanel(title: string, sub: string, rarity: string?)
	for _, child in panelBody:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	panelTitle.Text = title
	if rarity then
		Visuals.bind(panelTitle, rarity)
	else
		panelTitle.TextColor3 = Colors.GoldBright
	end
	panelSub.Text = sub
	shade.Visible = true
	Theme.popIn(panel)
end

local function bodyText(textValue: string, order: number)
	return text({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = textValue, TextSize = 15, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 12, Parent = panelBody })
end

local function bodyButton(label: string, order: number, enabled: boolean, onClick: () -> ())
	local b = Theme.button({ Size = UDim2.new(1, -8, 0, 44), Text = label, TextSize = 15, TextWrapped = true, LayoutOrder = order, ZIndex = 12, Parent = panelBody })
	for _, d in b:GetChildren() do
		if d:IsA("GuiObject") then
			d.ZIndex = 12
		end
	end
	b.Active = enabled
	if not enabled then
		b.BackgroundColor3 = Colors.Locked
		b.TextColor3 = Colors.TextMuted
	end
	b.Activated:Connect(function()
		if b.Active then
			onClick()
		end
	end)
	return b
end

local HOW_TO_GET = "Se consiguen abriendo cofres de runas (arriba a la derecha) y como botín de jefes. Ganar un capítulo por primera vez da una segura."

-- Detalle de una runa de colección
openDetail = function(id: string)
	local def = Defs.ById[id]
	local level = owned[id] or 0
	openPanel(def.Icon .. "  " .. def.Name, string.format("%s · Runa de colección", Rarities.Names[def.Rarity] or def.Rarity), def.Rarity)
	if level > 0 then
		bodyText(string.format("<b>Nivel %d/%d</b>\nAhora: <b>%s</b>", level, Defs.MaxLevel, Defs.describe(def, level)), 1)
		if level < Defs.MaxLevel then
			bodyText(string.format("<font color=\"#9be59b\">Próximo nivel: %s</font>\nConseguí esta runa otra vez para subirla.", Defs.describe(def, level + 1)), 2)
		else
			bodyText(string.format("Nivel máximo. Si te vuelve a salir, recibís %d 🔷 piedras.", Defs.DuplicateStones), 2)
		end
	else
		bodyText(string.format("Todavía no la tenés.\nNivel 1: %s · Nivel %d: %s", Defs.describe(def, 1), Defs.MaxLevel, Defs.describe(def, Defs.MaxLevel)), 1)
		bodyText(HOW_TO_GET, 2)
	end
	bodyText("Las runas de colección funcionan solas: no hace falta equiparlas.", 3)
end

-- Elegir qué runa especial va en un espacio
openSlotPicker = function(slot: number)
	if slot > openSlots then
		local need = Defs.SlotUnlocks[slot]
		openPanel("🔒  Espacio " .. slot, "Espacio de runa especial bloqueado")
		bodyText(string.format("Ganá <b>%s</b> para desbloquear este espacio.", if need then chapterName(need) else "?"), 1)
		return
	end
	openPanel("Espacio " .. slot, "Elegí una runa especial")
	local order = 1
	if active[slot] and active[slot] ~= "" then
		bodyButton("Quitar " .. Defs.ById[active[slot]].Name, order, true, function()
			send("Unequip", slot)
			closePanel()
		end)
		order += 1
	end
	local any = false
	for _, def in Defs.Special do
		if owned[def.Id] then
			any = true
			local where = table.find(active, def.Id)
			local label = string.format("%s  %s — %s", def.Icon, def.Name, def.Text)
			if where == slot then
				label ..= "  ✔"
			elseif where then
				label ..= string.format("  (en espacio %d)", where)
			end
			bodyButton(label, order, where ~= slot, function()
				send("Equip", slot, def.Id)
				closePanel()
			end)
			order += 1
		end
	end
	if not any then
		bodyText("No tenés runas especiales todavía.\n" .. HOW_TO_GET, order)
		order += 1
	end
	-- Las que faltan, para saber qué se puede conseguir
	local missing = {}
	for _, def in Defs.Special do
		if not owned[def.Id] then
			table.insert(missing, def.Icon .. " " .. def.Name)
		end
	end
	if #missing > 0 then
		bodyText("<font color=\"#a0968a\">Por conseguir: " .. table.concat(missing, " · ") .. "</font>", order)
	end
end

-- Resumen de todo lo que dan las runas
infoButton.Activated:Connect(function()
	local count = 0
	for _, def in Defs.Collection do
		if owned[def.Id] then
			count += 1
		end
	end
	openPanel("Tus runas", string.format("Colección %d/%d · Espacios abiertos %d/%d", count, #Defs.Collection, openSlots, Defs.ActiveSlots))
	local lines = {}
	for _, def in Defs.Collection do
		if owned[def.Id] then
			table.insert(lines, string.format("%s %s Nv.%d: %s", def.Icon, def.Name, owned[def.Id], Defs.describe(def, owned[def.Id])))
		end
	end
	bodyText(if #lines > 0 then table.concat(lines, "\n") else "Todavía no tenés runas de colección.", 1)
	local specials = {}
	for i = 1, openSlots do
		local def = Defs.ById[active[i] or ""]
		if def then
			table.insert(specials, string.format("%s %s: %s", def.Icon, def.Name, def.Text))
		end
	end
	bodyText("<b>Especiales activas</b>\n" .. (if #specials > 0 then table.concat(specials, "\n") else "Ninguna."), 2)
	bodyText(HOW_TO_GET, 3)
end)

---------------------------------------------------------------------
-- Cofre de runas (pide confirmación: gasta gemas)
---------------------------------------------------------------------
local confirmChest = false
local function refreshChest()
	local gems = player:GetAttribute("Gems") or 0
	chestButton.Text = if confirmChest then string.format("¿Abrir por 💎 %d?", Defs.ChestCost) else string.format("🎁 Cofre de runas · 💎 %d", Defs.ChestCost)
	local can = gems >= Defs.ChestCost
	chestButton.Active = can
	chestButton.BackgroundColor3 = if can then Colors.Gold else Colors.Locked
	chestButton.TextColor3 = if can then Color3.fromRGB(30, 22, 10) else Colors.TextMuted
end
player:GetAttributeChangedSignal("Gems"):Connect(refreshChest)
chestButton.Activated:Connect(function()
	if not chestButton.Active then
		showToast(string.format("Necesitás %d gemas para abrir el cofre.", Defs.ChestCost))
		return
	end
	if not confirmChest then
		confirmChest = true
		refreshChest()
		task.delay(3, function()
			confirmChest = false
			refreshChest()
		end)
	else
		confirmChest = false
		refreshChest()
		send("OpenChest")
	end
end)

---------------------------------------------------------------------
-- Redibujar
---------------------------------------------------------------------
local function refresh()
	refreshMoney()
	refreshChest()
	for _, def in Defs.Collection do
		local b = badges[def.Id]
		local level = owned[def.Id] or 0
		local color = rarityColor(def.Rarity)
		if level > 0 then
			b.button.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
			b.gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 160))
			b.stroke.Color = color
			b.stroke.Transparency = 0
			b.icon.TextTransparency = 0
			b.image.ImageColor3 = Color3.new(1, 1, 1)
			b.image.ImageTransparency = 0
			b.level.Text = "Nv." .. level
		else
			b.button.BackgroundColor3 = PURPLE_DARK
			b.gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
			b.stroke.Color = color
			b.stroke.Transparency = 0.6
			b.icon.TextTransparency = 0.75
			-- Sin conseguir: la imagen apagada y en gris
			b.image.ImageColor3 = Color3.fromRGB(110, 105, 120)
			b.image.ImageTransparency = 0.45
			b.level.Text = ""
		end
	end
	for i, slot in slots do
		local def = Defs.ById[active[i] or ""]
		if i > openSlots then
			slot.diamond.BackgroundColor3 = PURPLE_DARK
			slot.stroke.Color = Color3.fromRGB(80, 64, 110)
			slot.icon.Text = "🔒"
			slot.icon.TextTransparency = 0.2
			local need = Defs.SlotUnlocks[i]
			slot.caption.Text = if need then "Ganá " .. chapterName(need) else ""
		elseif def then
			local color = rarityColor(def.Rarity)
			slot.diamond.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
			slot.stroke.Color = color
			slot.icon.Text = def.Icon
			slot.icon.TextTransparency = 0
			slot.caption.Text = def.Name
		else
			slot.diamond.BackgroundColor3 = PURPLE_DARK
			slot.stroke.Color = Colors.Gold
			slot.icon.Text = "＋"
			slot.icon.TextTransparency = 0.3
			slot.caption.Text = "Vacío"
		end
	end
end

-- Resalta la runa recién conseguida
local function pulse(id: string?)
	local b = id and badges[id]
	if b then
		b.scale.Scale = 1.35
		TweenService:Create(b.scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	if id and Defs.ById[id] and Defs.ById[id].Kind == "Special" then
		for _, slot in slots do
			slot.diamond.Size = UDim2.fromScale(0.85, 0.85)
			TweenService:Create(slot.diamond, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.7, 0.7) }):Play()
		end
	end
end

---------------------------------------------------------------------
-- Abrir y cerrar (botón Runas del lobby y pestañas: EquipmentTab = "Runas")
---------------------------------------------------------------------
MenuTabs.new(window, "Runas")

local function closeWindow()
	gui.Enabled = false
	closePanel()
	playerGui:SetAttribute("EquipmentTab", nil)
end
close.Activated:Connect(closeWindow)

remotes:WaitForChild("RuneState").OnClientEvent:Connect(function(newOwned, newActive, slotCount, notice, justGot)
	owned, active, openSlots = newOwned or {}, newActive or {}, slotCount or 1
	if notice then
		showToast(notice)
	end
	refresh()
	if gui.Enabled then
		pulse(justGot)
	end
end)
playerGui:GetAttributeChangedSignal("EquipmentTab"):Connect(function()
	gui.Enabled = playerGui:GetAttribute("EquipmentTab") == "Runas" and player:GetAttribute("InMatch") ~= true
	if gui.Enabled then
		send("Get")
		avatarView.refresh()
		refresh()
		layoutBoard()
		Theme.popIn(window)
	else
		closePanel()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		closeWindow()
	end
end)
refresh()
