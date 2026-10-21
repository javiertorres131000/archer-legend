-- Habilidades por arma: mazos, efectos de arco, espada y puños, y legendarias.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
Config.Player.FireMode = "Auto" -- estas pruebas son del ataque automático
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Combat = require("./Combat")
local Weapons = require("./Weapons")
local Skills = require("./Skills")
local Progression = require("./Progression")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new

print("Habilidades por arma")
local p = M.addPlayer("Probador")
local state = PlayerData.get(p)
state.inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = V(0, 3, 0)
Config.Camera.Mode = "TopDown"

local function fresh(weapon)
	Enemies.clear()
	Combat.clear() -- sin flechas de pruebas anteriores
	state.stats = PlayerData.newStats()
	state.stats.weapon = weapon
	state.stats.critChance = 0
	state.lastShot = -math.huge
	state.currentOffer = nil
	state.attacks, state.combo, state.lastHitAt, state.nextPower, state.burstUntil = 0, 0, 0, 0, 0
end

local function capture(remote)
	local calls = {}
	local old = remote.FireAllClients
	remote.FireAllClients = function(_, ...) table.insert(calls, { ... }) end
	return calls, function() remote.FireAllClients = old end
end

test("catálogo: cada habilidad de arma apunta a un arma que existe; legendarias piden mazo", function()
	for _, def in Skills.List do
		if def.Weapon then assert(Weapons.ById[def.Weapon], def.Id) end
		if def.Rarity == "Legendary" then assert(def.Weapon and def.Requires and def.Requires > 0, def.Id) end
		assert(Config.Progression.RarityWeights[def.Rarity], "sin peso: " .. def.Rarity)
	end
end)

test("mazos: con cada arma solo salen comunes y las de esa arma", function()
	for _, weapon in { "Bow", "Sword", "Fists" } do
		fresh(weapon)
		for _ = 1, 300 do
			for _, id in Progression.rollChoices(state.stats) do
				local def = Skills.ById[id]
				assert(def.Weapon == nil or def.Weapon == weapon, weapon .. " sacó " .. id)
			end
		end
	end
end)

test("legendarias: solo con 2 habilidades del mazo del arma", function()
	fresh("Sword")
	local function seen(id)
		for _ = 1, 400 do
			for _, c in Progression.rollChoices(state.stats) do if c == id then return true end end
		end
		return false
	end
	assert(not seen("Judgment"))
	state.stats.stacks = { WideBlade = 1, Execute = 1 }
	assert(seen("Judgment"))
end)

test("arco: flecha trasera y tiro cargado cada 4 disparos", function()
	fresh("Bow")
	local fired, restore = capture(Remotes.ProjectileFired)
	Enemies.spawn("HeavyKnight", V(0, 0, 20))
	state.stats.backArrows = 1
	state.stats.chargedEvery = 4
	local giants = 0
	for i = 1, 4 do
		Combat.update(0.001, { target }, 100 + i, false)
	end
	for _, c in fired do
		if c[7] and c[7].size then giants += 1 end
	end
	assert(#fired == 4 * 2 + 1, "flechas: " .. #fired) -- 4 ráfagas de 2 (frente + atrás) + 1 gigante
	assert(giants == 1)
	restore()
end)

test("arco: ojo del cazador pega más a los lejanos", function()
	fresh("Bow")
	local _, restore = capture(Remotes.ProjectileFired)
	local _, restore2 = capture(Remotes.ProjectileEnded)
	state.stats.farDamage = 0.25
	local e = Enemies.spawn("HeavyKnight", V(0, 0, 40))
	local before = e.health
	Combat.update(0.001, { target }, 100, false)
	state.currentOffer = { "Damage" } -- eligiendo habilidad: no dispara más, las flechas siguen
	local t = 0
	while e.health == before and t < 3 do
		Combat.update(0.05, { target }, 200 + t, false)
		t += 0.05
	end
	state.currentOffer = nil
	assert(math.abs(before - e.health - state.stats.damage * 1.25) < 0.01, "daño: " .. (before - e.health))
	restore(); restore2()
end)

test("espada: hoja larga, ejecución y sed de sangre", function()
	fresh("Sword")
	local sword = Weapons.ById.Sword
	local far = Enemies.spawn("HeavyKnight", V(0, 0, sword.Range + 3))
	local hp = far.health
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 1 })
	assert(far.health == hp) -- fuera de alcance
	state.stats.meleeRange = 4
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 2 })
	assert(far.health < hp)
	-- Ejecución
	Enemies.clear()
	state.stats.executeBonus = 0.6
	local weak = Enemies.spawn("HeavyKnight", V(0, 0, 5))
	weak.health = weak.maxHealth * 0.2
	local before = weak.health
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 3 })
	assert(math.abs(before - weak.health - state.stats.damage * sword.DamageMult * 1.6) < 0.01)
	-- Sed de sangre
	state.stats.healOnKill = 4
	target.humanoid.Health = 50
	local victim = Enemies.spawn("HordeSkeleton", V(0, 0, 4))
	victim.health = 1
	Combat.meleeSwing(target, V(0, 0, 1), sword, { now = 4 })
	assert(not victim.alive and target.humanoid.Health == 54)
	target.humanoid.Health = target.humanoid.MaxHealth
