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
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

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

test("arma especial: solo con su premio; juega como su base con sus números", function()
	M.advance(1)
	data.Crates.Owned.FrostKatana = nil
	local ok, msg = WeaponService.select(p, "FrostKatana")
	assert(not ok and string.find(msg, "Caja"), "dejó elegir sin tenerla")
	data.Crates.Owned.FrostKatana = 1
	M.advance(1)
	assert(WeaponService.select(p, "FrostKatana"))
	assert(data.Weapon == "FrostKatana" and p:GetAttribute("Weapon") == "FrostKatana")
	local stats = PlayerData.newStats(); WeaponService.apply(p, stats)
	assert(stats.weapon == "Sword" and stats.weaponId == "FrostKatana", "stats: " .. tostring(stats.weapon) .. "/" .. tostring(stats.weaponId))
	-- Si pierde el premio, usa la base (no queda trabado en un arma que no tiene)
	data.Crates.Owned.FrostKatana = nil
	stats = PlayerData.newStats(); WeaponService.apply(p, stats)
	assert(stats.weapon == "Sword" and stats.weaponId == "Sword")
	WeaponService.publish(p)
	assert(data.Weapon == "Sword" and p:GetAttribute("Weapon") == "Sword")
	-- Las comunes no tienen Prize ni Base
	for _, id in { "Bow", "Sword", "Fists" } do
		assert(not Weapons.isSpecial(id) and Weapons.baseOf(id) == id)
	end
	assert(Weapons.isSpecial("FrostKatana"))
end)

test("Espada Celestial: viene con el skin Seraphiel (no con la caja de armas)", function()
	local CrateItems = require("./CrateItems")
	local def = Weapons.ById.CelestialSword
	assert(def and def.Base == "Sword" and def.Prize == "Seraphiel" and def.Fx == "Celestial", "datos del arma")
	eq(CrateItems.ById.Seraphiel.Kind, "Character", "Seraphiel es un skin")
	assert(Weapons.unlockedBy("Seraphiel") and Weapons.unlockedBy("FrostKatana") and not Weapons.unlockedBy("Knight"))
	M.advance(1)
	data.Crates.Owned.Seraphiel = nil
	local ok, msg = WeaponService.select(p, "CelestialSword")
	assert(not ok and string.find(msg, "Seraphiel"), "sin el skin no se puede: " .. tostring(msg))
	data.Crates.Owned.Seraphiel = 1
	WeaponService.publish(p)
	assert(string.find(p:GetAttribute("OwnedWeapons"), "CelestialSword"), "aparece en el menú Arma")
	M.advance(1)
	assert(WeaponService.select(p, "CelestialSword"))
	local stats = PlayerData.newStats(); WeaponService.apply(p, stats)
	assert(stats.weapon == "Sword" and stats.weaponId == "CelestialSword", "juega como espada con sus números")
	data.Crates.Owned.Seraphiel = nil
	WeaponService.publish(p)
	eq(data.Weapon, "Sword", "sin el skin vuelve a la espada común")
end)

test("Arco Celestial: premio del cofre independiente de Seraphiel", function()
	local def = Weapons.ById.CelestialBow
	assert(def and def.Kind == "Ranged" and def.Base == "Bow" and def.Fx == "Celestial")
	M.advance(1)
	data.Crates.Owned.CelestialBow = nil
	data.Crates.Owned.Seraphiel = 1
	local ok, msg = WeaponService.select(p, def.Id)
	assert(not ok and string.find(msg, "Caja"))
	data.Crates.Owned.CelestialBow = 1
	data.Crates.Owned.Seraphiel = nil
	WeaponService.publish(p)
	local owned = p:GetAttribute("OwnedWeapons")
	assert(string.find(owned, "CelestialBow") and not string.find(owned, "CelestialSword"))
	M.advance(1)
	assert(WeaponService.select(p, def.Id))
	local stats = PlayerData.newStats(); WeaponService.apply(p, stats)
	assert(stats.weapon == "Bow" and stats.weaponId == def.Id)
	assert(Profiles.reconcile({ Weapon = def.Id }).Weapon == def.Id)
	data.Crates.Owned.CelestialBow = nil
	WeaponService.publish(p)
	eq(data.Weapon, "Bow", "sin el premio vuelve al arco base")
end)

