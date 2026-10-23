-- Comprueba continuidad y restauración; la apariencia se valida en Studio.
local M = require("./mocks")
local V, CF = M.Vector3, M.CFrame
CF.identity = CF.new(0, 0, 0)
local mt = getmetatable(CF.identity)
mt.__index = { Lerp = function(a, b, k) return CF.new(a.Position:Lerp(b.Position, k)) end }
local beforeSimulation
M.game:GetService("RunService").PreSimulation = {
	Connect = function(_, callback)
		beforeSimulation = callback
		return { Disconnect = function() beforeSimulation = nil end }
	end,
}
local Motion = require("./UltimateMotion")
local Weapons = require("./Weapons")
local origin = V.new(0, 3, 0)
local target = V.new(40, 0, -20)
local initial = CF.lookAt(origin + V.new(0, 8, 15), origin)
local count = 0
for _, def in Weapons.List do
	local u = def.Ultimate
	if not u then continue end
	local character = M.Instance.new("Model")
	character.Parent = M.workspace
	local root = M.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CF.new(origin)
	root.Parent = character
	local joint = M.Instance.new("Motor6D")
	joint.Name = "RootJoint"
	joint.Transform = CF.identity
	joint.Parent = character
	local ctx = { center = target, path = { V.new(15, 3, 0), V.new(20, 3, -10), V.new(25, 3, -15) } }
	local motion = Motion.new(character, u, origin, V.new(0, 0, -1), ctx, {})
	local function sample(t)
		motion.Update(t)
		beforeSimulation()
		return motion.Camera(t, initial, 70, 16 / 9)
	end
	local previous = initial
	local previousBody = origin
	for i = 0, math.floor((u.Duration + 0.1) * 120) do
		local t = i / 120
		local frame, fov = sample(t)
		assert(frame.Position.X == frame.Position.X and fov == fov, def.Id .. ": encuadre válido")
		assert((frame.Position - previous.Position).Magnitude < 5, def.Id .. ": cámara sin saltos")
		assert((root.Position - previousBody).Magnitude < 8, def.Id .. ": avatar sin teletransportes entre fases")
		previousBody = root.Position
		previous = frame
	end
	if u.Leap then
		sample(1.1)
		assert(root.Position.Y > origin.Y + 10, "la espada celestial tiene un salto real")
	end
	-- No acumular errores ni depender de cuántos cuadros se hayan renderizado.
	local frameA = sample(1.25)
	sample(0.5)
	local frameB = sample(1.25)
	assert((frameA.Position - frameB.Position).Magnitude < 0.0001, def.Id .. ": tiempo absoluto")
	local last = sample(u.Duration + 0.1)
	assert((last.Position - initial.Position).Magnitude < 0.01, "la cámara vuelve a la vista anterior")
	motion.Destroy()
	assert((root.Position - origin).Magnitude < 0.01, "restaura la posición del avatar")
	assert(not character:GetAttribute("UltimatePerforming") and not beforeSimulation, "limpia estado y conexiones")
	count += 1
end
assert(count == 7)
for _, id in { "Bow", "Sword", "Fists" } do
	assert(not Weapons.ById[id].Ultimate, "las armas comunes siguen sin definitiva")
end
assert(Weapons.ById.FrostKatana.Ultimate.Slow == 0.7)
assert(Weapons.ById.VolcanicGauntlets.Ultimate.Burn == 0.2)
print("Definitivas: continuidad de cámara, tiempo absoluto y restauración en las siete armas especiales OK")
