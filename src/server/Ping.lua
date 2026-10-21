--!strict
-- Ping (ModuleScript)
-- Ubicación: ServerScriptService > Server > Ping
-- Marcas para el cooperativo: apuntás y apretás la tecla de marcar (G / ruedita del mouse /
-- cruz arriba del joystick / botón MARCAR en el celular) y todo el equipo ve una marca con tu
-- color, a través de las paredes y con flecha en el borde de la pantalla si no la ve.
--   · Enemigo: si la mira pasa cerca de uno, lo marca y la marca lo sigue hasta que muere.
--   · Cofre: si la mira pasa cerca de un cofre.
--   · Lugar: si no, el punto del piso donde mirás ("¡Vamos acá!").
--   · Ayuda: si estás derribado o agarrado, marcar pide ayuda en tu posición.
-- El cliente solo manda desde dónde mira la cámara y hacia dónde (Remotes.PingRequest). El
-- servidor valida tipos, que estés en partida y no eliminado, la frecuencia (Config.Ping.Cooldown)
-- y que el origen esté cerca de tu personaje; él decide qué se marcó y se lo manda a los
-- participantes (Remotes.Ping): ("Add", marca) · ("Remove", id) · ("Clear").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local Enemies = require(script.Parent.Enemies)
local Chests = require(script.Parent.Chests)
local Ground = require(script.Parent.Ground)

local Cfg = Config.Ping

export type Kind = "Enemy" | "Chest" | "Ground" | "Help"

export type Mark = {
	id: number,
	userId: number,
	name: string, -- quién marcó
	kind: Kind,
	pos: Vector3,
	part: BasePart?, -- enemigo marcado (la marca lo sigue)
	label: string,
	slot: number, -- color del jugador (1..4, orden por UserId entre los participantes)
	duration: number,
}

type Active = { id: number, expires: number }

local Ping = {}

local remote: RemoteEvent? = nil
local nextId = 0
local lastPing: { [Player]: number } = {}
local active: { [Player]: { Active } } = {}

local function finite(v: Vector3): boolean
	for _, c in { v.X, v.Y, v.Z } do
		if c ~= c or math.abs(c) > 1e6 then
			return false
		end
	end
	return true
end

local function participants(): { Player }
	local list = {}
	for p, s in PlayerData.all() do
		if s.inMatch and p.Parent then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function send(...: any)
	local r = remote
	if not r then
		return
	end
	for _, p in participants() do
		r:FireClient(p, ...)
	end
end

-- Punto del piso donde pega el rayo (o el final del rayo apoyado en el piso). Devuelve también
-- a qué distancia del origen quedó (para no marcar enemigos tapados por una loma).
local function groundHit(from: Vector3, dir: Vector3): (Vector3, number)
	local half = Enemies.getHalf()
	local step = Cfg.GroundStep
	local t = step
	while t <= Cfg.MaxDistance do
		local p = from + dir * t
		if math.abs(p.X) > half.X or math.abs(p.Z) > half.Z then
			break -- se fue del mapa: queda en el borde
		end
		local y = Ground.y(p.X, p.Z)
		if p.Y <= y then
			return Vector3.new(p.X, y, p.Z), t
		end
		t += step
	end
	local stop = math.min(t, Cfg.MaxDistance)
	local edge = Enemies.clampFlat(from + dir * stop, 2)
	return Vector3.new(edge.X, Ground.y(edge.X, edge.Z), edge.Z), stop
end

-- Qué tan cerca de la mira está `center` (0 = justo en el centro, >1 = afuera); nil si atrás o lejos.
local function aimScore(from: Vector3, dir: Vector3, center: Vector3, radius: number, maxT: number): number?
	local v = center - from
	local t = v:Dot(dir)
	if t <= 0 or t > maxT then
		return nil
	end
	local perp = (v - dir * t).Magnitude
	local allowed = radius + Cfg.AimAssist + t * Cfg.AimAssistPerStud
	if perp > allowed then
		return nil
	end
	return perp / allowed + 0.2 * t / Cfg.MaxDistance
end

