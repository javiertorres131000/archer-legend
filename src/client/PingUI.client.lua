-- PingUI (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > PingUI
-- Marcas para el cooperativo (ver server/Ping.lua y Config.Ping).
--   · Marcar: G, ruedita del mouse, cruz arriba del joystick o el botón MARCAR en el celular.
--     Manda al servidor desde dónde mira la cámara y hacia dónde; él decide qué se marcó.
--   · Dibuja las marcas de todo el equipo con el color de quien marcó: ícono, nombre y distancia,
--     visibles a través de todo. Si no la estás viendo, una flecha en el borde de la pantalla.
--   · Lugar: columna de luz y anillo en el piso. Enemigo: la marca lo sigue hasta que muere.
-- Es solo visual: el servidor valida frecuencia, estado y distancia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Cfg = Config.Ping
if not Cfg or Cfg.Enabled == false then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("PingRequest") :: RemoteEvent
local pingEvent = remotes:WaitForChild("Ping") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACTION = "CoopPing"
local ICONS = { Enemy = "⚠", Chest = "★", Ground = "▼", Help = "✚" }
local EDGE_MARGIN = 56

local screen = Instance.new("ScreenGui")
screen.Name = "Pings"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true -- así las coordenadas coinciden con WorldToViewportPoint
screen.DisplayOrder = 6
screen.Parent = playerGui

local worldFolder = Instance.new("Folder")
worldFolder.Name = "Pings"
worldFolder.Parent = workspace

local sound = Instance.new("Sound")
local def = Sounds.List.Ping
if def then
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (Sounds.MasterVolume or 1)
end
sound.Parent = script

type Marker = {
	id: number,
	kind: string,
	part: BasePart?,
	anchor: BasePart?,
	extras: { Instance },
	gui: BillboardGui,
	icon: TextLabel,
	dist: TextLabel,
	edge: Frame,
	arrow: TextLabel,
	height: number, -- altura del cartel sobre el objetivo
	born: number,
	expires: number,
}
local markers: { [number]: Marker } = {}

local function colorFor(slot: any): Color3
	local colors = Cfg.Colors or {}
	return colors[if type(slot) == "number" then slot else 1] or Color3.new(1, 1, 1)
end

local function remove(id: number)
	local m = markers[id]
	if not m then
		return
	end
	markers[id] = nil
	m.gui:Destroy()
	m.edge:Destroy()
	for _, x in m.extras do
		x:Destroy()
	end
end

local function clearAll()
	for id in table.clone(markers) do
		remove(id)
	end
end

local function worldPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = worldFolder
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.BuilderSansBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.25
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function add(mark: any)
	if type(mark) ~= "table" or type(mark.id) ~= "number" or typeof(mark.pos) ~= "Vector3" then
		return
	end
	remove(mark.id)
	local color = colorFor(mark.slot)
	local kind = tostring(mark.kind)
	local part = if typeof(mark.part) == "Instance" and mark.part:IsA("BasePart") then mark.part else nil
	local extras = {}
	local anchor: BasePart? = nil
	local height = 3
	if part then
		local top = part:GetAttribute("VisualTop")
		height = (if type(top) == "number" then top else part.Size.Y / 2) + 6
	else
		anchor = worldPart({ Name = "PingAnchor", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(mark.pos) })
		table.insert(extras, anchor)
		if kind == "Ground" then
			-- Columna de luz y anillo en el piso
			table.insert(extras, worldPart({
				Name = "PingBeam", Material = Enum.Material.Neon, Color = color, Transparency = 0.45,
				Size = Vector3.new(0.35, 26, 0.35), CFrame = CFrame.new(mark.pos + Vector3.new(0, 13, 0)),
			}))
			local ring = worldPart({
				Name = "PingRing", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color,
				Transparency = 0.5, Size = Vector3.new(0.15, 7, 7),
				CFrame = CFrame.new(mark.pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			})
			table.insert(extras, ring)
			height = 4
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Ping"
	gui.Adornee = part or anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 5000
	gui.Size = UDim2.fromOffset(170, 74)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.ResetOnSpawn = false
	local icon = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 0.05, BackgroundColor3 = color, Text = ICONS[kind] or "◆", TextSize = 20,
		TextColor3 = Color3.fromRGB(20, 20, 30), TextStrokeTransparency = 1,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = icon
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = icon
	local who = if mark.userId == player.UserId then "Vos" else tostring(mark.name)
	label(gui, {
		Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 18), TextSize = 15,
		Text = who .. " · " .. tostring(mark.label), TextColor3 = color,
	})
	local dist = label(gui, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Text = "" })
	gui.Parent = playerGui

	-- Indicador en el borde de la pantalla (cuando no se ve)
	local edge = Instance.new("Frame")
	edge.AnchorPoint = Vector2.new(0.5, 0.5)
	edge.Size = UDim2.fromOffset(40, 40)
	edge.BackgroundColor3 = color
	edge.BackgroundTransparency = 0.1
	edge.Visible = false
	local edgeCorner = Instance.new("UICorner")
	edgeCorner.CornerRadius = UDim.new(1, 0)
	edgeCorner.Parent = edge
	label(edge, { Size = UDim2.fromScale(1, 1), Text = ICONS[kind] or "◆", TextSize = 20, TextColor3 = Color3.fromRGB(20, 20, 30), TextStrokeTransparency = 1 })
	local arrow = label(edge, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 70),
		Text = "▲", TextSize = 16, TextColor3 = color, TextStrokeTransparency = 0.3, TextYAlignment = Enum.TextYAlignment.Top,
	})
	edge.Parent = screen

	local now = os.clock()
	markers[mark.id] = {
		id = mark.id, kind = kind, part = part, anchor = anchor, extras = extras, gui = gui, icon = icon,
		dist = dist, edge = edge, arrow = arrow, height = height, born = now,
		expires = now + (if type(mark.duration) == "number" then mark.duration else Cfg.Duration),
	}
	sound.PlaybackSpeed = (if def then def.Pitch else 1) * (if kind == "Help" then 0.6 else 1)
	SoundService:PlayLocalSound(sound)
