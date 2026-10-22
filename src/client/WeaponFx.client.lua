-- WeaponFx (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > WeaponFx
-- Lo que ves de tu arma (todo local, solo visual):
--   (se prende y apaga con Config.Effects.FirstPersonWeapon)
--
--   · Arma en primera persona, estilo shooter de Roblox, con balanceo al caminar y animación
--     en cada ataque. Espada y guantes: las manos en bloque de tu personaje (del color de tus
--     brazos) entran desde las esquinas de abajo y sostienen el ítem.
--       arco → solo el arco (sin manos), apuntando al frente como si fueras a disparar: un poco
--              a la izquierda y abajo, con la flecha hacia la mira; se tensa hacia vos, sale en
--              cada disparo y se carga otra.
--       espada → abajo a la derecha; tajo de lado a lado (vuelta completa en el Torbellino).
--       puños → un guante a cada lado, en guardia; golpes rectos alternados.
--     Modelos: ReplicatedStorage > WeaponModels > Bow / Sword / Fists (un guante; se usa en los
--     dos lados). Puede ser un Model o una sola MeshPart. Si no están, se arman con piezas. Se escalan y orientan solos; ajustes
--     opcionales en cada modelo: atributo "Rotation" (Vector3, grados) y "Flip" (bool: espada
--     al revés / arco con la curva para el otro lado).
--   · Chispas donde pegás, del color del arma.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local Config = require(Shared:WaitForChild("Config"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local SwingCombo = require(script.Parent:WaitForChild("SwingCombo"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local meleeSwing = remotes:WaitForChild("MeleeSwing") :: RemoteEvent
local projectileFired = remotes:WaitForChild("ProjectileFired") :: RemoteEvent
local combatText = remotes:WaitForChild("CombatText") :: RemoteEvent

local player = Players.LocalPlayer
local low = FxQuality.isLow()

-- Lado más largo de cada arma en pantalla (studs)
local SIZE = { Bow = 1.6, Sword = 2.2, Fists = 0.7 }
-- Manos/antebrazos en bloque (como los brazos de Roblox): grosor y largo visible (studs).
-- Salen de los codos, fuera de cámara abajo a los costados.
local ARM_THICK = 0.42
local ARM_LENGTH = 1.7
local ELBOW_R = Vector3.new(1.25, -1.75, -0.8)
local ELBOW_L = Vector3.new(-1.25, -1.75, -0.8)
local SPARK = {
	Bow = Color3.fromRGB(255, 225, 120),
	Sword = Color3.fromRGB(210, 235, 255),
	Fists = Color3.fromRGB(255, 160, 80),
}
local BOW_PULL = 0.4 -- cuánto se tensa la flecha hacia vos (studs)

---------------------------------------------------------------------
-- Modelos
---------------------------------------------------------------------

local function plainPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Modelos de respaldo armados con piezas (si no están en ReplicatedStorage > WeaponModels)
local function fallback(weapon: string): Model
	local m = Instance.new("Model")
	if weapon == "Sword" then
		plainPart(m, Vector3.new(0.25, 2.4, 0.08), CFrame.new(0, 0.9, 0), Color3.fromRGB(210, 215, 225), Enum.Material.Metal)
		plainPart(m, Vector3.new(0.9, 0.12, 0.2), CFrame.new(0, -0.35, 0), Color3.fromRGB(190, 150, 60), Enum.Material.Metal)
		plainPart(m, Vector3.new(0.14, 0.6, 0.14), CFrame.new(0, -0.7, 0), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	elseif weapon == "Bow" then
		-- Curva bien marcada hacia -Z (el centro es el más adelantado) y cuerda recta atrás
		for i = -3, 3 do
			local ang = math.rad(i * 15)
			plainPart(m, Vector3.new(0.12, 0.45, 0.12), CFrame.new(0, math.sin(ang) * 1.4, -math.cos(ang) * 0.7) * CFrame.Angles(ang, 0, 0), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
		end
		plainPart(m, Vector3.new(0.03, 2.3, 0.03), CFrame.new(0, 0, -0.3), Color3.fromRGB(235, 230, 215))
	else
		plainPart(m, Vector3.new(0.5, 0.5, 0.7), CFrame.new(), Color3.fromRGB(120, 60, 40), Enum.Material.Fabric)
	end
	return m
end

-- Ejes del modelo (en el espacio de su caja) ordenados del más largo al más corto
local function sortedAxes(size: Vector3): { { v: Vector3, s: number } }
	local axes = { { v = Vector3.xAxis, s = size.X }, { v = Vector3.yAxis, s = size.Y }, { v = Vector3.zAxis, s = size.Z } }
	table.sort(axes, function(x, y)
		return x.s > y.s
	end)
	return axes
end

-- Rotación que lleva a1 (lado más largo) a `primary` y a2 (segundo) a `secondary`
local function alignAxes(a1: Vector3, a2: Vector3, primary: Vector3, secondary: Vector3): CFrame
	local from = CFrame.fromMatrix(Vector3.zero, a1, a2, a1:Cross(a2))
	local to = CFrame.fromMatrix(Vector3.zero, primary, secondary, primary:Cross(secondary))
	return to * from:Inverse()
end

-- Arco: ¿para qué lado del segundo eje está la curva (el centro del arco)? Las piezas del medio
-- del arco quedan corridas hacia la panza; la cuerda, del otro lado. +1 o -1.
local function bulgeSign(model: Model, box: CFrame, a1: Vector3, a2: Vector3, length: number): number
	local mid, all, midW, allW = 0, 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = box:PointToObjectSpace(d.Position)
			local w = d.Size.X * d.Size.Y * d.Size.Z
			all += p:Dot(a2) * w
			allW += w
			if math.abs(p:Dot(a1)) < length * 0.2 then
				mid += p:Dot(a2) * w
				midW += w
			end
		end
	end
	if midW <= 0 or allW <= 0 then
		return 1
	end
	return if mid / midW >= all / allW then 1 else -1
end

-- Cómo se sostiene cada arma (en el marco del arma: -Z adelante, +Y arriba)
--   primary/secondary: hacia dónde van el lado más largo y el segundo
--   grip: dónde se agarra a lo largo del lado largo (0 = centro, -0.4 = cerca de una punta)
-- Arco: el segundo eje es la panza del arco; va hacia adelante (apuntando) y la cuerda queda
-- del lado de la cámara. BOW_TURN gira un poco el modelo sobre su eje para que se vea la curva.
local BOW_BELLY = -Vector3.zAxis
local BOW_TURN = math.rad(18)
local BOW_AIM = Vector3.new(0, 0, -40) -- la flecha apunta a este punto (el centro de la mira, lejos)
local HOLD = {
	Bow = { primary = Vector3.yAxis, secondary = BOW_BELLY, grip = 0 },
	Sword = { primary = Vector3.yAxis, secondary = Vector3.xAxis, grip = -0.38 },
	Fists = { primary = -Vector3.zAxis, secondary = Vector3.yAxis, grip = 0 },
}

type Weapon = { model: Model, hold: CFrame, length: number, depth: number }

local function prepare(model: Model, weapon: string): Weapon
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
		end
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0.01 then
		pcall(function()
			model:ScaleTo(model:GetScale() * (SIZE[weapon] or 1) / longest)
		end)
	end
	local box, scaled = model:GetBoundingBox()
	-- Con PrimaryPart, Roblox usa el pivote de esa pieza e ignora WorldPivot: el arma quedaría
	-- corrida de la mano. Sin ella, el pivote es el centro de la caja.
	model.PrimaryPart = nil
	model.WorldPivot = box -- girar desde el centro de la caja
	local h = HOLD[weapon]
	local axes = sortedAxes(scaled)
	local a1, a2 = axes[1].v, axes[2].v
	local length, depth = axes[1].s, axes[2].s
	if weapon == "Bow" then
		a2 *= bulgeSign(model, box, a1, a2, length)
	end
	local align = alignAxes(a1, a2, h.primary, h.secondary)
	-- Se agarra en "grip": corremos el centro del modelo a lo largo del lado largo
	local shift = h.primary * (-h.grip * length)
	local flipped = model:GetAttribute("Flip") == true
	local flip = CFrame.new()
	if flipped then
		flip = if weapon == "Bow" then CFrame.fromAxisAngle(h.primary, math.pi) else CFrame.Angles(0, 0, math.pi)
	end
	local custom = model:GetAttribute("Rotation")
	local extra = if typeof(custom) == "Vector3" then CFrame.Angles(math.rad(custom.X), math.rad(custom.Y), math.rad(custom.Z)) else CFrame.new()
	local turn = if weapon == "Bow" then CFrame.Angles(0, BOW_TURN, 0) else CFrame.new()
	return { model = model, hold = CFrame.new(shift) * turn * flip * extra * align, length = length, depth = depth }
end

-- weapon = arma base (cómo se sostiene y anima) · id = el arma exacta (especiales: modelo propio
-- en WeaponModels > <id>, o el de la base con la hoja teñida de su Tint)
local function build(weapon: string, id: string?): Weapon
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local own = folder and id and folder:FindFirstChild(id)
	local template = own or (folder and folder:FindFirstChild(weapon))
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	elseif template and template:IsA("BasePart") then
		model = Instance.new("Model")
		local part = template:Clone()
		part.Parent = model
	else
		model = fallback(weapon)
	end
	model.Name = "ViewModel"
	local def = id and Weapons.ById[id]
	if def and def.Tint and not own then
		-- La pieza más grande es la hoja: del color del arma especial, brillando
		local blade, size = nil, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Size.X * d.Size.Y * d.Size.Z > size then
				blade, size = d, d.Size.X * d.Size.Y * d.Size.Z
			end
		end
		if blade then
			blade.Color = def.Tint
			blade.Material = Enum.Material.Neon
			if blade:IsA("MeshPart") then
				blade.TextureID = ""
			end
			for _, c in blade:GetChildren() do
				if c:IsA("SpecialMesh") then
					c.TextureId = ""
				elseif c:IsA("SurfaceAppearance") or c:IsA("Decal") or c:IsA("Texture") then
					c:Destroy()
				end
			end
		end
	end
	return prepare(model, weapon)
end

---------------------------------------------------------------------
-- Arma en primera persona
---------------------------------------------------------------------

type Rig = {
	weapon: string, -- base: "Bow" | "Sword" | "Fists"
	id: string, -- el arma exacta (especiales: "FrostKatana")
	items: { Weapon }, -- arma (o un guante por lado)
	arrow: Model?, -- flecha cargada en el arco
	arrowParts: { { part: BasePart, offset: CFrame } },
	armR: Part,
	armL: Part,
	folder: Model,
}
local rig: Rig? = nil
local anim = { t = 1, kind = "", side = 1, dur = 0.2, step = 1 }
local bobClock = 0 -- reloj del balanceo (se detiene en la pausa de impacto)

-- Flecha de verdad para la primera persona: astil redondo, punta de metal con 4 filos,
-- 3 plumas y culatín. Largo fijo; se arma mirando a -Z con la cola (culatín) en el origen.
local ARROW_LEN = 1.35
local ARROW_SHAFT = Color3.fromRGB(205, 165, 110)
local ARROW_FEATHER = Color3.fromRGB(255, 205, 70) -- dorado, como tus flechas en vuelo
local ARROW_METAL = Color3.fromRGB(200, 205, 215)

local function buildArrow(parent: Instance): (Model, { { part: BasePart, offset: CFrame } })
	local m = Instance.new("Model")
	m.Name = "NockedArrow"
	local list = {}
	local function add(p: BasePart, offset: CFrame)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
		table.insert(list, { part = p, offset = offset })
	end
	-- Astil: cilindro (su eje es X; lo giramos para que vaya a lo largo de Z)
	local shaft = Instance.new("Part")
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Size = Vector3.new(ARROW_LEN - 0.2, 0.035, 0.035)
	shaft.Material = Enum.Material.Wood
	shaft.Color = ARROW_SHAFT
	add(shaft, CFrame.new(0, 0, -(ARROW_LEN - 0.2) / 2) * CFrame.Angles(0, math.rad(90), 0))
	-- Punta: pares de cuñas espejadas forman un triángulo que apunta a -Z; dos pares en cruz
	local headLen, headHalf = 0.22, 0.06
	local headBack = -(ARROW_LEN - 0.2) -- donde termina el astil
	for _, roll in { 0, 90 } do
		for _, side in { 1, -1 } do
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(0.012, headHalf, headLen)
			w.Material = Enum.Material.Metal
			w.Color = ARROW_METAL
			-- La cuña es alta atrás (+Z) y baja adelante (-Z): la de abajo va dada vuelta
			local flip = if side > 0 then CFrame.new() else CFrame.Angles(0, 0, math.pi)
			add(w, CFrame.new(0, 0, headBack - headLen / 2) * CFrame.Angles(0, 0, math.rad(roll)) * flip * CFrame.new(0, headHalf / 2, 0))
		end
	end
	-- Plumas: 3 cuñas finitas alrededor de la cola, más altas atrás
	for i = 0, 2 do
		local v = Instance.new("WedgePart")
		v.Size = Vector3.new(0.008, 0.07, 0.3)
		v.Material = Enum.Material.SmoothPlastic
		v.Color = ARROW_FEATHER
		add(v, CFrame.new(0, 0, -0.22) * CFrame.Angles(0, 0, math.rad(i * 120)) * CFrame.new(0, 0.052, 0))
	end
	-- Culatín (la muesca de la cuerda)
	local nock = Instance.new("Part")
	nock.Size = Vector3.new(0.045, 0.045, 0.05)
	nock.Material = Enum.Material.SmoothPlastic
	nock.Color = Color3.fromRGB(60, 45, 35)
	add(nock, CFrame.new(0, 0, -0.025))
	m.Parent = parent
	return m, list
end

-- Color de los brazos del personaje (BodyColors o la pieza del brazo)
local function armColor(side: string): Color3
	local character = player.Character
	local colors = character and character:FindFirstChildOfClass("BodyColors")
	if colors then
		return if side == "Right" then colors.RightArmColor3 else colors.LeftArmColor3
	end
	local part = character and (character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm"))
	return if part and part:IsA("BasePart") then part.Color else Color3.fromRGB(234, 184, 146)
end

local function clear()
	if rig then
		rig.folder:Destroy()
		rig = nil
	end
end

local function ensure(weapon: string, id: string)
	if rig and rig.id == id then
		return
	end
	clear()
	local folder = Instance.new("Model")
	folder.Name = "FirstPersonWeapon"
	local items = { build(weapon, id) }
	if weapon == "Fists" then
		table.insert(items, build(weapon))
	end
	for _, it in items do
		it.model.Parent = folder
		if weapon == "Fists" then
			-- Sin guante de boxeo: se ven las manos del personaje (los brazos de tu color)
			for _, d in it.model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 1
				elseif d:IsA("Decal") or d:IsA("Texture") then
					d.Transparency = 1
				end
			end
		end
	end
	local arrow, arrowParts = nil, {}
	if weapon == "Bow" then
		arrow, arrowParts = buildArrow(folder)
	end
	rig = {
		weapon = weapon,
		id = id,
		items = items,
		arrow = arrow,
		arrowParts = arrowParts,
		armR = plainPart(folder, Vector3.new(ARM_THICK, ARM_THICK, ARM_LENGTH), CFrame.new(), armColor("Right")),
		armL = plainPart(folder, Vector3.new(ARM_THICK, ARM_THICK, ARM_LENGTH), CFrame.new(), armColor("Left")),
		folder = folder,
	}
	folder.Parent = workspace.CurrentCamera
end

local function play(kind: string, dur: number)
	anim.kind = kind
	anim.dur = dur
	anim.t = 0
	anim.side = -anim.side
end

local function visible(): boolean
	if Config.Effects.FirstPersonWeapon ~= true then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("InMatch") == true
		and player:GetAttribute("CameraView") == "FirstPerson"
		and humanoid ~= nil
		and humanoid.Health > 0
		and player:GetAttribute("LifeState") ~= "DOWNED"
end

local function ease(t: number): number
	return 1 - (1 - t) ^ 3
end

-- Combo anime exagerado de las armas con estilo (Fx): por cada paso, dónde se carga el golpe
-- (wind, bien atrás), dónde termina (hit) y hasta dónde se sigue moviendo apenas mientras queda
-- congelado (over), en el espacio de la cámara. Los tiempos de cada fase son los de SwingCombo
-- (los mismos que el cuerpo en tercera persona y el tajo de AnimeFx).
local ANIME = {
	{ -- 1: de arriba a la derecha hacia abajo a la izquierda
		wind = CFrame.new(1.1, 0.35, -1.0) * CFrame.Angles(math.rad(35), math.rad(-25), math.rad(-75)),
		hit = CFrame.new(-0.85, -1.05, -1.6) * CFrame.Angles(math.rad(-95), math.rad(15), math.rad(75)),
		over = CFrame.new(-0.95, -1.15, -1.55) * CFrame.Angles(math.rad(-100), math.rad(18), math.rad(80)),
	},
	{ -- 2: de vuelta, de abajo a la izquierda hacia arriba a la derecha
		wind = CFrame.new(-0.75, -1.1, -1.2) * CFrame.Angles(math.rad(-90), math.rad(15), math.rad(80)),
		hit = CFrame.new(1.1, 0.4, -1.5) * CFrame.Angles(math.rad(30), math.rad(-15), math.rad(-80)),
		over = CFrame.new(1.2, 0.5, -1.45) * CFrame.Angles(math.rad(35), math.rad(-18), math.rad(-85)),
	},
	{ -- 3: remate: la hoja bien arriba por detrás de la cabeza y abajo de un golpe
		wind = CFrame.new(0.35, 0.75, -0.9) * CFrame.Angles(math.rad(55), 0, math.rad(-10)),
		hit = CFrame.new(0.05, -1.1, -1.7) * CFrame.Angles(math.rad(-110), 0, 0),
		over = CFrame.new(0.05, -1.2, -1.65) * CFrame.Angles(math.rad(-115), 0, 0),
	},
}

local function expoOut(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end

local function animePose(idle: CFrame, step: number, t: number): CFrame
	local k = ANIME[step] or ANIME[1]
	local m = SwingCombo.Moves[step] or SwingCombo.Moves[1]
	if t < m.wind then
		return idle:Lerp(k.wind, ease(t / m.wind))
	elseif t < m.strike then
		return k.wind:Lerp(k.hit, expoOut((t - m.wind) / (m.strike - m.wind)))
	elseif t < m.hold then
		-- congelado, arrastrándose apenas hacia "over", con un temblor de impacto que se apaga
		local f = (t - m.strike) / (m.hold - m.strike)
		local shake = math.sin(f * 45) * 0.02 * (1 - f)
		return k.hit:Lerp(k.over, ease(f)) * CFrame.new(shake, -shake, 0)
	end
	local f = (t - m.hold) / (1 - m.hold)
	return k.over:Lerp(idle, f * f * (3 - 2 * f))
end

-- Poses (en el espacio de la cámara). Devuelve dónde va el arma (o el guante izquierdo y el
-- derecho) y, para el arco, cuánto está tensada la flecha (0..1) y si hay flecha cargada.
local function poses(weapon: string, t: number, bob: Vector3): (CFrame, CFrame, number, boolean)
	local active = t < 1
	if weapon == "Bow" then
		-- Apuntando: un poco a la izquierda y abajo, mirando a la mira, punta de arriba apenas a la derecha
		local pos = Vector3.new(-0.24, -0.3, -1.45) + bob -- cerca del cuerpo
		local base = CFrame.lookAt(pos, BOW_AIM) * CFrame.Angles(0, 0, math.rad(-12))
		local pull, loaded, kick = 1, true, 0
		if active then
			if t < 0.15 then
				pull = 1 - ease(t / 0.15) -- suelta: la flecha sale
				loaded = false
				kick = math.sin(t / 0.15 * math.pi)
			else
				pull = ease((t - 0.15) / 0.85) -- carga otra y tensa
			end
		end
		local bow = base * CFrame.new(0, 0, 0.06 * kick) * CFrame.Angles(0, 0, math.rad(-3 * kick))
		return bow, bow, pull, loaded
	elseif weapon == "Sword" then
		-- Abajo a la derecha, hoja hacia arriba y un poco adelante
		local idle = CFrame.new(Vector3.new(0.6, -0.65, -1.45) + bob) * CFrame.Angles(math.rad(-25), math.rad(-15), math.rad(-15))
		local right = idle
		if active and anim.kind == "anime" then
			right = animePose(idle, anim.step, t) + bob
		elseif active and anim.kind == "slash" then
			local e = ease(t)
			local k = math.sin(t * math.pi)
			local from = CFrame.new(0.8, -0.25, -1.5) * CFrame.Angles(math.rad(-10), 0, math.rad(-60))
			local to = CFrame.new(-0.35, -0.75, -1.6) * CFrame.Angles(math.rad(-75), 0, math.rad(55))
			right = from:Lerp(to, e) * CFrame.new(0, 0, -0.25 * k) + bob
		elseif active and anim.kind == "spin" then
			right = idle * CFrame.Angles(0, 0, math.rad(-360 * ease(t)))
		end
		return right, right, 0, false
	else
		-- Guantes en guardia a los costados; directo al centro con el que toca
		local guardR = Vector3.new(0.48, -0.55, -1.35) + bob
		local guardL = Vector3.new(-0.48, -0.55, -1.35) + bob
		local punch = Vector3.new(0.1, -0.32, -2.1)
		local k = if active then math.sin(t * math.pi) else 0
		local r, l = guardR, guardL
		if anim.side > 0 then
			r = guardR:Lerp(punch + bob, k)
		else
			l = guardL:Lerp(Vector3.new(-punch.X, punch.Y, punch.Z) + bob, k)
		end
		-- Un poco girados hacia adentro, como puños cerrados en guardia
		return CFrame.new(l) * CFrame.Angles(0, math.rad(-12), math.rad(8)), CFrame.new(r) * CFrame.Angles(0, math.rad(12), math.rad(-8)), 0, false
	end
end

-- Flecha cargada: de la cuerda (tensada hacia la cámara) pasando por el centro del arco
-- Devuelve dónde agarra cada mano: el centro del arco (izquierda) y la cuerda (derecha)
local function placeArrow(r: Rig, bowCf: CFrame, item: Weapon, pull: number, loaded: boolean): (Vector3, Vector3)
	-- En el marco del arco: la panza está hacia BOW_BELLY y la cuerda del lado opuesto
	local belly = bowCf:PointToWorldSpace(BOW_BELLY * (item.depth * 0.5))
	local cord = bowCf:PointToWorldSpace(-BOW_BELLY * (item.depth * 0.5))
	local back = bowCf:VectorToWorldSpace(-BOW_BELLY) -- hacia la cámara
	local nock = cord + back * (BOW_PULL * pull)
	if not r.arrow then
		return belly, nock
	end
	local hide = if loaded then 0 else 1
	local dir = belly - nock
	if dir.Magnitude < 0.05 then
		dir = bowCf.LookVector
	end
	-- La cola en la cuerda, apoyada en el arco, apuntando hacia adelante
	local base = CFrame.lookAt(nock, nock + dir.Unit)
	for _, it in r.arrowParts do
		it.part.CFrame = base * it.offset
		it.part.Transparency = hide
	end
	return belly, nock
end

-- Antebrazo en bloque: la punta (la mano) en `hand` y el resto hacia el codo, fuera de cámara
local function placeArm(arm: Part, cam: CFrame, hand: Vector3, elbow: Vector3)
	local e = cam:PointToWorldSpace(elbow)
	local dir = e - hand
	if dir.Magnitude < 0.01 then
		dir = -cam.LookVector
	end
	local tip = hand - dir.Unit * 0.12 -- la mano asoma un poco por delante del agarre
	arm.CFrame = CFrame.lookAt(tip + dir.Unit * (ARM_LENGTH / 2), tip)
end

RunService.RenderStepped:Connect(function(dt)
	if not visible() then
		clear()
		return
	end
	local id = player:GetAttribute("Weapon") or "Bow"
	local weapon = Weapons.baseOf(id) -- las especiales se sostienen y animan como su base
	ensure(weapon, id)
	local r = rig
	if not r then
		return
	end
	local cam = workspace.CurrentCamera.CFrame
	-- Pausa de impacto (Juice): la animación y el balanceo se congelan un instante
	-- (el arma sigue pegada a la cámara)
	local frozen = os.clock() < (player:GetAttribute("HitStopUntil") or 0)
	if not frozen then
		anim.t = math.min(1, anim.t + dt / anim.dur)
		bobClock = os.clock()
	end

	-- Balanceo al caminar
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
	local clock = bobClock
	local bob = if moving then Vector3.new(math.sin(clock * 9) * 0.04, math.abs(math.cos(clock * 9)) * 0.05, 0) else Vector3.new(0, math.sin(clock * 2) * 0.015, 0)

	local left, right, pull, loaded = poses(weapon, anim.t, bob)
	local handL, handR
	if weapon == "Fists" then
		r.items[1].model:PivotTo(cam * right * r.items[1].hold)
		r.items[2].model:PivotTo(cam * left * r.items[2].hold)
		handL, handR = (cam * left).Position, (cam * right).Position
	else
		local item = r.items[1]
		local cf = cam * right
		item.model:PivotTo(cf * item.hold)
		if weapon == "Bow" then
			handL, handR = placeArrow(r, cf, item, pull, loaded)
		else
			-- Espada: la derecha en la empuñadura, la izquierda abajo libre
			handR = cf.Position
			handL = cam:PointToWorldSpace(Vector3.new(-0.85, -0.95, -1.7) + bob)
		end
	end
	-- Con el arco solo se ve el arco
	local arms = if weapon == "Bow" then 1 else 0
	r.armR.Transparency = arms
	r.armL.Transparency = arms
	placeArm(r.armR, cam, handR, ELBOW_R)
	placeArm(r.armL, cam, handL, ELBOW_L)
end)

player:GetAttributeChangedSignal("Weapon"):Connect(clear)
player.CharacterAdded:Connect(clear)

-- Predicción: con espada o puños comunes, el brazo se mueve apenas hacés click (el aviso del
-- servidor de ese mismo golpe se saltea). Si estás en recarga, espera al aviso del servidor.
local UserInputService = game:GetService("UserInputService")
local predictedUntil = 0
local readyAt = 0
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or player:GetAttribute("InMatch") ~= true then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.KeyCode ~= Enum.KeyCode.ButtonR2 then
		return
	end
	local id = player:GetAttribute("Weapon")
	local def = type(id) == "string" and Weapons.ById[id] or nil
	if not def or def.Kind ~= "Melee" or def.Fx then
		return
	end
	local now = os.clock()
	if now < readyAt then
		return
	end
	readyAt = now + Config.Player.AttackInterval * (def.IntervalMult or 1) * 0.9
	predictedUntil = now + 0.3
	if def.Id == "Fists" then
		play("punch", 0.14)
	else
		play("slash", 0.22)
	end
end)

-- Ataques propios (los confirma el servidor)
meleeSwing.OnClientEvent:Connect(function(userId, _origin, _dir, _range, arc, weaponId)
	if userId ~= player.UserId then
		return
	end
	local def0 = Weapons.ById[weaponId]
	if arc ~= 360 and os.clock() < predictedUntil and def0 and not def0.Fx then
		predictedUntil = 0 -- este golpe ya se animó al hacer click
		return
	end
	if Weapons.baseOf(weaponId) == "Sword" then
		local def = Weapons.ById[weaponId]
		if arc == 360 then
			play("spin", if def and def.Fx then SwingCombo.spinDuration(userId) else 0.35)
		elseif def and def.Fx then
			-- Arma con estilo anime: combo de 3 tajos (paso y duración los lleva SwingCombo)
			anim.step = SwingCombo.step(userId)
			play("anime", SwingCombo.duration(userId, anim.step))
		else
			play("slash", 0.22)
		end
	elseif weaponId == "Fists" then
		play("punch", 0.14)
	end
end)

projectileFired.OnClientEvent:Connect(function(_id, _origin, _dir, _speed, _lifetime, ownerUserId)
	if ownerUserId == player.UserId and anim.t >= 0.5 then
		play("shoot", 0.45)
	end
end)

---------------------------------------------------------------------
-- Chispas donde pegás
---------------------------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "HitSparks"
folder.Parent = workspace

local function sparks(pos: Vector3, color: Color3, big: boolean)
	local count = if low then 3 else (if big then 9 else 5)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(0.12, 0.12, if big then 1.1 else 0.7)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
		p.CFrame = CFrame.lookAt(pos, pos + dir)
		p.Parent = folder
		local travel = (if big then 3.5 else 2.2) * (0.6 + math.random() * 0.6)
		TweenService:Create(p, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(pos + dir * travel, pos + dir * (travel + 1)),
			Transparency = 1,
			Size = Vector3.new(0.05, 0.05, 0.3),
		}):Play()
		Debris:AddItem(p, 0.3)
	end
end

combatText.OnClientEvent:Connect(function(events)
	if typeof(events) ~= "table" or player:GetAttribute("InMatch") ~= true then
		return
	end
	local color = SPARK[Weapons.baseOf(player:GetAttribute("Weapon") or "Bow")] or SPARK.Bow
	for _, e in events do
		if (e.k == "hit" or e.k == "crit") and typeof(e.p) == "Vector3" then
			sparks(e.p + Vector3.new(0, 1, 0), color, e.k == "crit")
		end
	end
end)
