local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- Config (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Config
-- Lo leen el servidor y los clientes. Números globales de balance.
-- Los enemigos, jefes y capítulos están en ServerScriptService > Server > Data.

local Config = {}

Config.Arena = {
	Size = Vector3.new(120, 1, 120), -- ancho x alto x largo del piso (studs)
	WallHeight = 8,
	SpawnMargin = 6, -- distancia mínima a las paredes para spawnear enemigos
}

Config.Player = {
	WalkSpeed = 20,
	MaxHealth = 100,
	AttackRange = 60, -- distancia máxima de auto-apuntado
	-- En primera persona solo se apunta a enemigos delante tuyo: ancho del cono en grados.
	-- (En modo TopDown se apunta a todo alrededor.)
	AimConeFirstPerson = 110,
	AttackInterval = 0.6, -- segundos entre disparos
	StillThreshold = 1, -- velocidad horizontal debajo de la cual estás "quieto"
	SpawnInvulnerability = 2, -- segundos de escudo al aparecer
}

Config.Projectile = {
	Speed = 90, -- studs por segundo
	Damage = 25,
	Lifetime = 1.2, -- segundos antes de desaparecer
	Radius = 0.6, -- radio de impacto
	FrontSpacing = 1.2, -- separación entre flechas paralelas (Flecha frontal)
	DiagonalAngles = { 30, 55 }, -- grados de cada par de Flechas diagonales
	RicochetRange = 25, -- distancia máxima para rebotar a otro enemigo
	BurnFraction = 0.3, -- Flechas de fuego: % del daño por segundo
	BurnDuration = 3,
}

-- Reglas comunes a todos los enemigos
Config.Enemy = {
	MaxAlive = 25, -- tope de enemigos vivos a la vez (rendimiento); las invocaciones no lo respetan
	ContactCooldown = 1, -- segundos entre golpes del mismo enemigo
	MinSpawnDistance = 30, -- no aparecen pegados a un jugador
	SeparationPadding = 0.5, -- espacio extra para que no se apilen
	DefaultTelegraph = 0.5, -- segundos de aviso si un ataque no indica otro
	DefaultRest = 0.6, -- pausa entre ataques si el enemigo no indica otra
}

-- Valores por defecto de los proyectiles enemigos (cada ataque puede cambiarlos)
Config.EnemyProjectile = {
	Speed = 30,
	Damage = 10,
	Radius = 0.7, -- radio de impacto
	Size = 1.4, -- diámetro de la bola (visual)
	Lifetime = 3,
	Color = Color3.fromRGB(255, 60, 110),
	PlayerHitRadius = 1.5, -- "radio" del jugador para los impactos
}

-- Avisos en el piso y zonas peligrosas
Config.Hazards = {
	WarningColor = Color3.fromRGB(255, 50, 50),
	MarkerColor = Color3.fromRGB(170, 90, 255), -- teletransportes y apariciones (no hacen daño)
	ZoneTick = 0.25, -- cada cuánto dañan las zonas (segundos)
}

Config.Waves = {
	HealthGrowth = 0.12, -- cada oleada los enemigos comunes tienen +12% de vida
	BreakTime = 4, -- segundos de descanso entre oleadas (los caídos reviven acá)
}

-- Cooperativo: derribo, rescate y dificultad según la cantidad de jugadores
Config.Coop = {
	DownedTime = 15, -- segundos derribado antes de quedar eliminado
	ReviveTime = 3, -- segundos que hay que mantener la interacción para revivir
	ReviveRadius = 8, -- distancia máxima entre rescatador y derribado (studs)
	ReviveTolerance = 2, -- margen extra que acepta el servidor (lag)
	ReviveHealthFraction = 0.4, -- vida con la que vuelve (fracción de la máxima)
	ReviveInvulnerability = 2, -- segundos de escudo después de revivir
	PauseTimerWhileReviving = true, -- el reloj de derribo se frena mientras lo reviven
	DownedWalkSpeed = 0,
	-- Se fija al empezar cada oleada según los participantes de la partida (1 a 4).
	--   Health: vida de los enemigos · Count: cantidad de enemigos · XP: XP necesaria por nivel
	-- La velocidad y el daño de los enemigos no se escalan.
	Scaling = {
		{ Health = 1.0, Count = 1.0, XP = 1.0 },
		{ Health = 1.5, Count = 1.4, XP = 1.4 },
		{ Health = 2.0, Count = 1.75, XP = 1.75 },
		{ Health = 2.5, Count = 2.1, XP = 2.1 },
	},
}

Config.Progression = {
	-- XP para pasar del nivel N al N+1 = BaseXP + (N - 1) * XPGrowth
	BaseXP = 5,
	XPGrowth = 3,
	ChoiceTimeout = 12, -- segundos para elegir; después se elige una al azar
	ChoicesPerLevel = 3,
	RarityWeights = { Common = 60, Rare = 30, Epic = 10 },
}

-- Lobby y ciclo de partida (MatchManager)
Config.Match = {
	MaxPartySize = 4, -- jugadores por partida (configurá también Max Players = 4 en Game Settings)
	CountdownTime = 5, -- segundos de cuenta regresiva cuando todos están listos
	ResultsTime = 15, -- segundos de resultados antes de volver solos al lobby
	MinResultsTime = 2, -- "Volver al lobby" no responde antes de esto (evita doble clic)
	ReturnDelay = 1, -- segundos de pantalla de transición al volver
	RequestCooldown = 0.25, -- tiempo mínimo entre peticiones de un mismo jugador
}

-- Lobby físico: lejos de la arena para que nunca se vean
Config.Lobby = {
	Center = Vector3.new(0, 0, 400),
	Size = Vector3.new(90, 1, 90),
}

Config.UI = {
	GameTitle = "ARQUERO COOP",
	Subtitle = "Roguelite cooperativo",
}

Config.Camera = {
	-- "FirstPerson": en la arena ves por los ojos de tu personaje (el lobby sigue en tercera persona).
	-- "TopDown": la cámara cenital original, desde arriba.
	Mode = "FirstPerson",
	FirstPersonFieldOfView = 80,
	LobbyFieldOfView = 70,
	-- Cámara cenital (modo TopDown, y para mirar a un compañero cuando quedás eliminado)
	Height = 55,
	Back = 25,
	FieldOfView = 45,
}

-- Para probar. Dejalo en false y 1 para jugar normal.
Config.Debug = {
	UnlockAllChapters = false, -- todos los capítulos elegibles desde el lobby
	StartWave = 1, -- oleada con la que arranca cada partida
}

return Config
