-- HeldWeapon (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > HeldWeapon
-- Armas especiales en tercera persona (las que tienen Prize en Shared/Weapons.lua y un modelo en
-- ReplicatedStorage > WeaponModels > <Id>): cada cliente dibuja el arma en la mano de cada
-- jugador que la tenga equipada (también en el lobby) y anima su cuerpo al atacar, al estilo
-- anime exagerado. Es solo visual: el daño lo calcula el servidor.
--
--   · El arma: copia del modelo, más chica (LENGTH), agarrada por la empuñadura, en guardia baja
--     (hoja hacia adelante y abajo, filo hacia el piso). Se mueve con la mano cada cuadro.
--   · Estela: un Trail con la textura del tajo del estilo, prendido solo mientras corta.
--   · Cuerpo entero: en cada golpe (Remotes.MeleeSwing) suma giros y corrimientos a las
--     articulaciones (AnimationConstraint/Motor6D .Transform, después de las animaciones
--     normales): cadera, cintura, los dos brazos y las dos piernas. Combo de 3 (SwingCombo):
--       1. se agacha girado y se lanza en estocada diagonal (el otro brazo tirado para atrás)
--       2. tajo de vuelta subiendo, casi saltando
--       3. remate: se agacha, salta con la hoja arriba (a dos manos) y cae con un tajo vertical
--     Torbellino: salto chico y vuelta completa con los brazos abiertos.
--     Carga larga, golpe casi instantáneo y pose congelada (los tiempos están en SwingCombo).
--   · Cámara (solo tus golpes, en primera y tercera persona): sacudón e inclinación siguiendo el
--     tajo; en el remate y el Torbellino, un "impact frame" (destello en blanco y negro).
--     Se apaga con Config.Effects.ScreenShake = 0.
--   · Tu personaje: en primera persona no se dibuja el arma (ya la ves en pantalla, WeaponFx).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local FxStyles = require(Shared:WaitForChild("FxStyles"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local Config = require(Shared:WaitForChild("Config"))
local SwingCombo = require(script.Parent:WaitForChild("SwingCombo"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MeleeSwing") :: RemoteEvent

local player = Players.LocalPlayer
local low = FxQuality.isLow()

local LENGTH = 4.4 -- largo del arma en tercera persona (studs; un personaje mide ~5)

-- Guardia baja: la hoja sale de la mano hacia adelante y abajo; el filo mira al piso.
-- (En el espacio de la mano: -Z adelante, +Y arriba.)
local BLADE_DOWN = math.rad(35)
local GRIP = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.new(0, -math.cos(BLADE_DOWN), math.sin(BLADE_DOWN)), -- filo (X del modelo)
	Vector3.new(0, -math.sin(BLADE_DOWN), -math.cos(BLADE_DOWN)) -- hoja (Y del modelo)
)

---------------------------------------------------------------------
-- Poses (grados y studs). Brazos y piernas cuelgan: X+ los lleva hacia adelante/arriba.
-- Brazo derecho: Z+ lo abre hacia afuera, Z- lo cruza por delante. Brazo izquierdo al revés.
-- Rodillas: X- dobla. Cintura y cadera (Root): Y+ gira a la derecha, X- inclina hacia
-- adelante; la posición de Root corre el cuerpo entero (Y abajo/arriba, -Z adelante).
---------------------------------------------------------------------

type J = { r: Vector3, p: Vector3? }
type Pose = { [string]: J }

local function j(rx: number, ry: number, rz: number, px: number?, py: number?, pz: number?): J
	return { r = Vector3.new(rx, ry, rz), p = if px then Vector3.new(px, py or 0, pz or 0) else nil }
end

-- Dónde está cada articulación: nombre → (pieza, articulación)
local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RHip = { "RightUpperLeg", "RightHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
}

-- En guardia (sin atacar): solo el brazo de la espada un poco adelante y afuera
local IDLE: Pose = { RShoulder = j(20, 0, 8) }
local BOW_IDLE: Pose = { LShoulder = j(75, 0, -5), LElbow = j(10, 0, 0), RShoulder = j(65, 0, 30), RElbow = j(90, 0, 0) }

local P = {
	-- 1: carga girado a la derecha, agachado, hoja arriba atrás → estocada abajo a la izquierda
	W1 = {
		Root = j(0, 35, 0, 0, -0.55, 0.5), Waist = j(5, 30, 0),
		RShoulder = j(170, 0, 40), RElbow = j(50, 0, 0), LShoulder = j(30, 0, -25), LElbow = j(70, 0, 0),
		RHip = j(30, 0, 0), RKnee = j(-55, 0, 0), LHip = j(-20, 0, 0), LKnee = j(-35, 0, 0),
	},
	H1 = {
		Root = j(-12, -30, 0, 0, -1.0, -2.2), Waist = j(-18, -40, 0),
		RShoulder = j(50, 0, -85), RElbow = j(5, 0, 0), LShoulder = j(-70, 0, -45), LElbow = j(15, 0, 0),
		RHip = j(75, 0, 0), RKnee = j(-75, 0, 0), LHip = j(-50, 0, 0), LKnee = j(-10, 0, 0),
	},
	-- 2: carga abajo a la izquierda → sube arriba a la derecha casi despegando
	W2 = {
		Root = j(-8, -35, 0, 0, -0.9, -1.4), Waist = j(-12, -35, 0),
		RShoulder = j(30, 0, -80), RElbow = j(10, 0, 0), LShoulder = j(-40, 0, -40), LElbow = j(20, 0, 0),
		RHip = j(60, 0, 0), RKnee = j(-70, 0, 0), LHip = j(-40, 0, 0), LKnee = j(-20, 0, 0),
	},
	H2 = {
		Root = j(8, 40, 0, 0, 0.35, -1.6), Waist = j(12, 45, 0),
		RShoulder = j(178, 0, 45), RElbow = j(0, 0, 0), LShoulder = j(-60, 0, -55), LElbow = j(20, 0, 0),
		RHip = j(25, 0, 0), RKnee = j(-15, 0, 0), LHip = j(-35, 0, 0), LKnee = j(-45, 0, 0),
	},
	-- 3: remate: se agacha a dos manos, salta y cae con un tajo vertical
	CROUCH = {
		Root = j(10, 0, 0, 0, -1.2, 0.4), Waist = j(10, 0, 0),
		RShoulder = j(175, 0, 15), RElbow = j(70, 0, 0), LShoulder = j(175, 0, -15), LElbow = j(70, 0, 0),
		RHip = j(80, 0, 0), RKnee = j(-110, 0, 0), LHip = j(70, 0, 0), LKnee = j(-110, 0, 0),
	},
	AIR = {
		Root = j(-10, 0, 0, 0, 3.0, -1.2), Waist = j(5, 0, 0),
		RShoulder = j(185, 0, 10), RElbow = j(30, 0, 0), LShoulder = j(185, 0, -10), LElbow = j(30, 0, 0),
		RHip = j(60, 0, 0), RKnee = j(-90, 0, 0), LHip = j(20, 0, 0), LKnee = j(-60, 0, 0),
	},
	SLAM = {
		Root = j(-28, 0, 0, 0, -1.2, -2.4), Waist = j(-25, 0, 0),
		RShoulder = j(35, 0, -5), RElbow = j(0, 0, 0), LShoulder = j(35, 0, 5), LElbow = j(0, 0, 0),
		RHip = j(85, 0, 0), RKnee = j(-85, 0, 0), LHip = j(-45, 0, 0), LKnee = j(-15, 0, 0),
	},
	-- Torbellino: salto chico, brazos abiertos, vuelta completa
	SPIN_PREP = {
		Root = j(0, 40, 0, 0, 0.6, 0), Waist = j(0, 20, 0),
		RShoulder = j(90, 0, 85), LShoulder = j(90, 0, -85), RHip = j(20, 0, 0), LHip = j(-20, 0, 0),
	},
	SPIN_END = {
		Root = j(0, -360, 0, 0, 0.9, 0), Waist = j(0, -20, 0),
		RShoulder = j(90, 0, 85), LShoulder = j(90, 0, -85), RHip = j(20, 0, 0), LHip = j(-20, 0, 0),
	},
	SPIN_LAND = { Root = j(0, -360, 0) , RShoulder = j(20, 0, 8) },
}

-- La pose final "se sigue moviendo" apenas mientras está congelada (follow-through)
local function drift(pose: Pose, k: number): Pose
	local out = {}
	for name, v in pose do
		out[name] = { r = v.r * (1 + k), p = v.p }
	end
	return out
end

local function ease(t: number): number
	return 1 - (1 - t) ^ 3
end
local function expoOut(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end
local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end
local function linear(t: number): number
	return t
end

type Key = { t: number, pose: Pose, ease: (number) -> number }

local function slashKeys(step: number): { Key }
	local m = SwingCombo.Moves[step]
	if step == 3 then
		return {
			{ t = 0, pose = IDLE, ease = linear },
			{ t = 0.22, pose = P.CROUCH, ease = ease },
			{ t = m.wind, pose = P.AIR, ease = ease },
			{ t = m.strike, pose = P.SLAM, ease = expoOut },
			{ t = m.hold, pose = drift(P.SLAM, 0.06), ease = linear },
			{ t = 1, pose = IDLE, ease = smooth },
		}
	end
	local w, h = if step == 2 then P.W2 else P.W1, if step == 2 then P.H2 else P.H1
	return {
		{ t = 0, pose = IDLE, ease = linear },
		{ t = m.wind, pose = w, ease = ease },
		{ t = m.strike, pose = h, ease = expoOut },
		{ t = m.hold, pose = drift(h, 0.06), ease = linear },
		{ t = 1, pose = IDLE, ease = smooth },
	}
end

local SPIN_KEYS: { Key } = {
	{ t = 0, pose = IDLE, ease = linear },
	{ t = 0.15, pose = P.SPIN_PREP, ease = ease },
	{ t = 0.85, pose = P.SPIN_END, ease = smooth },
	{ t = 1, pose = P.SPIN_LAND, ease = smooth },
}

local BOW_KEYS: { Key } = {
	{ t = 0, pose = BOW_IDLE, ease = linear },
	{ t = 0.18, pose = { LShoulder = j(68, 0, -5), LElbow = j(18, 0, 0), RShoulder = j(65, 0, 55), RElbow = j(110, 0, 0) }, ease = ease },
	{ t = 1, pose = BOW_IDLE, ease = smooth },
}

-- Pose en el instante t (0..1): interpola entre las dos claves que lo rodean
local function sample(keys: { Key }, t: number): Pose
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			local f = if b.t > a.t then b.ease((t - a.t) / (b.t - a.t)) else 1
			local out: Pose = {}
			for name in JOINTS do
				local va, vb = a.pose[name], b.pose[name]
				if va or vb then
					local ra = if va then va.r else Vector3.zero
					local rb = if vb then vb.r else Vector3.zero
					local pa = if va and va.p then va.p else Vector3.zero
					local pb = if vb and vb.p then vb.p else Vector3.zero
					out[name] = { r = ra:Lerp(rb, f), p = pa:Lerp(pb, f) }
				end
			end
			return out
		end
	end
	return keys[#keys].pose
end

---------------------------------------------------------------------
-- Estado por jugador
---------------------------------------------------------------------

type Swing = { keys: { Key }, t0: number, dur: number, trailFrom: number, trailTo: number }
type Held = {
	id: string,
	character: Model,
	model: Model,
	parts: { BasePart },
	offsets: { CFrame }, -- de cada pieza respecto del punto de agarre de la mano
	trail: Trail?,
	swing: Swing?,
	joints: { [string]: Instance },
}
local held: { [Player]: Held } = {}

local function findJoints(character: Model): { [string]: Instance }
	local out = {}
	for name, where in JOINTS do
		local part = character:FindFirstChild(where[1])
		local jt = part and part:FindFirstChild(where[2])
		if jt and (jt:IsA("AnimationConstraint") or jt:IsA("Motor6D")) then
			out[name] = jt
		end
	end
	return out
end

local function specialId(p: Player): string?
	local id = p:GetAttribute("Weapon")
	local def = type(id) == "string" and Weapons.ById[id] or nil
	if not def or not def.Prize then
		return nil
	end
	if (id == "CelestialBow" or id == "VoidBow") then return id end
	if Weapons.baseOf(id) == "Fists" then return nil end -- los guanteletes van en las dos manos (Client/GauntletModels)
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	if not folder or not folder:FindFirstChild(def.Id) then
		return nil
	end
	return def.Id
end

---------------------------------------------------------------------
-- Armado del arma en la mano
---------------------------------------------------------------------

local function destroy(p: Player)
	local h = held[p]
	if h then
		h.model:Destroy()
		held[p] = nil
	end
end

local function build(p: Player, id: string, character: Model): Held?
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local template = folder and folder:FindFirstChild(id)
	if id ~= "CelestialBow" and id ~= "VoidBow" and (not template or not template:IsA("Model")) then
		return nil
	end
	local model = if template and template:IsA("Model") then template:Clone()
		else require(script.Parent:WaitForChild("CelestialBowModel")).build(id)
	model.Name = "HeldWeapon"
	model.PrimaryPart = nil -- con PrimaryPart, Roblox ignora WorldPivot
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	local length = if Weapons.baseOf(id) == "Bow" then 3.4 else LENGTH
	if longest > 0.01 then
		pcall(function()
			model:ScaleTo(model:GetScale() * length / longest)
		end)
	end
	-- Punto de agarre: en la empuñadura, un poco hacia la guarda
	local pivot = model:GetPivot()
	local handle = model:FindFirstChild("Handle", true) :: BasePart?
	local guard = model:FindFirstChild("Guard", true) :: BasePart?
	local gripPos: Vector3
	if handle then
		gripPos = handle.Position
		if guard then
			gripPos = gripPos:Lerp(guard.Position, 0.35)
		end
	else
		gripPos = pivot.Position + pivot.UpVector * LENGTH * 0.15
	end
	-- Marco del agarre en el modelo: mismo giro que el modelo, centrado en el agarre
	local gripFrame = pivot.Rotation + gripPos
	local parts, offsets = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local grip = if Weapons.baseOf(id) == "Bow" then CFrame.new() else GRIP
			table.insert(offsets, grip * gripFrame:ToObjectSpace(d.CFrame))
		end
	end
	-- Estela entre la base y la punta de la hoja (de la pieza invisible BladeAura si existe)
	local trail: Trail? = nil
	local blade = model:FindFirstChild("BladeAura", true) :: BasePart?
	local style = FxStyles.get(Weapons.ById[id].Fx)
	if blade and style then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, -blade.Size.Y / 2 + 0.2, 0)
		a0.Parent = blade
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, blade.Size.Y / 2, 0)
		a1.Parent = blade
		-- Cinta sólida (sin textura: con la del tajo quedaban cuadros planos): blanca en la hoja,
		-- color del estilo hacia la cola, que se afina y se desvanece
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.Core or Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.35, style.Light),
			ColorSequenceKeypoint.new(1, style.Deep or style.Light),
		})
		t.Lifetime = 0.14
		t.MinLength = 0.02
		t.LightEmission = 0.8
		t.LightInfluence = 0
		t.FaceCamera = false
		t.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		t.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		t.Enabled = false
		t.Parent = blade
		trail = t
	end
	model.Parent = character
	return {
		id = id,
		character = character,
		model = model,
		parts = parts,
		offsets = offsets,
		trail = trail,
		swing = nil,
		joints = findJoints(character),
	}
end

---------------------------------------------------------------------
-- Cámara (solo tus golpes)
---------------------------------------------------------------------

local shake = 0 -- studs, se apaga solo
local roll = 0 -- grados, vuelve a 0 solo
local rollTarget = 0
local impact: ColorCorrectionEffect? = nil

local function kick(amount: number, rollDeg: number)
	local k = Config.Effects.ScreenShake or 1
	shake = math.max(shake, amount * k)
	rollTarget = rollDeg * k
end

-- "Impact frame": dos cuadros en blanco y negro con mucho contraste, después el tinte del
-- estilo del arma (Flash en FxStyles)
local function flashOf(id: string): Color3?
	local style = FxStyles.get(Weapons.ById[id] and Weapons.ById[id].Fx)
	return style and style.Flash
end

local function impactFrame(tint: Color3?)
	if low or (Config.Effects.ScreenShake or 1) <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not impact or impact.Parent ~= camera then
		impact = Instance.new("ColorCorrectionEffect")
		impact.Name = "AnimeImpact"
		impact.Parent = camera
	end
	local cc = impact :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Saturation = -1
	cc.Contrast = 1.6
	cc.Brightness = 0.05
	cc.TintColor = Color3.new(1, 1, 1)
	task.delay(0.06, function()
		cc.Saturation = -0.3
		cc.Contrast = 0.4
		cc.Brightness = 0.2
		cc.TintColor = tint or Color3.fromRGB(180, 225, 255)
	end)
	task.delay(0.13, function()
		cc.Enabled = false
	end)
end

RunService:BindToRenderStep("AnimeSwingCamera", Enum.RenderPriority.Camera.Value + 5, function(dt)
	if shake < 0.003 and math.abs(roll) < 0.05 and rollTarget == 0 then
		return
	end
	-- La inclinación entra rápido y vuelve despacio
	roll += (rollTarget - roll) * math.min(1, dt * 30)
	rollTarget *= math.exp(-dt * 6)
	if math.abs(rollTarget) < 0.05 then
		rollTarget = 0
	end
	local camera = workspace.CurrentCamera
	local offset = Vector3.new((math.random() - 0.5) * 2 * shake, (math.random() - 0.5) * 2 * shake, 0)
	-- Solo se gira sobre el eje de la mirada y se corre: la cámara de Roblox no lo acumula
	camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(roll))
	shake *= math.exp(-dt * 12)
end)

