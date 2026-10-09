--!strict
-- Orbs (ModuleScript)
-- Ubicación: ServerScriptService > Server > Orbs
-- Orbes de XP: cada enemigo suelta uno al morir y el jugador que pasa cerca lo junta (imán,
-- radio = stats.pickupRadius). La XP es del equipo: la junte quien la junte, suben todos.
-- Al terminar la oleada, los orbes que quedan se juntan solos ("aspiradora").
--
-- El servidor decide todo (dónde hay orbes y quién los junta). Los clientes los dibujan con
-- lo que llega por Remotes.Orbs, agrupado cada FlushInterval:
--   { spawn = { {id, pos, value}, ... }, take = { {id, userId}, ... }, clear = true? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CombatFeed = require(script.Parent.CombatFeed)

type Orb = { id: number, pos: Vector3, value: number }
export type Collector = { player: Player, root: BasePart, state: { stats: { pickupRadius: number } } }

local Orbs = {}

local remote: RemoteEvent? = nil
local addXP: (number) -> () = function(_n: number) end
local list: { Orb } = {}
local nextId = 0
local spawned: { { any } } = {}
local taken: { { any } } = {}
local cleared = false
local lastFlush = 0

function Orbs.init(orbsRemote: RemoteEvent, onXP: (number) -> ())
	remote = orbsRemote
	addXP = onXP
end

local function take(index: number, player: Player?)
	local orb = table.remove(list, index) :: Orb
	addXP(orb.value)
	table.insert(taken, { orb.id, if player then player.UserId else 0 })
	if player then
		CombatFeed.xp(player, orb.pos, orb.value)
	end
end

-- Suelta un orbe con esta XP.
function Orbs.drop(pos: Vector3, value: number)
	if value <= 0 then
		return
	end
	-- Demasiados: el más viejo se cobra solo (la XP no se pierde)
	if #list >= Config.Frenzy.MaxOrbs then
		take(1, nil)
	end
	nextId += 1
	local orb = { id = nextId, pos = pos, value = value } -- pos: apoyado en el piso
	table.insert(list, orb)
	table.insert(spawned, { orb.id, orb.pos, orb.value } :: { any })
end

-- Cada frame: el que esté dentro de su radio de imán junta el orbe.
function Orbs.update(collectors: { Collector })
	for i = #list, 1, -1 do
		local orb = list[i]
		for _, c in collectors do
			local p = c.root.Position
			local dx, dz = p.X - orb.pos.X, p.Z - orb.pos.Z
			local r = c.state.stats.pickupRadius
			if dx * dx + dz * dz <= r * r then
				take(i, c.player)
				break
			end
		end
	end
end

-- Aspiradora: cada orbe va al jugador más cercano (o al equipo si no hay nadie).
function Orbs.collectAll(collectors: { Collector })
	for i = #list, 1, -1 do
		local orb = list[i]
		local best: Player? = nil
		local bestDist = math.huge
		for _, c in collectors do
			local d = Vector3.new(c.root.Position.X - orb.pos.X, 0, c.root.Position.Z - orb.pos.Z).Magnitude
			if d < bestDist then
				best, bestDist = c.player, d
			end
		end
		take(i, best)
	end
end

function Orbs.count(): number
	return #list
end

-- Manda a los clientes lo que cambió (cada FlushInterval).
function Orbs.flush(now: number)
	if now - lastFlush < Config.CombatText.FlushInterval then
		return
	end
	lastFlush = now
	if #spawned == 0 and #taken == 0 and not cleared then
		return
	end
	local r = remote
	if r then
		r:FireAllClients({ spawn = spawned, take = taken, clear = cleared })
	end
	spawned = {}
	taken = {}
	cleared = false
end

-- Fin de partida: sin orbes (no dan XP).
function Orbs.clear()
	table.clear(list)
	spawned = {}
	taken = {}
	cleared = true
	lastFlush = -math.huge
	Orbs.flush(os.clock()) -- avisar ya: después de la partida nadie más llama a flush
end

return Orbs
