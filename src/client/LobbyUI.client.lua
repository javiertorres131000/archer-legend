-- LobbyUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > LobbyUI
-- Interfaz del lobby: equipo, capítulos, botón JUGAR/LISTO, cuenta regresiva y avisos.
-- Solo muestra estado y manda pedidos: todo lo decide el servidor (MatchManager).
-- Lee: atributos de GameState (MatchState, SelectedChapter, LeaderId, CountdownEnd) y de
-- cada Player (Ready, InMatch, UnlockedChapters, ChapterRecords, ProfileStatus y una por moneda).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Theme = require(Shared:WaitForChild("UITheme"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local lobbyRequest = remotes:WaitForChild("LobbyRequest") :: RemoteEvent
local lobbyNotice = remotes:WaitForChild("LobbyNotice") :: RemoteEvent
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer
local Colors, Fonts, Icons = Theme.Colors, Theme.Fonts, Theme.Icons
local make, text, panel, button = Theme.make, Theme.text, Theme.panel, Theme.button

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
	Parent = player:WaitForChild("PlayerGui"),
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

-- Viñeta inferior para que el texto se lea sobre el escenario
local vignette = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0.45),
	BackgroundColor3 = Colors.Background,
	BorderSizePixel = 0,
	Parent = root,
})
make("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	}),
	Parent = vignette,
})

-- Título
text({
	Position = UDim2.new(0, 40, 0, 28),
	Size = UDim2.new(0, 520, 0, 64),
	Text = Config.UI.GameTitle,
	Font = Fonts.Title,
	TextSize = 58,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextStrokeTransparency = 0.5,
	Parent = content,
})
text({
	Position = UDim2.new(0, 44, 0, 90),
	Size = UDim2.new(0, 520, 0, 24),
	Text = Config.UI.Subtitle,
	Font = Fonts.Heading,
	TextSize = 18,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = content,
})

---------------------------------------------------------------------
-- Monedas y estado del perfil (arriba a la derecha)
---------------------------------------------------------------------
local wallet = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -40, 0, 34),
	Size = UDim2.new(0, 600, 0, 44),
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
	local chip = panel({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = i,
		Parent = wallet,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16), Parent = chip })
	walletLabels[c.Id] = text({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = c.Icon .. "  0",
		Font = Fonts.Bold,
		TextSize = 20,
		TextColor3 = c.Color,
		Parent = chip,
	})
end
local profileLabel = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -40, 0, 84),
	Size = UDim2.new(0, 600, 0, 22),
	Font = Fonts.Body,
	TextSize = 15,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = content,
})

local function formatAmount(n: number): string
	-- 12345 -> "12.345"
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out
end

local function refreshWallet()
	for _, c in Currencies do
		walletLabels[c.Id].Text = c.Icon .. "  " .. formatAmount(player:GetAttribute(c.Id) or 0)
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

