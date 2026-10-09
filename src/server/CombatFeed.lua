--!strict
-- CombatFeed (ModuleScript)
-- Ubicación: ServerScriptService > Server > CombatFeed
-- Junta lo que cada jugador tiene que ver como número flotante y se lo manda agrupado:
--   hit   daño que le hiciste a un enemigo (blanco)
--   crit  golpe crítico (amarillo, grande)
--   burn  daño de quemadura que causaste (naranja)
--   ally  daño de un compañero (gris, solo con Config.CombatText.ShowTeammateDamage)
--   hurt  daño que recibiste (rojo)
--   xp    experiencia de los orbes que juntaste (se suman en un número)
--   kill  murió un enemigo: explosión del color del enemigo y combo (lo ven todos)
--   loot  botín que cobraste (oro, gemas, piedras)
--
-- Para no saturar la red: los golpes al mismo enemigo dentro de FlushInterval se suman en un
-- solo número, y todo sale en un único RemoteEvent por jugador cada FlushInterval.
-- La quemadura hace daño en cada frame (fracciones): se acumula hasta llegar a 1.
-- Es solo visual: el daño, la XP y el botín reales ya los aplicó el servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Cfg = Config.CombatText

export type Kind = "hit" | "crit" | "burn" | "ally" | "hurt" | "xp" | "loot" | "kill"
export type Event = {
	k: Kind,
	p: Vector3?,
	a: number?,
	g: { [string]: number }?,
	i: Instance?, -- la parte del enemigo golpeado (para el destello blanco)
	c: Color3?,
	s: number?,
	x: boolean?, -- enemigo dorado
}

type Pending = { kind: Kind, pos: Vector3, amount: number, part: Instance? }

local CombatFeed = {}

local remote: RemoteEvent? = nil
local merged: { [Player]: { [any]: Pending } } = {} -- golpes sumados por enemigo
local direct: { [Player]: { Event } } = {} -- el resto, tal cual
local lastFlush = 0

function CombatFeed.init(combatText: RemoteEvent)
	remote = combatText
end

local function push(player: Player, event: Event)
	local list = direct[player]
	if not list then
		list = {}
		direct[player] = list
	end
	table.insert(list, event)
end

-- Daño a un enemigo. key identifica al enemigo (para sumar golpes seguidos).
-- part: la parte del enemigo, para que el cliente la haga destellar.
function CombatFeed.dealt(player: Player, key: any, pos: Vector3, amount: number, kind: Kind, part: Instance?)
	if amount <= 0 then
		return
	end
	local byKey = merged[player]
	if not byKey then
		byKey = {}
		merged[player] = byKey
	end
	local slot = kind .. ":" .. tostring(key)
	local entry = byKey[slot]
	if entry then
		entry.amount += amount
		entry.pos = pos
	else
		byKey[slot] = { kind = kind, pos = pos, amount = amount, part = part }
	end
end

-- Daño recibido por el jugador.
function CombatFeed.hurt(player: Player, amount: number)
	if amount > 0 then
		push(player, { k = "hurt", a = math.max(1, math.floor(amount + 0.5)) })
	end
end

-- XP de orbes que juntó el jugador (se suma en un solo número por envío).
function CombatFeed.xp(player: Player, pos: Vector3, amount: number)
	CombatFeed.dealt(player, "orbs", pos, amount, "xp")
end

-- Murió un enemigo: todos los que juegan ven la explosión (y suman al combo).
function CombatFeed.kill(players: { Player }, pos: Vector3, color: Color3, size: number, golden: boolean)
	for _, p in players do
		push(p, { k = "kill", p = pos, c = color, s = size, x = golden })
	end
end

-- Botín que cobró el jugador.
function CombatFeed.loot(player: Player, pos: Vector3, amounts: { [string]: number })
	if next(amounts) ~= nil then
		push(player, { k = "loot", p = pos, g = amounts })
	end
end

-- Arma los eventos de cada jugador (sin mandarlos). Sirve para probarlo.
function CombatFeed.collect(): { [Player]: { Event } }
	local out: { [Player]: { Event } } = {}
	for player, byKey in merged do
		for slot, entry in byKey do
			-- La quemadura espera a juntar al menos 1 punto
			if entry.kind ~= "burn" or entry.amount >= 1 then
				local list = out[player] or {}
				out[player] = list
				table.insert(list, {
					k = entry.kind,
					p = entry.pos,
					a = math.max(1, math.floor(entry.amount + 0.5)),
					i = entry.part,
				})
				byKey[slot] = nil
			end
		end
	end
	for player, list in direct do
		local into = out[player] or {}
		out[player] = into
		for _, e in list do
			table.insert(into, e)
		end
	end
	table.clear(direct)
	return out
end

-- Manda lo pendiente si pasó FlushInterval (llamar cada frame).
function CombatFeed.update(now: number)
	if now - lastFlush < Cfg.FlushInterval then
		return
	end
	lastFlush = now
	local events = CombatFeed.collect()
	local r = remote
	if not r then
		return
	end
	for player, list in events do
		if #list > 0 and player.Parent then
			r:FireClient(player, list)
		end
	end
end

-- Al terminar la partida o si se va el jugador.
function CombatFeed.clear(player: Player?)
	if player then
		merged[player] = nil
		direct[player] = nil
	else
		table.clear(merged)
		table.clear(direct)
	end
end

return CombatFeed
