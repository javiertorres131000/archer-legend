--!strict
-- CrateUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > CrateUI
-- Menú "CRATES" de la plaza volcánica. Se abre con el ProximityPrompt de cualquier plataforma
-- (con esa caja ya elegida). Dos pestañas:
--   · Skin Crates / Pet Eggs: cofres de skins y huevos de mascotas (Crates.lua, Type). Una tarjeta por caja (cofre que gira con el brillo de su color, nombre,
--     precio y OPEN) y abajo los DROP RATES de la caja elegida (barra proporcional y %).
--   · Index: todos los premios; los que todavía no tenés se ven como silueta.
-- Solo muestra y pide: OPEN manda ("Open", Id) a Remotes.CrateRequest y el servidor decide
-- todo (monedas, límite, premio). Con la respuesta arranca la animación (CrateCinematic).
-- El botón R$ pide ("BuyRobux", Id): el servidor muestra la compra de Roblox y, cuando llega el
-- recibo, avisa por Remotes.CrateOpened con el premio (y recién ahí arranca la animación).
-- En Index, EQUIP equipa una mascota o un personaje (uno de cada uno; ver CrateEquip).
-- Además hace flotar y girar los cofres de las plataformas (solo en esta pantalla).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Crates = require(Shared:WaitForChild("Crates"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local CrateModels = require(Shared:WaitForChild("CrateModels"))
local CrateCinematic = require(script.Parent:WaitForChild("CrateCinematic"))
local EggCinematic = require(script.Parent:WaitForChild("EggCinematic"))

-- ¿Hay alguna animación de apertura en curso?
local function anyPlaying(): boolean
	return CrateCinematic.isPlaying() or EggCinematic.isPlaying()
end

-- Cofres: animación de la arena; huevos: animación del huevo
local function playOpening(crate: Crates.Crate, result: { [string]: any }, onDone: () -> ())
	local r = { Prize = result.Prize, Count = result.Count, New = result.New == true }
	if Crates.isEgg(crate) then
		EggCinematic.play(crate, r, onDone)
	else
		CrateCinematic.play(crate, r, onDone)
	end
end
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("CrateRequest") :: RemoteFunction
local crateOpened = remotes:WaitForChild("CrateOpened") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local CURRENCY = Config.Crates.Currency

local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local PANEL = C(17, 15, 22)
local CARD = C(28, 25, 35)
local CARD_SELECTED = C(38, 34, 50)
local TEXT = C(242, 238, 232)
local MUTED = C(150, 145, 160)
local ACCENT = C(255, 128, 50)
local DANGER = C(255, 90, 90)
local GOLD = C(255, 205, 70)
local ROBUX = C(0, 176, 111) -- verde de Roblox
local W, H = 940, 660 -- tamaño base del panel (después se escala a la pantalla)
local KIND_NAMES = { Unit = "Unidad", Pet = "Mascota", Character = "Personaje" }

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: UDim?)
	make("UICorner", { CornerRadius = radius or UDim.new(0, 10) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or TEXT
	return make("TextLabel", props, parent)
end

-- Moneda dibujada (círculo dorado con borde)
local function coin(parent: Instance, size: number): Frame
	local f = make("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = GOLD, BorderSizePixel = 0 }, parent) :: Frame
	corner(f, UDim.new(1, 0))
	stroke(f, C(170, 110, 20), math.max(1, size / 10))
	make("UIGradient", { Color = ColorSequence.new(C(255, 240, 160), C(235, 160, 40)), Rotation = 90 }, f)
	local inner = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.55),
		BackgroundTransparency = 1,
	}, f)
	corner(inner, UDim.new(1, 0))
	stroke(inner, C(200, 135, 30), math.max(1, size / 14), 0.2)
	return f
end

-- Vista 3D de un modelo dentro de un ViewportFrame. Devuelve la cámara para girarla.
local function viewport(parent: Instance, model: Model, size: UDim2, position: UDim2, distance: number, height: number): (ViewportFrame, Camera, Vector3)
	local vf = make("ViewportFrame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Ambient = C(170, 160, 170),
		LightColor = C(255, 240, 225),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, parent) :: ViewportFrame
	model:PivotTo(CFrame.new())
	model.Parent = vf
	local cam = make("Camera", { FieldOfView = 30 }, vf) :: Camera
	vf.CurrentCamera = cam
	local focus = Vector3.new(0, height, 0)
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, distance * 0.25, -distance), focus)
	return vf, cam, focus
end

---------------------------------------------------------------------
-- Estructura
---------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "CrateUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
	Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

local dim = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C(0, 0, 0),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	BorderSizePixel = 0,
}, gui) :: TextButton

