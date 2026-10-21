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
	walkSpeed: number,
	dashCooldown: number,
	burnBonus: number,
	damage: number,
	attackInterval: number,
	maxHealth: number,
	frontArrows: number, -- flechas paralelas extra
	diagonalPairs: number, -- pares de flechas diagonales
	pierce: number, -- enemigos que atraviesa
	ricochet: number, -- rebotes
	burn: boolean,
	critChance: number,
	critMultiplier: number,
	pickupRadius: number, -- imán de orbes de XP
	-- Talentos permanentes (Shared/Talents.lua)
	goldBonus: number, -- oro extra del botín (0.1 = +10%)
	startChoices: number, -- habilidades gratis al empezar la partida
	rerolls: number, -- cambios de cartas que quedan en esta partida
	weapon: string, -- arma de la partida (Shared/Weapons.lua): "Bow" | "Sword" | "Fists"
	-- Habilidades de arco
	backArrows: number, -- flechas hacia atrás
	chargedEvery: number, -- cada cuántos disparos sale una flecha gigante (0 = nunca)
	farDamage: number, -- daño extra a enemigos lejanos (0.25 = +25%)
	arrowRain: boolean, -- lluvia de flechas cada tanto
	-- Habilidades de espada
	meleeArc: number, -- grados extra de arco
	meleeRange: number, -- studs extra de alcance
	whirlEvery: number, -- cada cuántos golpes gira 360° (0 = nunca)
	executeBonus: number, -- daño extra a enemigos con poca vida
	healOnKill: number, -- vida por enemigo muerto con un golpe
	judgment: boolean, -- espada gigante cada tanto
	-- Habilidades de puños
	comboStep: number, -- daño extra por golpe seguido (0.05 = +5%)
	uppercutEvery: number, -- cada cuántos golpes lanza y aturde (0 = nunca)
	thousandFists: boolean, -- ráfaga de golpes cada tanto
	stacks: { [string]: number }, -- skillId -> veces elegida
}

-- ALIVE: en pie (en la partida o en el lobby) · DOWNED: derribado, esperando rescate
-- ELIMINATED: se le acabó el tiempo de derribo; mira a un compañero hasta el descanso.
export type LifeState = "ALIVE" | "DOWNED" | "ELIMINATED"

export type State = {
	items: { [string]: number },
	nextStorm: number,
	dashReady: number,
	dashUntil: number,
	dashDirection: Vector3,
	dashOwned: boolean,
	stats: Stats,
	lastShot: number,
	-- Disparo manual (Config.Player.FireMode = "Manual"): lo manda el cliente y valida Combat
	grabbed: boolean, -- lo tiene agarrado un enemigo (Grab): no se mueve, no ataca ni hace dash
	grabImmuneUntil: number, -- después de soltarse no lo puede agarrar nadie hasta entonces (Grab)
	trigger: boolean, -- tiene apretado el botón de disparo
	fireQueued: boolean, -- hizo click durante la recarga: dispara apenas se pueda
	aimDir: Vector3?, -- hacia dónde apunta (plano, unitario)
	aimMsgs: number, -- mensajes en la ventana actual (límite de frecuencia)
	aimWindow: number,
	pendingOffers: number, -- niveles ganados todavía sin elegir
	currentOffer: { string }?, -- ids ofrecidos ahora mismo
	offerGolden: number, -- carta dorada de la oferta (índice; 0 = ninguna): da 2 niveles
	offerId: number,
	offerDeadline: number,
	life: LifeState,
	inMatch: boolean, -- participa de la partida en curso (si no, está en el lobby)
	kills: number,
	damageDealt: number,
	downs: number, -- veces que cayó
	revives: number, -- compañeros que revivió
	runLoot: { [string]: number }, -- botín juntado en esta partida (ya está en el perfil)
	lastHurt: number, -- os.clock() del último golpe recibido (pausa entre golpes)
	-- Habilidades por arma (Combat)
	attacks: number, -- ataques hechos en la partida (cada N: tiro cargado, torbellino, uppercut)
	combo: number, -- golpes seguidos (puños)
	lastHitAt: number, -- os.clock() del último golpe que pegó
	nextPower: number, -- próxima lluvia de flechas / juicio / ráfaga
	burstUntil: number, -- ráfaga de mil puños activa hasta
}

