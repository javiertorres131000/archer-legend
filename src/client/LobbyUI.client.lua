-- LobbyUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > LobbyUI
-- Interfaz del lobby: tarjeta del jugador, monedas, botonera, grupo, tarjeta de batalla con el
-- capítulo elegido (y la ventana para cambiarlo), botones JUGAR y BUSCAR GRUPO, invitaciones,
-- cuenta regresiva y avisos. Deja ver la Ciudadela: todo va en los bordes y el centro queda libre.
-- Solo muestra estado y manda pedidos: todo lo decide el servidor.
-- Según el rol del servidor (atributo PlaceRole de GameState, ver Server/Places):
--   · "Lobby" (la Ciudadela): cada uno está en su grupo (PartyService). Lee de cada Player
--     PartyId, PartyLeader, PartyChapter, PartyCountdownEnd, InQueue, QueueSince, PartySize.
--   · "Arena": no hay botones; solo "Preparando la batalla" (ArenaWaiting) y la cuenta.
--   · "Classic" (pruebas viejas): todo el servidor es un equipo (SelectedChapter, LeaderId,
--     CountdownEnd de GameState).
-- Además lee de cada Player: Ready, InMatch, UnlockedChapters, ChapterRecords, ProfileStatus,
-- AccountLevel, AccountXP, AccountXPNeeded, TalentPoints y una por moneda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Modes = require(Shared:WaitForChild("Modes"))
local Theme = require(Shared:WaitForChild("UITheme"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local lobbyRequest = remotes:WaitForChild("LobbyRequest") :: RemoteEvent
local lobbyNotice = remotes:WaitForChild("LobbyNotice") :: RemoteEvent
local partyInvite = remotes:WaitForChild("PartyInvite") :: RemoteEvent
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors, Fonts, Icons = Theme.Colors, Theme.Fonts, Theme.Icons
local make, text, panel, button = Theme.make, Theme.text, Theme.panel, Theme.button
local C = Color3.fromRGB
local QUICK = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Interfaces de Roblox que reemplazamos por las propias (equipo y vida).
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- Estructura
---------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "LobbyUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local root = make("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = gui,
})

-- Todo el contenido se arma sobre un lienzo de 1280×720 centrado y se escala entero
-- según la pantalla (PC grande ↔ teléfono). Los fondos de pantalla completa van afuera.
local DESIGN = Vector2.new(1280, 720)
local content = make("Frame", {
	Name = "Content",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = root,
})
local uiScale = make("UIScale", { Parent = content })
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.4, 1.5)
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Viñetas suaves arriba y abajo (el centro queda limpio para ver la ciudadela)
for _, info in { { 0, 0.22, 0 }, { 1, 0.3, 180 } } do
	local v = make("Frame", {
		AnchorPoint = Vector2.new(0, info[1]),
		Position = UDim2.fromScale(0, info[1]),
		Size = UDim2.fromScale(1, info[2]),
		BackgroundColor3 = Colors.Background,
		BorderSizePixel = 0,
		Parent = root,
	})
	make("UIGradient", {
		Rotation = 90 + info[3],
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = v,
	})
end

-- Panel "vidrio oscuro": más fino que Theme.panel, con brillo dorado arriba
local function glass(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or C(18, 15, 28)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.18
	props.BorderSizePixel = 0
	local f = make("Frame", props)
	Theme.corner(14).Parent = f
	make("UIStroke", { Color = Colors.GoldDark, Thickness = 1.2, Transparency = 0.25, Parent = f })
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C(255, 255, 255), C(170, 160, 190)),
		Parent = f,
	})
	return f
end

local function header(parent: Instance, title: string, pos: UDim2?): TextLabel
	return text({
		Position = pos or UDim2.new(),
		Size = UDim2.new(1, 0, 0, 22),
		Text = title,
		Font = Fonts.Heading,
		TextSize = 15,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function formatAmount(n: number): string
	-- 12345 -> "12.345"
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out
end

---------------------------------------------------------------------
-- Tarjeta del jugador (arriba a la izquierda)
---------------------------------------------------------------------
local playerCard = glass({
	Position = UDim2.new(0, 28, 0, 24),
	Size = UDim2.new(0, 330, 0, 84),
	Parent = content,
})
local avatarFrame = make("Frame", {
	Position = UDim2.new(0, 10, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = C(40, 34, 58),
	Parent = playerCard,
}, { Theme.corner(32), make("UIStroke", { Color = Colors.GoldBright, Thickness = 2 }) })
local avatar = make("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "",
	Parent = avatarFrame,
}, { Theme.corner(32) })
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		avatar.Image = img
	end
end)
text({
	Position = UDim2.new(0, 88, 0, 12),
	Size = UDim2.new(1, -100, 0, 24),
	Text = player.DisplayName,
	Font = Fonts.Bold,
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = playerCard,
})
local levelLine = text({
	Position = UDim2.new(0, 88, 0, 36),
	Size = UDim2.new(1, -100, 0, 18),
	Text = "",
	Font = Fonts.Body,
	TextSize = 14,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = playerCard,
})
local xpBar = make("Frame", {
	Position = UDim2.new(0, 88, 0, 60),
	Size = UDim2.new(1, -104, 0, 8),
	BackgroundColor3 = C(48, 42, 66),
	BorderSizePixel = 0,
	Parent = playerCard,
}, { Theme.corner(4) })
local xpFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.GoldBright,
	BorderSizePixel = 0,
	Parent = xpBar,
}, { Theme.corner(4), make("UIGradient", { Color = ColorSequence.new(Colors.GoldBright, Colors.Gold) }) })

local function refreshPlayerCard()
	local level = (player:GetAttribute("AccountLevel") or 1) :: number
	local xp = (player:GetAttribute("AccountXP") or 0) :: number
	local need = math.max(1, (player:GetAttribute("AccountXPNeeded") or 1) :: number)
	local points = (player:GetAttribute("TalentPoints") or 0) :: number
	levelLine.Text = string.format("Nivel %d  ·  %s / %s XP", level, formatAmount(xp), formatAmount(need))
		.. (if points > 0 then string.format("  ·  ⭐ %d", points) else "")
	TweenService:Create(xpFill, QUICK, { Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1) }):Play()
end
for _, attr in { "AccountLevel", "AccountXP", "AccountXPNeeded", "TalentPoints" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshPlayerCard)
end
refreshPlayerCard()

