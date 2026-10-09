-- ProjectileVisuals (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > ProjectileVisuals
-- Dibuja los proyectiles que simula el servidor. Son solo visuales: el daño lo decide el servidor.
-- La trayectoria se calcula igual que en el servidor: tramos rectos con zigzag opcional;
-- cuando el servidor avisa un rebote o una vuelta, empieza un tramo nuevo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local projectileFired = remotes:WaitForChild("ProjectileFired") :: RemoteEvent
local projectileEnded = remotes:WaitForChild("ProjectileEnded") :: RemoteEvent
local projectileRedirected = remotes:WaitForChild("ProjectileRedirected") :: RemoteEvent

local localPlayer = Players.LocalPlayer

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
}
local visuals: { [number]: Visual } = {}

local function removeVisual(id: number)
	local v = visuals[id]
	if v then
		v.part:Destroy()
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
		local part = Instance.new("Part")
		part.Name = if isEnemy then "EnemyOrb" else "Arrow"
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
		else
			part.Size = Vector3.new(0.3, 0.3, 2)
			part.Color = if ownerUserId == localPlayer.UserId
				then Color3.fromRGB(255, 230, 120)
				else Color3.fromRGB(150, 200, 255)
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
		}

		-- Si la flecha es nuestra, giramos el personaje hacia el objetivo.
		-- (El cliente controla la física de su propio personaje, así que esto se replica solo.)
		-- (En primera persona no: el personaje mira hacia donde mira la cámara.)
		local firstPerson = Config.Camera.Mode == "FirstPerson" and localPlayer:GetAttribute("InMatch") == true
		if ownerUserId == localPlayer.UserId and not firstPerson then
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
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
	for id, v in visuals do
		v.age += dt
		v.segAge += dt
		if v.age >= v.lifetime + 0.2 then -- margen por si el aviso del servidor llega tarde
			removeVisual(id)
			continue
		end
		local pos = positionOf(v)
		v.part.CFrame = CFrame.lookAt(pos, pos + v.dir)
	end
end)
