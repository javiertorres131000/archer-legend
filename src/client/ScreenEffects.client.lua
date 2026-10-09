-- ScreenEffects (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > ScreenEffects
-- Efectos de pantalla de la partida. Son solo visuales: el servidor no se entera.
--   · Alerta de amenazas (primera persona): flechas rojas que brillan alrededor de la mira y
--     el borde de la pantalla que se enciende del lado del enemigo que no estás viendo.
--   · Golpe: la pantalla se pone roja al recibir daño (más fuerte cuanto más te sacan).
--   · Sangre: con poca vida los bordes se van llenando de sangre; con muy poca, laten.
-- Todo se dibuja con Frames y gradientes (sin imágenes externas).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

local player = Players.LocalPlayer
local CamCfg = Config.Camera
local FxCfg = Config.Effects

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

-- Debajo del HUD (DisplayOrder menor) y cubriendo también la barra superior de Roblox
local gui = make("ScreenGui", {
	Name = "ScreenEffects",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = -1,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
-- Las flechas van arriba del HUD para que nada las tape
local arrowsGui = make("ScreenGui", {
	Name = "ThreatArrows",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local function inPlay(): boolean
	return player:GetAttribute("InMatch") == true and player:GetAttribute("LifeState") ~= "ELIMINATED"
end
local function refreshEnabled()
	gui.Enabled = player:GetAttribute("InMatch") == true
	arrowsGui.Enabled = gui.Enabled
end
player:GetAttributeChangedSignal("InMatch"):Connect(refreshEnabled)
refreshEnabled()

---------------------------------------------------------------------
-- Bordes con degradé: opacos en el borde de la pantalla y transparentes hacia el centro.
-- La intensidad se maneja con BackgroundTransparency (1 = no se ve).
---------------------------------------------------------------------
type Side = "Left" | "Right" | "Top" | "Bottom"
type Edges = { [Side]: Frame }

local function edge(side: Side, depth: number, color: Color3, zIndex: number, falloff: number): Frame
	local horizontal = side == "Left" or side == "Right"
	local frame = make("Frame", {
		Name = side,
		AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
		Position = UDim2.fromScale(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
		Size = if horizontal then UDim2.fromScale(depth, 1) else UDim2.fromScale(1, depth),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = gui,
	})
	-- El degradé va del borde (opaco) al centro (transparente)
	local rotation = ({ Left = 0, Right = 180, Top = 90, Bottom = 270 } :: { [Side]: number })[side]
	make("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(falloff, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = frame,
	})
	return frame
end

local function edges(depth: number, color: Color3, zIndex: number, falloff: number): Edges
	return {
		Left = edge("Left", depth, color, zIndex, falloff),
		Right = edge("Right", depth, color, zIndex, falloff),
		Top = edge("Top", depth, color, zIndex, falloff),
		Bottom = edge("Bottom", depth, color, zIndex, falloff),
	}
end

local function setEdges(set: Edges, alpha: number)
	local t = 1 - math.clamp(alpha, 0, 1)
	for _, f in set do
		f.BackgroundTransparency = t
	end
end

local function setDepth(set: Edges, depth: number)
	for side, f in set do
		f.Size = if side == "Left" or side == "Right" then UDim2.fromScale(depth, 1) else UDim2.fromScale(1, depth)
	end
end

---------------------------------------------------------------------
-- Sangre por vida baja
---------------------------------------------------------------------
local BLOOD_DARK = Color3.fromRGB(70, 0, 0)
local BLOOD = Color3.fromRGB(140, 0, 6)
local bloodOuter = edges(0.18, BLOOD_DARK, 1, 0.35)
local bloodInner = edges(0.3, BLOOD, 2, 0.25)

-- Manchas: círculos pegados a los bordes que aparecen de a poco a medida que baja la vida
type Blot = { frame: Frame, threshold: number }
local blots: { Blot } = {}
do
	local rng = Random.new(7)
	for i = 1, 18 do
		local size = rng:NextInteger(90, 240)
		-- Un punto del borde (la mitad de la mancha queda afuera de la pantalla)
		local along = rng:NextNumber(0, 1)
		local side = i % 4
		local x, y
		if side == 0 then
			x, y = 0, along
		elseif side == 1 then
			x, y = 1, along
		elseif side == 2 then
			x, y = along, 0
		else
			x, y = along, 1
		end
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = if rng:NextNumber() < 0.5 then BLOOD_DARK else BLOOD,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = gui,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
		table.insert(blots, { frame = frame, threshold = rng:NextNumber(0.1, 0.9) })
	end
end

---------------------------------------------------------------------
-- Destello rojo al recibir un golpe
---------------------------------------------------------------------
local hitEdges = edges(0.45, Color3.fromRGB(230, 0, 0), 4, 0.3)
local hitWash = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(200, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 4,
	Parent = gui,
})

local hit = 0 -- 0..1, se va apagando solo
local healthFrac = 1

local healthConn: RBXScriptConnection? = nil
local function watchHealth(character: Model)
	if healthConn then
		healthConn:Disconnect()
		healthConn = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local last = humanoid.Health
	healthFrac = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	healthConn = humanoid.HealthChanged:Connect(function(health: number)
		local max = math.max(humanoid.MaxHealth, 1)
		local lost = last - health
		last = health
		healthFrac = math.clamp(health / max, 0, 1)
		if lost > 0 and inPlay() then
			hit = math.clamp(math.max(hit, FxCfg.HitFlash) + (lost / max) * FxCfg.HitFlashPerDamage, 0, 1)
		end
	end)
end
player.CharacterAdded:Connect(watchHealth)
if player.Character then
	task.spawn(watchHealth, player.Character)
end

---------------------------------------------------------------------
-- Alerta de amenazas fuera de la vista (primera persona)
---------------------------------------------------------------------
local THREAT = Color3.fromRGB(255, 50, 30)
local threatEdges = edges(0.14, THREAT, 5, 0.2)

type Arrow = { holder: Frame, glow: TextLabel, core: TextLabel }
local MAX_ALERTS = 10
local RING_RADIUS = 130
local ring = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	Parent = arrowsGui,
})
local arrows: { Arrow } = {}
for i = 1, MAX_ALERTS do
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(80, 80),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = ring,
	})
	-- Halo: la misma flecha más grande y transparente, da el efecto de brillo
	local glow = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▲",
		Font = Theme.Fonts.Bold,
		TextSize = 70,
		TextColor3 = Color3.fromRGB(255, 20, 0),
		TextTransparency = 0.5,
		TextStrokeTransparency = 1,
		ZIndex = 1,
		Parent = holder,
	})
	local core = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "▲",
		Font = Theme.Fonts.Bold,
		TextSize = 44,
		TextColor3 = Color3.fromRGB(255, 120, 90),
		TextStrokeColor3 = Color3.fromRGB(255, 230, 200),
		TextStrokeTransparency = 0.2,
		ZIndex = 2,
		Parent = holder,
	})
	arrows[i] = { holder = holder, glow = glow, core = core }
