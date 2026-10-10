-- Hud (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Hud
-- Interfaz: oleada, barra de XP, anuncios, habilidades obtenidas y el menú de "elegí 1 de 3".
-- Toda la UI se crea por código para que viva en el repo (sin tocar StarterGui a mano).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local RarityVisuals = require(script.Parent.RarityVisuals)
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarities"))
local Skills = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skills"))
local Currencies = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Currencies"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skillOffer = remotes:WaitForChild("SkillOffer") :: RemoteEvent
local chooseSkill = remotes:WaitForChild("ChooseSkill") :: RemoteEvent
local skillGranted = remotes:WaitForChild("SkillGranted") :: RemoteEvent
local runReset = remotes:WaitForChild("RunReset") :: RemoteEvent
local runEnded = remotes:WaitForChild("RunEnded") :: RemoteEvent
local lobbyRequest = remotes:WaitForChild("LobbyRequest") :: RemoteEvent
local setAimMode = remotes:WaitForChild("SetAimMode") :: RemoteEvent
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextSize = props.TextSize or 18
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.6
	return make("TextLabel", props)
end

local function corner(radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

---------------------------------------------------------------------
-- Pantalla
---------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false, -- que no se borre al morir
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- El HUD de combate solo se ve dentro de la partida (en el lobby está LobbyUI)
local function refreshEnabled()
	gui.Enabled = player:GetAttribute("InMatch") == true
end
player:GetAttributeChangedSignal("InMatch"):Connect(refreshEnabled)
refreshEnabled()

-- Mira en el centro de la pantalla (solo en primera persona)
if Config.Camera.Mode == "FirstPerson" then
	local cross = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Colors.GoldBright,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), Theme.stroke(Color3.new(0, 0, 0), 1, 0.4) })
	-- Se oculta si quedás eliminado (la cámara pasa a mirar a un compañero)
	local function refreshCross()
		cross.Visible = player:GetAttribute("LifeState") ~= "ELIMINATED"
	end
	player:GetAttributeChangedSignal("LifeState"):Connect(refreshCross)
	refreshCross()
end

---------------------------------------------------------------------
-- Modo de apuntado: automático o manual (hacia la mira). Se cambia con Config.Player.AimToggleKeys.
---------------------------------------------------------------------
local aimKeys = {}
for _, key in Config.Player.AimToggleKeys or {} do
	aimKeys[key] = true
end
local aimKeyName = Config.Player.AimToggleKeys and Config.Player.AimToggleKeys[1] and Config.Player.AimToggleKeys[1].Name or ""

local aimLabel = Theme.text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 18),
	Size = UDim2.fromOffset(220, 20),
	Font = Theme.Fonts.Title,
	TextSize = 14,
	TextStrokeTransparency = 0.5,
	Parent = gui,
})
local function refreshAim()
	local manual = player:GetAttribute("AimMode") == "Manual"
	aimLabel.Text = string.format("%s  [%s]", if manual then "APUNTADO MANUAL" else "AUTO-APUNTADO", aimKeyName)
	aimLabel.TextColor3 = if manual then Theme.Colors.GoldBright else Theme.Colors.Text
	aimLabel.Visible = player:GetAttribute("LifeState") ~= "ELIMINATED"
end
player:GetAttributeChangedSignal("AimMode"):Connect(refreshAim)
player:GetAttributeChangedSignal("LifeState"):Connect(refreshAim)
refreshAim()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not aimKeys[input.KeyCode] then
		return
	end
	-- El servidor decide y lo devuelve en el atributo AimMode
	setAimMode:FireServer(if player:GetAttribute("AimMode") == "Manual" then "Auto" else "Manual")
end)

