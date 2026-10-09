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

test("sigue la regla de Archero: moviéndose no dispara", function()
	root.AssemblyLinearVelocity = V.new(10, 0, 0)
	eq(fireOnce(), nil, "disparo")
	root.AssemblyLinearVelocity = V.zero
end)

print("Apuntado manual")

test("manual: tira hacia donde mira aunque el más cercano esté atrás", function()
	state.aimMode = "Manual"
	Config.Player.AimConeFirstPerson = 360 -- en automático elegiría al de atrás
	local dir = fireOnce()
	assert(dir and dir.Z > 0.99 and math.abs(dir.X) < 0.01, "debería tirar derecho hacia adelante")
	Config.Player.AimConeFirstPerson = 110
end)

test("manual: tira aunque no haya nadie delante", function()
	ahead.alive = false
	local dir = fireOnce()
	assert(dir and dir.Z > 0.99, "debería disparar hacia la mira")
	ahead.alive = true
end)

test("manual: sin enemigos vivos no tira flechas al aire", function()
	ahead.alive, behind.alive = false, false
	eq(fireOnce(), nil, "disparo")
	ahead.alive, behind.alive = true, true
end)

test("manual: moviéndose tampoco dispara", function()
	root.AssemblyLinearVelocity = V.new(10, 0, 0)
	eq(fireOnce(), nil, "disparo")
	root.AssemblyLinearVelocity = V.zero
	state.aimMode = "Auto"
end)

test("el cliente cambia el modo; el servidor valida y lo publica en AimMode", function()
	PlayerData.init(function() end, function() end)
	local ana = M.addPlayer("Ana")
	eq(ana:GetAttribute("AimMode"), Config.Player.DefaultAimMode, "modo inicial")
	Remotes.SetAimMode.OnServerEvent:Fire(ana, "Manual")
	eq(PlayerData.get(ana).aimMode, "Manual", "estado")
	eq(ana:GetAttribute("AimMode"), "Manual", "atributo")
	Remotes.SetAimMode.OnServerEvent:Fire(ana, "Cualquiera")
	Remotes.SetAimMode.OnServerEvent:Fire(ana, 42)
	eq(PlayerData.get(ana).aimMode, "Manual", "ignora valores inválidos")
	Remotes.SetAimMode.OnServerEvent:Fire(ana, "Auto")
	eq(ana:GetAttribute("AimMode"), "Auto", "vuelve a automático")
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then error("hay pruebas que fallaron") end
