-- Valida el catálogo de enemigos y capítulos, y el generador de oleadas (con escalado coop).
local Config = require("./Config")
local T = require("./EnemyTypes")
local Chapters = require("./Chapters")
local Waves = require("./Waves")

local errors = 0
local function err(msg)
	errors += 1
	print("  FALLÓ " .. msg)
end

local MOVES = { Chase = true, Erratic = true, Keep = true, Wander = true, Still = true }
local ATTACKS = { Dash = true, Shoot = true, Area = true, Breath = true, Teleport = true, Burrow = true, Summon = true, Grab = true }
-- Campos que EnemyAI sortea con R()/RI(): solo estos pueden ser rangos {min, max}
local RANGEABLE = {
	Cooldown = true, Telegraph = true, RepeatTelegraph = true, Recover = true, ChainRest = true,
	Distance = true, Speed = true, Damage = true, Count = true, Bursts = true, BurstDelay = true,
	Repeats = true, Radius = true, Delay = true, Scatter = true, Duration = true, Emerge = true, Rotate = true, Dps = true,
}

local function checkAttack(id, a)
	if not ATTACKS[a.Type] then err(id .. ": ataque desconocido " .. tostring(a.Type)) end
	if a.Type == "Summon" and not T[a.Spawn] then err(id .. ": invoca un tipo inexistente " .. tostring(a.Spawn)) end
	if a.Then then checkAttack(id .. ".Then", a.Then) end
	for k, v in a do
		if type(v) == "table" and type(v[1]) == "number" and k ~= "SpeedSeq" then
			if #v ~= 2 or v[1] > v[2] then err(id .. ": rango inválido en " .. k) end
			if not RANGEABLE[k] then err(id .. ": " .. k .. " no admite rango {min, max}") end
		end
	end
end

print("Catálogo de enemigos")
local count = 0
for id, d in T do
	count += 1
	for _, f in { "Name", "Health", "Color" } do
		if d[f] == nil then err(id .. ": falta " .. f) end
	end
	if not d.Boss and not d.Cost then err(id .. ": falta Cost") end
	if d.Boss and not d.Phases then err(id .. ": jefe sin Phases") end
	for i, p in d.Phases or { { Move = d.Move, Attacks = d.Attacks or {} } } do
		if not p.Move or not MOVES[p.Move.Type] then err(id .. " fase " .. i .. ": Move inválido") end
		for _, a in p.Attacks or {} do checkAttack(id, a) end
	end
	if d.OnDeath and d.OnDeath.Split and not T[d.OnDeath.Split.Type] then err(id .. ": se divide en un tipo inexistente") end
end
print(string.format("  %d tipos revisados", count))

print("Capítulos")
for _, ch in Chapters do
	for _, e in ch.Pool do
		if not T[e.Type] then err(ch.Name .. ": pool con tipo inexistente " .. e.Type) end
	end
	for _, b in { ch.MiniBoss, ch.Boss } do
		if not T[b.Type] or not T[b.Type].Boss then err(ch.Name .. ": jefe inválido " .. b.Type) end
	end
end
print(string.format("  %d capítulos revisados", #Chapters))

print("Escalado coop de las oleadas")
local function avgSize(ch, n, mult)
	local total = 0
	for _ = 1, 200 do total += #Waves.buildQueue(ch, n, mult) end
	return total / 200
end
for players, scale in Config.Coop.Scaling do
	local ratio = avgSize(Chapters[1], 8, scale.Count) / avgSize(Chapters[1], 8, 1)
	print(string.format("  %d jugadores: %.2fx enemigos (objetivo %.2fx)", players, ratio, scale.Count))
	if math.abs(ratio - scale.Count) > 0.2 then err(players .. " jugadores: cantidad fuera de lo esperado") end
end

print("Variedad")
local same = 0
for _ = 1, 20 do
	local a, b = Waves.buildQueue(Chapters[2], 7), Waves.buildQueue(Chapters[2], 7)
	table.sort(a)
	table.sort(b)
	if table.concat(a, ",") == table.concat(b, ",") then same += 1 end
end
print(string.format("  %d de 20 pares de la misma oleada salieron idénticos", same))
if same > 5 then err("las oleadas se repiten demasiado") end

print(string.format("\n%d fallas", errors))
if errors > 0 then error("hay pruebas que fallaron") end
