-- Disparo automático según el modo de cámara.
-- Primera persona: solo apunta a enemigos dentro del cono delante del jugador.
-- Apuntado manual: tira hacia donde mira el jugador.
local M = require("./mocks")
local Config = require("./Config")
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Combat = require("./Combat")
local Hazards = require("./Hazards")

local V = M.Vector3
local passed, failed = 0, 0
local function test(name, f)
	local ok, err = pcall(f)
	if ok then passed += 1; print("  ok   " .. name)
	else failed += 1; print("  FALLÓ " .. name .. "\n         " .. tostring(err)) end
end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

-- Capturamos la dirección de cada flecha disparada
local shots = {}
Remotes.ProjectileFired.FireAllClients = function(_, _id, _origin, dir, _speed, _life, owner)
	if owner ~= 0 then table.insert(shots, dir) end
end

local half = V.new(60, 0.5, 60)
Hazards.init()
Combat.init(Remotes, half)
Enemies.init(half, Combat, Hazards)

-- Un jugador quieto en el origen, mirando hacia +Z
local state = { stats = PlayerData.newStats(), lastShot = -100, currentOffer = nil, life = "ALIVE", inMatch = true }
local root = M.Instance.new("Part")
root.Position = V.new(0, 3, 0)
root.AssemblyLinearVelocity = V.zero
root.CFrame = M.CFrame.lookAt(V.new(0, 3, 0), V.new(0, 3, 10))
local target = { player = { UserId = 1 }, root = root, humanoid = {}, state = state }

local function fireOnce()
	table.clear(shots)
	state.lastShot = -100
	M.advance(1)
	Combat.update(1 / 30, { target }, M.now, false)
	return shots[1]
end

print("Puntería según la cámara")

-- Enemigo atrás (más cerca) y enemigo adelante (más lejos)
local behind = Enemies.spawn("WhiteSkull", V.new(0, 0, -10))
local ahead = Enemies.spawn("WhiteSkull", V.new(3, 0, 25))

test("primera persona: ignora al de atrás aunque esté más cerca", function()
	Config.Camera.Mode = "FirstPerson"
	local dir = fireOnce()
	assert(dir, "debería disparar")
	assert(dir.Z > 0.9, "debería apuntar hacia adelante, apuntó a Z=" .. dir.Z)
end)

test("primera persona: sin nadie delante, no dispara", function()
	ahead.alive = false
	local dir = fireOnce()
	eq(dir, nil, "disparo")
	ahead.alive = true
end)

test("primera persona: el cono es configurable", function()
	local old = Config.Player.AimConeFirstPerson
	Config.Player.AimConeFirstPerson = 360
	local dir = fireOnce()
	assert(dir and dir.Z < -0.9, "con 360° apunta al más cercano (atrás)")
	Config.Player.AimConeFirstPerson = old
end)

test("cenital (TopDown): apunta al más cercano en cualquier dirección", function()
	Config.Camera.Mode = "TopDown"
	local dir = fireOnce()
	assert(dir and dir.Z < -0.9, "debería apuntar al de atrás")
	Config.Camera.Mode = "FirstPerson"
end)

test("dispara caminando", function()
	root.AssemblyLinearVelocity = V.new(10, 0, 0)
	assert(fireOnce(), "debería disparar aunque se mueva")
	root.AssemblyLinearVelocity = V.zero
end)

print("Mejora Tormenta (rayos)")

test("cada copia suma un rayo, cada uno a un enemigo distinto, cada Interval segundos", function()
	local bolts = 0
	Remotes.ItemEffect.FireAllClients = function(_, kind, _origin, _radius, destination)
		if kind == "bolt" and destination == nil then bolts += 1 end -- un destello por rayo
	end
	local skills = require("./Skills")
	local stats = PlayerData.newStats()
	stats.attackInterval = 1e9 -- sin flechas: solo rayos
	skills.ById.Thunder.Apply(stats)
	skills.ById.Thunder.Apply(stats)
	eq(stats.lightningBolts, 2, "dos copias = dos rayos")
	local lstate = { stats = stats, lastShot = M.now, currentOffer = nil, life = "ALIVE", inMatch = true, nextLightning = 0 }
	local lt = { player = { UserId = 2 }, root = root, humanoid = {}, state = lstate }
	local a = Enemies.spawn("WhiteSkull", V.new(5, 0, 0))
	local b = Enemies.spawn("WhiteSkull", V.new(-6, 0, 0))
	local far = Enemies.spawn("WhiteSkull", V.new(0, 0, Config.Lightning.Range + 20))
	local ha, hb, hf = a.health, b.health, far.health
	local nearBefore, aheadBefore = behind.health, ahead.health
	behind.alive, ahead.alive = false, false -- que solo estén a, b y el lejano
	Combat.update(1 / 30, { lt }, M.now, false)
	eq(bolts, 2, "dos rayos")
	assert(a.health < ha and b.health < hb, "cada rayo a un enemigo distinto")
	eq(far.health, hf, "fuera de alcance no le cae")
	eq(ha - a.health, stats.damage * Config.Lightning.DamageMult, "daño del rayo")
	-- Antes del intervalo no cae otro; después sí
	bolts = 0
	Combat.update(1 / 30, { lt }, M.now + Config.Lightning.Interval - 0.1, false)
	eq(bolts, 0, "todavía no")
	Combat.update(1 / 30, { lt }, M.now + Config.Lightning.Interval + 0.01, false)
	assert(bolts > 0, "pasado el intervalo, cae otra tanda")
	-- En pausa (eligiendo mejora) no caen rayos
	bolts = 0
	Combat.update(1 / 30, { lt }, M.now + 100, true)
	eq(bolts, 0, "pausado")
	behind.alive, ahead.alive = true, true
	behind.health, ahead.health = nearBefore, aheadBefore
	a.alive, b.alive, far.alive = false, false, false
end)

