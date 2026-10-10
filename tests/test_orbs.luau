-- Orbes de XP (Orbs) y cofres (Chests).
local M = require("./mocks")
local Config = require("./Config")
local Orbs = require("./Orbs")
local Chests = require("./Chests")

local V = M.Vector3
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

-- Un "jugador" mínimo: lo que usan Orbs y Chests
local function collector(name, pos, radius)
	local player = M.addPlayer(name)
	local root = M.Instance.new("Part")
	root.Position = pos
	return { player = player, root = root, state = { stats = { pickupRadius = radius or 10 } } }
end

local xp = 0
local sent = {}
local orbRemote = { FireAllClients = function(_, payload) table.insert(sent, payload) end }
Orbs.init(orbRemote :: any, function(n) xp += n end)

print("Orbes y cofres")

test("un orbe lejos no se junta; al acercarse, sí (y la XP es del equipo)", function()
	Orbs.clear()
	xp = 0
	local ana = collector("Ana", V.new(0, 3, 0), 10)
	Orbs.drop(V.new(20, 0, 0), 5)
	Orbs.update({ ana })
	eq(Orbs.count(), 1, "sigue en el piso")
	eq(xp, 0, "sin XP")
	ana.root.Position = V.new(12, 3, 0)
	Orbs.update({ ana })
	eq(Orbs.count(), 0, "juntado")
	eq(xp, 5, "XP sumada")
end)

test("el imán más grande junta de más lejos", function()
	Orbs.clear()
	local small = collector("Chico", V.new(0, 3, 0), 5)
	local big = collector("Grande", V.new(0, 3, 0), 15)
	Orbs.drop(V.new(10, 0, 0), 1)
	Orbs.update({ small })
	eq(Orbs.count(), 1, "radio 5 no llega")
	Orbs.update({ big })
	eq(Orbs.count(), 0, "radio 15 sí")
end)

test("aspiradora al terminar la oleada: se juntan todos", function()
	Orbs.clear()
	xp = 0
	local ana = collector("Ana2", V.new(0, 3, 0), 1)
	for i = 1, 10 do Orbs.drop(V.new(i * 5, 0, 0), 2) end
	Orbs.collectAll({ ana })
	eq(Orbs.count(), 0, "ninguno queda")
	eq(xp, 20, "toda la XP")
end)

test("con demasiados orbes, el más viejo se cobra solo", function()
	Orbs.clear()
	xp = 0
	for _ = 1, Config.Frenzy.MaxOrbs + 3 do Orbs.drop(V.new(50, 0, 50), 1) end
	eq(Orbs.count(), Config.Frenzy.MaxOrbs, "tope")
	eq(xp, 3, "la XP de los viejos no se pierde")
end)

test("a los clientes les llega todo junto: aparecidos, juntados y limpieza", function()
	Orbs.clear()
	table.clear(sent)
	local ana = collector("Ana3", V.new(0, 3, 0), 10)
	Orbs.drop(V.new(1, 0, 0), 3)
	Orbs.drop(V.new(40, 0, 0), 3)
	Orbs.update({ ana })
	Orbs.flush(1000)
	eq(#sent, 1, "un solo envío")
	eq(#sent[1].spawn, 2, "dos aparecidos")
	eq(#sent[1].take, 1, "uno juntado")
	eq(sent[1].take[1][2], ana.player.UserId, "por Ana")
	Orbs.flush(1000.01)
	eq(#sent, 1, "sin cambios no se manda nada")
	Orbs.clear()
	eq(sent[#sent].clear, true, "limpieza avisada enseguida")
end)

-- Cofres
local opened = {}
local chestRemote = { FireAllClients = function() end }
Chests.init(chestRemote :: any, V.new(60, 0, 60), function(pos, opener) table.insert(opened, { pos = pos, opener = opener }) end)

test("el cofre aparece cada ChestEveryKills muertes, solo durante la oleada", function()
	Chests.clear()
	for _ = 1, Config.Frenzy.ChestEveryKills - 1 do Chests.onKill() end
	Chests.update({}, true)
	eq(Chests.count(), 0, "todavía no")
	Chests.onKill()
	Chests.update({}, false)
	eq(Chests.count(), 0, "en el descanso no aparecen")
	Chests.update({}, true)
	eq(Chests.count(), 1, "apareció")
end)

test("no hay más de MaxChests a la vez", function()
	Chests.clear()
	for _ = 1, 5 do
		for _ = 1, Config.Frenzy.ChestEveryKills do Chests.onKill() end
		Chests.update({}, true)
	end
	eq(Chests.count(), Config.Frenzy.MaxChests, "tope")
end)

test("pasar al lado lo abre (una sola vez) y avisa quién fue", function()
	Chests.clear()
	table.clear(opened)
	for _ = 1, Config.Frenzy.ChestEveryKills do Chests.onKill() end
	Chests.update({}, true)
	local chestPart = M.workspace.Chests:GetChildren()[1]
	local pos = chestPart.Position
	local ana = collector("Ana4", V.new(pos.X + 100, 3, pos.Z), 1)
	Chests.update({ ana }, true)
	eq(#opened, 0, "lejos no se abre")
	ana.root.Position = V.new(pos.X + 1, 3, pos.Z)
	Chests.update({ ana }, true)
	Chests.update({ ana }, true)
	eq(#opened, 1, "abierto una vez")
	eq(opened[1].opener, ana.player, "por Ana")
	eq(#M.workspace.Chests:GetChildren(), 0, "se borró la parte")
end)

test("al terminar la oleada se abren solos los que quedan", function()
	Chests.clear()
	table.clear(opened)
	for _ = 1, 2 do
		for _ = 1, Config.Frenzy.ChestEveryKills do Chests.onKill() end
		Chests.update({}, true)
	end
	Chests.openAll()
	eq(#opened, 2, "dos abiertos")
	eq(opened[1].opener, nil, "sin jugador")
	eq(Chests.count(), 0, "ninguno queda")
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then
	error("hay pruebas que fallaron")
end
