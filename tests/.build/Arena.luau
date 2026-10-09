local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- Arena (ModuleScript)
-- Ubicación: ServerScriptService > Server > Arena
-- Construye el piso, las paredes y el punto de aparición.

local Config = require("./Config")
local ArenaCfg = Config.Arena

local Arena = {}

-- Mitad del tamaño del piso: los límites jugables son -Half..+Half en X y Z.
Arena.Half = ArenaCfg.Size / 2

local floor: Part? = nil
local walls: { Part } = {}

function Arena.build()
	-- Sacamos el piso y el spawn de la plantilla "Baseplate" si existen.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end

	local half = Arena.Half
	-- El piso queda con la cara de arriba en Y = 0.
	floor = makePart("Floor", ArenaCfg.Size, CFrame.new(0, -ArenaCfg.Size.Y / 2, 0), Color3.fromRGB(70, 90, 70))

	local wallColor = Color3.fromRGB(60, 60, 70)
	local h = ArenaCfg.WallHeight
	walls = {
		makePart("WallN", Vector3.new(ArenaCfg.Size.X + 2, h, 1), CFrame.new(0, h / 2, -half.Z - 0.5), wallColor),
		makePart("WallS", Vector3.new(ArenaCfg.Size.X + 2, h, 1), CFrame.new(0, h / 2, half.Z + 0.5), wallColor),
		makePart("WallW", Vector3.new(1, h, ArenaCfg.Size.Z), CFrame.new(-half.X - 0.5, h / 2, 0), wallColor),
		makePart("WallE", Vector3.new(1, h, ArenaCfg.Size.Z), CFrame.new(half.X + 0.5, h / 2, 0), wallColor),
	}

	-- Sin SpawnLocation: se aparece en el lobby y MatchManager trae a los participantes acá.
end

-- Puntos de aparición en la arena para `count` jugadores, en ronda alrededor del centro.
function Arena.spawnPoints(count: number): { CFrame }
	local points = {}
	for i = 1, count do
		local angle = (i - 1) / math.max(count, 1) * math.pi * 2
		local offset = if count == 1 then Vector3.zero else Vector3.new(math.cos(angle), 0, math.sin(angle)) * 5
		points[i] = CFrame.new(Vector3.new(0, 3, 0) + offset)
	end
	return points
end

-- Colores del capítulo actual.
function Arena.setTheme(floorColor: Color3, wallColor: Color3)
	if floor then
		floor.Color = floorColor
	end
	for _, w in walls do
		w.Color = wallColor
	end
end

return Arena