test("Arco del Vacío: requiere su premio, no se desbloquea con Seraphiel", function()
	local def = Weapons.ById.VoidBow
	assert(def.Prize == "VoidBow" and def.Base == "Bow" and def.PiercingEvery == 4)
	data.Crates.Owned.Seraphiel = 1
	data.Crates.Owned.VoidBow = nil
	M.advance(1)
	assert(not WeaponService.select(p, def.Id))
	data.Crates.Owned.VoidBow = 1
	data.Crates.Owned.Seraphiel = nil
	M.advance(1)
	assert(WeaponService.select(p, def.Id))
	local stats = PlayerData.newStats(); WeaponService.apply(p, stats)
	assert(stats.weapon == "Bow" and stats.weaponId == def.Id)
	data.Crates.Owned.VoidBow = nil
	WeaponService.publish(p)
	eq(data.Weapon, "Bow")
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
	-- Cadencia: la de la espada (IntervalMult)
	Combat.update(0.01, { target }, 101 + state.stats.attackInterval * Weapons.ById.Sword.IntervalMult - 0.02, false)
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

test("Arco Celestial: daño propio y estilo en multiflechas, diagonales y tiro cargado", function()
	fresh()
	Combat.clear()
	state.stats.weapon = "Bow"
	state.stats.weaponId = "CelestialBow"
	state.stats.frontArrows = 1
	state.stats.diagonalPairs = 1
	state.stats.chargedEvery = 1
	state.attacks = 0
	local mode = Config.Camera.Mode
	Config.Camera.Mode = "TopDown"
	local events = {}
	local oldFire = Remotes.ProjectileFired.FireAllClients
	Remotes.ProjectileFired.FireAllClients = function(_, _id, _origin, _dir, _speed, _life, _owner, style)
		table.insert(events, style)
	end
	Enemies.spawn("HeavyKnight", V(0, 0, 20))
	Combat.update(0.001, { target }, 300, false)
	eq(#events, 5, "dos frontales, dos diagonales y una cargada")
	for _, style in events do eq(style.weaponId, "CelestialBow") end
	eq(events[5].size, 3, "mantiene la flecha gigante")
	Combat.clear()
	Enemies.clear()
	state.stats.frontArrows = 0
	state.stats.diagonalPairs = 0
	state.stats.chargedEvery = 0
	state.lastShot = -math.huge
	local enemy = Enemies.spawn("HeavyKnight", V(0, 0, 8))
	local before = enemy.health
	for i = 1, 20 do Combat.update(0.01, { target }, 400 + i * 0.01, false) end
	local expected = state.stats.damage * Weapons.ById.CelestialBow.DamageMult
	assert(math.abs(before - enemy.health - expected) < 0.01, "aplica el multiplicador del arco una sola vez")
	Config.Camera.Mode = mode
	Remotes.ProjectileFired.FireAllClients = oldFire
	Combat.clear()
	Enemies.clear()
end)

test("Arco del Vacío: cada cuatro disparos agrega una flecha que atraviesa enemigos", function()
	fresh()
	Combat.clear()
	state.stats.weapon = "Bow"
	state.stats.weaponId = "VoidBow"
	state.stats.ricochet = 0
	state.stats.pierce = 0
	state.attacks = 0
	local mode = Config.Camera.Mode
	Config.Camera.Mode = "TopDown"
	local front = Enemies.spawn("HeavyKnight", V(0, 0, 15))
	local back = Enemies.spawn("HeavyKnight", V(0, 0, 25))
	front.health, back.health = 10000, 10000
	local events = {}
	local oldFire = Remotes.ProjectileFired.FireAllClients
	Remotes.ProjectileFired.FireAllClients = function(_, _id, _origin, _dir, _speed, _life, _owner, style)
		table.insert(events, style)
	end
	for i = 1, 4 do
		Combat.update(0.001, { target }, 500 + i * 2, false)
		if i < 4 then eq(#events, i, "sin perforante antes del cuarto disparo") end
	end
	eq(#events, 5)
	eq(events[5].size, 1.5)
	for _, style in events do eq(style.weaponId, "VoidBow") end
	for _ = 1, 100 do Combat.update(0.01, {}, 510, false) end
	local damage = state.stats.damage * Weapons.ById.VoidBow.DamageMult
	assert(math.abs(10000 - back.health - damage) < 0.01, "la perforante alcanza al enemigo de atrás una vez")
	assert(math.abs(10000 - front.health - damage * 5) < 0.01, "las cuatro normales y la perforante alcanzan al primero")
	Remotes.ProjectileFired.FireAllClients = oldFire
	Config.Camera.Mode = mode
	Combat.clear()
	Enemies.clear()
end)

test("el tocón verde y el cactus vuelan", function()
	for _, id in { "GreenStump", "Cactus" } do
		local def = EnemyTypes[id]
		assert(def.Float and def.Float > 0 and def.Move.Type ~= "Still", id)
	end
end)

print(passed .. " pruebas, 0 fallas")
