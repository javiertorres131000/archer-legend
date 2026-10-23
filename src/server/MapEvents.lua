--!strict
-- MapEvents (ModuleScript)
-- Ubicación: ServerScriptService > Server > MapEvents
-- Mecánicas propias de cada mapa: lo que hace que jugar el Bosque se sienta distinto a jugar el
-- Glaciar. Solo pasan durante una oleada (no en el descanso) y dañan a TODOS: jugadores y
-- enemigos, así que también sirven como arma (llevá a los bichos debajo de un árbol que cae).
-- Los números están en Config.MapEvents[tema del capítulo].
--
-- Bosque (tema "forest"):
--   · Grietas de lava: cerca de los jugadores aparece un aviso naranja; al llenarse, erupciona
--     (daño y quemadura) y queda fuego unos segundos.
--   · Árboles que caen: un árbol calcinado cercano a la pelea (Models "ArbolNegro" del mapa hecho
--     a mano) tiembla, se marca la franja donde va a caer y aplasta todo lo que esté debajo.
--     Queda tirado un rato y desaparece.
--
-- Glaciar (tema "glacier"): ver Server/GlacierEvents y Server/Chill.
--
-- Run llama a reset() al armar un mapa, update() cada frame de combate y clear() al terminar.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local Enemies = require(script.Parent.Enemies)
local Hazards = require(script.Parent.Hazards)
local Ground = require(script.Parent.Ground)
local GlacierEvents = require(script.Parent.GlacierEvents) -- carámbanos, ventisca, fogatas y frío

local MapEvents = {}

type FallingTree = {
	model: Model,
	base: Vector3, -- pie del árbol (en el piso)
	pivot: CFrame, -- pivote original
	height: number,
	dir: Vector3, -- hacia dónde cae (horizontal, unitario)
	length: number,
	phase: "warn" | "fall" | "down",
	t: number,
	strip: BasePart?,
}

local rng = Random.new()
local theme: string? = nil
local props: Instance? = nil
local trees: { Model }? = nil -- árboles en pie que pueden caer (se buscan una vez por mapa)
local falling: { FallingTree } = {}
local pendingVents: { { pos: Vector3, at: number } } = {}
local nextVent = 0
local nextTree = 0
local clock = 0
local waveTime = 0

local LAVA = Color3.fromRGB(255, 120, 30)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function cfg(): any
	return theme and (Config.MapEvents :: any)[theme] or nil
end

local function range(r: { number }): number
	return rng:NextNumber(r[1], r[2])
end

-- Daño a un enemigo como fracción de su vida máxima (los jefes reciben mucho menos)
local function hurtEnemy(enemy: any, frac: number, bossFrac: number)
	local amount = enemy.maxHealth * (if enemy.isBoss then bossFrac else frac)
	Enemies.damage(enemy, amount, nil, "burn")
end

local function aliveEnemies(): { any }
	local out = {}
	for _, e in Enemies.list do
		if e.alive and not e.hidden and e.part and e.part.Parent then
			table.insert(out, e)
		end
	end
	return out
end

---------------------------------------------------------------------
-- Efectos (solo del servidor; son pocos y cortos)
---------------------------------------------------------------------

local function burstFx(pos: Vector3, size: number)
	local folder = workspace:FindFirstChild("Hazards") or workspace
	local p = Instance.new("Part")
	p.Name = "Erupcion"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos + Vector3.new(0, 1, 0)
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = size * 1.5
	fire.Color = LAVA
	fire.SecondaryColor = Color3.fromRGB(255, 210, 90)
	fire.Parent = p
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = size * 2.5
	light.Brightness = 3
	light.Parent = p
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(LAVA)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.35)
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(18, 30)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.Parent = p
	p.Parent = folder
	pcall(function()
		sparks:Emit(40)
	end)
	Debris:AddItem(p, 1.6)

	-- Pilar de lava: sale disparado hacia arriba, se ensancha y se apaga
	local function neon(color: Color3): Part
		local n = Instance.new("Part")
		n.Anchored = true
		n.CanCollide = false
		n.CanQuery = false
		n.CanTouch = false
		n.CastShadow = false
		n.Material = Enum.Material.Neon
		n.Shape = Enum.PartType.Cylinder
		n.Color = color
		n.Parent = folder
		return n
	end
	local up = CFrame.Angles(0, 0, math.rad(90)) -- el cilindro tiene el eje en X
	local HEIGHT = 26
	local core = neon(Color3.fromRGB(255, 220, 120))
	local shell = neon(LAVA)
	shell.Transparency = 0.35
	for _, part in { core, shell } do
		local w = if part == core then 2.5 else 5
		part.Size = Vector3.new(0.5, w, w)
		part.CFrame = CFrame.new(pos) * up
		local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(part, info, {
			Size = Vector3.new(HEIGHT, w * 1.4, w * 1.4),
			CFrame = CFrame.new(pos + Vector3.new(0, HEIGHT / 2, 0)) * up,
		}):Play()
		task.delay(0.3, function()
			local out = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(part, out, {
				Size = Vector3.new(HEIGHT * 0.3, 0.3, 0.3),
				CFrame = CFrame.new(pos + Vector3.new(0, HEIGHT * 0.15, 0)) * up,
				Transparency = 1,
			}):Play()
		end)
		Debris:AddItem(part, 1.1)
	end
	-- Onda en el piso
	local ring = neon(LAVA)
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * up
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, size * 3.2, size * 3.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
	-- Gotas de lava que caen alrededor
	local blobs = Instance.new("ParticleEmitter")
	blobs.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	blobs.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(200, 50, 20))
	blobs.LightEmission = 1
	blobs.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.4) })
	blobs.Lifetime = NumberRange.new(1, 1.6)
	blobs.Speed = NumberRange.new(25, 40)
	blobs.SpreadAngle = Vector2.new(25, 25)
	blobs.Acceleration = Vector3.new(0, -60, 0)
	blobs.EmissionDirection = Enum.NormalId.Top
	blobs.Rate = 0
	blobs.Parent = p
	pcall(function()
		blobs:Emit(18)
	end)
