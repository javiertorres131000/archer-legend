--!strict
-- MapBuilder (ModuleScript)
-- Ubicación: ServerScriptService > Server > MapBuilder
-- Arma el mapa abierto del capítulo con relieve: lomas, mesetas con rampa para subir,
-- montañas en el borde y decoración repartida (árboles, ruinas, braseros...).
--
-- Dos formas:
--   · Hecho a mano: si en ServerStorage > Maps > <Id del capítulo> hay un TerrainRegion llamado
--     "Terrain", se pega ese terreno (y los Models que haya en la carpeta, como decoración).
--     Atributos "Color_<Material>" de la carpeta (Color3) tiñen ese material del terreno
--     (no en el place de la Ciudadela, que comparte los colores con la isla del lobby).
--     La altura del piso se mide con rayos contra el terreno (ver README para crearlo).
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
-- Alto y ancho de las montañas del borde (por tema: Config.Map.ThemeEdges)
local function edgeOf(theme: string?): (number, number, number?)
	local t = theme and (MapCfg :: any).ThemeEdges and (MapCfg :: any).ThemeEdges[theme]
	if t then
		return t.Height, t.Width, t.SnowLine
	end
	return MapCfg.EdgeHeight, MapCfg.EdgeWidth, nil
end

-- Lago congelado grande del Glaciar: dónde queda (sale de la semilla) o nil en otros temas
local function bigLake(seed: number, theme: string?): (Vector3?, number)
	local cfg = if theme == "glacier" then (Config :: any).MapEvents.glacier.IceLakes.Lake else nil
	if not cfg then
		return nil, 0
	end
	local r = Random.new(seed + 77)
	local a = r:NextNumber(0, math.pi * 2)
	local d = r:NextNumber(cfg.Distance[1], cfg.Distance[2])
	return Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), cfg.Radius
end

function MapBuilder.heightFunction(seed: number, half: Vector3, theme: string?): HeightFn
	local lakeAt, lakeR = bigLake(seed, theme)
	local edgeHeight, edgeWidth = edgeOf(theme)
	local rng = Random.new(seed)
	local noiseZ = rng:NextNumber(0, 1000)

	-- Mesetas: lejos del centro y del borde, sin pisarse demasiado
	local plateaus: { Plateau } = {}
	local tries = 0
	while #plateaus < MapCfg.Plateaus and tries < 200 do
		tries += 1
		local r = rng:NextNumber(MapCfg.PlateauRadius[1], MapCfg.PlateauRadius[2])
		local limit = half.X - edgeWidth - r - 6
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

		-- Lago congelado: plano (lo que haya ahí se aplana hacia el borde del lago)
		if lakeAt then
			local dl = math.sqrt((x - lakeAt.X) ^ 2 + (z - lakeAt.Z) ^ 2)
			h *= smoothstep((dl - lakeR) / 12)
		end

		-- Montañas en el borde (no se puede salir del mapa). El contorno es redondeado e irregular
		-- (una superelipse que ondula con ruido) y los picos tienen alturas distintas, así el valle
		-- no parece una caja cuadrada.
		local nx, nz = math.abs(x) / half.X, math.abs(z) / half.Z
		local rr = (nx ^ 4 + nz ^ 4) ^ 0.25 -- 1 = borde del cuadrado; las esquinas quedan dentro del cerro
		local ang = math.atan2(z, x)
		local ondula = math.noise(math.cos(ang) * 2.2, math.sin(ang) * 2.2, noiseZ + 99) * 0.14
			+ math.noise(math.cos(ang) * 6, math.sin(ang) * 6, noiseZ + 140) * 0.05
		local inicio = 1 - (edgeWidth / half.X) * 1.2 + ondula -- dónde empieza a subir
		local t = (rr - inicio) / math.max(1 - inicio, 0.05)
		if t > 0 then
			local s = smoothstep(math.min(t, 1))
			local picos = 0.55 + 0.9 * (math.noise(x / 38, z / 38, noiseZ + 200) + 0.5) -- 0,55 a 1,45
			local rugoso = math.noise(x / 11, z / 11, noiseZ + 300) * 5
			h = math.max(h, (edgeHeight * picos + rugoso) * s)
		end
		return h
	end
end

