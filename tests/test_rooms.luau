-- Salas y puertas: al terminar una oleada se abre la puerta, el equipo tiene que entrar
-- (o se acaba el tiempo) y recién ahí cambia la sala y arranca la oleada siguiente.
-- Carga el GameServer real y lo hace avanzar frame a frame.
local M = require("./mocks")
local Config = require("./Config")
Config.Camera.Mode = "TopDown"
local Remotes = require("./Remotes")
local PlayerData = require("./PlayerData")
local Enemies = require("./Enemies")
local Waves = require("./Waves")
local Chapters = require("./Chapters")
local Arena = require("./Arena")
local MatchManager = require("./MatchManager")

local V = M.Vector3
local RunService = M.game:GetService("RunService")
local gameState = Remotes.GameState
local RoomCfg = Config.Rooms

local pendingChoices = {}
Remotes.SkillOffer.FireClient = function(_, player, offerId)
	table.insert(pendingChoices, { player = player, offerId = offerId })
end

require("./GameServer")

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

local A = M.addPlayer("Ana")
local B = M.addPlayer("Beto")
local players = { A, B }

-- Un frame de servidor. Los jugadores son invulnerables y eligen siempre la primera habilidad.
local function tick(seconds, killAll)
	local dt = 1 / 30
	for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
		M.advance(dt)
		for _, p in players do
			local c = p.Character
			if c and not c:FindFirstChild("God") then
				local f = M.Instance.new("ForceField")
				f.Name = "God"
				f.Parent = c
			end
		end
		if killAll then
			for _, e in table.clone(Enemies.list) do
				Enemies.damage(e, 1e9, A)
			end
		end
		RunService.Heartbeat:Fire(dt)
		for _, ch in pendingChoices do
			Remotes.ChooseSkill.OnServerEvent:Fire(ch.player, ch.offerId, 1)
		end
		table.clear(pendingChoices)
	end
end
local function root(p) return p.Character.HumanoidRootPart end
local function phase() return gameState:GetAttribute("Phase") end
local function doorModel() return M.workspace.Arena:FindFirstChild("Door") end
-- Mata todo hasta que termina la oleada (con un tope de tiempo)
local function clearWave()
	for _ = 1, 600 do
		tick(0.5, true)
		if phase() == "Break" then return end
	end
	error("la oleada no terminó")
end

print("Salas y puertas")

-- Arrancar una partida de dos
tick(Config.Match.RequestCooldown + 0.1)
Remotes.LobbyRequest.OnServerEvent:Fire(A, "SetReady", true)
tick(Config.Match.RequestCooldown + 0.1)
Remotes.LobbyRequest.OnServerEvent:Fire(B, "SetReady", true)
tick(Config.Match.CountdownTime + 1)

