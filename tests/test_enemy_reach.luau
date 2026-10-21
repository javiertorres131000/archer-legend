-- Que los enemigos vengan al jugador (atracción y reubicación) y su aspecto (ojos, modelos).
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local EnemyVisuals = require("./EnemyVisuals")
local Arena = require("./Arena")
local Ground = require("./Ground")
local EnemyAI = require("./EnemyAI")
local Waves = require("./Waves")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new
local Cfg = Config.Enemy

print("Enemigos que vienen a vos")
local p = M.addPlayer("Cazador")
PlayerData.get(p).inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = V(0, 3, 0)
local targets = { target }
local now = 100

local function flatDist(e)
	local d = e.part.Position - target.root.Position
	return V(d.X, 0, d.Z).Magnitude
end
local function run(seconds, step)
	local t = 0
	while t < seconds do
		Enemies.update(step, targets, now, false)
		now += step
		t += step
	end
end

test("aparecen a una distancia razonable (ni encima ni lejísimos)", function()
	for _ = 1, 50 do
		local pos = Enemies.findSpawnPosition(targets)
		assert(pos)
		local d = V(pos.X, 0, pos.Z).Magnitude
		assert(d >= Cfg.MinSpawnDistance - 0.01 and d <= Cfg.MaxSpawnDistance + 0.01, d)
	end
end)

test("lejos, uno que deambula viene hacia vos rápido (en curva, pero acercándose)", function()
	Enemies.clear()
	local bat = Enemies.spawn("GreenBat", V(70, 0, 0))
	local before = flatDist(bat)
	run(0.5, 0.1)
	local moved = before - flatDist(bat)
	local minimum = Cfg.CatchUpSpeed * 0.5 * math.cos(math.rad(Cfg.FlankAngle)) * 0.9
	assert(moved >= minimum, "avanzó " .. moved)
end)

test("rodear: de lejos se desvía su ángulo propio, de cerca va directo", function()
	local dir = V(1, 0, 0)
	local far = EnemyAI.flankDir(dir, 40, Cfg.FlankFar + 10)
	assert(math.abs(math.deg(math.acos(math.clamp(far:Dot(dir), -1, 1))) - 40) < 0.5, "desvío completo")
	local near = EnemyAI.flankDir(dir, 40, Cfg.FlankNear - 1)
	assert(near:Dot(dir) > 0.9999, "de cerca, directo")
	local mid = EnemyAI.flankDir(dir, 40, (Cfg.FlankNear + Cfg.FlankFar) / 2)
	assert(math.abs(math.deg(math.acos(math.clamp(mid:Dot(dir), -1, 1))) - 20) < 0.5, "a mitad, medio desvío")
	assert(EnemyAI.flankDir(dir, 0, 100) == dir, "sin desvío propio (jefes)")
end)

test("rodear: varios que vienen del mismo lado llegan por costados distintos", function()
	Enemies.clear()
	local list = {}
	for i = 1, 12 do
		table.insert(list, Enemies.spawn("WhiteSkull", V(38 + (i % 3), 0, (i % 4) - 2)))
	end
	run(2.5, 0.1)
	local left, right = 0, 0
	for _, e in list do
		if e.alive then
			if e.part.Position.Z > 1 then right += 1 elseif e.part.Position.Z < -1 then left += 1 end
		end
	end
	assert(left >= 2 and right >= 2, string.format("se abren hacia los dos lados (izq %d, der %d)", left, right))
	for _, e in list do
		assert(flatDist(e) < 38, "todos se acercaron: " .. flatDist(e))
	end
end)