-- Escribe el terreno de Roblox según la función de altura.
local function writeTerrain(height: HeightFn, half: Vector3, theme: string, seed: number?)
	local terrain = workspace.Terrain
	local res = MapCfg.VoxelSize
	local mats = MapCfg.Materials[theme] or MapCfg.Materials.forest
	local edgeHeight, _, snowLine = edgeOf(theme)
	local top = edgeHeight * 1.5 + 8 -- los picos llegan hasta ×1,45
	local region = Region3.new(Vector3.new(-half.X, BOTTOM, -half.Z), Vector3.new(half.X, top, half.Z)):ExpandToGrid(res)
	local size = region.Size / res
	local sx, sy, sz = math.floor(size.X + 0.5), math.floor(size.Y + 0.5), math.floor(size.Z + 0.5)
	local minCorner = region.CFrame.Position - region.Size / 2
	-- Glaciar: lagos congelados (manchas de hielo liso en el piso; ahí se resbala más)
	local lakes = if theme == "glacier" then (Config :: any).MapEvents.glacier.IceLakes else nil
	local lakeZ = ((seed or 0) % 997) + 0.37
	local lakeAt, lakeR = bigLake(seed or 0, theme)

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
			if lakeAt and math.sqrt((wx - lakeAt.X) ^ 2 + (wz - lakeAt.Z) ^ 2) <= lakeR then
				surface = Enum.Material.Ice -- el lago grande
			elseif snowLine and h > edgeHeight * snowLine then
				surface = mats.Top -- picos nevados
			elseif lakes and surface == mats.Top and slope < res * 0.35 and math.sqrt(wx * wx + wz * wz) > MapCfg.SafeRadius * 0.5
				and math.noise(wx / lakes.Scale, wz / lakes.Scale, lakeZ) > lakes.Threshold then
				surface = Enum.Material.Ice
			elseif lakes and surface == mats.Top then
				-- Variedad para que la nieve no sea un blanco liso: costra de nieve vieja (Salt),
				-- nieve pisada y gris (Limestone) y rocas que asoman (Slate)
				local n1 = math.noise(wx / 23, wz / 23, lakeZ + 40)
				local n2 = math.noise(wx / 9, wz / 9, lakeZ + 80)
				if n2 > 0.42 and slope > res * 0.15 then
					surface = Enum.Material.Slate
				elseif n1 > 0.22 then
					surface = Enum.Material.Salt
				elseif n1 < -0.3 then
					surface = Enum.Material.Limestone
				end
			end
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
	if set and set:FindFirstChild("Terrain") then
		return set :: Folder
	end
	return nil
end

-- Mide el terreno con rayos (para mapas hechos a mano) y llena Ground.
local function measureTerrain(half: Vector3, step: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
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
	-- Pasto animado más bajo (Config.Map.GrassLength)
	pcall(function()
		terrain.GrassLength = MapCfg.GrassLength
	end)

	local custom = customMap(chapter.Id)
	if custom then
		local region = custom:FindFirstChild("Terrain") :: TerrainRegion
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
		local okAttrs, attrs = pcall(function()
			return custom:GetAttributes()
		end)
		if okAttrs and not workspace:FindFirstChild("Ciudadela") then
			for name, value in attrs do
				local material = string.match(name, "^Color_(%w+)$")
				if material and typeof(value) == "Color3" then
					pcall(function()
						terrain:SetMaterialColor((Enum.Material :: any)[material], value)
					end)
				end
			end
		end
		for _, child in custom:GetChildren() do
			if child:IsA("Model") then
				child:Clone().Parent = propsFolder
			end
		end
		measureTerrain(half, MapCfg.VoxelSize)
		return "custom"
	end

	local height = MapBuilder.heightFunction(seed, half, chapter.Theme)
	writeTerrain(height, half, chapter.Theme or "forest", seed)
	if chapter.Theme == "glacier" and not workspace:FindFirstChild("Ciudadela") then
		-- Colores del hielo: nieve casi blanca, hielo celeste translúcido, glaciar azul profundo
		pcall(function()
			-- Nieve y Hielo usan texturas propias (MaterialService del place de la Arena: NieveGlaciar y
			-- HieloGlaciar, imágenes en assets/textures/glacier); el color las tiñe, por eso van claros.
			-- Tonos algo grises y azulados: el blanco puro se "quema" con la luz y no se ve relieve
			terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(228, 234, 242))
			terrain:SetMaterialColor(Enum.Material.Salt, Color3.fromRGB(214, 222, 232))
			terrain:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(170, 180, 192))
			terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(78, 86, 98))
			terrain:SetMaterialColor(Enum.Material.Ice, Color3.fromRGB(205, 228, 245))
			terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(75, 130, 185))
		end)
	end
	Ground.fromFunction(height, half, MapCfg.VoxelSize)
	if builder then
		scatterProps(height, half, propsFolder, builder, Random.new(seed + 1))
	end
	-- Paredes invisibles al pie de las montañas: no se puede salir del valle trepando
	if (MapCfg :: any).BoundaryWalls then
		local _, edgeWidth = edgeOf(chapter.Theme)
		local inset = half.X - edgeWidth * 0.55
		for i = 0, 3 do
			local wall = Instance.new("Part")
			wall.Name = "LimiteInvisible"
			wall.Anchored = true
			wall.CanQuery = false
			wall.CanTouch = false
			wall.Transparency = 1
			wall.Size = Vector3.new(inset * 2 + 4, 400, 4)
			wall.CFrame = CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, 150, inset + 2)
			wall.Parent = propsFolder
		end
	end
	return "generated"
end

return MapBuilder
