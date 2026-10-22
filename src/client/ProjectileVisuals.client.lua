-- ProjectileVisuals (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > ProjectileVisuals
-- Dibuja los proyectiles que simula el servidor. Son solo visuales: el daño lo decide el servidor.
-- La trayectoria se calcula igual que en el servidor: tramos rectos con zigzag opcional;
-- cuando el servidor avisa un rebote o una vuelta, empieza un tramo nuevo.
-- Las flechas de quien tiene una skin con efectos (Shared/SkinFx) se visten con Client/SkinArrowFx.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FxQuality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FxQuality"))
local SkinArrowFx = require(script.Parent:WaitForChild("SkinArrowFx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local projectileFired = remotes:WaitForChild("ProjectileFired") :: RemoteEvent
local projectileEnded = remotes:WaitForChild("ProjectileEnded") :: RemoteEvent
local projectileRedirected = remotes:WaitForChild("ProjectileRedirected") :: RemoteEvent

local gameState = ReplicatedStorage:WaitForChild("GameState")
local localPlayer = Players.LocalPlayer
local low = FxQuality.isLow()
local lights = 0 -- luces en proyectiles enemigos (con muchas, cuesta rendimiento)
local MAX_LIGHTS = 10
local pools = { Arrow = {}, EnemyOrb = {}, Wave = {} }
local MAX_POOL = if low then 40 else 100
local TRAIL_LIFE = 0.15 -- estela de la flecha común

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
	trail.Lifetime = TRAIL_LIFE
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = part
end

-- Proyectil enemigo con efectos: según el color del ataque es fuego (rojo/naranja), rayo
-- (violeta/celeste), veneno (verde) o hielo (blanco/azul claro). Estela gruesa, llamas o chispas
-- que salen de atrás y un núcleo más claro. Se arma una vez por pieza del pool y se recolorea.
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function kindOf(c: Color3): string
	local h, s, _v = c:ToHSV()
	if s < 0.25 then
		return "ice"
	elseif h < 0.12 or h > 0.92 then
		return "fire"
	elseif h < 0.45 then
		return if h < 0.2 then "fire" else "poison"
	elseif h < 0.6 then
		return "ice"
	end
	return "bolt"
end

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end

local function dressEnemyOrb(part: Part, color: Color3)
	local kind = kindOf(color)
	local fx = part:FindFirstChild("Fx")
	if not fx then
		fx = Instance.new("Attachment")
		fx.Name = "Fx"
		fx.Parent = part
		local a0 = Instance.new("Attachment")
		a0.Name = "T0"
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Name = "T1"
		a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Name = "Estela"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = part
		local flames = Instance.new("ParticleEmitter")
		flames.Name = "Llamas"
		flames.EmissionDirection = Enum.NormalId.Back
		flames.LightEmission = 1
		flames.Parent = fx
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Chispas"
		sparks.Texture = SPARK_TEX
		sparks.LightEmission = 1
		sparks.Parent = fx
	end
	local size = part.Size.X
	local trail = part:FindFirstChild("Estela") :: Trail
	local flames = (fx :: Instance):FindFirstChild("Llamas") :: ParticleEmitter
	local sparks = (fx :: Instance):FindFirstChild("Chispas") :: ParticleEmitter
	;(part:FindFirstChild("T0") :: Attachment).Position = Vector3.new(0, size * 0.45, 0)
	;(part:FindFirstChild("T1") :: Attachment).Position = Vector3.new(0, -size * 0.45, 0)
	trail.Lifetime = if kind == "bolt" then 0.12 else 0.3
	trail.Color = ColorSequence.new(lighten(color, 0.5), color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Enabled = true
	-- Llamas (fuego), humo de colores (veneno), escarcha (hielo) o chispazos (rayo)
	flames.Texture = if kind == "fire" then FIRE_TEX elseif kind == "poison" then SMOKE_TEX else SPARK_TEX
	flames.Color = ColorSequence.new(lighten(color, 0.6), color)
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.9), NumberSequenceKeypoint.new(1, size * 0.2) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.25, 0.45)
	flames.Speed = NumberRange.new(2, 5)
	flames.SpreadAngle = Vector2.new(20, 20)
	flames.RotSpeed = NumberRange.new(-180, 180)
	flames.Rate = if kind == "bolt" then 40 else 60
	flames.Enabled = not low
	sparks.Color = ColorSequence.new(lighten(color, 0.4))
	sparks.Size = NumberSequence.new(if kind == "bolt" then 0.35 else 0.2)
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Speed = NumberRange.new(if kind == "bolt" then 10 else 4, if kind == "bolt" then 18 else 8)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = if kind == "bolt" then 45 else 15
	sparks.Enabled = not low
	-- Núcleo más claro: la bola brilla en el centro
	part.Color = lighten(color, 0.25)
end

-- Explosión chica donde pegó un proyectil enemigo (pool de piezas)
local burstPool: { Part } = {}
local function enemyBurst(pos: Vector3, color: Color3)
	if low then
		return
	end
	local p = table.remove(burstPool)
	if not p then
		p = Instance.new("Part")
		p.Name = "Impacto"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK_TEX
		e.LightEmission = 1
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(10, 22)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 4
		e.Parent = p
		local f = Instance.new("ParticleEmitter")
		f.Name = "Bola"
		f.Texture = FIRE_TEX
		f.LightEmission = 1
		f.Rate = 0
		f.Lifetime = NumberRange.new(0.2, 0.35)
		f.Speed = NumberRange.new(1, 3)
		f.SpreadAngle = Vector2.new(180, 180)
		f.Parent = p
	end
	p.Position = pos
	p.Parent = workspace
	local e = p:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
	local f = p:FindFirstChild("Bola") :: ParticleEmitter
	e.Color = ColorSequence.new(lighten(color, 0.4))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	f.Color = ColorSequence.new(lighten(color, 0.5), color)
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 4) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e:Emit(14)
	f:Emit(6)
	task.delay(0.6, function()
		p.Parent = nil
		if #burstPool < 20 then table.insert(burstPool, p) else p:Destroy() end
	end)
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
	h.Material = Enum.Material.Metal
	h.Color = Color3.fromRGB(190, 195, 205)
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
	color: Color3?, -- color del ataque (proyectiles enemigos)
	skin: any?, -- skin del arquero (SkinFx) si la flecha tiene efectos propios
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
		if v.skin then
			-- Antes del final de su alcance = pegó en algo: explosión. Si no, se apaga sola.
			SkinArrowFx.impact(v.part.Position, v.skin, v.age < v.lifetime - 0.05, low)
			SkinArrowFx.clear(v.part)
		end
		if v.part.Name == "EnemyOrb" then
			if v.age < v.lifetime - 0.05 then
				enemyBurst(v.part.Position, v.color or v.part.Color) -- pegó en algo
			end
			local fx = v.part:FindFirstChild("Fx")
			if fx then
				for _, e in fx:GetChildren() do
					if e:IsA("ParticleEmitter") then e.Enabled = false; e:Clear() end
				end
			end
		end
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
		local isWave = not isEnemy and style ~= nil and style.wave == true -- Onda cortante (espada)
		local kind = if isEnemy then "EnemyOrb" elseif isWave then "Wave" else "Arrow"
		local skin = if kind == "Arrow" then SkinArrowFx.forOwner(ownerUserId) else nil
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
			part.Color = style and style.color or Color3.fromRGB(255, 110, 40)
			dressEnemyOrb(part, part.Color)
			if not low and lights < MAX_LIGHTS then
				lights += 1
				local light = part:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
				light.Enabled = true
				light.Color = part.Color
				light.Range = 12
				light.Brightness = 3
				light.Parent = part
			end
		elseif isWave then
			-- Media luna de energía, ancha y plana
			local scale = style.size or 3
			part.Shape = Enum.PartType.Block
			part.Size = Vector3.new(scale * 1.6, 0.3, 0.9)
			part.Color = Color3.fromRGB(200, 235, 255)
			part.Transparency = 0.15
			if not low then
				local trail = part:FindFirstChildOfClass("Trail")
				if trail then trail.Enabled = true else addTrail(part, part.Color, 0.25) end
			end
		else
			part.Shape = Enum.PartType.Block
			part.Transparency = if style and style.ghost then 0.4 else 0
			-- style.size: flecha gigante (Tiro cargado)
			local scale = if style and style.size then style.size else 1
			-- Vara de madera; las plumas dicen de quién es (dorado: tuya · azul: compañero · naranja: gigante)
			part.Size = Vector3.new(0.1, 0.1, 2.2) * scale
			part.Material = Enum.Material.Wood
			part.Color = Color3.fromRGB(120, 80, 45)
			local feather = if style and style.ghost then Color3.fromRGB(190, 140, 255) -- Flecha fantasma
				elseif scale > 1 then Color3.fromRGB(255, 150, 60)
				elseif ownerUserId == localPlayer.UserId then Color3.fromRGB(255, 220, 110)
				else Color3.fromRGB(150, 200, 255)
			part.CFrame = CFrame.lookAt(origin, origin + dir)
			dressArrow(part, scale, feather)
			if not low then
				local trail = part:FindFirstChildOfClass("Trail")
				if not trail then
					addTrail(part, feather, 0.3)
					trail = part:FindFirstChildOfClass("Trail")
				end
				if trail then
					trail.Enabled = true
					if skin then
						local color, life, width = SkinArrowFx.trailStyle(skin)
						trail.Color = color
						trail.Lifetime = life
						trail.WidthScale = NumberSequence.new(width, width * 0.25)
					else
						trail.Color = ColorSequence.new(feather)
						trail.Lifetime = TRAIL_LIFE
						trail.WidthScale = NumberSequence.new(1)
					end
				end
			end
			if skin then
				-- Vara, punta, llamas, brasas y luz de la skin (las plumas siguen diciendo de quién es)
				SkinArrowFx.decorate(part, skin, low)
				SkinArrowFx.launch(origin, skin, low)
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
			skin = skin,
			color = if isEnemy then (style and style.color or Color3.fromRGB(255, 110, 40)) else nil,
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