---------------------------------------------------------------------
-- Cambio de sala: fundido a negro corto al cruzar la puerta
---------------------------------------------------------------------
local roomFade = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 40,
	Parent = gui,
})
local roomFadeText = Theme.text({
	Size = UDim2.fromScale(1, 1),
	Font = Theme.Fonts.Title,
	TextSize = 40,
	TextColor3 = Theme.Colors.GoldBright,
	TextTransparency = 1,
	ZIndex = 41,
	Parent = roomFade,
})
gameState:GetAttributeChangedSignal("RoomIndex"):Connect(function()
	local room = gameState:GetAttribute("RoomIndex") or 1
	if room <= 1 or player:GetAttribute("InMatch") ~= true then
		return
	end
	roomFadeText.Text = "Sala " .. room
	roomFade.BackgroundTransparency = 0
	roomFadeText.TextTransparency = 0
	task.delay(0.5, function()
		local info = TweenInfo.new(0.5)
		TweenService:Create(roomFade, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(roomFadeText, info, { TextTransparency = 1 }):Play()
	end)
end)

-- La alerta de amenazas, el destello al recibir daño y la sangre por vida baja
-- están en ScreenEffects.client.lua.


-- Botín juntado en esta partida (arriba a la derecha). Ya está sumado al perfil.
local lootPanel = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 12),
	Size = UDim2.new(0, 0, 0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Theme.Colors.Panel,
	BackgroundTransparency = 0.25,
	Parent = gui,
}, {
	corner(10),
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
Theme.stroke(Theme.Colors.GoldDark, 1.5).Parent = lootPanel
local lootLabels: { [string]: TextLabel } = {}
for i, c in Currencies do
	lootLabels[c.Id] = text({
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = c.Icon .. " 0",
		TextSize = 18,
		TextColor3 = c.Color,
		TextStrokeTransparency = 0.5,
		LayoutOrder = i,
		Parent = lootPanel,
	})
end
local function refreshLoot()
	for _, c in Currencies do
		lootLabels[c.Id].Text = c.Icon .. " " .. tostring(player:GetAttribute("Run" .. c.Id) or 0)
	end
end
for _, c in Currencies do
	player:GetAttributeChangedSignal("Run" .. c.Id):Connect(refreshLoot)
end
refreshLoot()

-- Barra de vida propia (reemplaza la de Roblox, que LobbyUI desactiva)
local healthBack = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0, 320, 0, 20),
	BackgroundColor3 = Theme.Colors.Panel,
	BorderSizePixel = 0,
	Parent = gui,
}, { Theme.corner(10), Theme.stroke(Theme.Colors.GoldDark, 1.5) })
local healthFill = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Colors.Danger,
	BorderSizePixel = 0,
	Parent = healthBack,
}, { Theme.corner(10) })
local healthText = Theme.text({
	Size = UDim2.fromScale(1, 1),
	Font = Theme.Fonts.Bold,
	TextSize = 14,
	ZIndex = 2,
	Parent = healthBack,
})
local healthConn: RBXScriptConnection? = nil
local function watchHealth(character: Model)
	if healthConn then
		healthConn:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local function update()
		local frac = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		healthFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
	end
	healthConn = humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end
player.CharacterAdded:Connect(watchHealth)
if player.Character then
	task.spawn(watchHealth, player.Character)
end

-- Arriba al centro: oleada + barra de XP
local top = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.6, 0, 0, 52),
	BackgroundTransparency = 1,
	Parent = gui,
}, { make("UISizeConstraint", { MaxSize = Vector2.new(520, 52) }) })

local waveLabel = text({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextSize = 20, Parent = top })

local xpBack = make("Frame", {
	Position = UDim2.new(0, 0, 0, 30),
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35),
	BorderSizePixel = 0,
	Parent = top,
}, { corner(6) })

local xpFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(90, 200, 120),
	BorderSizePixel = 0,
	Parent = xpBack,
}, { corner(6) })

local xpText = text({ Size = UDim2.fromScale(1, 1), TextSize = 14, ZIndex = 2, Parent = xpBack })

-- Centro: anuncios que aparecen y se desvanecen
local announceLabel = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.25),
	Size = UDim2.new(1, 0, 0, 50),
	TextSize = 40,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Parent = gui,
})

-- Abajo a la izquierda: habilidades obtenidas
local ownedLabel = text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.new(0, 260, 0, 200),
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	Font = Enum.Font.Gotham,
	Parent = gui,
})