local holder = make("Frame", {
	Name = "Holder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 1,
}, gui) :: Frame
local fitScale = make("UIScale", {}, holder) :: UIScale
make("UIAspectRatioConstraint", { AspectRatio = W / H }, holder)

local panel = make("Frame", {
	Name = "Panel",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
}, holder) :: Frame
corner(panel, UDim.new(0, 16))
stroke(panel, WHITE, 1, 0.82)
make("UIGradient", { Color = ColorSequence.new(C(255, 255, 255), C(200, 190, 205)), Rotation = 90 }, panel)
local popScale = make("UIScale", {}, panel) :: UIScale

-- Brillo cálido detrás del título
local headerGlow = make("Frame", {
	Size = UDim2.new(1, 0, 0, 90),
	BackgroundColor3 = ACCENT,
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
}, panel)
corner(headerGlow, UDim.new(0, 16))
make("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
}, headerGlow)

local title = label(panel, {
	Position = UDim2.fromOffset(28, 16),
	Size = UDim2.fromOffset(220, 40),
	Font = Enum.Font.GothamBlack,
	Text = "🔥 CRATES",
	TextSize = 32,
	TextColor3 = C(255, 170, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
})
stroke(title, C(90, 20, 0), 1.5, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

-- Pestañas
local tabBar = make("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(250, 18),
	Size = UDim2.fromOffset(420, 38),
	BackgroundColor3 = C(10, 9, 14),
	BorderSizePixel = 0,
}, panel)
corner(tabBar, UDim.new(1, 0))
stroke(tabBar, WHITE, 1, 0.9)
make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, tabBar)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
local tabButtons: { [string]: TextButton } = {}
for order, tab in { { "Shop", "Skin Crates" }, { "Eggs", "Pet Eggs" }, { "Index", "Index" } } do
	local b = make("TextButton", {
		Name = tab[1],
		LayoutOrder = order,
		Size = UDim2.new(1 / 3, -3, 1, 0),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBlack,
		Text = tab[2],
		TextSize = 16,
		TextColor3 = MUTED,
	}, tabBar) :: TextButton
	corner(b, UDim.new(1, 0))
	tabButtons[tab[1]] = b
end

-- Monedas
local wallet = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -78, 0, 18),
	Size = UDim2.fromOffset(170, 38),
	BackgroundColor3 = C(10, 9, 14),
	BorderSizePixel = 0,
}, panel)
corner(wallet, UDim.new(1, 0))
stroke(wallet, GOLD, 1, 0.7)
local walletCoin = coin(wallet, 22)
walletCoin.AnchorPoint = Vector2.new(0, 0.5)
walletCoin.Position = UDim2.new(0, 10, 0.5, 0)
local walletText = label(wallet, {
	Position = UDim2.fromOffset(40, 0),
	Size = UDim2.new(1, -50, 1, 0),
	Font = Enum.Font.GothamBlack,
	Text = "0",
	TextSize = 19,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- Cerrar
local closeButton = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -22, 0, 18),
	Size = UDim2.fromOffset(38, 38),
	BackgroundColor3 = C(40, 36, 48),
	AutoButtonColor = false,
	Font = Enum.Font.GothamBlack,
	Text = "X",
	TextSize = 20,
	TextColor3 = TEXT,
}, panel) :: TextButton
corner(closeButton, UDim.new(0, 10))
stroke(closeButton, WHITE, 1, 0.85)

