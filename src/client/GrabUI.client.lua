-- GrabUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > GrabUI
-- Agarre (Grab.lua en el servidor):
--   · Si te agarran: pantalla roja, "¡TE AGARRARON!" y la barra de forcejeo. Machacá ESPACIO
--     (A en el joystick, botón ¡SOLTATE! en el celular): cada toque se le avisa al servidor,
--     que los cuenta con límite de frecuencia y decide cuándo te soltás.
--   · Si agarran a un compañero: cartel "¡AYUDA!" rojo sobre su cabeza (se ve a través de todo).
--   · Al rescatar o ser rescatado: "¡NOMBRE te salvó!" / "¡Salvaste a NOMBRE!".
-- Lee los atributos del jugador: Grabbed, GrabProgress, SavedBy, Rescued.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local struggleRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StruggleRequest") :: RemoteEvent
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer
local ACTION = "GrabStruggle"
local RED = Color3.fromRGB(255, 60, 70)

local gui = Instance.new("ScreenGui")
gui.Name = "GrabUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- Pantalla de "te agarraron"
---------------------------------------------------------------------
local overlay = Theme.make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = RED,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	Parent = gui,
})
local title = Theme.make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 52,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(90, 0, 10),
	Text = "¡TE AGARRARON!",
	Parent = overlay,
})
local titleScale = Theme.make("UIScale", { Parent = title })
local hint = Theme.make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.3, 36),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.2,
	Parent = overlay,
})
local barBack = Theme.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.3, 76),
	Size = UDim2.fromOffset(360, 22),
	BackgroundColor3 = Color3.fromRGB(40, 10, 15),
	BorderSizePixel = 0,
	Parent = overlay,
}, { Theme.make("UICorner", { CornerRadius = UDim.new(0, 11) }) })
Theme.stroke(Color3.new(1, 1, 1), 2).Parent = barBack
local barFill = Theme.make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(255, 220, 90),
	BorderSizePixel = 0,
	Parent = barBack,
}, { Theme.make("UICorner", { CornerRadius = UDim.new(0, 11) }) })
local barScale = Theme.make("UIScale", { Parent = barBack })

local function hintText(): string
	local alone = (gameState:GetAttribute("PartySize") or 1) <= 1
	local key = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Tocá ¡SOLTATE! rápido"
		elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then "Machacá A"
		else "Machacá ESPACIO"
	return if alone then key .. " para soltarte" else key .. " o que tu compañero le pegue"
end

local function onStruggle(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin and player:GetAttribute("Grabbed") == true then
		struggleRemote:FireServer()
		barScale.Scale = 1.12
		TweenService:Create(barScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end
	return Enum.ContextActionResult.Sink -- que ESPACIO no salte mientras forcejeás
end

local function refreshGrabbed()
	local grabbed = player:GetAttribute("Grabbed") == true
	overlay.Visible = grabbed
	if grabbed then
		hint.Text = hintText()
		barFill.Size = UDim2.fromScale(0, 1)
		titleScale.Scale = 1.6
		TweenService:Create(titleScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		ContextActionService:BindActionAtPriority(ACTION, onStruggle, true, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		ContextActionService:SetTitle(ACTION, "¡SOLTATE!")
		ContextActionService:SetPosition(ACTION, UDim2.fromScale(0.5, 0.62))
	else
		ContextActionService:UnbindAction(ACTION)
	end
end
player:GetAttributeChangedSignal("Grabbed"):Connect(refreshGrabbed)
player:GetAttributeChangedSignal("GrabProgress"):Connect(function()
	local p = math.clamp(player:GetAttribute("GrabProgress") or 0, 0, 1)
	TweenService:Create(barFill, TweenInfo.new(0.08), { Size = UDim2.fromScale(p, 1) }):Play()
end)
refreshGrabbed()

-- Borde rojo que late mientras te tienen
RunService.RenderStepped:Connect(function()
	if overlay.Visible then
		overlay.BackgroundTransparency = 0.78 + math.sin(os.clock() * 8) * 0.06
	end
end)

---------------------------------------------------------------------
-- "¡AYUDA!" sobre un compañero agarrado
---------------------------------------------------------------------
local helpSigns: { [Player]: BillboardGui } = {}

local function clearHelp(other: Player)
	local sign = helpSigns[other]
	if sign then
		sign:Destroy()
		helpSigns[other] = nil
	end
end

local function refreshHelp(other: Player)
	if other == player then
		return
	end
	local grabbed = other:GetAttribute("Grabbed") == true
	local character = other.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not grabbed or not head then
		clearHelp(other)
		return
	end
	if helpSigns[other] then
		return
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = "GrabHelp"
	sign.Size = UDim2.fromOffset(220, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = RED
	label.TextStrokeTransparency = 0
	label.Text = "¡AYUDA!"
	label.Parent = sign
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.TextStrokeTransparency = 0
	sub.Text = "Pegale al Atrapador"
	sub.Parent = sign
	sign.Parent = gui -- en el PlayerGui: solo lo ve este jugador
	helpSigns[other] = sign
end

local function watch(other: Player)
	if other == player then
		return
	end
	other:GetAttributeChangedSignal("Grabbed"):Connect(function()
		refreshHelp(other)
	end)
	other.CharacterAdded:Connect(function()
		clearHelp(other)
		task.defer(refreshHelp, other)
	end)
	refreshHelp(other)
end
for _, other in Players:GetPlayers() do
	watch(other)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clearHelp)

-- El cartel late para llamar la atención
RunService.RenderStepped:Connect(function()
	local s = 1 + math.abs(math.sin(os.clock() * 6)) * 0.15
	for _, sign in helpSigns do
		sign.Size = UDim2.fromOffset(220 * s, 60 * s)
	end
end)

---------------------------------------------------------------------
-- Avisos de rescate
---------------------------------------------------------------------
local toast = Theme.make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 38,
	TextColor3 = Color3.fromRGB(120, 255, 160),
	TextStrokeTransparency = 0,
	TextTransparency = 1,
	Parent = gui,
})
local toastScale = Theme.make("UIScale", { Parent = toast })

local function showToast(text: string)
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0
	toastScale.Scale = 1.5
	TweenService:Create(toastScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		if toast.Text == text then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function nameFrom(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	return string.match(value, "^%d+|(.+)$")
end

player:GetAttributeChangedSignal("SavedBy"):Connect(function()
	local name = nameFrom(player:GetAttribute("SavedBy"))
	if name then
		showToast(string.format("¡%s te salvó!", name))
	end
end)
player:GetAttributeChangedSignal("Rescued"):Connect(function()
	local name = nameFrom(player:GetAttribute("Rescued"))
	if name then
		showToast(string.format("¡Salvaste a %s!", name))
	end
end)