---------------------------------------------------------------------
-- Estado de la partida (atributos replicados de GameState)
---------------------------------------------------------------------
local function refreshWave()
	local phase = gameState:GetAttribute("Phase")
	local wave = gameState:GetAttribute("Wave") or 0
	local total = gameState:GetAttribute("TotalWaves") or 0
	local chapterTag = string.format("Cap. %d · %s", gameState:GetAttribute("Chapter") or 1, gameState:GetAttribute("ChapterName") or "")
	local party = gameState:GetAttribute("PartySize") or 1
	if party > 1 then
		chapterTag ..= string.format("  ·  %d jugadores", party)
	end
	if phase == "Wave" then
		waveLabel.Text = string.format(
			"%s  ·  Oleada %d/%d  ·  Enemigos: %d",
			chapterTag,
			wave,
			total,
			gameState:GetAttribute("EnemiesLeft") or 0
		)
	elseif phase == "Break" then
		local doorEnd = gameState:GetAttribute("DoorEnd") or 0
		if Config.Waves.UseDoors and doorEnd > 0 then
			waveLabel.Text = string.format(
				"%s  ·  ¡Andá a la puerta! (%d/%d)  ·  %d s",
				chapterTag,
				gameState:GetAttribute("DoorInside") or 0,
				gameState:GetAttribute("DoorNeeded") or 0,
				math.max(0, math.ceil(doorEnd - workspace:GetServerTimeNow()))
			)
		else
			waveLabel.Text = string.format("%s  ·  Descanso  ·  Próxima: oleada %d", chapterTag, wave + 1)
		end
	elseif phase == "Victory" then
		waveLabel.Text = "¡Victoria!"
	elseif phase == "Defeat" then
		waveLabel.Text = "Derrota"
	else
		waveLabel.Text = "Esperando jugadores..."
	end
end

local function refreshXP()
	local level = gameState:GetAttribute("Level") or 1
	local xp = gameState:GetAttribute("XP") or 0
	local needed = gameState:GetAttribute("XPNeeded") or 1
	xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
	xpText.Text = string.format("Nivel %d  ·  %d / %d XP", level, xp, needed)
end

local announceToken = 0
local function announce(message: string)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = message
	announceLabel.TextTransparency = 0
	announceLabel.TextStrokeTransparency = 0.4
	task.delay(1.6, function()
		if token == announceToken then
			TweenService:Create(announceLabel, TweenInfo.new(0.6), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
end

gameState:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = gameState:GetAttribute("Phase")
	if phase == "Wave" then
		-- Esperamos un instante: el nombre del jefe se publica en el mismo frame, después de la fase.
		task.delay(0.15, function()
			local bossName = gameState:GetAttribute("BossName")
			local wave = gameState:GetAttribute("Wave") or 1
			if bossName and bossName ~= "" then
				announce("¡Jefe: " .. bossName .. "!")
			elseif wave == 1 then
				announce(string.format("Capítulo %d: %s", gameState:GetAttribute("Chapter") or 1, gameState:GetAttribute("ChapterName") or ""))
			else
				announce("Oleada " .. tostring(wave))
			end
		end)
	elseif phase == "Break" then
		announce(if Config.Waves.UseDoors then "¡Oleada superada! Andá a la puerta" else "¡Oleada superada!")
	end
	refreshWave()
end)
for _, attr in { "Wave", "TotalWaves", "EnemiesLeft", "Chapter", "ChapterName", "PartySize", "DoorInside", "DoorNeeded", "DoorEnd" } do
	gameState:GetAttributeChangedSignal(attr):Connect(refreshWave)
end
for _, attr in { "Level", "XP", "XPNeeded" } do
	gameState:GetAttributeChangedSignal(attr):Connect(refreshXP)
end
refreshWave()
-- El contador de la puerta baja cada segundo
task.spawn(function()
	while true do
		task.wait(1)
		if gameState:GetAttribute("Phase") == "Break" and (gameState:GetAttribute("DoorEnd") or 0) > 0 then
			refreshWave()
		end
	end
end)
refreshXP()

---------------------------------------------------------------------
-- Barra del jefe (debajo de la de XP)
---------------------------------------------------------------------
local BOSS_COLOR = Color3.fromRGB(220, 50, 70)
local ENRAGED_COLOR = Color3.fromRGB(255, 140, 30)

local bossFrame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 66),
	Size = UDim2.new(0.6, 0, 0, 46),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
}, { make("UISizeConstraint", { MaxSize = Vector2.new(520, 46) }) })