make("Frame", {
	Position = UDim2.fromOffset(24, 72),
	Size = UDim2.new(1, -48, 0, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
}, panel)

local pages = make("Frame", {
	Name = "Pages",
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 1, -80),
	BackgroundTransparency = 1,
}, panel)
local shopPage = make("Frame", { Name = "ShopPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pages) :: Frame
local indexPage = make("Frame", { Name = "IndexPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, pages) :: Frame

---------------------------------------------------------------------
-- Shop: tarjetas
---------------------------------------------------------------------
type Card = {
	crate: Crates.Crate,
	button: TextButton,
	stroke: UIStroke,
	scale: UIScale,
	glows: { Frame },
	price: TextLabel,
	open: TextButton,
	robux: TextButton,
	cam: Camera,
	focus: Vector3,
	hover: boolean,
}

local cards: { Card } = {}
local robuxPrices: { [string]: string } = {} -- precio en Robux de cada caja (lo dice Roblox)
local busy = false
-- Pestaña de compra actual ("Crate" cofres de skins | "Egg" huevos) y lo elegido en cada una
local shopType = "Crate"
local lastSelected: { [string]: string } = {}
for _, crate in Crates.List do
	lastSelected[crate.Type] = lastSelected[crate.Type] or crate.Id
end
local selectedId = lastSelected.Crate

local rows: { [string]: Frame } = {}
for _, info in { { "Crate", "Cards" }, { "Egg", "Eggs" } } do
	local row = make("Frame", {
		Name = info[2],
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 240),
		BackgroundTransparency = 1,
		Visible = info[1] == "Crate",
	}, shopPage) :: Frame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	rows[info[1]] = row
end

local message = label(shopPage, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -40, 0, 22),
	Text = "",
	TextSize = 16,
	TextColor3 = DANGER,
})

local refreshCards: () -> ()
local refreshRates: () -> ()
local requestOpen: (Crates.Crate) -> ()
local requestRobux: (Crates.Crate) -> ()

local function select(id: string)
	if selectedId == id then
		return
	end
	selectedId = id
	local crate = Crates.ById[id]
	if crate then
		lastSelected[crate.Type] = id
	end
	refreshCards()
	refreshRates()
end

for i, crate in Crates.List do
	local button = make("TextButton", {
		Name = crate.Id,
		LayoutOrder = i,
		Size = UDim2.fromOffset(164, 228),
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
	}, rows[crate.Type] or rows.Crate) :: TextButton
	corner(button, UDim.new(0, 14))
	local cardStroke = stroke(button, crate.Color, 1.5, 0.55)
	local cardScale = make("UIScale", {}, button) :: UIScale
	-- Brillo del color de la caja detrás del cofre (círculos superpuestos)
	local glows = {}
	for g, size in { 128, 96, 64 } do
		local glow = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 66),
			Size = UDim2.fromOffset(size, size * 0.8),
			BackgroundColor3 = crate.Color,
			BackgroundTransparency = 0.93 - g * 0.04,
			BorderSizePixel = 0,
		}, button) :: Frame
		corner(glow, UDim.new(1, 0))
		table.insert(glows, glow)
	end
	local chest = if Crates.isEgg(crate) then CrateModels.egg(crate) else CrateModels.crate(crate)
	local _, cam, focus = viewport(button, chest, UDim2.fromOffset(150, 116), UDim2.new(0.5, 0, 0, 8), 13, 1.8)
	label(button, {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBlack,
		Text = crate.Name,
		TextSize = 17,
		TextColor3 = crate.Color,
	})
	local priceRow = make("Frame", {
		Position = UDim2.fromOffset(0, 148),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
	}, button)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, priceRow)
	local paysRobux = Crates.paysWithRobux(crate)
	local coinIcon = coin(priceRow, 17)
	coinIcon.LayoutOrder = 1
	coinIcon.Visible = not paysRobux
	local price = label(priceRow, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBlack,
		Text = if paysRobux then "R$ ..." else Crates.formatPrice(crate.Price),
		TextSize = 17,
		TextColor3 = if paysRobux then C(90, 230, 160) else GOLD,
	})
	local open = make("TextButton", {
		Name = "Open",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(132, 36),
		BackgroundColor3 = crate.Color,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBlack,
		Text = "OPEN",
		TextSize = 18,
		TextColor3 = C(20, 16, 22),
		Visible = not paysRobux, -- las cajas de Robux solo tienen el botón R$
	}, button) :: TextButton
	corner(open, UDim.new(0, 10))
	make("UIGradient", { Color = ColorSequence.new(WHITE, C(185, 180, 190)), Rotation = 90 }, open)
	local openScale = make("UIScale", {}, open) :: UIScale
	-- Cajas de Robux: el botón R$ va en el lugar de OPEN
	local robux = make("TextButton", {
		Name = "Robux",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(132, 36),
		BackgroundColor3 = ROBUX,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBlack,
		Text = "R$ ...",
		TextSize = 17,
		TextColor3 = WHITE,
		Visible = false,
	}, button) :: TextButton
	corner(robux, UDim.new(0, 10))
	make("UIGradient", { Color = ColorSequence.new(WHITE, C(190, 200, 195)), Rotation = 90 }, robux)
	local robuxScale = make("UIScale", {}, robux) :: UIScale
	if paysRobux and crate.ProductId > 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(crate.ProductId, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				robuxPrices[crate.Id] = Crates.formatPrice(info.PriceInRobux)
			end
			if gui.Enabled then
				refreshCards()
			end
		end)
	end

	local card: Card = {
		crate = crate,
		button = button,
		stroke = cardStroke,
		scale = cardScale,
		glows = glows,
		price = price,
		open = open,
		robux = robux,
		cam = cam,
		focus = focus,
		hover = false,
	}
	table.insert(cards, card)

	button.MouseEnter:Connect(function()
		card.hover = true
		refreshCards()
	end)
	button.MouseLeave:Connect(function()
		card.hover = false
		refreshCards()
	end)
	button.Activated:Connect(function()
		select(crate.Id)
	end)
	open.MouseEnter:Connect(function()
		tween(openScale, 0.1, { Scale = 1.06 })
	end)
	open.MouseLeave:Connect(function()
		tween(openScale, 0.1, { Scale = 1 })
	end)
	open.Activated:Connect(function()
		select(crate.Id)
		requestOpen(crate)
	end)
	robux.MouseEnter:Connect(function()
		tween(robuxScale, 0.1, { Scale = 1.06 })
	end)
	robux.MouseLeave:Connect(function()
		tween(robuxScale, 0.1, { Scale = 1 })
	end)
	robux.Activated:Connect(function()
		select(crate.Id)
		requestRobux(crate)
	end)