test("al empezar: sala 1, puerta cerrada, todos en la entrada (sur)", function()
	eq(MatchManager.getState(), "PLAYING", "estado")
	eq(gameState:GetAttribute("RoomIndex"), 1, "sala")
	eq(doorModel(), nil, "puerta")
	for _, p in players do
		assert(root(p).Position.Z > Arena.Half.Z * 0.5, "debería estar en la entrada, Z = " .. root(p).Position.Z)
	end
	assert(#M.workspace.Arena.Room:GetChildren() > 0, "la sala tiene decoración")
end)

test("al terminar la oleada se abre la puerta y no arranca la siguiente sola", function()
	clearWave()
	tick(0.2)
	assert(doorModel() ~= nil, "debería existir la puerta")
	assert(gameState:GetAttribute("DoorEnd") > 0, "DoorEnd debería estar fijado")
	eq(gameState:GetAttribute("DoorNeeded"), 2, "tienen que entrar los dos")
	tick(Config.Waves.BreakTime + 2)
	eq(phase(), "Break", "sigue el descanso aunque pasó BreakTime")
	eq(gameState:GetAttribute("Wave"), 1, "oleada")
end)

test("si entra uno solo, la sala no cambia", function()
	root(A).Position = Arena.doorPosition() + V.new(0, 3, 0)
	tick(1)
	eq(gameState:GetAttribute("DoorInside"), 1, "adentro")
	eq(gameState:GetAttribute("RoomIndex"), 1, "sala")
	eq(phase(), "Break", "fase")
end)

test("cuando entran todos: sala 2, puerta cerrada, todos en la entrada", function()
	root(B).Position = Arena.doorPosition() + V.new(2, 3, 0)
	tick(0.2)
	eq(gameState:GetAttribute("RoomIndex"), 2, "sala")
	eq(doorModel(), nil, "puerta")
	eq(gameState:GetAttribute("DoorEnd"), 0, "DoorEnd")
	for _, p in players do
		assert(root(p).Position.Z > Arena.Half.Z * 0.5, "debería estar en la entrada, Z = " .. root(p).Position.Z)
		assert(not Arena.inDoorZone(root(p).Position), "no debería quedar en la puerta")
	end
	eq(phase(), "Break", "todavía no arranca (EnterDelay)")
end)

test("después de EnterDelay arranca la oleada 2", function()
	tick(RoomCfg.EnterDelay + 0.2)
	eq(phase(), "Wave", "fase")
	eq(gameState:GetAttribute("Wave"), 2, "oleada")
end)

test("si nadie va a la puerta, pasan solos al acabarse el tiempo", function()
	clearWave()
	tick(RoomCfg.DoorTimeout - 2)
	eq(gameState:GetAttribute("RoomIndex"), 2, "todavía en la sala 2")
	tick(3)
	eq(gameState:GetAttribute("RoomIndex"), 3, "sala tras el límite")
	tick(RoomCfg.EnterDelay + 0.2)
	eq(gameState:GetAttribute("Wave"), 3, "oleada")
end)

test("un jugador derribado/eliminado no bloquea la puerta (solo cuentan los que están en pie)", function()
	clearWave()
	tick(0.2)
	-- En el descanso todos vuelven a estar en pie: DoorNeeded es igual a los participantes vivos
	eq(gameState:GetAttribute("DoorNeeded"), #PlayerData.getAliveTargets(), "necesarios")
	for _, p in players do
		root(p).Position = Arena.doorPosition() + V.new(0, 3, 0)
	end
	tick(RoomCfg.EnterDelay + 0.5)
	eq(gameState:GetAttribute("RoomIndex"), 4, "sala")
end)

test("si se van todos con la puerta abierta, se cierra y se limpia", function()
	clearWave()
	tick(0.2)
	assert(doorModel() ~= nil, "puerta abierta durante el descanso")
	M.removePlayer(A)
	M.removePlayer(B)
	tick(Config.Match.ResultsTime + Config.Match.ReturnDelay + 2)
	eq(doorModel(), nil, "puerta")
	eq(gameState:GetAttribute("DoorEnd"), 0, "DoorEnd")
end)

test("salas hechas a mano: se usa el Model de ServerStorage > Rooms > <capítulo>", function()
	local ServerStorage = M.game:GetService("ServerStorage")
	local rooms = M.Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = ServerStorage
	local set = M.Instance.new("Folder")
	set.Name = "forest"
	set.Parent = rooms
	for _, name in { "Sala2", "Sala1" } do
		local model = M.Instance.new("Model")
		model.Name = name
		model.Clone = function(self)
			local copy = M.Instance.new("Model")
			copy.Name = self.Name
			return copy
		end
		model.Parent = set
	end
	Arena.buildRoom(Chapters[1], 1)
	local kids = M.workspace.Arena.Room:GetChildren()
	eq(#kids, 1, "un solo modelo")
	eq(kids[1].Name, "Sala1", "sala 1 usa el primero por nombre")
	Arena.buildRoom(Chapters[1], 2)
	eq(M.workspace.Arena.Room:GetChildren()[1].Name, "Sala2", "sala 2")
	Arena.buildRoom(Chapters[1], 3)
	eq(M.workspace.Arena.Room:GetChildren()[1].Name, "Sala1", "sala 3 vuelve a empezar")
	-- Otro capítulo sin modelos: se genera por código
	Arena.buildRoom(Chapters[2], 1)
	assert(#M.workspace.Arena.Room:GetChildren() >= RoomCfg.PropsPerRoom, "decoración generada para ruins")
	rooms.Parent = nil
end)

test("más enemigos por oleada: EnemyCountMultiplier agranda el presupuesto", function()
	local ch = Chapters[1]
	local old = Config.Waves.EnemyCountMultiplier
	local function avg(mult)
		Config.Waves.EnemyCountMultiplier = mult
		local total = 0
		for _ = 1, 200 do
			total += #Waves.buildQueue(ch, 4, 1)
		end
		return total / 200
	end
	local base, more = avg(1), avg(1.5)
	Config.Waves.EnemyCountMultiplier = old
	print(string.format("         enemigos oleada 4: x1 = %.1f · x1.5 = %.1f", base, more))
	assert(more > base * 1.3, "debería haber ~50% más enemigos")
end)

test("la decoración queda pegada a las paredes y lejos de puerta y entrada", function()
	for _, ch in Chapters do
		Arena.buildRoom(ch, 1)
		for _, prop in M.workspace.Arena.Room:GetChildren() do
			local pos = prop.Position or (prop.PrimaryPart and prop.PrimaryPart.Position)
			if not pos then
				for _, part in prop:GetChildren() do
					if part.Position then pos = part.Position break end
				end
			end
			if pos then
				local edge = math.min(Arena.Half.X - math.abs(pos.X), Arena.Half.Z - math.abs(pos.Z))
				assert(edge <= RoomCfg.PropBand + 6, string.format("%s: prop en el centro (%.0f, %.0f)", ch.Id, pos.X, pos.Z))
				assert(not Arena.inDoorZone(pos), ch.Id .. ": prop en la puerta")
			end
		end
	end
end)

print(string.format("\n%d pruebas, %d fallas", passed + failed, failed))
if failed > 0 then
	error("hay pruebas que fallaron")
end
