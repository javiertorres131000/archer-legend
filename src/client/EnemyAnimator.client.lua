-- EnemyAnimator (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > EnemyAnimator
-- Animaciones de los modelos de enemigos, solo en la pantalla de cada jugador (no le cuestan
-- nada al servidor ni a la red). Usa los nombres de los grupos del modelo (los modelos
-- generados con IA vienen separados en "body", "head", "left leg", "right arm", "left wing"...):
--   · Caminar (atributo Gait = "Walk"): las piezas de grupos con "leg" en el nombre se
--     balancean desde la cadera, izquierda y derecha alternadas; las de "arm", al revés que las
--     piernas. Cuanto más rápido va, más amplio el paso. Quieto: vuelven a su lugar.
--   · Saltitos (Gait = "Hop", slimes): en cada salto el modelo se estira al despegar, hace un
--     arco en el aire y se aplasta al caer, con un rebote gelatinoso. Quieto: respira.
--   · Aleteo: las piezas de grupos con "wing" en el nombre aletean desde su unión con el cuerpo.
-- Gait lo pone el servidor al crear el enemigo (Enemies.gaitOf, según su forma de moverse).
-- Cómo: el servidor suelda el modelo a la caja del enemigo (EnemyVisuals). Acá se desactiva
-- localmente la soldadura de las piezas que se animan, se las ancla y se las ubica cada frame
-- respecto de la caja. Ajustes en Config.Enemy (Walk*, Hop*, WingFlap*, AnimateDistance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Cfg = Config.Enemy

-- Una pieza animada: dónde está respecto de la caja (rest), su tamaño original y la bisagra
type Piece = { part: BasePart, rest: CFrame, size: Vector3, hinge: Vector3, sign: number }
type Entry = {
	gait: string,
	wings: { Piece },
	legs: { Piece },
	arms: { Piece },
	blob: { Piece }, -- todas las piezas (saltitos: se escala el modelo entero)
	bottom: number, -- Y más bajo del modelo respecto de la caja
	height: number,
	phase: number,
	stride: number,
	speed: number,
	lastPos: Vector3,
	moving: boolean,
	hopT: number,
	landT: number,
}

local entries: { [BasePart]: Entry } = {}

local function groupName(part: Instance): string
	local parent = part.Parent
	return if parent then string.lower(parent.Name) else ""
end

local function has(name: string, word: string): boolean
	return string.find(name, word, 1, true) ~= nil
end

-- Media extensión de una pieza a lo largo de un eje de la caja (rest es relativo a la caja)
local function halfExtent(rest: CFrame, size: Vector3, axis: Vector3): number
	return math.abs(rest.RightVector:Dot(axis)) * size.X / 2 + math.abs(rest.UpVector:Dot(axis)) * size.Y / 2 + math.abs(rest.LookVector:Dot(axis)) * size.Z / 2
end

-- Suelta la pieza solo en esta pantalla (el servidor la sigue teniendo soldada) y la ancla
local function detach(part: BasePart)
	for _, j in part:GetChildren() do
		if j:IsA("WeldConstraint") or j:IsA("JointInstance") then
			(j :: any).Enabled = false
		end
	end
	part.Anchored = true
end

local function register(hitbox: BasePart)
	if entries[hitbox] or not hitbox.Parent then
		return
	end
	local look = hitbox:FindFirstChild("Look")
	if not look then
		return
	end
	local gait = (hitbox:GetAttribute("Gait") :: string?) or "Walk"
	local e: Entry = {
		gait = gait,
		wings = {},
		legs = {},
		arms = {},
		blob = {},
		bottom = math.huge,
		height = 0,
		phase = math.random() * math.pi * 2,
		stride = 0,
		speed = 0,
		lastPos = hitbox.Position,
		moving = false,
		hopT = 0,
		landT = 10,
	}
	local top = -math.huge
	for _, d in look:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local rest = hitbox.CFrame:ToObjectSpace(d.CFrame)
		local c = rest.Position
		local halfY = halfExtent(rest, d.Size, Vector3.yAxis)
		e.bottom = math.min(e.bottom, c.Y - halfY)
		top = math.max(top, c.Y + halfY)
		local name = groupName(d)
		local sign = if has(name, "left") then -1 elseif has(name, "right") then 1 elseif c.X >= 0 then 1 else -1
		local piece: Piece = { part = d, rest = rest, size = d.Size, hinge = c, sign = sign }
		if has(name, "wing") then
			-- Bisagra: el borde del ala que da al cuerpo
			piece.hinge = Vector3.new(c.X - sign * halfExtent(rest, d.Size, Vector3.xAxis) * 0.85, c.Y, c.Z)
			table.insert(e.wings, piece)
		elseif gait == "Walk" and has(name, "leg") then
			-- Bisagra: arriba de la pierna (la cadera)
			piece.hinge = Vector3.new(c.X, c.Y + halfY * 0.9, c.Z)
			table.insert(e.legs, piece)
		elseif gait == "Walk" and has(name, "arm") then
			piece.hinge = Vector3.new(c.X, c.Y + halfY * 0.8, c.Z)
			table.insert(e.arms, piece)
		end
		table.insert(e.blob, piece)
	end
	e.height = math.max(0.5, top - e.bottom)
	-- Qué piezas se sueltan: con saltitos, todas; si no, solo las que se mueven
	if gait == "Hop" then
		for _, p in e.blob do
			detach(p.part)
		end
	else
		e.blob = {}
		for _, list in { e.wings, e.legs, e.arms } do
			for _, p in list do
				detach(p.part)
			end
		end
		-- Una sola pierna no camina (sería un modelo mal separado): mejor quieto
		if #e.legs < 2 then
			for _, p in e.legs do
				table.insert(e.arms, p)
			end
			e.legs = {}
		end
	end
	if #e.wings + #e.legs + #e.arms + #e.blob > 0 then
		entries[hitbox] = e
	end
end

local function watch(child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local hitbox = child :: BasePart
	if hitbox:FindFirstChild("Look") then
		task.defer(register, hitbox)
		return
	end
	local conn: RBXScriptConnection
	conn = hitbox.ChildAdded:Connect(function(c)
		if c.Name == "Look" then
			conn:Disconnect()
			task.defer(register, hitbox)
		end
	end)
end

local folder = workspace:WaitForChild("Enemies")
folder.ChildAdded:Connect(watch)
for _, c in folder:GetChildren() do
	watch(c)
end

-- Escala de una pieza en sus propios ejes cuando el modelo se estira (sxz de costado, sy alto)
local function scaledSize(rest: CFrame, size: Vector3, sxz: number, sy: number): Vector3
	local function axis(v: Vector3): number
		return math.sqrt((v.X * sxz) ^ 2 + (v.Y * sy) ^ 2 + (v.Z * sxz) ^ 2)
	end
	return Vector3.new(size.X * axis(rest.RightVector), size.Y * axis(rest.UpVector), size.Z * axis(rest.LookVector))
end

local function swing(base: CFrame, p: Piece, angle: number)
	p.part.CFrame = base * CFrame.new(p.hinge) * CFrame.Angles(angle, 0, 0) * CFrame.new(-p.hinge) * p.rest
end

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local far = Cfg.AnimateDistance or 150
	local flapAngle = math.rad(Cfg.WingFlapAngle or 35)
	local flapSpeed = Cfg.WingFlapSpeed or 14
	local walkSwing = math.rad(Cfg.WalkSwing or 38)
	local strideRate = Cfg.WalkStride or 0.9 -- radianes de paso por stud recorrido
	local hopTime = Cfg.HopTime or 0.42
	local hopHeight = Cfg.HopHeight or 0.45 -- en alturas del modelo
	local squash = Cfg.HopSquash or 0.3
	dt = math.min(dt, 0.1)
	for hitbox, e in entries do
		if not hitbox.Parent then
			entries[hitbox] = nil
			continue
		end
		local base = hitbox.CFrame
		local pos = base.Position
		-- Velocidad en el piso (suavizada: la posición llega del servidor a saltos)
		local delta = Vector3.new(pos.X - e.lastPos.X, 0, pos.Z - e.lastPos.Z).Magnitude
		e.lastPos = pos
		local raw = if dt > 0 then delta / dt else 0
		e.speed += (raw - e.speed) * math.min(1, dt * 10)
		local near = (pos - camPos).Magnitude <= far

		-- Aleteo
		local flap = if near then flapAngle * math.sin(now * flapSpeed + e.phase) else 0
		for _, w in e.wings do
			if w.part.Parent then
				w.part.CFrame = base * CFrame.new(w.hinge) * CFrame.Angles(0, 0, w.sign * flap) * CFrame.new(-w.hinge) * w.rest
			end
		end

		-- Caminar: piernas alternadas, brazos al revés
		if #e.legs > 0 or #e.arms > 0 then
			local amount = if near then math.clamp(e.speed / 6, 0, 1) else 0
			e.stride += delta * strideRate
			-- Quieto: amount baja a 0 y el paso se cierra solo
			local a = walkSwing * amount * math.sin(e.stride)
			for _, l in e.legs do
				if l.part.Parent then
					swing(base, l, a * l.sign)
				end
			end
			for _, arm in e.arms do
				if arm.part.Parent then
					swing(base, arm, -a * arm.sign * 0.7)
				end
			end
		end

		-- Saltitos: estirar, arco, aplastar y rebote gelatinoso
		if #e.blob > 0 then
			local moving = e.speed > 1.5
			local sy, lift = 1, 0
			if moving then
				if not e.moving then
					e.hopT = 0
				end
				e.hopT += dt
				local p = (e.hopT % hopTime) / hopTime
				if e.hopT >= hopTime and (e.hopT - dt) % hopTime > p then
					e.landT = 0 -- cayó y vuelve a saltar
				end
				lift = math.sin(math.pi * p) * hopHeight * e.height
				sy = 1 + squash * 0.7 * math.cos(math.pi * p) -- estirado al subir, aplastado al bajar
			elseif e.moving then
				e.landT = 0 -- aterrizó
			end
			e.moving = moving
			e.landT += dt
			-- Rebote al caer (se apaga solo) y respiración de quieto
			sy *= 1 - squash * math.exp(-e.landT * 9) * math.cos(e.landT * 22)
			if not moving then
				sy *= 1 + 0.04 * math.sin(now * 3 + e.phase)
			end
			if not near then
				sy, lift = 1, 0
			end
			local sxz = 1 / math.sqrt(math.max(0.2, sy)) -- mismo volumen: si baja, se ensancha
			for _, b in e.blob do
				if b.part.Parent then
					local r = b.rest.Position
					local newPos = Vector3.new(r.X * sxz, e.bottom + (r.Y - e.bottom) * sy + lift, r.Z * sxz)
					b.part.Size = scaledSize(b.rest, b.size, sxz, sy)
					b.part.CFrame = base * CFrame.new(newPos) * b.rest.Rotation
				end
			end
		end
	end
end)
