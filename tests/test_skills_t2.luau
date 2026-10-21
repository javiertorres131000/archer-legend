-- Habilidades nuevas: segunda tanda por arma, comunes nuevas, sinergias con bono y efectos
-- de SkillEffects (esquiva, escudo, armadura, explosiones, rayo, vampirismo...).
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
Config.Player.FireMode = "Auto"
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Combat = require("./Combat")
local Weapons = require("./Weapons")
local Skills = require("./Skills")
local Synergies = require("./Synergies")
local Progression = require("./Progression")
local SkillEffects = require("./SkillEffects")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new

print("Habilidades nuevas")
local p = M.addPlayer("Probador2")
local state = PlayerData.get(p)
state.inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = V(0, 3, 0)
Config.Camera.Mode = "TopDown"

local function fresh(weapon)
	Enemies.clear()
	Combat.clear()
	state.stats = PlayerData.newStats()
	state.stats.weapon = weapon
	state.stats.critChance = 0
	state.lastShot = -math.huge
	state.currentOffer = nil
	state.attacks, state.combo, state.lastHitAt, state.nextPower, state.burstUntil = 0, 0, 0, 0, 0
	state.shieldReadyAt, state.riposteReady, state.nextPhantom, state.nextDance, state.nextDragon = nil, nil, nil, nil, nil
	state.lastHurt = -math.huge
	target.humanoid.MaxHealth = 100
	target.humanoid.Health = 100
end

test("catálogo: 6 comunes nuevas y 6 de segunda tanda por arma; todas aplican sin error", function()
	local tier2 = { Bow = 0, Sword = 0, Fists = 0 }
	for _, def in Skills.List do
		if def.Tier == 2 then
			assert(def.Weapon, "la tanda 2 es de un arma: " .. def.Id)
			tier2[def.Weapon] += 1
		end
		local s = PlayerData.newStats()
		for _ = 1, def.Max do def.Apply(s) end -- al máximo
	end
	for w, n in tier2 do
		assert(n == 6, w .. ": " .. n)
	end
	for _, id in { "Vampirism", "Frost", "Thunder", "ManaShield", "Dodge", "Explosive" } do
		assert(Skills.ById[id] and Skills.ById[id].Weapon == nil, id)
	end
end)

test("segunda tanda: no sale antes del nivel SecondTierLevel; después sí", function()
	fresh("Sword")
	local function seen(id)
		for _ = 1, 500 do
			for _, c in Progression.rollChoices(state.stats) do if c == id then return true end end
		end
		return false
	end
	Progression.reset()
	assert(not seen("SlashWave"), "salió antes de tiempo")
	-- Subir de nivel hasta la segunda tanda (sin jugadores en partida que reciban ofertas)
	state.inMatch = false
	while Progression.level() < Config.Progression.SecondTierLevel do
		Progression.addXP(1000)
	end
	state.inMatch = true
	assert(seen("SlashWave"), "no sale en la segunda tanda")
	-- La legendaria nueva pide 4 del mazo
	assert(not seen("BladeDance"))
	state.stats.stacks = { WideBlade = 1, Execute = 1, LongBlade = 1, Riposte = 1 }
	assert(seen("BladeDance"))
	Progression.reset()
end)

test("sinergias: todas con bono y Apply; el bono se aplica una sola vez por partida", function()
	for _, syn in Synergies.List do
		assert(type(syn.Bonus) == "string" and type(syn.Apply) == "function", syn.Name)
		syn.Apply(PlayerData.newStats())
	end
	fresh("Bow")
	state.inMatch = true
	local granted = {}
	local old = Remotes.SkillGranted.FireClient
	Remotes.SkillGranted.FireClient = function(_, _p, id) table.insert(granted, id) end
	-- Perforación + Rebote = Flecha imparable (+1 rebote)
	state.currentOffer = { "Pierce" }
	state.offerId += 1
	Remotes.ChooseSkill.OnServerEvent:Fire(p, state.offerId, 1)
	assert(state.stats.ricochet == 0)
	state.currentOffer = { "Ricochet" }
	state.offerId += 1
	Remotes.ChooseSkill.OnServerEvent:Fire(p, state.offerId, 1)
	assert(state.stats.ricochet == 2, "rebote + bono: " .. state.stats.ricochet)
	assert(state.stats.synergies["Flecha imparable"])
	-- Subir Rebote otra vez no repite el bono
	state.currentOffer = { "Ricochet" }
	state.offerId += 1
	Remotes.ChooseSkill.OnServerEvent:Fire(p, state.offerId, 1)
	assert(state.stats.ricochet == 3, "sin bono repetido: " .. state.stats.ricochet)
	Remotes.SkillGranted.FireClient = old
end)

test("esquiva, escudo de maná y armadura", function()
	fresh("Sword")
	state.stats.dodge = 1 -- siempre esquiva (tope 60%: se prueba varias veces)
	local dodged = 0
	for _ = 1, 200 do
		if SkillEffects.incoming(target, 10) == 0 then dodged += 1 end
	end
	assert(dodged > 80 and dodged < 160, "esquiva con tope: " .. dodged)
	fresh("Sword")
	state.stats.shieldInterval = 12
	assert(SkillEffects.incoming(target, 10) == 0, "el escudo bloquea el primero")
	assert(SkillEffects.incoming(target, 10) == 10, "recargando")
	M.advance(12.1)
	assert(SkillEffects.incoming(target, 10) == 0, "recargado")
	fresh("Sword")
	state.stats.damageTaken = 0.88
	assert(math.abs(SkillEffects.incoming(target, 10) - 8.8) < 1e-6)
end)

