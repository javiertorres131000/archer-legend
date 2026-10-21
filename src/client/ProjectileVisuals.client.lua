-- ProjectileVisuals (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > ProjectileVisuals
-- Dibuja los proyectiles que simula el servidor. Son solo visuales: el daño lo decide el servidor.
-- La trayectoria se calcula igual que en el servidor: tramos rectos con zigzag opcional;
-- cuando el servidor avisa un rebote o una vuelta, empieza un tramo nuevo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FxQuality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FxQuality"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local projectileFired = remotes:WaitForChild("ProjectileFired") :: RemoteEvent
local projectileEnded = remotes:WaitForChild("ProjectileEnded") :: RemoteEvent
local projectileRedirected = remotes:WaitForChild("ProjectileRedirected") :: RemoteEvent

local gameState = ReplicatedStorage:WaitForChild("GameState")
local localPlayer = Players.LocalPlayer
local low = FxQuality.isLow()
local lights = 0 -- luces en proyectiles enemigos (con muchas, cuesta rendimiento)
local MAX_LIGHTS = 10
local pools = { Arrow = {}, EnemyOrb = {} }
local MAX_POOL = if low then 40 else 100

-- Estela de color detrás de la flecha (no en calidad baja)
local function addTrail(part: Part, color: Color3, width: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, part.Size.Z / 2)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, part.Size.Z / 2)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.15
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = part
end

-- Flecha de verdad: vara de madera (la pieza principal), punta de metal y plumas, soldadas.
-- Se arman una vez por pieza del pool; solo se ajusta el tamaño y el color de las plumas.
local function dressArrow(part: Part, scale: number, featherColor: Color3)
	local head = part:FindFirstChild("Head") :: Part?
	local fletch = part:FindFirstChild("Fletch") :: Part?
	if not head then
		local h = Instance.new("Part")
		h.Name = "Head"
		h.Material = Enum.Material.Metal
		h.Color = Color3.fromRGB(190, 195, 205)
		h.CanCollide = false
		h.CanQuery = false
		h.CanTouch = false
		h.CastShadow = false
		h.Massless = true
		h.Anchored = false
		h.Parent = part
		head = h
		local f = h:Clone()
		f.Name = "Fletch"
		f.Material = Enum.Material.SmoothPlastic
		f.Parent = part
		fletch = f
		for _, child in { h, f } do
			local w = Instance.new("WeldConstraint")
			w.Part0 = part
			w.Part1 = child
			w.Parent = child
		end
	end
	local h, f = head :: Part, fletch :: Part
	local length = part.Size.Z
	-- (con la pieza principal en el origen, mirando a -Z: la punta va adelante)
	h.Size = Vector3.new(0.22, 0.22, 0.45) * scale
	h.CFrame = part.CFrame * CFrame.new(0, 0, -length / 2 - 0.15 * scale)
	f.Size = Vector3.new(0.04, 0.3, 0.5) * scale
	f.Color = featherColor
	f.CFrame = part.CFrame * CFrame.new(0, 0, length / 2 - 0.25 * scale)
end

-- Carpeta solo de este cliente (no se replica al servidor)
local folder = Instance.new("Folder")
folder.Name = "ProjectileVisuals"
folder.Parent = workspace

type Visual = {
	part: Part,
	origin: Vector3,
	dir: Vector3,
	speed: number,
	lifetime: number,
	age: number, -- edad total
	segAge: number, -- edad del tramo actual
	zigAmp: number,
	zigFreq: number,
	above: number?, -- altura sobre el piso al salir (sigue el relieve)
}
local visuals: { [number]: Visual } = {}

-- Altura del terreno debajo de un punto (los proyectiles suben y bajan con las colinas).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(pos: Vector3): number?
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), groundParams)
	return hit and hit.Position.Y
end

local function removeVisual(id: number)
	local v = visuals[id]
	if v then
		local light = v.part:FindFirstChildOfClass("PointLight")
		if light and light.Enabled then lights -= 1; light.Enabled = false end
		local trail = v.part:FindFirstChildOfClass("Trail")
		if trail then trail.Enabled = false; trail:Clear() end
		local pool = pools[v.part.Name]
		v.part.Parent = nil
		if pool and #pool < MAX_POOL then table.insert(pool, v.part) else v.part:Destroy() end
		visuals[id] = nil
	end