---------------------------------------------------------------------
-- Monedas y estado del perfil (arriba a la derecha)
---------------------------------------------------------------------
local wallet = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -28, 0, 28),
	Size = UDim2.new(0, 640, 0, 42),
	BackgroundTransparency = 1,
	Parent = content,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local walletLabels: { [string]: TextLabel } = {}
for i, c in Currencies do
	local chip = glass({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = i,
		Parent = wallet,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16), Parent = chip })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = chip,
	})
	make("TextLabel", {
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = c.Color,
		BackgroundTransparency = 0.75,
		Text = c.Icon,
		TextSize = 18,
		Font = Fonts.Bold,
		TextColor3 = Colors.Text,
		Parent = chip,
	}, { Theme.corner(15) })
	walletLabels[c.Id] = text({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "0",
		Font = Fonts.Bold,
		TextSize = 20,
		TextColor3 = c.Color,
		Parent = chip,
	})
end
local profileLabel = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -30, 0, 76),
	Size = UDim2.new(0, 600, 0, 18),
	Font = Fonts.Body,
	TextSize = 13,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextStrokeTransparency = 0.7,
	Parent = content,
})

local function refreshWallet()
	for _, c in Currencies do
		walletLabels[c.Id].Text = formatAmount(player:GetAttribute(c.Id) or 0)
	end
	local status = player:GetAttribute("ProfileStatus")
	if status == "Loading" or status == nil then
		profileLabel.Text = "Cargando tu perfil…"
		profileLabel.TextColor3 = Colors.TextMuted
	elseif status == "Offline" then
		profileLabel.Text = "⚠ Sin guardado: el progreso de esta sesión no se guarda"
		profileLabel.TextColor3 = Colors.Danger
	else
		profileLabel.Text = "✔ Progreso guardado"
		profileLabel.TextColor3 = Colors.Success
	end
end
player:GetAttributeChangedSignal("ProfileStatus"):Connect(refreshWallet)
for _, c in Currencies do
	player:GetAttributeChangedSignal(c.Id):Connect(refreshWallet)
end
refreshWallet()

---------------------------------------------------------------------
-- Botonera (izquierda, vertical)
---------------------------------------------------------------------
local dock = make("Frame", {
	Position = UDim2.new(0, 28, 0, 128),
	Size = UDim2.new(0, 76, 0, 6 * 76 + 5 * 8),
	BackgroundTransparency = 1,
	Parent = content,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
-- Cartelito que aparece al lado del botón
local dockTip = glass({
	Size = UDim2.fromOffset(0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	Visible = false,
	ZIndex = 20,
	Parent = content,
})
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = dockTip })
local dockTipText = text({
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Fonts.Bold,
	TextSize = 15,
	ZIndex = 21,
	Parent = dockTip,
})
-- Acción de cada botón: abrir equipo (el inventario y las runas son pestañas de Equipo),
-- abrir talentos, stats, arma, tienda o misiones (la tienda y las misiones son pestañas de ShopUI)
local lobbyButtons = {
	{ Icons.Equipment, "Equipo", "Equipment", "Equipo, inventario y runas" },
	{ "⭐", "Talentos", "Talents", "Árbol de talentos" },
	{ "📊", "Stats", "Stats", "Tus estadísticas" },
	{ "⚔️", "Arma", "Weapon", "Elegir arma" },
	{ Icons.Shop, "Tienda", "Shop", "Ofertas del día" },
	{ "📜", "Misiones", "Missions", "Misiones diarias y semanales" },
}
for i, item in lobbyButtons do
	local action = item[3]
	local b = make("TextButton", {
		Size = UDim2.new(0, 76, 0, 76),
		BackgroundColor3 = C(18, 15, 28),
		BackgroundTransparency = 0.15,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = i,
		Parent = dock,
	}, { Theme.corner(16), make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(165, 155, 185)) }) })
	local stroke = make("UIStroke", { Color = Colors.GoldDark, Thickness = 1.5, Transparency = 0.2, Parent = b })
	local scale = make("UIScale", { Parent = b })
	text({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 6), Text = item[1], TextSize = 30, Parent = b })
	text({
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 18),
		Text = item[2],
		Font = Fonts.Bold,
		TextSize = 13,
		TextColor3 = Colors.GoldBright,
		Parent = b,
	})
	local badgeAttr = if action == "Missions" then "MissionsClaimable" elseif action == "Talents" then "TalentPoints" else nil
	if badgeAttr then
		-- Aviso con la cantidad de cosas pendientes (misiones para cobrar, puntos de talento)
		local badge = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 6, 0, -6),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Colors.Danger,
			Font = Fonts.Bold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			Visible = false,
			ZIndex = 3,
			Parent = b,
		}, { Theme.corner(12), make("UIStroke", { Color = C(30, 10, 10), Thickness = 1.5 }) })
		local function updateBadge()
			local n = (player:GetAttribute(badgeAttr) or 0) :: number
			badge.Visible = n > 0
			badge.Text = tostring(n)
		end
		player:GetAttributeChangedSignal(badgeAttr):Connect(updateBadge)
		updateBadge()
	end
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.07 }):Play()
		TweenService:Create(stroke, QUICK, { Color = Colors.GoldBright, Transparency = 0 }):Play()
		dockTipText.Text = item[4]
		dockTip.Position = UDim2.fromOffset(28 + 76 + 12, 128 + (i - 1) * 84 + 21)
		dockTip.Visible = true
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
		TweenService:Create(stroke, QUICK, { Color = Colors.GoldDark, Transparency = 0.2 }):Play()
		dockTip.Visible = false
	end)
	b.Activated:Connect(function()
		if action == "Equipment" then
			playerGui:SetAttribute("EquipmentTab", "Equipo")
		elseif action == "Talents" then
			playerGui:SetAttribute("TalentsOpen", true)
		elseif action == "Stats" then
			playerGui:SetAttribute("StatsOpen", true)
		elseif action == "Weapon" then
			playerGui:SetAttribute("WeaponOpen", true)
		elseif action == "Shop" then
			playerGui:SetAttribute("ShopOpen", nil)
			playerGui:SetAttribute("ShopOpen", "Tienda")
		elseif action == "Missions" then
			playerGui:SetAttribute("ShopOpen", nil)
			playerGui:SetAttribute("ShopOpen", "Misiones")
		end
	end)
end

