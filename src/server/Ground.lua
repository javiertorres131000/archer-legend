--!strict
-- Ground (ModuleScript)
-- Ubicación: ServerScriptService > Server > Ground
-- Altura del piso en cualquier punto del mapa. La usan los enemigos (caminan sobre las
-- colinas), los avisos del piso, los orbes, los cofres y los puntos de aparición.
--
-- MapBuilder la llena al armar el mapa: con la fórmula del relieve (mapas generados) o
-- midiendo el terreno con rayos (mapas esculpidos a mano). Se guarda en una grilla y se
-- interpola, así preguntar la altura es barato aunque haya 100 enemigos.

local Ground = {}

local step = 4
local originX, originZ = 0, 0
local nx, nz = 0, 0
local heights: { number } = {}

-- Grilla de alturas: heights[(iz - 1) * nx + ix] es la altura en (originX + (ix-1)*step, originZ + (iz-1)*step).
function Ground.setGrid(gridStep: number, x0: number, z0: number, countX: number, countZ: number, values: { number })
	step = gridStep
	originX, originZ = x0, z0
	nx, nz = countX, countZ
	heights = values
end

-- Arma la grilla evaluando una función de altura en cada punto.
function Ground.fromFunction(fn: (number, number) -> number, half: Vector3, gridStep: number)
	local countX = math.floor(half.X * 2 / gridStep) + 1
	local countZ = math.floor(half.Z * 2 / gridStep) + 1
	local values = table.create(countX * countZ, 0)
	for iz = 1, countZ do
		for ix = 1, countX do
			values[(iz - 1) * countX + ix] = fn(-half.X + (ix - 1) * gridStep, -half.Z + (iz - 1) * gridStep)
		end
	end
	Ground.setGrid(gridStep, -half.X, -half.Z, countX, countZ, values)
end

-- Piso plano (antes de armar el mapa, o en las pruebas).
function Ground.flat()
	nx, nz = 0, 0
	heights = {}
end

local function at(ix: number, iz: number): number
	ix = math.clamp(ix, 1, nx)
	iz = math.clamp(iz, 1, nz)
	return heights[(iz - 1) * nx + ix] or 0
end

-- Altura del piso en (x, z), interpolada entre los cuatro puntos de grilla más cercanos.
function Ground.y(x: number, z: number): number
	if nx == 0 then
		return 0
	end
	local fx = (x - originX) / step
	local fz = (z - originZ) / step
	local ix = math.floor(fx)
	local iz = math.floor(fz)
	local tx = fx - ix
	local tz = fz - iz
	ix += 1
	iz += 1
	local a = at(ix, iz) + (at(ix + 1, iz) - at(ix, iz)) * tx
	local b = at(ix, iz + 1) + (at(ix + 1, iz + 1) - at(ix, iz + 1)) * tx
	return a + (b - a) * tz
end

-- El mismo punto, apoyado en el piso.
function Ground.place(pos: Vector3, above: number?): Vector3
	return Vector3.new(pos.X, Ground.y(pos.X, pos.Z) + (above or 0), pos.Z)
end

return Ground
