-- Arena (ModuleScript)
-- Ubicación: ServerScriptService > Server > Arena
-- El mapa de la partida: bordes, piso de seguridad, terreno con relieve y decoración
-- (los arma MapBuilder), puntos de aparición en el centro y, opcionalmente, la puerta.
--
-- Mapa abierto (Config.Waves.UseDoors = false, lo normal): un mapa grande por partida.
-- Con puertas: al terminar cada oleada se abre la puerta del norte y, cuando entra el equipo,
-- se genera un mapa nuevo.
--
-- Mapas hechos a mano: ServerStorage > Maps > <Id del capítulo> (ver MapBuilder y el README).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ArenaCfg = Config.Arena
local RoomCfg = Config.Rooms
local MapBuilder = require(script.Parent.MapBuilder)
local Ground = require(script.Parent.Ground)

local Arena = {}

-- Mitad del tamaño del piso: los límites jugables son -Half..+Half en X y Z.
Arena.Half = ArenaCfg.Size / 2

local folder: Folder
local roomFolder: Folder
local floor: Part? = nil
local walls: { Part } = {}
local strips: { Part } = {} -- líneas neón en las paredes (color del capítulo)
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
	-- Piso de seguridad debajo del terreno (por si algo atraviesa el relieve). El terreno de
	-- verdad lo arma MapBuilder en cada partida.
	floor = makePart(folder, "Floor", ArenaCfg.Size, CFrame.new(0, -3 - ArenaCfg.Size.Y / 2, 0), Color3.fromRGB(70, 90, 70))

	local wallColor = Color3.fromRGB(60, 60, 70)
	local h = ArenaCfg.WallHeight
	local t = ArenaCfg.WallThickness or 10
	-- Arrancan 40 studs abajo del piso (por si el terreno tiene pozos junto al borde) y se cruzan en
	-- las esquinas para que no quede ninguna rendija.
	local y = h / 2 - 40
	walls = {
		makePart(folder, "WallN", Vector3.new(ArenaCfg.Size.X + 2 * t, h, t), CFrame.new(0, y, -half.Z - t / 2), wallColor),
		makePart(folder, "WallS", Vector3.new(ArenaCfg.Size.X + 2 * t, h, t), CFrame.new(0, y, half.Z + t / 2), wallColor),
		makePart(folder, "WallW", Vector3.new(t, h, ArenaCfg.Size.Z + 2 * t), CFrame.new(-half.X - t / 2, y, 0), wallColor),
		makePart(folder, "WallE", Vector3.new(t, h, ArenaCfg.Size.Z + 2 * t), CFrame.new(half.X + t / 2, y, 0), wallColor),
		-- Techo invisible: por más alto que se trepe, no se pasa por arriba
		makePart(folder, "Ceiling", Vector3.new(ArenaCfg.Size.X + 2 * t, t, ArenaCfg.Size.Z + 2 * t), CFrame.new(0, y + h / 2 + t / 2, 0), wallColor),
	}
	-- Paredes invisibles: el borde se ve como montañas; esto solo evita salirse trepando
	for _, w in walls do
		w.Transparency = 1
		w.CastShadow = false
	end
	-- Líneas neón arriba y abajo de cada pared: marcan el borde de la sala con el color del capítulo
	-- (en primera persona ayudan a orientarse, y con el bloom de la arena brillan).
	local neon = Color3.fromRGB(120, 255, 200)
	for _, w in (if Config.Effects.NeonStrips then walls else {}) :: { Part } do
		if w.Name == "Ceiling" then
			continue
		end
		for _, sy in { 0.15, 90 } do
			local strip = makePart(folder, "NeonStrip", Vector3.new(w.Size.X + 0.1, 0.3, w.Size.Z + 0.1), CFrame.new(w.Position.X, sy, w.Position.Z), neon, Enum.Material.Neon)
			strip.CanCollide = false
			table.insert(strips, strip)
		end
	end
	-- Sin SpawnLocation: se aparece en el lobby y MatchManager trae a los participantes acá.
end

-- ¿Este punto está afuera del mapa o se cayó debajo del piso?
function Arena.isOutside(pos: Vector3): boolean
	local half = Arena.Half
	return math.abs(pos.X) > half.X - 1 or math.abs(pos.Z) > half.Z - 1 or pos.Y < Ground.y(pos.X, pos.Z) - ArenaCfg.FallBelow
end

-- Red de seguridad: trae de vuelta a quien quedó afuera (trepando, con el dash, por un bug).
-- Lo pone sobre el terreno, a ReturnMargin del borde, quieto. Devuelve a cuántos movió.
function Arena.keepInside(roots: { BasePart }): number
	local half = Arena.Half
	local margin = ArenaCfg.ReturnMargin
	local moved = 0
	for _, root in roots do
		local pos = root.Position
		if Arena.isOutside(pos) then
			local x = math.clamp(pos.X, -half.X + margin, half.X - margin)
			local z = math.clamp(pos.Z, -half.Z + margin, half.Z - margin)
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(Ground.place(Vector3.new(x, 0, z), 4))
			moved += 1
		end
	end
	return moved
end

-- Puntos de aparición en el centro del mapa (zona plana), en fila, mirando al norte.
function Arena.spawnPoints(count: number): { CFrame }
	local points = {}
	local z = RoomCfg.EntranceDistance
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 5
		local pos = Vector3.new(x, Ground.y(x, z) + 3, z)
		points[i] = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	end
	return points
end

-- Altura del piso en (x, z) (la usan los demás módulos a través de Ground).
function Arena.groundY(x: number, z: number): number
	return Ground.y(x, z)
end

