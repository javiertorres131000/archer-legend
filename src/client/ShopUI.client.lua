-- ShopUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > ShopUI
-- Ventana de la Tienda y las Misiones del lobby (botones "Tienda" y "Misiones" de LobbyUI).
-- Se abre con el atributo "ShopOpen" de PlayerGui: "Tienda" o "Misiones" (nil = cerrada).
-- Solo muestra y pide: el servidor (ShopService, MissionService) valida, cobra y entrega.
--   · Tienda: 4 ofertas de equipo del día, cambios de monedas y cofre de runas.
--   · Misiones: 3 diarias y 3 semanales con su progreso, premio y botón COBRAR.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("UITheme"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local EquipmentDefs = require(Shared:WaitForChild("EquipmentDefs"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local Missions = require(Shared:WaitForChild("Missions"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shopRequest = remotes:WaitForChild("ShopRequest") :: RemoteFunction
local missionRequest = remotes:WaitForChild("MissionRequest") :: RemoteFunction

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors, Fonts = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local ICONS: { [string]: string } = {}
for _, c in Currencies do
	ICONS[c.Id] = c.Icon
end

local function priceText(p: { Currency: string, Amount: number }): string
	return (ICONS[p.Currency] or "") .. " " .. tostring(p.Amount)
end

local function rewardText(reward: { [string]: number }): string
	local parts = {}
	for _, c in Currencies do
		local n = reward[c.Id]
		if n and n > 0 then
			table.insert(parts, c.Icon .. " " .. n)
		end
	end
	return table.concat(parts, "   ")
end

---------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "ShopUI", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false, IgnoreGuiInset = true, Parent = playerGui })
local backdrop = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Modal = true,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.3,
	AutoButtonColor = false,
	Parent = gui,
})
local window = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.86), Parent = backdrop })
make("UISizeConstraint", { MaxSize = Vector2.new(860, 520), Parent = window })
local title = text({
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(0.5, 0, 0, 34),
	Text = "💰  TIENDA",
	Font = Fonts.Title,
	TextSize = 26,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = window,
})
local wallet = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -64, 0, 14),
	Size = UDim2.new(0.45, 0, 0, 26),
	Text = "",
	Font = Fonts.Bold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = window,
})
local close = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(40, 32), Text = "×", Parent = window })

-- Pestañas
local tabs = make("Frame", { Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 0, 36), BackgroundTransparency = 1, Parent = window }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
})
local tabButtons: { [string]: TextButton } = {}
for _, t in { { "Tienda", "🛒  Tienda" }, { "Misiones", "📜  Misiones" } } do
	local b = make("TextButton", {
		Size = UDim2.fromOffset(170, 36),
		BackgroundColor3 = Colors.PanelLight,
		Font = Fonts.Bold,
		TextSize = 17,
		TextColor3 = Colors.Text,
		Text = t[2],
		AutoButtonColor = true,
		Parent = tabs,
	}, { Theme.corner(10), Theme.stroke(Colors.GoldDark, 1.5) })
	b.Activated:Connect(function()
		playerGui:SetAttribute("ShopOpen", t[1])
	end)
	tabButtons[t[1]] = b
end

local body = make("Frame", { Position = UDim2.fromOffset(16, 96), Size = UDim2.new(1, -32, 1, -136), BackgroundTransparency = 1, Parent = window })
local status = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(1, -32, 0, 24),
	Text = "",
	Font = Fonts.Bold,
	TextSize = 16,
	Parent = window,
})

local function setStatus(message: string?, ok: boolean?)
	status.Text = message or ""
	status.TextColor3 = if ok == false then Colors.Danger else Colors.Success
end

local function refreshWallet()
	local parts = {}
	for _, c in Currencies do
		table.insert(parts, c.Icon .. " " .. tostring(player:GetAttribute(c.Id) or 0))
	end
	wallet.Text = table.concat(parts, "    ")
end
for _, c in Currencies do
	player:GetAttributeChangedSignal(c.Id):Connect(refreshWallet)
end

local function clearBody()
	for _, child in body:GetChildren() do
		child:Destroy()
	end
end

local function card(parent: Instance, props: { [string]: any }): Frame
	props.BackgroundColor3 = Colors.PanelLight
	props.BackgroundTransparency = 0.05
	props.BorderSizePixel = 0
	props.Parent = parent
	local f = make("Frame", props)
	Theme.corner(10).Parent = f
	return f
end

local busy = false
local current: string? = nil
local renderShop: (any) -> ()
local renderMissions: (any) -> ()