end

function refreshCards()
	local gold = player:GetAttribute(CURRENCY) or 0
	for _, card in cards do
		local selected = card.crate.Id == selectedId
		local target = if selected then 1.05 elseif card.hover then 1.03 else 1
		tween(card.scale, 0.16, { Scale = target }, Enum.EasingStyle.Back)
		tween(card.stroke, 0.16, { Thickness = if selected then 3 else 1.5, Transparency = if selected then 0 else (if card.hover then 0.3 else 0.55) })
		tween(card.button, 0.16, { BackgroundColor3 = if selected then CARD_SELECTED else CARD })
		for g, glow in card.glows do
			tween(glow, 0.2, { BackgroundTransparency = (if selected then 0.82 else 0.93) - g * 0.04 })
		end
		local crate = card.crate
		if Crates.paysWithRobux(crate) then
			-- R$: precio de Roblox; "PRONTO" sin producto; bloqueado donde Roblox no lo permite
			local price = robuxPrices[crate.Id]
			local ready = Config.Crates.RobuxEnabled and crate.ProductId > 0
			local allowed = player:GetAttribute("PaidCratesAllowed") == true
			card.price.Text = if not ready then "Pronto" elseif price then "R$ " .. price else "R$ ..."
			card.robux.Visible = true
			card.robux.Text = if busy then "..." elseif not ready then "PRONTO" elseif not allowed then "NO DISPONIBLE" else "R$ " .. (price or "")
			card.robux.TextSize = if ready and allowed then 18 else 14
			card.robux.BackgroundColor3 = if ready and allowed and not busy then ROBUX else C(90, 90, 100)
		else
			local affordable = gold >= crate.Price
			card.price.TextColor3 = if affordable then GOLD else DANGER
			card.open.AutoButtonColor = false
			card.open.BackgroundColor3 = if busy then C(90, 90, 100) else crate.Color
			card.open.Text = if busy then "..." else "OPEN"
			card.robux.Visible = false
		end
	end
end

---------------------------------------------------------------------
-- Shop: DROP RATES
---------------------------------------------------------------------
local rates = make("Frame", {
	Position = UDim2.fromOffset(24, 262),
	Size = UDim2.new(1, -48, 1, -300),
	BackgroundColor3 = C(11, 10, 15),
	BorderSizePixel = 0,
}, shopPage)
corner(rates, UDim.new(0, 12))
stroke(rates, WHITE, 1, 0.9)
label(rates, {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.fromOffset(140, 24),
	Font = Enum.Font.GothamBlack,
	Text = "DROP RATES",
	TextSize = 18,
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local ratesCrate = label(rates, {
	Position = UDim2.fromOffset(160, 10),
	Size = UDim2.new(1, -180, 0, 24),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 42),
	Size = UDim2.new(1, -20, 1, -50),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, rates) :: ScrollingFrame
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local secretLabels: { TextLabel } = {}

function refreshRates()
	local crate = Crates.ById[selectedId]
	ratesCrate.Text = "— " .. crate.Name
	ratesCrate.TextColor3 = crate.Color
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(secretLabels)
	for i, rate in Crates.rates(crate) do
		local prize = CrateItems.ById[rate.Prize]
		local rarity = CrateItems.rarity(prize.Rarity)
		local row = make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 32),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = if i % 2 == 0 then 0.97 else 1,
			BorderSizePixel = 0,
		}, list)
		corner(row, UDim.new(0, 8))
		local dot = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = rarity.Color,
			BorderSizePixel = 0,
		}, row)
		corner(dot, UDim.new(1, 0))
		stroke(dot, rarity.Color, 3, 0.7)
		local name = label(row, {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.fromOffset(190, 32),
			Text = prize.Name,
			TextSize = 16,
			TextColor3 = rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local tag = make("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 226, 0.5, 0),
			Size = UDim2.fromOffset(92, 20),
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.82,
			Font = Enum.Font.GothamBlack,
			Text = string.upper(rarity.Name),
			TextSize = 11,
			TextColor3 = rarity.Color,
		}, row) :: TextLabel
		corner(tag, UDim.new(1, 0))
		if prize.Rarity == "Secret" then
			table.insert(secretLabels, name)
			table.insert(secretLabels, tag)
		end
		local track = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 334, 0.5, 0),
			Size = UDim2.new(1, -334 - 112, 0, 10),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
		}, row)
		corner(track, UDim.new(1, 0))
		local fill = make("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = rarity.Color,
			BorderSizePixel = 0,
		}, track) :: Frame
		corner(fill, UDim.new(1, 0))
		make("UIGradient", { Color = ColorSequence.new(rarity.Color:Lerp(WHITE, 0.35), rarity.Color) }, fill)
		label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.fromOffset(96, 32),
			Font = Enum.Font.GothamBlack,
			Text = Crates.formatPercent(rate.Percent),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		-- La barra crece hasta su porcentaje (con un mínimo visible para los muy raros)
		local width = math.max(rate.Percent / 100, 0.008)
		task.delay(i * 0.03, function()
			if fill.Parent then
				tween(fill, 0.45, { Size = UDim2.fromScale(width, 1) }, Enum.EasingStyle.Quart)
			end
		end)
	end
