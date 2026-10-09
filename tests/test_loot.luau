-- Botín (Loot.roll) y números flotantes (CombatFeed): cálculo y agrupado.
local M = require("./mocks")
local Config = require("./Config")
local Loot = require("./Loot")
local CombatFeed = require("./CombatFeed")

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
local function fixed(v) return function() return v end end

print("Botín y números flotantes")

test("enemigo común: oro según su costo, sin gemas con mala suerte", function()
	-- random = 0.5 → sin variación; 0.5 > probabilidad de gema y piedra
	local r = Loot.roll(3, false, 1, fixed(0.5))
	eq(r.Gold, 3 * Config.Loot.GoldPerCost, "oro")
	eq(r.Gems, nil, "gemas")
	eq(r.Stones, nil, "piedras")
end)

test("con suerte suelta gema y piedra", function()
	local r = Loot.roll(1, false, 1, fixed(0.001))
	eq(r.Gems, 1, "gema")
	eq(r.Stones, 1, "piedra")
	assert(r.Gold >= 1, "siempre al menos 1 de oro")
end)

test("el capítulo multiplica el botín", function()
	local a = Loot.roll(4, false, 1, fixed(0.5))
	local b = Loot.roll(4, false, 2.5, fixed(0.5))
	eq(b.Gold, math.floor(a.Gold * 2.5 + 0.5), "oro x2.5")
end)

test("los jefes sueltan el extra de Config.Loot.Boss", function()
	local r = Loot.roll(1, true, 1, fixed(0.5))
	eq(r.Gold, 1 + Config.Loot.Boss.Gold, "oro")
	eq(r.Gems, Config.Loot.Boss.Gems, "gemas")
	eq(r.Stones, Config.Loot.Boss.Stones, "piedras")
end)

test("variación: el oro queda dentro de ±GoldVariation", function()
	local cost = 10
	for _ = 1, 200 do
		local g = Loot.roll(cost, false, 1).Gold
		assert(g >= math.floor(cost * (1 - Config.Loot.GoldVariation)), "muy poco: " .. g)
		assert(g <= math.ceil(cost * (1 + Config.Loot.GoldVariation)), "demasiado: " .. g)
	end
end)

local P = M.addPlayer("Ana")
local Q = M.addPlayer("Beto")
local enemyA, enemyB = {}, {}

test("golpes seguidos al mismo enemigo se suman en un solo número", function()
	CombatFeed.clear()
	CombatFeed.dealt(P, enemyA, M.Vector3.new(1, 0, 0), 10, "hit")
	CombatFeed.dealt(P, enemyA, M.Vector3.new(2, 0, 0), 15, "hit")
	CombatFeed.dealt(P, enemyB, M.Vector3.new(5, 0, 0), 7, "hit")
	local out = CombatFeed.collect()
	eq(#out[P], 2, "dos números (uno por enemigo)")
	local total = 0
	for _, e in out[P] do total += e.a end
	eq(total, 32, "suma")
	eq(out[Q], nil, "Beto no ve el daño de Ana")
end)

test("la quemadura junta fracciones hasta llegar a 1", function()
	CombatFeed.clear()
	for _ = 1, 3 do CombatFeed.dealt(P, enemyA, M.Vector3.zero, 0.3, "burn") end
	local out = CombatFeed.collect()
	eq(out[P], nil, "todavía nada (0.9)")
	CombatFeed.dealt(P, enemyA, M.Vector3.zero, 0.3, "burn")
	out = CombatFeed.collect()
	eq(out[P][1].k, "burn", "tipo")
	eq(out[P][1].a, 1, "1 de quemadura")
end)

test("daño recibido, XP para todos y botín de cada uno", function()
	CombatFeed.clear()
	CombatFeed.hurt(P, 12.4)
	CombatFeed.xp({ P, Q }, M.Vector3.zero, 5)
	CombatFeed.loot(Q, M.Vector3.zero, { Gold = 3 })
	CombatFeed.loot(P, M.Vector3.zero, {}) -- vacío: no se manda
	local out = CombatFeed.collect()
	eq(#out[P], 2, "Ana: daño recibido y XP")
	eq(out[P][1].k, "hurt", "tipo")
	eq(out[P][1].a, 12, "redondeo")
	eq(#out[Q], 2, "Beto: XP y botín")
	eq(out[Q][2].g.Gold, 3, "oro")
	eq(next(CombatFeed.collect()), nil, "después de mandar, no queda nada")
end)

test("se manda como mucho una vez cada FlushInterval", function()
	CombatFeed.clear()
	local sent = 0
	local fake = { FireClient = function() sent += 1 end }
	CombatFeed.init(fake :: any)
	CombatFeed.update(100)
	CombatFeed.hurt(P, 5)
	CombatFeed.update(100 + Config.CombatText.FlushInterval / 2)
	eq(sent, 0, "muy pronto")
	CombatFeed.update(100 + Config.CombatText.FlushInterval * 1.01)
	eq(sent, 1, "una vez")
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then
	error("hay pruebas que fallaron")
end
