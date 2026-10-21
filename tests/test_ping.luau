-- Marcas (Ping): el servidor decide qué se marcó, valida y se lo manda a los participantes.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Chests = require("./Chests")
local Ground = require("./Ground")
local Grab = require("./Grab")
local Ping = require("./Ping")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new
local Cfg = Config.Ping

print("Marcas")
Ground.flat()
local A = M.addPlayer("Ana")
local B = M.addPlayer("Beto")
local L = M.addPlayer("Lobby") -- no está en la partida: no recibe marcas
local sA, sB = PlayerData.get(A), PlayerData.get(B)
sA.inMatch, sB.inMatch = true, true
A.Character.HumanoidRootPart.Position = V(0, 3, 0)
B.Character.HumanoidRootPart.Position = V(30, 3, 0)

-- Lo que reciben los clientes
local sent = {}
Remotes.Ping.FireClient = function(_, p, action, arg)
	table.insert(sent, { p = p, action = action, arg = arg })
end
Remotes.Ping.FireAllClients = function(_, action, arg)
	table.insert(sent, { p = "todos", action = action, arg = arg })
end
local function fresh()
	Ping.clear()
	Enemies.clear()
	table.clear(sent)
	M.advance(Cfg.Cooldown + 0.1)
	sA.life, sB.life = "ALIVE", "ALIVE"
	sA.grabbed = false
	PlayerData.setPaused(false)
end
local head = V(0, 4.5, 0)
local function ping(p, origin, dir)
	M.advance(Cfg.Cooldown + 0.01)
	return Ping.request(p, origin, dir)
end

test("mirando a un enemigo lo marca (y la marca lo sigue)", function()
	fresh()
	local e = Enemies.spawn("GreenSlime", V(0, 0, 30))
	local dir = (e.part.Position - head).Unit
	local mark = ping(A, head, dir)
	assert(mark and mark.kind == "Enemy", "tipo: " .. tostring(mark and mark.kind))
	assert(mark.part == e.part, "la marca apunta a la pieza del enemigo")
	assert(mark.label == e.def.Name, mark.label)
	assert(mark.name == "Ana" and mark.userId == A.UserId)
end)

test("se manda solo a los participantes", function()
	local to = {}
	for _, s in sent do
		assert(s.action == "Add")
		to[s.p] = true
	end
	assert(to[A] and to[B] and not to[L], "destinatarios")
end)

test("perdona un poco de puntería, más de lejos", function()
	fresh()
	local e = Enemies.spawn("GreenSlime", V(0, 0, 60))
	local off = V(e.radius + Cfg.AimAssist, 0, 0) -- apuntar un poco al costado
	local dir = (e.part.Position + off - head).Unit
	local mark = ping(A, head, dir)
	assert(mark and mark.kind == "Enemy", "debería contar como enemigo")
	local wide = (e.part.Position + V(15, 0, 0) - head).Unit
	local miss = ping(A, head, wide)
	assert(miss and miss.kind ~= "Enemy", "muy al costado no")
end)

test("mirando al piso marca el lugar", function()
	fresh()
	local target = V(10, 0, 20)
	local mark = ping(A, head, (target - head).Unit)
	assert(mark and mark.kind == "Ground", tostring(mark and mark.kind))
	assert((mark.pos - target).Magnitude < 2.5, "lugar: " .. tostring(mark.pos.X) .. "," .. tostring(mark.pos.Z))
	assert(math.abs(mark.pos.Y - Ground.y(mark.pos.X, mark.pos.Z)) < 0.01, "apoyado en el piso")
end)

test("mirando al cielo marca el final de la mira, adentro del mapa", function()
	fresh()
	local mark = ping(A, head, V(0, 1, 1).Unit)
	assert(mark and mark.kind == "Ground")
	local half = Enemies.getHalf()
	assert(math.abs(mark.pos.X) <= half.X and math.abs(mark.pos.Z) <= half.Z)
end)

test("un enemigo atrás tuyo no se marca", function()
	fresh()
	Enemies.spawn("GreenSlime", V(0, 0, -20))
	local mark = ping(A, head, V(0, -0.2, 1).Unit)
	assert(mark and mark.kind == "Ground")
end)

test("cofre", function()
	fresh()
	local old = Chests.positions
	Chests.positions = function() return { V(-15, 1, 25) } end
	local mark = ping(A, head, (V(-15, 1, 25) - head).Unit)
	Chests.positions = old
	assert(mark and mark.kind == "Chest", tostring(mark and mark.kind))
end)