test("contraataque: después de recibir un golpe, el próximo tajo pega el doble", function()
	fresh("Sword")
	state.stats.riposte = 1
	local sword = Weapons.get("Sword")
	local e = Enemies.spawn("HeavyKnight", V(0, 0, 5))
	local before = e.health
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 1 })
	local normal = before - e.health
	SkillEffects.incoming(target, 5)
	before = e.health
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 2 })
	assert(math.abs((before - e.health) - normal * 2) < 0.01, "doble: " .. (before - e.health) .. " vs " .. normal)
	before = e.health
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 3 })
	assert(math.abs((before - e.health) - normal) < 0.01, "se consume")
end)

test("toque helado frena; rompeguardias hace recibir más daño", function()
	fresh("Fists")
	state.stats.slowOnHit = 0.3
	state.stats.armorBreak = 0.04
	local fists = Weapons.get("Fists")
	local e = Enemies.spawn("HeavyKnight", V(0, 0, 4))
	Combat.meleeSwing(target, V(0, 0, 1), fists, { now = 1 })
	assert(e.slowAmount == 0.3 and e.slowUntil, "frenado")
	assert(math.abs((e.vuln or 0) - 0.04) < 1e-9, "vuln")
	for i = 2, 10 do Combat.meleeSwing(target, V(0, 0, 1), fists, { now = i }) end
	assert(math.abs(e.vuln - 0.2) < 1e-9, "tope de rompeguardias: " .. e.vuln)
end)

test("cadáver explosivo daña a los de al lado (sin reacción infinita) y vampirismo cura", function()
	fresh("Sword")
	state.stats.explodeOnKill = 0.4
	state.stats.lifeOnKill = 2
	target.humanoid.Health = 50
	local dead = Enemies.spawn("HordeSkeleton", V(0, 0, 30))
	local near = Enemies.spawn("HeavyKnight", V(3, 0, 30))
	local far = Enemies.spawn("HeavyKnight", V(30, 0, 30))
	local nearBefore, farBefore = near.health, far.health
	SkillEffects.onKill(p, dead, "hit", dead.part.Position)
	assert(math.abs(nearBefore - near.health - state.stats.damage * 0.4) < 0.01, "explosión")
	assert(far.health == farBefore, "lejos no")
	assert(target.humanoid.Health == 52, "vampirismo: " .. target.humanoid.Health)
	-- Una muerte por explosión no explota de nuevo
	nearBefore = near.health
	SkillEffects.onKill(p, dead, "blast", dead.part.Position)
	assert(near.health == nearBefore, "sin cadena de explosiones")
end)

test("primera sangre: más daño con la vida llena", function()
	fresh("Bow")
	state.stats.firstStrike = 0.6
	local e = Enemies.spawn("HeavyKnight", V(0, 0, 20))
	assert(SkillEffects.hitMult(state.stats, e, "arrow") == 1.6)
	e.health -= 1
	assert(SkillEffects.hitMult(state.stats, e, "arrow") == 1)
end)

test("anillo de flechas cada 8 disparos y onda cortante cada 4 tajos", function()
	fresh("Bow")
	local fired = {}
	local old = Remotes.ProjectileFired.FireAllClients
	Remotes.ProjectileFired.FireAllClients = function(_, ...) table.insert(fired, { ... }) end
	Enemies.spawn("HeavyKnight", V(0, 0, 20))
	state.stats.ringEvery = 8
	for i = 1, 8 do
		Combat.update(0.001, { target }, 100 + i, false)
	end
	assert(#fired == 8 + 12, "flechas: " .. #fired)
	fresh("Sword")
	table.clear(fired)
	state.stats.slashWaveEvery = 4
	Enemies.spawn("HeavyKnight", V(0, 0, 5))
	for i = 1, 4 do
		Combat.update(0.001, { target }, 200 + i * 2, false)
	end
	local waves = 0
	for _, c in fired do
		if c[7] and c[7].wave then waves += 1 end
	end
	assert(waves == 1, "ondas: " .. waves)
	Remotes.ProjectileFired.FireAllClients = old
end)

test("puño del dragón: cada 12 s, golpe en cono", function()
	fresh("Fists")
	state.stats.dragonFist = true
	local front = Enemies.spawn("HeavyKnight", V(0, 0, 12))
	local back = Enemies.spawn("HeavyKnight", V(0, 0, -12))
	local fb, bb = front.health, back.health
	SkillEffects.update(target, 1) -- arranca el reloj
	SkillEffects.update(target, 5)
	assert(front.health == fb, "antes de tiempo")
	SkillEffects.update(target, 13.1)
	assert(front.health < fb, "no pegó adelante")
	-- El de atrás está a la misma distancia: el cono apunta al más cercano, que puede ser
	-- cualquiera de los dos; el otro no recibe daño
	assert(back.health == bb, "atrás no (está fuera del cono)")
end)

print(passed .. " pruebas, 0 fallas")
