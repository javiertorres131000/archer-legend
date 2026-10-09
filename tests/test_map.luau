-- Mapa abierto con relieve: fórmula del terreno, altura del piso (Ground), decoración,
-- mapas hechos a mano y enemigos apoyados en el relieve.
local M = require("./mocks")
local Config = require("./Config")
local Ground = require("./Ground")
local MapBuilder = require("./MapBuilder")
local Arena = require("./Arena")
local Chapters = require("./Chapters")
local Enemies = require("./Enemies")

local V = M.Vector3
local MapCfg = Config.Map
local half = Config.Arena.Size / 2

local passed, failed = 0, 0
local function test(name, f)
	local ok, err = pcall(f)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FALLÓ " .. name .. "\n         " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

print("Mapa con relieve")

local h = MapBuilder.heightFunction(1234, half)

test("misma semilla, mismo mapa; otra semilla, otro mapa", function()
	local again = MapBuilder.heightFunction(1234, half)
	local other = MapBuilder.heightFunction(999, half)
	local same, diff = true, false
	for i = 1, 50 do
		local x, z = (i * 37) % 200 - 100, (i * 53) % 200 - 100
		if h(x, z) ~= again(x, z) then same = false end
		if math.abs(h(x, z) - other(x, z)) > 0.5 then diff = true end
	end
	assert(same, "con la misma semilla debería dar lo mismo")
	assert(diff, "con otra semilla debería cambiar")
end)

test("el centro (donde se aparece) es casi plano", function()
	for x = -MapCfg.SafeRadius * 0.5, MapCfg.SafeRadius * 0.5, 3 do
		for z = -MapCfg.SafeRadius * 0.5, MapCfg.SafeRadius * 0.5, 3 do
			assert(math.abs(h(x, z)) < 1.5, string.format("altura %.1f en (%d, %d)", h(x, z), x, z))
		end
	end
end)

test("el borde es una montaña (no se puede salir)", function()
	for _, p in { { half.X - 1, 0 }, { -half.X + 1, 0 }, { 0, half.Z - 1 }, { 0, -half.Z + 1 } } do
		assert(h(p[1], p[2]) >= MapCfg.EdgeHeight * 0.8, "borde bajo: " .. h(p[1], p[2]))
	end
end)

test("hay mesetas para subir (lugares altos dentro del mapa)", function()
	local highest = 0
	local limit = half.X - MapCfg.EdgeWidth - 2
	for x = -limit, limit, 4 do
		for z = -limit, limit, 4 do
			highest = math.max(highest, h(x, z))
		end
	end
	assert(highest >= MapCfg.PlateauHeight[1], "lo más alto adentro mide " .. highest)
end)

test("cada meseta tiene una rampa: se puede subir caminando", function()
	-- Desde lo alto de cada meseta hay un camino que baja sin escalones de más de 2,5 studs cada 2 studs
	local limit = half.X - MapCfg.EdgeWidth - 2
	local tops = 0
	for x = -limit, limit, 6 do
		for z = -limit, limit, 6 do
			if h(x, z) >= MapCfg.PlateauHeight[1] - 0.01 then
				tops += 1
			end
		end
	end
	assert(tops > 0, "no encontré mesetas")
	-- Buscar al menos una bajada suave desde alguna cima
	local found = false
	for angle = 0, 359, 5 do
		local a = math.rad(angle)
		for x = -limit, limit, 12 do
			for z = -limit, limit, 12 do
				if not found and h(x, z) >= MapCfg.PlateauHeight[1] then
					local px, pz, ok = x, z, true
					for _ = 1, 40 do
						local nxp, nzp = px + math.cos(a) * 2, pz + math.sin(a) * 2
						if math.abs(h(nxp, nzp) - h(px, pz)) > 2.5 then ok = false break end
						px, pz = nxp, nzp
					end
					if ok and h(px, pz) < 3 then found = true end
				end
			end
		end
	end
	assert(found, "ninguna meseta tiene una bajada caminable")
end)

