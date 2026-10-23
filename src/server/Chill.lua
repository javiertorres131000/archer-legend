--!strict
-- Chill (ModuleScript)
-- Ubicación: ServerScriptService > Server > Chill
-- Frío de los mapas de hielo (Config.Chill). Cada golpe que recibe un jugador suma puntos de frío
-- (PlayerLife.damage llama a onHurt) y la ventisca/carámbanos suman más (MapEvents). Cada punto
-- baja la velocidad de caminar; con el máximo queda congelado un momento. Se pierde de a un punto,
-- más rápido junto a una fogata. Es del servidor: escribe Humanoid.WalkSpeed y publica en el
-- jugador los atributos "Chill" (0 a 1) y "Frozen" (bool) para los efectos del cliente (IceWorld).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)

local Chill = {}

type State = {
	stacks: number,
	decayAt: number,
	frozenUntil: number,
	immuneUntil: number,
	slowed: boolean, -- si la última vez le bajamos la velocidad (para devolvérsela una sola vez)
	shown: number, -- último "Chill" publicado
	frozenShown: boolean,
}

local active = false
local warmSpots: { Vector3 } = {}
local data: { [Player]: State } = setmetatable({}, { __mode = "k" }) :: any
local clock = 0

local function cfg(): any
	return (Config :: any).Chill
end

local function get(player: Player): State
	local s = data[player]
	if not s then
		s = { stacks = 0, decayAt = 0, frozenUntil = 0, immuneUntil = 0, slowed = false, shown = 0, frozenShown = false }
		data[player] = s
	end
	return s
end

-- ¿El tema del mapa tiene frío?
function Chill.setTheme(theme: string?)
	local c = cfg()
	local on = c ~= nil and theme ~= nil and c.Themes[theme] == true
	if not on and active then
		Chill.clear()
	end
	active = on
end

function Chill.isActive(): boolean
	return active
end

-- Fogatas: cerca de estas posiciones se va el frío (MapEvents las pone)
function Chill.setWarmSpots(list: { Vector3 })
	warmSpots = list
end

function Chill.isWarm(pos: Vector3): boolean
	local c = (Config :: any).MapEvents and (Config :: any).MapEvents.glacier
	local r = if c and c.Campfires then c.Campfires.WarmRadius else 10
	for _, p in warmSpots do
		local d = Vector3.new(pos.X - p.X, 0, pos.Z - p.Z)
		if d.Magnitude <= r then
			return true
		end
	end
	return false
end

-- Suma frío. Con el máximo (y sin inmunidad) congela.
function Chill.add(player: Player, amount: number)
	local c = cfg()
	if not active or not c or amount <= 0 then
		return
	end
	local s = get(player)
	if clock < s.frozenUntil or clock < s.immuneUntil then
		return
	end
	s.stacks = math.min(c.MaxStacks, s.stacks + amount)
	s.decayAt = clock + c.DecayEvery
	if s.stacks >= c.MaxStacks then
		s.frozenUntil = clock + c.FreezeTime
		s.immuneUntil = s.frozenUntil + c.ImmuneAfterFreeze
		s.stacks = 0
	end
end

function Chill.onHurt(player: Player)
	local c = cfg()
	if c then
		Chill.add(player, c.PerHit)
	end
end

function Chill.stacks(player: Player): number
	local s = data[player]
	return if s then s.stacks else 0
end

function Chill.isFrozen(player: Player): boolean
	local s = data[player]
	return s ~= nil and clock < s.frozenUntil
end

local function publish(player: Player, s: State, value: number, frozen: boolean)
	if math.abs(s.shown - value) > 0.001 then
		s.shown = value
		player:SetAttribute("Chill", if value > 0 then value else nil)
	end
	if s.frozenShown ~= frozen then
		s.frozenShown = frozen
		player:SetAttribute("Frozen", if frozen then true else nil)
	end
end

function Chill.update(dt: number, targets: { PlayerData.Target })
	clock += dt
	local c = cfg()
	if not active or not c then
		return
	end
	for _, t in targets do
		local s = get(t.player)
		local warm = Chill.isWarm(t.root.Position)
		if s.stacks > 0 and clock >= s.decayAt then
			s.stacks -= 1
			s.decayAt = clock + (if warm then c.WarmDecayEvery else c.DecayEvery)
		elseif warm and s.stacks > 0 then
			s.decayAt = math.min(s.decayAt, clock + c.WarmDecayEvery)
		end
		local frozen = clock < s.frozenUntil
		local mult = if frozen then 0 else 1 - s.stacks * c.SlowPerStack
		local alive = t.state.life == "ALIVE"
		if alive and mult < 1 then
			local want = t.state.stats.walkSpeed * mult
			if math.abs(t.humanoid.WalkSpeed - want) > 0.05 then
				t.humanoid.WalkSpeed = want
			end
			s.slowed = true
		elseif s.slowed then
			s.slowed = false
			if alive then
				t.humanoid.WalkSpeed = t.state.stats.walkSpeed
			end
		end
		publish(t.player, s, s.stacks / c.MaxStacks, frozen)
	end
end

-- Fin del mapa o de la partida: devuelve la velocidad y borra los atributos.
function Chill.clear()
	for player, s in data do
		if player.Parent then
			player:SetAttribute("Chill", nil)
			player:SetAttribute("Frozen", nil)
			if s.slowed then
				local state = PlayerData.get(player)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if state and humanoid and state.life == "ALIVE" then
					humanoid.WalkSpeed = state.stats.walkSpeed
				end
			end
		end
	end
	table.clear(data)
	table.clear(warmSpots)
end

function Chill.onPlayerRemoving(player: Player)
	data[player] = nil
end

return Chill
