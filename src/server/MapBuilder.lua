--!strict
-- MapBuilder (ModuleScript)
-- Ubicación: ServerScriptService > Server > MapBuilder
-- Arma el mapa abierto del capítulo con relieve: lomas, mesetas con rampa para subir,
-- montañas en el borde y decoración repartida (árboles, ruinas, braseros...).
--
-- Dos formas:
--   · Hecho a mano: en ServerStorage > Maps > <Id del capítulo> puede haber
--       - un TerrainRegion llamado "Terrain" (Terreno de Roblox), que se pega tal cual, y/o
--       - un MeshPart o Model llamado "Ground" (un piso modelado, por ejemplo importado de Blender),
--         que se escala al tamaño del mapa y se centra (ver Config.Map.GroundModel).
--     Los demás Models de la carpeta van como decoración. La altura del piso se mide con rayos.
--   · Generado: se escribe el terreno con una fórmula de relieve distinta en cada partida.
--
-- Los jugadores caminan y saltan sobre el terreno con la física normal de Roblox. Los enemigos
-- no usan física: siguen la altura que guarda Ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ground = require(script.Parent.Ground)

local MapCfg = Config.Map

type Plateau = { x: number, z: number, r: number, h: number, ramp: number }
export type HeightFn = (number, number) -> number

local MapBuilder = {}

local BOTTOM = -12 -- fondo del terreno (Y)

---------------------------------------------------------------------
-- Relieve generado
---------------------------------------------------------------------

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Ángulo más corto entre dos direcciones (radianes).
local function angleDiff(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	return if d > math.pi then 2 * math.pi - d else d
end

-- Devuelve la función de altura h(x, z) de un mapa generado con esta semilla.
function MapBuilder.heightFunction(seed: number, half: Vector3): HeightFn
	local rng = Random.new(seed)
	local noiseZ = rng:NextNumber(0, 1000)

	-- Mesetas: lejos del centro y del borde, sin pisarse demasiado
	local plateaus: { Plateau } = {}
	local tries = 0
	while #plateaus < MapCfg.Plateaus and tries < 200 do
		tries += 1
		local r = rng:NextNumber(MapCfg.PlateauRadius[1], MapCfg.PlateauRadius[2])
		local limit = half.X - MapCfg.EdgeWidth - r - 6
		local x = rng:NextNumber(-limit, limit)
		local z = rng:NextNumber(-limit, limit)
		local ok = math.sqrt(x * x + z * z) > MapCfg.SafeRadius + r + 10
		for _, p in plateaus do
			if math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) < p.r + r + 12 then
				ok = false
			end
		end
		if ok then
			table.insert(plateaus, {
				x = x,
				z = z,
				r = r,
				h = rng:NextNumber(MapCfg.PlateauHeight[1], MapCfg.PlateauHeight[2]),
				ramp = rng:NextNumber(0, 2 * math.pi), -- hacia dónde baja la rampa
			})
		end
	end

	return function(x: number, z: number): number
		-- Lomas suaves (dos escalas de ruido)
		local h = math.noise(x / MapCfg.HillScale, z / MapCfg.HillScale, noiseZ) * MapCfg.HillHeight
			+ math.noise(x / (MapCfg.HillScale * 0.35), z / (MapCfg.HillScale * 0.35), noiseZ + 50) * MapCfg.HillHeight * 0.3
		h = math.max(h, -2)

		-- Centro casi plano (ahí se aparece)
		local d0 = math.sqrt(x * x + z * z)
		h *= smoothstep((d0 - MapCfg.SafeRadius * 0.6) / (MapCfg.SafeRadius * 0.6))

		-- Mesetas: arriba planas, con un acantilado alrededor y una rampa para subir
		for _, p in plateaus do
			local dx, dz = x - p.x, z - p.z
			local d = math.sqrt(dx * dx + dz * dz)
			local ph = 0
			if d <= p.r then
				ph = p.h
			elseif angleDiff(math.atan2(dz, dx), p.ramp) < math.rad(22) then
				ph = p.h * (1 - smoothstep((d - p.r) / MapCfg.RampLength))
			else
				ph = p.h * (1 - smoothstep((d - p.r) / 4)) -- acantilado
			end
			h = math.max(h, ph)
		end

		-- Montañas en el borde (no se puede salir del mapa)
		local edge = math.min(half.X - math.abs(x), half.Z - math.abs(z))
		if edge < MapCfg.EdgeWidth then
			h = math.max(h, MapCfg.EdgeHeight * smoothstep(1 - edge / MapCfg.EdgeWidth))
		end
		return h
	end
