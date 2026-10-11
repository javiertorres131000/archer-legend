-- Config (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Config
-- Lo leen el servidor y los clientes. Números globales de balance.
-- Los enemigos, jefes y capítulos están en ServerScriptService > Server > Data.

local Config = {}

Config.Arena = {
	Size = Vector3.new(300, 1, 300), -- ancho x alto x largo del mapa (studs)
	WallHeight = 90, -- paredes invisibles en el borde (para no salirse por las montañas)
	SpawnMargin = 30, -- distancia mínima al borde para que aparezcan enemigos (las montañas)
}

-- Mapa abierto con relieve (MapBuilder.lua). Si en ServerStorage > Maps > <Id del capítulo> hay
-- un TerrainRegion llamado "Terrain" (y Models con decoración), se usa ese mapa hecho a mano.
Config.Map = {
	VoxelSize = 4, -- resolución del terreno (studs)
	SafeRadius = 30, -- centro casi plano donde se aparece
	HillHeight = 6, -- altura de las lomas suaves
	HillScale = 70, -- tamaño de las lomas (más = más anchas)
	Plateaus = 8, -- mesetas para subir
	PlateauHeight = { 8, 16 },
	PlateauRadius = { 14, 26 },
	RampLength = 24, -- largo de la rampa para subir a cada meseta
	EdgeWidth = 30, -- montañas del borde
	EdgeHeight = 34,
	Props = 120, -- decoración repartida por el mapa (árboles, rocas, ruinas...)
	Materials = {
		forest = { Top = Enum.Material.Grass, Under = Enum.Material.Ground, Cliff = Enum.Material.Rock },
		ruins = { Top = Enum.Material.Sandstone, Under = Enum.Material.Sandstone, Cliff = Enum.Material.Slate },
		fortress = { Top = Enum.Material.Basalt, Under = Enum.Material.Basalt, Cliff = Enum.Material.CrackedLava },
	},
}

Config.Player = {
	WalkSpeed = 20,
	MaxHealth = 100,
	AttackRange = 60, -- distancia máxima de auto-apuntado
	-- En primera persona solo se apunta a enemigos delante tuyo: ancho del cono en grados.
	-- (En modo TopDown se apunta a todo alrededor.)
	AimConeFirstPerson = 110,
	AttackInterval = 0.6, -- segundos entre disparos
	CritChance = 0.1, -- probabilidad de golpe crítico
	CritMultiplier = 2, -- daño del crítico
	PickupRadius = 14, -- radio del imán de orbes de XP (studs)
	SpawnInvulnerability = 2, -- segundos de escudo al aparecer
	-- Después de recibir un golpe, este tiempo no recibís otro (con hordas, evita que 10 enemigos
	-- te peguen en el mismo instante). 0 = sin pausa.
	HurtInvulnerability = 0.3,
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
	MaxAlive = 110, -- tope de enemigos vivos a la vez (rendimiento); las invocaciones no lo respetan
	-- Barras de vida sobre los enemigos: "Bosses" (solo jefes y dorados) o "All".
	-- Con hordas grandes, "All" pesa en celulares; el daño ya se ve con los números flotantes.
	HealthBars = "Bosses",
	ContactCooldown = 1, -- segundos entre golpes del mismo enemigo
	MinSpawnDistance = 32, -- no aparecen pegados a un jugador
	MaxSpawnDistance = 75, -- ni tan lejos que nunca lleguen (el mapa es grande)
	SeparationPadding = 0.5, -- espacio extra para que no se apilen
	DefaultTelegraph = 0.5, -- segundos de aviso si un ataque no indica otro
	DefaultRest = 0.6, -- pausa entre ataques si el enemigo no indica otra
}

-- Valores por defecto de los proyectiles enemigos (cada ataque puede cambiarlos)
Config.EnemyProjectile = {
	UseDangerColor = true, -- balas enemigas siempre rosa/rojo; false recupera colores por tipo
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
	HealthGrowth = 0.12, -- cada oleada los enemigos comunes tienen +20% de vida
	EnemyCountMultiplier = 10, -- más o menos enemigos por oleada en todos los capítulos (1 = original)
	-- Entre oleadas: con UseDoors el equipo camina hasta la puerta para pasar a la sala siguiente
	-- (y el mapa se vuelve a generar). Sin puertas (mapa abierto), la oleada siguiente arranca sola
	-- después de BreakTime segundos.
	UseDoors = false,
	BreakTime = 4,
}

-- Modo frenético: hordas, orbes de XP, cofres, enemigos dorados y "jugo" visual
Config.Frenzy = {
	-- Hordas
	SpawnIntervalMult = 0.25, -- multiplica el intervalo entre apariciones de cada capítulo (menos = más seguido)
	SpawnGroup = 5, -- enemigos que aparecen juntos en cada aparición
	EnemyHealthMult = 0.6, -- vida de los enemigos comunes (son muchos más: mueren más rápido)
	EnemyDamageMult = 0.5, -- daño de los enemigos comunes (son muchos más: cada uno pega menos)
	Knockback = 1.2, -- studs que retrocede un enemigo al recibir un flechazo (los jefes no)
	-- Enemigo dorado: raro, brilla, aguanta más y suelta muchísimo botín
	GoldenChance = 0.008, -- probabilidad por cada enemigo común que aparece
	GoldenHealthMult = 4,
	GoldenLootMult = 6,
	-- Orbes de XP: caen al morir y el imán los atrae (ver Orbs.lua)
	MaxOrbs = 200, -- si hay más, los más viejos se cobran solos
	-- Cofres: aparecen cada tantas muertes del equipo (ver Chests.lua)
	ChestEveryKills = 45,
	MaxChests = 2,
	ChestOpenRadius = 5,
	ChestGold = 40, -- por el multiplicador de botín del capítulo
	ChestGemChance = 0.5,
	ChestGivesSkill = false, -- abrirlo regala una habilidad a cada jugador
	-- Combo (cliente): muertes del equipo seguidas sin pasar más de esto entre una y otra
	ComboWindow = 2.5,
}

-- Mejora "Tormenta": rayos que caen solos sobre enemigos cercanos (ver Combat.lua)
Config.Lightning = {
	Interval = 3, -- segundos entre tandas de rayos
	DamageMult = 1.5, -- daño de cada rayo, sobre el daño de tus flechas
	Range = 40, -- solo cae sobre enemigos a esta distancia del jugador
	-- Cada copia de la mejora suma 1 rayo por tanda (cada rayo busca un enemigo distinto)
}

-- Mejora "Meteorito": cae sobre el grupo más denso de enemigos y daña en área (ver Combat.lua)
Config.Meteor = {
	Interval = 5, -- segundos entre tandas de meteoritos
	Count = 3, -- meteoritos por tanda (cada uno a un grupo distinto)
	DamageMult = 3, -- daño a cada enemigo del área, sobre el daño de tus flechas
	Radius = 8, -- radio de la explosión con 1 copia (studs)
	RadiusPerCopy = 3, -- cada copia extra agranda el radio esto
	Range = 45, -- solo apunta a enemigos a esta distancia del jugador
	FallTime = 0.8, -- segundos desde el aviso (círculo rojo) hasta que pega
}

-- Mejora "Veneno": las flechas envenenan; el veneno quita un % de la vida MÁXIMA por segundo
Config.Poison = {
	PercentPerCopy = 0.05, -- cada copia de la mejora: +5% de la vida máxima por segundo
	MaxPercent = 0.30, -- tope (6 copias)
	Duration = 3, -- segundos que dura; cada flecha que pega lo renueva
	BossMult = 0.1, -- jefes y mini-jefes reciben esta fracción (0.1 = 30% → 3% por segundo). 1 = igual que todos
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

Config.Dash = { Cooldown = 3.5, Duration = 0.2, Speed = 70 }

Config.Progression = {
	PauseWhileChoosing = true,
	ChoosingShield = true,
	-- XP para pasar del nivel N al N+1 = BaseXP + (N - 1) * XPGrowth
	BaseXP = 12,
	XPGrowth = 7,
	ChoiceTimeout = 30, -- segundos para elegir; después se elige una al azar
	ChoicesPerLevel = 3,
	RarityWeights = { Common = 55, Rare = 32, Epic = 13 },
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
	-- Calidad de efectos: "Auto" (baja en celulares), "High" o "Low".
	-- En baja: sin bloom ni rayos de sol, menos partículas y sin luces en los proyectiles.
	Quality = "Auto",
	ScreenShake = 1, -- intensidad del sacudón de cámara (0 = apagado)
	-- Iluminación de la arena (en el lobby queda la normal)
	ArenaClockTime = 13.5, -- hora del día (0 = medianoche, 12 = mediodía)
	ArenaAmbient = Color3.fromRGB(125, 125, 120),
	ArenaBrightness = 2.5,
	Bloom = { Intensity = 0.35, Size = 24, Threshold = 0.95 }, -- brillo suave: solo lo muy luminoso
	Saturation = 0.2,
	Contrast = 0.06,
	TintStrength = 0.06, -- cuánto se tiñe la luz con el color del capítulo (0 = nada)
	NeonStrips = false, -- líneas neón en las paredes de la arena
	Haze = 0.28, -- bruma a lo lejos (da profundidad al mapa grande; 0 = sin bruma)
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

-- Botín al matar enemigos (Loot.lua). Lo cobran TODOS los participantes (botín compartido,
-- así nadie le "roba" las muertes al compañero). Se suma al perfil en el momento.
-- Se multiplica por Rewards.LootMult del capítulo. Los invocados por jefes no dan botín.
Config.Loot = {
	GoldPerCost = 0.5, -- oro por cada punto de Cost del enemigo (EnemyTypes)
	GoldVariation = 0.5, -- ±50% al azar
	GemChance = 0.03, -- probabilidad de 1 gema por enemigo
	StoneChance = 0.02, -- probabilidad de 1 piedra de mejora por enemigo
	Boss = { Gold = 25, Gems = 3, Stones = 2 }, -- botín extra de jefes y mini-jefes
}

-- Números flotantes (CombatFeed.lua y CombatText.client.lua)
Config.CombatText = {
	FlushInterval = 0.1, -- el servidor junta los golpes y los manda cada esto (menos tráfico)
	Lifetime = 0.9, -- segundos que se ve cada número
	ShowTeammateDamage = false, -- true: también ves el daño que hacen tus compañeros
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
	ShowPerformance = false, -- FPS, peor frame, enemigos y proyectiles; sólo diagnóstico
	UnlockAllChapters = false, -- todos los capítulos elegibles desde el lobby
	StartWave = 1, -- oleada con la que arranca cada partida
	-- Solo en Studio (en el juego publicado no hacen nada):
	TestGems = 0, -- al entrar, si tenés menos gemas que esto te las completa (0 = apagado)
	PrintStats = true, -- al empezar la partida escribe en Output tus stats: base, +equipo, +talentos, +runas
}

return Config
