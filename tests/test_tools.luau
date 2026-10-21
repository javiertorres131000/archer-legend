-- Herramientas de prueba y balance: panel de stats, registro de partidas y comandos de prueba.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local Equipment = require("./Equipment")
local Runes = require("./Runes")
local Talents = require("./Talents")
local StatsBreakdown = require("./StatsBreakdown")
local RunLog = require("./RunLog")
local DebugCommands = require("./DebugCommands")
local Run = require("./Run")
local Waves = require("./Waves")
local Enemies = require("./Enemies")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end

print("Herramientas de prueba y balance")
local p = M.addPlayer("Probador")
local data = Profiles.get(p)

test("stats: base → equipo → talentos → runas, sin tocar las stats reales", function()
	local r = StatsBreakdown.compute(p)
	assert(#r.columns == 5 and r.columns[1] == "Base" and r.columns[4] == "Runas" and r.columns[5] == "Mascota" and not r.inMatch)
	local base = PlayerData.newStats()
	assert(r.values[1].damage == base.damage)
	local withEquip = PlayerData.newStats(); Equipment.apply(p, withEquip)
	assert(r.values[2].damage == withEquip.damage) -- el equipo inicial ya suma algo
	data.Talents = { Core = 1, Edge = 5 }
	Runes.grant(p, "Fury")
	r = StatsBreakdown.compute(p)
	assert(r.values[3].damage > r.values[2].damage and r.values[4].damage > r.values[3].damage)
	local real = PlayerData.get(p).stats.damage
	StatsBreakdown.compute(p)
	assert(PlayerData.get(p).stats.damage == real)
	assert(#r.rows >= 10 and r.rows[1].key == "damage")
end)

test("stats en partida: agrega la columna Ahora con lo de la partida", function()
	local s = PlayerData.get(p)
	s.inMatch = true
	s.stats.damage = 999
	local r = StatsBreakdown.compute(p)
	assert(#r.columns == 6 and r.columns[6] == "Ahora" and r.values[6].damage == 999 and r.inMatch)
	s.inMatch = false
	s.stats = PlayerData.newStats()
end)

test("stats por remoto: responde y limita la frecuencia", function()
	local sent = 0
	local old = Remotes.StatsState.FireClient
	Remotes.StatsState.FireClient = function() sent += 1 end
	M.advance(1)
	Remotes.StatsRequest.OnServerEvent:Fire(p)
	Remotes.StatsRequest.OnServerEvent:Fire(p)
	assert(sent == 1)
	M.advance(1)
	Remotes.StatsRequest.OnServerEvent:Fire(p)
	assert(sent == 2)
	Remotes.StatsState.FireClient = old
end)

local function fakeEntry(ch, result, waves, secs, gold, dmg)
	return {
		t = 0, ch = ch, r = result, w = waves, tw = 10, s = secs, n = 1, lv = 5, k = 100, dmg = dmg, dn = 1, rv = 0,
		g = gold, gm = 0, st = 0, xp = 300, al = 2, tp = 1, eq = 6, ru = 0, sk = {}, it = {},
	}
end

test("registro: arma la fila desde el resumen y el perfil", function()
	local s = PlayerData.get(p)
	s.kills, s.damageDealt, s.downs, s.revives = 120, 5432.6, 2, 1
	s.stats.stacks = { Damage = 2 }
	local summary = { chapter = 1, result = "Defeat", wavesCleared = 4, totalWaves = 10, time = 300, partySize = 2, level = 7 }
	local personal = { rewards = { Gold = 40 }, loot = { Gold = 900, Gems = 2 }, accountXP = 250 }
	local e = RunLog.entry(p, summary, personal, s)
	assert(e.ch == "forest" and e.r == "Defeat" and e.w == 4 and e.s == 300 and e.n == 2 and e.lv == 7)
	assert(e.k == 120 and e.dmg == 5432 and e.dn == 2 and e.rv == 1)
	assert(e.g == 940 and e.gm == 2 and e.xp == 250)
	assert(e.tp == Talents.spent(data.Talents) and e.eq >= 6 and e.ru >= 1 and e.sk.Damage == 2)
	s.stats.stacks.Damage = 5
	assert(e.sk.Damage == 2) -- copia, no la tabla viva
end)

test("registro: promedios por capítulo, sin contar abandonos", function()
	local report = RunLog.aggregate({
		fakeEntry("forest", "Victory", 10, 600, 4000, 60000),
		fakeEntry("forest", "Defeat", 4, 200, 1000, 10000),
		fakeEntry("forest", "Abandoned", 0, 10, 0, 0),
		fakeEntry("ruins", "Defeat", 2, 100, 500, 1000),
	})
	local f = report.forest
	assert(f.runs == 2 and f.victories == 1 and f.avgWaves == 7 and f.avgTime == 400 and f.avgGold == 2500)
	assert(math.abs(f.avgDps - (100 + 50) / 2) < 1e-6)
	assert(report.ruins.runs == 1)
end)

test("registro: memoria con tope y una escritura por partida al DataStore", function()
	RunLog.reset()
	local before = M.dataStore.calls
	for i = 1, Config.RunLog.MemoryLimit + 5 do
		RunLog.record(fakeEntry("forest", "Defeat", i % 10, 100, 10, 10))
	end
	assert(#RunLog.recent() == Config.RunLog.MemoryLimit)
	RunLog.flush()
	assert(M.dataStore.calls == before + 1)
	local key = RunLog.dayKey(M.os.time())
	local stored = M.dataStore.data[key]
	assert(type(stored) == "table" and #stored == Config.RunLog.MemoryLimit + 5)
	RunLog.flush() -- nada pendiente: no escribe
	assert(M.dataStore.calls == before + 1)
	-- Tope por día
	for _ = 1, Config.RunLog.PerDayLimit do
		RunLog.record(fakeEntry("forest", "Defeat", 1, 100, 10, 10))
	end
	RunLog.flush()
	assert(#M.dataStore.data[key] == Config.RunLog.PerDayLimit)
	local text = RunLog.report(1)
	assert(string.find(text, "Bosque", 1, true) or string.find(text, "partidas", 1, true))
end)

test("registro: Studio sin acceso al DataStore no rompe ni reintenta", function()
	RunLog.reset()
	M.dataStore.accessDenied = true
	RunLog.record(fakeEntry("forest", "Defeat", 1, 100, 10, 10))
	RunLog.flush()
	local calls = M.dataStore.calls
	RunLog.record(fakeEntry("forest", "Defeat", 1, 100, 10, 10))
	RunLog.flush()
	assert(M.dataStore.calls == calls) -- ya no lo intenta
	assert(#RunLog.load(7) == 2) -- usa la memoria
	M.dataStore.accessDenied = false
	RunLog.reset()
end)

test("comandos: en Studio sí; publicado solo admins; el pedido ajeno se ignora", function()
	assert(DebugCommands.allowed(p) and type(p:GetAttribute("DebugAllowed")) == "string")
	M.isStudio = false
	assert(not DebugCommands.allowed(p))
	local gold = data.Currencies.Gold
	local replies = 0
	local old = Remotes.DebugCommand.FireClient
	Remotes.DebugCommand.FireClient = function() replies += 1 end
	M.advance(1)
	Remotes.DebugCommand.OnServerEvent:Fire(p, "Gold")
	assert(data.Currencies.Gold == gold and replies == 0)
	table.insert(Config.Debug.Admins, p.UserId)
	assert(DebugCommands.allowed(p))
	M.advance(1)
	Remotes.DebugCommand.OnServerEvent:Fire(p, "Gold")
	assert(data.Currencies.Gold == gold + 5000 and replies == 1)
	table.clear(Config.Debug.Admins)
	M.isStudio = true
	Config.Debug.Commands = false
	assert(not DebugCommands.allowed(p))
	Config.Debug.Commands = true
	Remotes.DebugCommand.FireClient = old
end)

test("comandos: validan acción, frecuencia y partida", function()
	M.advance(1)
	assert(not DebugCommands.run(p, "Inventado"))
	M.advance(1)
	assert(not DebugCommands.run(p, { "Gold" }))
	M.advance(1)
	assert(DebugCommands.run(p, "Gems"))
	assert(not DebugCommands.run(p, "Gems")) -- muy seguido
	M.advance(1)
	local ok, msg = DebugCommands.run(p, "SkipWave")
	assert(not ok and string.find(msg, "partida"))
	M.advance(1)
	local level = data.Account.Level
	assert(DebugCommands.run(p, "Levels"))
	assert(data.Account.Level == level + 5)
	M.advance(1)
	assert(DebugCommands.run(p, "Chapters"))
	for _, rec in data.Chapters do assert(rec.Unlocked) end
end)

test("comandos de partida: saltar oleada, jefe, objeto y curar", function()
	local mode = Config.Camera.Mode
	Config.Camera.Mode = "TopDown" -- sin cámara en las pruebas
	Run.start(1, { p })
	Run.step(0.1)
	assert(Waves.phase() == "Wave")
	M.advance(1)
	assert(DebugCommands.run(p, "Boss"))
	local bosses = 0
	for _, e in Enemies.list do if e.alive and e.def.Boss then bosses += 1 end end
	M.advance(1)
	assert(DebugCommands.run(p, "Item"))
	M.advance(1)
	assert(DebugCommands.run(p, "KillAll"))
	assert(Enemies.aliveCount() == 0)
	M.advance(1)
	assert(DebugCommands.run(p, "SkipWave"))
	Run.step(0.1)
	assert(Waves.phase() == "Break", Waves.phase())
	M.advance(1)
	assert(DebugCommands.run(p, "Heal"))
	M.advance(1)
	assert(DebugCommands.run(p, "LevelUp"))
	Run.cleanup()
	Config.Camera.Mode = mode
	assert(bosses == 1, "jefes: " .. bosses)
end)

print(passed .. " pruebas, 0 fallas")
