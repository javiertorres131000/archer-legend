--!strict
-- Hearts (ModuleScript)
-- Ubicación: ServerScriptService > Server > Hearts
-- Corazones de vida: a veces un enemigo suelta uno al morir (los jefes, varios). El jugador que
-- pasa cerca y no tiene la vida llena lo junta y se cura. Duran un rato y antes de desaparecer
-- titilan. Valores en Config.Hearts. Lo decide todo el servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)

local Cfg = Config.Hearts

type Heart = { part: BasePart, label: TextLabel, pos: Vector3, born: number }

local Hearts = {}
local list: { Heart } = {}
local folder: Folder? = nil
local ROJO = Color3.fromRGB(255, 50, 80)

local function getFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Hearts"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function crear(pos: Vector3): Heart
	local part = Instance.new("Part")
	part.Name = "Heart"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 1.6
	part.Material = Enum.Material.Neon
	part.Color = ROJO
	part.Transparency = 0.35
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Position = pos + Vector3.new(0, 1.6, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 4)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "❤"
	label.TextScaled = true
	label.TextColor3 = ROJO
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	local luz = Instance.new("PointLight")
	luz.Color, luz.Range, luz.Brightness = ROJO, 10, 1.5
	luz.Parent = part
	local brillo = Instance.new("ParticleEmitter")
	brillo.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	brillo.Color = ColorSequence.new(ROJO)
	brillo.LightEmission, brillo.Rate = 1, 6
	brillo.Lifetime = NumberRange.new(0.6, 1)
	brillo.Speed = NumberRange.new(1, 2)
	brillo.Size = NumberSequence.new(0.4, 0)
	brillo.Parent = part
	part.Parent = getFolder()
	return { part = part, label = label, pos = part.Position, born = os.clock() }
end

-- Al morir un enemigo: quizás suelta corazones. pos: apoyado en el piso.
function Hearts.maybeDrop(pos: Vector3, isBoss: boolean, summoned: boolean)
	if summoned and not Cfg.FromSummons then
		return
	end
	local cuantos = if isBoss then Cfg.BossCount elseif math.random() < Cfg.Chance then 1 else 0
	for i = 1, cuantos do
		local off = if cuantos > 1 then Vector3.new(math.cos(i * 2.1), 0, math.sin(i * 2.1)) * 4 else Vector3.zero
		table.insert(list, crear(pos + off))
	end
end

-- Cada frame: flotan, titilan antes de irse y los junta el que pase cerca y esté herido.
function Hearts.update(collectors: { PlayerData.Target })
	local now = os.clock()
	for i = #list, 1, -1 do
		local h = list[i]
		local age = now - h.born
		if age > Cfg.Lifetime then
			h.part:Destroy()
			table.remove(list, i)
			continue
		end
		h.part.Position = h.pos + Vector3.new(0, math.sin(now * 3 + h.born) * 0.4, 0)
		local queda = Cfg.Lifetime - age
		h.label.TextTransparency = if queda < 3 and math.floor(now * 8) % 2 == 0 then 0.8 else 0
		for _, c in collectors do
			local hum = c.humanoid
			local d = c.root.Position - h.pos
			if hum.Health > 0 and hum.Health < hum.MaxHealth and d.X * d.X + d.Z * d.Z <= Cfg.PickupRadius ^ 2 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * Cfg.HealFraction)
				h.part:Destroy()
				table.remove(list, i)
				break
			end
		end
	end
end

-- Fin de partida: sin corazones.
function Hearts.clear()
	for _, h in list do
		h.part:Destroy()
	end
	table.clear(list)
end

return Hearts
