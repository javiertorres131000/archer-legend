-- Agarre: el Atrapador te inmoviliza; te salva un compañero pegándole o te soltás forcejeando.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Grab = require("./Grab")
local Combat = require("./Combat")
local Dash = require("./Dash")
local Remotes = require("./Remotes")
local EnemyTypes = require("./EnemyTypes")
local Chapters = require("./Chapters")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local V = M.Vector3.new
local Cfg = Config.Grab

print("Agarre")
local A = M.addPlayer("Ana")
local B = M.addPlayer("Beto")
local sA, sB = PlayerData.get(A), PlayerData.get(B)
sA.inMatch, sB.inMatch = true, true

local function targetOf(p)
	for _, t in PlayerData.getAliveTargets() do
		if t.player == p then return t end
	end
	error("sin target para " .. p.Name)
end
local function noShield(p)
	for _, c in p.Character:GetChildren() do
		if c.ClassName == "ForceField" then c:Destroy() end
	end
end
local tA, tB = targetOf(A), targetOf(B)
tA.root.Position = V(0, 3, 0)
tB.root.Position = V(20, 3, 0)

local function fresh()
	Grab.clear()
	Enemies.clear()
	M.advance(Cfg.RegrabCooldown + 1)
	for _, p in { A, B } do
		local s = PlayerData.get(p)
		s.life = "ALIVE"
		s.dashUntil = 0
		s.lastHurt = -math.huge
		s.currentOffer = nil -- matar al Atrapador da XP: puede abrir una oferta y pausar
		s.pendingOffers = 0
		noShield(p)
		local h = p.Character:FindFirstChildOfClass("Humanoid")
		h.Health = h.MaxHealth
	end
	tA.root.Anchored = false
	PlayerData.setPaused(false)
end
local function grabber(pos)
	return Enemies.spawn("Grabber", pos or V(2, 0, 0))
end
local function update(seconds, step)
	step = step or 0.1
	local t = 0
	while t < seconds - 1e-6 do
		M.advance(step)
		Grab.update(step)
		t += step
	end
end
local function flatDist(e, root)
	local d = e.part.Position - root.Position
	return V(d.X, 0, d.Z).Magnitude
end

test("agarra: quedás anclado, sin atacar ni dash, y el cliente se entera", function()
	fresh()
	local e = grabber()
	assert(Grab.try(e, tA, 12), "debería agarrar")
	assert(tA.root.Anchored == true, "anclado")
	assert(A:GetAttribute("Grabbed") == true and sA.grabbed, "atributo y estado")
	assert(Grab.isGrabbed(A) and e.grabbing == A)
	assert(not Dash.request(A, V(1, 0, 0)), "sin dash")
	-- No ataca aunque tenga el gatillo apretado
	local fired = 0
	local old = Remotes.ProjectileFired.FireAllClients
	Remotes.ProjectileFired.FireAllClients = function() fired += 1 end
	local mode = Config.Player.FireMode
	Config.Player.FireMode = "Manual"
	sA.lastShot = -math.huge
	Combat.setTrigger(A, true, V(1, 0, 0))
	Combat.update(0.01, { tA }, M.now + 10, false)
	assert(fired == 0, "atacó estando agarrado")
	Combat.setTrigger(A, false, V(1, 0, 0))
	Config.Player.FireMode = mode
	Remotes.ProjectileFired.FireAllClients = old
end)

test("mientras te tiene te saca vida de a poco", function()
	local h = tA.humanoid
	local before = h.Health
	update(2)
	local lost = before - h.Health
	local expected = 12 * 2
	assert(lost >= expected * 0.7 and lost <= expected * 1.4, "perdió " .. lost)
end)

test("el compañero le pega y te suelta; queda anotado quién te salvó", function()
	local e = Enemies.list[1]
	local distBefore = flatDist(e, tA.root)
	Enemies.damage(e, e.maxHealth * (Cfg.ReleaseDamageFraction + 0.01), B)
	update(0.1)
	assert(not Grab.isGrabbed(A), "debería soltarlo")
	assert(tA.root.Anchored == false and A:GetAttribute("Grabbed") == false and not sA.grabbed)
	assert(string.find(A:GetAttribute("SavedBy") or "", "Beto", 1, true), "SavedBy")
	assert(string.find(B:GetAttribute("Rescued") or "", "Ana", 1, true), "Rescued")
	assert((e.stunUntil or 0) > M.now, "queda aturdido: " .. tostring(e.stunUntil) .. " vs " .. tostring(M.now) .. " alive " .. tostring(e.alive))
	assert(flatDist(e, tA.root) > distBefore + 1, "sale despedido")
end)

test("si lo matan también te suelta", function()
	fresh()
	local e = grabber()
	assert(Grab.try(e, tA, 12))
	Enemies.damage(e, e.maxHealth * 2, B)
	update(0.1)
	assert(not Grab.isGrabbed(A) and tA.root.Anchored == false)
end)