local bossName = text({ Size = UDim2.new(1, 0, 0, 20), TextSize = 17, Parent = bossFrame })

local bossBack = make("Frame", {
	Position = UDim2.new(0, 0, 0, 24),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundColor3 = Color3.fromRGB(25, 25, 35),
	BorderSizePixel = 0,
	Parent = bossFrame,
}, { corner(6) })

local bossFill = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BOSS_COLOR,
	BorderSizePixel = 0,
	Parent = bossBack,
}, { corner(6) })

local function refreshBoss()
	local maxHealth = gameState:GetAttribute("BossMaxHealth") or 0
	if maxHealth <= 0 then
		bossFrame.Visible = false
		return
	end
	local health = gameState:GetAttribute("BossHealth") or 0
	local enraged = gameState:GetAttribute("BossEnraged") == true
	bossFrame.Visible = true
	bossName.Text = (gameState:GetAttribute("BossName") or "") .. (if enraged then "  ·  ¡FURIA!" else "")
	bossName.TextColor3 = if enraged then ENRAGED_COLOR else Color3.new(1, 1, 1)
	bossFill.BackgroundColor3 = if enraged then ENRAGED_COLOR else BOSS_COLOR
	bossFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
end

for _, attr in { "BossName", "BossHealth", "BossMaxHealth", "BossEnraged" } do
	gameState:GetAttributeChangedSignal(attr):Connect(refreshBoss)
end
refreshBoss()

---------------------------------------------------------------------
-- Estado de vida: derribado, eliminado o espectador (+ compañeros caídos)
-- Lo publica el servidor como atributos del Player: LifeState, DownedLeft,
-- ReviveProgress y RevivedBy.
---------------------------------------------------------------------
local deadLabel = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.new(0.9, 0, 0, 56),
	TextSize = 22,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Visible = false,
	Parent = gui,
})

-- Barras del derribado: tiempo que queda (rojo) y progreso del rescate (verde)
local downedBars = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.new(0.5, 0, 0, 20),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
}, { make("UISizeConstraint", { MaxSize = Vector2.new(360, 20) }) })

local function smallBar(y: number, color: Color3): Frame
	local back = make("Frame", {
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BorderSizePixel = 0,
		Parent = downedBars,
	}, { corner(4) })
	return make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	}, { corner(4) })
end
local downedTimerFill = smallBar(0, Color3.fromRGB(255, 90, 90))
local downedReviveFill = smallBar(11, Color3.fromRGB(90, 220, 120))

-- Lista de compañeros caídos (a la izquierda), por si están fuera de cámara
local allyList = text({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.45, 0),
	Size = UDim2.new(0, 280, 0, 120),
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(255, 140, 140),
	Text = "",
	Parent = gui,
})

local function refreshLife()
	local life = player:GetAttribute("LifeState")
	local phase = gameState:GetAttribute("Phase")
	local inRun = phase == "Wave" or phase == "Break"
	downedBars.Visible = false
	if life == "DOWNED" then
		local left = player:GetAttribute("DownedLeft") or 0
		local by = player:GetAttribute("RevivedBy") or ""
		if by ~= "" then
			deadLabel.Text = string.format("¡%s te está reviviendo!", by)
		else
			deadLabel.Text = string.format("¡Caíste! Un compañero puede revivirte  ·  %d s", math.ceil(left))
		end
		downedTimerFill.Size = UDim2.fromScale(math.clamp(left / Config.Coop.DownedTime, 0, 1), 1)
		downedReviveFill.Size = UDim2.fromScale(math.clamp(player:GetAttribute("ReviveProgress") or 0, 0, 1), 1)
		downedBars.Visible = true
		deadLabel.Visible = true
	elseif life == "ELIMINATED" and inRun then
		deadLabel.Text = "Eliminado. Volvés en el próximo descanso entre oleadas."
		deadLabel.Visible = true
	else
		deadLabel.Visible = false
	end
