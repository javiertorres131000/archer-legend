-- Eventos de la oleada (élites, horda, metas de equipo) y maestría por arma con candados.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Chests = require("./Chests")
local WaveEvents = require("./WaveEvents")
local Chapters = require("./Chapters")
local Remotes = require("./Remotes")
local Mastery = require("./Mastery")
local MasteryService = require("./MasteryService")
local Profiles = require("./Profiles")
local Rewards = require("./Rewards")
local Progression = require("./Progression")
local Skills = require("./Skills")
local Waves = require("./Waves")

local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end
local V = M.Vector3.new
local gs = Remotes.GameState

print("Eventos de la oleada y maestría")
local p = M.addPlayer("Eventos")
local state = PlayerData.get(p)
state.inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = V(0, 3, 0)
local forest = Chapters[1]

local function waveInfo(n, extra)
	local info = { wave = n, localWave = n, chapter = forest, queueSize = 40, countScale = 1, bossWave = false, healthMult = 1, dmgMult = 1 }
	for k, v in extra or {} do info[k] = v end
	return info
end

local function fresh()
	Enemies.clear()
	Chests.clear()
	WaveEvents.reset()
end

---------------------------------------------------------------------
-- Élites
---------------------------------------------------------------------
test("élites: cuántos por oleada (ninguno al principio, más con las oleadas, con tope)", function()
	eq(WaveEvents.eliteCount(1), 0, "oleada 1")
	eq(WaveEvents.eliteCount(2), 1, "oleada 2")
	eq(WaveEvents.eliteCount(8), 3, "oleada 8")
	eq(WaveEvents.eliteCount(100), Config.Events.Elite.Max, "tope")
end)

test("élites: salen en la cola, solo de tipos comunes, y cada uno una vez", function()
	fresh()
	local cfg = Config.Events.Horde
	local oldChance = cfg.Chance
	cfg.Chance = 0
	WaveEvents.onWaveStart(waveInfo(8))
	cfg.Chance = oldChance
	local got = 0
	for remaining = 40, 1, -1 do
		if WaveEvents.takeElite("Treant", remaining) then
			error("un jefe salió élite")
		end
		if WaveEvents.takeElite("HordeSkeleton", remaining) then
			got += 1
		end
	end
	eq(got, 3, "élites de la oleada 8")
end)

test("élite: más vida, más grande, cartel con su rasgo, más XP; al morir suelta un cofre", function()
	fresh()
	local affix = Config.Events.Elite.Affixes[1]
	local normal = Enemies.spawn("HordeSkeleton", V(10, 0, 10))
	local elite = Enemies.spawn("HordeSkeleton", V(-10, 0, 10), { elite = affix })
	eq(elite.elite, affix.Id, "rasgo")
	assert(elite.maxHealth >= normal.maxHealth * Config.Events.Elite.HealthMult - 1e-6, "vida")
	assert(elite.radius > normal.radius, "más grande")
	assert(elite.xp > normal.xp, "más XP")
	eq(elite.part:GetAttribute("Elite"), true, "marca de élite")
	eq(elite.part:GetAttribute("EliteAffix"), affix.Name, "rasgo en el cartel")
	-- Un jefe nunca se vuelve élite
	local boss = Enemies.spawn("Treant", V(0, 0, 30), { elite = affix })
	eq(boss.elite, nil, "jefe")
	local before = Chests.count()
	WaveEvents.onKill(elite, V(-10, 0, 10))
	eq(Chests.count(), before + 1, "cofre del élite")
	WaveEvents.onKill(normal, V(10, 0, 10))
	eq(Chests.count(), before + 1, "el común no suelta")
end)

test("cofre soltado: tarda un instante en poder abrirse y no es peor que la rareza pedida", function()
	fresh()
	for _ = 1, 30 do
		local r = Chests.rollAtLeast("Rare")
		assert(table.find({ "Rare", "Epic", "Legendary", "Mythic" }, r), "rareza " .. r)
	end
	Chests.dropAt(V(0, 0, 0), "Rare")
	local opened = 0
	Chests.onOpened(function() opened += 1 end)
	Chests.update({ { player = p, root = target.root } }, false)
	eq(opened, 0, "recién soltado")
	M.advance(1)
	Chests.update({ { player = p, root = target.root } }, false)
	eq(opened, 1, "abierto")
end)