end

---------------------------------------------------------------------
-- Index
---------------------------------------------------------------------
local owned: { [string]: number } = {}
local openedCount = 0
local equipBusy = false
local requestEquip: (CrateItems.Prize) -> ()

local function equippedIn(slot: string): string
	local id = player:GetAttribute("Equipped" .. slot)
	return if type(id) == "string" then id else ""
end

local function isEquipped(prize: CrateItems.Prize): boolean
	return equippedIn(CrateItems.slotOf(prize)) == prize.Id
end

-- "+9% daño" para mascotas
local function petBonusText(prize: CrateItems.Prize): string
	local bonus = (Config.Crates.PetDamageBonus :: any)[prize.Rarity] or 0
	return string.format("+%d%% daño", math.floor(bonus * 100 + 0.5))
end

local indexHeader = label(indexPage, {
	Position = UDim2.fromOffset(28, 6),
	Size = UDim2.new(1, -56, 0, 26),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextSize = 17,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	RichText = true,
})
local equippedLine = label(indexPage, {
	Position = UDim2.fromOffset(28, 32),
	Size = UDim2.new(1, -56, 0, 22),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextSize = 15,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	RichText = true,
})
local grid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 60),
	Size = UDim2.new(1, -40, 1, -72),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, indexPage) :: ScrollingFrame
make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, grid)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(136, 200),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, grid)

type Entry = { prize: CrateItems.Prize, frame: Frame, stroke: UIStroke, view: ViewportFrame, name: TextLabel, count: TextLabel, equip: TextButton, hover: boolean }
local entries: { Entry } = {}
local indexBuilt = false

local function buildIndex()
	if indexBuilt then
		return
	end
	indexBuilt = true
	local sorted = table.clone(CrateItems.List)
	table.sort(sorted, function(a, b)
		local ra, rb = CrateItems.rarity(a.Rarity).Order, CrateItems.rarity(b.Rarity).Order
		if ra ~= rb then
			return ra < rb
		end
		return a.Name < b.Name
	end)
	for i, prize in sorted do
		local rarity = CrateItems.rarity(prize.Rarity)
		local frame = make("Frame", { Name = prize.Id, LayoutOrder = i, BackgroundColor3 = CARD, BorderSizePixel = 0 }, grid) :: Frame
		corner(frame, UDim.new(0, 12))
		local s = stroke(frame, rarity.Color, 1.5, 0.6)
		local model = CrateModels.prize(prize.Id)
		local height = math.max(CrateModels.height(model), 0.5)
		local view = viewport(frame, model, UDim2.fromOffset(126, 108), UDim2.new(0.5, 0, 0, 4), height * 3.2, height * 0.5)
		local name = label(frame, {
			Position = UDim2.fromOffset(4, 112),
			Size = UDim2.new(1, -8, 0, 22),
			Text = prize.Name,
			TextSize = 15,
			TextColor3 = rarity.Color,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local kindLine = label(frame, {
			Position = UDim2.fromOffset(4, 134),
			Size = UDim2.new(1, -8, 0, 14),
			Font = Enum.Font.GothamBlack,
			Text = string.upper(rarity.Name) .. " · " .. (KIND_NAMES[prize.Kind] or prize.Kind),
			TextScaled = true,
			TextColor3 = rarity.Color,
		})
		make("UITextSizeConstraint", { MaxTextSize = 11 }, kindLine)
		if prize.Kind == "Pet" then
			label(frame, {
				Position = UDim2.fromOffset(4, 147),
				Size = UDim2.new(1, -8, 0, 12),
				Font = Enum.Font.GothamBold,
				Text = petBonusText(prize),
				TextSize = 11,
				TextColor3 = C(255, 215, 120),
			})
		end
		local count = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(40, 20),
			BackgroundColor3 = C(10, 9, 14),
			Font = Enum.Font.GothamBlack,
			Text = "",
			TextSize = 12,
			TextColor3 = TEXT,
		}, frame) :: TextLabel
		corner(count, UDim.new(1, 0))
		local equip = make("TextButton", {
			Name = "Equip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 163),
			Size = UDim2.fromOffset(112, 28),
			BackgroundColor3 = ACCENT,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBlack,
			Text = "EQUIP",
			TextSize = 14,
			TextColor3 = C(30, 14, 6),
			Visible = false,
		}, frame) :: TextButton
		corner(equip, UDim.new(0, 8))
		local entry: Entry = { prize = prize, frame = frame, stroke = s, view = view, name = name, count = count, equip = equip, hover = false }
		equip.MouseEnter:Connect(function()
			entry.hover = true
			if isEquipped(prize) then
				equip.Text = "UNEQUIP"
			end
		end)
		equip.MouseLeave:Connect(function()
			entry.hover = false
			if isEquipped(prize) then
				equip.Text = "EQUIPPED"
			end
		end)
		equip.Activated:Connect(function()
			requestEquip(prize)
		end)
		table.insert(entries, entry)
	end
