-- EnemyMarkers (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > EnemyMarkers
-- Indicador brillante arriba de cada enemigo (Config.Enemy.Markers): un rombo que se ve a través
-- de paredes y relieve, así siempre sabés dónde están (y se nota si alguno quedó trabado).
--   · Color: naranja los comunes, violeta las élites, dorado los dorados, rojo los jefes.
--   · Cuando quedan pocos por matar (MarkerFewLeft), se agrandan y laten.
--   · Los enterrados (atributo Hidden) no se marcan.
--   · Con pocos por matar aparece arriba de la pantalla una flecha que apunta al más cercano,
--     con cuántos quedan y a qué distancia está.
-- Es solo visual y local: no manda nada al servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EnemyCfg = Config.Enemy
if EnemyCfg.Markers == false then
	return
end

local player = Players.LocalPlayer
local gameState = ReplicatedStorage:WaitForChild("GameState")
local folder = workspace:WaitForChild("Enemies")

local COLORS = {
	Horde = Color3.fromRGB(255, 150, 60),
	Elite = Color3.fromRGB(200, 110, 255),
	Golden = Color3.fromRGB(255, 215, 60),
	Boss = Color3.fromRGB(255, 60, 60),
}

type Marker = { gui: BillboardGui, diamond: Frame, glow: Frame, part: BasePart }
local markers: { [BasePart]: Marker } = {}

local function colorFor(part: BasePart): Color3
	if string.sub(part.Name, 1, 6) == "Golden" then
		return COLORS.Golden
	end
	local role = part:GetAttribute("ThreatRole")
	if role == "Boss" then
		return COLORS.Boss
	elseif part:GetAttribute("Elite") or role == "Elite" then
		return COLORS.Elite
	end
	return COLORS.Horde
end

local function add(part: Instance)
	if not part:IsA("BasePart") or markers[part] then
		return
	end
	local color = colorFor(part)
	local size = EnemyCfg.MarkerSize or 14
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 2000
	gui.Size = UDim2.fromOffset(size * 2, size * 2)
	-- Arriba del modelo si tiene uno (VisualTop: alto desde el centro de la caja)
	local top = part:GetAttribute("VisualTop")
	gui.StudsOffsetWorldSpace = Vector3.new(0, (if typeof(top) == "number" then top else part.Size.Y / 2) + 2.5, 0)
	gui.ResetOnSpawn = false
	-- Halo suave detrás
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.7
	glow.BorderSizePixel = 0
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow
	glow.Parent = gui
	-- Rombo brillante
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.42, 0.42)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = color
	diamond.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = diamond
	diamond.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	markers[part] = { gui = gui, diamond = diamond, glow = glow, part = part }
end

local function remove(part: Instance)
	local m = markers[part :: BasePart]
	if m then
		m.gui:Destroy()
		markers[part :: BasePart] = nil
	end
end

-- Flecha arriba al centro (solo cuando quedan pocos)
local arrowGui = Instance.new("ScreenGui")
arrowGui.Name = "EnemyArrow"
arrowGui.ResetOnSpawn = false
arrowGui.DisplayOrder = 5
arrowGui.Parent = player:WaitForChild("PlayerGui")
local arrowHolder = Instance.new("Frame")
arrowHolder.AnchorPoint = Vector2.new(0.5, 0)
arrowHolder.Position = UDim2.new(0.5, 0, 0, 92)
arrowHolder.Size = UDim2.fromOffset(160, 84)
arrowHolder.BackgroundTransparency = 1
arrowHolder.Visible = false
arrowHolder.Parent = arrowGui
local arrow = Instance.new("TextLabel")
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.fromOffset(80, 26)
arrow.Size = UDim2.fromOffset(48, 48)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextSize = 44
arrow.Font = Enum.Font.GothamBlack
arrow.TextColor3 = COLORS.Horde
arrow.TextStrokeTransparency = 0.2
arrow.Parent = arrowHolder
local arrowText = Instance.new("TextLabel")
arrowText.AnchorPoint = Vector2.new(0.5, 0)
arrowText.Position = UDim2.fromOffset(80, 54)
arrowText.Size = UDim2.fromOffset(200, 22)
arrowText.BackgroundTransparency = 1
arrowText.Font = Enum.Font.GothamBold
arrowText.TextSize = 15
arrowText.TextColor3 = Color3.new(1, 1, 1)
arrowText.TextStrokeTransparency = 0.3
arrowText.Parent = arrowHolder

for _, child in folder:GetChildren() do
	add(child)
end
folder.ChildAdded:Connect(add)
folder.ChildRemoved:Connect(remove)

-- Latido (cuando quedan pocos) y limpieza de los que ya no están
RunService.RenderStepped:Connect(function()
	local left = gameState:GetAttribute("EnemiesLeft") or 0
	local few = left > 0 and left <= (EnemyCfg.MarkerFewLeft or 10)
	local size = EnemyCfg.MarkerSize or 14
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
	local px = if few then size * (2.6 + pulse * 0.8) else size * 2
	local inMatch = player:GetAttribute("InMatch") == true
	local camera = workspace.CurrentCamera
	local nearest: BasePart? = nil
	local nearestDist = math.huge
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for part, m in markers do
		if not part.Parent then
			m.gui:Destroy()
			markers[part] = nil
			continue
		end
		m.gui.Enabled = inMatch and part:GetAttribute("Hidden") ~= true
		m.gui.Size = UDim2.fromOffset(px, px)
		m.glow.BackgroundTransparency = if few then 0.45 + 0.3 * (1 - pulse) else 0.7
		if few and m.gui.Enabled and myRoot then
			local d = (part.Position - myRoot.Position).Magnitude
			if d < nearestDist then
				nearest, nearestDist = part, d
			end
		end
	end

	-- Flecha hacia el más cercano: 0° = adelante de la cámara, 90° = a la derecha
	arrowHolder.Visible = inMatch and few and nearest ~= nil and camera ~= nil
	if arrowHolder.Visible and nearest and camera then
		local rel = camera.CFrame:VectorToObjectSpace(nearest.Position - camera.CFrame.Position)
		arrow.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
		arrow.TextColor3 = colorFor(nearest)
		arrow.TextSize = 40 + 6 * pulse
		arrowText.Text = string.format("Quedan %d · %d m", left, math.floor(nearestDist + 0.5))
	end
end)
