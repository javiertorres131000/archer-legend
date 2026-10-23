--!strict
-- HazardAlert (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > HazardAlert
-- Aviso en pantalla cuando estás parado dentro de un círculo de peligro (Server/Hazards marca
-- cada aviso con Warning, Radius y EndsAt). Hace falta sobre todo en primera persona, donde el
-- círculo del piso no se ve: bordes rojos que laten, "¡SALÍ DEL CÍRCULO!", una flecha que apunta
-- hacia afuera y una barra con el tiempo que queda. Solo visual.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local MARGEN = 2 -- studs de más: avisa también si estás justo en el borde

local gui = Instance.new("ScreenGui")
gui.Name = "HazardAlert"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.Enabled = false

-- Bordes rojos (cuatro franjas con degradé hacia el centro)
local bordes: { Frame } = {}
for i, cfg in { { 0, 0, 1, 0.12, 90 }, { 0, 0.88, 1, 0.12, -90 }, { 0, 0, 0.08, 1, 0 }, { 0.92, 0, 0.08, 1, 180 } } do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	f.Position = UDim2.fromScale(cfg[1], cfg[2])
	f.Size = UDim2.fromScale(cfg[3], cfg[4])
	local g = Instance.new("UIGradient")
	g.Rotation = cfg[5]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	f.Parent = gui
	bordes[i] = f
end

local texto = Instance.new("TextLabel")
texto.BackgroundTransparency = 1
texto.AnchorPoint = Vector2.new(0.5, 0.5)
texto.Position = UDim2.fromScale(0.5, 0.3)
texto.Size = UDim2.fromScale(0.6, 0.06)
texto.Font = Enum.Font.GothamBlack
texto.TextScaled = true
texto.Text = "¡SALÍ DEL CÍRCULO!"
texto.TextColor3 = Color3.fromRGB(255, 70, 60)
texto.TextStrokeTransparency = 0
texto.Parent = gui

local flecha = Instance.new("TextLabel")
flecha.BackgroundTransparency = 1
flecha.AnchorPoint = Vector2.new(0.5, 0.5)
flecha.Position = UDim2.fromScale(0.5, 0.5)
flecha.Size = UDim2.fromOffset(110, 110)
flecha.Font = Enum.Font.GothamBlack
flecha.TextScaled = true
flecha.Text = "➜"
flecha.TextColor3 = Color3.fromRGB(255, 220, 90)
flecha.TextStrokeTransparency = 0
flecha.Parent = gui

local barraFondo = Instance.new("Frame")
barraFondo.AnchorPoint = Vector2.new(0.5, 0.5)
barraFondo.Position = UDim2.fromScale(0.5, 0.36)
barraFondo.Size = UDim2.fromScale(0.25, 0.012)
barraFondo.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
barraFondo.BorderSizePixel = 0
barraFondo.Parent = gui
local barra = Instance.new("Frame")
barra.BackgroundColor3 = Color3.fromRGB(255, 60, 40)
barra.BorderSizePixel = 0
barra.Size = UDim2.fromScale(1, 1)
barra.Parent = barraFondo

gui.Parent = player:WaitForChild("PlayerGui")

local avisos: { [BasePart]: boolean } = {}
local function mirar(c: Instance)
	if c:IsA("BasePart") and c:GetAttribute("Warning") then
		avisos[c] = true
		c.AncestryChanged:Connect(function()
			if not c.Parent then
				avisos[c] = nil
			end
		end)
	end
end
task.spawn(function()
	local carpeta = Workspace:WaitForChild("Hazards")
	for _, c in carpeta:GetChildren() do
		mirar(c)
	end
	carpeta.ChildAdded:Connect(function(c)
		task.defer(mirar, c) -- los atributos llegan junto con la pieza
	end)
end)

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = Workspace.CurrentCamera
	if not root or not cam then
		gui.Enabled = false
		return
	end
	local now = Workspace:GetServerTimeNow()
	local peor: BasePart? = nil
	local peorQueda = math.huge
	for p in avisos do
		if not p.Parent then
			avisos[p] = nil
			continue
		end
		local r = (p:GetAttribute("Radius") :: number?) or 0
		local d = Vector3.new(root.Position.X - p.Position.X, 0, root.Position.Z - p.Position.Z)
		local queda = ((p:GetAttribute("EndsAt") :: number?) or now) - now
		if d.Magnitude <= r + MARGEN and queda < peorQueda then
			peor, peorQueda = p, queda
		end
	end
	if not peor then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local pulso = 0.35 + 0.35 * math.sin(os.clock() * 18)
	for _, f in bordes do
		f.BackgroundTransparency = pulso
	end
	-- flecha: hacia afuera del círculo, vista desde la cámara (arriba en pantalla = adelante)
	local centro = (peor :: BasePart).Position
	local salida = Vector3.new(root.Position.X - centro.X, 0, root.Position.Z - centro.Z)
	if salida.Magnitude < 0.5 then
		salida = cam.CFrame.RightVector
	end
	salida = Vector3.new(salida.X, 0, salida.Z).Unit
	local adelante = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	adelante = if adelante.Magnitude > 0.01 then adelante.Unit else Vector3.new(0, 0, -1)
	local derecha = Vector3.new(-adelante.Z, 0, adelante.X)
	flecha.Rotation = math.deg(math.atan2(-salida:Dot(adelante), salida:Dot(derecha)))
	local total = math.max(((peor :: BasePart):GetAttribute("Total") :: number?) or 1.5, 0.1)
	barra.Size = UDim2.fromScale(math.clamp(peorQueda / total, 0, 1), 1)
end)