test("aparecen desde varios lados a la vez, y a veces por la espalda", function()
	Enemies.clear()
	Waves.setChapter(1)
	Waves.reset()
	target.root.CFrame = M.CFrame.lookAt(V(0, 3, 0), V(0, 3, 10)) -- mira hacia +Z
	local old = Config.Frenzy.BehindSpawnChance
	Config.Frenzy.BehindSpawnChance = 1
	local t = 0
	while Enemies.aliveCount() == 0 and t < 30 do
		Waves.update(0.1, targets, false)
		t += 0.1
	end
	assert(Enemies.aliveCount() > 0, "no apareció nadie")
	-- Sectores de 120°: con 3 lados deberían ocuparse al menos 2
	local sectors, behind = {}, false
	for _, e in Enemies.list do
		if e.alive and not e.isBoss then
			local d = V(e.part.Position.X, 0, e.part.Position.Z)
			local angle = math.deg(math.atan2(d.Z, d.X)) % 360
			sectors[angle // 120] = true
			if d.Unit:Dot(V(0, 0, -1)) > math.cos(math.rad(45)) then
				behind = true
			end
		end
	end
	local n = 0
	for _ in sectors do n += 1 end
	assert(n >= 2, "todos del mismo lado")
	assert(behind, "nadie por la espalda")
	Config.Frenzy.BehindSpawnChance = old
	Enemies.clear()
	Waves.reset()
end)

test("reparto entre lados: parejo y sin grupos vacíos", function()
	local function same(a, b) return table.concat(a, ",") == table.concat(b, ",") end
	assert(same(Waves.splitSides(6, 3), { 2, 2, 2 }))
	assert(same(Waves.splitSides(5, 3), { 2, 2, 1 }))
	assert(same(Waves.splitSides(2, 3), { 1, 1 }))
	assert(same(Waves.splitSides(4, 1), { 4 }))
end)

test("punto en una dirección: respeta el lado y la distancia", function()
	for _ = 1, 30 do
		local pos = Enemies.findSpawnPositionAt(targets, target, 0) -- hacia +X
		local d = V(pos.X, 0, pos.Z)
		assert(d.Magnitude >= Cfg.MinSpawnDistance - 0.01 and d.Magnitude <= Cfg.MaxSpawnDistance + 0.01, d.Magnitude)
		assert(d.Unit:Dot(V(1, 0, 0)) > math.cos(math.rad(30)), "fuera del lado pedido")
	end
end)

test("un quieto lejos reaparece cerca; uno quieto cerca se queda", function()
	Enemies.clear()
	local far = Enemies.spawn("GreenPlant", V(70, 0, 0))
	local near = Enemies.spawn("BluePlant", V(0, 0, 30))
	local nearPos = near.part.Position
	run(Cfg.LeashTime - 0.5, 0.25)
	assert(flatDist(far) > 60) -- todavía no
	run(1, 0.25)
	local d = flatDist(far)
	assert(d >= Cfg.MinSpawnDistance - 1 and d <= Cfg.MaxSpawnDistance + 1, "quedó a " .. d)
	assert((near.part.Position - nearPos).Magnitude < 0.01)
end)

test("cualquiera muy lejos (el equipo se fue) vuelve cerca", function()
	Enemies.clear()
	local skull = Enemies.spawn("WhiteSkull", V(0, 0, 130))
	assert(flatDist(skull) > Cfg.LeashDistance)
	run(Cfg.LeashTime + 0.5, 0.25)
	assert(flatDist(skull) <= Cfg.MaxSpawnDistance + 1, flatDist(skull))
end)

test("ojos: aparecen en las figuras y se esconden al enterrarse", function()
	Enemies.clear()
	local e = Enemies.spawn("GreenBat", V(30, 0, 0))
	local eyes = 0
	for _, c in e.part:GetChildren() do
		if c.Name == "Eye" or c.Name == "Pupil" then eyes += 1 end
	end
	assert(eyes == 4 and #e.visual.parts == 4 and e.visual.hitboxVisible)
	Enemies.setHidden(e, true)
	for _, part in e.visual.parts do assert(part.Transparency == 1) end
	assert(e.part.Transparency == 1)
	Enemies.setHidden(e, false)
	for _, part in e.visual.parts do assert(part.Transparency == 0) end
	Cfg.Eyes = false
	local plain = Enemies.spawn("GreenBat", V(30, 0, 5))
	assert(#plain.visual.parts == 0)
	Cfg.Eyes = true
	Enemies.clear()
end)

test("modelos: se les borran los scripts antes de usarlos", function()
	local model = M.Instance.new("Model")
	local body = M.Instance.new("Part"); body.Parent = model
	local evil = M.Instance.new("Script"); evil.Parent = body
	local evil2 = M.Instance.new("LocalScript"); evil2.Parent = model
	local mod = M.Instance.new("ModuleScript"); mod.Parent = model
	EnemyVisuals.sanitize(model)
	for _, d in model:GetDescendants() do
		assert(d.ClassName ~= "Script" and d.ClassName ~= "LocalScript" and d.ClassName ~= "ModuleScript")
	end
	assert(body.Parent == model)
end)

test("sin carpeta de modelos no avisa nada", function()
	assert(#EnemyVisuals.missing({ "GreenBat" }) == 0)
end)

test("modelos por grupo: Redondos para los redondos, Todos para el resto", function()
	local storage = M.game:GetService("ServerStorage")
	local folder = M.Instance.new("Folder"); folder.Name = "EnemyModels"; folder.Parent = storage
	local round = M.Instance.new("Model"); round.Name = "Redondos"; round.Parent = folder
	local shape = function(id) return if id == "GreenSlime" or id == "RedBomb" then "Ball" else nil end
	local missing = EnemyVisuals.missing({ "GreenSlime", "RedBomb", "WhiteSkull" }, shape)
	assert(#missing == 1 and missing[1] == "WhiteSkull")
	local all = M.Instance.new("Model"); all.Name = "Todos"; all.Parent = folder
	assert(#EnemyVisuals.missing({ "GreenSlime", "WhiteSkull" }, shape) == 0)
	folder:Destroy()
end)

test("variedad: una carpeta con varios modelos reparte uno fijo por tipo", function()
	local folder = M.Instance.new("Folder"); folder.Name = "EnemyModels"
	local all = M.Instance.new("Folder"); all.Name = "Todos"; all.Parent = folder
	local a = M.Instance.new("Model"); a.Name = "A"; a.Parent = all
	local b = M.Instance.new("Model"); b.Name = "B"; b.Parent = all
	local seen = {}
	for _, id in { "WhiteSkull", "GreyWolf", "Spider", "Snake", "Cactus", "SkeletonArcher", "OrbTower", "Reaper" } do
		local t = EnemyVisuals.templateFor(folder, id, nil)
		assert(t == a or t == b)
		assert(EnemyVisuals.templateFor(folder, id, nil) == t) -- siempre el mismo para ese tipo
		seen[t] = true
	end
	assert(seen[a] and seen[b], "no reparte entre los dos modelos")
	local empty = M.Instance.new("Folder"); empty.Name = "Todos"
	all:Destroy(); empty.Parent = folder
	assert(EnemyVisuals.templateFor(folder, "WhiteSkull", nil) == nil)
end)

test("enterrados: avisan al cliente para esconder el indicador", function()
	local e = Enemies.spawn("Worm", V(20, 0, 0))
	Enemies.setHidden(e, true)
	assert(e.part:GetAttribute("Hidden") == true)
	Enemies.setHidden(e, false)
	assert(e.part:GetAttribute("Hidden") == nil)
	Enemies.clear()
end)

test("borde del mapa: quien se sale o se cae vuelve adentro, apoyado y quieto", function()
	local half = Arena.Half
	local margin = Config.Arena.ReturnMargin
	local root = target.root
	root.Position = V(half.X + 30, 50, 10)
	root.AssemblyLinearVelocity = V(0, -80, 0)
	assert(Arena.keepInside({ root }) == 1)
	assert(root.Position.X <= half.X - margin + 0.01 and math.abs(root.Position.Z - 10) < 0.01)
	assert(math.abs(root.Position.Y - (Ground.y(root.Position.X, root.Position.Z) + 4)) < 0.01)
	assert(root.AssemblyLinearVelocity.Magnitude == 0)
	-- Cayendo por debajo del piso
	root.Position = V(0, Ground.y(0, 0) - Config.Arena.FallBelow - 5, 0)
	assert(Arena.keepInside({ root }) == 1 and root.Position.Y > Ground.y(0, 0))
	-- Adentro y sobre el piso: no se toca
	root.Position = V(10, Ground.y(10, 0) + 3, 0)
	assert(Arena.keepInside({ root }) == 0 and root.Position.X == 10)
	-- En una esquina, afuera en los dos ejes
	root.Position = V(-half.X - 5, 10, half.Z + 5)
	Arena.keepInside({ root })
	assert(not Arena.isOutside(root.Position))
	root.Position = V(0, 3, 0)
end)

test("esqueletos del tamaño de un personaje y gárgolas a la altura de los ojos", function()
	local Types = require("./EnemyTypes")
	for _, id in { "HordeSkeleton", "SkeletonArcher", "RedArcher" } do
		local h = Types[id].Height
		assert(h and h >= 5.2 and h <= 6, id .. " mide " .. tostring(h))
	end
	for _, id in { "GreenBat", "RedBat" } do
		assert((Types[id].Float or 0) >= 4, id .. " vuela bajo")
	end
end)

test("voladores: suben y bajan en el aire, los de a pie no", function()
	Enemies.clear()
	local bat = Enemies.spawn("GreenBat", V(20, 0, 0))
	local walker = Enemies.spawn("HordeSkeleton", V(-20, 0, 0))
	assert(Enemies.flyBob(walker, 123) == 0, "el esqueleto no flota")
	local lo, hi = math.huge, -math.huge
	for i = 0, 40 do
		local b = Enemies.flyBob(bat, i * 0.1)
		lo, hi = math.min(lo, b), math.max(hi, b)
	end
	assert(hi - lo > Cfg.FlyBob, "casi no se mueve: " .. (hi - lo))
	assert(hi <= Cfg.FlyBob + 1e-6 and lo >= -Cfg.FlyBob - 1e-6, "se pasa del vaivén")
	-- En el juego: la altura del murciélago cambia mientras vuela
	local heights = {}
	for _ = 1, 10 do
		run(0.2, 0.1)
		if bat.alive then table.insert(heights, bat.part.Position.Y) end
	end
	local minY, maxY = math.huge, -math.huge
	for _, y in heights do minY, maxY = math.min(minY, y), math.max(maxY, y) end
	assert(maxY - minY > 0.1, "no sube ni baja")
	Enemies.clear()
end)

print(passed .. " pruebas, 0 fallas")
