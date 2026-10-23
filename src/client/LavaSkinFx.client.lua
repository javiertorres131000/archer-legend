--!strict
-- LavaSkinFx (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > LavaSkinFx
-- Efectos visuales de los trajes con brillo (CrateLooks): Demonio Ígneo, Mago Cósmico y Necromante. Todo corre en cada cliente, nada se
-- replica ni toca la jugabilidad:
--   · Brillo que late: todo lo que CrateLooks marca con el tag "LavaGlow" (SurfaceAppearance o
--     PointLight, con el atributo GlowBase) pulsa alrededor de su valor.
--   · Balanceo: las Welds con tag "LavaSway" (alas y capa) se mueven con el tiempo y la velocidad.
--     Las alas se abren al saltar (aletazos fuertes subiendo, planeo cayendo).
--   · Para los personajes con una skin de Shared/SkinFx: pisadas de lava, aura en el piso, estela en el
--     dash y explosión de brasas al equiparlo.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkinFx"))

local C = Color3.fromRGB

-- Trajes con efectos de movimiento: los colores salen de Shared/SkinFx (Id del premio -> paleta)
local function colorsOf(id: any): SkinFx.Palette?
	local skin = SkinFx.get(id)
	return skin and skin.Colors
end

local FAR = 160 -- más lejos que esto de la cámara no se anima nada
local STEP_EVERY = 0.3 -- segundos entre pisadas
local MARK_LIFE = 1.6
local MAX_MARKS = 40
local DASH_SPEED = 40 -- velocidad horizontal a partir de la que se ve la estela

local camera = Workspace.CurrentCamera
local fxFolder = Instance.new("Folder")
fxFolder.Name = "LavaSkinFx"
fxFolder.Parent = Workspace

---------------------------------------------------------------------
-- Brillo que late
---------------------------------------------------------------------

local glows: { [Instance]: number } = {} -- instancia -> fase
local function addGlow(inst: Instance)
	glows[inst] = math.random() * math.pi * 2
end
for _, inst in CollectionService:GetTagged("LavaGlow") do
	addGlow(inst)
end
CollectionService:GetInstanceAddedSignal("LavaGlow"):Connect(addGlow)
CollectionService:GetInstanceRemovedSignal("LavaGlow"):Connect(function(inst)
	glows[inst] = nil
end)

local function positionOf(inst: Instance): Vector3?
	local p = inst:FindFirstAncestorWhichIsA("BasePart")
	if inst:IsA("BasePart") then
		p = inst
	end
	return if p then p.Position else nil
end

local function pulse(t: number, phase: number): number
	-- latido lento (sin parpadeo rápido), entre ~0.75 y ~1.1
	return 0.92 + 0.16 * math.sin(t * 1.6 + phase) + 0.02 * math.sin(t * 3.7 + phase * 2.3)
end

local function updateGlows(t: number)
	local camPos = camera.CFrame.Position
	for inst, phase in glows do
		local base = inst:GetAttribute("GlowBase")
		if type(base) ~= "number" then
			continue
		end
		-- Las vistas previas (ViewportFrame) no tienen posición útil: se animan igual
		if inst:IsDescendantOf(Workspace) then
			local pos = positionOf(inst)
			if pos and (pos - camPos).Magnitude > FAR then
				continue
			end
		end
		local k = pulse(t, phase)
		if inst:IsA("SurfaceAppearance") then
			inst.EmissiveStrength = base * k
		elseif inst:IsA("PointLight") then
			inst.Brightness = base * k
		end
	end
end

---------------------------------------------------------------------
-- Balanceo de alas y capa
---------------------------------------------------------------------

local sways: { [Weld]: CFrame } = {} -- weld -> C0 original
local function addSway(inst: Instance)
	if inst:IsA("Weld") then
		sways[inst] = inst.C0
	end
end
for _, inst in CollectionService:GetTagged("LavaSway") do
	addSway(inst)
end
CollectionService:GetInstanceAddedSignal("LavaSway"):Connect(addSway)
CollectionService:GetInstanceRemovedSignal("LavaSway"):Connect(function(inst)
	sways[inst :: any] = nil
end)

-- Estado por weld: velocidad suavizada, fase acumulada (se acumula con dt para que cambiar la
-- frecuencia no haga saltar la animación) y cuánto está en el aire (0 a 1)
type SwayState = { speed: number, phase: number, air: number, wasAir: boolean, humanoid: Humanoid? }
local swayState: { [Weld]: SwayState } = {}

-- ¿El personaje está en el aire? (piso de aire o velocidad vertical clara)
local function isAirborne(humanoid: Humanoid?, base: BasePart): boolean
	if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
		return true
	end
	return math.abs(base.AssemblyLinearVelocity.Y) > 6
end

local function updateSways(dt: number)
	local camPos = camera.CFrame.Position
	dt = math.min(dt, 0.1)
	for weld, original in sways do
		local base = weld.Part0
		if not base or not weld.Parent then
			sways[weld] = nil
			swayState[weld] = nil
			continue
		end
		if (base.Position - camPos).Magnitude > FAR then
			continue
		end
		local st = swayState[weld]
		if not st then
			local character = base:FindFirstAncestorWhichIsA("Model")
			st = {
				speed = 0,
				phase = math.random() * 0.5,
				air = 0,
				wasAir = false,
				humanoid = character and character:FindFirstChildOfClass("Humanoid"),
			}
			swayState[weld] = st
		end
		local kind = weld:GetAttribute("Kind")
		-- En el aire: se abren rápido al despegar y se cierran más lento al aterrizar
		local airborne = isAirborne(st.humanoid, base)
		st.air += ((if airborne then 1 else 0) - st.air) * math.min(1, dt * (if airborne then 7 else 3.5))
		if airborne and not st.wasAir and kind == "Wing" then
			-- llamarada de las alas al despegar
			local wing = weld.Part1
			local flames = wing and wing:FindFirstChild("FxLlamas")
			if flames and flames:IsA("ParticleEmitter") then
				flames:Emit(25)
			end
		end
		st.wasAir = airborne
		-- Velocidad horizontal con zona muerta (ignora el temblor de las animaciones) y muy suavizada
		local v = base.AssemblyLinearVelocity
		local raw = Vector3.new(v.X, 0, v.Z).Magnitude
		local target = math.clamp((raw - 3) / 20, 0, 1)
		st.speed += (target - st.speed) * math.min(1, dt * 2.5)
		local s = st.speed
		local pivot = weld:GetAttribute("Pivot")
		local pv: Vector3 = if typeof(pivot) == "Vector3" then pivot else Vector3.zero
		local rot: CFrame
		if kind == "Wing" then
			local side = weld:GetAttribute("Side") :: number? or 1
			local a = st.air
			local vy = v.Y
			-- En el piso: ~1 aleteo cada 3 s (más rápido al correr). Subiendo: aletazos fuertes.
			-- Cayendo: planea con aletazos lentos.
			local up = math.clamp(vy / 12, 0, 1) -- 0 cayendo/planeando, 1 subiendo (continuo)
			local airSpeed = 3 + 3.5 * up
			st.phase += dt * ((2.1 + 1.2 * s) * (1 - a) + airSpeed * a)
			local wave = math.sin(st.phase)
			-- curva suavizada: más tiempo en los extremos y transición lenta
			local eased = wave * (1.5 - 0.5 * wave * wave)
			-- Piso: se balancean hacia atrás/adelante (eje Y)
			local flap = eased * (0.14 + 0.04 * s)
			local fold = 0.08 + 0.22 * s -- al correr se pliegan hacia atrás
			local lift = math.sin(st.phase - 0.6) * 0.035
			-- Aire: abiertas hacia los costados (eje Z) y aleteando arriba/abajo
			local beat = 0.12 + 0.16 * up
			local open = -0.5 + eased * beat
			local yaw = (flap + fold) * (1 - a) - 0.1 * a -- en el aire, un poco hacia adelante
			local roll = lift * (1 - a) + open * a
			rot = CFrame.Angles(0, side * yaw, side * roll)
		elseif kind == "Skirt" then
			-- Faldones alrededor de la cintura: se mecen poco (si se inclinan mucho, atraviesan las piernas)
			st.phase += dt * (1.2 + 1.4 * s)
			local back = 0.02 + 0.1 * s
			local wave = math.sin(st.phase) * (0.02 + 0.025 * s)
			rot = CFrame.Angles(-(back + wave), 0, math.sin(st.phase * 0.7) * 0.02)
		else -- Cape
			st.phase += dt * (1.4 + 1.6 * s)
			local back = 0.05 + 0.35 * s
			local wave = math.sin(st.phase) * (0.025 + 0.04 * s)
			rot = CFrame.Angles(-(back + wave), 0, math.sin(st.phase * 0.6) * 0.015)
		end
		weld.C0 = original * CFrame.new(pv) * rot * CFrame.new(-pv)
	end
end

---------------------------------------------------------------------
-- Efectos de movimiento (solo skins de Shared/SkinFx)
---------------------------------------------------------------------

type Colors = { hot: Color3, mid: Color3, dark: Color3 }
type Tracked = {
	character: Model,
	skin: string,
	lastStep: number,
	foot: number,
	instances: { Instance },
	trail: Trail?,
	burst: ParticleEmitter?,
	dashing: boolean,
}
local tracked: { [Model]: Tracked } = {}
local marks: { BasePart } = {}

local function emitterProps(e: ParticleEmitter, props: { [string]: any })
	for k, v in props do
		(e :: any)[k] = v
	end
end

local function sparkBurst(at: Vector3, colors: Colors, count: number, speed: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.5, 0.2, 0.5)
	holder.CFrame = CFrame.new(at)
	local e = Instance.new("ParticleEmitter")
	emitterProps(e, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 0,
		Lifetime = NumberRange.new(0.3, 0.8),
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -12, 0),
		LightEmission = 1,
		LightInfluence = 0,
		Color = ColorSequence.new(colors.hot, colors.mid),
		Size = NumberSequence.new(0.15, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	e.Parent = holder
	holder.Parent = fxFolder
	e:Emit(count)
	task.delay(1, function()
		holder:Destroy()
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function footprint(character: Model, foot: BasePart, colors: Colors)
	rayParams.FilterDescendantsInstances = { character, fxFolder }
	local hit = Workspace:Raycast(foot.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, -4, 0), rayParams)
	if not hit then
		return
	end
	local flat = CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(0, math.rad(90), 0)
	local yaw = CFrame.Angles(math.rad(math.random(0, 360)), 0, 0)
	-- costra oscura + centro de lava
	local crust = Instance.new("Part")
	crust.Shape = Enum.PartType.Cylinder
	crust.Anchored = true
	crust.CanCollide = false
	crust.CanQuery = false
	crust.CanTouch = false
	crust.CastShadow = false
	crust.Material = Enum.Material.Slate
	crust.Color = C(30, 18, 15)
	crust.Size = Vector3.new(0.04, 1.3, 1.3)
	crust.CFrame = flat * yaw * CFrame.new(0.01, 0, 0)
	crust.Transparency = 0.15
	local core = crust:Clone()
	core.Material = Enum.Material.Neon
	core.Color = colors.mid
	core.Size = Vector3.new(0.05, 0.75, 0.75)
	core.CFrame = flat * yaw * CFrame.new(0.02, 0, 0)
	core.Transparency = 0
	crust.Parent = fxFolder
	core.Parent = fxFolder
	local info = TweenInfo.new(MARK_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(core, info, { Transparency = 1, Size = Vector3.new(0.05, 0.2, 0.2), Color = colors.dark }):Play()
	TweenService:Create(crust, info, { Transparency = 1 }):Play()
	table.insert(marks, crust)
	table.insert(marks, core)
	while #marks > MAX_MARKS do
		local old = table.remove(marks, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(MARK_LIFE, function()
		crust:Destroy()
		core:Destroy()
	end)
	sparkBurst(hit.Position + Vector3.new(0, 0.1, 0), colors, 6, 6)
end

-- Explosión de brasas, anillo y destello (al equipar)
local function equipBurst(root: BasePart, colors: Colors)
	local at = root.Position
	sparkBurst(at, colors, 45, 18)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = colors.mid
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.CFrame = CFrame.new(at - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = colors.mid
	light.Range = 22
	light.Brightness = 6
	light.Parent = ring
	ring.Parent = fxFolder
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.1, 16, 16), Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	task.delay(0.8, function()
		ring:Destroy()
	end)
end

local function stopTracking(character: Model)
	local tr = tracked[character]
	if not tr then
		return
	end
	for _, inst in tr.instances do
		inst:Destroy()
	end
	tracked[character] = nil
end

local function startTracking(character: Model, skin: string, burst: boolean)
	stopTracking(character)
	local colors = colorsOf(skin)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not colors or not root or not humanoid then
		return
	end
	local instances: { Instance } = {}
	local floorY = -(humanoid.HipHeight + root.Size.Y / 2)

	-- Aura en el piso: disco invisible soldado a los pies, con ondas y brasas que suben
	local aura = Instance.new("Part")
	aura.Name = "LavaAura"
	aura.Size = Vector3.new(3.5, 0.1, 3.5)
	aura.Transparency = 1
	aura.CanCollide = false
	aura.CanQuery = false
	aura.CanTouch = false
	aura.Massless = true
	aura.CFrame = root.CFrame * CFrame.new(0, floorY + 0.1, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = aura
	weld.Parent = aura
	local waves = Instance.new("ParticleEmitter")
	emitterProps(waves, {
		Name = "Ondas",
		Texture = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Rate = 1.3,
		Lifetime = NumberRange.new(1.4),
		LockedToPart = true,
		LightEmission = 1,
		LightInfluence = 0,
		Color = ColorSequence.new(colors.mid, colors.dark),
		Size = NumberSequence.new(0.5, 3.2),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	waves.Parent = aura
	local rising = Instance.new("ParticleEmitter")
	emitterProps(rising, {
		Name = "BrasasPiso",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(1, 2.5),
		Rate = 7,
		Lifetime = NumberRange.new(0.8, 1.5),
		LightEmission = 1,
		LightInfluence = 0,
		Acceleration = Vector3.new(0, 2, 0),
		Color = ColorSequence.new(colors.hot, colors.mid),
		Size = NumberSequence.new(0.12, 0),
		Transparency = NumberSequence.new(0, 1),
	})
	rising.Parent = aura
	local glow = Instance.new("PointLight")
	glow.Color = colors.mid
	glow.Range = 9
	glow.Brightness = 1.2
	glow:SetAttribute("GlowBase", 1.2)
	glow.Parent = aura
	addGlow(glow)
	aura.Parent = character
	table.insert(instances, aura)

	-- Estela del dash (se prende solo a alta velocidad)
	local torso = (character:FindFirstChild("UpperTorso") or root) :: BasePart
	local a0 = Instance.new("Attachment")
	a0.Name = "LavaTrailTop"
	a0.Position = Vector3.new(0, 1.2, 0.3)
	a0.Parent = torso
	local a1 = Instance.new("Attachment")
	a1.Name = "LavaTrailBottom"
	a1.Position = Vector3.new(0, -2.6, 0.3)
	a1.Parent = torso
	local trail = Instance.new("Trail")
	trail.Name = "LavaTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.28
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors.hot),
		ColorSequenceKeypoint.new(0.4, colors.mid),
		ColorSequenceKeypoint.new(1, colors.dark),
	})
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Enabled = false
	trail.Parent = torso
	table.insert(instances, a0)
	table.insert(instances, a1)
	table.insert(instances, trail)

	local flames = Instance.new("ParticleEmitter")
	emitterProps(flames, {
		Name = "LavaDashFlames",
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 0,
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(40, 40),
		LightEmission = 1,
		LightInfluence = 0,
		Color = ColorSequence.new(colors.hot, colors.dark),
		Size = NumberSequence.new(1.2, 0),
		Transparency = NumberSequence.new(0.2, 1),
		Rotation = NumberRange.new(0, 360),
	})
	flames.Parent = torso
	table.insert(instances, flames)

	tracked[character] = {
		character = character,
		skin = skin,
		lastStep = 0,
		foot = 0,
		instances = instances,
		trail = trail,
		burst = flames,
		dashing = false,
	}
	if burst then
		equipBurst(root, colors)
	end
end

local function refresh(character: Model, burst: boolean)
	local id = character:GetAttribute("CrateLook")
	if type(id) == "string" and colorsOf(id) then
		local tr = tracked[character]
		if not tr or tr.skin ~= id then
			-- espera a que estén las piezas del avatar
			character:WaitForChild("HumanoidRootPart", 5)
			startTracking(character, id, burst)
		end
	else
		stopTracking(character)
	end
end

local function watchCharacter(character: Model)
	task.spawn(refresh, character, false)
	character:GetAttributeChangedSignal("CrateLook"):Connect(function()
		refresh(character, true)
	end)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(Workspace) then
			stopTracking(character)
		end
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

local function updateMovement(now: number)
	local camPos = camera.CFrame.Position
	for character, tr in tracked do
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		if (root.Position - camPos).Magnitude > FAR then
			continue
		end
		local colors = colorsOf(tr.skin) :: Colors
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air

		-- Dash: estela + llamarada al arrancar
		local dashing = speed > DASH_SPEED
		if tr.trail then
			tr.trail.Enabled = dashing
		end
		if dashing and not tr.dashing and tr.burst then
			tr.burst:Emit(18)
		end
		tr.dashing = dashing

		-- Pisadas
		if grounded and speed > 4 and now - tr.lastStep >= STEP_EVERY then
			tr.lastStep = now
			tr.foot = 1 - tr.foot
			local foot = character:FindFirstChild(if tr.foot == 0 then "LeftFoot" else "RightFoot") :: BasePart?
			if foot then
				footprint(character, foot, colors)
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	updateGlows(t)
	updateSways(dt)
	updateMovement(t)
end)