end

local function refreshIndex()
	buildIndex()
	local have = 0
	for _, e in entries do
		local n = owned[e.prize.Id] or 0
		local rarity = CrateItems.rarity(e.prize.Rarity)
		if n > 0 then
			have += 1
			e.view.ImageColor3 = WHITE
			e.view.ImageTransparency = 0
			e.name.Text = e.prize.Name
			e.name.TextColor3 = rarity.Color
			e.stroke.Transparency = 0.45
			e.count.Visible = true
			e.count.Text = "x" .. n
			local on = isEquipped(e.prize)
			e.equip.Visible = true
			e.equip.Text = if on then (if e.hover then "UNEQUIP" else "EQUIPPED") elseif equipBusy then "..." else "EQUIP"
			e.equip.BackgroundColor3 = if on then C(70, 200, 120) else ACCENT
			e.stroke.Thickness = if on then 3 else 1.5
			if on then
				e.stroke.Transparency = 0
			end
		else
			e.view.ImageColor3 = C(0, 0, 0) -- silueta
			e.view.ImageTransparency = 0.15
			e.name.Text = "???"
			e.name.TextColor3 = MUTED
			e.stroke.Transparency = 0.85
			e.stroke.Thickness = 1.5
			e.count.Visible = false
			e.equip.Visible = false
		end
	end
	indexHeader.Text = string.format('Colección  <font color="#ffcd46">%d / %d</font>     Cajas abiertas  <font color="#ffcd46">%d</font>', have, #entries, openedCount)
	local pet = CrateItems.ById[equippedIn("Pet")]
	local char = CrateItems.ById[equippedIn("Character")]
	equippedLine.Text = string.format(
		'Mascota: <font color="#f2eee8">%s</font>     Personaje: <font color="#f2eee8">%s</font>',
		if pet then pet.Name .. " (" .. petBonusText(pet) .. ")" else "ninguna",
		if char then char.Name else "tu avatar"
	)
end

local function fetchCollection()
	local ok, res = pcall(function()
		return request:InvokeServer("Collection")
	end)
	if ok and type(res) == "table" and res.Ok and type(res.Owned) == "table" then
		owned = {}
		for id, n in res.Owned do
			if type(id) == "string" and type(n) == "number" then
				owned[id] = n
			end
		end
		openedCount = if type(res.Opened) == "number" then res.Opened else openedCount
	end
	refreshIndex()
end

---------------------------------------------------------------------
-- Pestañas, abrir y cerrar
---------------------------------------------------------------------
local function showTab(tab: string)
	for id, b in tabButtons do
		local on = id == tab
		tween(b, 0.15, { BackgroundTransparency = if on then 0 else 1, TextColor3 = if on then C(30, 14, 6) else MUTED })
	end
	shopPage.Visible = tab == "Shop" or tab == "Eggs"
	indexPage.Visible = tab == "Index"
	if tab == "Shop" or tab == "Eggs" then
		local wanted = if tab == "Eggs" then "Egg" else "Crate"
		if shopType ~= wanted then
			shopType = wanted
			selectedId = lastSelected[wanted] or selectedId
		end
		for kind, row in rows do
			row.Visible = kind == shopType
		end
		refreshCards()
		refreshRates()
	end
	if tab == "Index" then
		refreshIndex()
		task.spawn(fetchCollection)
	end
end
for id, b in tabButtons do
	b.Activated:Connect(function()
		showTab(id)
	end)
end

local function updateWallet()
	walletText.Text = Crates.formatPrice(player:GetAttribute(CURRENCY) or 0)
	if gui.Enabled then
		refreshCards()
	end
end
player:GetAttributeChangedSignal(CURRENCY):Connect(updateWallet)

local function fit()
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	fitScale.Scale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.35, 1.25)
end