local function header(parent: Instance, icon: string, title: string): TextLabel
	return text({
		Size = UDim2.new(1, 0, 0, 30),
		Text = icon .. "  " .. title,
		Font = Fonts.Heading,
		TextSize = 20,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

---------------------------------------------------------------------
-- Panel de equipo (izquierda)
---------------------------------------------------------------------
local teamPanel = panel({
	Position = UDim2.new(0, 40, 0, 140),
	Size = UDim2.new(0, 300, 0, 330),
	Parent = content,
})
Theme.padding(16).Parent = teamPanel
header(teamPanel, Icons.Team, "EQUIPO")
local readyCounter = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 4),
	Size = UDim2.new(0, 120, 0, 24),
	Font = Fonts.Bold,
	TextSize = 16,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = teamPanel,
})
local teamList = make("Frame", {
	Position = UDim2.new(0, 0, 0, 40),
	Size = UDim2.new(1, 0, 1, -40),
	BackgroundTransparency = 1,
	Parent = teamPanel,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

---------------------------------------------------------------------
-- Panel de capítulos (derecha)
---------------------------------------------------------------------
local chapterPanel = panel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -40, 0, 140),
	Size = UDim2.new(0, 400, 0, 430),
	Parent = content,
})
Theme.padding(16).Parent = chapterPanel
header(chapterPanel, Icons.Chapter, "CAPÍTULO")
local chapterHint = text({
	Position = UDim2.new(0, 0, 0, 30),
	Size = UDim2.new(1, 0, 0, 20),
	Font = Fonts.Body,
	TextSize = 14,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = chapterPanel,
})
local chapterList = make("Frame", {
	Position = UDim2.new(0, 0, 0, 58),
	Size = UDim2.new(1, 0, 1, -58),
	BackgroundTransparency = 1,
	Parent = chapterPanel,
}, { make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

type Card = { button: TextButton, stroke: UIStroke, lock: TextLabel, name: TextLabel, desc: TextLabel, record: TextLabel }
local cards: { [string]: Card } = {}

for i, ch in Chapters do
	local card = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 108),
		BackgroundColor3 = Colors.PanelLight,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = i,
		Parent = chapterList,
	}, { Theme.corner(10), Theme.padding(12) })
	local stroke = Theme.stroke(Colors.GoldDark, 1.5)
	stroke.Parent = card
	text({
		Size = UDim2.new(0, 44, 0, 44),
		Text = ch.Icon or "",
		TextSize = 32,
		Parent = card,
	})
	local name = text({
		Position = UDim2.new(0, 54, 0, 0),
		Size = UDim2.new(1, -54, 0, 26),
		Text = string.format("Capítulo %d · %s", i, ch.Name),
		Font = Fonts.Heading,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	local desc = text({
		Position = UDim2.new(0, 54, 0, 28),
		Size = UDim2.new(1, -54, 1, -50),
		Text = ch.Description or "",
		Font = Fonts.Body,
		TextSize = 14,
		TextColor3 = Colors.TextMuted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local record = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 54, 1, 0),
		Size = UDim2.new(1, -54, 0, 18),
		Text = "",
		Font = Fonts.Bold,
		TextSize = 13,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local lock = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 30, 0, 26),
		Text = Icons.Locked,
		TextSize = 20,
		Visible = false,
		Parent = card,
	})
	card.Activated:Connect(function()
		lobbyRequest:FireServer("SelectChapter", ch.Id)
	end)
	cards[ch.Id] = { button = card, stroke = stroke, lock = lock, name = name, desc = desc, record = record }
end

---------------------------------------------------------------------
-- Botón JUGAR y estado (abajo al centro)
---------------------------------------------------------------------
local playButton = button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -48),
	Size = UDim2.new(0, 320, 0, 76),
	Text = Icons.Play .. "  JUGAR",
	TextSize = 30,
	Parent = content,
})
local statusLabel = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -134),
	Size = UDim2.new(0, 640, 0, 26),
	Font = Fonts.Body,
	TextSize = 18,
	TextColor3 = Colors.Text,
	TextStrokeTransparency = 0.6,
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

---------------------------------------------------------------------
-- Próximamente: inventario, equipamiento y tienda (abajo a la izquierda)
---------------------------------------------------------------------
local soonRow = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 40, 1, -48),
	Size = UDim2.new(0, 5 * 84 + 4 * 12, 0, 84),
	BackgroundTransparency = 1,
	Parent = content,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local soonTip = text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 40, 1, -140),
	Size = UDim2.new(0, 300, 0, 22),
	Text = "",
	Font = Fonts.Body,
	TextSize = 15,
	TextColor3 = Colors.TextMuted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = content,
})
-- Acción de cada botón: abrir equipo (el inventario y las runas son pestañas de Equipo),
-- abrir talentos o (tienda) próximamente
local lobbyButtons = {
	{ Icons.Equipment, "Equipo", "Equipment" },
	{ "⭐", "Talentos", "Talents" },
	{ "📊", "Stats", "Stats" },
	{ "⚔️", "Arma", "Weapon" },
	{ Icons.Shop, "Tienda", nil },
}
for i, item in lobbyButtons do
	local action = item[3]
	local b = make("TextButton", {
		Size = UDim2.new(0, 84, 0, 84),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = i,
		Parent = soonRow,
	}, { Theme.corner(12), Theme.stroke(Colors.Locked, 1.5) })
	text({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0, 6), Text = item[1], TextSize = 30, TextTransparency = if action then 0 else 0.45, Parent = b })
	text({
		Position = UDim2.new(0, 0, 1, -28),
		Size = UDim2.new(1, 0, 0, 22),
		Text = item[2],
		Font = Fonts.Bold,
		TextSize = 13,
		TextColor3 = if action then Colors.GoldBright else Colors.Locked,
		Parent = b,
	})
	local function showTip()
		soonTip.Text = if action then "Abrir " .. item[2] else Icons.Locked .. "  " .. item[2] .. ": próximamente"
	end
	b.MouseEnter:Connect(showTip)
	b.Activated:Connect(function()
		local playerGui = player:WaitForChild("PlayerGui")
		if action == "Equipment" then
			playerGui:SetAttribute("EquipmentTab", "Equipo")
		elseif action == "Talents" then
			playerGui:SetAttribute("TalentsOpen", true)
		elseif action == "Stats" then
			playerGui:SetAttribute("StatsOpen", true)
		elseif action == "Weapon" then
			playerGui:SetAttribute("WeaponOpen", true)
		else
			showTip()
		end
	end)
	b.MouseLeave:Connect(function()
		soonTip.Text = ""
	end)