end

-- Escribe el terreno de Roblox según la función de altura.
local function writeTerrain(height: HeightFn, half: Vector3, theme: string)
	local terrain = workspace.Terrain
	local res = MapCfg.VoxelSize
	local mats = MapCfg.Materials[theme] or MapCfg.Materials.forest
	local top = MapCfg.EdgeHeight + 8
	local region = Region3.new(Vector3.new(-half.X, BOTTOM, -half.Z), Vector3.new(half.X, top, half.Z)):ExpandToGrid(res)
	local size = region.Size / res
	local sx, sy, sz = math.floor(size.X + 0.5), math.floor(size.Y + 0.5), math.floor(size.Z + 0.5)
	local minCorner = region.CFrame.Position - region.Size / 2

	local materials = table.create(sx)
	local occupancy = table.create(sx)
	for ix = 1, sx do
		local matX = table.create(sy)
		local occX = table.create(sy)
		local wx = minCorner.X + (ix - 0.5) * res
		for iy = 1, sy do
			matX[iy] = table.create(sz, Enum.Material.Air)
			occX[iy] = table.create(sz, 0)
		end
		for iz = 1, sz do
			local wz = minCorner.Z + (iz - 0.5) * res
			local h = height(wx, wz)
			-- Pendiente: si cambia mucho con los vecinos, es roca (acantilado)
			local slope = math.max(math.abs(height(wx + res, wz) - h), math.abs(height(wx, wz + res) - h))
			local surface = if slope > res * 0.9 then mats.Cliff else mats.Top
			for iy = 1, sy do
				local yb = minCorner.Y + (iy - 1) * res
				local occ = math.clamp((h - yb) / res, 0, 1)
				if occ > 0 then
					occX[iy][iz] = occ
					matX[iy][iz] = if h - yb < res * 1.5 then surface else mats.Under
				end
			end
		end
		materials[ix] = matX
		occupancy[ix] = occX
	end
	terrain:WriteVoxels(region, res, materials, occupancy)
end

---------------------------------------------------------------------
-- Decoración
---------------------------------------------------------------------

-- Reparte decoración por el mapa (no en el centro ni sobre acantilados).
local function scatterProps(height: HeightFn, half: Vector3, folder: Instance, builder: any, rng: Random)
	local placed = 0
	local tries = 0
	while placed < MapCfg.Props and tries < MapCfg.Props * 6 do
		tries += 1
		local limit = half.X - MapCfg.EdgeWidth * 0.6
		local x = rng:NextNumber(-limit, limit)
		local z = rng:NextNumber(-limit, limit)
		if math.sqrt(x * x + z * z) > MapCfg.SafeRadius then
			local h = height(x, z)
			local slope = math.abs(height(x + 2, z) - h) + math.abs(height(x, z + 2) - h)
			if slope < 1.5 then
				builder(folder, Vector3.new(x, h, z), rng)
				placed += 1
			end
		end
	end
	return placed
end

---------------------------------------------------------------------
-- Mapa hecho a mano
---------------------------------------------------------------------

local function customMap(chapterId: string): Folder?
	local maps = ServerStorage:FindFirstChild("Maps")
	local set = maps and maps:FindFirstChild(chapterId)
	if set and (set:FindFirstChild("Terrain") or set:FindFirstChild("Ground")) then
		return set :: Folder
	end
	return nil
end

