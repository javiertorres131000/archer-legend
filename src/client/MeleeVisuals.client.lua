-- MeleeVisuals (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > MeleeVisuals
-- Dibuja los golpes cuerpo a cuerpo y los poderes que avisa el servidor (Remotes.MeleeSwing):
--   · Espada: una media luna brillante que barre el arco del golpe (360° = Torbellino).
--   · Puños: un destello corto delante del jugador.
--   · "Rain": una flecha que cae del cielo (Lluvia de flechas).
--   · "Judgment": una espada gigante que cae y una onda en el piso (Juicio).
--   · "Burst": un anillo de energía alrededor del jugador (Ráfaga de mil puños).
-- Es solo visual: el daño ya lo calculó el servidor.
-- Las armas con estilo anime (campo Fx en Shared/Weapons.lua) las dibuja AnimeFx, no este script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local FxStyles = require(Shared:WaitForChild("FxStyles"))

-- ¿Lo dibuja AnimeFx? (el arma tiene un estilo anime)
local function hasAnimeFx(weaponId: string): boolean
	local def = Weapons.ById[weaponId]
	return def ~= nil and FxStyles.get(def.Fx) ~= nil
end
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MeleeSwing") :: RemoteEvent

local low = FxQuality.isLow()
local folder = Instance.new("Folder")
folder.Name = "MeleeFx"
folder.Parent = workspace

local COLORS = {
	Sword = Color3.fromRGB(200, 230, 255),
	Fists = Color3.fromRGB(255, 190, 110),
}

local function piece(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Transparency = 0.15
	p.Parent = folder
	return p
end

local function fade(p: BasePart, time: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = p.Size + grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.05)
end

local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SOUNDS = {
	SwordSwing = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.55, Pitch = { 1.05, 1.3 } },
	SwordRing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.35, Pitch = { 1.3, 1.5 } },
	Punch = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.5, Pitch = { 0.55, 0.7 } },
	PunchThud = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7, Pitch = { 0.8, 1.0 } },
}

-- Sonido en un punto del mundo (se oye más fuerte cerca)
local function playAt(pos: Vector3, name: string, volumeMult: number?)
	local def = SOUNDS[name]
	local holder = Instance.new("Attachment")
	holder.WorldPosition = pos
	holder.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (volumeMult or 1)
	sound.PlaybackSpeed = def.Pitch[1] + math.random() * (def.Pitch[2] - def.Pitch[1])
	sound.RollOffMaxDistance = 120
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 2)
end

-- Ráfaga de partículas de una sola vez
local function emitAt(pos: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?)
	if low then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or SPARK_TEX
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.2, 0.4)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 0.6)
end

local function flash(pos: Vector3, color: Color3, range: number)
	if low then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 4
	l.Parent = a
	TweenService:Create(l, TweenInfo.new(0.18), { Brightness = 0 }):Play()
	Debris:AddItem(a, 0.25)
end

-- Espada: media luna doble (núcleo blanco y filo de color) que barre el arco, chispas en la
-- punta del recorrido, destello y silbido del tajo.
local function sword(origin: Vector3, dir: Vector3, range: number, arc: number)
	local color = COLORS.Sword
	local segments = if low then 6 else 14
	local radius = range * 0.75
	local base = math.atan2(dir.X, dir.Z)
	local half = math.rad(arc / 2)
	local flip = math.random() < 0.5 -- alterna de qué lado arranca, como un combo
	local height = 0.6 + math.random() * 0.8
	for i = 0, segments do
		local t = i / segments
		local k = if flip then 1 - t else t
		local angle = base - half + k * 2 * half
		local out = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local pos = origin + out * radius + Vector3.new(0, height, 0)
		local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
		local length = radius * 2 * half / segments + 0.5
		-- más grueso en el medio del barrido
		local thick = 0.5 + math.sin(t * math.pi) * 0.9
		local core = piece(Vector3.new(0.18, thick * 0.55, length), CFrame.lookAt(pos, pos + tangent), Color3.new(1, 1, 1))
		local edge = piece(Vector3.new(0.12, thick * 1.3, length), CFrame.lookAt(pos + out * 0.35, pos + out * 0.35 + tangent), color)
		edge.Transparency = 1
		core.Transparency = 1
		task.delay(t * 0.07, function()
			core.Transparency = 0
			edge.Transparency = 0.35
			fade(core, 0.16)
			fade(edge, 0.24, Vector3.new(0, 0.4, 0))
		end)
	end
	local tip = origin + Vector3.new(math.sin(base + (if flip then -half else half)), 0, math.cos(base + (if flip then -half else half))) * radius + Vector3.new(0, height, 0)
	task.delay(0.07, function()
		emitAt(tip, color, 14, 26, 0.35)
	end)
	flash(origin + dir * radius * 0.6 + Vector3.new(0, 2, 0), color, 14)
	playAt(origin, "SwordSwing")
	playAt(origin, "SwordRing", 0.6)
end

