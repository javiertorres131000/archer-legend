-- Pruebas del ciclo de vida coop: derribo, rescate, eliminación, descanso, entradas y salidas.
local M = require("./mocks")
local Config = require("./Config")
local PlayerData = require("./PlayerData")
local PlayerLife = require("./PlayerLife")

local Coop = Config.Coop
local V = M.Vector3
local passed, failed = 0, 0

local function test(name, f)
	local ok, err = pcall(f)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FALLÓ " .. name .. "\n         " .. tostring(err))
	end
end

local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end

PlayerLife.init()
PlayerData.init(PlayerLife.onPlayerAdded, PlayerLife.onPlayerRemoving)
local ARENA = M.CFrame.new(0, 3, 0)

local function target(p)
	for _, t in PlayerData.getAliveTargets() do
		if t.player == p then return t end
	end
	return nil
end
local function life(p) return PlayerData.get(p).life end
local function hum(p) return p.Character.Humanoid end
local function clearShields(p)
	for _, c in p.Character:GetChildren() do
		if c.ClassName == "ForceField" then c:Destroy() end
	end
end
local function knockDown(p)
	clearShields(p)
	PlayerLife.damage(target(p), 9999)
end
-- Simula N segundos de juego a 30 fps
local function run(seconds)
	local steps = math.floor(seconds * 30 + 0.5)
	for _ = 1, steps do
		M.advance(1 / 30)
		PlayerLife.update(1 / 30)
	end
end
local function prompt(p) return p.Character.HumanoidRootPart:FindFirstChild("RevivePrompt") end

local A = M.addPlayer("Ana")
local B = M.addPlayer("Beto")
-- Arranca una partida con los dos (como haría MatchManager)
PlayerLife.beginMatch({ A, B }, { M.CFrame.new(0, 3, 0), M.CFrame.new(4, 3, 0) })

print("Ciclo de vida coop")

test("en el lobby nadie recibe daño", function()
	local L = M.addPlayer("Lobby")
	local t = { player = L, root = L.Character.HumanoidRootPart, humanoid = L.Character.Humanoid, state = PlayerData.get(L) }
	clearShields(L)
	PlayerLife.damage(t, 50)
	eq(L.Character.Humanoid.Health, 100, "vida")
	eq(PlayerData.get(L).inMatch, false, "no participa")
	M.removePlayer(L)
end)

test("al empezar la partida: participantes ALIVE, en la arena, con escudo", function()
	eq(PlayerData.get(A).inMatch, true, "Ana participa")
	eq(A:GetAttribute("InMatch"), true, "atributo para el cliente")
	eq(A.Character.HumanoidRootPart.Position.X, 0, "en su punto de la arena")
	eq(B.Character.HumanoidRootPart.Position.X, 4, "Beto en el suyo")
end)

test("al aparecer está ALIVE con escudo de aparición", function()
	eq(life(A), "ALIVE", "estado")
	assert(A.Character:FindFirstChildOfClass("ForceField"), "falta el escudo de aparición")
	eq(A:GetAttribute("LifeState"), "ALIVE", "atributo para el HUD")
end)

test("el escudo bloquea el daño", function()
	local h = hum(A).Health
	PlayerLife.damage(target(A), 30)
	eq(hum(A).Health, h, "vida")
end)

test("el daño normal resta vida", function()
	clearShields(A)
	PlayerLife.damage(target(A), 30)
	eq(hum(A).Health, 70, "vida")
end)

test("daño letal: DOWNED con 1 de vida, sin morir, quieto", function()
	knockDown(A)
	eq(life(A), "DOWNED", "estado")
	eq(hum(A).Health, 1, "vida")
	eq(hum(A).WalkSpeed, Coop.DownedWalkSpeed, "velocidad")
	assert(prompt(A), "falta el botón de revivir")
	eq(PlayerData.get(A).downs, 1, "contador de caídas")
end)

test("un derribado no es objetivo ni recibe daño", function()
	eq(target(A), nil, "no debería estar en la lista de objetivos")
	local t = { player = A, root = A.Character.HumanoidRootPart, humanoid = hum(A), state = PlayerData.get(A) }
	PlayerLife.damage(t, 50)
	eq(hum(A).Health, 1, "vida")
end)

test("queda alguien en pie: no es derrota", function()
	eq(PlayerLife.noneActive(), false, "noneActive")
end)

test("no se puede revivir a uno mismo", function()
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(A)
	run(Coop.ReviveTime + 0.1)
	pr.Triggered:Fire(A)
	eq(life(A), "DOWNED", "estado")
	pr.PromptButtonHoldEnded:Fire(A)
end)

test("soltar antes de tiempo no revive", function()
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(B)
	run(1)
	pr.Triggered:Fire(B) -- un cliente tramposo que dispara antes
	eq(life(A), "DOWNED", "estado")
	pr.PromptButtonHoldEnded:Fire(B)
end)

test("el reloj de derribo se frena mientras lo reviven", function()
	local before = A:GetAttribute("DownedLeft")
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(B)
	run(1.5)
	local during = A:GetAttribute("DownedLeft")
	eq(during, before, "tiempo restante")
	eq(A:GetAttribute("RevivedBy"), "Beto", "quién revive")
	assert(A:GetAttribute("ReviveProgress") > 0.4, "progreso del rescate")
	pr.PromptButtonHoldEnded:Fire(B)
end)

test("si el rescatador se aleja, se cancela", function()
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(B)
	run(1)
	M.moveTo(B, V.new(40, 3, 0)) -- lejos
	run(2.5)
	pr.Triggered:Fire(B)
	eq(life(A), "DOWNED", "estado")
	M.moveTo(B, V.new(4, 3, 0))
	pr.PromptButtonHoldEnded:Fire(B)
end)

