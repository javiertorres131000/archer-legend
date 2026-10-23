--!strict
-- AzrakothAnimator (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > AzrakothAnimator
-- Anima a los jefes con rig propio (modelo con el atributo AnimData, hoy solo Azrakoth): mueve
-- sus Motor6D en cada pantalla con los datos de Shared/AzrakothAnimData (exportados de Blender,
-- assets/azrakoth) y dispara sus efectos (AzrakothVFX). Es solo visual: el daño lo decide el
-- servidor (EnemyAI).
--   · Base: "Walk" si la caja del jefe se mueve, "Idle" si no.
--   · Ataques: el servidor pone en la caja el atributo BossAnim = "Nombre|aviso|hora". La
--     animación se acelera o frena para que su marca de golpe (Hit, Cast, Summon...) caiga justo
--     al terminar el aviso, y después sigue a velocidad normal.
--   · Peso: cada hueso persigue su pose con un resorte (el torso responde rápido, los brazos un
--     poco menos, y alas, capa y tabardos llegan tarde y se siguen meciendo). Así los golpes tienen
--     inercia y nada se mueve "de pose en pose".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AzrakothAnimData")) :: any
local VFX = require(script.Parent:WaitForChild("AzrakothVFX"))

type Key = { t: number, pose: { [string]: CFrame } }
type Anim = { dur: number, loop: boolean, keys: { Key }, hit: number?, marcas: { { t: number, nombre: string } } }
type Entry = {
	look: Model,
	motors: { [string]: Motor6D },
	actual: { [string]: CFrame },
	rigidez: { [string]: number },
	scale: number,
	lastPos: Vector3,
	vel: number, -- velocidad suavizada (la posición llega del servidor de a saltos)
	walkW: number, -- 0 = quieto, 1 = caminando (se mezcla de a poco)
	walkT: number,
	action: Anim?,
	start: number,
	rate: number,
	tPrev: number,
	fx: VFX.Boss,
}

local MARCAS_GOLPE = { "Hit", "Hit1", "Cast", "Summon", "BeamStart", "FX_Burst", "Dive", "FX_WingBurst", "FX_CorePulse2" }
local FUNDIDO = 0.25 -- segundos para pasar de una animación a otra
local DISTANCIA_MAX = 450

-- Qué tan rápido sigue cada hueso a su pose (más alto = más firme)
local function rigidezDe(hueso: string): number
	if string.find(hueso, "^Cape") or string.find(hueso, "^Tabard") or string.find(hueso, "^ClothSide") then
		return 5
	elseif string.find(hueso, "^Wing") then
		return if string.find(hueso, "_3$") then 6 elseif string.find(hueso, "_2$") then 7.5 else 9
	elseif hueso == "Halo" or hueso == "Crown" then
		return 8
	elseif string.find(hueso, "Leg") or string.find(hueso, "^Foot") or hueso == "Hips" then
		return 22
	elseif string.find(hueso, "Arm") or string.find(hueso, "Hand") or hueso == "Sword" or string.find(hueso, "Finger")
		or string.find(hueso, "Thumb") then
		return 15
	end
	return 18 -- torso, cuello, cabeza, núcleo
end

-- Precalcula las poses como CFrames (rotación + traslación de Root/Hips)
local anims: { [string]: Anim } = {}
for _, a in Data.animaciones do
	local keys: { Key } = {}
	for _, k in a.claves do
		local pose: { [string]: CFrame } = {}
		for hueso, q in k.rot do
			pose[hueso] = CFrame.new(0, 0, 0, q[2], q[3], q[4], q[1])
		end
		for hueso, d in k.loc do
			pose[hueso] = CFrame.new(d[1], d[2], d[3]) * (pose[hueso] or CFrame.identity)
		end
		table.insert(keys, { t = k.t, pose = pose })
	end
	local hit = nil
	for _, nombre in MARCAS_GOLPE do
		if a.marcas[nombre] then
			hit = a.marcas[nombre]
			break
		end
	end
	local marcas = {}
	for nombre, t in a.marcas do
		table.insert(marcas, { t = t, nombre = nombre })
	end
	anims[a.nombre] = { dur = a.duracion, loop = a.bucle, keys = keys, hit = hit, marcas = marcas }
end

-- Interpolación lineal entre claves: el resorte de cada hueso redondea las esquinas
local function sample(anim: Anim, t: number, hueso: string): CFrame
	local keys = anim.keys
	if t <= keys[1].t then
		return keys[1].pose[hueso] or CFrame.identity
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t < b.t then
			local x = (t - a.t) / math.max(b.t - a.t, 1e-3)
			return (a.pose[hueso] or CFrame.identity):Lerp(b.pose[hueso] or CFrame.identity, x)
		end
	end
	return keys[#keys].pose[hueso] or CFrame.identity
end

local entries: { [BasePart]: Entry } = {}

local function readAction(hitbox: BasePart, e: Entry)
	local v = hitbox:GetAttribute("BossAnim")
	if type(v) ~= "string" then
		return
	end
	local nombre, aviso, hora = string.match(v, "^([^|]+)|([^|]+)|([^|]+)$")
	local anim = nombre and anims[nombre]
	if not anim then
		return
	end
	local telegraph = tonumber(aviso) or 0
	e.action = anim
	e.start = tonumber(hora) or Workspace:GetServerTimeNow()
	e.rate = if anim.hit and telegraph > 0.05 then math.clamp(anim.hit / telegraph, 0.5, 2.5) else 1
	e.tPrev = -1
end

local function register(hitbox: Instance)
	if not hitbox:IsA("BasePart") or entries[hitbox] then
		return
	end
	local look = hitbox:FindFirstChild("Look")
	if not (look and look:IsA("Model") and look:GetAttribute("AnimData") == "Azrakoth") then
		return
	end
	local motors: { [string]: Motor6D } = {}
	local rigidez: { [string]: number } = {}
	for _, d in look:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			motors[d.Part1.Name] = d
			rigidez[d.Part1.Name] = rigidezDe(d.Part1.Name)
		end
	end
	local scale = look:GetScale()
	local e: Entry = { look = look, motors = motors, actual = {}, rigidez = rigidez, scale = scale,
		lastPos = hitbox.Position, vel = 0, walkW = 0, walkT = 0, action = nil, start = 0, rate = 1, tPrev = -1,
		fx = VFX.setup(hitbox, look, scale) }
	entries[hitbox] = e
	readAction(hitbox, e)
	hitbox:GetAttributeChangedSignal("BossAnim"):Connect(function()
		readAction(hitbox, e)
	end)
	hitbox.AncestryChanged:Connect(function()
		if not hitbox:IsDescendantOf(Workspace) then
			entries[hitbox] = nil
		end
	end)
end

local function watch(hitbox: Instance)
	register(hitbox)
	if hitbox:IsA("BasePart") and not entries[hitbox] then
		local conn
		conn = hitbox.ChildAdded:Connect(function(c)
			if c.Name == "Look" then
				conn:Disconnect()
				task.defer(register, hitbox)
			end
		end)
	end
end

local folder = Workspace:WaitForChild("Enemies")
for _, c in folder:GetChildren() do
	watch(c)
end
folder.ChildAdded:Connect(watch)

-- Respiración y mirada cuando está quieto (se suma a Idle, que es sutil)
local function respira(hueso: string, now: number, w: number): CFrame
	if w < 0.01 then
		return CFrame.identity
	end
	local r = 0
	if hueso == "Chest" then
		return CFrame.Angles(math.sin(now * 1.4) * math.rad(3) * w, 0, 0)
	elseif hueso == "Head" then
		return CFrame.Angles(math.sin(now * 0.9) * math.rad(3) * w, math.sin(now * 0.35) * math.rad(12) * w, 0)
	elseif hueso == "Wing_L_1" or hueso == "Wing_R_1" then
		r = math.sin(now * 1.1) * math.rad(6) * w
		return CFrame.Angles(0, 0, if hueso == "Wing_L_1" then r else -r)
	elseif hueso == "Wing_L_2" or hueso == "Wing_R_2" then
		r = math.sin(now * 1.1 - 0.6) * math.rad(5) * w
		return CFrame.Angles(0, 0, if hueso == "Wing_L_2" then r else -r)
	elseif hueso == "UpperArm_L" or hueso == "Shoulder_L" or hueso == "Shoulder_R" then
		return CFrame.Angles(math.sin(now * 1.4 + 0.5) * math.rad(2) * w, 0, 0)
	end
	return CFrame.identity
end

-- Movimiento extra que no está en las claves: alas y telas nunca quedan del todo quietas
local function vida(hueso: string, now: number, i: number): CFrame
	if string.find(hueso, "^Wing") then
		local n = math.noise(now * 0.6, i * 3.1) * 0.05
		return CFrame.Angles(0, 0, n)
	elseif string.find(hueso, "^Cape") or string.find(hueso, "^Tabard") or string.find(hueso, "^ClothSide") then
		return CFrame.Angles(math.noise(now * 0.9, i * 1.7) * 0.07, 0, math.noise(now * 0.7, i * 2.3) * 0.04)
	end
	return CFrame.identity
end

RunService.RenderStepped:Connect(function(dt)
	local cam = Workspace.CurrentCamera
	local now = Workspace:GetServerTimeNow()
	local clock = os.clock()
	for hitbox, e in entries do
		local pos = hitbox.Position
		local delta = pos - e.lastPos
		e.lastPos = pos
		local speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / math.max(dt, 1e-3)
		e.vel += (speed - e.vel) * (1 - math.exp(-3 * dt))
		local quiere = if e.vel > 1.2 then 1 else 0
		e.walkW += (quiere - e.walkW) * (1 - math.exp(-4 * dt))
		-- el paso acompaña la velocidad (más rápido en las fases 2 y 3)
		e.walkT = (e.walkT + dt * math.clamp(e.vel / (6 * e.scale + 1), 0.7, 1.8)) % anims.Walk.dur
		VFX.update(e.fx, clock)
		if cam and (cam.CFrame.Position - pos).Magnitude > DISTANCIA_MAX then
			continue
		end
		local idle, walk = anims.Idle, anims.Walk
		local tIdle = clock % idle.dur
		local function base(hueso: string): CFrame
			local a = sample(idle, tIdle, hueso)
			if e.walkW > 0.01 then
				return a:Lerp(sample(walk, e.walkT, hueso), e.walkW)
			end
			return a
		end
		-- tiempo dentro de la acción: acelerada hasta el golpe, normal después
		local action = e.action
		local tAct, peso = 0, 0
		if action then
			local elapsed = now - e.start
			local hit = action.hit
			if hit and elapsed * e.rate < hit then
				tAct = elapsed * e.rate
			elseif hit then
				tAct = hit + (elapsed - hit / e.rate)
			else
				tAct = elapsed
			end
			-- efectos de las marcas que se cruzaron en este cuadro
			for _, mk in action.marcas do
				if mk.t > e.tPrev and mk.t <= tAct then
					task.spawn(VFX.marca, e.fx, mk.nombre)
				end
			end
			e.tPrev = tAct
			if tAct >= action.dur and action == anims.Death then
				tAct = action.dur - 1e-3 -- muerto: se queda tirado hasta desaparecer
				peso = 1
			elseif tAct >= action.dur then
				e.action = nil
			else
				peso = math.clamp(elapsed / FUNDIDO, 0, 1) * math.clamp((action.dur - tAct) / FUNDIDO, 0, 1)
			end
		end
		local i = 0
		for hueso, motor in e.motors do
			i += 1
			local objetivo = base(hueso) * respira(hueso, clock, 1 - e.walkW)
			if action and peso > 0 then
				objetivo = objetivo:Lerp(sample(action, tAct, hueso), peso)
			end
			if hueso == "Hips" then -- el hueso Root no tiene pieza: su giro y altura van en la cadera
				local root = base("Root")
				if action and peso > 0 then
					root = root:Lerp(sample(action, tAct, "Root"), peso)
				end
				objetivo = root * objetivo
			end
			objetivo *= vida(hueso, clock, i)
			-- resorte: se acerca a la pose objetivo según la rigidez del hueso
			local antes = e.actual[hueso] or objetivo
			local cf = antes:Lerp(objetivo, 1 - math.exp(-e.rigidez[hueso] * dt))
			e.actual[hueso] = cf
			if e.scale ~= 1 then
				cf = cf - cf.Position + cf.Position * e.scale
			end
			motor.Transform = cf
		end
	end
end)