end

---------------------------------------------------------------------
-- Avisos del servidor (arriba al centro)
---------------------------------------------------------------------
local toast = panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -80),
	Size = UDim2.new(0, 520, 0, 52),
	ZIndex = 10,
	Parent = content,
})
toast.Visible = false
local toastText = text({ Size = UDim2.fromScale(1, 1), Font = Fonts.Bold, TextSize = 17, TextWrapped = true, Parent = toast })
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

local function lobbyPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InMatch") ~= true then
			table.insert(list, p)
		end
	end
	return list
end

local function chapterName(id: string): string
	for i, ch in Chapters do
		if ch.Id == id then
			return string.format("Capítulo %d · %s", i, ch.Name)
		end
	end
	return id
end

local function refreshTeam()
	for _, child in teamList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local leaderId = gameState:GetAttribute("LeaderId")
	local group = lobbyPlayers()
	local ready = 0
	for i, p in group do
		local isReady = p:GetAttribute("Ready") == true
		if isReady then
			ready += 1
		end
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Colors.PanelLight,
			LayoutOrder = i,
			Parent = teamList,
		}, { Theme.corner(8), Theme.padding(10) })
		if p == player then
			Theme.stroke(Colors.Gold, 1, 0.4).Parent = row
		end
		text({
			Size = UDim2.new(1, -110, 1, 0),
			Text = (if p.UserId == leaderId then Icons.Leader .. " " else "") .. p.DisplayName,
			Font = Fonts.Bold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local chip = make("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 100, 0, 26),
			BackgroundColor3 = if isReady then Colors.Success else Colors.Panel,
			Parent = row,
		}, { Theme.corner(13) })
		text({
			Size = UDim2.fromScale(1, 1),
			Text = if isReady then Icons.Ready .. " LISTO" else "ESPERANDO",
			Font = Fonts.Bold,
			TextSize = 13,
			TextColor3 = if isReady then Color3.fromRGB(16, 40, 22) else Colors.TextMuted,
			Parent = chip,
		})
	end
	readyCounter.Text = string.format("Listos %d/%d", ready, #group)
end

local function refreshChapters()
	local selected = gameState:GetAttribute("SelectedChapter")
	local isLeader = gameState:GetAttribute("LeaderId") == player.UserId
	local unlocked = myUnlocks()
	local records = myRecords()
	for id, card in cards do
		local rec = records[id]
		local total = 0
		for _, ch in Chapters do
			if ch.Id == id then
				total = ch.Waves
			end
		end
		card.record.Text = if not rec
			then ""
			elseif rec.clears > 0 then string.format("✔ Ganado %d %s", rec.clears, if rec.clears == 1 then "vez" else "veces")
			else string.format("Mejor: oleada %d/%d", rec.best, total)
		local isUnlocked = unlocked[id] == true
		local isSelected = id == selected
		card.lock.Visible = not isUnlocked
		card.stroke.Color = if isSelected then Colors.GoldBright else Colors.GoldDark
		card.stroke.Thickness = if isSelected then 3 else 1.5
		card.button.BackgroundColor3 = if isSelected then Color3.fromRGB(52, 44, 34) else Colors.PanelLight
		card.name.TextColor3 = if isUnlocked then Colors.Text else Colors.Locked
		card.button.Active = isLeader and isUnlocked
		if not isUnlocked then
			card.desc.Text = "Ganá el capítulo anterior para desbloquearlo."
		else
			for _, ch in Chapters do
				if ch.Id == id then
					card.desc.Text = ch.Description or ""
				end
			end
		end
	end
	if isLeader then
		chapterHint.Text = "Sos el líder: elegí el capítulo"
	else
		local leaderName = "el líder"
		for _, p in Players:GetPlayers() do
			if p.UserId == gameState:GetAttribute("LeaderId") then
				leaderName = p.DisplayName
			end
		end
		chapterHint.Text = "Elige " .. leaderName
	end
end

local function refreshMain()
	local inMatch = player:GetAttribute("InMatch") == true
	root.Visible = not inMatch
	if inMatch then
		return
	end
	local matchState = gameState:GetAttribute("MatchState")
	local isReady = player:GetAttribute("Ready") == true
	local busy = matchState == "PLAYING" or matchState == "RESULTS" or matchState == "RETURNING"

	playButton.Active = not busy
	if busy then
		playButton.Text = "Partida en curso…"
		playButton.BackgroundColor3 = Colors.Locked
		statusLabel.Text = "Hay una partida en juego. Te sumás a la siguiente."
	elseif isReady then
		playButton.Text = Icons.Ready .. "  LISTO  ·  Cancelar"
		playButton.BackgroundColor3 = Colors.Success
	else
		playButton.Text = Icons.Play .. "  JUGAR"
		playButton.BackgroundColor3 = Colors.Gold
	end

	if not busy then
		local group = lobbyPlayers()
		local ready = 0
		for _, p in group do
			if p:GetAttribute("Ready") == true then
				ready += 1
			end
		end
		if matchState == "STARTING" then
			statusLabel.Text = "¡Todos listos! " .. chapterName(gameState:GetAttribute("SelectedChapter") or "")
		elseif ready > 0 then
			statusLabel.Text = string.format("Esperando a que todos estén listos (%d/%d)", ready, #group)
		else
			statusLabel.Text = chapterName(gameState:GetAttribute("SelectedChapter") or "")
		end
	end
	countdownLabel.Visible = matchState == "STARTING"
end

local function refreshAll()
	refreshTeam()
	refreshChapters()
	refreshMain()
end

playButton.Activated:Connect(function()
	if not playButton.Active then
		return
	end
	lobbyRequest:FireServer("SetReady", player:GetAttribute("Ready") ~= true)
end)

-- Cuenta regresiva: número que late cada segundo (calculado con la hora del servidor)
local lastShown = -1
RunService.RenderStepped:Connect(function()
	if not countdownLabel.Visible then
		lastShown = -1
		return
	end
	local countdownEnd = gameState:GetAttribute("CountdownEnd") or 0
	local left = math.max(0, math.ceil(countdownEnd - workspace:GetServerTimeNow()))
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
for _, attr in { "MatchState", "SelectedChapter", "LeaderId", "CountdownEnd" } do
	gameState:GetAttributeChangedSignal(attr):Connect(refreshAll)
end

local watched: { [Player]: { RBXScriptConnection } } = {}
local function watchPlayer(p: Player)
	local conns = {}
	for _, attr in { "Ready", "InMatch", "UnlockedChapters", "ChapterRecords" } do
		table.insert(conns, p:GetAttributeChangedSignal(attr):Connect(refreshAll))
	end
	watched[p] = conns
	refreshAll()
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
	task.defer(refreshAll)
end)

-- Transiciones con pantalla negra al entrar y al salir de la arena
local previousInMatch = player:GetAttribute("InMatch") == true
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	local nowInMatch = player:GetAttribute("InMatch") == true
	if nowInMatch and not previousInMatch then
		flash(Icons.Play .. "  " .. chapterName(gameState:GetAttribute("SelectedChapter") or ""))
	elseif previousInMatch and not nowInMatch then
		flash("De vuelta en el lobby")
		Theme.popIn(teamPanel)
		Theme.popIn(chapterPanel)
	end
	previousInMatch = nowInMatch
end)

refreshAll()
Theme.popIn(teamPanel)
Theme.popIn(chapterPanel)
