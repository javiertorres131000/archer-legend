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
	-- Modo de apuntado (cada jugador lo cambia con AimToggleKeys):
	--   "Auto"   → elige solo al enemigo más cercano a tiro (en primera persona, dentro del cono)
	--   "Manual" → dispara hacia donde mirás (la mira), haya o no un enemigo ahí
	-- En los dos, solo dispara quieto y mientras queden enemigos.
	DefaultAimMode = "Auto",
	AimToggleKeys = { Enum.KeyCode.Q, Enum.KeyCode.DPadUp }, -- teclado / joystick
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
	MaxAlive = 35, -- tope de enemigos vivos a la vez (rendimiento); las invocaciones no lo respetan
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
	EnemyCountMultiplier = 1.5, -- más o menos enemigos por oleada en todos los capítulos (1 = original)
	-- Entre oleadas: con UseDoors el equipo camina hasta la puerta para pasar a la sala siguiente.
	-- Sin puertas, la oleada siguiente arranca sola después de BreakTime segundos.
	UseDoors = true,
	BreakTime = 4,
}

-- Salas: cada oleada se juega en una sala con otra decoración (ver Arena.lua)
Config.Rooms = {
	DoorRadius = 7, -- tamaño de la zona dorada frente a la puerta
	DoorTimeout = 40, -- segundos máximos esperando a que entren todos; después pasan igual
	EnterDelay = 1.2, -- segundos entre llegar a la sala nueva y que empiece la oleada
	EntranceDistance = 10, -- distancia de la entrada (sur) a la pared
	PropsPerRoom = 16, -- decoración generada por código (si no hay salas modeladas)
	PropBand = 9, -- la decoración va en esta franja pegada a las paredes
	FloorMaterials = {
		forest = Enum.Material.Grass,
		ruins = Enum.Material.Cobblestone,
		fortress = Enum.Material.Basalt,
	},
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

-- Efectos de pantalla (cliente, solo visuales): alerta de amenazas, golpe y sangre
Config.Effects = {
	ThreatEdgeGlow = 0.75, -- qué tan fuerte brilla el borde de la pantalla del lado de la amenaza (0 a 1)
	HitFlash = 0.55, -- rojo mínimo de la pantalla al recibir un golpe (0 a 1)
	HitFlashPerDamage = 2.5, -- rojo extra según la vida que te sacó (golpe del 20% = +0.5)
	HitFlashFade = 3, -- qué tan rápido se va el rojo del golpe (más = más rápido)
	BloodStartsAt = 0.8, -- la sangre en los bordes aparece con menos de este % de vida
	BloodMax = 0.9, -- opacidad máxima de la sangre (con la vida casi en 0)
	HeartbeatBelow = 0.3, -- con menos de este % de vida, la sangre late
}

Config.Camera = {
	-- "FirstPerson": en la arena ves por los ojos de tu personaje (el lobby sigue en tercera persona).
	-- "TopDown": la cámara cenital original, desde arriba.
	Mode = "FirstPerson",
	-- En modo "FirstPerson" cada jugador puede alternar la vista de la arena con la tecla:
	--   "FirstPerson" → por los ojos del personaje
	--   "ThirdPerson" → detrás del hombro; el personaje sigue girando hacia donde mirás
	DefaultView = "FirstPerson", -- con cuál arranca
	ToggleKeys = { Enum.KeyCode.V, Enum.KeyCode.ButtonR3 }, -- teclado / joystick
	ThirdPersonDistance = 12, -- distancia inicial de la cámara (se puede acercar/alejar con la rueda)
	ThirdPersonMinZoom = 6,
	ThirdPersonMaxZoom = 22,
	ThirdPersonShoulder = Vector3.new(1.75, 0.5, 0), -- corrimiento al costado para no tapar la mira
	ThirdPersonFieldOfView = 75,
	FirstPersonFieldOfView = 80,
	LobbyFieldOfView = 70,
	-- Alerta de amenazas fuera de la vista (primera persona): flechitas rojas alrededor de la mira
	ThreatRadius = 20, -- enemigos más cerca que esto y fuera de la vista
	ThreatProjectileRadius = 14, -- proyectiles enemigos más cerca que esto
	ThreatViewAngle = 50, -- grados desde el centro de la mira en que algo ya "se ve"
	-- Cámara cenital (modo TopDown, y para mirar a un compañero cuando quedás eliminado)
	Height = 55,
	Back = 25,
	FieldOfView = 45,
}

-- Perfil guardado con DataStore (Profiles.lua)
-- En Studio solo guarda si el juego está publicado y en Game Settings › Security está activado
-- "Enable Studio Access to API Services". Si no, se juega igual pero sin guardar (aviso en el lobby).
Config.Profiles = {
	Enabled = true, -- false: nunca usa DataStore (todo queda en memoria)
	StoreName = "PlayerProfiles_v1", -- cambiarlo empieza perfiles nuevos (no borra los viejos)
	AutoSaveInterval = 60, -- segundos entre guardados automáticos
	Retries = 3, -- intentos por cada lectura/escritura
	RetryDelay = 1, -- espera antes del 2.º intento (se duplica en cada uno)
	LockExpire = 300, -- un bloqueo de sesión más viejo que esto se considera abandonado
	LockRetries = 5, -- veces que se espera a que otro servidor suelte el perfil antes de tomarlo
	LockRetryDelay = 4,
	CloseTimeout = 25, -- al cerrar el servidor, cuánto esperar a que terminen los guardados
}

-- Para probar. Dejalo en false y 1 para jugar normal.
Config.Debug = {
	UnlockAllChapters = false, -- todos los capítulos elegibles desde el lobby
	StartWave = 1, -- oleada con la que arranca cada partida
}

return Config
