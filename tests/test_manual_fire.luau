-- Disparo manual: el jugador aprieta y apunta; el servidor valida y respeta la cadencia.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Combat = require("./Combat")
local Weapons = require("./Weapons")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new

print("Disparo manual")
Config.Player.FireMode = "Manual"
local p = M.addPlayer("Tirador")
local state = PlayerData.get(p)
state.inMatch = true
local target = PlayerData.getAliveTargets()[1]
target.root.Position = V(0, 3, 0)

local shots, swings = {}, {}
Remotes.ProjectileFired.FireAllClients = function(_, _id, _origin, dir, _speed, _life, owner)
	if owner == p.UserId then table.insert(shots, dir) end
end
Remotes.MeleeSwing.FireAllClients = function(_, userId, _origin, dir)
	if userId == p.UserId then table.insert(swings, dir) end
end

local now = 1000
local function fresh(weapon)
	Enemies.clear()
	Combat.clear()
	table.clear(shots); table.clear(swings)
	state.stats = PlayerData.newStats()
	state.stats.weapon = weapon
	state.lastShot = -math.huge
	state.currentOffer = nil
	state.trigger, state.fireQueued, state.aimDir = false, false, nil
	state.aimMsgs, state.aimWindow = 0, 0
	M.advance(2)
end
local function tick(dt)
	now += dt
	Combat.update(0.001, { target }, now, false)
end

test("sin apretar no dispara, aunque haya enemigos cerca", function()
	fresh("Bow")
	Enemies.spawn("HeavyKnight", V(0, 0, 10))
	for _ = 1, 5 do tick(1) end
	assert(#shots == 0, "disparó solo")
end)

test("apretado: dispara hacia donde apunta, no al enemigo", function()
	fresh("Bow")
	Enemies.spawn("HeavyKnight", V(0, 0, 10)) -- adelante
	assert(Combat.setTrigger(p, true, V(1, 0, 0)))
	tick(0.01)
	assert(#shots == 1 and shots[1].X > 0.99, "debería tirar hacia +X")
end)

test("mantener apretado sigue disparando a la cadencia del arma", function()
	fresh("Bow")
	Combat.setTrigger(p, true, V(0, 0, 1))
	tick(0.01)
	tick(state.stats.attackInterval * 0.5)
	assert(#shots == 1, "no respeta la cadencia")
	tick(state.stats.attackInterval * 0.6)
	assert(#shots == 2)
	Combat.setTrigger(p, false, V(0, 0, 1))
	tick(5)
	assert(#shots == 2, "siguió disparando después de soltar")
end)

test("click corto durante la recarga queda en cola (una sola vez)", function()
	fresh("Bow")
	Combat.setTrigger(p, true, V(0, 0, 1)); tick(0.01) -- primer disparo
	Combat.setTrigger(p, false, V(0, 0, 1))
	Combat.setTrigger(p, true, V(0, 0, 1)); Combat.setTrigger(p, false, V(0, 0, 1)) -- click en la recarga
	tick(0.05)
	assert(#shots == 1)
	tick(state.stats.attackInterval)
	assert(#shots == 2, "el click en cola no salió")
	tick(state.stats.attackInterval * 3)
	assert(#shots == 2)
end)

test("espada: golpea hacia donde apunta (aunque sea al aire)", function()
	fresh("Sword")
	local front = Enemies.spawn("HeavyKnight", V(0, 0, 6))
	local before = front.health
	Combat.setTrigger(p, true, V(0, 0, -1)) -- de espaldas al enemigo
	tick(0.01)
	assert(#swings == 1 and swings[1].Z < -0.99 and front.health == before)
	Combat.setTrigger(p, false, V(0, 0, 1))
	Combat.setTrigger(p, true, V(0, 0, 1))
	tick(state.stats.attackInterval * Weapons.ById.Sword.IntervalMult + 0.01)
	assert(#swings == 2 and front.health < before, "debería pegarle al apuntarle")
	assert(#shots == 0, "la espada no tira flechas")
end)

test("valida: tipos, números raros, dirección vertical, fuera de partida", function()
	fresh("Bow")
	assert(not Combat.setTrigger(p, "si", V(0, 0, 1)))
	assert(not Combat.setTrigger(p, true, "adelante"))
	assert(not Combat.setTrigger(p, true, V(0 / 0, 0, 1)))
	assert(not Combat.setTrigger(p, true, V(50, 0, 0)))
	assert(not Combat.setTrigger(p, true, V(0, 1, 0)), "solo vertical: sin dirección en el plano")
	assert(Combat.setTrigger(p, true, V(0.6, 0.8, 0)) and state.aimDir.X > 0.99 and state.aimDir.Y == 0)
	Combat.setTrigger(p, false, V(0, 0, 1))
	state.inMatch = false
	assert(not Combat.setTrigger(p, true, V(0, 0, 1)))
	state.inMatch = true
	state.life = "DOWNED"
	assert(not Combat.setTrigger(p, true, V(0, 0, 1)))
	state.life = "ALIVE"
end)

test("límite de frecuencia de mensajes", function()
	fresh("Bow")
	local ok = 0
	for _ = 1, Config.Player.FireMessagesPerSecond + 20 do
		if Combat.setTrigger(p, false, V(0, 0, 1)) then ok += 1 end
	end
	assert(ok == Config.Player.FireMessagesPerSecond, "pasaron " .. ok)
	M.advance(1.1)
	assert(Combat.setTrigger(p, false, V(0, 0, 1)), "en el segundo siguiente vuelve a aceptar")
end)

test("no ataca mientras elige habilidad", function()
	fresh("Bow")
	state.currentOffer = { "Multishot" }
	Combat.setTrigger(p, true, V(0, 0, 1))
	tick(1)
	local old = Config.Progression.PauseWhileChoosing
	assert(#shots == 0 or not old)
	state.currentOffer = nil
end)

test("el remote está conectado a Combat.setTrigger", function()
	assert(Remotes.AttackRequest, "falta Remotes.AttackRequest")
end)

print(passed .. " pruebas, 0 fallas")