end)

test("espada: cada 5º golpe es torbellino (pega atrás)", function()
	fresh("Sword")
	state.stats.whirlEvery = 5
	local behind = Enemies.spawn("HeavyKnight", V(0, 0, -9)) -- en alcance, pero atrás y más lejos
	local front = Enemies.spawn("HeavyKnight", V(0, 0, 5)) -- el que recibe los golpes normales
	local hp = behind.health
	local swings, restore = capture(Remotes.MeleeSwing)
	local function swing(now)
		front.part.Position = V(0, front.part.Position.Y, 5)
		behind.part.Position = V(0, behind.part.Position.Y, -9)
		Combat.update(0.001, { target }, now, false)
	end
	for i = 1, 4 do
		swing(100 + i * 5)
	end
	assert(behind.health == hp and #swings == 4, "golpes: " .. #swings)
	swing(200)
	assert(behind.health < hp and swings[5][5] == 360)
	restore()
end)

test("puños: el combo sube el daño y se corta; uppercut aturde", function()
	fresh("Fists")
	local fists = Weapons.ById.Fists
	state.stats.comboStep = 0.05
	local e = Enemies.spawn("HeavyKnight", V(0, 0, 4))
	local function hit(now)
		local h = e.health
		Combat.meleeSwing(target, V(0, 0, 1), fists, { now = now })
		e.part.Position = V(0, e.part.Position.Y, 4) -- vuelve al alcance tras el empujón
		return h - e.health
	end
	local base = hit(10)
	local second = hit(10.5)
	local third = hit(11)
	assert(second > base and third > second, "el combo no sube")
	local reset = hit(20) -- pasó más de 1,5 s
	assert(math.abs(reset - base) < 0.01)
	-- Uppercut
	Combat.meleeSwing(target, V(0, 0, 1), fists, { now = 30, uppercut = true })
	assert(e.stunUntil and e.stunUntil > 30)
	local pos = e.part.Position
	Enemies.update(0.2, { target }, 30.1, false)
	assert((e.part.Position - pos).Magnitude < 0.01, "aturdido se movió")
end)

test("legendarias: lluvia de flechas, juicio y ráfaga de mil puños", function()
	-- Lluvia
	fresh("Bow")
	state.stats.arrowRain = true
	local swings, restore = capture(Remotes.MeleeSwing)
	local _, r2 = capture(Remotes.ProjectileFired)
	local e = Enemies.spawn("HeavyKnight", V(0, 0, 30))
	Combat.update(0.001, { target }, 100, true) -- arma el reloj
	state.currentOffer = nil
	Combat.update(0.001, { target }, 100, false)
	local hp = e.health
	Combat.update(0.001, { target }, 107, false)
	assert(e.health < hp)
	local rain = 0
	for _, c in swings do if c[6] == "Rain" then rain += 1 end end
	assert(rain == 1)
	-- Juicio
	fresh("Sword")
	state.stats.judgment = true
	local a = Enemies.spawn("HeavyKnight", V(0, 0, 20))
	local b = Enemies.spawn("HeavyKnight", V(4, 0, 22))
	Combat.update(0.001, { target }, 300, false)
	local ha, hb = a.health, b.health
	Combat.update(0.001, { target }, 309, false)
	assert(a.health < ha and b.health < hb)
	-- Ráfaga
	fresh("Fists")
	state.stats.thousandFists = true
	Combat.update(0.001, { target }, 500, false)
	Combat.update(0.001, { target }, 511, false)
	assert(state.burstUntil > 511)
	restore(); r2()
	Enemies.clear()
end)

print(passed .. " pruebas, 0 fallas")
