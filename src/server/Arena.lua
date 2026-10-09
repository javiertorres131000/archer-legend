-- Arena (ModuleScript)
-- Ubicación: ServerScriptService > Server > Arena
-- La arena es una "sala": piso, paredes, decoración, puerta y entrada.
-- Cada oleada se juega en una sala distinta: al terminarla se abre la puerta del norte y,
-- cuando el equipo entra, se arma la sala siguiente y aparecen en la entrada del sur.
--
-- Decoración de las salas:
--   · Si en ServerStorage > Rooms > <Id del capítulo> (por ejemplo Rooms > forest) hay
--     Models hechos a mano en Studio, se usan esos (uno por sala, en orden).
--   · Si no, se genera por código según el Theme del capítulo (árboles, columnas, braseros...).
-- La decoración va pegada a las paredes: el centro queda libre para pelear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ArenaCfg = Config.Arena
local RoomCfg = Config.Rooms

local Arena = {}

-- Mitad del tamaño del piso: los límites jugables son -Half..+Half en X y Z.
Arena.Half = ArenaCfg.Size / 2

local folder: Folder
local roomFolder: Folder
local floor: Part? = nil
local walls: { Part } = {}
local door: Model? = nil

local GOLD = Color3.fromRGB(212, 168, 70)

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Arena.build()
	-- Sacamos el piso y el spawn de la plantilla "Baseplate" si existen.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	roomFolder = Instance.new("Folder")
	roomFolder.Name = "Room"
	roomFolder.Parent = folder

	local half = Arena.Half
	-- El piso queda con la cara de arriba en Y = 0.
	floor = makePart(folder, "Floor", ArenaCfg.Size, CFrame.new(0, -ArenaCfg.Size.Y / 2, 0), Color3.fromRGB(70, 90, 70))

	local wallColor = Color3.fromRGB(60, 60, 70)
	local h = ArenaCfg.WallHeight
	walls = {
		makePart(folder, "WallN", Vector3.new(ArenaCfg.Size.X + 2, h, 1), CFrame.new(0, h / 2, -half.Z - 0.5), wallColor),
		makePart(folder, "WallS", Vector3.new(ArenaCfg.Size.X + 2, h, 1), CFrame.new(0, h / 2, half.Z + 0.5), wallColor),
		makePart(folder, "WallW", Vector3.new(1, h, ArenaCfg.Size.Z), CFrame.new(-half.X - 0.5, h / 2, 0), wallColor),
		makePart(folder, "WallE", Vector3.new(1, h, ArenaCfg.Size.Z), CFrame.new(half.X + 0.5, h / 2, 0), wallColor),
	}
	-- Sin SpawnLocation: se aparece en el lobby y MatchManager trae a los participantes acá.
end

-- Puntos de aparición en la entrada (sur), en fila, mirando hacia la puerta (norte).
function Arena.spawnPoints(count: number): { CFrame }
	local points = {}
	local z = Arena.Half.Z - RoomCfg.EntranceDistance
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 5
		local pos = Vector3.new(x, 3, z)
		points[i] = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	end
	return points
end

-- Colores base del capítulo.
function Arena.setTheme(floorColor: Color3, wallColor: Color3)
	if floor then
		floor.Color = floorColor
	end
	for _, w in walls do
		w.Color = wallColor
	end
end

---------------------------------------------------------------------
-- Decoración generada por código
---------------------------------------------------------------------

-- Un punto al azar en la franja pegada a las paredes (el centro queda libre).
local function edgePoint(rng: Random): Vector3
	local half = Arena.Half
	local band = RoomCfg.PropBand
	local side = rng:NextInteger(1, 4)
	local along = rng:NextNumber(-1, 1)
	local inset = rng:NextNumber(2, band)
	local x, z
	if side == 1 then
		x, z = along * (half.X - 4), -half.Z + inset
	elseif side == 2 then
		x, z = along * (half.X - 4), half.Z - inset
	elseif side == 3 then
		x, z = -half.X + inset, along * (half.Z - 4)
	else
		x, z = half.X - inset, along * (half.Z - 4)
	end
	-- La puerta (norte) y la entrada (sur) quedan despejadas
	if math.abs(x) < 10 and math.abs(z) > half.Z - band - 2 then
		x += if x < 0 then -12 else 12
	end
	return Vector3.new(x, 0, z)
end

local Props = {}