-- Decide qué marcó el jugador mirando desde `from` hacia `dir` (unitario).
function Ping.resolve(from: Vector3, dir: Vector3): (Kind, Vector3, BasePart?, string)
	local floor, floorT = groundHit(from, dir)
	local maxT = math.min(Cfg.MaxDistance, floorT + 3) -- lo que está detrás de una loma no se ve

	local bestEnemy: any = nil
	local bestScore = math.huge
	for _, e in Enemies.list do
		if e.alive and not e.hidden then
			local score = aimScore(from, dir, e.part.Position, math.max(e.radius, e.height / 2), maxT)
			if score and score < bestScore then
				bestEnemy, bestScore = e, score
			end
		end
	end
	if bestEnemy then
		local name = (bestEnemy.def and bestEnemy.def.Name) or bestEnemy.typeId
		local label = if bestEnemy.isBoss
			then "¡JEFE! " .. name
			elseif bestEnemy.golden then "★ " .. name .. " dorado"
			else name
		return "Enemy", bestEnemy.part.Position, bestEnemy.part, label
	end

	local bestChest: Vector3? = nil
	bestScore = math.huge
	for _, pos in Chests.positions() do
		local score = aimScore(from, dir, pos, Cfg.ChestRadius, maxT)
		if score and score < bestScore then
			bestChest, bestScore = pos, score
		end
	end
	if bestChest then
		return "Chest", bestChest, nil, "Cofre"
	end
	return "Ground", floor, nil, "¡Vamos acá!"
end

local function slotOf(player: Player): number
	for i, p in participants() do
		if p == player then
			return i
		end
	end
	return 1
end

-- Pedido del cliente. Devuelve la marca creada (o nil si se descartó).
function Ping.request(player: Player, origin: any, dir: any): Mark?
	if not Cfg.Enabled or typeof(dir) ~= "Vector3" or not finite(dir) then
		return nil
	end
	local state = PlayerData.get(player)
	if not state or not state.inMatch or state.life == "ELIMINATED" or PlayerData.isPaused() then
		return nil
	end
	local now = os.clock()
	if now - (lastPing[player] or -math.huge) < Cfg.Cooldown then
		return nil
	end
	local character = player.Character
	local root = (character and character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then
		return nil
	end

	local kind: Kind, pos: Vector3, part: BasePart?, label: string
	if state.life == "DOWNED" or state.grabbed then
		kind, pos, part, label = "Help", root.Position, nil, "¡AYUDA!"
	else
		local mag = dir.Magnitude
		if mag < 0.5 or mag > 1.5 then
			return nil
		end
		local unit = dir / mag
		local head = root.Position + Vector3.new(0, 1.5, 0)
		local from = head
		if typeof(origin) == "Vector3" and finite(origin) and (origin - head).Magnitude <= Cfg.OriginSlack then
			from = origin -- la cámara (tercera persona o cenital) mira desde más atrás
		end
		kind, pos, part, label = Ping.resolve(from, unit)
	end
	lastPing[player] = now

	-- Tope de marcas vivas por jugador: la más vieja se borra
	local mine = active[player] or {}
	active[player] = mine
	for i = #mine, 1, -1 do
		if mine[i].expires <= now then
			table.remove(mine, i)
		end
	end
	while #mine >= Cfg.MaxPerPlayer do
		local old = table.remove(mine, 1) :: Active
		send("Remove", old.id)
	end

	nextId += 1
	local duration = if kind == "Enemy" then Cfg.EnemyDuration elseif kind == "Help" then Cfg.HelpDuration else Cfg.Duration
	local mark: Mark = {
		id = nextId,
		userId = player.UserId,
		name = player.DisplayName,
		kind = kind,
		pos = pos,
		part = part,
		label = label,
		slot = slotOf(player),
		duration = duration,
	}
	table.insert(mine, { id = mark.id, expires = now + duration })
	send("Add", mark)
	return mark
end

-- Fin de partida: se borran todas
function Ping.clear()
	table.clear(lastPing)
	table.clear(active)
	local r = remote
	if r then
		r:FireAllClients("Clear")
	end
end

function Ping.init(remotes)
	remote = remotes.Ping
	remotes.PingRequest.OnServerEvent:Connect(function(player: Player, origin: any, dir: any)
		Ping.request(player, origin, dir)
	end)
end

return Ping
