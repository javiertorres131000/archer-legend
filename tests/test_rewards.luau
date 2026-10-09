-- Recompensas (Rewards.compute): cálculo puro con los valores de Chapters.lua.
local _M = require("./mocks")
local Chapters = require("./Chapters")
local Rewards = require("./Rewards")
local Currencies = require("./Currencies")

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

print("Recompensas")
local forest = Chapters[1]

test("derrota en la oleada 4 (3 superadas): solo oro por oleadas", function()
	local r = Rewards.compute(forest, { result = "Defeat", wavesCleared = 3, bossesKilled = {}, kills = 20 }, false)
	eq(r.Gold, 30, "oro")
	eq(r.Gems, nil, "gemas")
	eq(r.Stones, nil, "piedras")
end)

test("derrota después del mini-jefe: oro y piedras del mini-jefe", function()
	local r = Rewards.compute(forest, { result = "Defeat", wavesCleared = 6, bossesKilled = { "KingSlime" }, kills = 0 }, false)
	eq(r.Gold, 60 + 30, "oro")
	eq(r.Stones, 1, "piedras")
end)

test("primera victoria: todo + gemas de primera vez", function()
	local r = Rewards.compute(forest, { result = "Victory", wavesCleared = 10, bossesKilled = { "KingSlime", "Treant" }, kills = 0 }, true)
	eq(r.Gold, 100 + 30 + 60 + 100, "oro")
	eq(r.Gems, 5 + 50, "gemas")
	eq(r.Stones, 1 + 2, "piedras")
end)

test("victoria repetida: sin gemas de primera vez", function()
	local r = Rewards.compute(forest, { result = "Victory", wavesCleared = 10, bossesKilled = { "KingSlime", "Treant" }, kills = 0 }, false)
	eq(r.Gems, 5, "gemas")
end)

test("valores raros del servidor no inflan nada (oleadas fuera de rango, jefes ajenos)", function()
	local r = Rewards.compute(forest, { result = "Defeat", wavesCleared = 999, bossesKilled = { "StoneGolem" }, kills = 0 }, false)
	eq(r.Gold, 10 * forest.Waves, "oro con tope de oleadas")
	eq(r.Stones, nil, "un jefe de otro capítulo no paga")
	local none = Rewards.compute(forest, { result = "Defeat", wavesCleared = -3, bossesKilled = {}, kills = 0 }, false)
	eq(none.Gold, nil, "negativo")
end)

test("cada capítulo tiene recompensas con monedas existentes y paga más que el anterior", function()
	local valid = {}
	for _, c in Currencies do valid[c.Id] = true end
	local prevGold = 0
	for _, ch in Chapters do
		assert(ch.Rewards, ch.Id .. " sin Rewards")
		for _, key in { "MiniBoss", "Boss" } do
			for id in ch.Rewards[key] do
				assert(valid[id], ch.Id .. "." .. key .. ": moneda desconocida " .. id)
			end
		end
		local r = Rewards.compute(ch, { result = "Victory", wavesCleared = ch.Waves, bossesKilled = { ch.MiniBoss.Type, ch.Boss.Type }, kills = 0 }, false)
		assert(r.Gold > prevGold, ch.Id .. " debería pagar más oro que el anterior")
		prevGold = r.Gold
	end
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then
	error("hay pruebas que fallaron")
end