test("Ground: la grilla devuelve la altura de la fórmula y la interpola entre puntos", function()
	Ground.fromFunction(h, half, 4)
	eq(Ground.y(-half.X, -half.Z), h(-half.X, -half.Z), "esquina")
	local x, z = 8, 12
	assert(math.abs(Ground.y(x, z) - h(x, z)) < 0.01, "punto de grilla")
	local mid = Ground.y(x + 2, z)
	local lo, hi = math.min(h(x, z), h(x + 4, z)), math.max(h(x, z), h(x + 4, z))
	assert(mid >= lo - 0.01 and mid <= hi + 0.01, "interpolado entre vecinos")
	eq(Ground.place(V.new(x, 99, z), 3).Y, Ground.y(x, z) + 3, "apoyar en el piso")
end)

Arena.build()

test("mapa generado: escribe el terreno y reparte la decoración lejos del centro", function()
	local writes = M.terrainWrites
	eq(Arena.buildRoom(Chapters[1], 1), "generated", "tipo")
	eq(M.terrainWrites, writes + 1, "terreno escrito")
	local props = M.workspace.Arena.Room:GetChildren()
	assert(#props >= MapCfg.Props, "decoración: " .. #props)
	for _, p in props do
		local pos = p.Position
		if pos and p.Name ~= "Canopy" then
			assert(math.sqrt(pos.X ^ 2 + pos.Z ^ 2) > MapCfg.SafeRadius - 5, string.format("%s en el centro (%.0f, %.0f)", p.Name, pos.X, pos.Z))
		end
	end
end)

test("los puntos de aparición están en el centro, apoyados en el piso", function()
	for _, cf in Arena.spawnPoints(4) do
		local p = cf.Position
		assert(math.sqrt(p.X ^ 2 + p.Z ^ 2) < MapCfg.SafeRadius, "fuera del centro")
		assert(math.abs(p.Y - (Ground.y(p.X, p.Z) + 3)) < 0.01, "altura")
	end
end)

test("mapa hecho a mano: ServerStorage > Maps > forest con Terrain y decoración", function()
	local ServerStorage = M.game:GetService("ServerStorage")
	local maps = M.Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = ServerStorage
	local set = M.Instance.new("Folder")
	set.Name = "forest"
	set.Parent = maps
	local region = M.Instance.new("TerrainRegion")
	region.Name = "Terrain"
	region.SizeInCells = V.new(75, 15, 75)
	region.Parent = set
	local model = M.Instance.new("Model")
	model.Name = "MisArboles"
	model.Clone = function()
		local copy = M.Instance.new("Model")
		copy.Name = "MisArboles"
		return copy
	end
	model.Parent = set
	eq(Arena.buildRoom(Chapters[1], 1), "custom", "tipo")
	local props = M.workspace.Arena.Room:GetChildren()
	eq(#props, 1, "solo la decoración hecha a mano")
	eq(props[1].Name, "MisArboles", "modelo")
	-- Otro capítulo sin mapa propio: se genera
	eq(Arena.buildRoom(Chapters[2], 1), "generated", "ruins se genera")
	maps.Parent = nil
end)

test("los enemigos aparecen apoyados en el relieve y a buena distancia del jugador", function()
	Arena.buildRoom(Chapters[1], 1)
	Enemies.init(Arena.Half, {}, {})
	-- Un punto alto del mapa
	local best, bestH = V.new(0, 0, 0), -1
	for x = -100, 100, 10 do
		for z = -100, 100, 10 do
			if Ground.y(x, z) > bestH then best, bestH = V.new(x, 0, z), Ground.y(x, z) end
		end
	end
	local e = Enemies.spawn("GreenSlime", best)
	assert(math.abs(e.part.Position.Y - (Ground.y(best.X, best.Z) + e.baseY)) < 0.01, "a la altura del piso")
	Enemies.clear()

	local root = M.Instance.new("Part")
	root.Position = V.new(0, 3, 0)
	local targets = { { player = nil, root = root } }
	for _ = 1, 50 do
		local pos = Enemies.findSpawnPosition(targets :: any)
		if pos then
			local d = math.sqrt(pos.X ^ 2 + pos.Z ^ 2)
			assert(d >= Config.Enemy.MinSpawnDistance - 0.01, "muy cerca: " .. d)
			assert(d <= Config.Enemy.MaxSpawnDistance + 0.01, "muy lejos: " .. d)
		end
	end
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then
	error("hay pruebas que fallaron")
end
