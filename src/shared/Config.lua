-- Config (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Config
-- Lo leen el servidor y los clientes. Números globales de balance.
-- Los enemigos, jefes y capítulos están en ServerScriptService > Server > Data.

local Config = {}

Config.Arena = {
	Size = Vector3.new(300, 1, 300), -- ancho x alto x largo del mapa (studs)
	WallHeight = 260, -- paredes invisibles en el borde (para no salirse por las montañas)
	WallThickness = 10, -- gruesas: ni el dash ni un salto rápido las atraviesan
	-- Red de seguridad (Arena.keepInside): si alguien igual queda afuera del borde o cae debajo
	-- del piso, vuelve adentro, apoyado en el terreno y a esta distancia del borde.
	ReturnMargin = 40,
	FallBelow = 25, -- studs por debajo del piso que cuentan como "se cayó"
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
	-- Largo del pasto animado del terreno (0.1 a 1; Roblox trae 1). Más bajo = se ve mejor el piso
	-- y los enemigos chicos. Solo se ve si el Terreno tiene "Decoration" activado en Studio.
	GrassLength = 0.35,
	Materials = {
		forest = { Top = Enum.Material.Grass, Under = Enum.Material.Ground, Cliff = Enum.Material.Rock },
		ruins = { Top = Enum.Material.Sandstone, Under = Enum.Material.Sandstone, Cliff = Enum.Material.Slate },
		fortress = { Top = Enum.Material.Basalt, Under = Enum.Material.Basalt, Cliff = Enum.Material.CrackedLava },
		glacier = { Top = Enum.Material.Snow, Under = Enum.Material.Glacier, Cliff = Enum.Material.Ice },
		desert = { Top = Enum.Material.Sand, Under = Enum.Material.Sandstone, Cliff = Enum.Material.Sandstone },
	},
}

Config.Player = {
	WalkSpeed = 20,
	MaxHealth = 100,
	-- Cómo se ataca: "Manual" = click (o R2 / botón ATACAR en el celular) y apuntás vos con la
	-- mira; mantener apretado sigue atacando. "Auto" = dispara solo al enemigo más cercano.
	FireMode = "Manual",
	FireMessagesPerSecond = 30, -- tope de mensajes de apuntado por jugador (anti-spam)
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
	MinSpawnDistance = 26, -- no aparecen pegados a un jugador
	MaxSpawnDistance = 50, -- ni tan lejos que haya que salir a buscarlos
	-- Que todos vengan a vos (Enemies.update / EnemyAI):
	ChaseDistance = 40, -- más lejos que esto, cualquiera que se mueva va directo al jugador más cercano
	CatchUpSpeed = 14, -- velocidad mínima mientras se acerca desde lejos
	-- Rodear en vez de hacer fila: cada enemigo que persigue se acerca en curva, desviado hasta
	-- FlankAngle grados (el suyo, al azar). Desde FlankFar studs tiene el desvío completo y se va
	-- enderezando hasta ir directo a menos de FlankNear. Así llegan por todos los costados.
	FlankAngle = 50,
	FlankFar = 35,
	FlankNear = 12,
	LeashDistance = 75, -- más lejos que esto durante LeashTime: reaparece cerca del equipo
	StillLeashDistance = 45, -- lo mismo para los quietos (plantas, torretas), que nunca caminan
	LeashTime = 3,
	-- Aspecto (EnemyVisuals): modelos en ServerStorage > EnemyModels > <Id del tipo>
	Models = true,
	ModelsFolder = "EnemyModels",
	ModelMinHeight = 5, -- alto mínimo de los modelos (studs): los enemigos chicos no quedan bajo el pasto
	-- Voladores (enemigos con Float): suben y bajan suave en el aire (cada uno a su ritmo)
	FlyBob = 0.6, -- studs de vaivén para arriba y para abajo
	FlyBobSpeed = 2.2, -- qué tan rápido (radianes por segundo)
	-- Aleteo (EnemyAnimator, en el cliente): las piezas de un modelo cuyo grupo se llama
	-- "left wing" / "right wing" (o tiene "wing" en el nombre) aletean desde su unión con el cuerpo.
	WingFlapAngle = 35, -- grados de aleteo hacia cada lado
	WingFlapSpeed = 14, -- velocidad del aleteo (radianes por segundo, ~2 aleteos por segundo)
	AnimateDistance = 150, -- más lejos que esto no se anima (rendimiento)
	-- Caminar (modelos con piernas "left leg"/"right leg" y Gait = "Walk")
	WalkSwing = 38, -- grados que se abre cada pierna a velocidad normal
	WalkStride = 0.9, -- radianes de paso por stud recorrido (más = pasos más cortos y rápidos)
	-- Saltitos (slimes, Gait = "Hop")
	HopTime = 0.42, -- segundos de cada salto
	HopHeight = 0.45, -- altura del salto, en alturas del modelo
	HopSquash = 0.3, -- cuánto se aplasta y estira (0.3 = 30%)
	ModelTint = 0.45, -- cuánto se tiñe el modelo con el color de su enemigo (0 = nada, 1 = todo)
	Eyes = true, -- ojos en las figuras que no tienen modelo
	-- Indicador brillante arriba de cada enemigo (EnemyMarkers, en el cliente): se ve a través de
	-- las paredes y de lejos. Cuando quedan pocos, se agranda y late para encontrar al último.
	Markers = true,
	MarkerSize = 14, -- píxeles
	MarkerFewLeft = 10, -- con esta cantidad o menos por matar, se agrandan
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

-- Mecánicas propias de cada mapa (Server/MapEvents), por tema del capítulo. Pasan solo durante
-- las oleadas y dañan a jugadores Y enemigos. Daño a enemigos: fracción de su vida máxima
-- (EnemyFrac; los jefes, BossFrac).
Config.MapEvents = {
	forest = {
		FirstDelay = 6, -- segundos de respiro al empezar cada oleada
		LavaVents = { -- grietas de lava que erupcionan cerca de los jugadores
			Every = { 9, 13 },
			Count = 2, -- +1 con 3 o más jugadores
			Offset = { 3, 12 }, -- distancia al jugador elegido
			Radius = 9,
			Warn = 1.8, -- segundos de aviso (círculo que se llena)
			Damage = 18, -- a jugadores, al erupcionar
			FireTime = 4, -- fuego que queda
			FireDps = 8,
			EnemyFrac = 0.45,
			EnemyBurnFrac = 0.08, -- quemadura por segundo mientras dura el fuego
			BossFrac = 0.03,
		},
		FallingTrees = { -- árboles calcinados que caen sobre la pelea
			Every = { 15, 22 },
			Reach = 55, -- solo árboles a esta distancia de algún jugador
			Warn = 2.2,
			FallTime = 0.55,
			Width = 8,
			MaxLength = 34,
			Damage = 32,
			EnemyFrac = 1.2, -- aplasta a casi todo lo común
			BossFrac = 0.08,
			LyingTime = 7, -- queda tirado y después desaparece
		},
	},
}

Config.Waves = {
	HealthGrowth = 0.12, -- cada oleada los enemigos comunes tienen +20% de vida
	EnemyCountMultiplier = 4, -- más o menos enemigos por oleada en todos los capítulos (1 = original)
	-- Menos bichos pero más bravos (los jefes no cambian):
	EnemySpeedMult = 1.3, -- caminan más rápido
	EnemyAttackCooldownMult = 0.7, -- atacan más seguido (menos espera entre ataques)
	-- Bichos sin ataque a distancia que igual tiran algo: esta parte de ellos suma un disparo
	ExtraShotChance = 0.45,
	ExtraShot = { Type = "Shoot", Cooldown = { 2.6, 3.8 }, Range = 45, Telegraph = 0.45, Speed = 38, Damage = 9, Color = Color3.fromRGB(255, 90, 60) },
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
	SpawnGroup = 6, -- enemigos que aparecen en cada aparición (repartidos entre SpawnSides lados)
	-- Desde todos lados: cada aparición se reparte en SpawnSides grupos desde direcciones
	-- distintas alrededor de un jugador (y la próxima, desde otras). Con BehindSpawnChance,
	-- uno de los grupos sale por la espalda de ese jugador: hay que mirar a todos lados.
	SpawnSides = 3,
	BehindSpawnChance = 0.5,
	EnemyHealthMult = 1.4, -- vida de los enemigos comunes (menos bichos, cada uno aguanta más)
	EnemyDamageMult = 0.9, -- daño de los enemigos comunes (menos bichos, cada uno pega más)
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

-- Eventos de la oleada (ver Server/WaveEvents.lua): élites, momentos horda y metas de equipo
Config.Events = {
	-- Élites: enemigos comunes "potenciados" con un rasgo. Más grandes, con aura y cartel, y al
	-- morir sueltan un cofre (de rareza EliteChestMinRarity o mejor).
	Elite = {
		FromWave = 2, -- desde esta oleada
		PerWave = 1, -- cuántos por oleada...
		ExtraEvery = 4, -- ...y uno más cada tantas oleadas (oleada 8: 1 + 2 = 3)
		Max = 4,
		HealthMult = 7,
		DamageMult = 1.6,
		SizeMult = 1.4,
		ChestMinRarity = "Rare",
		-- Rasgos: uno al azar por élite (el nombre sale en su cartel)
		Affixes = {
			{ Id = "Swift", Name = "Veloz", Speed = 1.55 },
			{ Id = "Armored", Name = "Blindado", Health = 1.6, Speed = 0.85 },
			{ Id = "Furious", Name = "Furioso", Damage = 1.7 },
			{ Id = "Giant", Name = "Gigante", Health = 1.3, Size = 1.25 },
		},
	},
	-- Momento horda: a mitad de oleada, una avalancha de enemigos débiles desde todos lados.
	-- Superarla (matarlos a todos) da oro al equipo y un cofre.
	Horde = {
		FromWave = 3,
		Chance = 0.45, -- probabilidad de que la oleada tenga horda (nunca en la de jefe)
		StartAfter = { 8, 16 }, -- segundos después de empezar la oleada (al azar en el rango)
		Count = 45, -- enemigos (× el escalado de cantidad por jugadores)
		Burst = 9, -- cuántos salen juntos
		BurstEvery = 0.35, -- segundos entre tandas
		HealthMult = 0.45, -- son débiles: se mueren de un par de golpes
		Distance = 26, -- a qué distancia del equipo aparecen (en anillo)
		Gold = 60, -- premio por superarla (× el botín del capítulo), para cada uno
		ChestRarity = "Rare", -- rareza mínima del cofre que suelta al final
	},
	-- Metas de equipo: una por oleada (desde FromWave). Si la cumplen, oro para todos y un cofre.
	Goals = {
		FromWave = 2,
		Delay = 3, -- segundos después de empezar la oleada
		Gold = 50, -- premio (× el botín del capítulo), para cada uno
		GemChance = 0.35, -- y a veces gemas
		ChestRarity = "Uncommon",
		Kills = { Count = 70, Time = 30 }, -- "maten N entre todos en T s" (N × escalado por jugadores)
		Elite = { Time = 25 }, -- "maten al élite marcado en T s"
		Chests = { Count = 2 }, -- "abran N cofres en esta oleada"
	},
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
		glacier = Enum.Material.Snow,
		desert = Enum.Material.Sand,
	},
}

-- Cooperativo: derribo, rescate y dificultad según la cantidad de jugadores
-- Agarre (Grab.lua): el Atrapador te salta encima y te inmoviliza. Te salva un compañero
-- pegándole, o te soltás solo machacando ESPACIO (toque en el celular, A en el joystick).
Config.Grab = {
	TickTime = 0.5, -- cada tanto te saca Dps × TickTime de vida mientras te tiene
	ReleaseDamageFraction = 0.25, -- te suelta si recibe esta fracción de su vida máxima mientras te tiene
	StrugglePresses = 16, -- toques para soltarte solo
	StruggleMaxRate = 12, -- toques por segundo que cuenta como máximo (anti-macro)
	MaxHold = 10, -- segundos máximos agarrado (por las dudas)
	StunAfter = 1.5, -- el que te soltó queda aturdido estos segundos
	Knockback = 8, -- y sale despedido estos studs
	RegrabCooldown = 6, -- segundos antes de que ESE Atrapador pueda volver a agarrar a alguien
	ImmuneAfter = 5, -- segundos después de soltarte en que ningún Atrapador te puede agarrar
}

-- Marcas para el cooperativo (Ping.lua / PingUI): apuntás y marcás un enemigo, un cofre o un
-- lugar; todo el equipo lo ve con tu color. Derribado o agarrado, marcar pide ayuda.
Config.Ping = {
	Enabled = true,
	Keys = { Enum.KeyCode.G, Enum.UserInputType.MouseButton3, Enum.KeyCode.DPadUp }, -- teclado / ruedita / joystick
	Cooldown = 0.6, -- segundos mínimos entre dos marcas del mismo jugador (lo controla el servidor)
	MaxPerPlayer = 2, -- marcas vivas por jugador; la más vieja se borra
	Duration = 6, -- segundos que dura una marca de lugar o cofre
	EnemyDuration = 8, -- una marca de enemigo (antes, si muere)
	HelpDuration = 5, -- un pedido de ayuda
	MaxDistance = 220, -- hasta dónde llega la mira (studs)
	OriginSlack = 70, -- distancia máxima entre la cámara que manda el cliente y su personaje
	AimAssist = 2.5, -- studs de margen alrededor del enemigo o cofre para que cuente
	AimAssistPerStud = 0.03, -- y un poco más cuanto más lejos está
	ChestRadius = 2,
	GroundStep = 1.5, -- paso con el que se busca el piso a lo largo de la mira
	-- Color de cada jugador (orden por UserId entre los participantes)
	Colors = {
		Color3.fromRGB(80, 200, 255),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(120, 240, 120),
		Color3.fromRGB(255, 120, 200),
	},
}

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
	-- Arranque rápido: los primeros niveles piden solo esta fracción (nivel 1→2, 2→3, ...).
	-- Con 12/7 queda 4, 9, 16, 25 y después la fórmula normal (40, 47...): 3-4 niveles en el
	-- primer minuto, para que la partida enganche desde el principio.
	EarlyLevelMult = { 0.35, 0.45, 0.6, 0.75 },
	ChoiceTimeout = 30, -- segundos para elegir; después se elige una al azar
	ChoicesPerLevel = 3,
	RarityWeights = { Common = 55, Rare = 32, Epic = 13, Legendary = 9 },
	-- Las habilidades del mazo de tu arma salen más seguido que las comunes (× este peso)
	WeaponDeckWeight = 1.6,
	-- Carta dorada sorpresa: con esta probabilidad, una de las cartas de la oferta viene dorada y
	-- da 2 niveles de esa habilidad de una vez (solo en habilidades con lugar para 2 niveles más).
	GoldenCardChance = 0.05,
	-- Segunda tanda del mazo de cada arma (Skills con Tier = 2): sale desde este nivel de la
	-- partida. Al llegar, el HUD avisa "¡Nueva tanda de habilidades!".
	SecondTierLevel = 6,
}

-- Lobby y ciclo de partida (MatchManager)
Config.Match = {
	MaxPartySize = 4, -- jugadores por partida (configurá también Max Players = 4 en Game Settings)
	CountdownTime = 5, -- segundos de cuenta regresiva cuando todos están listos
	ResultsTime = 15, -- segundos de resultados antes de volver solos al lobby
	MinResultsTime = 2, -- "Volver al lobby" no responde antes de esto (evita doble clic)
	-- Botón OTRA en los resultados: al volver al lobby quedás listo solo, con el mismo capítulo,
	-- y si todos los del lobby apretaron OTRA la cuenta regresiva es esta (más corta).
	AgainCountdownTime = 3,
	ReturnDelay = 1, -- segundos de pantalla de transición al volver
	RequestCooldown = 0.25, -- tiempo mínimo entre peticiones de un mismo jugador
}

-- Places de la experiencia: la Ciudadela (lobby, muchos jugadores) y la Arena (partidas privadas
-- de un grupo). Server/Places decide el rol de cada servidor:
--   · Place de la arena (ArenaPlaceId) publicado: "Arena" (recibe al grupo, juega y lo devuelve).
--   · Cualquier otro (el lobby, y siempre en Studio): "Lobby" (grupos, invitaciones y cola). Si se
--     puede teletransportar (no es Studio y ArenaPlaceId no es 0) el grupo viaja a una arena
--     privada; si no, la partida se juega en este mismo servidor (una a la vez).
-- Cómo armarlo: en el Creator Dashboard (o en Studio: Asset Manager › Places › Add New Place)
-- creá el place de la arena dentro de la misma experiencia, publicale este mismo código con la
-- arena y pegá acá su Id. En Game Settings poné Max Players = LobbyMaxPlayers en el lobby y
-- Config.Match.MaxPartySize en la arena.
Config.Places = {
	LobbyPlaceId = 81254012896939, -- la Ciudadela (este place)
	ArenaPlaceId = 99709174908492, -- la Arena (servidores privados por grupo). 0 = todo en un mismo servidor
	LobbyMaxPlayers = 20, -- referencia: se configura en Game Settings del place del lobby
	InviteTime = 30, -- segundos que dura una invitación a un grupo
	QueueMaxWait = 20, -- cola rápida: si en este tiempo no se llenó el grupo, sale igual
	QueueStartDelay = 3, -- cuenta regresiva corta cuando la cola arma un grupo
	ArenaWaitMax = 25, -- arena: segundos máximos esperando que llegue todo el grupo
	ArenaCountdown = 3, -- arena: cuenta regresiva cuando llegó todo el grupo
	TeleportRetries = 3, -- intentos si un teletransporte falla
}

-- Lobby físico: lejos de la arena para que nunca se vean
Config.Lobby = {
	Center = Vector3.new(0, 0, 400),
	Size = Vector3.new(90, 1, 90),
}

-- Cajas (crates) de la plaza volcánica, al este del lobby. Precios, premios y probabilidades
-- están en Shared/Crates.lua y Shared/CrateItems.lua; acá, cómo funciona el sistema.
Config.Crates = {
	Enabled = true, -- false: no se arma la plaza ni se pueden abrir cajas
	Currency = "Gold", -- moneda con la que se paga (Shared/Currencies.lua)
	LeaderstatName = "Monedas", -- columna de leaderstats que muestra esa moneda
	OpenCooldown = 2, -- segundos mínimos entre dos aperturas del mismo jugador
	InfoCooldown = 0.4, -- segundos mínimos entre dos pedidos de la colección (pestaña Index)
	StationRange = 40, -- hay que estar a esta distancia (studs) de una plataforma para abrir
	EquipCooldown = 0.5, -- segundos mínimos entre dos cambios de equipo
	-- Robux: cada caja con ProductId (Shared/Crates.lua) muestra un botón "R$". Con false no
	-- aparece ninguno. Donde Roblox prohíbe cajas pagas al azar (PolicyService) nunca aparece.
	RobuxEnabled = true,
	MaxSavedReceipts = 100, -- compras recordadas por perfil (para no entregar dos veces la misma)
	-- Mascota equipada: daño extra según su rareza (0.05 = +5%). Los personajes son solo aspecto.
	PetDamageBonus = {
		Common = 0.02,
		Uncommon = 0.04,
		Rare = 0.06,
		Epic = 0.09,
		Legendary = 0.12,
		Mythic = 0.16,
		Secret = 0.2,
	},
	-- Cómo te sigue la mascota (solo visual, en cada pantalla)
	Pet = {
		Height = 2.4, -- alto en studs
		Offset = Vector3.new(2.6, 1.2, 2.4), -- a tu derecha, arriba y atrás
		FollowSpeed = 8, -- más alto = se pega más rápido
		BobHeight = 0.35,
	},
	-- Monedas para probar: se dan UNA vez por perfil. Con OnlyInStudio = true, solo en Studio.
	-- Antes de publicar: TestGold = 0 (o dejá OnlyInStudio en true).
	TestGold = 30000,
	TestGoldOnlyInStudio = true,
	-- Plaza: pegada al muro este del lobby, con una puerta en ese muro
	Plaza = {
		Size = Vector3.new(100, 1, 96), -- ancho (X) x alto x largo (Z)
		DoorZ = 12, -- dónde está la puerta en el muro del lobby (corrida en Z desde el centro)
		DoorWidth = 14,
		StationSpacing = 15, -- distancia entre plataformas (con 6 cajas, más de 16 se sale de la plaza)
		StationRadius = 6, -- radio del hexágono
	},
	-- Luz de la plaza (solo en tu pantalla, al entrar): cielo rojizo y niebla cálida
	Lighting = {
		ClockTime = 17.7, -- sol bajo: atardecer rojizo para cualquier lado que mires
		Brightness = 1.6,
		Ambient = Color3.fromRGB(95, 45, 35),
		OutdoorAmbient = Color3.fromRGB(130, 60, 40),
		HazeDensity = 0.42,
		HazeColor = Color3.fromRGB(255, 120, 75),
		HazeDecay = Color3.fromRGB(120, 28, 16),
		HazeGlare = 0.5,
		Haze = 2.3,
		BloomIntensity = 0.7,
		BloomSize = 28,
		BloomThreshold = 0.95,
		Tint = Color3.fromRGB(255, 228, 210),
		Saturation = 0.18,
		Contrast = 0.12,
	},
	-- Animación de apertura (cliente)
	Cinematic = {
		-- Arena cinemática (solo existe en tu pantalla mientras se abre una caja). Lejos de todo y
		-- a baja altura: muy arriba la atmósfera se afina y el cielo se ve negro en vez de rojizo.
		Origin = Vector3.new(0, 40, -2600),
		ShakeTime = 2.4, -- segundos que la caja tiembla antes de explotar
		OrbitSpeed = 7, -- grados por segundo que gira la cámara alrededor de los premios
		RouletteLaps = 3, -- vueltas completas antes de frenar
		RouletteFast = 0.045, -- segundos por premio al principio de la ruleta
		RouletteSlow = 0.55, -- segundos del último salto
	},
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
	-- Pausa de impacto ("hit-stop") en tus críticos, dorados y jefes: el arma se congela un
	-- instante, la cámara se acerca y la pantalla destella. Solo visual, en tu pantalla.
	HitStop = 0.06, -- segundos de congelado en un crítico (dorados y jefes: el doble/triple)
	HitStopGap = 0.2, -- mínimo entre dos pausas (con muchos críticos seguidos no se traba)
	HitStopFov = 4, -- grados que se acerca la cámara (0 = sin acercamiento)
	-- Racha de muertes: cada muerte seguida suena una nota más aguda (escala pentatónica).
	-- Se corta como el combo (Config.Frenzy.ComboWindow). StreakNotes: cuántos escalones sube
	-- (5 escalones = una octava; 10 = dos octavas, más arriba se vuelve chillón).
	StreakNotes = 10,
	-- Orbes de XP en escalera: cada cobro seguido (dentro de OrbLadderWindow s) suena una nota
	-- más aguda, hasta OrbLadderNotes escalones; si pasa un rato sin juntar, vuelve a empezar.
	OrbLadderNotes = 7,
	OrbLadderWindow = 0.8,
	-- Arma en primera persona (manos de Roblox sosteniendo el ítem). Apagado: solo chispas al pegar.
	FirstPersonWeapon = true,
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
	-- Luz de la arena: "Code" (los valores de arriba, de día) o "Place" (la que armes vos en
	-- Studio dentro de Lighting: hora, Atmosphere, Sky, efectos). Con "Place" el juego no la toca.
	ArenaLighting = "Code",
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
	-- Con racha, tus números de daño salen más grandes: +ComboGrow (60%) al llegar a x ComboGrowAt
	ComboGrow = 0.6,
	ComboGrowAt = 50,
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
	-- Panel de prueba (F2): monedas, niveles, saltar oleada, jefe, etc. Lo valida el servidor.
	-- Funciona siempre en Studio; en un servidor publicado, solo para los UserId de Admins.
	Commands = true,
	Admins = {} :: { number }, -- p. ej. { 12345678 }
}

-- Registro de partidas para balancear (RunLog.lua)
Config.RunLog = {
	Print = true, -- una línea por jugador en la Salida al terminar cada partida
	SaveToDataStore = true, -- guardar en un DataStore aparte (no toca los perfiles)
	StoreName = "RunLog_v1",
	PerDayLimit = 400, -- filas por día (UTC); las de más se descartan
	MemoryLimit = 100, -- filas que quedan en memoria del servidor
}

return Config