end

-- Bicho alcanzado: se prende fuego unos segundos (se ve desde lejos)
local function igniteFx(enemy: any, duration: number)
	local part = enemy.part
	if not part or not part.Parent or part:FindFirstChild("LavaFuego") then
		return
	end
	local fire = Instance.new("Fire")
	fire.Name = "LavaFuego"
	fire.Size = math.clamp((enemy.radius or 2) * 2, 3, 10)
	fire.Heat = fire.Size * 1.5
	fire.Color = LAVA
	fire.SecondaryColor = Color3.fromRGB(255, 210, 90)
	fire.Parent = part
	local light = Instance.new("PointLight")
	light.Name = "LavaLuz"
	light.Color = LAVA
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = part
	Debris:AddItem(fire, duration)
	Debris:AddItem(light, duration)
end

local function dustFx(pos: Vector3)
	local folder = workspace:FindFirstChild("Hazards") or workspace
	local p = Instance.new("Part")
	p.Name = "Polvo"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos + Vector3.new(0, 1, 0)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(90, 80, 72))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Rate = 0
	e.Parent = p
	p.Parent = folder
	pcall(function()
		e:Emit(30)
	end)
	Debris:AddItem(p, 2.5)
end

---------------------------------------------------------------------
-- Grietas de lava
---------------------------------------------------------------------

