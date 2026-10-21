-- EventsHud (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > EventsHud
-- Lo que pasa dentro de la oleada (Server/WaveEvents): la meta de equipo arriba al centro, con
-- su progreso y tiempo; el cartel de "¡HORDA!" con cuántos quedan; y el aviso de cada élite.
-- Solo lee atributos de GameState (los sonidos están en Sfx).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("UITheme"))
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer
local Colors = Theme.Colors
local ELITE = Color3.fromRGB(200, 110, 255)
local HORDE = Color3.fromRGB(255, 90, 70)

local gui = Theme.make("ScreenGui", {
	Name = "EventsHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 6,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local function refreshEnabled()
	gui.Enabled = player:GetAttribute("InMatch") == true
end
player:GetAttributeChangedSignal("InMatch"):Connect(refreshEnabled)
refreshEnabled()

---------------------------------------------------------------------
-- Meta de equipo (debajo de la barra de oleada)
---------------------------------------------------------------------
local goalPanel = Theme.panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 66),
	Size = UDim2.new(0.6, 0, 0, 50),
	BackgroundTransparency = 0.2,
	Visible = false,
	Parent = gui,
})
Theme.make("UISizeConstraint", { MaxSize = Vector2.new(420, 50), Parent = goalPanel })
local goalStroke = Theme.stroke(Colors.Gold, 1.5)
goalStroke.Parent = goalPanel
local goalTitle = Theme.text({
	Position = UDim2.fromOffset(10, 3),
	Size = UDim2.new(1, -70, 0, 16),
	Text = "🎯 META DE EQUIPO",
	Font = Theme.Fonts.Bold,
	TextSize = 12,
	TextColor3 = Colors.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = goalPanel,
})
local goalTime = Theme.text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 3),
	Size = UDim2.fromOffset(60, 16),
	Text = "",
	Font = Theme.Fonts.Bold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = goalPanel,
})
local goalText = Theme.text({
	Position = UDim2.fromOffset(10, 19),
	Size = UDim2.new(1, -20, 0, 16),
	Text = "",
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = goalPanel,
})
local goalBack = Theme.make("Frame", {
	Position = UDim2.new(0, 10, 1, -10),
	Size = UDim2.new(1, -20, 0, 5),
	BackgroundColor3 = Color3.fromRGB(45, 40, 58),
	BorderSizePixel = 0,
	Parent = goalPanel,
}, { Theme.corner(3) })
local goalFill = Theme.make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Gold,
	BorderSizePixel = 0,
	Parent = goalBack,
}, { Theme.corner(3) })

local hideToken = 0
local lastGoalState = ""

local function refreshGoal()
	local state = gameState:GetAttribute("GoalState") or ""
	local progress = gameState:GetAttribute("GoalProgress") or 0
	local target = math.max(1, gameState:GetAttribute("GoalTarget") or 1)
	local timeLeft = gameState:GetAttribute("GoalTimeLeft") or -1
	if state == "" then
		goalPanel.Visible = false
		lastGoalState = state
		return
	end
	goalPanel.Visible = true
	goalText.Text = gameState:GetAttribute("GoalText") or ""
	local id = gameState:GetAttribute("GoalId")
	local showCount = id == "Kills" or id == "Chests"
	if state == "active" then
		goalTitle.Text = if showCount then string.format("🎯 META DE EQUIPO  ·  %d/%d", progress, target) else "🎯 META DE EQUIPO"
		goalTitle.TextColor3 = Colors.GoldBright
		goalStroke.Color = Colors.Gold
		goalFill.BackgroundColor3 = Colors.Gold
		goalTime.Text = if timeLeft >= 0 then string.format("⏱ %d s", timeLeft) else "toda la oleada"
		goalTime.TextColor3 = if timeLeft >= 0 and timeLeft <= 5 then Colors.Danger else Colors.Text
	elseif state == "done" then
		goalTitle.Text = "✔ ¡META CUMPLIDA!  ·  premio para el equipo"
		goalTitle.TextColor3 = Colors.Success
		goalStroke.Color = Colors.Success
		goalFill.BackgroundColor3 = Colors.Success
		goalTime.Text = ""
	else
		goalTitle.Text = "✖ Meta fallida"
		goalTitle.TextColor3 = Colors.TextMuted
		goalStroke.Color = Colors.Locked
		goalFill.BackgroundColor3 = Colors.Locked
		goalTime.Text = ""
	end
	local fraction = if state == "done" then 1 else math.clamp(progress / target, 0, 1)
	TweenService:Create(goalFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(fraction, 1) }):Play()
	if state ~= lastGoalState then
		if state == "active" then
			Theme.popIn(goalPanel)
		end
		-- Cumplida o fallida: queda un rato y se va
		hideToken += 1
		local token = hideToken
		if state == "done" or state == "failed" then
			task.delay(4, function()
				if token == hideToken then
					goalPanel.Visible = false
				end
			end)
		end
	end
	lastGoalState = state