local function invoke(remote: RemoteFunction, ...: any): any
	if busy then
		return nil
	end
	busy = true
	local args = table.pack(...)
	local ok, res = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	if not ok or type(res) ~= "table" then
		setStatus("No se pudo conectar con el servidor.", false)
		return nil
	end
	if not res.Ok then
		setStatus(res.Error or "No se pudo.", false)
		return nil
	end
	return res
end

---------------------------------------------------------------------
-- Tienda
---------------------------------------------------------------------

function renderShop(res: any)
	clearBody()
	text({
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Ofertas del día · cambian en " .. Missions.formatTime(res.ResetIn or 0),
		Font = Fonts.Bold,
		TextSize = 16,
		TextColor3 = Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	local row = make("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0.5, -26), BackgroundTransparency = 1, Parent = body }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }),
	})
	for _, o in res.Offers or {} do
		local color = Rarities.Colors[o.Rarity] or Colors.Text
		local c = card(row, { Size = UDim2.new(1 / math.max(1, #res.Offers), -8, 1, 0) })
		Theme.stroke(color, if o.Bought then 1 else 2, if o.Bought then 0.6 else 0).Parent = c
		text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 40), Text = EquipmentDefs.SlotIcons[o.Slot] or "🎁", TextSize = 32, Parent = c })
		text({ Position = UDim2.fromOffset(6, 48), Size = UDim2.new(1, -12, 0, 36), Text = o.Name, Font = Fonts.Bold, TextSize = 15, TextWrapped = true, Parent = c })
		text({ Position = UDim2.fromOffset(6, 84), Size = UDim2.new(1, -12, 0, 18), Text = Rarities.Names[o.Rarity] or o.Rarity, Font = Fonts.Bold, TextSize = 14, TextColor3 = color, Parent = c })
		local buy = Theme.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 34),
			Text = if o.Bought then "Comprada" else priceText(o.Price),
			TextSize = 16,
			BackgroundColor3 = if o.Bought then Colors.Locked else Colors.Gold,
			Parent = c,
		})
		buy.Active = not o.Bought
		buy.Activated:Connect(function()
			if o.Bought then
				return
			end
			local r = invoke(shopRequest, "BuyOffer", o.Index)
			if r then
				setStatus(r.Message, true)
				renderShop(r)
			end
		end)
	end

	text({
		Position = UDim2.new(0, 0, 0.5, 8),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Cambios (por día) y cofre de runas",
		Font = Fonts.Bold,
		TextSize = 16,
		TextColor3 = Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	local row2 = make("Frame", { Position = UDim2.new(0, 0, 0.5, 34), Size = UDim2.new(1, 0, 0.5, -34), BackgroundTransparency = 1, Parent = body }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }),
	})
	local items = #(res.Exchanges or {}) + 1
	for _, e in res.Exchanges or {} do
		local c = card(row2, { Size = UDim2.new(1 / items, -8, 1, 0) })
		Theme.stroke(Colors.GoldDark, 1.5).Parent = c
		text({ Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 22), Text = e.Name, Font = Fonts.Bold, TextSize = 16, Parent = c })
		text({ Position = UDim2.fromOffset(6, 34), Size = UDim2.new(1, -12, 0, 26), Text = priceText(e.Give) .. "  →  " .. priceText(e.Get), TextSize = 18, Parent = c })
		text({ Position = UDim2.fromOffset(6, 62), Size = UDim2.new(1, -12, 0, 18), Text = string.format("Quedan %d de %d hoy", e.Left, e.PerDay), TextSize = 13, TextColor3 = Colors.TextMuted, Parent = c })
		local b = Theme.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 34),
			Text = if e.Left > 0 then "Cambiar" else "Agotado",
			TextSize = 16,
			BackgroundColor3 = if e.Left > 0 then Colors.Gold else Colors.Locked,
			Parent = c,
		})
		b.Activated:Connect(function()
			if e.Left <= 0 then
				return
			end
			local r = invoke(shopRequest, "Exchange", e.Id)
			if r then
				setStatus(r.Message, true)
				renderShop(r)
			end
		end)
	end
	local rc = card(row2, { Size = UDim2.new(1 / items, -8, 1, 0) })
	Theme.stroke(Color3.fromRGB(170, 110, 255), 1.5).Parent = rc
	text({ Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 22), Text = "🔮 Cofre de runas", Font = Fonts.Bold, TextSize = 16, Parent = rc })
	text({ Position = UDim2.fromOffset(6, 34), Size = UDim2.new(1, -12, 0, 44), Text = "Una runa al azar (a veces especial). Las repetidas suben de nivel.", TextSize = 13, TextWrapped = true, TextColor3 = Colors.TextMuted, Parent = rc })
	local rb = Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 34),
		Text = "💎 " .. tostring(res.RuneChestCost or 60),
		TextSize = 16,
		Parent = rc,
	})
	rb.Activated:Connect(function()
		local r = invoke(shopRequest, "RuneChest")
		if r then
			setStatus(r.Message, true)
			renderShop(r)
		end
	end)
