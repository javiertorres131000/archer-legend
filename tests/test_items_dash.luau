local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
Config.Player.FireMode = "Auto" -- estas pruebas son del ataque automático
local PlayerData = require("./PlayerData")
local PlayerLife = require("./PlayerLife")
local Progression = require("./Progression")
local Combat = require("./Combat")
local Enemies = require("./Enemies")
local ItemService = require("./ItemService")
local Items = require("./RunItems")
local Dash = require("./Dash")
local Profiles = require("./Profiles")
local Remotes = require("./Remotes")
local p = M.addPlayer("Objetos")
local state = PlayerData.get(p)
state.inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = M.Vector3.new(0, 3, 0)
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
test("objetos se acumulan hasta su máximo y modifican stats", function()
	for _ = 1, Items.ById.SwiftBoots.Max do assert(ItemService.grant(p, "SwiftBoots")) end
	assert(not ItemService.grant(p, "SwiftBoots")); assert(state.stats.walkSpeed > Config.Player.WalkSpeed)
	assert(target.humanoid.WalkSpeed == state.stats.walkSpeed)
	assert(not ItemService.grant(p, "inventado"))
end)
test("aura y tormenta dañan sin cliente y el prisma aumenta su poder", function()
	Enemies.clear()
	assert(ItemService.grant(p, "Ember")); assert(ItemService.grant(p, "Storm")); assert(ItemService.grant(p, "Prism"))
	local a = Enemies.spawn("HeavyKnight", M.Vector3.new(3, 0, 0))
	local b = Enemies.spawn("HeavyKnight", M.Vector3.new(12, 0, 0))
	local ah, bh = a.health, b.health
	ItemService.update(0.5, { target }, 100)
	assert(a.health < ah and b.health < bh)
end)
test("bajas explotan sin recursión y fuego produce sinergia", function()
	Enemies.clear(); assert(ItemService.grant(p, "Powder"))
	local a = Enemies.spawn("HordeSkeleton", M.Vector3.new(2, 0, 0))
	local b = Enemies.spawn("HeavyKnight", M.Vector3.new(4, 0, 0))
	local before = b.health
	ItemService.onKill(a, p, "hit"); local withFire = before - b.health
	state.items.Ember = nil
	before = b.health; ItemService.onKill(a, p, "hit"); assert(withFire > before - b.health)
	before = b.health; ItemService.onKill(a, p, "explosion"); assert(b.health == before)
end)
test("modo opcional sin pausa permite disparar", function()
	Config.Progression.PauseWhileChoosing = false
	Config.Progression.ChoosingShield = false
	state.currentOffer = { "Damage" }
	assert(not Progression.allChoosing({ target }))
	PlayerData.setChoosingShield(p, true); assert(not p.Character:FindFirstChild("ChoiceShield"))
	Config.Camera.Mode = "TopDown"
	local fired = 0; local old = Remotes.ProjectileFired.FireAllClients
	Remotes.ProjectileFired.FireAllClients = function() fired += 1 end
	Combat.update(0.01, { target }, 100, false)
	assert(fired > 0); Remotes.ProjectileFired.FireAllClients = old
	state.currentOffer = nil
	Config.Progression.PauseWhileChoosing = true
	Config.Progression.ChoosingShield = true
end)
test("proyectiles en resultados no pueden seguir dando daño", function()
	Enemies.clear(); state.lastShot = 0
	local e = Enemies.spawn("HeavyKnight", M.Vector3.new(5, 0, 0))
	Combat.update(0.001, { target }, 200, false)
	local health = e.health
	Combat.update(0.05, { target }, 201, true)
	assert(e.health == health)
	Combat.clear()
end)
test("dash rechaza spam, NaN, direcciones gigantes, lobby y derribo", function()
	assert(not Dash.request(p, M.Vector3.new(999, 0, 0)))
	assert(not Dash.request(p, M.Vector3.new(0/0, 0, 0)))
	assert(Dash.request(p, M.Vector3.new(1, 0, 0)))
	assert(not Dash.request(p, M.Vector3.new(1, 0, 0)))
	Dash.update({ target }, M.os.clock())
	assert(target.root.AssemblyLinearVelocity.X == Config.Dash.Speed)
	M.advance(1); Dash.update({ target }, M.os.clock()); assert(not state.dashOwned)
	M.advance(10); state.life = "DOWNED"; assert(not Dash.request(p, M.Vector3.new(1, 0, 0)))
	state.life = "ALIVE"; state.inMatch = false; assert(not Dash.request(p, M.Vector3.new(1, 0, 0))); state.inMatch = true
end)
test("invocaciones y divisiones respetan presupuesto", function()
	Enemies.clear(); local cap = Config.Enemy.MaxAlive; Config.Enemy.MaxAlive = 3
	for _ = 1, 20 do Enemies.queueSpawn("HordeSkeleton", M.Vector3.zero) end
	assert(Enemies.aliveCount() == 3)
	Enemies.update(0, {}, 0, false); assert(Enemies.aliveCount() == 3)
	Config.Enemy.MaxAlive = cap
end)
test("objetos temporales desaparecen y no entran al perfil", function()
	local currencies = Profiles.get(p).Currencies.Gold
	PlayerData.resetStats()
	assert(next(state.items) == nil and state.stats.walkSpeed == Config.Player.WalkSpeed)
	assert(state.dashUntil == 0 and state.dashReady == 0 and state.nextStorm == 0)
	assert(Profiles.get(p).items == nil and Profiles.get(p).Currencies.Gold == currencies)
end)
print(passed .. " pruebas, 0 fallas")