---------------------------------------------------------------------
-- Cada cuadro
---------------------------------------------------------------------

-- Después de las animaciones de Roblox: suma los giros a las articulaciones
RunService.Stepped:Connect(function()
	local now = os.clock()
	for p, h in held do
		if not h.character.Parent then
			continue
		end
		local isBow = Weapons.baseOf(h.id) == "Bow"
		local pose = if isBow then (if p:GetAttribute("InMatch") == true then BOW_IDLE else {}) else IDLE
		local trailOn = false
		local s = h.swing
		if s and (not isBow or p:GetAttribute("InMatch") == true) then
			-- Para revisar poses: workspace.AnimeSlowMo = 5 hace todo 5 veces más lento
			local slow = workspace:GetAttribute("AnimeSlowMo")
			local t = (now - s.t0) / (s.dur * (if type(slow) == "number" and slow > 0 then slow else 1))
			if t >= 1 then
				h.swing = nil
			else
				pose = sample(s.keys, t)
				trailOn = t > s.trailFrom and t < s.trailTo
			end
		end
		for name, v in pose do
			local jt = h.joints[name]
			if jt and jt.Parent then
				local add = CFrame.Angles(math.rad(v.r.X), math.rad(v.r.Y), math.rad(v.r.Z))
				if v.p then
					add = CFrame.new(v.p) * add
				end
				(jt :: any).Transform = (jt :: any).Transform * add
			end
		end
		if h.trail then
			h.trail.Enabled = trailOn and h.model.Parent ~= nil
		end
	end
end)