print("Mejora Meteorito (área)")

local function meteorSetup()
	local warned = {}
	Remotes.ItemEffect.FireAllClients = function(_, kind, origin, radius)
		if kind == "meteor" then table.insert(warned, { pos = origin, radius = radius }) end
	end
	local stats = PlayerData.newStats()
	stats.attackInterval = 1e9 -- sin flechas
	local mstate = { stats = stats, lastShot = M.now, currentOffer = nil, life = "ALIVE", inMatch = true, nextMeteor = 0 }
	return warned, stats, { player = { UserId = 3 }, root = root, humanoid = {}, state = mstate }
end

test("caen Count meteoritos por tanda (no más con cada copia), el primero al grupo más denso", function()
	local warned, stats, mt = meteorSetup()
	local skills = require("./Skills")
	skills.ById.Meteor.Apply(stats)
	behind.alive, ahead.alive = false, false
	local alone = Enemies.spawn("WhiteSkull", V.new(6, 0, 0))
	local group = {
		Enemies.spawn("WhiteSkull", V.new(-20, 0, 0)),
		Enemies.spawn("WhiteSkull", V.new(-22, 0, 2)),
		Enemies.spawn("WhiteSkull", V.new(-21, 0, -2)),
	}
	local other = Enemies.spawn("WhiteSkull", V.new(20, 0, 25))
	local extra = Enemies.spawn("WhiteSkull", V.new(-5, 0, 30))
	local hp = group[1].health
	Combat.update(1 / 30, { mt }, M.now, false)
	eq(#warned, Config.Meteor.Count, "Count meteoritos")
	assert(warned[1].pos.X < -15, "el primero va al grupo")
	for i = 1, #warned do
		for j = i + 1, #warned do
			assert((warned[i].pos - warned[j].pos).Magnitude >= Config.Meteor.Radius, "zonas distintas")
		end
	end
	eq(group[1].health, hp, "todavía no pegó (está cayendo)")
	Combat.update(Config.Meteor.FallTime + 1, { mt }, M.now, true)
	eq(group[1].health, hp, "en pausa no pega")
	Combat.update(Config.Meteor.FallTime + 0.01, { mt }, M.now + 0.1, false)
	for _, e in group do
		eq(hp - e.health, stats.damage * Config.Meteor.DamageMult, "daño en área")
	end
	Combat.clear()
	for _, e in { alone, other, extra, table.unpack(group) } do e.alive = false end
	behind.alive, ahead.alive = true, true
end)

test("cada copia agranda el área de impacto", function()
	eq(Combat.meteorRadius(1), Config.Meteor.Radius, "1 copia")
	eq(Combat.meteorRadius(3), Config.Meteor.Radius + 2 * Config.Meteor.RadiusPerCopy, "3 copias")
	local oldCount = Config.Meteor.Count
	Config.Meteor.Count = 1 -- un solo meteorito para ver hasta dónde llega
	local warned, stats, mt = meteorSetup()
	behind.alive, ahead.alive = false, false
	-- Dos enemigos separados por más que el radio base pero menos que con 2 copias
	local gap = Config.Meteor.Radius + Config.Meteor.RadiusPerCopy * 0.5
	local a = Enemies.spawn("WhiteSkull", V.new(30, 0, 0))
	local b = Enemies.spawn("WhiteSkull", V.new(30 + gap, 0, 0))
	a.radius, b.radius = 0.5, 0.5
	a.health, b.health = 10000, 10000 -- que no mueran con el primero
	local hpA, hpB = a.health, b.health
	stats.meteors = 1
	Combat.update(1 / 30, { mt }, M.now, false)
	Combat.update(Config.Meteor.FallTime + 0.01, { mt }, M.now + 0.1, false)
	eq(warned[1].radius, Config.Meteor.Radius, "radio base")
	assert((a.health < hpA) ~= (b.health < hpB), "con 1 copia solo alcanza a uno")
	a.health, b.health = hpA, hpB
	table.clear(warned)
	stats.meteors = 2
	Combat.update(1 / 30, { mt }, M.now + Config.Meteor.Interval + 1, false)
	Combat.update(Config.Meteor.FallTime + 0.01, { mt }, M.now + Config.Meteor.Interval + 1.1, false)
	eq(warned[1].radius, Combat.meteorRadius(2), "radio más grande")
	assert(a.health < hpA and b.health < hpB, "con 2 copias alcanza a los dos")
	Config.Meteor.Count = oldCount
	Combat.clear()
	a.alive, b.alive = false, false
	-- Con más copias no caen más meteoritos: siguen siendo Count (enemigos bien separados)
	table.clear(warned)
	local spread = {}
	-- (más lejos entre sí que el radio con 5 copias, y dentro del alcance)
	for _, pos in { V.new(38, 0, 0), V.new(-38, 0, 0), V.new(0, 0, 38), V.new(0, 0, -38), V.new(27, 0, 27) } do
		table.insert(spread, Enemies.spawn("WhiteSkull", pos))
	end
	stats.meteors = 5
	Combat.update(1 / 30, { mt }, M.now + Config.Meteor.Interval * 3, false)
	eq(#warned, Config.Meteor.Count, "5 copias: siguen cayendo Count")
	Combat.clear()
	for _, e in spread do e.alive = false end
	behind.alive, ahead.alive = true, true
end)

print("Mejora Veneno")

test("cada copia suma 5% de la vida máxima por segundo, con tope de 30%", function()
	local skills = require("./Skills")
	local stats = PlayerData.newStats()
	local def = skills.ById.Poison
	eq(def.Max, 6, "6 copias")
	for n = 1, 8 do
		def.Apply(stats)
		local expected = math.min(n, 6) * Config.Poison.PercentPerCopy
		assert(math.abs(stats.poison - expected) < 1e-9, "copia " .. n .. ": " .. stats.poison)
	end
end)

test("la flecha envenena; quita % de la vida máxima por segundo y se termina a los Duration s", function()
	Remotes.ItemEffect.FireAllClients = function() end
	behind.alive, ahead.alive = false, false
	local e = Enemies.spawn("WhiteSkull", V.new(0, 0, 8))
	e.maxHealth, e.health = 1000, 1000
	state.stats.poison = 0.1
	fireOnce()
	-- La flecha vuela: avanzamos hasta que pegue
	for _ = 1, 30 do
		Combat.update(1 / 30, { target }, M.now, false)
		if e.poisonFraction > 0 then break end
	end
	eq(e.poisonFraction, 0.1, "envenenado al 10%")
	local hp = e.health
	Enemies.update(1, {}, M.now, false)
	assert(math.abs((hp - e.health) - 100) < 1e-6, "10% de 1000 en 1 s, quitó " .. (hp - e.health))
	-- En pausa no hace daño
	hp = e.health
	Enemies.update(1, {}, M.now, true)
	eq(e.health, hp, "pausado")
	-- Se termina solo
	Enemies.update(0.1, {}, M.now + Config.Poison.Duration + 1, false)
	eq(e.poisonFraction, 0, "se terminó")
	hp = e.health
	Enemies.update(1, {}, M.now, false)
	eq(e.health, hp, "sin veneno no baja")
	state.stats.poison = 0
	e.alive = false
	behind.alive, ahead.alive = true, true
end)

test("a los jefes les hace BossMult; dos venenos: queda el más fuerte", function()
	local boss = Enemies.spawn("WhiteSkull", V.new(30, 0, 30))
	boss.isBoss = true
	boss.maxHealth, boss.health = 1000, 1000
	Enemies.applyPoison(boss, 0.3, 5, nil)
	Enemies.applyPoison(boss, 0.05, 5, nil)
	eq(boss.poisonFraction, 0.3, "se queda con el más fuerte")
	local hp = boss.health
	Enemies.update(1, {}, M.now, false)
	assert(math.abs((hp - boss.health) - 1000 * 0.3 * Config.Poison.BossMult) < 1e-6, "jefe reducido")
	boss.alive = false
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then error("hay pruebas que fallaron") end