-- Colores base del capítulo.
function Arena.setTheme(floorColor: Color3, wallColor: Color3, accent: Color3?)
	if floor then
		floor.Color = floorColor
	end
	for _, w in walls do
		w.Color = wallColor
	end
	if accent then
		for _, s in strips do
			s.Color = accent
		end
	end
end

---------------------------------------------------------------------
-- Decoración generada por código
---------------------------------------------------------------------

local Props = {}
Arena.Props = Props

Props.forest = function(parent: Instance, pos: Vector3, rng: Random)
	-- Sin árboles (tapaban la vista en primera persona): rocas y arbustos
	if rng:NextNumber() < 0.5 then -- roca
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

Props.glacier = function(parent: Instance, pos: Vector3, rng: Random)
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then -- cristal de hielo
		local h = rng:NextNumber(4, 10)
		local crystal = makePart(parent, "IceCrystal", Vector3.new(2, h, 2), CFrame.new(pos + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(150, 210, 255), Enum.Material.Ice)
		crystal.Transparency = 0.2
	elseif kind == 2 then -- montículo de nieve
		local s = rng:NextNumber(3, 6)
		local mound = makePart(parent, "Snowdrift", Vector3.new(s * 1.4, s * 0.6, s), CFrame.new(pos + Vector3.new(0, s * 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(240, 245, 250), Enum.Material.Snow)
		mound.Shape = Enum.PartType.Ball
	else -- pino nevado (bajo: no tapa la vista)
		makePart(parent, "Trunk", Vector3.new(0.8, 2, 0.8), CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.fromRGB(80, 55, 40), Enum.Material.Wood)
		for i, w in { 4, 3, 1.8 } do
			local cone = makePart(parent, "Pine", Vector3.new(w, 1.6, w), CFrame.new(pos + Vector3.new(0, 1.6 + i * 1.2, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), Color3.fromRGB(40, 90, 70), Enum.Material.Grass)
			cone.CanCollide = i == 1
			local snow = makePart(parent, "PineSnow", Vector3.new(w * 0.8, 0.3, w * 0.8), CFrame.new(pos + Vector3.new(0, 2.5 + i * 1.2, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), Color3.fromRGB(245, 250, 255), Enum.Material.Snow)
			snow.CanCollide = false
		end
	end
end

Props.desert = function(parent: Instance, pos: Vector3, rng: Random)
	local kind = rng:NextInteger(1, 4)
	if kind == 1 then -- cactus
		local h = rng:NextNumber(4, 7)
		makePart(parent, "Cactus", Vector3.new(1.4, h, 1.4), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(70, 130, 60), Enum.Material.Grass)
		local side = if rng:NextNumber() < 0.5 then 1 else -1
		makePart(parent, "CactusArm", Vector3.new(2, 0.9, 0.9), CFrame.new(pos + Vector3.new(side * 1.1, h * 0.55, 0)), Color3.fromRGB(70, 130, 60), Enum.Material.Grass)
		makePart(parent, "CactusArm", Vector3.new(0.9, 1.8, 0.9), CFrame.new(pos + Vector3.new(side * 1.7, h * 0.55 + 1.2, 0)), Color3.fromRGB(70, 130, 60), Enum.Material.Grass)
	elseif kind == 2 then -- obelisco roto
		local h = rng:NextNumber(5, 12)
		makePart(parent, "Obelisk", Vector3.new(2.2, h, 2.2), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi), 0), Color3.fromRGB(210, 180, 120), Enum.Material.Sandstone)
	elseif kind == 3 then -- calavera de bestia y huesos
		makePart(parent, "Bone", Vector3.new(4, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(240, 230, 205), Enum.Material.Slate)
		makePart(parent, "Skull", Vector3.new(1.8, 1.4, 2.2), CFrame.new(pos + Vector3.new(1.5, 0.7, 0.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(240, 230, 205), Enum.Material.Slate)
	else -- roca de arenisca
		local s = rng:NextNumber(3, 6)
		makePart(parent, "Mesa", Vector3.new(s * 1.3, s * 0.8, s), CFrame.new(pos + Vector3.new(0, s * 0.35, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(195, 140, 90), Enum.Material.Sandstone)
	end
end

-- Variación de color por sala para que se note el cambio
local function shade(color: Color3, rng: Random): Color3
	local k = rng:NextNumber(0.8, 1.15)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

-- Arma el mapa del capítulo: terreno con relieve y decoración (MapBuilder). roomIndex cambia la
-- semilla: con puertas (Config.Waves.UseDoors) cada sala es un mapa nuevo.
function Arena.buildRoom(chapter, roomIndex: number)
	local seed = math.floor(os.clock() * 1000) % 100000 + roomIndex * 7919
	local rng = Random.new(seed)
	Arena.setTheme(shade(chapter.Floor, rng), shade(chapter.Wall, rng), chapter.Accent)
	return MapBuilder.build(chapter, seed, Arena.Half, roomFolder, Props[chapter.Theme])
end

---------------------------------------------------------------------
-- Puerta
---------------------------------------------------------------------

-- Centro de la zona de la puerta (al norte, antes de las montañas del borde), apoyado en el piso.
function Arena.doorPosition(): Vector3
	local z = -Arena.Half.Z + Config.Map.EdgeWidth + 8
	return Vector3.new(0, Ground.y(0, z), z)
end

-- ¿Este punto está dentro de la zona de la puerta?
function Arena.inDoorZone(pos: Vector3): boolean
	local door = Arena.doorPosition()
	return Vector3.new(pos.X - door.X, 0, pos.Z - door.Z).Magnitude <= RoomCfg.DoorRadius
end

function Arena.openDoor()
	Arena.closeDoor()
	local model = Instance.new("Model")
	model.Name = "Door"
	local base = Arena.doorPosition() - Vector3.new(0, 0, 3)
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