---------------------------------------------------------------------
-- Horda
---------------------------------------------------------------------
test("horda: tipos más baratos del capítulo; aparece, frena el fin de la oleada y premia al superarla", function()
	fresh()
	local types = WaveEvents.hordeTypes(forest, 3)
	assert(#types == 2 and types[1], "tipos")
	WaveEvents.onWaveStart(waveInfo(3, { bossWave = true })) -- con jefe nunca hay horda...
	WaveEvents.update(30, { target })
	eq(WaveEvents.hordeState(), "", "sin horda en la oleada del jefe")
	WaveEvents.onWaveStart(waveInfo(3))
	WaveEvents.debugHorde(forest) -- ...pero se puede forzar
	WaveEvents.update(0.01, { target })
	eq(gs:GetAttribute("HordeState"), "active", "empezó")
	local total = gs:GetAttribute("HordeLeft")
	assert(total >= Config.Events.Horde.Count, "cuántos: " .. tostring(total))
	assert(WaveEvents.pending() > 0, "falta aparecer: la oleada no termina")
	-- Aparecen por tandas
	for _ = 1, 40 do
		WaveEvents.update(Config.Events.Horde.BurstEvery + 0.01, { target })
	end
	eq(WaveEvents.pending(), 0, "ya aparecieron todos")
	local horde = 0
	for _, e in Enemies.list do
		if e.horde then horde += 1 end
	end
	eq(horde, total, "todos de horda")
	-- Morir todos = superada: cofre para el equipo
	local chests = Chests.count()
	for _, e in table.clone(Enemies.list) do
		if e.horde then Enemies.damage(e, e.health + 1, nil, "debug") end
	end
	WaveEvents.update(0.01, { target })
	eq(gs:GetAttribute("HordeState"), "cleared", "superada")
	eq(Chests.count(), chests + 1, "cofre de la horda")
end)

---------------------------------------------------------------------
-- Metas de equipo
---------------------------------------------------------------------
local function startGoal(id)
	for _ = 1, 50 do
		fresh()
		WaveEvents.onWaveStart(waveInfo(4))
		WaveEvents.debugGoal({ target })
		local g = WaveEvents.goal()
		if g and g.id == id then return g end
	end
	error("no salió la meta " .. id)
end

test("meta: matar N en T segundos (cumplida y fallida por tiempo)", function()
	local g = startGoal("Kills")
	eq(gs:GetAttribute("GoalState"), "active")
	local chests = Chests.count()
	local dummy = Enemies.spawn("HordeSkeleton", V(5, 0, 5))
	for _ = 1, g.target do WaveEvents.onKill(dummy, V(5, 0, 5)) end
	eq(gs:GetAttribute("GoalState"), "done", "cumplida")
	eq(Chests.count(), chests + 1, "cofre del premio")
	eq(state.teamGoals, 1, "cuenta en la partida")
	g = startGoal("Kills")
	WaveEvents.update(Config.Events.Goals.Kills.Time + 1, { target })
	eq(gs:GetAttribute("GoalState"), "failed", "se acabó el tiempo")
end)

test("meta: matar al élite marcado", function()
	local g = startGoal("Elite")
	assert(g.enemy and g.enemy.elite and g.enemy.goalTarget, "élite marcado")
	local other = Enemies.spawn("HordeSkeleton", V(5, 0, 5))
	WaveEvents.onKill(other, V(5, 0, 5))
	eq(gs:GetAttribute("GoalState"), "active", "otro no cuenta")
	WaveEvents.onKill(g.enemy, V(0, 0, 0))
	eq(gs:GetAttribute("GoalState"), "done", "cumplida")
end)

test("meta: abrir cofres y que nadie caiga (se decide al terminar la oleada)", function()
	startGoal("Chests")
	for _ = 1, Config.Events.Goals.Chests.Count do WaveEvents.onChestOpened(V(0, 0, 0)) end
	eq(gs:GetAttribute("GoalState"), "done", "cofres")
	startGoal("Chests")
	WaveEvents.onWaveEnd()
	eq(gs:GetAttribute("GoalState"), "failed", "sin cofres al terminar")
	startGoal("NoDown")
	WaveEvents.onWaveEnd()
	eq(gs:GetAttribute("GoalState"), "done", "nadie cayó")
	startGoal("NoDown")
	state.downs += 1
	WaveEvents.update(0.1, { target })
	eq(gs:GetAttribute("GoalState"), "failed", "alguien cayó")
	state.downs -= 1
end)

test("metas: ninguna en la primera oleada; sale sola a los pocos segundos", function()
	fresh()
	WaveEvents.onWaveStart(waveInfo(1))
	WaveEvents.update(Config.Events.Goals.Delay + 1, { target })
	eq(WaveEvents.goal(), nil, "oleada 1")
	WaveEvents.onWaveStart(waveInfo(2))
	WaveEvents.update(Config.Events.Goals.Delay + 0.1, { target })
	assert(WaveEvents.goal(), "oleada 2: hay meta")
	fresh()
	eq(gs:GetAttribute("GoalState"), "", "limpio")
end)

---------------------------------------------------------------------
-- Maestría
---------------------------------------------------------------------
test("maestría: niveles, progreso, bono, títulos y texto del atributo", function()
	eq(Mastery.levelOf(0), 1)
	eq(Mastery.levelOf(Mastery.Levels[2]), 2)
	eq(Mastery.levelOf(Mastery.Levels[2] - 1), 1)
	eq(Mastery.levelOf(1e9), Mastery.MaxLevel)
	local into, needed = Mastery.progress(Mastery.Levels[2] + 10)
	eq(into, 10)
	eq(needed, Mastery.Levels[3] - Mastery.Levels[2])
	local _, none = Mastery.progress(1e9)
	eq(none, 0, "máximo")
	local dmg, crit = Mastery.bonus(1)
	eq(dmg, 0)
	eq(crit, 0)
	dmg, crit = Mastery.bonus(10)
	assert(math.abs(dmg - 0.18) < 1e-9 and math.abs(crit - 0.05) < 1e-9, "bono al máximo")
	eq(Mastery.title(2), nil)
	eq(Mastery.title(6), "Experto")
	local decoded = Mastery.decode(Mastery.encode({ Bow = 12, Sword = 3400 }))
	eq(decoded.Bow, 12)
	eq(decoded.Sword, 3400)
	eq(decoded.Fists, 0)
	eq(next(Mastery.decode("Hack=99,nada")), nil, "basura")
end)

test("maestría: XP de la partida (abandonar no da)", function()
	eq(Mastery.runXP({ result = "Abandoned", kills = 500 }), 0)
	local d = Mastery.runXP({ result = "Defeat", kills = 100, wavesCleared = 3, bosses = 1 })
	eq(d, 100 + 3 * Mastery.XP.PerWave + Mastery.XP.PerBoss)
	eq(Mastery.runXP({ result = "Victory", kills = 0, wavesCleared = 0, bosses = 0 }), Mastery.XP.Victory)
end)

test("candados: cada habilidad bloqueada existe, es de su arma y de la segunda tanda", function()
	for family, list in Mastery.Locks do
		for skillId, level in list do
			local def = Skills.ById[skillId]
			assert(def, "no existe " .. skillId)
			eq(def.Weapon, family, skillId)
			eq(def.Tier, 2, skillId)
			assert(level > 1 and level <= Mastery.MaxLevel, skillId)
		end
	end
	local locked = Mastery.lockedSkills({})
	assert(locked.BladeDance and locked.PhantomArrow and locked.DragonFist, "sin maestría: bloqueadas")
	locked = Mastery.lockedSkills({ Sword = Mastery.Levels[5] })
	assert(not locked.BladeDance and not locked.DashSlash and locked.PhantomArrow, "espada 5")
end)

test("candados: una habilidad bloqueada no sale en las ofertas", function()
	state.stats = PlayerData.newStats()
	state.stats.weapon = "Sword"
	state.stats.stacks = { WideBlade = 1, Execute = 1, LongBlade = 1, Riposte = 1 } -- mazo para la legendaria
	state.inMatch = false
	Progression.reset()
	while Progression.level() < Config.Progression.SecondTierLevel do
		Progression.addXP(1000)
	end
	state.inMatch = true
	local function seen(id)
		for _ = 1, 400 do
			for _, c in Progression.rollChoices(state.stats) do
				if c == id then return true end
			end
		end
		return false
	end
	assert(seen("BladeDance"), "sin candado sale")
	state.stats.lockedSkills = Mastery.lockedSkills({})
	assert(not seen("BladeDance") and not seen("DashSlash"), "con candado no sale")
	assert(seen("SlashWave"), "las otras de la segunda tanda sí")
	Progression.reset()
end)

test("maestría en la partida: suma XP al terminar, sube de nivel, avisa lo desbloqueado y da el bono", function()
	local data = Profiles.get(p)
	data.Mastery = {}
	data.Weapon = "FrostKatana" -- especial: suma a Espada
	local r = MasteryService.grant(p, "FrostKatana", { result = "Victory", kills = 2500, wavesCleared = 10, bosses = 2 })
	assert(r, "resultado")
	eq(r.family, "Sword", "familia de la katana")
	assert(r.level > r.levelBefore, "subió")
	eq(data.Mastery.Sword, r.xp, "guardado")
	assert(string.find(p:GetAttribute("Mastery"), "Sword=" .. r.xp, 1, true), "atributo")
	local found = false
	for _, text in r.unlocked do
		if string.find(text, Skills.ById.DashSlash.Name, 1, true) then found = true end
	end
	assert(found, "avisa Tajo veloz: " .. table.concat(r.unlocked, " | "))
	-- Bono al empezar
	local stats = PlayerData.newStats()
	stats.weapon = "Sword"
	local base = stats.damage
	MasteryService.apply(p, stats)
	local dmg = Mastery.bonus(Mastery.levelOf(r.xp))
	assert(math.abs(stats.damage - base * (1 + dmg)) < 1e-6, "bono de daño")
	assert(stats.lockedSkills and not stats.lockedSkills.DashSlash and stats.lockedSkills.PhantomArrow, "candados")
	-- Con otra arma, el bono es el de esa familia (nivel 1: nada)
	stats = PlayerData.newStats()
	stats.weapon = "Bow"
	base = stats.damage
	MasteryService.apply(p, stats)
	eq(stats.damage, base, "arco sin maestría")
	-- Rewards la incluye
	local g = Rewards.grant(p, forest, { result = "Defeat", wavesCleared = 2, bossesKilled = {}, kills = 50, weapon = "Bow" })
	assert(g and g.mastery and g.mastery.family == "Bow" and g.mastery.gained > 0, "rewards con maestría")
end)

test("perfil: la maestría se guarda; datos rotos se descartan; los perfiles viejos arrancan con XP", function()
	local rec = Profiles.reconcile({ Mastery = { Bow = 120, Hack = 5, Sword = -3, Fists = "x" } })
	eq(rec.Mastery.Bow, 120)
	eq(rec.Mastery.Hack, nil)
	eq(rec.Mastery.Sword, nil)
	eq(rec.Mastery.Fists, nil)
	local old = Profiles.migrate(10, { Weapon = "InfernoBlade", Stats = { Kills = 2000 } })
	eq(old.Mastery.Sword, 1000, "mitad de las bajas a su familia")
	local veteran = Profiles.migrate(10, { Weapon = "Bow", Stats = { Kills = 10 ^ 7 } })
	eq(veteran.Mastery.Bow, Mastery.Levels[Mastery.MigrationCapLevel], "con tope")
	local new = Profiles.migrate(10, {})
	eq(next(new.Mastery), nil, "nuevo: nada")
	eq(Profiles.SCHEMA_VERSION, 11)
end)

test("oleadas reales: con élites y metas la partida sigue terminando sus oleadas", function()
	-- Smoke: una oleada completa del capítulo 1 con los eventos activos
	Waves.setChapter(1)
	Waves.reset()
	fresh()
	Waves.update(0.1, { target }, false)
	eq(Waves.phase(), "Wave")
	for _ = 1, 4000 do
		Waves.update(0.1, { target }, false)
		for _, e in table.clone(Enemies.list) do
			if e.alive then Enemies.damage(e, e.health + 1, nil, "debug") end
		end
		Enemies.update(0.1, { target }, M.now, false)
		if Waves.phase() ~= "Wave" then break end
	end
	eq(Waves.phase(), "Break", "terminó la oleada")
	Waves.reset()
end)

print(passed .. " pruebas, 0 fallas")