local spinConn: RBXScriptConnection? = nil
local isOpen = false

local function closeMenu(instant: boolean?)
	if not isOpen then
		return
	end
	isOpen = false
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	message.Text = ""
	if instant then
		gui.Enabled = false
		return
	end
	tween(dim, 0.15, { BackgroundTransparency = 1 })
	tween(popScale, 0.15, { Scale = 0.9 })
	task.delay(0.15, function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local function openMenu(crateId: string?)
	if anyPlaying() or player:GetAttribute("InMatch") == true then
		return
	end
	local target = if crateId then Crates.ById[crateId] else nil
	if target then
		lastSelected[target.Type] = target.Id
		shopType = target.Type
		selectedId = target.Id
	end
	fit()
	updateWallet()
	showTab(if shopType == "Egg" then "Eggs" else "Shop")
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	dim.BackgroundTransparency = 1
	tween(dim, 0.25, { BackgroundTransparency = 0.45 })
	popScale.Scale = 0.85
	tween(popScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	-- Los cofres de las tarjetas giran; el nombre de los Secret cambia de color
	spinConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i, card in cards do
			local a = t * 0.8 + i
			local d = 13
			local selected = card.crate.Id == selectedId
			local bob = if selected then math.sin(t * 3) * 0.15 else 0
			card.cam.CFrame = CFrame.lookAt(card.focus + Vector3.new(math.sin(a) * d, d * 0.3 - bob, -math.cos(a) * d), card.focus)
		end
		local secret = CrateItems.color("Secret", t)
		for _, l in secretLabels do
			l.TextColor3 = secret
		end
	end)
end

closeButton.MouseEnter:Connect(function()
	tween(closeButton, 0.1, { BackgroundColor3 = C(200, 60, 60) })
end)
closeButton.MouseLeave:Connect(function()
	tween(closeButton, 0.1, { BackgroundColor3 = C(40, 36, 48) })
end)
closeButton.Activated:Connect(function()
	closeMenu()
end)
dim.Activated:Connect(function()
	closeMenu()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and isOpen and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
		closeMenu()
	end
end)

local function showMessage(text: string)
	message.Text = text
	message.TextTransparency = 0
	local myText = text
	task.delay(3, function()
		if message.Text == myText then
			tween(message, 0.4, { TextTransparency = 1 })
		end
	end)
end

-- Sacudón corto de la tarjeta (no alcanzó, límite, etc.)
local function nudge(crateId: string)
	for _, card in cards do
		if card.crate.Id == crateId then
			local pos = card.button.Position
			task.spawn(function()
				for _, dx in { 8, -7, 5, -3, 0 } do
					card.button.Position = pos + UDim2.fromOffset(dx, 0)
					task.wait(0.035)
				end
			end)
		end
	end
end

function requestOpen(crate: Crates.Crate)
	if busy or anyPlaying() then
		return
	end
	busy = true
	refreshCards()
	message.Text = ""
	local ok, res = pcall(function()
		return request:InvokeServer("Open", crate.Id)
	end)
	busy = false
	refreshCards()
	if not ok or type(res) ~= "table" then
		showMessage("No se pudo abrir. Probá de nuevo.")
		return
	end
	if not res.Ok then
		showMessage(if type(res.Error) == "string" then res.Error else "No se pudo abrir.")
		nudge(crate.Id)
		return
	end
	if type(res.Prize) ~= "string" or not CrateItems.ById[res.Prize] then
		showMessage("Premio desconocido.")
		return
	end
	owned[res.Prize] = if type(res.Count) == "number" then res.Count else (owned[res.Prize] or 0) + 1
	openedCount += 1
	closeMenu(true)
	playOpening(crate, res, function()
		openMenu(crate.Id)
	end)
end

function requestEquip(prize: CrateItems.Prize)
	if equipBusy then
		return
	end
	equipBusy = true
	local on = isEquipped(prize)
	local ok, res = pcall(function()
		if on then
			return request:InvokeServer("Unequip", CrateItems.slotOf(prize))
		end
		return request:InvokeServer("Equip", prize.Id)
	end)
	equipBusy = false
	if not ok or type(res) ~= "table" or not res.Ok then
		local text = if ok and type(res) == "table" and type(res.Error) == "string" then res.Error else "No se pudo equipar."
		indexHeader.Text = '<font color="#ff5a5a">' .. text .. "</font>"
		task.delay(2, refreshIndex)
		return
	end
	refreshIndex()
end
player:GetAttributeChangedSignal("EquippedPet"):Connect(function()
	if indexPage.Visible then
		refreshIndex()
	end
end)
player:GetAttributeChangedSignal("EquippedCharacter"):Connect(function()
	if indexPage.Visible then
		refreshIndex()
	end
end)
player:GetAttributeChangedSignal("PaidCratesAllowed"):Connect(function()
	if gui.Enabled then
		refreshCards()
	end
end)

-- Comprar con Robux: el servidor valida y muestra la ventana de compra de Roblox
function requestRobux(crate: Crates.Crate)
	if busy or anyPlaying() then
		return
	end
	if crate.ProductId <= 0 or not Config.Crates.RobuxEnabled then
		showMessage("Esta caja todavía no está a la venta.")
		return
	end
	if player:GetAttribute("PaidCratesAllowed") ~= true then
		showMessage("Las cajas con Robux no están disponibles en tu región.")
		return
	end
	busy = true
	refreshCards()
	local ok, res = pcall(function()
		return request:InvokeServer("BuyRobux", crate.Id)
	end)
	busy = false
	refreshCards()
	if not ok or type(res) ~= "table" then
		showMessage("No se pudo comprar. Probá de nuevo.")
	elseif not res.Ok then
		showMessage(if type(res.Error) == "string" then res.Error else "No se pudo comprar.")
		nudge(crate.Id)
	end
end

-- Llega una caja pagada con Robux (con el recibo): animación apenas se pueda
local paidQueue: { { [string]: any } } = {}
local function playPaid()
	if #paidQueue == 0 or anyPlaying() or player:GetAttribute("InMatch") == true then
		return
	end
	local res = table.remove(paidQueue, 1) :: { [string]: any }
	local crate = Crates.ById[res.Crate]
	if not crate or not CrateItems.ById[res.Prize] then
		return
	end
	owned[res.Prize] = if type(res.Count) == "number" then res.Count else (owned[res.Prize] or 0) + 1
	openedCount += 1
	closeMenu(true)
	playOpening(crate, res, function()
		if #paidQueue > 0 then
			playPaid()
		else
			openMenu(crate.Id)
		end
	end)
end
crateOpened.OnClientEvent:Connect(function(res: any)
	if type(res) == "table" and type(res.Crate) == "string" and type(res.Prize) == "string" then
		table.insert(paidQueue, res)
		playPaid()
	end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") ~= true then
		task.delay(2, playPaid) -- volvió al lobby: mostrar las que quedaron pendientes
	end
end)

-- Los prompts de las plataformas abren el menú con esa caja elegida
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player then
		return
	end
	local id = prompt:GetAttribute("CrateId")
	if type(id) == "string" then
		openMenu(id)
	end
end)