export type Target = { player: Player, root: BasePart, humanoid: Humanoid, state: State }

local states: { [Player]: State } = {}
local choosingPaused = false
local pausedRoots: { [BasePart]: boolean } = {}
function PlayerData.isPaused(): boolean return choosingPaused end
function PlayerData.setPaused(on: boolean)
	choosingPaused = on
	if on then
		for player, state in states do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if state.inMatch and root and pausedRoots[root] == nil then
				pausedRoots[root] = root.Anchored == true
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.Anchored = true
				state.dashUntil = 0
			end
		end
	else
		for root, wasAnchored in pausedRoots do
			if root.Parent then root.Anchored = wasAnchored end
		end
		table.clear(pausedRoots)
	end
end

function PlayerData.newStats(): Stats
	return {
		walkSpeed = PlayerCfg.WalkSpeed,
		dashCooldown = Config.Dash.Cooldown,
		burnBonus = 0,
		damage = Config.Projectile.Damage,
		attackInterval = PlayerCfg.AttackInterval,
		maxHealth = PlayerCfg.MaxHealth,
		frontArrows = 0,
		diagonalPairs = 0,
		pierce = 0,
		ricochet = 0,
		burn = false,
		critChance = PlayerCfg.CritChance,
		critMultiplier = PlayerCfg.CritMultiplier,
		pickupRadius = PlayerCfg.PickupRadius,
		goldBonus = 0,
		startChoices = 0,
		rerolls = 0,
		weapon = "Bow",
		backArrows = 0,
		chargedEvery = 0,
		farDamage = 0,
		arrowRain = false,
		meleeArc = 0,
		meleeRange = 0,
		whirlEvery = 0,
		executeBonus = 0,
		healOnKill = 0,
		judgment = false,
		comboStep = 0,
		uppercutEvery = 0,
		thousandFists = false,
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
	if state.life == "ALIVE" then humanoid.WalkSpeed = state.stats.walkSpeed end
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
	if on and not Config.Progression.ChoosingShield then return end
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
	PlayerData.setPaused(false)
	for _, state in states do
		table.clear(state.items)
		state.nextStorm = 0
		state.dashReady = 0
		state.dashUntil = 0
		state.dashOwned = false
		state.lastHurt = -math.huge
		state.lastShot = 0
		state.grabbed = false
		state.grabImmuneUntil = 0
		state.trigger = false
		state.fireQueued = false
		state.aimDir = nil
		state.attacks = 0
		state.combo = 0
		state.lastHitAt = 0
		state.nextPower = 0
		state.burstUntil = 0
		state.stats = PlayerData.newStats()
		state.pendingOffers = 0
		state.currentOffer = nil
		state.offerGolden = 0
		state.kills = 0
		state.damageDealt = 0
		state.downs = 0
		state.revives = 0
		table.clear(state.runLoot)
	end
end

-- onAdded: con cada jugador nuevo. onRemoving: justo antes de borrar su estado.
function PlayerData.init(onAdded: (Player) -> (), onRemoving: (Player) -> ())
	local function added(player: Player)
		states[player] = {
			items = {}, nextStorm = 0, dashReady = 0, dashUntil = 0, dashDirection = Vector3.zero, dashOwned = false,
			stats = PlayerData.newStats(),
			lastShot = 0,
			grabbed = false,
			grabImmuneUntil = 0,
			trigger = false,
			fireQueued = false,
			aimDir = nil,
			aimMsgs = 0,
			aimWindow = 0,
			attacks = 0,
			combo = 0,
			lastHitAt = 0,
			nextPower = 0,
			burstUntil = 0,
			pendingOffers = 0,
			currentOffer = nil,
			offerGolden = 0,
			offerId = 0,
			offerDeadline = 0,
			life = "ALIVE",
			inMatch = false,
			kills = 0,
			damageDealt = 0,
			downs = 0,
			revives = 0,
			runLoot = {},
			lastHurt = -math.huge,
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