---------------------------------------------------------------------
-- Equipo (abajo a la izquierda, compacto)
---------------------------------------------------------------------
local teamPanel = glass({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -28),
	Size = UDim2.new(0, 290, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = content,
})
Theme.padding(12).Parent = teamPanel
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = teamPanel })
local teamHeader = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 0, Parent = teamPanel })
local teamTitle = header(teamHeader, Icons.Team .. "  EQUIPO")
local readyCounter = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 120, 1, 0),
	Font = Fonts.Bold,
	TextSize = 14,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = teamHeader,
})
local teamList = make("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Parent = teamPanel,
}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
-- Invitar / salir del grupo (solo en la Ciudadela)
local teamActions = make("Frame", {
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Parent = teamPanel,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local function smallButton(props: { [string]: any }): TextButton
	local b = make("TextButton", {
		Size = props.Size or UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = props.BackgroundColor3 or C(52, 44, 74),
		AutoButtonColor = false,
		Text = props.Text,
		Font = Fonts.Bold,
		TextSize = props.TextSize or 14,
		TextColor3 = props.TextColor3 or Colors.GoldBright,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
	}, { Theme.corner(9), make("UIStroke", { Color = Colors.GoldDark, Thickness = 1.2 }) })
	local scale = make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	return b
end
local inviteButton = smallButton({ Text = "＋  Invitar", LayoutOrder = 1, Parent = teamActions })
local leaveButton = smallButton({
	Text = "Salir del grupo",
	LayoutOrder = 2,
	TextColor3 = Colors.Text,
	BackgroundColor3 = C(70, 34, 40),
	Parent = teamActions,
})

---------------------------------------------------------------------
-- Tarjeta de batalla (derecha): capítulo elegido + botón para cambiarlo
---------------------------------------------------------------------
local battle = glass({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -28, 0, 110),
	Size = UDim2.new(0, 330, 0, 196),
	Parent = content,
})
Theme.padding(14).Parent = battle
header(battle, "⚔  BATALLA")
local chapterHint = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0.6, 0, 0, 22),
	Font = Fonts.Body,
	TextSize = 13,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = battle,
})
local battleIcon = text({
	Position = UDim2.new(0, 0, 0, 32),
	Size = UDim2.fromOffset(56, 56),
	Text = "",
	TextSize = 40,
	Parent = battle,
})
local battleName = text({
	Position = UDim2.new(0, 64, 0, 32),
	Size = UDim2.new(1, -64, 0, 26),
	Text = "",
	Font = Fonts.Heading,
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = battle,
})
local battleRecord = text({
	Position = UDim2.new(0, 64, 0, 60),
	Size = UDim2.new(1, -64, 0, 20),
	Text = "",
	Font = Fonts.Bold,
	TextSize = 14,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = battle,
})
local battleDesc = text({
	Position = UDim2.new(0, 0, 0, 92),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "",
	Font = Fonts.Body,
	TextSize = 14,
	TextColor3 = Colors.TextMuted,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = battle,
})
local changeButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = C(52, 44, 74),
	AutoButtonColor = false,
	Text = "📜  Cambiar capítulo",
	Font = Fonts.Bold,
	TextSize = 16,
	TextColor3 = Colors.GoldBright,
	Parent = battle,
}, { Theme.corner(10), make("UIStroke", { Color = Colors.GoldDark, Thickness = 1.2 }) })

---------------------------------------------------------------------
-- Ventana de capítulos (se abre con "Cambiar capítulo")
---------------------------------------------------------------------
local picker = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C(6, 5, 10),
	BackgroundTransparency = 0.45,
	Visible = false,
	ZIndex = 30,
	Parent = root,
})
local pickerWindow = glass({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(820, 540),
	BackgroundTransparency = 0.05,
	ZIndex = 31,
	Parent = picker,
})
local pickerScale = make("UIScale", { Parent = pickerWindow })
local function updatePickerScale()
	pickerScale.Scale = uiScale.Scale
end
uiScale:GetPropertyChangedSignal("Scale"):Connect(updatePickerScale)
updatePickerScale()
Theme.padding(20).Parent = pickerWindow
text({
	Size = UDim2.new(1, 0, 0, 40),
	Text = "Elegí tu batalla",
	Font = Fonts.Title,
	TextSize = 36,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 32,
	Parent = pickerWindow,
})
local closePicker = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = C(52, 44, 74),
	AutoButtonColor = false,
	Text = "X",
	Font = Fonts.Bold,
	TextSize = 20,
	TextColor3 = Colors.Text,
	ZIndex = 32,
	Parent = pickerWindow,
}, { Theme.corner(20), make("UIStroke", { Color = Colors.GoldDark, Thickness = 1.2 }) })
local chapterList = make("ScrollingFrame", {
	Position = UDim2.new(0, 0, 0, 56),
	Size = UDim2.new(1, 0, 1, -56),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Colors.GoldDark,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 32,
	Parent = pickerWindow,
}, {
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(378, 116),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
})

local function openPicker(open: boolean)
	picker.Visible = open
	if open then
		pickerWindow.Position = UDim2.new(0.5, 0, 0.5, 20)
		TweenService:Create(pickerWindow, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
end
changeButton.Activated:Connect(function()
	openPicker(true)
end)
closePicker.Activated:Connect(function()
	openPicker(false)
end)

type Card = { button: TextButton, stroke: UIStroke, lock: TextLabel, name: TextLabel, desc: TextLabel, record: TextLabel }
local cards: { [string]: Card } = {}

-- Capítulos y, después, los modos (Shared/Modes.lua): se eligen igual, por Id
local entries: { { def: any, order: number, title: string } } = {}
for i, ch in Chapters do
	table.insert(entries, { def = ch, order = i, title = string.format("Capítulo %d · %s", i, ch.Name) })
end
for i, m in Modes.List do
	table.insert(entries, { def = m, order = 100 + i, title = m.Name })
end

for _, entry in entries do
	local ch = entry.def
	local i = entry.order
	local card = make("TextButton", {
		BackgroundColor3 = Colors.PanelLight,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = i,
		ZIndex = 33,
		Parent = chapterList,
	}, { Theme.corner(12), Theme.padding(12) })
	local stroke = Theme.stroke(Colors.GoldDark, 1.5)
	stroke.Parent = card
	text({
		Size = UDim2.new(0, 48, 0, 48),
		Text = ch.Icon or "",
		TextSize = 34,
		ZIndex = 34,
		Parent = card,
	})
	local name = text({
		Position = UDim2.new(0, 58, 0, 0),
		Size = UDim2.new(1, -90, 0, 24),
		Text = entry.title,
		Font = Fonts.Heading,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 34,
		Parent = card,
	})
	local desc = text({
		Position = UDim2.new(0, 58, 0, 26),
		Size = UDim2.new(1, -58, 1, -46),
		Text = ch.Description or "",
		Font = Fonts.Body,
		TextSize = 13,
		TextColor3 = Colors.TextMuted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 34,
		Parent = card,
	})
	local record = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 58, 1, 0),
		Size = UDim2.new(1, -58, 0, 18),
		Text = "",
		Font = Fonts.Bold,
		TextSize = 13,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 34,
		Parent = card,
	})
	local lock = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 30, 0, 26),
		Text = Icons.Locked,
		TextSize = 20,
		Visible = false,
		ZIndex = 34,
		Parent = card,
	})
	card.Activated:Connect(function()
		if card.Active then
			lobbyRequest:FireServer("SelectChapter", ch.Id)
			openPicker(false)
		end
	end)
	cards[ch.Id] = { button = card, stroke = stroke, lock = lock, name = name, desc = desc, record = record }