end

local function refreshAllies()
	local lines = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("LifeState") == "DOWNED" then
			local by = other:GetAttribute("RevivedBy") or ""
			if by ~= "" then
				table.insert(lines, string.format("%s: lo están reviviendo", other.DisplayName))
			else
				table.insert(lines, string.format("%s caído  ·  %d s", other.DisplayName, math.ceil(other:GetAttribute("DownedLeft") or 0)))
			end
		end
	end
	allyList.Text = if #lines > 0 then "¡Compañeros caídos!\n" .. table.concat(lines, "\n") else ""
end

local LIFE_ATTRS = { "LifeState", "DownedLeft", "ReviveProgress", "RevivedBy" }
local function watchPlayer(p: Player)
	for _, attr in LIFE_ATTRS do
		p:GetAttributeChangedSignal(attr):Connect(function()
			if p == player then
				refreshLife()
			else
				refreshAllies()
			end
		end)
	end
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshAllies)
end)
gameState:GetAttributeChangedSignal("Phase"):Connect(refreshLife)
refreshLife()
refreshAllies()

-- Botón de revivir: no mostrar el propio, ni ninguno si no estás en pie.
-- (Es solo visual: el servidor igual rechaza esos intentos.)
local hiddenPrompts: { [ProximityPrompt]: boolean } = {}
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Name ~= "RevivePrompt" then
		return
	end
	local own = player.Character ~= nil and prompt:IsDescendantOf(player.Character)
	if own or player:GetAttribute("LifeState") ~= "ALIVE" then
		prompt.Enabled = false
		hiddenPrompts[prompt] = true
	end
end)
player:GetAttributeChangedSignal("LifeState"):Connect(function()
	if player:GetAttribute("LifeState") == "ALIVE" then
		for prompt in hiddenPrompts do
			if prompt.Parent and not (player.Character and prompt:IsDescendantOf(player.Character)) then
				prompt.Enabled = true
			end
		end
		table.clear(hiddenPrompts)
	end
end)

-- Sin botón de "Reiniciar personaje": la muerte la maneja el juego (derribo y rescate).
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
			break
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- Habilidades obtenidas
---------------------------------------------------------------------
local owned: { [string]: number } = {}

local function refreshOwned()
	ownedLabel.RichText = true
	local lines = {}
	for _, def in Skills.List do
		local n = owned[def.Id]
		if n then
			table.insert(lines, string.format('<font color="#%s">%s ×%d</font>', Rarities.Colors[def.Rarity]:ToHex(), def.Name, n))
		end
	end
	ownedLabel.Text = table.concat(lines, "\n")
end

skillGranted.OnClientEvent:Connect(function(skillId: string, stacks: number)
	owned[skillId] = stacks
	refreshOwned()
end)

---------------------------------------------------------------------
-- Menú "elegí 1 de 3"
---------------------------------------------------------------------
local overlay = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
})
-- En primera persona Roblox traba el mouse en el centro. Un botón con Modal = true lo
-- libera mientras el menú está visible, para poder hacer clic en las cartas.
local pickerMouse = make("TextButton", { Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1, Text = "", Modal = false, Parent = overlay })

text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.18),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "PARTIDA EN PAUSA · Elegí un poder",
	TextSize = 22,
	ZIndex = 11,
	Parent = overlay,
})

local timerLabel = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.18, 44),
	Size = UDim2.new(1, 0, 0, 24),
	TextSize = 15,
	Font = Enum.Font.Gotham,
	ZIndex = 11,
	Parent = overlay,
})