-- Piso modelado: se copia, se escala para cubrir el mapa y se centra en el origen, con la cara de
-- arriba más o menos en Y = 0 (como el terreno generado). Devuelve la copia.
local function placeGroundModel(source: Instance, half: Vector3, parent: Instance): Instance
	local copy = source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		model = Instance.new("Model")
		model.Name = "Ground"
		copy.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true
			-- Con la colisión simplificada, los jugadores caminan sobre una "lona" invisible por
			-- arriba de las rocas (parece que flotan). Solo se puede cambiar en Studio.
			if d:IsA("MeshPart") and d.CollisionFidelity ~= Enum.CollisionFidelity.PreciseConvexDecomposition then
				warn(string.format(
					"[Mapa] %s tiene CollisionFidelity = %s: los jugadores van a flotar cerca de las rocas. En Studio ponele PreciseConvexDecomposition.",
					source:GetFullName() .. (if d ~= copy then "." .. d.Name else ""),
					d.CollisionFidelity.Name
				))
			end
		end
	end
	local cfg = MapCfg.GroundModel or {}
	local _, extent = model:GetBoundingBox()
	-- Que cubra el mapa: el lado más largo del modelo = el lado del mapa (Fill de la config)
	local target = math.max(half.X, half.Z) * 2 * (cfg.Fill or 1)
	model:ScaleTo(model:GetScale() * target / math.max(extent.X, extent.Z, 0.01))
	local box, ext = model:GetBoundingBox()
	local pivot = model:GetPivot()
	-- Centro del modelo en (0, ?, 0); la base en BOTTOM, o la altura que diga TopY
	local baseY = if cfg.BottomY then cfg.BottomY else BOTTOM
	local shift = Vector3.new(-box.Position.X, baseY - (box.Position.Y - ext.Y / 2), -box.Position.Z)
	model:PivotTo(pivot + shift)
	model.Name = "Ground"
	model.Parent = parent
	return model
end

-- Mide el terreno con rayos (para mapas hechos a mano) y llena Ground. extra: piso modelado, si hay.
local function measureTerrain(half: Vector3, step: number, extra: Instance?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if extra then { workspace.Terrain, extra } else { workspace.Terrain }
	local countX = math.floor(half.X * 2 / step) + 1
	local countZ = math.floor(half.Z * 2 / step) + 1
	local values = table.create(countX * countZ, 0)
	for iz = 1, countZ do
		for ix = 1, countX do
			local x = -half.X + (ix - 1) * step
			local z = -half.Z + (iz - 1) * step
			local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
			values[(iz - 1) * countX + ix] = if hit then hit.Position.Y else 0
		end
	end
	Ground.setGrid(step, -half.X, -half.Z, countX, countZ, values)
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

-- Arma el mapa del capítulo. propsFolder: dónde va la decoración (se vacía antes).
-- builder: función que pone una pieza de decoración (Arena.Props[tema]).
-- Devuelve "custom" o "generated".
function MapBuilder.build(chapter: any, seed: number, half: Vector3, propsFolder: Instance, builder: any): string
	local terrain = workspace.Terrain
	propsFolder:ClearAllChildren()
	terrain:Clear()

	local custom = customMap(chapter.Id)
	if custom then
		local region = custom:FindFirstChild("Terrain")
		if region and region:IsA("TerrainRegion") then
			-- Se pega donde estaba cuando se copió (atributo "Corner", en celdas de 4 studs);
			-- si no lo tiene, centrado en el origen del mapa.
			local saved = region:GetAttribute("Corner")
			local corner = if typeof(saved) == "Vector3"
				then Vector3int16.new(saved.X, saved.Y, saved.Z)
				else Vector3int16.new(
					-math.floor(region.SizeInCells.X / 2),
					math.floor(BOTTOM / 4),
					-math.floor(region.SizeInCells.Z / 2)
				)
			terrain:PasteRegion(region, corner, true)
		end
		local groundSource = custom:FindFirstChild("Ground")
		local ground = if groundSource then placeGroundModel(groundSource, half, propsFolder) else nil
		for _, child in custom:GetChildren() do
			if child:IsA("Model") and child ~= groundSource then
				child:Clone().Parent = propsFolder
			end
		end
		measureTerrain(half, MapCfg.VoxelSize, ground)
		return "custom"
	end

	local height = MapBuilder.heightFunction(seed, half)
	writeTerrain(height, half, chapter.Theme or "forest")
	Ground.fromFunction(height, half, MapCfg.VoxelSize)
	if builder then
		scatterProps(height, half, propsFolder, builder, Random.new(seed + 1))
	end
	return "generated"
end

return MapBuilder
