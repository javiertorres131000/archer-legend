-- Modos: torre infinita (pisos, ambientaciones, jefes, premios por hito) y desafío diario
-- (mismo para todos el mismo día, modificadores, premio una vez por día).
local M = require("./mocks")
require("./GameServer")
local Chapters = require("./Chapters")
local Modes = require("./Modes")
local Waves = require("./Waves")
local Rewards = require("./Rewards")
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local EnemyTypes = require("./EnemyTypes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

print("Modos")

test("capítulos 4 y 5: enemigos, jefes y desbloqueo en cadena", function()
	eq(#Chapters, 5, "capítulos")
	eq(Chapters[4].Id, "glacier")
	eq(Chapters[5].Id, "desert")
	eq(Chapters[4].Requires, "fortress")
	eq(Chapters[5].Requires, "glacier")
	for i = 4, 5 do
		local ch = Chapters[i]
		assert(EnemyTypes[ch.Boss.Type].Boss and EnemyTypes[ch.MiniBoss.Type].Boss, ch.Id)
		assert(ch.Lighting and ch.Lighting.Weather, "clima " .. ch.Id)
		assert(ch.HealthMult > Chapters[i - 1].HealthMult, "más difícil que el anterior")
		assert(ch.Rewards.VictoryGold > Chapters[i - 1].Rewards.VictoryGold, "paga más")
		assert(#Waves.buildQueue(ch, 1) > 0)
	end
end)

test("torre: el piso define ambientación, piso del tramo y jefes", function()
	local f1 = Modes.towerChapter(1)
	eq(f1.ThemeIndex, 1)
	eq(f1.LocalWave, 1)
	assert(f1.Endless, "sin final")
	eq(Modes.towerChapter(10).LocalWave, 10, "piso 10: jefe del tramo")
	eq(Modes.towerChapter(11).ThemeIndex, 2, "piso 11: ruinas")
	eq(Modes.towerChapter(11).LocalWave, 1)
	eq(Modes.towerChapter(45).ThemeIndex, 5, "piso 45: desierto")
	local lap = Modes.towerChapter(51)
	eq(lap.ThemeIndex, 1, "vuelve al bosque")
	assert(lap.HealthMult > Chapters[1].HealthMult * 1.5, "segunda vuelta más difícil")
	-- No se tocan los capítulos originales al armar pisos
	eq(Chapters[1].Id, "forest")
	assert(not Chapters[1].Endless)
end)

test("torre: hitos de pisos múltiplos de 10, una vez cada uno", function()
	local m = Modes.towerMilestones(0, 9)
	assert(next(m) == nil, "sin hito antes del 10")
	m = Modes.towerMilestones(0, 23)
	eq(m.Gems, Modes.Tower.Milestone.Gems * 2, "10 y 20")
	m = Modes.towerMilestones(23, 29)
	assert(next(m) == nil, "ya los tenía")
	m = Modes.towerMilestones(23, 31)
	eq(m.Gems, Modes.Tower.Milestone.Gems, "el 30")
end)

test("torre: oro por piso y por jefe, sin tope de pisos", function()
	local def = Modes.towerChapter(25)
	local a = Rewards.compute(def, { result = "Defeat", wavesCleared = 25, bossesKilled = { "Treant", "KingSlime", "StoneGolem" }, kills = 500 }, false)
	eq(a.Gold, 25 * Modes.Tower.GoldPerFloor + 3 * Modes.Tower.BossGold, "oro")
end)

test("torre en Waves: TotalWaves 0, no hay victoria y el HUD sabe el piso", function()
	Waves.setChapter(1)
	Waves.setMode("tower")
	local gs = require("./Remotes").GameState
	eq(gs:GetAttribute("TotalWaves"), 0, "sin final")
	eq(gs:GetAttribute("Mode"), "tower")
	assert(Waves.currentChapter().Endless)
	Waves.setChapter(1)
	eq(gs:GetAttribute("Mode"), "", "capítulo normal")
end)

test("desafío diario: igual todo el día, cambia otro día, con 2 modificadores", function()
	local a, b = Modes.dailyInfo(20000), Modes.dailyInfo(20000)
	eq(a.chapter, b.chapter)
	eq(#a.modifiers, Modes.Daily.ModifierCount)
	assert(a.modifiers[1] ~= a.modifiers[2], "distintos")
	local different = false
	for d = 1, 10 do
		local c = Modes.dailyInfo(20000 + d)
		if c.chapter ~= a.chapter or c.modifiers[1] ~= a.modifiers[1] then different = true end
	end
	assert(different, "nunca cambia")
	for d = 20000, 20030 do
		local def = Modes.dailyChapter(d)
		eq(def.Mode, "daily")
		assert(def.HealthMult >= Modes.Daily.HealthMult, "base del desafío")
		assert(#Waves.buildQueue(def, 1) > 0)
		assert(type(Modes.dailyText(d)) == "string")
	end
end)

test("desafío diario: modificadores de jugador", function()
	-- Buscar un día con Cañón de cristal
	for d = 20000, 20400 do
		local info = Modes.dailyInfo(d)
		if table.find(info.modifiers, "Glass") then
			local s = PlayerData.newStats()
			local hp, dmg = s.maxHealth, s.damage
			Modes.applyDailyPlayer(s, d)
			eq(s.maxHealth, hp * 0.5, "mitad de vida")
			assert(math.abs(s.damage - dmg * 1.6) < 1e-6, "más daño")
			return
		end
	end
	error("ningún día con Cañón de cristal en 400 días")
end)

test("desafío diario: el premio extra se cobra una vez por día", function()
	local p = M.addPlayer("Diario")
	local data = Profiles.get(p)
	local day = Modes.day(M.os.time()) -- el reloj de los módulos es el de mocks
	local def = Modes.dailyChapter(day)
	data.Modes.DailyWonDay = -1
	local gems = data.Currencies.Gems
	local g = Rewards.grant(p, def, { result = "Victory", wavesCleared = def.Waves, bossesKilled = {}, kills = 100 })
	assert(g and g.dailyBonus, "premio del día")
	eq(data.Modes.DailyWonDay, day)
	assert(data.Currencies.Gems >= gems + Modes.Daily.Reward.Gems, "gemas")
	g = Rewards.grant(p, def, { result = "Victory", wavesCleared = def.Waves, bossesKilled = {}, kills = 100 })
	assert(g and not g.dailyBonus, "solo una vez por día")
	-- La torre guarda el récord de pisos como un capítulo más
	local tower = Modes.towerChapter(12)
	Rewards.grant(p, tower, { result = "Defeat", wavesCleared = 12, bossesKilled = { "Treant" }, kills = 300 })
	eq(Profiles.chapter(p, "tower").BestWave, 12, "récord de la torre")
end)

print(passed .. " pruebas, 0 fallas")