local cardsRow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(0.92, 0.45),
	BackgroundTransparency = 1,
	ZIndex = 11,
	Parent = overlay,
}, {
	make("UISizeConstraint", { MaxSize = Vector2.new(900, 320) }),
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.03, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

type Card = {
	button: TextButton,
	stroke: UIStroke,
	name: TextLabel,
	rarity: TextLabel,
	desc: TextLabel,
	stacks: TextLabel,
	scale: UIScale,
	glow: number, -- cuánto late el borde según la rareza
	spinUntil: number, -- hasta cuándo "gira" como tragamonedas
}
local cards: { Card } = {}
local GLOW = { Common = 0.6, Rare = 1.6, Epic = 3 }

local currentOfferId: number? = nil
local currentChoices: { string } = {}
local deadline = 0

local function closePicker()
	currentOfferId = nil
	pickerMouse.Modal = false
	overlay.Visible = false
end

local function choose(index: number)
	if not currentOfferId or not currentChoices[index] then
		return
	end
	local card = cards[index]
	if card and os.clock() < card.spinUntil then
		return -- todavía está girando
	end
	chooseSkill:FireServer(currentOfferId, index)
	closePicker()
end

for i = 1, 3 do
	local button = make("TextButton", {
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Color3.fromRGB(30, 30, 42),
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = i,
		ZIndex = 12,
		Parent = cardsRow,
	}, { corner(12), make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}) })
	local stroke = make("UIStroke", {
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})

	local name = text({ Size = UDim2.new(1, 0, 0, 28), TextSize = 22, TextWrapped = true, ZIndex = 13, Parent = button })
	local rarity = text({
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		Font = Enum.Font.Gotham,
		ZIndex = 13,
		Parent = button,
	})
	local desc = text({
		Position = UDim2.new(0, 0, 0, 60),
		Size = UDim2.new(1, 0, 1, -100),
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		ZIndex = 13,
		Parent = button,
	})
	local stacks = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 190, 200),
		ZIndex = 13,
		Parent = button,
	})

	local scale = make("UIScale", { Parent = button })

	button.Activated:Connect(function()
		choose(i)
	end)
	cards[i] = {
		button = button,
		stroke = stroke,
		name = name,
		rarity = rarity,
		desc = desc,
		stacks = stacks,
		scale = scale,
		glow = 0,
		spinUntil = 0,
	}
end

skillOffer.OnClientEvent:Connect(function(offerId: number, choices: { string }, timeout: number)
	currentOfferId = offerId
	currentChoices = choices
	deadline = os.clock() + timeout

	for i, card in cards do
		local def = Skills.ById[choices[i]]
		card.button.Visible = def ~= nil
		if def then
			local color = Skills.RarityColors[def.Rarity]
			card.stroke.Color = color
			card.name.Text = def.Name
			card.rarity.Text = Skills.RarityNames[def.Rarity]
			RarityVisuals.bind(card.rarity, def.Rarity)
			card.desc.Text = def.Description
			if def.Max == math.huge then
				card.stacks.Text = string.format("[%d]", i)
			else
				card.stacks.Text = string.format("[%d]   %d / %d", i, owned[def.Id] or 0, def.Max)
			end
			card.glow = GLOW[def.Rarity] or 0.6
			-- Entrada: aparecen de a una y "giran" como tragamonedas antes de mostrar la habilidad
			card.scale.Scale = 0
			card.button.Rotation = -8
			card.spinUntil = os.clock() + 0.3 + i * 0.15
			task.delay((i - 1) * 0.1, function()
				TweenService:Create(card.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				TweenService:Create(card.button, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
			end)
		end
	end
	pickerMouse.Modal = true
	overlay.Visible = true
end)

-- Atajos de teclado 1, 2, 3
local keyToIndex = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not overlay.Visible then
		return
	end
	local index = keyToIndex[input.KeyCode]
	if index then
		choose(index)
	end
end)

local waitingForTeam = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.new(0.8, 0, 0, 70), Text = "Partida en pausa · Esperando que el equipo termine de elegir", TextSize = 24, TextWrapped = true, Visible = false, ZIndex = 11, Parent = gui })
RunService.Heartbeat:Connect(function()
	waitingForTeam.Visible = gameState:GetAttribute("ChoosingPaused") == true and not overlay.Visible
end)