end

---------------------------------------------------------------------
-- Ventana "Invitar al grupo": los jugadores libres de la Ciudadela
---------------------------------------------------------------------
local inviteModal = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C(6, 5, 10),
	BackgroundTransparency = 0.45,
	Visible = false,
	ZIndex = 30,
	Parent = root,
})
local inviteWindow = glass({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(480, 500),
	BackgroundTransparency = 0.05,
	ZIndex = 31,
	Parent = inviteModal,
})
local inviteScale = make("UIScale", { Parent = inviteWindow })
uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
	inviteScale.Scale = uiScale.Scale
end)
inviteScale.Scale = uiScale.Scale
Theme.padding(20).Parent = inviteWindow
text({
	Size = UDim2.new(1, -50, 0, 36),
	Text = "Invitar al grupo",
	Font = Fonts.Title,
	TextSize = 30,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 32,
	Parent = inviteWindow,
})
text({
	Position = UDim2.new(0, 0, 0, 36),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "Jugadores en la Ciudadela. Se suman al aceptar.",
	Font = Fonts.Body,
	TextSize = 13,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 32,
	Parent = inviteWindow,
})
local closeInvite = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = C(52, 44, 74),
	AutoButtonColor = false,
	Text = "X",
	Font = Fonts.Bold,
	TextSize = 20,
	TextColor3 = Colors.Text,
	ZIndex = 32,
	Parent = inviteWindow,
}, { Theme.corner(20), make("UIStroke", { Color = Colors.GoldDark, Thickness = 1.2 }) })
local inviteList = make("ScrollingFrame", {
	Position = UDim2.new(0, 0, 0, 66),
	Size = UDim2.new(1, 0, 1, -66),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Colors.GoldDark,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 32,
	Parent = inviteWindow,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) }),
})
local inviteEmpty = text({
	Position = UDim2.new(0, 0, 0, 90),
	Size = UDim2.new(1, 0, 0, 60),
	Text = "No hay nadie libre en la Ciudadela ahora.\nPodés usar BUSCAR GRUPO para jugar con otros.",
	Font = Fonts.Body,
	TextSize = 15,
	TextColor3 = Colors.TextMuted,
	TextWrapped = true,
	Visible = false,
	ZIndex = 32,
	Parent = inviteWindow,
})

---------------------------------------------------------------------
-- Invitación recibida (a la derecha, debajo de la batalla)
---------------------------------------------------------------------
local inviteCard = glass({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -28, 0, 322),
	Size = UDim2.new(0, 330, 0, 132),
	BackgroundColor3 = C(28, 22, 40),
	ZIndex = 12,
	Parent = content,
})
inviteCard.Visible = false
local inviteCardStroke = inviteCard:FindFirstChildOfClass("UIStroke") :: UIStroke
inviteCardStroke.Color = Colors.GoldBright
inviteCardStroke.Thickness = 2
Theme.padding(14).Parent = inviteCard
local inviteTitle = text({
	Size = UDim2.new(1, 0, 0, 22),
	Text = "✉  INVITACIÓN",
	Font = Fonts.Heading,
	TextSize = 15,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 13,
	Parent = inviteCard,
})
local inviteFrom = text({
	Position = UDim2.new(0, 0, 0, 24),
	Size = UDim2.new(1, 0, 0, 22),
	Text = "",
	Font = Fonts.Bold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 13,
	Parent = inviteCard,
})
local inviteInfo = text({
	Position = UDim2.new(0, 0, 0, 46),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "",
	Font = Fonts.Body,
	TextSize = 13,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 13,
	Parent = inviteCard,
})
local acceptButton = smallButton({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -8),
	Size = UDim2.new(0.5, -4, 0, 34),
	Text = Icons.Ready .. "  Aceptar",
	TextSize = 15,
	TextColor3 = C(16, 40, 22),
	BackgroundColor3 = Colors.Success,
	ZIndex = 13,
	Parent = inviteCard,
})
local declineButton = smallButton({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 1, -8),
	Size = UDim2.new(0.5, -4, 0, 34),
	Text = "Rechazar",
	TextSize = 15,
	TextColor3 = Colors.Text,
	ZIndex = 13,
	Parent = inviteCard,
})
local inviteTimer = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = Colors.GoldBright,
	BorderSizePixel = 0,
	ZIndex = 13,
	Parent = inviteCard,
}, { Theme.corner(2) })

---------------------------------------------------------------------
-- Botón JUGAR y estado (abajo al centro)
---------------------------------------------------------------------
local playButton = button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.new(0, 340, 0, 78),
	Text = Icons.Play .. "  JUGAR",
	TextSize = 32,
	Font = Fonts.Title,
	Parent = content,
})
-- Brillo que respira detrás del botón (hermano con ZIndex menor: queda atrás)
local playGlow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.fromOffset(364, 102),
	BackgroundColor3 = Colors.GoldBright,
	BackgroundTransparency = 0.8,
	ZIndex = 0,
	Parent = content,
}, { Theme.corner(20) })
local playSubtitle = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -38),
	Size = UDim2.new(0, 400, 0, 20),
	Font = Fonts.Body,
	TextSize = 15,
	TextColor3 = Colors.TextMuted,
	TextStrokeTransparency = 0.6,
	Parent = content,
})
local statusLabel = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -128),
	Size = UDim2.new(0, 640, 0, 26),
	Font = Fonts.Bold,
	TextSize = 18,
	TextColor3 = Colors.Text,
	TextStrokeTransparency = 0.5,
	Parent = content,
})