end

pingEvent.OnClientEvent:Connect(function(action, arg)
	if action == "Add" then
		add(arg)
	elseif action == "Remove" and type(arg) == "number" then
		remove(arg)
	elseif action == "Clear" then
		clearAll()
	end
end)

-- Entrada ---------------------------------------------------------------
local lastSent = 0

local function aim(): (Vector3?, Vector3?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	if Config.Camera.Mode == "TopDown" then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		return ray.Origin, ray.Direction.Unit
	end
	return camera.CFrame.Position, camera.CFrame.LookVector
end

local function onAction(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or player:GetAttribute("InMatch") ~= true then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastSent < (Cfg.Cooldown or 0.5) then
		return Enum.ContextActionResult.Sink
	end
	local origin, dir = aim()
	if origin and dir then
		lastSent = now
		request:FireServer(origin, dir)
	end
	return Enum.ContextActionResult.Sink
end

local bound = false
local function refresh()
	local active = player:GetAttribute("InMatch") == true
	if active and not bound then
		ContextActionService:BindAction(ACTION, onAction, true, table.unpack(Cfg.Keys))
		ContextActionService:SetTitle(ACTION, "MARCAR")
		ContextActionService:SetPosition(ACTION, UDim2.fromScale(0.62, 0.55))
		bound = true
	elseif not active and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	if not active then
		clearAll()
	end
end
player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
refresh()

-- Cada frame: distancia, latido al aparecer, flecha en el borde y vencimiento ----------
RunService.RenderStepped:Connect(function()
	if next(markers) == nil then
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = os.clock()
	local view = camera and camera.ViewportSize or Vector2.new(1, 1)
	local center = view / 2
	for id, m in markers do
		local target = m.part or m.anchor
		if now >= m.expires or not target or not target.Parent then
			remove(id)
			continue
		end
		local pos = target.Position + Vector3.new(0, m.height, 0) -- donde está el cartel
		if root then
			m.dist.Text = string.format("%d m", math.floor((target.Position - root.Position).Magnitude + 0.5))
		end
		local age = now - m.born
		local pop = if age < 0.5 then 1 + 0.6 * (1 - age / 0.5) else 1 + 0.06 * math.sin(now * 6)
		m.icon.Size = UDim2.fromOffset(34 * pop, 34 * pop)
		-- Últimos 1,5 s: se desvanece
		local fade = math.clamp((m.expires - now) / 1.5, 0, 1)
		m.gui.Enabled = fade > 0.05
		m.icon.BackgroundTransparency = 1 - 0.95 * fade

		if camera then
			local v = camera:WorldToViewportPoint(pos)
			local onScreen = v.Z > 0 and v.X >= 0 and v.X <= view.X and v.Y >= 0 and v.Y <= view.Y
			m.edge.Visible = not onScreen
			if not onScreen then
				local p = Vector2.new(v.X, v.Y)
				if v.Z <= 0 then
					p = view - p -- detrás de la cámara: del lado contrario
				end
				local d = p - center
				if d.Magnitude < 1 then
					d = Vector2.new(0, 1)
				end
				local dir = d.Unit
				local hw, hh = center.X - EDGE_MARGIN, center.Y - EDGE_MARGIN
				local t = math.min(
					if math.abs(dir.X) > 1e-4 then hw / math.abs(dir.X) else math.huge,
					if math.abs(dir.Y) > 1e-4 then hh / math.abs(dir.Y) else math.huge
				)
				local at = center + dir * t
				m.edge.Position = UDim2.fromOffset(at.X, at.Y)
				m.arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
			end
		end
	end
end)