end

local enemiesFolder: Instance? = nil
local orbsFolder: Instance? = nil

-- Busca amenazas y dibuja las flechas. Devuelve cuánto brilla cada borde (izq, der, abajo).
local function updateThreats(pulse: number): (number, number, number)
	local used = 0
	local left, right, back = 0, 0, 0
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if CamCfg.Mode == "FirstPerson" and inPlay() and camera and root then
		enemiesFolder = enemiesFolder or workspace:FindFirstChild("Enemies")
		orbsFolder = orbsFolder or workspace:FindFirstChild("ProjectileVisuals")
		local viewCos = math.cos(math.rad(CamCfg.ThreatViewAngle))
		local look = camera.CFrame.LookVector
		local lookFlat = Vector3.new(look.X, 0, look.Z)
		lookFlat = if lookFlat.Magnitude > 0.01 then lookFlat.Unit else Vector3.new(0, 0, -1)
		local rightFlat = Vector3.new(-lookFlat.Z, 0, lookFlat.X)

		local function consider(part: BasePart, radius: number)
			if used >= MAX_ALERTS or part.Transparency >= 1 then
				return
			end
			local offset = part.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dist = flat.Magnitude
			if dist > radius or dist < 0.1 then
				return
			end
			-- Dirección respecto de hacia dónde mirás (solo el giro horizontal)
			local dir = flat.Unit
			local forward = dir:Dot(lookFlat)
			if forward >= viewCos then
				return -- ya lo estás viendo
			end
			local side = dir:Dot(rightFlat)
			local angle = math.atan2(side, forward) -- 0 = adelante, ±π = atrás
			local closeness = 1 - dist / radius
			used += 1
			local a = arrows[used]
			a.holder.Position = UDim2.fromOffset(math.sin(angle) * RING_RADIUS, -math.cos(angle) * RING_RADIUS)
			a.holder.Rotation = math.deg(angle)
			a.holder.Visible = true
			-- Siempre bien visible; más cerca = más grande y el halo late más fuerte
			a.core.TextSize = 40 + 22 * closeness
			a.core.TextTransparency = 0.15 - 0.15 * closeness
			a.glow.TextSize = (40 + 22 * closeness) * 1.7
			a.glow.TextTransparency = 0.65 - 0.35 * closeness * pulse
			right = math.max(right, math.max(side, 0) * (0.4 + 0.6 * closeness))
			left = math.max(left, math.max(-side, 0) * (0.4 + 0.6 * closeness))
			back = math.max(back, math.max(-forward, 0) * (0.4 + 0.6 * closeness))
		end
		if enemiesFolder then
			for _, e in enemiesFolder:GetChildren() do
				if e:IsA("BasePart") then
					consider(e, CamCfg.ThreatRadius)
				end
			end
		end
		if orbsFolder then
			for _, o in orbsFolder:GetChildren() do
				if o:IsA("BasePart") and o.Name == "EnemyOrb" then
					consider(o, CamCfg.ThreatProjectileRadius)
				end
			end
		end
	end
	for i = used + 1, MAX_ALERTS do
		arrows[i].holder.Visible = false
	end
	return left, right, back
