-- EnemyAnimator (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > EnemyAnimator
-- Animaciones de los modelos de enemigos, solo en la pantalla de cada jugador (no le cuestan
-- nada al servidor ni a la red):
--   · Aleteo: las piezas de un modelo cuyo grupo se llama "left wing" / "right wing" (o tiene
--     "wing" en el nombre) aletean girando desde su unión con el cuerpo. Los modelos generados
--     con las alas separadas (murciélagos / gárgolas) ya vienen así.
-- Cómo: el servidor suelda el modelo a la caja del enemigo (EnemyVisuals). Acá, en el cliente,
-- se desactiva localmente la soldadura de cada ala, se la ancla y se la ubica cada frame
-- respecto de la caja, con el giro del aleteo. Ajustes en Config.Enemy (WingFlap*, AnimateDistance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Cfg = Config.Enemy

type Wing = { part: BasePart, rest: CFrame, hinge: Vector3, sign: number }
type Entry = { wings: { Wing }, phase: number }

local entries: { [BasePart]: Entry } = {}

local function isWingGroup(inst: Instance?): boolean
	return inst ~= nil and string.find(string.lower(inst.Name), "wing", 1, true) ~= nil
end

-- Media extensión de una pieza a lo largo del eje X de la caja (rest es relativo a la caja)
local function halfExtentX(rest: CFrame, size: Vector3): number
	return math.abs(rest.RightVector.X) * size.X / 2 + math.abs(rest.UpVector.X) * size.Y / 2 + math.abs(rest.LookVector.X) * size.Z / 2
end

local function register(hitbox: BasePart)
	if entries[hitbox] or not hitbox.Parent then
		return
	end
	local look = hitbox:FindFirstChild("Look")
	if not look then
		return
	end
	local wings: { Wing } = {}
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") and isWingGroup(d.Parent) then
			local rest = hitbox.CFrame:ToObjectSpace(d.CFrame)
			local c = rest.Position
			local sign = if c.X >= 0 then 1 else -1
			-- Bisagra: el borde del ala que da al cuerpo
			local hinge = Vector3.new(c.X - sign * halfExtentX(rest, d.Size) * 0.85, c.Y, c.Z)
			-- Suelta el ala solo en esta pantalla (el servidor la sigue teniendo soldada)
			for _, j in d:GetChildren() do
				if j:IsA("WeldConstraint") or j:IsA("JointInstance") then
					(j :: any).Enabled = false
				end
			end
			d.Anchored = true
			table.insert(wings, { part = d, rest = rest, hinge = hinge, sign = sign })
		end
	end
	if #wings > 0 then
		entries[hitbox] = { wings = wings, phase = math.random() * math.pi * 2 }
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

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local maxAngle = math.rad(Cfg.WingFlapAngle or 35)
	local speed = Cfg.WingFlapSpeed or 14
	local far = Cfg.AnimateDistance or 150
	for hitbox, e in entries do
		if not hitbox.Parent then
			entries[hitbox] = nil
			continue
		end
		local base = hitbox.CFrame
		-- Lejos: quietas en su lugar (igual hay que acompañar a la caja, están ancladas)
		local angle = if (hitbox.Position - camPos).Magnitude <= far then maxAngle * math.sin(now * speed + e.phase) else 0
		for _, w in e.wings do
			if w.part.Parent then
				w.part.CFrame = base * CFrame.new(w.hinge) * CFrame.Angles(0, 0, w.sign * angle) * CFrame.new(-w.hinge) * w.rest
			end
		end
	end
end)