-- Cuenta regresiva grande en el centro
local countdownLabel = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(0, 300, 0, 160),
	Font = Fonts.Title,
	TextSize = 140,
	TextColor3 = Colors.GoldBright,
	TextStrokeTransparency = 0.3,
	Visible = false,
	Parent = content,
})
local countdownScale = make("UIScale", { Parent = countdownLabel })

-- Cola rápida: arma un grupo con otros jugadores del mismo capítulo
local queueButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0.5, 186, 1, -48),
	Size = UDim2.fromOffset(176, 62),
	BackgroundColor3 = C(28, 24, 44),
	BackgroundTransparency = 0.05,
	AutoButtonColor = false,
	Text = "",
	Parent = content,
}, {
	Theme.corner(14),
	make("UIStroke", { Color = Colors.GoldBright, Thickness = 1.6, Transparency = 0.15 }),
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 255, 255), C(170, 160, 195)) }),
})
local queueScale = make("UIScale", { Parent = queueButton })
local _queueTitle = text({
	Position = UDim2.new(0, 0, 0, 9),
	Size = UDim2.new(1, 0, 0, 24),
	Text = "🔎  BUSCAR GRUPO",
	Font = Fonts.Heading,
	TextSize = 17,
	TextColor3 = Colors.GoldBright,
	Parent = queueButton,
})
local queueSub = text({
	Position = UDim2.new(0, 0, 0, 34),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "Jugá con otros",
	Font = Fonts.Body,
	TextSize = 13,
	TextColor3 = Colors.TextMuted,
	Parent = queueButton,
})
queueButton.MouseEnter:Connect(function()
	TweenService:Create(queueScale, QUICK, { Scale = 1.05 }):Play()
end)
queueButton.MouseLeave:Connect(function()
	TweenService:Create(queueScale, QUICK, { Scale = 1 }):Play()
end)

---------------------------------------------------------------------
-- Avisos del servidor (arriba al centro)
---------------------------------------------------------------------
local toast = glass({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -80),
	Size = UDim2.new(0, 520, 0, 52),
	ZIndex = 10,
	Parent = content,
})
toast.Visible = false
local toastText = text({ Size = UDim2.fromScale(1, 1), Font = Fonts.Bold, TextSize = 17, TextWrapped = true, ZIndex = 11, Parent = toast })
local toastToken = 0
lobbyNotice.OnClientEvent:Connect(function(message: string)
	toastToken += 1
	local token = toastToken
	toastText.Text = message
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 24) }):Play()
	task.delay(3, function()
		if token == toastToken then
			local out = TweenService:Create(toast, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -80) })
			out.Completed:Connect(function()
				if token == toastToken then
					toast.Visible = false
				end
			end)
			out:Play()
		end
	end)
end)