test("solo: machacando te soltás; tocar demasiado rápido no cuenta", function()
	fresh()
	local e = grabber()
	assert(Grab.try(e, tA, 12))
	Grab.struggle(A)
	Grab.struggle(A) -- en el mismo instante: no cuenta
	assert(math.abs((A:GetAttribute("GrabProgress") or 0) - 1 / Cfg.StrugglePresses) < 1e-6, "contó dos toques simultáneos")
	for _ = 2, Cfg.StrugglePresses - 1 do
		M.advance(0.1)
		Grab.struggle(A)
	end
	assert(Grab.isGrabbed(A), "todavía no")
	M.advance(0.1)
	Grab.struggle(A)
	assert(not Grab.isGrabbed(A), "se soltó")
	assert(tA.root.Anchored == false)
	-- Por el remote también (y el de alguien no agarrado no hace nada)
	Remotes.StruggleRequest.OnServerEvent:Fire(B)
	assert(not Grab.isGrabbed(B))
end)

test("no agarra: con escudo, en dash, ya agarrado, derribado; y uno no tiene a dos", function()
	fresh()
	local e1, e2 = grabber(), grabber(V(-2, 0, 0))
	local field = M.Instance.new("ForceField")
	field.Parent = A.Character
	assert(not Grab.try(e1, tA, 12), "con escudo")
	field:Destroy()
	sA.dashUntil = M.now + 1
	assert(not Grab.try(e1, tA, 12), "en dash")
	sA.dashUntil = 0
	assert(Grab.try(e1, tA, 12))
	assert(not Grab.try(e2, tA, 12), "ya agarrado")
	assert(not Grab.try(e1, tB, 12), "ya tiene a alguien")
	sB.life = "DOWNED"
	assert(not Grab.try(e2, tB, 12), "derribado")
	sB.life = "ALIVE"
end)

test("si te derriban, te suelta y quedás libre", function()
	sA.life = "DOWNED"
	update(0.1)
	assert(not Grab.isGrabbed(A) and tA.root.Anchored == false)
	sA.life = "ALIVE"
end)

test("tope de tiempo: nadie queda agarrado para siempre", function()
	fresh()
	local e = grabber()
	assert(Grab.try(e, tA, 0.01))
	update(Cfg.MaxHold - 0.5, 0.25)
	assert(Grab.isGrabbed(A))
	update(1, 0.25)
	assert(not Grab.isGrabbed(A), "debería soltarlo al llegar al tope")
end)

test("recién soltado no vuelve a agarrar enseguida", function()
	local e = Enemies.list[1]
	assert(not Grab.try(e, tA, 12), "muy pronto")
	M.advance(Cfg.RegrabCooldown + 0.1)
	assert(Grab.try(e, tA, 12), "después del tiempo, sí")
	Grab.clear()
	assert(not Grab.isGrabbed(A) and tA.root.Anchored == false, "clear suelta a todos")
end)

test("la IA: el Atrapador salta, te agarra y se queda pegado", function()
	fresh()
	local e = grabber(V(14, 0, 0))
	tA.root.Position = V(0, 3, 0)
	local grabbed = false
	local now = M.now
	for _ = 1, 150 do
		Enemies.update(0.1, { tA }, now, false)
		now += 0.1
		M.advance(0.1)
		if Grab.isGrabbed(A) then grabbed = true break end
	end
	assert(grabbed, "no lo agarró en 15 s")
	for _ = 1, 10 do
		Enemies.update(0.1, { tA }, now, false)
		now += 0.1
	end
	assert(flatDist(e, tA.root) <= e.radius + 1.6, "se quedó pegado: " .. flatDist(e, tA.root))
	Grab.clear()
end)

test("el Atrapador existe y sale en todos los capítulos desde la oleada 3", function()
	local def = EnemyTypes.Grabber
	assert(def and def.Attacks[1].Type == "Grab" and def.Attacks[1].Dps > 0)
	for _, ch in Chapters do
		local found = false
		for _, entry in ch.Pool do
			if entry.Type == "Grabber" then
				found = true
				assert(entry.From == 3, ch.Id)
			end
		end
		assert(found, "falta en " .. ch.Id)
	end
end)

test("con dos Atrapadores no te agarran en cadena: inmunidad después de soltarte", function()
	fresh()
	local e1 = grabber(V(2, 0, 0))
	local e2 = grabber(V(-2, 0, 0))
	assert(Grab.try(e1, tA, 12), "el primero agarra")
	for _ = 1, Cfg.StrugglePresses do
		M.advance(0.1)
		Grab.struggle(A)
	end
	assert(not Grab.isGrabbed(A), "se soltó forcejeando")
	assert(not Grab.try(e2, tA, 12), "el segundo no puede agarrarlo enseguida")
	M.advance(Cfg.ImmuneAfter - 0.5)
	assert(not Grab.try(e2, tA, 12), "todavía inmune")
	M.advance(1)
	assert(Grab.try(e2, tA, 12), "pasada la inmunidad, sí")
	Grab.clear()
end)

print(passed .. " pruebas, 0 fallas")