-- Si empieza la partida, el menú se cierra
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") == true then
		closeMenu(true)
	end
end)

local function onViewport()
	if gui.Enabled then
		fit()
	end
end
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewport)
	end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
updateWallet()

---------------------------------------------------------------------
-- Cofres de las plataformas: flotan y giran (solo en esta pantalla)
---------------------------------------------------------------------
type Display = { model: Model, base: CFrame, phase: number }
local displays: { Display } = {}
local known: { [Model]: boolean } = {}

-- Anota los cofres nuevos con su posición original (la que puso el servidor)
local function collectDisplays(plaza: Instance)
	for _, d in plaza:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("CrateDisplay") == true and not known[d] then
			known[d] = true
			table.insert(displays, { model = d, base = d:GetPivot(), phase = #displays * 1.3 })
		end
	end
end

task.spawn(function()
	local plaza = workspace:WaitForChild("CratePlaza", 60)
	if not plaza then
		return
	end
	local stations = plaza:WaitForChild("Stations", 30)
	if not stations then
		return
	end
	task.wait(1) -- que lleguen todas las piezas
	collectDisplays(plaza)
	stations.ChildAdded:Connect(function()
		task.wait(1)
		collectDisplays(plaza)
	end)
	RunService.RenderStepped:Connect(function()
		if #displays == 0 or player:GetAttribute("InMatch") == true or anyPlaying() then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - displays[1].base.Position).Magnitude > 220 then
			return
		end
		local t = os.clock()
		for _, d in displays do
			if d.model.Parent then
				d.model:PivotTo(d.base * CFrame.new(0, 0.6 + math.sin(t * 1.6 + d.phase) * 0.4, 0) * CFrame.Angles(0, t * 0.7 + d.phase, 0))
			end
		end
	end)
end)