end

---------------------------------------------------------------------
-- Cada frame
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt: number)
	if not gui.Enabled then
		hit = 0
		return
	end
	local now = os.clock()
	local playing = inPlay()

	-- Amenazas: flechas y bordes que laten
	local pulse = 0.75 + 0.25 * math.sin(now * 12)
	local left, right, back = updateThreats(pulse)
	local glow = FxCfg.ThreatEdgeGlow * pulse
	threatEdges.Left.BackgroundTransparency = 1 - left * glow
	threatEdges.Right.BackgroundTransparency = 1 - right * glow
	threatEdges.Bottom.BackgroundTransparency = 1 - back * glow
	threatEdges.Top.BackgroundTransparency = 1

	-- Golpe: se apaga solo
	hit *= math.exp(-dt * FxCfg.HitFlashFade)
	if hit < 0.01 then
		hit = 0
	end
	setEdges(hitEdges, hit)
	hitWash.BackgroundTransparency = 1 - hit * 0.3

	-- Sangre: aparece con menos de BloodStartsAt de vida y crece hasta BloodMax
	local downed = player:GetAttribute("LifeState") == "DOWNED"
	local amount = 0
	if playing then
		local start = FxCfg.BloodStartsAt
		amount = if downed then 1 else math.clamp((start - healthFrac) / start, 0, 1)
	end
	local blood = amount ^ 0.8 * FxCfg.BloodMax
	if amount > 0 and (downed or healthFrac < FxCfg.HeartbeatBelow) then
		-- Latido: dos golpes seguidos y una pausa
		local beat = (now * 1.3) % 1
		local thump = math.max(0, 1 - math.abs(beat - 0.1) * 12) + 0.7 * math.max(0, 1 - math.abs(beat - 0.3) * 12)
		blood = math.min(1, blood + 0.15 * thump)
	end
	setEdges(bloodOuter, blood)
	setEdges(bloodInner, blood * 0.8)
	setDepth(bloodInner, 0.15 + 0.3 * amount) -- la sangre avanza hacia el centro
	for _, b in blots do
		-- Cada mancha aparece cuando la vida baja de su umbral
		local show = math.clamp((amount - b.threshold) / 0.15, 0, 1)
		b.frame.BackgroundTransparency = 1 - show * 0.85 * (blood / math.max(FxCfg.BloodMax, 0.01))
	end
end)