end
for _, attr in { "GoalState", "GoalText", "GoalProgress", "GoalTarget", "GoalTimeLeft", "GoalId" } do
	gameState:GetAttributeChangedSignal(attr):Connect(refreshGoal)
end
refreshGoal()

---------------------------------------------------------------------
-- Carteles grandes (horda y élites)
---------------------------------------------------------------------
local banner = Theme.text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.34),
	Size = UDim2.new(1, 0, 0, 56),
	Text = "",
	Font = Theme.Fonts.Title,
	TextSize = 46,
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
	Parent = gui,
})
local bannerSub = Theme.text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.34, 30),
	Size = UDim2.new(1, 0, 0, 24),
	Text = "",
	Font = Theme.Fonts.Bold,
	TextSize = 18,
	TextStrokeTransparency = 0.4,
	TextTransparency = 1,
	Parent = gui,
})
local bannerScale = Theme.make("UIScale", { Parent = banner })
local bannerToken = 0

local function showBanner(title: string, sub: string, color: Color3, seconds: number)
	bannerToken += 1
	local token = bannerToken
	banner.Text = title
	banner.TextColor3 = color
	bannerSub.Text = sub
	bannerSub.TextColor3 = Colors.Text
	for _, label in { banner, bannerSub } do
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.3
	end
	bannerScale.Scale = 1.6
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds, function()
		if token ~= bannerToken then
			return
		end
		for _, label in { banner, bannerSub } do
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Contador de la horda (debajo de la meta)
local hordeLabel = Theme.text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 122),
	Size = UDim2.fromOffset(300, 26),
	Text = "",
	Font = Theme.Fonts.Bold,
	TextSize = 20,
	TextColor3 = HORDE,
	TextStrokeTransparency = 0.3,
	Visible = false,
	Parent = gui,
})

-- Borde rojo que late mientras dura la horda
local vignette = Theme.make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = gui,
})
local vignetteStroke = Theme.make("UIStroke", {
	Color = HORDE,
	Thickness = 18,
	Transparency = 1,
	Parent = vignette,
})

local lastHorde = ""
local function refreshHorde()
	local state = gameState:GetAttribute("HordeState") or ""
	local left = gameState:GetAttribute("HordeLeft") or 0
	hordeLabel.Visible = state == "active"
	hordeLabel.Text = string.format("☠ Horda: %d", left)
	if state ~= lastHorde then
		if state == "active" then
			showBanner("⚠ ¡HORDA! ⚠", "Vienen de todos lados: aguanten", HORDE, 2.2)
		elseif state == "cleared" then
			showBanner("¡Horda superada!", "Oro y un cofre para el equipo", Colors.GoldBright, 2.2)
		end
	end
	lastHorde = state
end
gameState:GetAttributeChangedSignal("HordeState"):Connect(refreshHorde)
gameState:GetAttributeChangedSignal("HordeLeft"):Connect(refreshHorde)
refreshHorde()

task.spawn(function()
	while true do
		task.wait(0.05)
		if hordeLabel.Visible then
			vignetteStroke.Transparency = 0.55 + 0.3 * math.abs(math.sin(os.clock() * 4))
		elseif vignetteStroke.Transparency < 1 then
			vignetteStroke.Transparency = 1
		end
	end
end)

-- Élite: "¡Élite Veloz!" con el enemigo
gameState:GetAttributeChangedSignal("EliteAnnounce"):Connect(function()
	local text = gameState:GetAttribute("EliteAnnounce")
	if type(text) ~= "string" or text == "" then
		return
	end
	local parts = string.split(text, "|")
	showBanner("★ ÉLITE " .. string.upper(parts[1] or "") .. " ★", (parts[2] or "") .. " · al morir suelta un cofre", ELITE, 1.8)
end)
