--!strict
-- GlacierEvents (ModuleScript)
-- Ubicación: ServerScriptService > Server > GlacierEvents
-- Mecánicas del Glaciar Eterno (Config.MapEvents.glacier). Las llama MapEvents.
--   · Carámbanos: caen del cielo cerca de los jugadores (aviso celeste), lastiman y suman frío.
--     También lastiman a los enemigos.
--   · Ventisca: cada tanto un viento blanco cruza el mapa. Avisa, empuja a los jugadores (lo
--     aplica el cliente, IceWorld) y suma frío a quien no esté junto a una fogata.
--     Se publica en GameState el atributo "Blizzard" = "inicio|fin|dirX|dirZ" (hora del servidor).
--   · Fogatas: repartidas por el mapa, con antorchas que marcan el camino desde el centro.
--     Cerca de una el frío se va rápido.
--   · Se presentan de a una: carámbanos desde Icicles.FromWave y ventisca desde
--     Blizzard.FromWave. Cada mecánica nueva publica en GameState "GlacierTip" = "clave|hora"
--     (el cliente muestra el cartel) y la próxima ventisca "BlizzardNext" = hora del servidor.
-- El frío en sí (lentitud y congelamiento) está en Server/Chill.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Enemies = require(script.Parent.Enemies)
local Hazards = require(script.Parent.Hazards)
local Ground = require(script.Parent.Ground)
local Chill = require(script.Parent.Chill)

local GlacierEvents = {}

local FROST = Color3.fromRGB(150, 220, 255)
local ICE = Color3.fromRGB(190, 235, 255)
local WARN = Color3.fromRGB(255, 35, 90)

local rng = Random.new()
local enabled = false
local clock = 0
local nextIcicle = 0
local nextBlizzard = 0
local blizzardStart = 0
local blizzardEnd = 0
local blizzardChill: { [Player]: number } = {}
local pending: { { pos: Vector3, at: number } } = {}
local inWave = false
local tipsShown: { [string]: boolean } = {}
local blizzardReady = false -- ya se presentó la ventisca en esta partida

local function cfg(): any
	return (Config :: any).MapEvents.glacier
end

local function range(r: { number }): number
	return rng:NextNumber(r[1], r[2])
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function hazardsFolder(): Instance
	return workspace:FindFirstChild("Hazards") or workspace
end