Props.forest = function(parent: Instance, pos: Vector3, rng: Random)
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then -- árbol
		local h = rng:NextNumber(8, 13)
		makePart(parent, "Trunk", Vector3.new(1.6, h, 1.6), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(92, 62, 40), Enum.Material.Wood)
		local canopy = makePart(parent, "Canopy", Vector3.one * rng:NextNumber(6, 9), CFrame.new(pos + Vector3.new(0, h + 1, 0)), Color3.fromRGB(46, 96, 52), Enum.Material.Grass)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
	elseif kind == 2 then -- roca
		local s = rng:NextNumber(2.5, 5)
		makePart(parent, "Rock", Vector3.new(s, s * 0.7, s * 1.2), CFrame.new(pos + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(110, 110, 105), Enum.Material.Rock)
	else -- arbusto
		local bush = makePart(parent, "Bush", Vector3.one * rng:NextNumber(2.5, 4), CFrame.new(pos + Vector3.new(0, 1.2, 0)), Color3.fromRGB(60, 120, 60), Enum.Material.Grass)
		bush.Shape = Enum.PartType.Ball
	end
end

Props.ruins = function(parent: Instance, pos: Vector3, rng: Random)
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then -- columna rota
		local h = rng:NextNumber(3, 11)
		makePart(parent, "Column", Vector3.new(3, h, 3), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(150, 145, 130), Enum.Material.Limestone)
	elseif kind == 2 then -- escombros
		for _ = 1, 3 do
			local s = rng:NextNumber(0.8, 2)
			makePart(parent, "Rubble", Vector3.one * s, CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), s / 2, rng:NextNumber(-2, 2))) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Color3.fromRGB(130, 125, 115), Enum.Material.Cobblestone)
		end
	else -- tumba
		makePart(parent, "Tomb", Vector3.new(2.5, 3.5, 1), CFrame.new(pos + Vector3.new(0, 1.75, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(100, 100, 110), Enum.Material.Slate)
	end
end

Props.fortress = function(parent: Instance, pos: Vector3, rng: Random)
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then -- brasero con fuego
		makePart(parent, "Brazier", Vector3.new(2.4, 3, 2.4), CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(50, 40, 40), Enum.Material.Metal)
		local flame = makePart(parent, "Flame", Vector3.one * 1.8, CFrame.new(pos + Vector3.new(0, 3.6, 0)), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Range = 14
		light.Parent = flame
	elseif kind == 2 then -- púas de obsidiana
		local h = rng:NextNumber(4, 9)
		makePart(parent, "Spike", Vector3.new(1.6, h, 1.6), CFrame.new(pos + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), Color3.fromRGB(30, 22, 30), Enum.Material.Basalt)
	else -- charco de lava (solo decoración, no daña)
		local lava = makePart(parent, "Lava", Vector3.new(0.2, rng:NextNumber(5, 8), rng:NextNumber(5, 8)), CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 90, 20), Enum.Material.Neon)
		lava.Shape = Enum.PartType.Cylinder
		lava.CanCollide = false
	end
end

-- Variación de color por sala para que se note el cambio
local function shade(color: Color3, rng: Random): Color3
	local k = rng:NextNumber(0.8, 1.15)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

-- Arma la sala `roomIndex` del capítulo (borra la decoración anterior).
function Arena.buildRoom(chapter, roomIndex: number)
	roomFolder:ClearAllChildren()
	local rng = Random.new(math.floor(os.clock() * 1000) + roomIndex)
	Arena.setTheme(shade(chapter.Floor, rng), shade(chapter.Wall, rng))
	if floor then
		floor.Material = (RoomCfg.FloorMaterials :: any)[chapter.Theme] or Enum.Material.SmoothPlastic
	end

	-- ¿Hay salas hechas a mano para este capítulo?
	local custom = ServerStorage:FindFirstChild("Rooms")
	local set = custom and custom:FindFirstChild(chapter.Id)
	local models = {}
	if set then
		for _, child in set:GetChildren() do
			if child:IsA("Model") then
				table.insert(models, child)
			end
		end
		table.sort(models, function(a, b)
			return a.Name < b.Name
		end)
	end
	if #models > 0 then
		local model = models[(roomIndex - 1) % #models + 1]:Clone()
		model.Parent = roomFolder
		return
	end

	local builder = Props[chapter.Theme]
	if builder then
		for _ = 1, RoomCfg.PropsPerRoom do
			builder(roomFolder, edgePoint(rng), rng)
		end
	end
end

---------------------------------------------------------------------
-- Puerta
---------------------------------------------------------------------

-- Centro de la zona de la puerta (al pie de la pared norte).
function Arena.doorPosition(): Vector3
	return Vector3.new(0, 0, -Arena.Half.Z + 4)
end

-- ¿Este punto está dentro de la zona de la puerta?
function Arena.inDoorZone(pos: Vector3): boolean
	local d = Vector3.new(pos.X, 0, pos.Z) - Arena.doorPosition()
	return d.Magnitude <= RoomCfg.DoorRadius
end

function Arena.openDoor()
	Arena.closeDoor()
	local model = Instance.new("Model")
	model.Name = "Door"
	local base = Vector3.new(0, 0, -Arena.Half.Z + 0.6)
	local h = 11
	makePart(model, "PostL", Vector3.new(1.5, h, 1.5), CFrame.new(base + Vector3.new(-5, h / 2, 0)), GOLD, Enum.Material.Metal)
	makePart(model, "PostR", Vector3.new(1.5, h, 1.5), CFrame.new(base + Vector3.new(5, h / 2, 0)), GOLD, Enum.Material.Metal)
	makePart(model, "Lintel", Vector3.new(11.5, 1.5, 1.5), CFrame.new(base + Vector3.new(0, h + 0.75, 0)), GOLD, Enum.Material.Metal)
	local portal = makePart(model, "Portal", Vector3.new(8.5, h, 0.4), CFrame.new(base + Vector3.new(0, h / 2, 0.4)), Color3.fromRGB(255, 215, 120), Enum.Material.Neon)
	portal.Transparency = 0.35
	portal.CanCollide = false
	-- Marca en el piso de dónde hay que pararse
	local pad = makePart(model, "Pad", Vector3.new(0.1, RoomCfg.DoorRadius * 2, RoomCfg.DoorRadius * 2), CFrame.new(Arena.doorPosition() + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon)
	pad.Shape = Enum.PartType.Cylinder
	pad.Transparency = 0.6
	pad.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 26
	light.Brightness = 3
	light.Parent = portal

	-- Cartel visible a través de las paredes, para encontrarla en primera persona
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(160, 40)
	sign.StudsOffset = Vector3.new(0, 3, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 1000
	sign.Parent = portal
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "▶ PUERTA"
	label.Font = Enum.Font.Fondamento
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(255, 220, 130)
	label.TextStrokeTransparency = 0.3
	label.Parent = sign

	model.Parent = folder
	door = model
end

function Arena.closeDoor()
	if door then
		door:Destroy()
		door = nil
	end
end

return Arena
