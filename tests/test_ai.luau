-- Simula 60 s de cada enemigo y jefe contra un jugador que se mueve en círculo.
-- Comprueba que ninguno tira errores, que todos los que tienen ataques atacan y que
-- los jefes pasan a su segunda fase.
local M = require("./mocks")
local T = require("./EnemyTypes")
local AI = require("./EnemyAI")

local V = M.Vector3
local half = V.new(60, 0.5, 60)
local summoned = 0
local function part() return { Destroy = function() end } end

AI.init({
	getHalf = function() return half end,
	clampFlat = function(p, m)
		return V.new(math.clamp(p.X, -half.X + m, half.X - m), 0, math.clamp(p.Z, -half.Z + m, half.Z - m))
	end,
	baseColor = function(e) return e.color end,
	setHidden = function(e, h) e.hidden = h end,
	countSummoned = function() return summoned end,
	queueSpawn = function(t)
		assert(T[t], "invoca un tipo inexistente " .. tostring(t))
		summoned += 1
	end,
}, {
	fireEnemyProjectile = function(_, d, opts)
		assert(math.abs(d.Magnitude - 1) < 1e-3, "dirección no unitaria")
		assert(opts.speed > 0 and opts.damage > 0, "proyectil sin velocidad o daño")
	end,
}, {
	strip = function() return part() end,
	marker = function() end,
	warn = function(_, r, d, dmg) assert(r > 0 and d > 0 and dmg > 0, "aviso de área inválido") end,
	zone = function(_, r, d, dps) assert(r > 0 and d > 0 and dps > 0, "zona inválida") end,
})

-- Jugador falso: PlayerLife.damage lo ignora porque no tiene personaje, alcanza para la IA
local target = {
	player = { Character = nil },
	root = { Position = V.zero },
	humanoid = {},
	state = { life = "ALIVE" },
}

local ids = {}
for id in T do table.insert(ids, id) end
table.sort(ids)

local problems = 0
for _, id in ids do
	local def = T[id]
	summoned = 0
	local e = {
		typeId = id, def = def, radius = (def.Size or 3) / 2, height = def.Height or def.Size or 3,
		color = def.Color, maxHealth = def.Health, health = def.Health, healthMult = 1, dmgMult = 1,
		isBoss = def.Boss == true, hidden = false, alive = true,
		part = { Position = V.new(20, 0, 20), Color = def.Color, Transparency = 0, CFrame = { LookVector = V.zAxis } },
	}
	AI.setup(e)
	local used, phases = {}, {}
	local ok, err = pcall(function()
		local t = 0
		while t < 60 do
			M.now = t
			target.root.Position = V.new(math.cos(t * 0.7) * 15, 0, math.sin(t * 0.7) * 15)
			if e.isBoss then e.health = def.Health * math.max(0.05, 1 - t / 60) end
			local before = e.ai.state
			local pos, facing = AI.step(e, 1 / 30, { target })
			assert(pos and pos.X == pos.X, "posición inválida")
			if e.ai.state == "Windup" and before ~= "Windup" then
				used[e.ai.attack.Type] = (used[e.ai.attack.Type] or 0) + 1
			end
			phases[e.ai.phase] = true
			e.part.Position = V.new(math.clamp(pos.X, -59, 59), 0, math.clamp(pos.Z, -59, 59))
			if facing then e.part.CFrame = { LookVector = facing } end
			t += 1 / 30
		end
	end)
	local list = {}
	for ty, n in used do table.insert(list, ty .. "×" .. n) end
	table.sort(list)
	local nPhases = 0
	for _ in phases do nPhases += 1 end
	local line = string.format("  %-15s %s", id, #list > 0 and table.concat(list, " ") or "(cuerpo a cuerpo)")
	local hasAttacks = def.Attacks ~= nil or def.Phases ~= nil
	if not ok then problems += 1; line ..= "  <<< ERROR: " .. tostring(err) end
	if hasAttacks and #list == 0 then problems += 1; line ..= "  <<< nunca atacó" end
	if def.Boss and nPhases < #def.Phases then problems += 1; line ..= "  <<< no pasó de fase" end
	print(line)
end

print(string.format("\n%d tipos simulados, %d problemas", #ids, problems))
if problems > 0 then error("hay pruebas que fallaron") end