test("mantener 3 s cerca revive con 40% de vida, escudo y +1 rescate", function()
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(B)
	run(Coop.ReviveTime + 0.1)
	pr.Triggered:Fire(B)
	eq(life(A), "ALIVE", "estado")
	eq(hum(A).Health, hum(A).MaxHealth * Coop.ReviveHealthFraction, "vida")
	eq(hum(A).WalkSpeed, Config.Player.WalkSpeed, "velocidad")
	eq(hum(A).JumpHeight, 7.2, "salto restaurado")
	assert(A.Character:FindFirstChild("ReviveShield"), "falta el escudo post-rescate")
	eq(PlayerData.get(B).revives, 1, "rescates de Beto")
	eq(prompt(A), nil, "el botón debería desaparecer")
	eq(A:GetAttribute("DownedLeft"), nil, "atributos limpios")
end)

test("el escudo post-rescate dura lo configurado", function()
	run(Coop.ReviveInvulnerability + 0.1)
	eq(A.Character:FindFirstChild("ReviveShield"), nil, "escudo")
end)

test("dos rescatadores a la vez: un solo rescate", function()
	local C = M.addPlayer("Caro")
	M.moveTo(C, V.new(-4, 3, 0))
	knockDown(A)
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(B)
	pr.PromptButtonHoldBegan:Fire(C)
	run(Coop.ReviveTime + 0.1)
	pr.Triggered:Fire(B)
	pr.Triggered:Fire(C)
	eq(life(A), "ALIVE", "estado")
	eq(PlayerData.get(B).revives + PlayerData.get(C).revives, 2, "rescates totales (1 previo + 1)")
	M.removePlayer(C)
end)

test("si el rescatador cae a mitad, se cancela", function()
	knockDown(A)
	local pr = prompt(A)
	pr.PromptButtonHoldBegan:Fire(B)
	run(1)
	knockDown(B)
	run(2.5)
	pr.Triggered:Fire(B)
	eq(life(A), "DOWNED", "estado de Ana")
end)

test("todos derribados: no queda nadie activo (derrota)", function()
	eq(PlayerLife.noneActive(), true, "noneActive")
end)

test("se acaba el tiempo: ELIMINATED y el personaje muere", function()
	run(Coop.DownedTime + 0.5)
	eq(life(A), "ELIMINATED", "estado de Ana")
	eq(hum(A).Health, 0, "vida")
	eq(prompt(A), nil, "botón")
end)

test("descanso: derribados se levantan y eliminados reaparecen", function()
	-- B sigue derribado (lo derribaron después), A está eliminada
	local revivesBefore = PlayerData.get(B).revives
	PlayerLife.onBreak(ARENA)
	eq(life(A), "ALIVE", "Ana reaparece")
	eq(hum(A).Health, hum(A).MaxHealth, "Ana con vida completa")
	eq(life(B), "ALIVE", "Beto se levanta")
	eq(PlayerData.get(B).revives, revivesBefore, "levantarse en el descanso no suma rescates")
end)

test("entra alguien a mitad de partida: queda en el lobby, no participa", function()
	local D = M.addPlayer("Dani")
	eq(PlayerData.get(D).inMatch, false, "no participa")
	eq(PlayerLife.partySize(), 2, "la dificultad sigue para 2")
	PlayerLife.onBreak(ARENA)
	eq(PlayerData.get(D).inMatch, false, "el descanso no lo mete en la partida")
	M.removePlayer(D)
end)

test("un reset (muerte de Roblox) cuenta como eliminado", function()
	clearShields(A)
	hum(A).Health = 0 -- como si tocara "Reiniciar"
	eq(life(A), "ELIMINATED", "estado")
	PlayerLife.onBreak(ARENA)
end)

test("se va un derribado: se limpia sin errores", function()
	local E = M.addPlayer("Eli")
	PlayerLife.beginMatch({ E }, { M.CFrame.new(2, 3, 0) })
	knockDown(E)
	prompt(E).PromptButtonHoldBegan:Fire(B)
	M.removePlayer(E)
	run(1)
end)

test("se va el rescatador a mitad: el derribado sigue esperando", function()
	local F = M.addPlayer("Fede")
	PlayerLife.beginMatch({ F }, { M.CFrame.new(2, 3, 0) })
	clearShields(F)
	knockDown(A)
	prompt(A).PromptButtonHoldBegan:Fire(F)
	run(1)
	eq(A:GetAttribute("RevivedBy"), "Fede", "Fede lo está reviviendo")
	M.removePlayer(F)
	run(1)
	eq(life(A), "DOWNED", "estado")
	eq(A:GetAttribute("RevivedBy"), "", "nadie lo está reviviendo")
	PlayerLife.onBreak(ARENA)
end)

test("el tamaño del grupo cuenta solo participantes", function()
	eq(PlayerLife.partySize(), 2, "con Ana y Beto")
	local extra = {}
	for i = 1, 5 do table.insert(extra, M.addPlayer("X" .. i)) end
	eq(PlayerLife.partySize(), 2, "los del lobby no cuentan")
	for _, p in extra do M.removePlayer(p) end
end)

test("fin de partida: derribos limpios y todos de vuelta al lobby", function()
	knockDown(A)
	PlayerLife.endMatch()
	PlayerData.resetStats()
	eq(life(A), "ALIVE", "Ana")
	eq(life(B), "ALIVE", "Beto")
	eq(PlayerData.get(A).inMatch, false, "Ana fuera de la partida")
	eq(prompt(A), nil, "sin botón de rescate")
	eq(PlayerData.get(B).revives, 0, "estadísticas a cero")
	eq(PlayerLife.noneActive(), false, "sin participantes no hay derrota")
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then error("hay pruebas que fallaron") end