---------------------------------------------------------------------
-- Fogatas
---------------------------------------------------------------------

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function campfire(parent: Instance, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Fogata"
	for i = 0, 3 do
		local log = part(model, "Tronco", Vector3.new(0.7, 0.7, 3.2), CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
		log.CanCollide = false
	end
	for i = 0, 7 do -- piedras alrededor
		local a = i / 8 * math.pi * 2
		part(model, "Piedra", Vector3.new(1, 0.7, 1), CFrame.new(pos + Vector3.new(math.cos(a) * 2.2, 0.3, math.sin(a) * 2.2)), Color3.fromRGB(90, 95, 105), Enum.Material.Slate)
	end
	local core = part(model, "Brasa", Vector3.new(1.4, 0.5, 1.4), CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	core.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 130, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 22
	light.Brightness = 2.5
	light.Shadows = true
	light.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Chispas"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 180, 80))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.18)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Rate = 10
	sparks.Parent = core
	-- Anillo cálido: muestra hasta dónde llega el calor
	local radius = cfg().Campfires.WarmRadius
	local ring = part(model, "Calor", Vector3.new(0.15, radius * 2, radius * 2), CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false
	ring.Transparency = 0.88
	ring.CastShadow = false
	model:SetAttribute("Warm", true) -- el cliente le pone humo y calor (IceWorld)
	model.Parent = parent
end

-- Pino oscuro con nieve (para los bosques del borde: dan forma al valle y contraste)
local function pine(parent: Instance, pos: Vector3, scale: number)
	local m = Instance.new("Model")
	m.Name = "PinoBorde"
	part(m, "Tronco", Vector3.new(1, 3, 1) * scale, CFrame.new(pos + Vector3.new(0, 1.5 * scale, 0)), Color3.fromRGB(55, 40, 30), Enum.Material.Wood)
	for i, w in { 5.5, 4.2, 3, 1.8 } do
		local y = (2 + i * 1.6) * scale
		local cone = part(m, "Copa", Vector3.new(w, 2, w) * scale, CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(30 * i), 0), Color3.fromRGB(25, 55, 45), Enum.Material.Grass)
		cone.CanCollide = i == 1
		local snow = part(m, "Nieve", Vector3.new(w * 0.75, 0.4, w * 0.75) * scale, CFrame.new(pos + Vector3.new(0, y + 1.1 * scale, 0)) * CFrame.Angles(0, math.rad(30 * i + 15), 0), Color3.fromRGB(235, 242, 250), Enum.Material.Snow)
		snow.CanCollide = false
	end
	m.Parent = parent
end

local function darkRock(parent: Instance, pos: Vector3, s: number)
	local r = part(parent, "RocaOscura", Vector3.new(s * 1.4, s, s * 1.1), CFrame.new(pos + Vector3.new(0, s * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(45, 50, 62), Enum.Material.Slate)
	r.CanCollide = true
end

-- Bosques de pinos y rocas oscuras en un anillo antes de las montañas
local function borderForest(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "BosqueBorde"
	for _ = 1, 70 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(84, 100)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local pos = Vector3.new(x, Ground.y(x, z), z)
		if rng:NextNumber() < 0.7 then
			pine(folder, pos, rng:NextNumber(1.1, 1.8))
		else
			darkRock(folder, pos, rng:NextNumber(3, 6))
		end
	end
	folder.Parent = parent
end

-- Antorchas desde el centro hasta cada fogata: marcan el camino al calor
local function torchPath(parent: Instance, to: Vector3)
	local flatTo = Vector3.new(to.X, 0, to.Z)
	local dist = flatTo.Magnitude
	if dist < 20 then
		return
	end
	local dir = flatTo.Unit
	local d = 14
	while d < dist - 6 do
		local p = dir * d
		local pos = Vector3.new(p.X, Ground.y(p.X, p.Z), p.Z)
		local post = part(parent, "Antorcha", Vector3.new(0.35, 3, 0.35), CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(70, 50, 35), Enum.Material.Wood)
		post.CanCollide = false
		local flame = part(parent, "Llama", Vector3.new(0.6, 0.8, 0.6), CFrame.new(pos + Vector3.new(0, 3.3, 0)), Color3.fromRGB(255, 150, 50), Enum.Material.Neon)
		flame.CanCollide = false
		d += 11
	end
end

local function placeCampfires(parent: Instance)
	local c = cfg().Campfires
	local spots = {}
	local base = rng:NextNumber(0, math.pi * 2)
	for i = 1, c.Count do
		local a = base + (i - 1) / c.Count * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local d = if i == 1 then rng:NextNumber(16, 24) else rng:NextNumber(35, 80)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local pos = Vector3.new(x, Ground.y(x, z), z)
		campfire(parent, pos)
		torchPath(parent, pos)
		table.insert(spots, pos)
	end
	Chill.setWarmSpots(spots)
end

---------------------------------------------------------------------
-- Carámbanos
---------------------------------------------------------------------

local function shatterFx(pos: Vector3)
	local folder = hazardsFolder()
	-- El carámbano cae desde arriba
	local spike = Instance.new("Part")
	spike.Name = "Carambano"
	spike.Anchored = true
	spike.CanCollide = false
	spike.CanQuery = false
	spike.CanTouch = false
	spike.Material = Enum.Material.Ice
	spike.Color = ICE
	spike.Transparency = 0.15
	spike.Size = Vector3.new(2.2, 9, 2.2)
	spike.CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	spike.Parent = folder
	-- Se clava, se resquebraja y se derrite
	TweenService:Create(spike, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = Vector3.new(1.4, 5, 1.4) }):Play()
	Debris:AddItem(spike, 1.7)
	-- Esquirlas
	local holder = Instance.new("Part")
	holder.Name = "Esquirlas"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos + Vector3.new(0, 1, 0)
	holder.Parent = folder
	local shards = Instance.new("ParticleEmitter")
	shards.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	shards.Color = ColorSequence.new(ICE, Color3.new(1, 1, 1))
	shards.LightEmission = 0.8
	shards.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	shards.Lifetime = NumberRange.new(0.5, 1)
	shards.Speed = NumberRange.new(14, 26)
	shards.SpreadAngle = Vector2.new(70, 70)
	shards.Acceleration = Vector3.new(0, -40, 0)
	shards.Rate = 0
	shards.Parent = holder
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	mist.Lifetime = NumberRange.new(0.8, 1.4)
	mist.Speed = NumberRange.new(5, 10)
	mist.SpreadAngle = Vector2.new(80, 10)
	mist.Rate = 0
	mist.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = FROST
	light.Range = 12
	light.Brightness = 3
	light.Parent = holder
	pcall(function()
		shards:Emit(30)
		mist:Emit(10)
	end)
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 1.6)
	-- Anillo de escarcha en el piso
	local ring = Instance.new("Part")
	ring.Name = "Escarcha"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Ice
	ring.Color = Color3.fromRGB(220, 240, 255)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.1, 2, 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	local r = cfg().Icicles.Radius * 2
	TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = Vector3.new(0.1, r, r) }):Play()
	TweenService:Create(ring, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	Debris:AddItem(ring, 2.6)
end

local function spawnIcicles(targets: { PlayerData.Target })
	local c = cfg().Icicles
	if #targets == 0 then
		return
	end
	local count = c.Count + (if #targets >= 3 then 1 else 0)
	for i = 1, count do
		local t = targets[rng:NextInteger(1, #targets)]
		-- El primero va justo donde estás parado (hay que moverse); el resto alrededor
		local dist = if i == 1 then 0 else range(c.Offset)
		local angle = rng:NextNumber(0, math.pi * 2)
		local p = flat(t.root.Position) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
		Hazards.warn(p, c.Radius, c.Warn, c.Damage, nil, WARN, "Carámbano") -- rojo fuerte: el celeste no se ve en la nieve
		table.insert(pending, { pos = p, at = clock + c.Warn })
	end
end

local function updateIcicles(targets: { PlayerData.Target })
	local c = cfg().Icicles
	for i = #pending, 1, -1 do
		local v = pending[i]
		if clock >= v.at then
			table.remove(pending, i)
			local ground = v.pos + Vector3.new(0, Ground.y(v.pos.X, v.pos.Z), 0)
			shatterFx(ground)
			for _, t in targets do
				if (flat(t.root.Position) - v.pos).Magnitude <= c.Radius then
					Chill.add(t.player, c.ChillStacks)
				end
			end
			for _, e in Enemies.list do
				if e.alive and not e.hidden and e.part and e.part.Parent
					and (flat(e.part.Position) - v.pos).Magnitude <= c.Radius + (e.radius or 0) * 0.5 then
					Enemies.damage(e, e.maxHealth * (if e.isBoss then c.BossFrac else c.EnemyFrac), nil, "hit")
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Ventisca
---------------------------------------------------------------------

local function tip(key: string)
	if tipsShown[key] then
		return
	end
	tipsShown[key] = true
	Remotes.GameState:SetAttribute("GlacierTip", string.format("%s|%.3f", key, workspace:GetServerTimeNow()))
end

local function publishNext()
	Remotes.GameState:SetAttribute("BlizzardNext", if blizzardReady then workspace:GetServerTimeNow() + (nextBlizzard - clock) else 0)
end

local function publishBlizzard(text: string)
	Remotes.GameState:SetAttribute("Blizzard", text)
end

local function startBlizzard()
	local c = cfg().Blizzard
	local now = workspace:GetServerTimeNow()
	local a = rng:NextNumber(0, math.pi * 2)
	blizzardStart = clock + c.Warn
	blizzardEnd = blizzardStart + c.Duration
	table.clear(blizzardChill)
	publishBlizzard(string.format("%.3f|%.3f|%.3f|%.3f", now + c.Warn, now + c.Warn + c.Duration, math.cos(a), math.sin(a)))
end

local function updateBlizzard(targets: { PlayerData.Target })
	if blizzardEnd == 0 then
		return
	end
	if clock >= blizzardEnd then
		blizzardEnd = 0
		publishBlizzard("")
		return
	end
	if clock < blizzardStart then
		return
	end
	local c = cfg().Blizzard
	for _, t in targets do
		if not Chill.isWarm(t.root.Position) then
			local nextAt = blizzardChill[t.player] or (clock + c.ChillEvery)
			if clock >= nextAt then
				Chill.add(t.player, 1)
				nextAt = clock + c.ChillEvery
			end
			blizzardChill[t.player] = nextAt
		end
	end
end

---------------------------------------------------------------------
-- API (la usa MapEvents)
---------------------------------------------------------------------

function GlacierEvents.reset(theme: string?, propsFolder: Instance?)
	GlacierEvents.clear()
	Chill.setTheme(theme)
	enabled = theme == "glacier" and cfg() ~= nil
	if enabled and propsFolder then
		placeCampfires(propsFolder)
		borderForest(propsFolder)
	end
end

function GlacierEvents.clear()
	enabled = false
	table.clear(pending)
	table.clear(blizzardChill)
	blizzardEnd = 0
	nextIcicle = 0
	nextBlizzard = 0
	inWave = false
	blizzardReady = false
	table.clear(tipsShown)
	Remotes.GameState:SetAttribute("GlacierTip", "")
	Remotes.GameState:SetAttribute("BlizzardNext", 0)
	if Remotes.GameState:GetAttribute("Blizzard") then
		publishBlizzard("")
	end
	Chill.clear()
end

function GlacierEvents.update(dt: number, targets: { PlayerData.Target }, phase: string)
	clock += dt
	Chill.update(dt, targets)
	if not enabled then
		return
	end
	local c = cfg()
	updateIcicles(targets)
	updateBlizzard(targets)
	if phase ~= "Wave" then
		inWave = false
		return
	end
	local wave = (Remotes.GameState:GetAttribute("Wave") :: number?) or 1
	local icicles = wave >= (c.Icicles.FromWave or 1)
	if not inWave then
		inWave = true
		tip("cold") -- primera oleada: frío y fogatas
		nextIcicle = clock + c.FirstDelay + (if icicles and not tipsShown.icicles then 3 else 0)
		if icicles then
			tip("icicles")
		end
		if wave >= (c.Blizzard.FromWave or 1) then
			if not blizzardReady then
				blizzardReady = true
				tip("blizzard")
				nextBlizzard = clock + 14 -- la primera, poco después del cartel
			end
			publishNext()
		end
	end
	if icicles and clock >= nextIcicle then
		spawnIcicles(targets)
		nextIcicle = clock + range(c.Icicles.Every)
	end
	if blizzardReady and blizzardEnd == 0 and clock >= nextBlizzard then
		startBlizzard()
		nextBlizzard = clock + c.Blizzard.Warn + c.Blizzard.Duration + range(c.Blizzard.Every)
		publishNext()
	end
end

-- Para pruebas
GlacierEvents._forceIcicles = spawnIcicles
GlacierEvents._forceBlizzard = startBlizzard
function GlacierEvents._pending(): number
	return #pending
end

return GlacierEvents