test("derribado o agarrado: marcar pide ayuda en tu lugar", function()
	fresh()
	sA.life = "DOWNED"
	local mark = ping(A, head, V(0, 0, 1))
	assert(mark and mark.kind == "Help" and mark.label == "¡AYUDA!")
	assert((mark.pos - A.Character.HumanoidRootPart.Position).Magnitude < 0.01)
	sA.life = "ALIVE"
	sA.grabbed = true
	local mark2 = ping(A, head, V(0, 0, 1))
	assert(mark2 and mark2.kind == "Help")
	sA.grabbed = false
end)

test("valida: tipos, números raros, fuera de partida, eliminado y pausa", function()
	fresh()
	local nan = 0 / 0
	assert(ping(A, head, nil) == nil)
	assert(ping(A, head, "hola") == nil)
	assert(ping(A, head, V(nan, 0, 1)) == nil)
	assert(ping(A, head, V(0, 0, 0)) == nil, "vector cero")
	assert(ping(A, head, V(0, 0, 5)) == nil, "largo raro")
	assert(ping(L, head, V(0, 0, 1)) == nil, "fuera de la partida")
	sA.life = "ELIMINATED"
	assert(ping(A, head, V(0, 0, 1)) == nil, "eliminado")
	sA.life = "ALIVE"
	PlayerData.setPaused(true)
	assert(ping(A, head, V(0, 0, 1)) == nil, "en pausa")
	PlayerData.setPaused(false)
	assert(ping(A, "no es un vector", V(0, -0.3, 1).Unit) ~= nil, "origen inválido: usa la cabeza")
end)

test("frecuencia: no se puede inundar de marcas", function()
	fresh()
	assert(ping(A, head, V(0, -0.3, 1).Unit))
	assert(Ping.request(A, head, V(0, -0.3, 1).Unit) == nil, "demasiado rápido")
	M.advance(Cfg.Cooldown * 0.5)
	assert(Ping.request(A, head, V(0, -0.3, 1).Unit) == nil, "todavía no")
	assert(ping(A, head, V(0, -0.3, 1).Unit), "después sí")
end)

test("tope de marcas por jugador: la más vieja se borra", function()
	fresh()
	local ids = {}
	for i = 1, Cfg.MaxPerPlayer + 1 do
		table.insert(ids, ping(A, head, V(0, -0.3, 1).Unit).id)
	end
	local removed = {}
	for _, s in sent do
		if s.action == "Remove" then removed[s.arg] = true end
	end
	assert(removed[ids[1]], "borró la primera")
	assert(not removed[ids[#ids]], "la nueva queda")
	-- Las vencidas no cuentan
	table.clear(sent)
	M.advance(Cfg.Duration + 1)
	ping(A, head, V(0, -0.3, 1).Unit)
	for _, s in sent do
		assert(s.action ~= "Remove", "no borra si las otras ya vencieron")
	end
end)

test("el origen tiene que estar cerca del personaje", function()
	fresh()
	Enemies.spawn("GreenSlime", V(50, 0, 0))
	local far = V(50, 4, -60) -- desde ahí se vería el enemigo, pero está a ~78 studs de Ana
	assert((far - head).Magnitude > Cfg.OriginSlack)
	local mark = ping(A, far, V(0, 0, 1))
	assert(mark and mark.kind ~= "Enemy", "usó un origen trucho")
	-- Desde una cámara cerca (tercera persona), sí se usa ese origen
	local cam = V(0, 8, -10)
	local e = Enemies.spawn("GreenSlime", V(0, 0, 25))
	local ok = ping(A, cam, (e.part.Position - cam).Unit)
	assert(ok and ok.kind == "Enemy")
end)

test("color: cada participante su lugar por UserId", function()
	fresh()
	local mA = ping(A, head, V(0, -0.3, 1).Unit)
	local mB = ping(B, V(30, 4.5, 0), V(0, -0.3, 1).Unit)
	assert(mA.slot == 1 and mB.slot == 2, mA.slot .. " " .. mB.slot)
	assert(Cfg.Colors[mA.slot] and Cfg.Colors[mB.slot])
end)

test("fin de partida: se borran todas", function()
	fresh()
	ping(A, head, V(0, -0.3, 1).Unit)
	table.clear(sent)
	Ping.clear()
	assert(#sent == 1 and sent[1].action == "Clear")
	assert(ping(A, head, V(0, -0.3, 1).Unit), "se puede volver a marcar enseguida")
end)

print(passed .. " pruebas, 0 fallas")