-- Cuenta regresiva; si se acaba, el servidor elige al azar y cerramos el menú.
RunService.Heartbeat:Connect(function()
	if not overlay.Visible then
		return
	end
	local now = os.clock()
	-- Tragamonedas: mientras gira, nombres al azar; después, la habilidad de verdad
	for i, card in cards do
		local def = Skills.ById[currentChoices[i]]
		if def and card.button.Visible then
			if now < card.spinUntil then
				local random = Skills.List[math.random(1, #Skills.List)]
				card.name.Text = random.Name
				card.name.TextColor3 = Skills.RarityColors[random.Rarity]
			elseif card.name.Text ~= def.Name or card.name.TextColor3 ~= Color3.new(1, 1, 1) then
				card.name.Text = def.Name
				card.name.TextColor3 = Color3.new(1, 1, 1)
			end
			-- El borde late más cuanto más rara es
			card.stroke.Thickness = 2 + card.glow * (0.5 + math.sin(now * 6 + i) * 0.5)
			card.stroke.Color = Rarities.color(def.Rarity, now)
		end
	end
	local left = deadline - now
	if left <= 0 then
		closePicker()
	else
		timerLabel.Text = string.format("Se elige sola en %d s", math.ceil(left))
	end
end)

---------------------------------------------------------------------
-- Pantalla de resultados (victoria o derrota)
---------------------------------------------------------------------
local results = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
})
make("TextButton", { Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1, Text = "", Modal = true, Parent = results })

local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 490),
	BackgroundColor3 = Theme.Colors.Panel,
	ZIndex = 21,
	Parent = results,
}, {
	corner(14),
	make("UISizeConstraint", { MaxSize = Vector2.new(520, 490) }),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 18),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	}),
})

Theme.stroke(Theme.Colors.Gold, 2).Parent = panel
local resultTitle = text({ Size = UDim2.new(1, 0, 0, 44), TextSize = 42, Font = Theme.Fonts.Title, ZIndex = 22, Parent = panel })
local resultSub = text({
	Position = UDim2.new(0, 0, 0, 50),
	Size = UDim2.new(1, 0, 0, 44),
	TextSize = 15,
	TextWrapped = true,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(200, 200, 210),
	ZIndex = 22,
	Parent = panel,
})

-- Tabla de jugadores: nombre · bajas · daño
local tableFrame = make("Frame", {
	Position = UDim2.new(0, 0, 0, 104),
	Size = UDim2.new(1, 0, 1, -258),
	BackgroundTransparency = 1,
	ZIndex = 22,
	Parent = panel,
}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function tableRow(order: number, name: string, kills: string, revives: string, damage: string, header: boolean)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = if header then 1 else 0.5,
		BackgroundColor3 = Color3.fromRGB(45, 45, 62),
		LayoutOrder = order,
		ZIndex = 22,
		Parent = tableFrame,
	}, { corner(6) })
	local color = if header then Color3.fromRGB(170, 170, 185) else Color3.new(1, 1, 1)
	local font = if header then Enum.Font.Gotham else Enum.Font.GothamBold
	text({
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0.45, -10, 1, 0),
		Text = name,
		TextSize = 16,
		TextColor3 = color,
		Font = font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 23,
		Parent = row,
	})
	text({
		Position = UDim2.fromScale(0.45, 0),
		Size = UDim2.fromScale(0.15, 1),
		Text = kills,
		TextSize = 16,
		TextColor3 = color,
		Font = font,
		ZIndex = 23,
		Parent = row,
	})
	text({
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.fromScale(0.15, 1),
		Text = revives,
		TextSize = 16,
		TextColor3 = color,
		Font = font,
		ZIndex = 23,
		Parent = row,
	})
	text({
		Position = UDim2.fromScale(0.75, 0),
		Size = UDim2.new(0.25, -10, 1, 0),
		Text = damage,
		TextSize = 16,
		TextColor3 = color,
		Font = font,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 23,
		Parent = row,
	})
end

