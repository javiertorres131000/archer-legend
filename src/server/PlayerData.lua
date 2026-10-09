-- PlayerData (ModuleScript)
-- Ubicación: ServerScriptService > Server > PlayerData
-- Estado de cada jugador durante la partida: stats (modificadas por habilidades),
-- cadencia de disparo, oferta de habilidades abierta y estadísticas.
-- El ciclo de vida (vivo, derribado, eliminado, espectador) lo maneja PlayerLife.

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerCfg = Config.Player

local PlayerData = {}

export type Stats = {
	damage: number,
	attackInterval: number,
	maxHealth: number,
	frontArrows: number, -- flechas paralelas extra
	diagonalPairs: number, -- pares de flechas diagonales
	pierce: number, -- enemigos que atraviesa
	ricochet: number, -- rebotes
	burn: boolean,
	stacks: { [string]: number }, -- skillId -> veces elegida
}

-- ALIVE: en pie (en la partida o en el lobby) · DOWNED: derribado, esperando rescate
-- ELIMINATED: se le acabó el tiempo de derribo; mira a un compañero hasta el descanso.
export type LifeState = "ALIVE" | "DOWNED" | "ELIMINATED"

export type State = {
	stats: Stats,
	lastShot: number,
	pendingOffers: number, -- niveles ganados todavía sin elegir
	currentOffer: { string }?, -- ids ofrecidos ahora mismo
	offerId: number,
	offerDeadline: number,
	life: LifeState,
	inMatch: boolean, -- participa de la partida en curso (si no, está en el lobby)
	kills: number,
	damageDealt: number,
	downs: number, -- veces que cayó
	revives: number, -- compañeros que revivió
}

export type Target = { player: Player, root: BasePart, humanoid: Humanoid, state: State }

local states: { [Player]: State } = {}

function PlayerData.newStats(): Stats
	return {
		damage = Config.Projectile.Damage,
		attackInterval = PlayerCfg.AttackInterval,
		maxHealth = PlayerCfg.MaxHealth,
		frontArrows = 0,
		diagonalPairs = 0,
		pierce = 0,
		ricochet = 0,
		burn = false,
		stacks = {},
	}
end

function PlayerData.get(player: Player): State?
	return states[player]
end

function PlayerData.all(): { [Player]: State }
	return states
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Aplica las stats actuales al personaje (vida máxima). heal = cuánto curar además.
function PlayerData.applyToCharacter(player: Player, heal: number?)
	local state = states[player]
	local humanoid = getHumanoid(player)
	if not state or not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.MaxHealth = state.stats.maxHealth
	-- Un derribado no se cura con habilidades: solo vuelve si lo reviven
	if heal and heal > 0 and state.life == "ALIVE" then
		humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)
	end
end

-- Escudo visible mientras el jugador elige habilidad.
-- Mientras haya un ForceField en el personaje, no recibe daño (PlayerLife.damage lo respeta).
function PlayerData.setChoosingShield(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("ChoiceShield")
	if on and not existing then
		local shield = Instance.new("ForceField")
		shield.Name = "ChoiceShield"
		shield.Parent = character
	elseif not on and existing then
		existing:Destroy()
	end
end

-- Nueva partida: stats y estadísticas a cero. (La aparición la hace PlayerLife.beginMatch.)
function PlayerData.resetStats()
	for _, state in states do
		state.stats = PlayerData.newStats()
		state.pendingOffers = 0
		state.currentOffer = nil
		state.kills = 0
		state.damageDealt = 0
		state.downs = 0
		state.revives = 0
	end
end

-- onAdded: con cada jugador nuevo. onRemoving: justo antes de borrar su estado.
function PlayerData.init(onAdded: (Player) -> (), onRemoving: (Player) -> ())
	local function added(player: Player)
		states[player] = {
			stats = PlayerData.newStats(),
			lastShot = 0,
			pendingOffers = 0,
			currentOffer = nil,
			offerId = 0,
			offerDeadline = 0,
			life = "ALIVE",
			inMatch = false,
			kills = 0,
			damageDealt = 0,
			downs = 0,
			revives = 0,
		}
		onAdded(player)
	end

	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		onRemoving(player)
		states[player] = nil
	end)
end

-- Jugadores que se pueden atacar y que atacan: participantes ALIVE con personaje.
function PlayerData.getAliveTargets(): { Target }
	local list = {}
	for player, state in states do
		if state.life ~= "ALIVE" or not state.inMatch then
			continue
		end
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				table.insert(list, { player = player, root = root, humanoid = humanoid, state = state })
			end
		end
	end
	return list
end

-- Vector en el plano XZ (el juego es 2D visto desde arriba).
function PlayerData.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

return PlayerData