end

---------------------------------------------------------------------
-- Misiones
---------------------------------------------------------------------

local function missionColumn(parent: Instance, x: number, titleText: string, period: string, list: { any })
	local col = make("Frame", { Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = parent })
	text({
		Size = UDim2.new(1, 0, 0, 22),
		Text = titleText,
		Font = Fonts.Bold,
		TextSize = 16,
		TextColor3 = Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = col,
	})
	for i, m in list do
		local c = card(col, { Position = UDim2.new(0, 0, (i - 1) / 3, 26 - (i - 1) * 8), Size = UDim2.new(1, 0, 1 / 3, -16) })
		Theme.stroke(if m.Done and not m.Claimed then Colors.GoldBright else Colors.GoldDark, if m.Done and not m.Claimed then 2 else 1).Parent = c
		text({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -130, 0, 36),
			Text = m.Text,
			Font = Fonts.Bold,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if m.Claimed then Colors.TextMuted else Colors.Text,
			Parent = c,
		})
		text({
			Position = UDim2.fromOffset(10, 42),
			Size = UDim2.new(1, -130, 0, 18),
			Text = "Premio: " .. rewardText(m.Reward),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Colors.GoldBright,
			Parent = c,
		})
		-- Barra de progreso
		local bar = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.new(1, -130, 0, 10), BackgroundColor3 = Colors.Background, BorderSizePixel = 0, Parent = c }, { Theme.corner(5) })
		make("Frame", { Size = UDim2.fromScale(math.clamp(m.Progress / math.max(1, m.Target), 0, 1), 1), BackgroundColor3 = if m.Done then Colors.Success else Colors.Gold, BorderSizePixel = 0, Parent = bar }, { Theme.corner(5) })
		text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -124, 1, -20), Size = UDim2.fromOffset(120, 16), Text = string.format("%d / %d", m.Progress, m.Target), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Colors.TextMuted, Parent = c })
		local b = Theme.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(104, 36),
			Text = if m.Claimed then "✔ Cobrada" elseif m.Done then "COBRAR" else "En curso",
			TextSize = 15,
			BackgroundColor3 = if m.Done and not m.Claimed then Colors.Gold else Colors.Locked,
			Parent = c,
		})
		b.Activated:Connect(function()
			if not m.Done or m.Claimed then
				return
			end
			local r = invoke(missionRequest, "Claim", period, i)
			if r then
				setStatus("✔ Cobraste " .. rewardText(r.Claimed or m.Reward), true)
				renderMissions(r)
			end
		end)
	end
end

function renderMissions(res: any)
	clearBody()
	missionColumn(body, 0, "📅 Diarias · se renuevan en " .. Missions.formatTime(res.DailyResetIn or 0), "Daily", res.Daily or {})
	missionColumn(body, 0.5, "🗓 Semanales · se renuevan en " .. Missions.formatTime(res.WeeklyResetIn or 0), "Weekly", res.Weekly or {})
end

---------------------------------------------------------------------
-- Abrir / cerrar
---------------------------------------------------------------------

local function open(tab: string)
	current = tab
	gui.Enabled = true
	refreshWallet()
	setStatus(nil)
	title.Text = if tab == "Misiones" then "📜  MISIONES" else "💰  TIENDA"
	for id, b in tabButtons do
		b.BackgroundColor3 = if id == tab then Colors.Gold else Colors.PanelLight
		b.TextColor3 = if id == tab then Color3.fromRGB(40, 28, 10) else Colors.Text
	end
	clearBody()
	text({ Size = UDim2.fromScale(1, 1), Text = "Cargando…", TextColor3 = Colors.TextMuted, Parent = body })
	local res = invoke(if tab == "Misiones" then missionRequest else shopRequest, "Get")
	if not res or current ~= tab then
		return
	end
	if tab == "Misiones" then
		renderMissions(res)
	else
		renderShop(res)
	end
end

local function onAttribute()
	local tab = playerGui:GetAttribute("ShopOpen")
	if (tab == "Tienda" or tab == "Misiones") and player:GetAttribute("InMatch") ~= true then
		open(tab)
	else
		current = nil
		gui.Enabled = false
	end
end

close.Activated:Connect(function()
	playerGui:SetAttribute("ShopOpen", nil)
end)
playerGui:GetAttributeChangedSignal("ShopOpen"):Connect(onAttribute)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		playerGui:SetAttribute("ShopOpen", nil)
	end
end)
