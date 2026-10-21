-- Armas del jugador (arco, espada, puños) y enemigos voladores.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
Config.Player.FireMode = "Auto" -- estas pruebas son del ataque automático
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Combat = require("./Combat")
local Weapons = require("./Weapons")
local WeaponService = require("./WeaponService")
local EnemyTypes = require("./EnemyTypes")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new

print("Armas")
local p = M.addPlayer("Guerrero")
local data = Profiles.get(p)
local function select(id) M.advance(1); return WeaponService.select(p, id) end

test("catálogo: arco por defecto, cuerpo a cuerpo con alcance y arco", function()
	assert(Weapons.Default == "Bow" and Weapons.ById.Bow.Kind == "Ranged")
	for _, def in Weapons.List do
		assert(def.DamageMult > 0 and def.IntervalMult > 0)
		if def.Kind == "Melee" then assert(def.Range > 0 and def.Arc > 0 and def.Knockback) end
	end
	assert(data.Weapon == "Bow" and p:GetAttribute("Weapon") == "Bow")
end)

test("elegir: valida id, listo, partida y frecuencia; guarda y publica", function()
	assert(not select("Hacha")); assert(not select(nil)); assert(not select({}))
	p:SetAttribute("Ready", true); assert(not select("Sword")); p:SetAttribute("Ready", false)
	PlayerData.get(p).inMatch = true; assert(not select("Sword")); PlayerData.get(p).inMatch = false
	assert(select("Sword")); assert(data.Weapon == "Sword" and p:GetAttribute("Weapon") == "Sword")
	assert(not WeaponService.select(p, "Fists")) -- muy seguido
	local stats = PlayerData.newStats(); WeaponService.apply(p, stats)
	assert(stats.weapon == "Sword")
end)

test("perfil: arma inválida vuelve al arco, válida se conserva", function()
	assert(Profiles.reconcile({ Weapon = "Lanzallamas" }).Weapon == "Bow")
	assert(Profiles.reconcile({ Weapon = 5 }).Weapon == "Bow")
	assert(Profiles.reconcile({ Weapon = "Fists" }).Weapon == "Fists")
	assert(Profiles.reconcile({}).Weapon == "Bow")
end)

local state = PlayerData.get(p)
state.inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = V(0, 3, 0)

local function fresh()
	Enemies.clear()
	state.stats = PlayerData.newStats()
	state.stats.critChance = 0
	state.stats.burn = false
	state.lastShot = -math.huge
	state.currentOffer = nil
end

test("espada: pega a todos los de adelante en alcance, no a los de atrás ni lejos", function()
	fresh()
	local sword = Weapons.ById.Sword
	local front = Enemies.spawn("HeavyKnight", V(0, 0, 7))
	local side = Enemies.spawn("HeavyKnight", V(5, 0, 6))
	local back = Enemies.spawn("HeavyKnight", V(0, 0, -8))
	local far = Enemies.spawn("HeavyKnight", V(0, 0, 30))
	local hp = { front.health, side.health, back.health, far.health }
	local hits = Combat.meleeSwing(target, V(0, 0, 1), sword)
	assert(hits == 2, "golpes: " .. hits)
	local expected = state.stats.damage * sword.DamageMult
	assert(math.abs(hp[1] - front.health - expected) < 0.01)
	assert(side.health < hp[2] and back.health == hp[3] and far.health == hp[4])
end)

test("bonos de habilidades: flecha extra sube el daño, par diagonal abre el arco", function()
	fresh()
	local fists = Weapons.ById.Fists
	local e = Enemies.spawn("HeavyKnight", V(5, 0, 4)) -- ~51° del frente: afuera del arco de 80°
	local before = e.health
	Combat.meleeSwing(target, V(0, 0, 1), fists)
	assert(e.health == before)
	state.stats.diagonalPairs = 2 -- +40° → 120°
	state.stats.frontArrows = 1
	Combat.meleeSwing(target, V(0, 0, 1), fists)
	local expected = state.stats.damage * fists.DamageMult * (1 + Weapons.MeleeBonus.FrontArrow)
	assert(math.abs(before - e.health - expected) < 0.01)
end)

test("en partida: con espada no dispara flechas, golpea al que entra en alcance", function()
	fresh()
	state.stats.weapon = "Sword"
	local fired, swings = 0, 0
	local oldFire, oldSwing = Remotes.ProjectileFired.FireAllClients, Remotes.MeleeSwing.FireAllClients
	Remotes.ProjectileFired.FireAllClients = function() fired += 1 end
	Remotes.MeleeSwing.FireAllClients = function() swings += 1 end
	local mode = Config.Camera.Mode
	Config.Camera.Mode = "TopDown"
	local far = Enemies.spawn("HeavyKnight", V(0, 0, 40))
	Combat.update(0.01, { target }, 100, false)
	assert(swings == 0 and fired == 0) -- nadie en alcance
	far.part.Position = V(0, far.part.Position.Y, 6)
	Combat.update(0.01, { target }, 101, false)
	assert(swings == 1 and fired == 0)
	-- Cadencia: con la espada tarda más que el arco
	Combat.update(0.01, { target }, 101 + state.stats.attackInterval, false)
	assert(swings == 1)
	Combat.update(0.01, { target }, 101 + state.stats.attackInterval * Weapons.ById.Sword.IntervalMult + 0.01, false)
	assert(swings == 2)
	-- Con arco vuelve a disparar flechas
	state.stats.weapon = "Bow"
	Combat.update(0.01, { target }, 200, false)
	assert(fired > 0)
	Config.Camera.Mode = mode
	Remotes.ProjectileFired.FireAllClients, Remotes.MeleeSwing.FireAllClients = oldFire, oldSwing
	Enemies.clear()
end)

test("el tocón verde y el cactus vuelan", function()
	for _, id in { "GreenStump", "Cactus" } do
		local def = EnemyTypes[id]
		assert(def.Float and def.Float > 0 and def.Move.Type ~= "Still", id)
	end
end)

print(passed .. " pruebas, 0 fallas")