end

local function positionOf(v: Visual): Vector3
	local pos = v.origin + v.dir * v.speed * v.segAge
	if v.zigAmp > 0 then
		pos += Vector3.new(-v.dir.Z, 0, v.dir.X) * v.zigAmp * math.sin(v.segAge * v.zigFreq)
	end
	return pos
end

projectileFired.OnClientEvent:Connect(
	function(id: number, origin: Vector3, dir: Vector3, speed: number, lifetime: number, ownerUserId: number, style)
		local isEnemy = ownerUserId == 0 -- 0 = proyectil enemigo
		local kind = if isEnemy then "EnemyOrb" else "Arrow"
		local part = table.remove(pools[kind]) or Instance.new("Part")
		part.Name = kind
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		if isEnemy then
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * (style and style.size or 1.4)
			part.Color = style and style.color or Color3.fromRGB(255, 60, 110)
			if not low and lights < MAX_LIGHTS then
				lights += 1
				local light = part:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
				light.Enabled = true
				light.Color = part.Color
				light.Range = 8
				light.Brightness = 2
				light.Parent = part
			end
		else
			part.Shape = Enum.PartType.Block
			-- style.size: flecha gigante (Tiro cargado)
			local scale = if style and style.size then style.size else 1
			-- Vara de madera; las plumas dicen de quién es (dorado: tuya · azul: compañero · naranja: gigante)
			part.Size = Vector3.new(0.1, 0.1, 2.2) * scale
			part.Material = Enum.Material.Wood
			part.Color = Color3.fromRGB(120, 80, 45)
			local feather = if scale > 1 then Color3.fromRGB(255, 150, 60)
				elseif ownerUserId == localPlayer.UserId then Color3.fromRGB(255, 220, 110)
				else Color3.fromRGB(150, 200, 255)
			part.CFrame = CFrame.lookAt(origin, origin + dir)
			dressArrow(part, scale, feather)
			if not low then
				local trail = part:FindFirstChildOfClass("Trail")
				if trail then trail.Enabled = true; trail.Color = ColorSequence.new(feather) else addTrail(part, feather, 0.3) end
			end
		end
		part.CFrame = CFrame.lookAt(origin, origin + dir)
		part.Parent = folder

		visuals[id] = {
			part = part,
			origin = origin,
			dir = dir,
			speed = speed,
			lifetime = lifetime,
			age = 0,
			segAge = 0,
			zigAmp = style and style.zigAmp or 0,
			zigFreq = style and style.zigFreq or 0,
			above = (function()
				local g = groundAt(origin)
				return g and math.max(1, origin.Y - g)
			end)(),
		}

		-- Si la flecha es nuestra, giramos el personaje hacia el objetivo.
		-- (El cliente controla la física de su propio personaje, así que esto se replica solo.)
		-- (En primera persona no: el personaje mira hacia donde mira la cámara.)
		local firstPerson = Config.Camera.Mode == "FirstPerson" and localPlayer:GetAttribute("InMatch") == true
		if ownerUserId == localPlayer.UserId and not firstPerson then
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- Caminando (modo frenético) no se gira: lo haría pelear con la dirección de movimiento
			local moving = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 1
			if root and not moving then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
			end
		end
	end
)

projectileEnded.OnClientEvent:Connect(removeVisual)

-- Rebote o vuelta: tramo nuevo desde pos. remaining = segundos de vida que le quedan.
projectileRedirected.OnClientEvent:Connect(function(id: number, pos: Vector3, dir: Vector3, remaining: number?)
	local v = visuals[id]
	if v then
		v.origin = Vector3.new(pos.X, v.origin.Y, pos.Z)
		v.dir = dir
		v.segAge = 0
		if remaining then
			v.lifetime = v.age + remaining
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if gameState:GetAttribute("ChoosingPaused") then return end
	for id, v in visuals do
		v.age += dt
		v.segAge += dt
		if v.age >= v.lifetime + 0.2 then -- margen por si el aviso del servidor llega tarde
			removeVisual(id)
			continue
		end
		local pos = positionOf(v)
		if v.above then
			local g = groundAt(pos)
			if g then
				pos = Vector3.new(pos.X, g + v.above, pos.Z)
			end
		end
		v.part.CFrame = CFrame.lookAt(pos, pos + v.dir)
	end
end)
