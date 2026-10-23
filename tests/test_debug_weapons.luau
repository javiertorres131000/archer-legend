local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local DebugCommands = require("./DebugCommands")
local p = M.addPlayer("ProbadorArmas")
local data = Profiles.get(p)
local passed = 0
local function test(name, f) f(); passed += 1; print("ok " .. name) end
test("F2: cada arma tiene botón, se desbloquea y equipa también durante la partida", function()
	local Weapons = require("./Weapons")
	local state = PlayerData.get(p)
	local skin = data.Crates.Equipped.Character
	state.inMatch = true
	state.stats.damage = 123
	for _, weapon in Weapons.List do
		local command = "Weapon_" .. weapon.Id
		assert(table.find(DebugCommands.Order, command) and DebugCommands.Actions[command])
		assert(string.find(p:GetAttribute("DebugAllowed"), command, 1, true))
		M.advance(1)
		assert(DebugCommands.run(p, command))
		assert(data.Weapon == weapon.Id and p:GetAttribute("Weapon") == weapon.Id)
		assert(state.stats.weapon == (weapon.Base or weapon.Id) and state.stats.weaponId == weapon.Id)
		assert(state.stats.damage == 123, "conserva las mejoras de la partida")
		assert(data.Crates.Equipped.Character == skin, "no cambia el skin")
		if weapon.Prize then assert(data.Crates.Owned[weapon.Prize] >= 1) end
	end
	state.inMatch = false
	M.isStudio = false
	M.advance(1)
	assert(not DebugCommands.run(p, "Weapon_Bow"), "sigue requiriendo permiso de administrador")
	M.isStudio = true
end)

print(passed .. " pruebas, 0 fallas")