-- Recompensas de esta partida (las calcula y entrega el servidor)
local rewardsTitle = text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -128),
	Size = UDim2.new(1, 0, 0, 20),
	Text = "RECOMPENSAS",
	TextSize = 14,
	Font = Theme.Fonts.Heading,
	TextColor3 = Theme.Colors.Gold,
	ZIndex = 22,
	Parent = panel,
})
local rewardsRow = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -86),
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundTransparency = 1,
	ZIndex = 22,
	Parent = panel,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local function showRewards(rewards: { [string]: number }?, firstClear: boolean, loot: { [string]: number }?)
	for _, child in rewardsRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local any = false
	for i, c in Currencies do
		local n = rewards and rewards[c.Id] or 0
		if n > 0 then
			any = true
			local chip = make("Frame", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(45, 40, 58),
				LayoutOrder = i,
				ZIndex = 22,
				Parent = rewardsRow,
			}, { corner(19), make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
			Theme.stroke(c.Color, 1.5, 0.3).Parent = chip
			text({
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = string.format("%s +%d", c.Icon, n),
				TextSize = 19,
				Font = Theme.Fonts.Bold,
				TextColor3 = c.Color,
				ZIndex = 23,
				Parent = chip,
			})
		end
	end
	if not any then
		text({
			Size = UDim2.new(1, 0, 1, 0),
			Text = if rewards then "Sin recompensas esta vez" else "Tu perfil no estaba cargado: sin recompensas",
			TextSize = 15,
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(170, 170, 185),
			ZIndex = 23,
			Parent = rewardsRow,
		})
	end
	local title = if firstClear then "RECOMPENSAS  ·  ¡PRIMERA VICTORIA!" else "RECOMPENSAS"
	-- Botín juntado matando enemigos (ya cobrado durante la partida)
	local lootParts = {}
	for _, c in Currencies do
		local n = loot and loot[c.Id] or 0
		if n > 0 then
			table.insert(lootParts, c.Icon .. " " .. n)
		end
	end
	if #lootParts > 0 then
		title ..= "   ·   Botín: " .. table.concat(lootParts, "  ")
	end
	rewardsTitle.Text = title
end

local againButton = Theme.button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 260, 0, 48),
	Text = "Volver al lobby",
	TextSize = 20,
	ZIndex = 22,
	Parent = panel,
})

local restartLabel = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 14,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(170, 170, 185),
	ZIndex = 22,
	Parent = panel,
})

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

runEnded.OnClientEvent:Connect(function(summary)
	closePicker()
	deadLabel.Visible = false
	local victory = summary.result == "Victory"
	resultTitle.Text = if victory then "¡Victoria!" else "Derrota"
	resultTitle.TextColor3 = if victory then Color3.fromRGB(255, 215, 90) else Color3.fromRGB(255, 100, 100)
	resultSub.Text = string.format(
		"Capítulo %d · %s  ·  Oleada %d/%d  ·  Nivel %d  ·  Tiempo %s\n%s",
		summary.chapter,
		summary.chapterName,
		summary.wave,
		summary.totalWaves,
		summary.level,
		formatTime(summary.time),
		summary.nextText
	)

	for _, child in tableFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	tableRow(0, "Jugador", "Bajas", "Rescates", "Daño", true)
	for i, p in summary.players do
		tableRow(i, p.name, tostring(p.kills), tostring(p.revives or 0), tostring(p.damage), false)
	end

	showRewards(summary.rewards, summary.firstClear == true, summary.loot)

	againButton.Text = "Volver al lobby"
	results.Visible = true
	Theme.popIn(panel)
end)

againButton.Activated:Connect(function()
	-- Cuando todos los del equipo lo tocan, vuelven antes; si no, al terminar el tiempo
	lobbyRequest:FireServer("ReturnToLobby")
	againButton.Text = "Esperando al equipo…"
end)

RunService.Heartbeat:Connect(function()
	if results.Visible then
		local resultsEnd = gameState:GetAttribute("ResultsEnd") or 0
		local left = math.max(0, math.ceil(resultsEnd - workspace:GetServerTimeNow()))
		restartLabel.Text = string.format("Volvés al lobby en %d s", left)
	end
end)

runReset.OnClientEvent:Connect(function()
	table.clear(owned)
	refreshOwned()
	closePicker()
	results.Visible = false
	deadLabel.Visible = false
end)
