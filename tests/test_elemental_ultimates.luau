local M = require("./mocks")
require("./GameServer")
local Run = require("./Run")
local PlayerData = require("./PlayerData")
local Ultimate = require("./UltimateService")
local Weapons = require("./Weapons")
local player = M.addPlayer("Elemental")
Run.start(1, { player })
Run.step(0.01)
local root = player.Character.HumanoidRootPart
local target = root.Position + M.Vector3.new(35, -3, 0)
M.workspace.Raycast = function(_, from)
	return { Position = M.Vector3.new(from.X, target.Y, from.Z) }
end
local requests = M.Instance.new("RemoteEvent")
local enemies = { list = {} }
function enemies.damage(e, amount) e.received = (e.received or 0) + amount end
function enemies.applyBurn(e, dps, duration) e.burnDps, e.burnDuration = dps, duration end
Ultimate.init({ UltimateRequest = requests, UltimateFx = M.Instance.new("RemoteEvent") }, enemies)
for _, id in { "FrostKatana", "VolcanicGauntlets" } do
	local u = Weapons.ById[id].Ultimate
	player:SetAttribute("Weapon", id)
	player:SetAttribute("UltCharge", 1)
	local inside = { alive = true, part = { Position = target }, radius = 1 }
	local outside = { alive = true, part = { Position = target + M.Vector3.new(0, 0, 40) }, radius = 1 }
	local boss = { alive = true, part = { Position = target }, isBoss = true, radius = 1 }
	enemies.list = { inside, outside, boss }
	requests.OnServerEvent:Fire(player, root.Position + M.Vector3.new(1000, 0, 0))
	assert(player:GetAttribute("UltCharge") == 1 and not inside.received, "rechaza blancos fuera de alcance sin gastar carga")
	requests.OnServerEvent:Fire(player, target)
	assert(player:GetAttribute("UltCharge") == 0, "consume la definitiva al confirmar")
	assert(inside.received and not outside.received, "daño solo en el área seleccionada")
	assert(boss.received == inside.received * u.BossMult, "respeta la reducción del jefe")
	assert(PlayerData.isPaused(), "combate detenido durante el ataque")
	if u.Slow then
		assert(inside.slowAmount == u.Slow and inside.slowUntil > M.now, "Escarcha ralentiza a los supervivientes")
		assert(not inside.burnDps, "el hielo no quema")
	else
		assert(inside.burnDps == inside.received * u.Burn and inside.burnDuration == 3, "el magma deja quemadura")
		assert(not inside.slowUntil, "el magma no aplica hielo")
	end
	M.advance(0.5)
	PlayerData.setPaused(false)
end
Run.cleanup()
print("Escarcha y Volcánicos: selección, alcance, daño, jefes, estados y pausa OK")