-- El arma sigue a la mano (después de que se movió el cuerpo)
RunService.RenderStepped:Connect(function()
	for p, h in held do
		local isBow = Weapons.baseOf(h.id) == "Bow"
		local side = if isBow then "Left" else "Right"
		local hand = h.character:FindFirstChild(side .. "Hand") or h.character:FindFirstChild(side .. " Arm")
		local grip = hand and hand:FindFirstChild(side .. "GripAttachment") :: Attachment?
		if not hand then
			continue
		end
		-- En primera persona tu propia arma no se dibuja (la ves en pantalla)
		local hide = p == player and player:GetAttribute("InMatch") == true
			and player:GetAttribute("CameraView") == "FirstPerson"
		if hide then
			if h.model.Parent then
				h.model.Parent = nil
			end
			continue
		elseif not h.model.Parent then
			h.model.Parent = h.character
		end
		-- Posición del agarre de Roblox, pero con el giro de la mano (el del agarre mira hacia abajo)
		local gripPosition = if grip then grip.WorldPosition else (hand :: BasePart).Position
		local base = (hand :: BasePart).CFrame.Rotation + gripPosition
		if isBow then
			-- La muñeca gira con las animaciones del avatar: no debe acostar el arco.
			-- Mantener su eje vertical y orientar la curva hacia donde mira el personaje.
			local root = h.character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local forward = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
			forward = Vector3.new(forward.X, 0, forward.Z)
			if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
			local frame = CFrame.lookAt(gripPosition, gripPosition + forward, Vector3.yAxis)
			-- Separar de los guantes voluminosos y mostrar la curva en vez de verla de canto.
			local at = gripPosition - frame.RightVector * 0.18 + forward.Unit * 0.22
			base = CFrame.lookAt(at, at + forward, Vector3.yAxis) * CFrame.Angles(0, math.rad(-30), 0)
		end
		local cfs = table.create(#h.parts)
		for i, off in h.offsets do
			cfs[i] = base * off
		end
		workspace:BulkMoveTo(h.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- Arma y personaje de cada jugador (cada medio segundo alcanza)
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local id = specialId(p)
			local character = p.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local h = held[p]
			if not id or not character or not humanoid or humanoid.Health <= 0 then
				destroy(p)
			elseif not h or h.id ~= id or h.character ~= character then
				destroy(p)
				local ok, result = pcall(build, p, id, character)
				if ok and result then
					held[p] = result
				elseif not ok then
					warn("[HeldWeapon]", result)
				end
			end
		end
		task.wait(0.5)
	end
end)

Players.PlayerRemoving:Connect(destroy)

-- El arco usa el aviso de disparo, sin pasar por las poses de espada.
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ProjectileFired").OnClientEvent:Connect(function(_id, _origin, _dir, _speed, _life, ownerId, style)
	local owner = Players:GetPlayerByUserId(ownerId)
	local h = owner and held[owner]
	if not h or Weapons.baseOf(h.id) ~= "Bow" or (style and style.wave) then return end
	h.swing = { keys = BOW_KEYS, t0 = os.clock(), dur = 0.4, trailFrom = 0, trailTo = 0.2 }
end)

-- Golpes: arrancar la animación del cuerpo de ese jugador (y la cámara si es tuyo)
remote.OnClientEvent:Connect(function(userId, _origin, _dir, _range, arc, weaponId)
	if type(userId) ~= "number" then
		return
	end
	local p = Players:GetPlayerByUserId(userId)
	local h = p and held[p]
	-- Solo golpes de esa arma (el Juicio y otros poderes también llegan por acá)
	if not h or weaponId ~= h.id then
		return
	end
	local mine = p == player
	if arc == 360 then
		local dur = SwingCombo.spinDuration(userId)
		h.swing = { keys = SPIN_KEYS, t0 = os.clock(), dur = dur, trailFrom = 0.12, trailTo = 0.88 }
		if mine then
			kick(0.3, 0)
			task.delay(dur * 0.15, impactFrame, flashOf(h.id))
		end
		return
	end
	local step = SwingCombo.step(userId)
	local m = SwingCombo.Moves[step]
	local dur = SwingCombo.duration(userId, step)
	h.swing = { keys = slashKeys(step), t0 = os.clock(), dur = dur, trailFrom = m.wind - 0.04, trailTo = m.hold }
	if mine then
		-- El sacudón y la inclinación llegan con el golpe, no con la carga
		task.delay(dur * m.wind, function()
			if step == 3 then
				kick(0.55, 0)
				impactFrame(flashOf(h.id))
			else
				kick(0.2, 9 * SwingCombo.side(step))
			end
		end)
	end
end)
