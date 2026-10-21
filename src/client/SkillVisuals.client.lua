-- SkillVisuals (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > SkillVisuals
-- Dibuja los efectos de las habilidades nuevas que avisa el servidor (Remotes.SkillFx, lo manda
-- Server/SkillEffects). Solo visual: el daño ya lo calculó el servidor.
--   "Chain"  (desde, hasta)   rayo en zigzag entre dos enemigos
--   "Blast"  (centro, radio, color) explosión: esfera que crece y se desvanece
--   "Wave"   (centro, radio, color) onda en el piso (golpe sísmico)
--   "Blades" (centro, radio)  tres espadas espectrales que giran
--   "Dragon" (origen, dirección, largo) puño gigante y onda en cono
--   "Shield" (posición)       burbuja que se rompe (escudo de maná)
--   "Dodge"  (posición)       destello y "¡ESQUIVA!" (solo si es cerca tuyo)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkillFx") :: RemoteEvent

local low = FxQuality.isLow()
local folder = Instance.new("Folder")
folder.Name = "SkillFx"
folder.Parent = workspace

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

local function fade(p: BasePart, time: number, goal: { [string]: any }?)
	local g = goal or {}
	g.Transparency = 1
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), g):Play()
	Debris:AddItem(p, time + 0.05)
end

local function chain(from: Vector3, to: Vector3)
	local color = Color3.fromRGB(160, 220, 255)
	local segments = if low then 3 else 6
	local prev = from + Vector3.new(0, 1.5, 0)
	local finish = to + Vector3.new(0, 1.5, 0)
	for i = 1, segments do
		local t = i / segments
		local point = from:Lerp(to, t) + Vector3.new(0, 1.5, 0)
		if i < segments then
			point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.2
		else
			point = finish
		end
		local len = (point - prev).Magnitude
		local p = piece(Vector3.new(0.18, 0.18, len), CFrame.lookAt((prev + point) / 2, point), color)
		fade(p, 0.18)
		prev = point
	end
	local spark = piece(Vector3.one * 1.4, CFrame.new(finish), color, Enum.PartType.Ball)
	fade(spark, 0.2, { Size = Vector3.one * 2.6 })
end

local function blastFx(center: Vector3, radius: number, color: Color3)
	local ball = piece(Vector3.one * 1, CFrame.new(center + Vector3.new(0, 1, 0)), color, Enum.PartType.Ball)
	ball.Transparency = 0.3
	fade(ball, 0.28, { Size = Vector3.one * radius * 2 })
	if not low then
		local ring = piece(Vector3.new(0.2, 1, 1), CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		fade(ring, 0.35, { Size = Vector3.new(0.2, radius * 2.4, radius * 2.4) })
	end
end

local function wave(center: Vector3, radius: number, color: Color3)
	local ring = piece(Vector3.new(0.4, 2, 2), CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	fade(ring, 0.45, { Size = Vector3.new(0.4, radius * 2, radius * 2) })
	if not low then
		for i = 1, 8 do
			local a = math.rad(i * 45 + math.random(0, 20))
			local pos = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.6
			local rock = piece(Vector3.new(0.8, 0.8, 0.8), CFrame.new(pos) * CFrame.Angles(math.random(), math.random(), math.random()), Color3.fromRGB(120, 100, 85))
			rock.Material = Enum.Material.Slate
			rock.Transparency = 0
			TweenService:Create(rock, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rock.CFrame + Vector3.new(0, 2.2, 0) }):Play()
			task.delay(0.25, function()
				fade(rock, 0.25, { CFrame = rock.CFrame - Vector3.new(0, 2.2, 0) })
			end)
		end
	end
end

local function blades(center: Vector3, radius: number)
	local color = Color3.fromRGB(200, 230, 255)
	local start = math.random() * math.pi * 2
	for i = 0, 2 do
		local a0 = start + i * math.pi * 2 / 3
		local blade = piece(Vector3.new(0.25, 0.5, 3.2), CFrame.new(center), color)
		local steps = if low then 4 else 8
		for s = 0, steps do
			task.delay(s * 0.04, function()
				if blade.Parent then
					local a = a0 + s * 0.35
					local pos = center + Vector3.new(math.cos(a), 0.6, math.sin(a)) * radius * 0.8
					blade.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
				end
			end)
		end
		task.delay(steps * 0.04, function()
			fade(blade, 0.12)
		end)
	end
end

local function dragon(origin: Vector3, dir: Vector3, length: number)
	local color = Color3.fromRGB(255, 120, 40)
	local fist = piece(Vector3.new(3, 3, 3), CFrame.new(origin + Vector3.new(0, 1.5, 0)), color, Enum.PartType.Ball)
	TweenService:Create(fist, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(origin + dir * length * 0.8 + Vector3.new(0, 1.5, 0)), Size = Vector3.one * 5 }):Play()
	Debris:AddItem(fist, 0.4)
	task.delay(0.25, function()
		fade(fist, 0.12)
	end)
	-- Cono: varias medias lunas que se abren
	for i = 1, (if low then 3 else 6) do
		task.delay(i * 0.035, function()
			local d = length * i / 6
			local pos = origin + dir * d + Vector3.new(0, 0.6, 0)
			local width = 2 + d * 0.7
			local slab = piece(Vector3.new(width, 0.3, 1.2), CFrame.lookAt(pos, pos + dir), Color3.fromRGB(255, 200, 90))
			fade(slab, 0.3)
		end)
	end
end

local function shield(pos: Vector3)
	local bubble = piece(Vector3.one * 6, CFrame.new(pos), Color3.fromRGB(120, 170, 255), Enum.PartType.Ball)
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 0
	fade(bubble, 0.4, { Size = Vector3.one * 9 })
end

local function dodge(pos: Vector3)
	local ghost = piece(Vector3.new(2, 5, 1), CFrame.new(pos), Color3.fromRGB(220, 240, 255))
	ghost.Transparency = 0.5
	fade(ghost, 0.25, { CFrame = CFrame.new(pos + Vector3.new(0, 0, 0)) * CFrame.new(1.5, 0, 0) })
end

remote.OnClientEvent:Connect(function(kind: any, pos: any, a: any, b: any)
	if typeof(pos) ~= "Vector3" then
		return
	end
	if kind == "Chain" and typeof(a) == "Vector3" then
		chain(pos, a)
	elseif kind == "Blast" then
		blastFx(pos, if type(a) == "number" then a else 4, if typeof(b) == "Color3" then b else Color3.fromRGB(255, 150, 60))
	elseif kind == "Wave" then
		wave(pos, if type(a) == "number" then a else 8, if typeof(b) == "Color3" then b else Color3.fromRGB(255, 190, 110))
	elseif kind == "Blades" then
		blades(pos, if type(a) == "number" then a else 8)
	elseif kind == "Dragon" and typeof(a) == "Vector3" then
		dragon(pos, a, if type(b) == "number" then b else 20)
	elseif kind == "Shield" then
		shield(pos)
	elseif kind == "Dodge" then
		dodge(pos)
	end
end)