---------------------------------------------------------------------
-- Pantalla de transición (al entrar y salir de la arena)
---------------------------------------------------------------------
local fade = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Colors.Background,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = gui,
})
local fadeText = text({
	Size = UDim2.fromScale(1, 1),
	Font = Fonts.Title,
	TextSize = 44,
	TextColor3 = Colors.GoldBright,
	TextTransparency = 1,
	ZIndex = 51,
	Parent = fade,
})
local function flash(message: string)
	fadeText.Text = message
	fade.BackgroundTransparency = 0
	fadeText.TextTransparency = 0
	task.delay(0.6, function()
		local info = TweenInfo.new(0.6)
		TweenService:Create(fade, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(fadeText, info, { TextTransparency = 1 }):Play()
	end)
end

---------------------------------------------------------------------
-- Estado → pantalla
---------------------------------------------------------------------
local MAX_PARTY = Config.Match.MaxPartySize

local function role(): string
	return (gameState:GetAttribute("PlaceRole") or "Lobby") :: string
end
local function partyMode(): boolean
	return role() == "Lobby"
end

-- Lo que antes era de todo el servidor, ahora es de tu grupo
local function selectedChapter(): string
	if partyMode() then
		return (player:GetAttribute("PartyChapter") or "") :: string
	end
	return (gameState:GetAttribute("SelectedChapter") or "") :: string
end
local function leaderId(): number
	if partyMode() then
		return (player:GetAttribute("PartyLeader") or player.UserId) :: number
	end
	return (gameState:GetAttribute("LeaderId") or 0) :: number
end
local function countdownEnd(): number
	if partyMode() then
		return (player:GetAttribute("PartyCountdownEnd") or 0) :: number
	end
	if gameState:GetAttribute("MatchState") ~= "STARTING" then
		return 0
	end
	return (gameState:GetAttribute("CountdownEnd") or 0) :: number
end
local function inQueue(): boolean
	return partyMode() and player:GetAttribute("InQueue") == true
end

local function myUnlocks(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("UnlockedChapters") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

-- "forest=2/10,ruins=0/4" -> { forest = { clears = 2, best = 10 }, ... }
local function myRecords(): { [string]: { clears: number, best: number } }
	local out = {}
	for id, clears, best in string.gmatch(player:GetAttribute("ChapterRecords") or "", "(%w+)=(%d+)/(%d+)") do
		out[id] = { clears = tonumber(clears) or 0, best = tonumber(best) or 0 }
	end
	return out
end

-- Tu equipo: en la Ciudadela, los de tu grupo; si no, todos los que no están jugando
local function teamPlayers(): { Player }
	local list = {}
	local myParty = player:GetAttribute("PartyId")
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InMatch") == true then
			continue
		end
		if partyMode() then
			if p == player or (myParty ~= nil and p:GetAttribute("PartyId") == myParty) then
				table.insert(list, p)
			end
		else
			table.insert(list, p)
		end
	end
	-- el líder primero, después por nombre
	local lead = leaderId()
	table.sort(list, function(a, b)
		if (a.UserId == lead) ~= (b.UserId == lead) then
			return a.UserId == lead
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

local function chapterName(id: string): string
	for i, ch in Chapters do
		if ch.Id == id then
			return string.format("Capítulo %d · %s", i, ch.Name)
		end
	end
	local m = Modes.ById[id]
	return if m then m.Name else id
end

local function chapterDef(id: string): any
	for _, ch in Chapters do
		if ch.Id == id then
			return ch
		end
	end
	return Modes.ById[id]
end

local function playerName(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	return if p then p.DisplayName else "el líder"
end

local function refreshTeam()
	for _, child in teamList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local lead = leaderId()
	local amLeader = lead == player.UserId
	local group = teamPlayers()
	local ready = 0
	for i, p in group do
		local isReady = p:GetAttribute("Ready") == true
		if isReady then
			ready += 1
		end
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Colors.PanelLight,
			BackgroundTransparency = 0.2,
			LayoutOrder = i,
			Parent = teamList,
		}, { Theme.corner(10) })
		if p == player then
			Theme.stroke(Colors.Gold, 1, 0.4).Parent = row
		end
		-- avatar chiquito
		local face = make("ImageLabel", {
			Position = UDim2.new(0, 6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = C(40, 34, 58),
			Image = "",
			Parent = row,
		}, { Theme.corner(15) })
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok and face.Parent then
				face.Image = img
			end
		end)
		local canKick = partyMode() and amLeader and p ~= player
		text({
			Position = UDim2.new(0, 44, 0, 0),
			Size = UDim2.new(1, if canKick then -176 else -140, 1, 0),
			Text = (if p.UserId == lead then Icons.Leader .. " " else "") .. p.DisplayName,
			Font = Fonts.Bold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local chip = make("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, if canKick then -42 else -6, 0.5, 0),
			Size = UDim2.new(0, 88, 0, 24),
			BackgroundColor3 = if isReady then Colors.Success else Colors.Panel,
			Parent = row,
		}, { Theme.corner(12) })
		text({
			Size = UDim2.fromScale(1, 1),
			Text = if isReady then Icons.Ready .. " LISTO" else "ESPERANDO",
			Font = Fonts.Bold,
			TextSize = 12,
			TextColor3 = if isReady then Color3.fromRGB(16, 40, 22) else Colors.TextMuted,
			Parent = chip,
		})
		if canKick then
			local kick = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(30, 26),
				BackgroundColor3 = C(70, 34, 40),
				AutoButtonColor = true,
				Text = "X",
				Font = Fonts.Bold,
				TextSize = 14,
				TextColor3 = Colors.Text,
				Parent = row,
			}, { Theme.corner(8) })
			local target = p.UserId
			kick.Activated:Connect(function()
				lobbyRequest:FireServer("Kick", target)
			end)
		end
	end
	-- Lugares libres del grupo
	if partyMode() then
		for i = #group + 1, MAX_PARTY do
			local slot = make("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = Colors.PanelLight,
				BackgroundTransparency = 0.75,
				LayoutOrder = i,
				Parent = teamList,
			}, { Theme.corner(10) })
			Theme.stroke(Colors.GoldDark, 1, 0.6).Parent = slot
			text({
				Size = UDim2.fromScale(1, 1),
				Text = "Lugar libre",
				Font = Fonts.Body,
				TextSize = 13,
				TextColor3 = Colors.TextMuted,
				Parent = slot,
			})
		end
	end
	teamTitle.Text = if partyMode()
		then string.format("%s  GRUPO  %d/%d", Icons.Team, #group, MAX_PARTY)
		else Icons.Team .. "  EQUIPO"
	readyCounter.Text = string.format("Listos %d/%d", ready, #group)
	-- Botones del grupo
	teamActions.Visible = partyMode()
	local busy = countdownEnd() > 0 or inQueue()
	inviteButton.Visible = #group < MAX_PARTY
	inviteButton.Active = not busy
	inviteButton.TextTransparency = if busy then 0.5 else 0
	leaveButton.Visible = #group > 1
	inviteButton.Size = if leaveButton.Visible then UDim2.new(0.5, -4, 1, 0) else UDim2.new(1, 0, 1, 0)
	leaveButton.Size = if inviteButton.Visible then UDim2.new(0.5, -4, 1, 0) else UDim2.new(1, 0, 1, 0)
end

local function recordText(id: string, rec: { clears: number, best: number }?): string
	local total = 0
	for _, ch in Chapters do
		if ch.Id == id then
			total = ch.Waves
		end
	end
	return if not rec
		then ""
		elseif id == "tower" then string.format("Récord: piso %d", rec.best)
		elseif rec.clears > 0 then string.format("✔ Ganado %d %s", rec.clears, if rec.clears == 1 then "vez" else "veces")
		else string.format("Mejor: oleada %d/%d", rec.best, total)
end

local function descText(id: string, isUnlocked: boolean): string
	if not isUnlocked then
		return if Modes.ById[id] then "Ganá el Capítulo 1 para desbloquearla." else "Ganá el capítulo anterior para desbloquearlo."
	elseif id == "daily" then
		return "Hoy: " .. Modes.dailyText(Modes.day(os.time())) .. ". Premio extra la primera victoria del día."
	end
	local def = chapterDef(id)
	return if def then def.Description or "" else ""
end

local function refreshChapters()
	local selected = selectedChapter()
	local isLeader = leaderId() == player.UserId
	local canChange = isLeader and not inQueue() and countdownEnd() == 0
	local unlocked = myUnlocks()
	local records = myRecords()
	for id, card in cards do
		local isUnlocked = unlocked[id] == true
		local isSelected = id == selected
		card.record.Text = recordText(id, records[id])
		card.lock.Visible = not isUnlocked
		card.stroke.Color = if isSelected then Colors.GoldBright else Colors.GoldDark
		card.stroke.Thickness = if isSelected then 3 else 1.5
		card.button.BackgroundColor3 = if isSelected then Color3.fromRGB(52, 44, 34) else Colors.PanelLight
		card.name.TextColor3 = if isUnlocked then Colors.Text else Colors.Locked
		card.button.Active = isLeader and isUnlocked
		card.button.AutoButtonColor = false
		card.desc.Text = descText(id, isUnlocked)
	end
	-- Tarjeta de batalla
	local def = chapterDef(selected)
	battleIcon.Text = if def then def.Icon or "⚔" else "⚔"
	battleName.Text = chapterName(selected)
	battleRecord.Text = recordText(selected, records[selected])
	battleDesc.Text = if selected ~= "" then descText(selected, true) else ""
	changeButton.Visible = canChange
	if isLeader then
		chapterHint.Text = if #teamPlayers() > 1 then "Sos el líder" else "Elegís vos"
	else
		chapterHint.Text = "Elige " .. playerName(leaderId())
	end
	if picker.Visible and not canChange then
		openPicker(false)
	end
	playSubtitle.Text = chapterName(selected)
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refreshMain()
	local inMatch = player:GetAttribute("InMatch") == true
	root.Visible = not inMatch
	if inMatch then
		return
	end
	local r = role()
	local arena = r == "Arena"
	local matchState = gameState:GetAttribute("MatchState")
	local isReady = player:GetAttribute("Ready") == true
	local counting = countdownEnd() > 0

	-- En la arena no se elige nada: solo se espera al grupo
	for _, f in { dock, teamPanel, battle, playButton, playGlow, playSubtitle } do
		f.Visible = not arena
	end
	queueButton.Visible = false
	if arena then
		if player:GetAttribute("Traveling") == "Lobby" or matchState == "RETURNING" then
			statusLabel.Text = "Volviendo a la Ciudadela…"
		elseif matchState == "STARTING" then
			statusLabel.Text = "¡Arranca la batalla! " .. chapterName(selectedChapter())
		else
			local waiting = gameState:GetAttribute("ArenaWaiting") or ""
			statusLabel.Text = "Preparando la batalla…" .. (if waiting ~= "" then "  (" .. waiting .. " llegaron)" else "")
		end
		countdownLabel.Visible = counting
		return
	end

	local busy = (not partyMode()) and (matchState == "PLAYING" or matchState == "RESULTS" or matchState == "RETURNING")
	local isLeader = leaderId() == player.UserId
	local group = teamPlayers()
	local queued = inQueue()
	playButton.Active = not busy and (not queued or isLeader)
	if busy then
		playButton.Text = "Partida en curso…"
		playButton.BackgroundColor3 = Colors.Locked
		statusLabel.Text = "Hay una partida en juego. Te sumás a la siguiente."
	elseif queued then
		-- el texto con el tiempo lo actualiza el RenderStepped
		playButton.BackgroundColor3 = C(70, 110, 170)
	elseif isReady then
		playButton.Text = Icons.Ready .. "  LISTO  ·  Cancelar"
		playButton.BackgroundColor3 = Colors.Success
	else
		playButton.Text = Icons.Play .. "  JUGAR"
		playButton.BackgroundColor3 = Colors.Gold
	end
	playGlow.BackgroundColor3 = if queued then C(110, 160, 230) elseif isReady then Colors.Success else Colors.GoldBright

	-- BUSCAR GRUPO: lo usa el líder, si al grupo le falta gente
	queueButton.Visible = partyMode() and isLeader and not queued and not counting and #group < MAX_PARTY
	queueSub.Text = if #group > 1 then string.format("Completar grupo (%d/%d)", #group, MAX_PARTY) else "Jugá con otros"

	if not busy then
		local ready = 0
		for _, p in group do
			if p:GetAttribute("Ready") == true then
				ready += 1
			end
		end
		if queued then
			statusLabel.Text = if isLeader
				then "Buscando jugadores para " .. chapterName(selectedChapter()) .. "…"
				else playerName(leaderId()) .. " está buscando más jugadores…"
		elseif counting then
			statusLabel.Text = "¡Todos listos! " .. chapterName(selectedChapter())
		elseif ready > 0 and #group > 1 then
			statusLabel.Text = string.format("Esperando a que todos estén listos (%d/%d)", ready, #group)
		else
			statusLabel.Text = ""
		end
	end
	countdownLabel.Visible = counting
end

---------------------------------------------------------------------
-- Ventana de invitar
---------------------------------------------------------------------
local invitedAt: { [number]: number } = {}

local function refreshInviteList()
	if not inviteModal.Visible then
		return
	end
	for _, child in inviteList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local myParty = player:GetAttribute("PartyId")
	local count = 0
	local candidates = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("InMatch") ~= true and p:GetAttribute("Traveling") == nil
			and (myParty == nil or p:GetAttribute("PartyId") ~= myParty) then
			table.insert(candidates, p)
		end
	end
	table.sort(candidates, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	for i, p in candidates do
		count += 1
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Colors.PanelLight,
			BackgroundTransparency = 0.15,
			LayoutOrder = i,
			ZIndex = 33,
			Parent = inviteList,
		}, { Theme.corner(10) })
		local face = make("ImageLabel", {
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = C(40, 34, 58),
			Image = "",
			ZIndex = 34,
			Parent = row,
		}, { Theme.corner(19) })
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok and face.Parent then
				face.Image = img
			end
		end)
		text({
			Position = UDim2.new(0, 56, 0, 6),
			Size = UDim2.new(1, -180, 0, 22),
			Text = p.DisplayName,
			Font = Fonts.Bold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 34,
			Parent = row,
		})
		local size = (p:GetAttribute("PartySize") or 1) :: number
		text({
			Position = UDim2.new(0, 56, 0, 28),
			Size = UDim2.new(1, -180, 0, 18),
			Text = string.format("Nivel %d", (p:GetAttribute("AccountLevel") or 1) :: number)
				.. (if size > 1 then string.format("  ·  en un grupo (%d/%d)", size, MAX_PARTY) else ""),
			Font = Fonts.Body,
			TextSize = 13,
			TextColor3 = Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 34,
			Parent = row,
		})
		local sent = (invitedAt[p.UserId] or -math.huge) > os.clock() - 8
		local b = smallButton({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(108, 34),
			Text = if sent then Icons.Ready .. " Enviada" else "Invitar",
			TextSize = 15,
			TextColor3 = if sent then Colors.TextMuted else C(30, 22, 10),
			BackgroundColor3 = if sent then C(52, 44, 74) else Colors.Gold,
			ZIndex = 34,
			Parent = row,
		})
		local userId = p.UserId
		b.Activated:Connect(function()
			if (invitedAt[userId] or -math.huge) > os.clock() - 8 then
				return
			end
			invitedAt[userId] = os.clock()
			lobbyRequest:FireServer("Invite", userId)
			refreshInviteList()
			task.delay(8.1, refreshInviteList)
		end)
	end
	inviteEmpty.Visible = count == 0
end

local function openInvite(open: boolean)
	inviteModal.Visible = open
	if open then
		refreshInviteList()
		inviteWindow.Position = UDim2.new(0.5, 0, 0.5, 20)
		TweenService:Create(inviteWindow, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
end
inviteButton.Activated:Connect(function()
	if inviteButton.Active then
		openInvite(true)
	end
end)
closeInvite.Activated:Connect(function()
	openInvite(false)
end)
leaveButton.Activated:Connect(function()
	lobbyRequest:FireServer("LeaveParty")
end)

---------------------------------------------------------------------
-- Invitaciones recibidas (de a una; las demás esperan su turno)
---------------------------------------------------------------------
type Invite = { PartyId: string, From: string, FromId: number, Chapter: string, Size: number, Expires: number }
local inbox: { Invite } = {}
local shownInvite: Invite? = nil

local function showNextInvite()
	local t = workspace:GetServerTimeNow()
	while #inbox > 0 and (inbox[1].Expires <= t or inbox[1].PartyId == player:GetAttribute("PartyId")) do
		table.remove(inbox, 1)
	end
	local nextInvite = inbox[1]
	if nextInvite == shownInvite then
		return
	end
	shownInvite = nextInvite
	if not nextInvite then
		inviteCard.Visible = false
		return
	end
	inviteFrom.Text = nextInvite.From .. " te invita a su grupo"
	inviteInfo.Text = string.format("%s  ·  %d/%d jugadores", chapterName(nextInvite.Chapter), nextInvite.Size, MAX_PARTY)
	inviteTitle.Text = if #inbox > 1 then string.format("✉  INVITACIÓN  (+%d)", #inbox - 1) else "✉  INVITACIÓN"
	inviteCard.Visible = true
	Theme.popIn(inviteCard)
end

partyInvite.OnClientEvent:Connect(function(info: any)
	if type(info) ~= "table" or type(info.PartyId) ~= "string" then
		return
	end
	-- una sola por grupo (la más nueva)
	for i = #inbox, 1, -1 do
		if inbox[i].PartyId == info.PartyId then
			table.remove(inbox, i)
		end
	end
	table.insert(inbox, info :: Invite)
	shownInvite = nil
	showNextInvite()
end)
local function answerInvite(accept: boolean)
	local current = shownInvite
	if not current then
		return
	end
	lobbyRequest:FireServer(if accept then "AcceptInvite" else "DeclineInvite", current.PartyId)
	for i, inv in inbox do
		if inv == current then
			table.remove(inbox, i)
			break
		end
	end
	shownInvite = nil
	showNextInvite()
end
acceptButton.Activated:Connect(function()
	answerInvite(true)
end)
declineButton.Activated:Connect(function()
	answerInvite(false)
end)

local function refreshAll()
	refreshTeam()
	refreshChapters()
	refreshMain()
	refreshInviteList()
end

playButton.Activated:Connect(function()
	if not playButton.Active then
		return
	end
	if inQueue() then
		lobbyRequest:FireServer("Queue", false)
	else
		lobbyRequest:FireServer("SetReady", player:GetAttribute("Ready") ~= true)
	end
end)
queueButton.Activated:Connect(function()
	if player:GetAttribute("Ready") == true then
		lobbyRequest:FireServer("SetReady", false)
	end
	lobbyRequest:FireServer("Queue", true)
end)

-- Cuenta regresiva (con la hora del servidor), tiempo en la cola, invitación y brillo del JUGAR
local lastShown = -1
local lastQueueSecond = -1
RunService.RenderStepped:Connect(function()
	if not root.Visible then
		return
	end
	local t = os.clock()
	local serverT = workspace:GetServerTimeNow()
	playGlow.BackgroundTransparency = 0.72 + 0.16 * (0.5 + 0.5 * math.sin(t * 2.4))
	if inQueue() then
		local waited = math.floor(serverT - ((player:GetAttribute("QueueSince") or serverT) :: number))
		if waited ~= lastQueueSecond then
			lastQueueSecond = waited
			playButton.Text = if leaderId() == player.UserId
				then "🔎  " .. formatTime(waited) .. "  ·  Cancelar"
				else "🔎  Buscando…  " .. formatTime(waited)
		end
	elseif lastQueueSecond ~= -1 then
		lastQueueSecond = -1
		refreshMain()
	end
	if shownInvite then
		local left = shownInvite.Expires - serverT
		if left <= 0 then
			showNextInvite()
		else
			inviteTimer.Size = UDim2.new(math.clamp(left / Config.Places.InviteTime, 0, 1), 0, 0, 4)
		end
	end
	if not countdownLabel.Visible then
		lastShown = -1
		return
	end
	local left = math.max(0, math.ceil(countdownEnd() - serverT))
	if left ~= lastShown then
		lastShown = left
		countdownLabel.Text = if left > 0 then tostring(left) else Icons.Play
		countdownScale.Scale = 1.35
		TweenService:Create(countdownScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end)

---------------------------------------------------------------------
-- Escuchar cambios (todo por atributos replicados: sin consultas al servidor)
---------------------------------------------------------------------
-- Varias señales llegan juntas (el servidor publica el grupo entero): se redibuja una vez por frame
local refreshQueued = false
local function scheduleRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refreshAll()
	end)
end

for _, attr in { "MatchState", "SelectedChapter", "LeaderId", "CountdownEnd", "PlaceRole", "ArenaWaiting" } do
	gameState:GetAttributeChangedSignal(attr):Connect(scheduleRefresh)
end

local WATCHED_ATTRS = {
	"Ready", "InMatch", "UnlockedChapters", "ChapterRecords", "Traveling", "AccountLevel",
	"PartyId", "PartyLeader", "PartyChapter", "PartyCountdownEnd", "InQueue", "PartySize",
}
local watched: { [Player]: { RBXScriptConnection } } = {}
local function watchPlayer(p: Player)
	local conns = {}
	for _, attr in WATCHED_ATTRS do
		table.insert(conns, p:GetAttributeChangedSignal(attr):Connect(scheduleRefresh))
	end
	watched[p] = conns
	scheduleRefresh()
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	-- Sin fugas: se desconectan las escuchas de quien se va
	for _, c in (watched[p] or {}) :: { RBXScriptConnection } do
		c:Disconnect()
	end
	watched[p] = nil
	scheduleRefresh()
end)

local function popAll()
	for _, f in { playerCard, battle, teamPanel, dock } do
		if f.Visible then
			Theme.popIn(f)
		end
	end
end

-- Transiciones con pantalla negra al entrar y al salir de la partida
local previousInMatch = player:GetAttribute("InMatch") == true
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	local nowInMatch = player:GetAttribute("InMatch") == true
	if nowInMatch and not previousInMatch then
		openPicker(false)
		openInvite(false)
		flash(Icons.Play .. "  " .. chapterName(selectedChapter()))
	elseif previousInMatch and not nowInMatch then
		flash(if role() == "Arena" then "Fin de la batalla" else "De vuelta en la Ciudadela")
		popAll()
	end
	previousInMatch = nowInMatch
end)

refreshAll()
popAll()