-- Puños: golpe con onda expansiva delante, anillo en el aire, chispas y polvo, y un golpe seco.
local function fists(origin: Vector3, dir: Vector3, range: number)
	local color = COLORS.Fists
	local side = dir:Cross(Vector3.yAxis).Unit * (if math.random() < 0.5 then 0.8 else -0.8)
	local pos = origin + dir * range * 0.6 + side + Vector3.new(0, 0.8, 0)
	local core = piece(Vector3.one * 1.1, CFrame.new(pos), Color3.new(1, 1, 1), Enum.PartType.Ball)
	core.Transparency = 0
	fade(core, 0.12, Vector3.one * 1.6)
	local glow = piece(Vector3.one * 1.6, CFrame.new(pos), color, Enum.PartType.Ball)
	glow.Transparency = 0.3
	fade(glow, 0.2, Vector3.one * 3.2)
	-- Anillo de choque mirando hacia adelante
	local ring = piece(Vector3.new(0.15, 1.2, 1.2), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0), color, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	fade(ring, 0.22, Vector3.new(0, 4.5, 4.5))
	emitAt(pos, color, 12, 22, 0.3)
	emitAt(pos, Color3.fromRGB(200, 190, 175), 5, 6, 1.4, SMOKE_TEX)
	flash(pos, color, 10)
	playAt(pos, "Punch")
	playAt(pos, "PunchThud", 0.8)
end

local function rain(pos: Vector3)
	local color = Color3.fromRGB(255, 230, 120)
	local arrow = piece(Vector3.new(0.35, 4, 0.35), CFrame.new(pos + Vector3.new(0, 28, 0)), color)
	TweenService:Create(arrow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) }):Play()
	task.delay(0.22, function()
		fade(arrow, 0.15)
		local ring = piece(Vector3.new(0.2, 3, 3), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		fade(ring, 0.25, Vector3.new(0, 3, 3))
	end)
end

local function judgment(pos: Vector3, radius: number)
	local color = Color3.fromRGB(255, 240, 200)
	local blade = piece(Vector3.new(1.5, 18, 4), CFrame.new(pos + Vector3.new(0, 40, 0)), color)
	TweenService:Create(blade, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) }):Play()
	task.delay(0.3, function()
		fade(blade, 0.5)
		local ring = piece(Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		fade(ring, 0.4, Vector3.new(0, radius * 2, radius * 2))
	end)
end

local function burst(pos: Vector3, radius: number)
	local ring = piece(Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), COLORS.Fists, Enum.PartType.Cylinder)
	fade(ring, 0.5, Vector3.new(0, radius * 2, radius * 2))
end

-- Arma de quien lanzó el poder (el Juicio de una espada especial lo dibuja AnimeFx)
local function weaponOf(userId: any): string
	local owner = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	local id = owner and owner:GetAttribute("Weapon")
	return if type(id) == "string" then id else "Sword"
end

-- Predicción del golpe propio: con espada o puños comunes, el tajo se dibuja y suena apenas
-- hacés click (sin esperar la ida y vuelta al servidor). El aviso del servidor de ese mismo golpe
-- se saltea. Es solo visual: el daño lo sigue decidiendo el servidor.
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
local skipEchoUntil = 0
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or localPlayer:GetAttribute("InMatch") ~= true then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.KeyCode ~= Enum.KeyCode.ButtonR2 then
		return
	end
	local weaponId = weaponOf(localPlayer.UserId)
	local def = Weapons.ById[weaponId]
	if not def or def.Kind ~= "Melee" or hasAnimeFx(weaponId) then
		return
	end
	if os.clock() < skipEchoUntil then
		return -- todavía no terminó el golpe anterior
	end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local dir = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local range = def.Range or 10
	if weaponId == "Fists" then
		fists(root.Position, dir, range)
	else
		sword(root.Position, dir, range, def.Arc or 120)
	end
	skipEchoUntil = os.clock() + 0.35
end)

remote.OnClientEvent:Connect(function(userId, origin, dir, range, arc, weaponId)
	if weaponId == "Rain" and typeof(origin) == "Vector3" then
		rain(origin)
		return
	elseif weaponId == "Judgment" and typeof(origin) == "Vector3" then
		if hasAnimeFx(weaponOf(userId)) then
			return
		end
		judgment(origin, if type(range) == "number" then range else 10)
		return
	elseif weaponId == "Burst" and typeof(origin) == "Vector3" then
		burst(origin, if type(range) == "number" then range else 6)
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or type(range) ~= "number" then
		return
	end
	if type(weaponId) == "string" and hasAnimeFx(weaponId) then
		return
	end
	-- Nuestro golpe ya se dibujó al hacer click (predicción): se saltea este aviso
	if userId == localPlayer.UserId and os.clock() < skipEchoUntil then
		skipEchoUntil = 0
		return
	end
	if weaponId == "Fists" then
		fists(origin, dir, range)
	else
		sword(origin, dir, range, if type(arc) == "number" then arc else 120)
	end
end)
