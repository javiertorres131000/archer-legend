-- Juice (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Juice
-- "Jugo": todo lo que hace que cada golpe se sienta. Solo visual, calculado en el cliente.
--   · Destello blanco del enemigo al recibir un golpe tuyo
--   · Explosión de partículas del color del enemigo al morir (enorme si es dorado)
--   · Sacudón de cámara en tus críticos, al recibir daño y con los dorados
--   · Contador de combo (muertes del equipo seguidas) con anuncios: ¡EN RACHA!, ¡MASACRE!...
--     Todo en arcoíris que corre de costado (número, barra y carteles), más rápido cuanto más
--     larga la racha.
--     Publica el combo en el atributo local "Combo" (Sfx toca una nota más aguda por muerte)
--     y la mejor racha de la partida en "BestCombo" (se muestra en los resultados).
--   · Pausa de impacto en tus críticos, dorados y jefes: el arma se congela un instante
--     (atributo local "HitStopUntil", lo lee WeaponFx), la cámara se acerca y la pantalla destella.
--   · Destello dorado y "¡NIVEL N!" al subir de nivel
--   · Cartel "¡SINERGIA!" en arcoíris cuando completás un par de habilidades (atributo local
--     "Synergy" que publica el Hud; los pares están en Shared/Synergies.lua)
-- Usa los eventos de Remotes.CombatText (los mismos que los números flotantes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local Theme = require(Shared:WaitForChild("UITheme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatText = remotes:WaitForChild("CombatText") :: RemoteEvent
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer
local low = FxQuality.isLow()

---------------------------------------------------------------------
-- Destello blanco
---------------------------------------------------------------------
local flashing: { [BasePart]: { color: Color3, untilT: number } } = {}
local FLASH_TIME = 0.07
local WHITE = Color3.new(1, 1, 1)

local function flash(part: Instance?)
	if not part or not part:IsA("BasePart") or not part.Parent then
		return
	end
	local entry = flashing[part]
	if entry then
		entry.untilT = os.clock() + FLASH_TIME
	else
		flashing[part] = { color = part.Color, untilT = os.clock() + FLASH_TIME }
		part.Color = WHITE
	end
end

---------------------------------------------------------------------
-- Explosiones al morir
---------------------------------------------------------------------
type Burst = { attachment: Attachment, emitter: ParticleEmitter, sparks: ParticleEmitter }
local bursts: { Burst } = {}
for i = 1, 8 do
	local attachment = Instance.new("Attachment")
	attachment.Name = "DeathBurst"
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Speed = NumberRange.new(14, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Drag = 5
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = attachment
	-- Chispas blancas que salen más rápido (brillo)
	local sparks = emitter:Clone()
	sparks.Speed = NumberRange.new(30, 50)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Color = ColorSequence.new(WHITE)
	sparks.Parent = attachment
	bursts[i] = { attachment = attachment, emitter = emitter, sparks = sparks }
end
local nextBurst = 1

-- Onda expansiva (esfera neón que crece y se desvanece)
local waveFolder = Instance.new("Folder")
waveFolder.Name = "DeathWaves"
waveFolder.Parent = workspace

local function shockwave(pos: Vector3, color: Color3, size: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Transparency = 0.25
	ball.Size = Vector3.one * size * 0.5
	ball.Position = pos
	ball.Parent = waveFolder
	local tween = TweenService:Create(ball, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size * 2.6,
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		ball:Destroy()
	end)
	tween:Play()
end

local function explode(pos: Vector3, color: Color3, size: number, golden: boolean)
	local b = bursts[nextBurst]
	nextBurst = nextBurst % #bursts + 1
	b.attachment.WorldPosition = pos + Vector3.new(0, size * 0.4, 0)
	local c = if golden then Color3.fromRGB(255, 210, 60) else color
	b.emitter.Color = ColorSequence.new(c, c:Lerp(WHITE, 0.5))
	local count = math.floor((if low then 10 else 22) * math.clamp(size / 3, 0.7, 3) * (if golden then 4 else 1))
	b.emitter:Emit(count)
	if not low then
		b.sparks:Emit(math.floor(count / 2))
		shockwave(pos + Vector3.new(0, size * 0.4, 0), c, size * (if golden then 3 else 1))
	end
end

---------------------------------------------------------------------
-- Sacudón de cámara (Humanoid.CameraOffset, funciona en primera persona)
---------------------------------------------------------------------
local shake = 0
local function addShake(amount: number)
	shake = math.max(shake, amount * Config.Effects.ScreenShake)
end

---------------------------------------------------------------------
-- Pausa de impacto (hit-stop)
---------------------------------------------------------------------
local lastHitStop = -math.huge
local fovBase: number? = nil -- FOV antes del acercamiento (para volver exacto)
local fovTween: Tween? = nil
local impactFlash: Frame? = nil -- se crea con la pantalla (más abajo)

-- strength: 1 = crítico, 2 = dorado, 3 = jefe
local function hitStop(strength: number)
	local cfg = Config.Effects
	local now = os.clock()
	if (cfg.HitStop or 0) <= 0 or now - lastHitStop < (cfg.HitStopGap or 0) then
		return
	end
	lastHitStop = now
	local duration = cfg.HitStop * strength
	player:SetAttribute("HitStopUntil", now + duration)
	addShake(0.1 + 0.12 * strength)
	-- Acercamiento de cámara y vuelta
	local camera = workspace.CurrentCamera
	local fov = (cfg.HitStopFov or 0) * (0.7 + 0.3 * strength)
	if camera and fov > 0 then
		if fovTween then
			fovTween:Cancel()
		end
		fovBase = fovBase or camera.FieldOfView
		local base = fovBase :: number
		camera.FieldOfView = base - fov
		local tween = TweenService:Create(camera, TweenInfo.new(duration + 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		fovTween = tween
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and fovTween == tween then
				fovBase = nil
				fovTween = nil
			end
		end)
		tween:Play()
	end
	-- Destello blanco cortito
	local flashFrame = impactFlash
	if flashFrame then
		flashFrame.BackgroundTransparency = 0.88 - 0.06 * strength
		TweenService:Create(flashFrame, TweenInfo.new(duration + 0.08), { BackgroundTransparency = 1 }):Play()
	end
end

-- Si cambia la vista (V) en medio del acercamiento, se corta: CameraController pone el FOV nuevo
player:GetAttributeChangedSignal("CameraView"):Connect(function()
	if fovTween then
		fovTween:Cancel()
		fovTween = nil
	end
	fovBase = nil
end)

---------------------------------------------------------------------
-- Pantalla: combo y nivel
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Juice"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local function refreshEnabled()
	gui.Enabled = player:GetAttribute("InMatch") == true
end
player:GetAttributeChangedSignal("InMatch"):Connect(refreshEnabled)
refreshEnabled()

local comboFrame = Instance.new("Frame")
comboFrame.AnchorPoint = Vector2.new(1, 0.5)
comboFrame.Position = UDim2.new(1, -24, 0.42, 0)
comboFrame.Size = UDim2.fromOffset(200, 90)
comboFrame.BackgroundTransparency = 1
comboFrame.Visible = false
comboFrame.Parent = gui
local comboScale = Instance.new("UIScale")
comboScale.Parent = comboFrame
local comboNumber = Instance.new("TextLabel")
comboNumber.Size = UDim2.new(1, 0, 0, 60)
comboNumber.BackgroundTransparency = 1
comboNumber.Font = Enum.Font.GothamBlack
comboNumber.TextSize = 56
comboNumber.TextXAlignment = Enum.TextXAlignment.Right
comboNumber.TextStrokeTransparency = 0
comboNumber.Parent = comboFrame
local comboLabel = Instance.new("TextLabel")
comboLabel.Position = UDim2.new(0, 0, 0, 56)
comboLabel.Size = UDim2.new(1, 0, 0, 20)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextSize = 18
comboLabel.Text = "COMBO"
comboLabel.TextColor3 = Color3.new(1, 1, 1)
comboLabel.TextXAlignment = Enum.TextXAlignment.Right
comboLabel.TextStrokeTransparency = 0.3
comboLabel.Parent = comboFrame
local comboBarBack = Instance.new("Frame")
comboBarBack.AnchorPoint = Vector2.new(1, 0)
comboBarBack.Position = UDim2.new(1, 0, 0, 80)
comboBarBack.Size = UDim2.fromOffset(120, 5)
comboBarBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
comboBarBack.BorderSizePixel = 0
comboBarBack.Parent = comboFrame
local comboBar = Instance.new("Frame")
comboBar.Size = UDim2.fromScale(1, 1)
comboBar.BorderSizePixel = 0
comboBar.Parent = comboBarBack

local announce = Instance.new("TextLabel")
announce.AnchorPoint = Vector2.new(0.5, 0.5)
announce.Position = UDim2.fromScale(0.5, 0.28)
announce.Size = UDim2.fromOffset(700, 80)
announce.BackgroundTransparency = 1
announce.Font = Enum.Font.GothamBlack
announce.TextSize = 54
announce.TextStrokeTransparency = 0
announce.TextTransparency = 1
announce.TextStrokeColor3 = Color3.new(0, 0, 0)
announce.Parent = gui
local announceScale = Instance.new("UIScale")
announceScale.Parent = announce
-- Segunda línea opcional del cartel (sinergias: "Perforación + Rebote")
local announceSub = Instance.new("TextLabel")
announceSub.AnchorPoint = Vector2.new(0.5, 0)
announceSub.Position = UDim2.new(0.5, 0, 0.28, 40)
announceSub.Size = UDim2.fromOffset(700, 32)
announceSub.BackgroundTransparency = 1
announceSub.Font = Enum.Font.GothamBold
announceSub.TextSize = 24
announceSub.TextColor3 = Color3.new(1, 1, 1)
announceSub.TextStrokeTransparency = 0
announceSub.TextTransparency = 1
announceSub.Parent = gui

-- Arcoíris de la racha: un degradado que recorre los colores y se desplaza cada frame
local RAINBOW_KEYS = 8
local function rainbowSequence(phase: number): ColorSequence
	local keys = table.create(RAINBOW_KEYS)
	for i = 0, RAINBOW_KEYS - 1 do
		local t = i / (RAINBOW_KEYS - 1)
		keys[i + 1] = ColorSequenceKeypoint.new(t, Color3.fromHSV((phase + t * 0.8) % 1, 0.7, 1))
	end
	return ColorSequence.new(keys)
end
local function rainbowGradient(target: GuiObject): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Rainbow"
	gradient.Color = rainbowSequence(0)
	gradient.Parent = target
	return gradient
end
-- El texto queda blanco para que el degradado muestre sus colores tal cual
comboNumber.TextColor3 = WHITE
comboBar.BackgroundColor3 = WHITE
local comboGradients = { rainbowGradient(comboNumber), rainbowGradient(comboLabel), rainbowGradient(comboBar) }
local announceRainbow = rainbowGradient(announce)
announceRainbow.Enabled = false
local rainbowPhase = 0

local function shout(message: string, color: Color3, rainbow: boolean?, sub: string?)
	announceSub.Text = sub or ""
	announceSub.TextTransparency = if sub then 0 else 1
	announceSub.TextStrokeTransparency = if sub then 0 else 1
	announce.Text = message
	announceRainbow.Enabled = rainbow == true
	announce.TextColor3 = if rainbow then WHITE else color
	announce.TextTransparency = 0
	announce.TextStrokeTransparency = 0
	announceScale.Scale = 1.6
	TweenService:Create(announceScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(if sub then 1.8 else 0.9, function()
		if announce.Text == message then
			local info = TweenInfo.new(0.5)
			TweenService:Create(announce, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(announceSub, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local MILESTONES = {
	[10] = "¡EN RACHA!",
	[25] = "¡BUENA RACHA!",
	[50] = "¡MASACRE!",
	[100] = "¡IMPARABLE!",
	[200] = "¡LEYENDA!",
	[400] = "¡DIVINO!",
}
local combo = 0
local lastKill = 0
local bestCombo = 0

-- El combo y la mejor racha quedan en atributos locales (Sfx y los resultados los leen)
local function publishCombo()
	player:SetAttribute("Combo", combo)
	if combo > bestCombo then
		bestCombo = combo
		player:SetAttribute("BestCombo", bestCombo)
	end
end

local function addKill()
	local now = os.clock()
	if now - lastKill > Config.Frenzy.ComboWindow then
		combo = 0
	end
	lastKill = now
	combo += 1
	publishCombo()
	if combo >= 3 then
		comboFrame.Visible = true
		comboNumber.Text = "x" .. combo
		comboScale.Scale = 1.25
		TweenService:Create(comboScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local milestone = MILESTONES[combo]
	if milestone then
		shout(milestone .. "  x" .. combo, WHITE, true)
		addShake(0.3)
	end
end

-- Destello blanco de la pausa de impacto
local impact = Instance.new("Frame")
impact.Size = UDim2.fromScale(1, 1)
impact.BackgroundColor3 = WHITE
impact.BackgroundTransparency = 1
impact.BorderSizePixel = 0
impact.Parent = gui
impactFlash = impact

-- Destello de pantalla completa (subir de nivel)
local screenFlash = Instance.new("Frame")
screenFlash.Size = UDim2.fromScale(1, 1)
screenFlash.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
screenFlash.BackgroundTransparency = 1
screenFlash.BorderSizePixel = 0
screenFlash.Parent = gui

local lastLevel = gameState:GetAttribute("Level") or 1
gameState:GetAttributeChangedSignal("Level"):Connect(function()
	local level = gameState:GetAttribute("Level") or 1
	if level > lastLevel and player:GetAttribute("InMatch") == true then
		screenFlash.BackgroundTransparency = 0.45
		TweenService:Create(screenFlash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		shout("¡NIVEL " .. level .. "!", Theme.Colors.GoldBright)
	end
	lastLevel = level
end)

-- Sinergia (la publica el Hud): "contador|nombre|habilidad A + habilidad B"
player:GetAttributeChangedSignal("Synergy"):Connect(function()
	local value = player:GetAttribute("Synergy")
	if typeof(value) ~= "string" or player:GetAttribute("InMatch") ~= true then
		return
	end
	local _, name, pair = string.match(value, "^(%d+)|([^|]*)|(.*)$")
	if name then
		shout("¡SINERGIA!  " .. name, WHITE, true, pair)
		addShake(0.2)
	end
end)

---------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------
combatText.OnClientEvent:Connect(function(events)
	if typeof(events) ~= "table" then
		return
	end
	for _, e in events do
		local kind = e.k
		if kind == "hit" or kind == "crit" or kind == "burn" then
			flash(e.i)
			if kind == "crit" then
				addShake(0.12)
				hitStop(1)
			end
		elseif kind == "kill" and typeof(e.p) == "Vector3" then
			local color = if typeof(e.c) == "Color3" then e.c else WHITE
			local size = if typeof(e.s) == "number" then e.s else 3
			explode(e.p, color, size, e.x == true)
			addKill()
			if e.b == true then
				lastHitStop = -math.huge -- un jefe siempre pausa, aunque recién haya habido otra
				hitStop(3)
			elseif e.x == true then
				lastHitStop = -math.huge
				hitStop(2)
			end
			if e.x == true then
				addShake(0.35)
				shout("¡DORADO!", Color3.fromRGB(255, 210, 60))
			end
		elseif kind == "hurt" then
			addShake(0.25)
		end
	end
end)

-- Al entrar o volver al lobby: combo en cero. La mejor racha se borra al empezar otra partida
-- (en los resultados todavía se muestra la de la partida que terminó).
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	combo = 0
	comboFrame.Visible = false
	publishCombo()
	if player:GetAttribute("InMatch") == true then
		bestCombo = 0
		player:SetAttribute("BestCombo", 0)
	end
end)

---------------------------------------------------------------------
-- Cada frame
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()

	-- Fin de los destellos
	for part, entry in flashing do
		if now >= entry.untilT or not part.Parent then
			if part.Parent then
				part.Color = entry.color
			end
			flashing[part] = nil
		end
	end

	-- Arcoíris de la racha: corre más rápido cuanto más larga es
	if comboFrame.Visible or announceRainbow.Enabled then
		rainbowPhase = (rainbowPhase + dt * (0.35 + math.min(combo, 100) / 100 * 1.2)) % 1
		local sequence = rainbowSequence(rainbowPhase)
		for _, gradient in comboGradients do
			gradient.Color = sequence
		end
		announceRainbow.Color = sequence
	end

	-- Combo: barra que se vacía; si llega a 0, se corta
	if comboFrame.Visible then
		local left = 1 - (now - lastKill) / Config.Frenzy.ComboWindow
		if left <= 0 then
			comboFrame.Visible = false
			combo = 0
			publishCombo()
		else
			comboBar.Size = UDim2.fromScale(left, 1)
		end
	end

	-- Sacudón
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if shake > 0.005 then
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * 2 * shake,
				(math.random() - 0.5) * 2 * shake,
				(math.random() - 0.5) * 2 * shake
			)
			shake *= math.exp(-dt * 14)
		elseif humanoid.CameraOffset ~= Vector3.zero then
			humanoid.CameraOffset = Vector3.zero
			shake = 0
		end
	end
end)