local function spawnVents(targets: { PlayerData.Target })
	local c = cfg().LavaVents
	if not c or #targets == 0 then
		return
	end
	local count = c.Count + (if #targets >= 3 then 1 else 0)
	for _ = 1, count do
		local t = targets[rng:NextInteger(1, #targets)]
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = range(c.Offset)
		local p = flat(t.root.Position) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
		-- Los avisos y el daño a jugadores los maneja Hazards; el daño a enemigos, nosotros
		Hazards.warn(p, c.Radius, c.Warn, c.Damage, { Duration = c.FireTime, Dps = c.FireDps, Color = LAVA }, LAVA)
		table.insert(pendingVents, { pos = p, at = clock + c.Warn })
	end
end

local function updateVents()
	local c = cfg().LavaVents
	for i = #pendingVents, 1, -1 do
		local v = pendingVents[i]
		if clock >= v.at then
			table.remove(pendingVents, i)
			burstFx(v.pos + Vector3.new(0, Ground.y(v.pos.X, v.pos.Z), 0), 7)
			for _, e in aliveEnemies() do
				if (flat(e.part.Position) - v.pos).Magnitude <= c.Radius + (e.radius or 0) * 0.5 then
					hurtEnemy(e, c.EnemyFrac, c.BossFrac)
					if e.alive then
						igniteFx(e, c.FireTime)
						Enemies.applyBurn(e, e.maxHealth * (if e.isBoss then c.BossFrac * 0.2 else c.EnemyBurnFrac), c.FireTime)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Árboles que caen
---------------------------------------------------------------------

local function findTrees(): { Model }
	local list = {}
	if props then
		for _, d in props:GetDescendants() do
			if d:IsA("Model") and d.Name == "ArbolNegro" and not d:GetAttribute("Fallen") then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function startTreeFall(targets: { PlayerData.Target }): boolean
	local c = cfg().FallingTrees
	if not c or #targets == 0 then
		return false
	end
	trees = trees or findTrees()
	local list = trees :: { Model }
	-- El árbol en pie más cercano a algún jugador (dentro del alcance)
	local best: Model?, bestDist, bestTarget = nil, c.Reach, nil
	for _, m in list do
		if m.Parent and not m:GetAttribute("Fallen") then
			local pos = flat(m:GetPivot().Position)
			for _, t in targets do
				local d = (flat(t.root.Position) - pos).Magnitude
				if d < bestDist and d > 6 then
					best, bestDist, bestTarget = m, d, t
				end
			end
		end
	end
	if not best or not bestTarget then
		return false
	end
	local model = best :: Model
	model:SetAttribute("Fallen", true)
	local cf, size = model:GetBoundingBox()
	local base = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
	-- Cae hacia el jugador (con un poco de desvío): la franja cruza la pelea
	local toward = flat((bestTarget :: PlayerData.Target).root.Position - base)
	local dir = (if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(1, 0, 0))
	local spread = math.rad(rng:NextNumber(-12, 12))
	dir = (CFrame.Angles(0, spread, 0) * dir).Unit
	local length = math.clamp(size.Y * 0.95, 14, c.MaxLength)
	local strip = Hazards.strip(base, dir, length, c.Width, Color3.fromRGB(255, 70, 40), 0.55)
	table.insert(falling, {
		model = model,
		base = base,
		pivot = model:GetPivot(),
		height = size.Y,
		dir = dir,
		length = length,
		phase = "warn",
		t = 0,
		strip = strip,
	})
	return true
end

local function crush(f: FallingTree)
	local c = cfg().FallingTrees
	local a = flat(f.base)
	local b = a + f.dir * f.length
	local function inStrip(pos: Vector3, extra: number): boolean
		local p = flat(pos)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (p - (a + ab * t)).Magnitude <= c.Width / 2 + extra
	end
	for _, target in PlayerData.getAliveTargets() do
		if inStrip(target.root.Position, 1) then
			PlayerLife.damage(target, c.Damage, "Árbol")
		end
	end
	for _, e in aliveEnemies() do
		if inStrip(e.part.Position, (e.radius or 0) * 0.5) then
			hurtEnemy(e, c.EnemyFrac, c.BossFrac)
		end
	end
	dustFx(a + f.dir * (f.length * 0.6) + Vector3.new(0, Ground.y(b.X, b.Z), 0))
end

local function updateTrees(dt: number)
	local c = cfg().FallingTrees
	for i = #falling, 1, -1 do
		local f = falling[i]
		f.t += dt
		if not f.model.Parent then
			if f.strip then
				f.strip:Destroy()
			end
			table.remove(falling, i)
			continue
		end
		-- Gira alrededor del pie, sobre el eje perpendicular a la caída
		local axis = Vector3.new(0, 1, 0):Cross(f.dir).Unit
		local function tilt(angle: number)
			local around = CFrame.new(f.base) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-f.base)
			f.model:PivotTo(around * f.pivot)
		end
		if f.phase == "warn" then
			-- Tiembla cada vez más mientras se llena el aviso
			local k = f.t / c.Warn
			tilt(math.sin(f.t * 28) * math.rad(1.5 + 3 * k))
			if f.t >= c.Warn then
				f.phase = "fall"
				f.t = 0
			end
		elseif f.phase == "fall" then
			local k = math.clamp(f.t / c.FallTime, 0, 1)
			tilt(math.rad(84) * k * k) -- acelera al caer
			if k >= 1 then
				f.phase = "down"
				f.t = 0
				if f.strip then
					f.strip:Destroy()
					f.strip = nil
				end
				crush(f)
			end
		elseif f.phase == "down" then
			if f.t >= c.LyingTime then
				f.model:Destroy()
				table.remove(falling, i)
			end
		end
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

-- Mapa nuevo: se olvidan los árboles y los eventos pendientes.
function MapEvents.reset(chapter: any?, propsFolder: Instance?)
	MapEvents.clear()
	theme = chapter and (chapter.Theme or chapter.Id) or nil
	props = propsFolder
	Remotes.GameState:SetAttribute("MapEvents", if cfg() then theme else "")
	GlacierEvents.reset(theme, propsFolder)
end

function MapEvents.clear()
	for _, f in falling do
		if f.strip then
			f.strip:Destroy()
		end
	end
	table.clear(falling)
	table.clear(pendingVents)
	GlacierEvents.clear()
	trees = nil
	waveTime = 0
	nextVent = 0
	nextTree = 0
end

-- Un frame de combate. phase: la de Waves ("Wave", "Break"...).
function MapEvents.update(dt: number, targets: { PlayerData.Target }, phase: string)
	local c = cfg()
	if not c then
		return
	end
	clock += dt
	GlacierEvents.update(dt, targets, phase)
	-- Lo que ya arrancó termina aunque se acabe la oleada
	updateVents()
	updateTrees(dt)
	if phase ~= "Wave" then
		waveTime = 0
		return
	end
	if waveTime == 0 then
		-- Al empezar cada oleada, un respiro antes del primer evento
		nextVent = clock + c.FirstDelay
		nextTree = clock + c.FirstDelay + 4
	end
	waveTime += dt
	if c.LavaVents and clock >= nextVent then
		spawnVents(targets)
		nextVent = clock + range(c.LavaVents.Every)
	end
	if c.FallingTrees and clock >= nextTree then
		startTreeFall(targets)
		nextTree = clock + range(c.FallingTrees.Every)
	end
end

-- Para pruebas
MapEvents._forceVents = spawnVents
MapEvents._forceTree = startTreeFall
function MapEvents._pending(): (number, number)
	return #pendingVents, #falling
end

return MapEvents
