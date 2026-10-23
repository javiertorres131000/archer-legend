-- EnemyTypes (ModuleScript)
-- Ubicación: ServerScriptService > Server > Data > EnemyTypes
-- Catálogo de enemigos y jefes, inspirado en Archero. Todo es dato: EnemyAI lo interpreta.
--
-- Campos de un enemigo:
--   Name, Health, Size, Height?, Shape? ("Ball"), Float? (vuela a esa altura), Color
--   ContactDamage, XP, Cost (cuánto "presupuesto" de oleada consume)
--   Move    = { Type = "Chase" | "Erratic" | "Keep" | "Wander" | "Still", Speed, ... }
--             Erratic: Hop, Pause, Wobble · Keep: Min, Max (distancia que mantiene)
--   Attacks = lista de ataques (ver abajo). Rest = pausa entre ataques.
--   OnDeath = { Split = { Type, Count } } se divide al morir
--   Trail   = { Interval, Radius, Duration, Dps, Color } deja zonas peligrosas al moverse
--   Boss = true y Phases = { { Above = 0.5, Move, Attacks, Rest }, { Above = 0, ... } }
--
-- Campos comunes de un ataque: Type, Cooldown, Range, MinRange, Weight, Telegraph (aviso),
--   Recover, Repeats (lo repite con un aviso más corto), Then (encadena otro ataque),
--   ChainRest (pausa después). Casi cualquier número puede ser un rango {min, max}.
-- Tipos: Dash, Shoot, Area, Breath, Teleport, Burrow, Summon, Grab (ver EnemyAI).
--   Grab: salta como el Dash y, si te alcanza, te agarra (Grab.lua): Dps = daño por segundo.

local C = Color3.fromRGB

-- Colores de proyectiles
local FIRE = C(255, 120, 30)
local ROCK = C(150, 135, 120)
local MAGIC = C(190, 90, 255)
local POISON = C(130, 230, 80)
local BONE = C(240, 235, 210)
local DARK = C(255, 60, 110)
local ICE = C(120, 200, 255)
local SPARK = C(255, 240, 90)

local T = {}

---------------------------------------------------------------------
-- Atrapador: te salta encima y te inmoviliza hasta que un compañero le pegue o te soltés
-- (Config.Grab). Sale de a uno cada tanto (peso bajo en los capítulos).

T.Grabber = {
	Name = "Atrapador",
	Health = 150,
	Size = 3,
	Color = C(130, 45, 170),
	ContactDamage = 8,
	XP = 4,
	Cost = 4,
	Move = { Type = "Chase", Speed = 12 },
	Attacks = {
		{
			Type = "Grab",
			Cooldown = { 4, 6 },
			Range = 22,
			Telegraph = 0.8,
			Distance = { 18, 26 },
			Speed = 60,
			Dps = 12,
		},
	},
}

---------------------------------------------------------------------
-- Slimes y calaveras: cuerpo a cuerpo
---------------------------------------------------------------------
T.GreenSlime = {
	Name = "Slime verde",
	Health = 40,
	Size = 2.4,
	Shape = "Ball",
	Color = C(90, 200, 90),
	ContactDamage = 8,
	XP = 1,
	Cost = 1,
	Move = { Type = "Erratic", Speed = 14, Hop = { 0.4, 0.6 }, Pause = { 0.4, 0.8 }, Wobble = 50 },
}

T.RedSlime = {
	Name = "Slime rojo",
	Health = 70,
	Size = 3,
	Shape = "Ball",
	Color = C(220, 70, 70),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	Move = { Type = "Erratic", Speed = 20, Hop = { 0.35, 0.5 }, Pause = { 0.2, 0.45 }, Wobble = 40 },
	OnDeath = { Split = { Type = "GreenSlime", Count = 2 } },
}

T.WhiteSkull = {
	Name = "Calavera blanca",
	Health = 55,
	Size = 2.4,
	Color = BONE,
	ContactDamage = 12,
	XP = 1,
	Cost = 1,
	Move = { Type = "Chase", Speed = 7 },
}

T.YellowSkull = {
	Name = "Calavera amarilla",
	Health = 90,
	Size = 3,
	Color = C(240, 210, 80),
	ContactDamage = 14,
	XP = 2,
	Cost = 2,
	Move = { Type = "Chase", Speed = 8 },
	OnDeath = { Split = { Type = "WhiteSkull", Count = 2 } },
}

---------------------------------------------------------------------
-- Animales: embestidas
---------------------------------------------------------------------
T.GreenBat = {
	Name = "Murciélago verde",
	Health = 35,
	Size = 2,
	Shape = "Ball",
	Float = 4, -- vuela a la altura de los ojos (los golpes se miden en el plano: no cuesta más pegarle)
	Color = C(80, 170, 90),
	ContactDamage = 8,
	XP = 1,
	Cost = 1,
	Move = { Type = "Wander", Speed = 10 },
	Attacks = {
		{ Type = "Dash", Cooldown = { 2.2, 3.2 }, Range = 35, Telegraph = 0.6, Distance = { 16, 22 }, Speed = 50, Damage = 12 },
	},
}

T.RedBat = {
	Name = "Murciélago rojo",
	Health = 50,
	Size = 2.2,
	Shape = "Ball",
	Float = 4,
	Color = C(200, 50, 60),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	Move = { Type = "Wander", Speed = 13 },
	Attacks = {
		{ Type = "Dash", Cooldown = { 1.8, 2.6 }, Range = 35, Telegraph = 0.45, Distance = { 18, 24 }, Speed = 70, Damage = 14 },
		{ Type = "Shoot", Cooldown = { 3, 4 }, Range = 40, Telegraph = 0.4, Speed = 35, Damage = 10, Color = DARK },
	},
}

T.GreyWolf = {
	Name = "Lobo gris",
	Health = 80,
	Size = 3,
	Color = C(140, 140, 150),
	ContactDamage = 12,
	XP = 2,
	Cost = 2,
	Move = { Type = "Chase", Speed = 11 },
	Attacks = {
		{
			Type = "Dash",
			Cooldown = { 2.5, 3.5 },
			Range = 28,
			Telegraph = 0.5,
			Distance = { 20, 26 },
			Speed = 60,
			Damage = 16,
		},
	},
}

T.BrownWolf = {
	Name = "Lobo marrón",
	Health = 110,
	Size = 3.2,
	Color = C(130, 85, 50),
	ContactDamage = 14,
	XP = 3,
	Cost = 3,
	Move = { Type = "Chase", Speed = 13 },
	Attacks = {
		-- Encadena 2 o 3 embestidas, reapuntando cada vez
		{
			Type = "Dash",
			Cooldown = { 3, 4 },
			Range = 30,
			Telegraph = 0.55,
			RepeatTelegraph = 0.3,
			Repeats = { 2, 3 },
			Distance = { 16, 22 },
			Speed = 65,
			Damage = 16,
		},
	},
}

T.Snake = {
	Name = "Serpiente verde",
	Health = 60,
	Size = 2.2,
	Height = 1.4,
	Color = C(60, 160, 70),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	Move = { Type = "Chase", Speed = 9 },
	Attacks = {
		{ Type = "Dash", Cooldown = { 1.4, 2 }, Range = 14, Telegraph = 0.35, Distance = { 9, 12 }, Speed = 70, Damage = 12 },
	},
}

T.Spider = {
	Name = "Araña azul",
	Health = 45,
	Size = 2.2,
	Height = 1.2,
	Color = C(70, 100, 220),
	ContactDamage = 8,
	XP = 2,
	Cost = 2,
	Move = { Type = "Erratic", Speed = 16, Hop = { 0.25, 0.4 }, Pause = { 0.1, 0.3 }, Wobble = 90 },
	Trail = { Interval = 0.7, Radius = 2.2, Duration = 3, Dps = 10, Color = C(110, 60, 170) },
}

T.Crocodile = {
	Name = "Cocodrilo púrpura",
	Health = 130,
	Size = 3.4,
	Height = 2,
	Color = C(120, 60, 150),
	ContactDamage = 12,
	XP = 3,
	Cost = 3,
	Move = { Type = "Chase", Speed = 7 },
	Attacks = {
		-- Cono de fuego hacia adelante
		{
			Type = "Breath",
			Cooldown = { 3, 4 },
			Range = 16,
			Telegraph = 0.6,
			Duration = { 1, 1.4 },
			Rate = 0.06,
			Spread = 35,
			TurnRate = 70,
			Speed = 28,
			Lifetime = 0.6,
			Damage = 6,
			Size = 1.1,
			Color = FIRE,
		},
	},
}

T.Worm = {
	Name = "Gusano marrón",
	Health = 70,
	Size = 2.6,
	Height = 3,
	Color = C(150, 100, 60),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	Move = { Type = "Still" },
	Rest = 0.4,
	Attacks = {
		{ Type = "Burrow", Cooldown = { 4, 6 }, Telegraph = 0.6, Duration = { 1.5, 2.2 }, Emerge = { 8, 13 }, ChainRest = 0.3 },
		-- Proyectil en arco: cae donde estabas
		{ Type = "Area", Cooldown = { 2, 3 }, Range = 50, Telegraph = 0.4, Count = 1, Radius = 3, Delay = 1, Damage = 14, Scatter = 2 },
	},
}

---------------------------------------------------------------------
-- Plantas y tocones: quietos, disparan
---------------------------------------------------------------------
T.GreenPlant = {
	Name = "Planta de enredaderas",
	Health = 60,
	Size = 2.4,
	Height = 3.4,
	Color = C(150, 70, 170),
	ContactDamage = 8,
	XP = 2,
	Cost = 2,
	Move = { Type = "Still" },
	Attacks = {
		{ Type = "Area", Cooldown = { 2.5, 3.5 }, Range = 60, Telegraph = 0.5, Count = 1, Radius = 3, Delay = 1.1, Damage = 14, Scatter = 2 },
	},
}

T.BluePlant = {
	Name = "Planta de enredaderas azul",
	Health = 80,
	Size = 2.6,
	Height = 3.6,
	Color = C(90, 80, 200),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Still" },
	Attacks = {
		{ Type = "Area", Cooldown = { 2.5, 3.5 }, Range = 60, Telegraph = 0.5, Count = 2, Radius = 3, Delay = 1.1, Damage = 14, Scatter = 6 },
	},
}

T.GreenStump = {
	Name = "Tocón verde",
	Health = 70,
	Size = 3,
	Height = 2,
	Color = C(110, 140, 60),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	-- Vuela: flota sobre el piso y se mantiene a media distancia mientras dispara
	Float = 3.5,
	Move = { Type = "Keep", Speed = 9, Min = 12, Max = 24 },
	Attacks = {
		-- Salta y libera 4 proyectiles (en + o en x, al azar)
		{
			Type = "Shoot",
			Pattern = "Radial",
			Cooldown = { 2.5, 3.5 },
			Range = 45,
			Telegraph = 0.6,
			Jump = true,
			Count = 4,
			Speed = 24,
			Damage = 11,
			Color = POISON,
		},
	},
}

T.BlueStump = {
	Name = "Tocón azul",
	Health = 100,
	Size = 3.2,
	Height = 2.2,
	Color = C(60, 110, 150),
	ContactDamage = 10,
	XP = 3,
	Cost = 3,
	Move = { Type = "Still" },
	Attacks = {
		{
			Type = "Shoot",
			Pattern = "Radial",
			Cooldown = { 2.5, 3.5 },
			Range = 45,
			Telegraph = 0.6,
			Jump = true,
			Count = 8,
			Bursts = 2,
			BurstDelay = 0.35,
			Rotate = 22.5,
			Speed = 24,
			Damage = 11,
			Color = ICE,
		},
	},
}

T.Cactus = {
	Name = "Cactus",
	Health = 90,
	Size = 2,
	Height = 4,
	Color = C(60, 150, 80),
	ContactDamage = 12,
	XP = 3,
	Cost = 2,
	-- Vuela: flota y busca distancia para su ráfaga
	Float = 3,
	Move = { Type = "Keep", Speed = 8, Min = 16, Max = 30 },
	Attacks = {
		-- Línea de aviso y ráfaga rápida hacia donde estabas
		{
			Type = "Shoot",
			Cooldown = { 2.5, 3.2 },
			Range = 55,
			Telegraph = 0.9,
			AimLine = true,
			Track = false,
			Bursts = 3,
			BurstDelay = 0.1,
			Speed = 60,
			Damage = 10,
			Size = 0.9,
			Color = POISON,
		},
	},
}

---------------------------------------------------------------------
-- Gólems y arqueros: mantienen distancia
---------------------------------------------------------------------
T.WhiteGolem = {
	Name = "Gólem blanco",
	Health = 120,
	Size = 3.4,
	Color = C(210, 210, 215),
	ContactDamage = 14,
	XP = 3,
	Cost = 3,
	Move = { Type = "Keep", Speed = 6, Min = 14, Max = 26 },
	Attacks = {
		{ Type = "Shoot", Cooldown = { 2.2, 3 }, Range = 45, Telegraph = 0.6, Count = 3, Spread = 40, Speed = 30, Damage = 12, Size = 1.8, Color = ROCK },
	},
}

T.BlueGolem = {
	Name = "Gólem azul",
	Health = 160,
	Size = 3.8,
	Color = C(90, 130, 210),
	ContactDamage = 16,
	XP = 4,
	Cost = 4,
	Move = { Type = "Keep", Speed = 6, Min = 14, Max = 26 },
	Attacks = {
		{ Type = "Shoot", Cooldown = { 2.2, 3 }, Range = 45, Telegraph = 0.6, Count = 5, Spread = 70, Speed = 30, Damage = 12, Size = 1.8, Color = ROCK },
	},
}

T.SkeletonArcher = {
	Name = "Arquero esqueleto",
	Health = 60,
	Size = 2.4,
	Height = 5.5, -- del tamaño de un personaje de Roblox
	Color = C(170, 210, 170),
	ContactDamage = 8,
	XP = 2,
	Cost = 2,
	Move = { Type = "Keep", Speed = 9, Min = 18, Max = 30 },
	Attacks = {
		{ Type = "Shoot", Cooldown = { 1.8, 2.6 }, Range = 50, Telegraph = 0.8, AimLine = true, Speed = 50, Damage = 12, Size = 1, Color = BONE },
	},
}

T.RedArcher = {
	Name = "Arquero esqueleto rojo",
	Health = 80,
	Size = 2.4,
	Height = 5.5,
	Color = C(210, 110, 110),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Keep", Speed = 9, Min = 18, Max = 30 },
	Attacks = {
		-- Flechas que rebotan en las paredes
		{
			Type = "Shoot",
			Cooldown = { 2, 2.8 },
			Range = 55,
			Telegraph = 0.8,
			AimLine = true,
			Bursts = 2,
			BurstDelay = 0.3,
			Bounces = 2,
			Speed = 45,
			Damage = 12,
			Size = 1,
			Lifetime = 4,
			Color = DARK,
		},
	},
}

---------------------------------------------------------------------
-- Elementales, magos y bombas
---------------------------------------------------------------------
T.FireSpirit = {
	Name = "Espíritu de fuego",
	Health = 55,
	Size = 2,
	Shape = "Ball",
	Float = 2,
	Color = C(255, 140, 50),
	ContactDamage = 8,
	XP = 2,
	Cost = 2,
	Move = { Type = "Keep", Speed = 10, Min = 12, Max = 22 },
	Attacks = {
		{
			Type = "Shoot",
			Cooldown = { 2, 2.8 },
			Range = 45,
			Telegraph = 0.5,
			Bursts = { 2, 3 },
			BurstDelay = 0.25,
			Jitter = 10,
			Speed = 34,
			Damage = 12,
			Color = FIRE,
		},
	},
}

T.TornadoMage = {
	Name = "Mago tornado",
	Health = 90,
	Size = 2.6,
	Height = 3.6,
	Color = C(120, 200, 200),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Keep", Speed = 8, Min = 16, Max = 28 },
	Attacks = {
		-- Tornados en zigzag
		{
			Type = "Shoot",
			Cooldown = { 2.5, 3.2 },
			Range = 55,
			Telegraph = 0.6,
			Count = { 1, 2 },
			Spread = 25,
			Bursts = 2,
			BurstDelay = 0.5,
			Zigzag = { Amp = 4, Freq = 6 },
			Speed = 22,
			Lifetime = 4,
			Damage = 13,
			Size = 1.8,
			Color = ICE,
		},
		{ Type = "Teleport", Cooldown = { 5, 7 }, Telegraph = 0.5, Distance = { 14, 22 }, ChainRest = 0.3 },
	},
}

T.FireMage = {
	Name = "Mago de fuego",
	Health = 90,
	Size = 2.6,
	Height = 3.6,
	Color = C(220, 70, 40),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Keep", Speed = 8, Min = 18, Max = 32 },
	Attacks = {
		-- Bolas de fuego que caen desde arriba
		{ Type = "Area", Cooldown = { 2.6, 3.4 }, Range = 60, Telegraph = 0.6, Count = 1, Radius = 3.5, Delay = 1, Damage = 16 },
		{ Type = "Teleport", Cooldown = { 5, 7 }, Telegraph = 0.5, Distance = { 16, 24 }, ChainRest = 0.3 },
	},
}

T.WhiteBomb = {
	Name = "Bomba viviente",
	Health = 60,
	Size = 2.4,
	Shape = "Ball",
	Color = C(230, 230, 230),
	ContactDamage = 8,
	XP = 2,
	Cost = 2,
	Move = { Type = "Wander", Speed = 6 },
	Attacks = {
		{ Type = "Area", Cooldown = { 2.5, 3.5 }, Range = 50, Telegraph = 0.5, Count = 1, Radius = 3, Delay = 1.1, Damage = 15, Scatter = 2 },
		{ Type = "Teleport", Cooldown = { 4, 6 }, Telegraph = 0.5, Distance = { 12, 20 }, ChainRest = 0.4 },
	},
}

T.BlueBomb = {
	Name = "Bomba viviente azul",
	Health = 80,
	Size = 2.6,
	Shape = "Ball",
	Color = C(80, 140, 230),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Wander", Speed = 6 },
	Attacks = {
		{ Type = "Area", Cooldown = { 2.8, 3.6 }, Range = 50, Telegraph = 0.5, Count = 3, Radius = 2.8, Delay = 1.1, Damage = 14, Scatter = 7 },
		{ Type = "Teleport", Cooldown = { 4, 6 }, Telegraph = 0.5, Distance = { 12, 20 }, ChainRest = 0.4 },
	},
}

T.RedBomb = {
	Name = "Bomba viviente roja",
	Health = 80,
	Size = 2.6,
	Shape = "Ball",
	Color = C(220, 60, 50),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Wander", Speed = 6 },
	Attacks = {
		-- Deja el piso en llamas
		{
			Type = "Area",
			Cooldown = { 3, 4 },
			Range = 50,
			Telegraph = 0.5,
			Count = 1,
			Radius = 3.4,
			Delay = 1.1,
			Damage = 14,
			Scatter = 2,
			Zone = { Duration = 4, Dps = 10 },
		},
		{ Type = "Teleport", Cooldown = { 4, 6 }, Telegraph = 0.5, Distance = { 12, 20 }, ChainRest = 0.4 },
	},
}

---------------------------------------------------------------------
-- Torretas
---------------------------------------------------------------------
T.ElectricTower = {
	Name = "Torre eléctrica",
	Health = 140,
	Size = 2.6,
	Height = 6,
	Color = C(230, 210, 60),
	ContactDamage = 10,
	XP = 3,
	Cost = 3,
	Move = { Type = "Still" },
	Attacks = {
		-- Marca zonas y descarga rayos
		{
			Type = "Area",
			Cooldown = { 3, 4 },
			Range = 70,
			Telegraph = 0.5,
			Count = 2,
			FirstExact = true,
			Scatter = 6,
			Radius = 3.5,
			Delay = 1.2,
			Damage = 18,
			WarnColor = SPARK,
		},
	},
}

T.OrbTower = {
	Name = "Torre de orbes",
	Health = 140,
	Size = 2.6,
	Height = 5,
	Color = C(120, 60, 170),
	ContactDamage = 10,
	XP = 3,
	Cost = 3,
	Move = { Type = "Still" },
	Attacks = {
		{
			Type = "Shoot",
			Pattern = "Radial",
			Cooldown = { 3, 4 },
			Range = 60,
			Telegraph = 0.6,
			Count = 6,
			Bursts = 3,
			BurstDelay = 0.3,
			Rotate = 20,
			Speed = 22,
			Damage = 11,
			Color = MAGIC,
		},
	},
}

---------------------------------------------------------------------
-- Mini-jefes y jefes (2 por capítulo)
---------------------------------------------------------------------

-- Capítulo 1 · mini-jefe
T.KingSlime = {
	Name = "Rey Slime",
	Boss = true,
	Health = 1100,
	Size = 7,
	Shape = "Ball",
	Color = C(60, 170, 70),
	ContactDamage = 18,
	XP = 12,
	OnDeath = { Split = { Type = "RedSlime", Count = 2 } },
	Phases = {
		{
			Above = 0.5,
			Rest = { 1, 1.6 },
			Move = { Type = "Erratic", Speed = 12, Hop = { 0.6, 0.9 }, Pause = { 0.6, 1 }, Wobble = 30 },
			Attacks = {
				{ Type = "Area", Target = "Self", Range = 14, Telegraph = 0.4, Radius = 9, Delay = 0.8, Damage = 20, Weight = 2 },
				{ Type = "Shoot", Pattern = "Radial", Telegraph = 0.6, Jump = true, Count = 10, Speed = 24, Damage = 12, Color = POISON },
				{ Type = "Summon", Telegraph = 0.6, Spawn = "GreenSlime", Count = 2, Max = 4 },
			},
		},
		{
			Above = 0,
			Rest = { 0.7, 1.1 },
			Move = { Type = "Erratic", Speed = 16, Hop = { 0.5, 0.8 }, Pause = { 0.3, 0.6 }, Wobble = 30 },
			Attacks = {
				{ Type = "Area", Target = "Self", Range = 15, Telegraph = 0.35, Radius = 10, Delay = 0.7, Damage = 22, Weight = 2 },
				{
					Type = "Shoot",
					Pattern = "Radial",
					Telegraph = 0.5,
					Jump = true,
					Count = 14,
					Bursts = 2,
					BurstDelay = 0.35,
					Rotate = 13,
					Speed = 26,
					Damage = 12,
					Color = POISON,
				},
				{ Type = "Summon", Telegraph = 0.5, Spawn = "GreenSlime", Count = 3, Max = 6 },
				{ Type = "Dash", Telegraph = 0.7, Distance = { 25, 35 }, Speed = 45, Damage = 22 },
			},
		},
	},
}

-- Capítulo 1 · jefe
T.Treant = {
	Name = "Guardián Treant",
	Boss = true,
	Health = 3200,
	Size = 8,
	Height = 10,
	Color = C(110, 75, 45),
	ContactDamage = 20,
	XP = 30,
	Phases = {
		{
			Above = 0.5,
			Rest = { 1.1, 1.7 },
			Move = { Type = "Chase", Speed = 4 },
			Attacks = {
				-- Raíces que emergen del suelo bajo los jugadores
				{
					Type = "Area",
					Telegraph = 0.5,
					Count = { 3, 4 },
					FirstExact = true,
					Scatter = 7,
					Radius = 3,
					Delay = 1,
					Damage = 18,
					Bursts = 2,
					BurstDelay = 0.6,
					WarnColor = C(160, 110, 50),
				},
				{
					Type = "Shoot",
					Pattern = "Radial",
					Telegraph = 0.6,
					Count = 12,
					Bursts = 3,
					BurstDelay = 0.4,
					Rotate = 15,
					Speed = 22,
					Damage = 12,
					Color = POISON,
				},
				{ Type = "Shoot", Telegraph = 0.6, Count = 5, Spread = 60, Bursts = 2, BurstDelay = 0.5, Speed = 32, Damage = 13, Color = C(160, 110, 50) },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "GreenSlime", Count = 3, Max = 5 },
			},
		},
		{
			Above = 0,
			Rest = { 0.8, 1.2 },
			Move = { Type = "Chase", Speed = 6 },
			Attacks = {
				{
					Type = "Area",
					Telegraph = 0.4,
					Count = { 4, 6 },
					FirstExact = true,
					Scatter = 9,
					Radius = 3,
					Delay = 0.9,
					Damage = 18,
					Bursts = 3,
					BurstDelay = 0.5,
					WarnColor = C(160, 110, 50),
				},
				{
					Type = "Shoot",
					Pattern = "Radial",
					Telegraph = 0.5,
					Count = 16,
					Bursts = 4,
					BurstDelay = 0.35,
					Rotate = { 10, 20 },
					Speed = 24,
					Damage = 12,
					Color = POISON,
				},
				{
					Type = "Shoot",
					Telegraph = 0.5,
					Count = 7,
					Spread = 90,
					Bursts = 2,
					BurstDelay = 0.4,
					Bounces = 1,
					Speed = 32,
					Damage = 13,
					Color = C(160, 110, 50),
				},
				{ Type = "Summon", Telegraph = 0.6, Spawn = "RedSlime", Count = 2, Max = 3 },
			},
		},
	},
}

-- Capítulo 1 · jefe de la oleada 10: Azrakoth, el Serafín del Eclipse Carmesí (assets/azrakoth).
-- Modelo en ServerStorage > EnemyModels > Azrakoth (piezas unidas con Motor6D); lo anima
-- Client/AzrakothAnimator con Shared/AzrakothAnimData. Cada ataque lleva Anim = nombre de la
-- animación: el golpe de la animación cae justo cuando termina el aviso (Telegraph).
-- Tres fases (70 % y 35 % de vida); al cambiar de fase hace "PhaseTransform" (PhaseAnim).
T.Azrakoth = {
	Name = "Azrakoth, Serafín del Eclipse",
	Boss = true,
	Health = 7000,
	Size = 14,
	Height = 34, -- altura del modelo con las alas (el cuerpo mide ~26 studs)
	Color = C(140, 20, 15),
	ContactDamage = 26,
	XP = 60,
	Alone = true, -- su oleada no trae otros enemigos ni eventos (Waves)
	PhaseAnim = "PhaseTransform",
	DeathAnim = "Death", -- al morir se desploma (5,3 s) y se desvanece
	DeathTime = 5.8,
	Phases = {
		{ -- El Guardián Despierta
			Above = 0.7,
			Rest = { 1.3, 1.9 },
			Move = { Type = "Chase", Speed = 5 },
			Attacks = {
				-- Juicio Carmesí: espadón al suelo + onda expansiva
				{ Type = "Area", Anim = "AttackVertical", Telegraph = 1.5, Count = 1, FirstExact = true, Radius = 9, Delay = 0.3,
					Damage = 30, WarnColor = FIRE, Recover = 0.6, Weight = 2,
					Then = { Type = "Shoot", Pattern = "Radial", Telegraph = 0.05, Count = 18, Speed = 20, Damage = 12, Color = FIRE } },
				-- Danza del Verdugo: dos estocadas rápidas y un tercer golpe con carga larga
				{ Type = "Dash", Anim = "Combo3", Telegraph = 0.6, Repeats = 2, RepeatTelegraph = 0.35, Distance = 16, Speed = 40,
					Damage = 24, Range = 40,
					Then = { Type = "Area", Target = "Self", Telegraph = 1.0, Radius = 11, Delay = 0.3, Damage = 30, WarnColor = FIRE } },
				-- Tormenta de Alas: plumas de fuego y zonas incendiadas
				{ Type = "Shoot", Anim = "WingsOpen", Telegraph = 1.0, Count = 9, Spread = 110, Bursts = 3, BurstDelay = 0.4,
					Speed = 30, Damage = 12, Color = FIRE,
					Then = { Type = "Area", Target = "Random", Telegraph = 0.2, Count = 5, Radius = 4, Delay = 1.0, Damage = 14,
						WarnColor = FIRE, Zone = { Duration = 3, Dps = 8, Color = FIRE } } },
			},
		},
		{ -- El Eclipse Desciende
			Above = 0.35,
			Rest = { 1.0, 1.5 },
			Move = { Type = "Chase", Speed = 6 },
			Attacks = {
				{ Type = "Area", Anim = "AttackVertical", Telegraph = 1.3, Count = 1, FirstExact = true, Radius = 10, Delay = 0.3,
					Damage = 32, WarnColor = FIRE,
					Then = { Type = "Shoot", Pattern = "Radial", Telegraph = 0.05, Count = 22, Bursts = 2, BurstDelay = 0.35,
						Rotate = 8, Speed = 22, Damage = 12, Color = FIRE } },
				{ Type = "Dash", Anim = "Combo3", Telegraph = 0.55, Repeats = 2, RepeatTelegraph = 0.3, Distance = 18, Speed = 44,
					Damage = 26, Range = 40,
					Then = { Type = "Area", Target = "Self", Telegraph = 0.9, Radius = 12, Delay = 0.3, Damage = 32, WarnColor = FIRE } },
				-- Cadenas del Abismo: círculos que estallan debajo de los jugadores
				{ Type = "Area", Anim = "ChainSummon", Telegraph = 1.1, Count = { 3, 4 }, FirstExact = true, Scatter = 6, Radius = 4,
					Delay = 1.3, Damage = 22, WarnColor = DARK },
				-- Caída del Serafín: desaparece en el cielo y cae sobre un jugador
				{ Type = "Teleport", Anim = "SeraphFall", Telegraph = 1.0, Distance = 4, Duration = 1.2,
					Then = { Type = "Area", Target = "Self", Telegraph = 0.9, Radius = 13, Delay = 0.3, Damage = 34, WarnColor = FIRE,
						Zone = { Duration = 3, Dps = 10, Color = FIRE } } },
				-- Corazón del Eclipse: el núcleo se carga y explota en anillos
				{ Type = "Shoot", Anim = "CoreCharge", Pattern = "Radial", Telegraph = 2.0, Count = 24, Bursts = 4, BurstDelay = 0.3,
					Rotate = 7, Speed = 24, Damage = 13, Color = DARK, Cooldown = { 10, 14 } },
				-- Legión de los Condenados
				{ Type = "Summon", Anim = "SummonSoldiers", Telegraph = 1.3, Spawn = "HordeSkeleton", Count = 4, Max = 6,
					Cooldown = { 14, 18 } },
			},
		},
		{ -- El Último Juicio (Ira del Serafín Caído: todo más rápido y potenciado)
			Above = 0,
			Rest = { 0.7, 1.1 },
			Move = { Type = "Chase", Speed = 7 },
			Attacks = {
				-- Rayo del Eclipse: barrido de rayos desde el halo
				{ Type = "Breath", Anim = "BeamFire", Telegraph = 1.5, Duration = 2.8, Spin = 55, Rate = 0.05, Spread = 8,
					Speed = 34, Damage = 10, Color = DARK, Cooldown = { 9, 12 }, Weight = 2 },
				{ Type = "Area", Anim = "AttackVertical", Telegraph = 1.1, Count = 1, FirstExact = true, Radius = 11, Delay = 0.3,
					Damage = 34, WarnColor = FIRE,
					Then = { Type = "Shoot", Pattern = "Radial", Telegraph = 0.05, Count = 26, Bursts = 3, BurstDelay = 0.3,
						Rotate = 7, Speed = 24, Damage = 13, Color = FIRE } },
				{ Type = "Dash", Anim = "Combo3", Telegraph = 0.5, Repeats = 2, RepeatTelegraph = 0.28, Distance = 20, Speed = 48,
					Damage = 28, Range = 42,
					Then = { Type = "Area", Target = "Self", Telegraph = 0.8, Radius = 13, Delay = 0.3, Damage = 34, WarnColor = FIRE,
						Zone = { Duration = 3, Dps = 10, Color = FIRE } } },
				{ Type = "Teleport", Anim = "SeraphFall", Telegraph = 0.9, Distance = 4, Duration = 1.0,
					Then = { Type = "Area", Target = "Self", Telegraph = 0.8, Radius = 14, Delay = 0.3, Damage = 36, WarnColor = FIRE,
						Zone = { Duration = 4, Dps = 12, Color = FIRE } } },
				{ Type = "Area", Anim = "ChainSummon", Telegraph = 1.0, Count = { 4, 5 }, FirstExact = true, Scatter = 7, Radius = 4,
					Delay = 1.2, Damage = 24, WarnColor = DARK },
				{ Type = "Summon", Anim = "SummonSoldiers", Telegraph = 1.2, Spawn = "HordeSkeleton", Count = 4, Max = 8,
					Cooldown = { 12, 16 } },
			},
		},
	},
}

-- Capítulo 2 · mini-jefe: tres estrellas lentas y tres rápidas que rebotan
T.CyclopsMage = {
	Name = "Mago Cíclope",
	Boss = true,
	Health = 1800,
	Size = 4,
	Height = 6,
	Color = C(150, 90, 200),
	ContactDamage = 16,
	XP = 15,
	Phases = {
		{
			Above = 0.5,
			Rest = { 0.9, 1.4 },
			Move = { Type = "Keep", Speed = 9, Min = 16, Max = 26 },
			Attacks = {
				{
					Type = "Shoot",
					Telegraph = 0.6,
					Bursts = 6,
					BurstDelay = 0.25,
					SpeedSeq = { 16, 16, 16, 40, 40, 40 },
					Bounces = 2,
					Lifetime = 5,
					Damage = 14,
					Size = 1.8,
					Color = MAGIC,
				},
				{ Type = "Shoot", Pattern = "Radial", Telegraph = 0.6, Count = 8, Bounces = 1, Speed = 26, Lifetime = 4, Damage = 12, Color = MAGIC },
				{ Type = "Teleport", Telegraph = 0.5, Distance = { 14, 22 }, ChainRest = 0.2 },
			},
		},
		{
			Above = 0,
			Rest = { 0.6, 1 },
			Move = { Type = "Keep", Speed = 11, Min = 16, Max = 26 },
			Attacks = {
				{
					Type = "Shoot",
					Telegraph = 0.5,
					Count = 3,
					Spread = 30,
					Bursts = 6,
					BurstDelay = 0.22,
					SpeedSeq = { 16, 16, 16, 42, 42, 42 },
					Bounces = 2,
					Lifetime = 5,
					Damage = 14,
					Size = 1.8,
					Color = MAGIC,
				},
				{
					Type = "Shoot",
					Pattern = "Radial",
					Telegraph = 0.5,
					Count = 12,
					Bursts = 2,
					BurstDelay = 0.4,
					Rotate = 15,
					Bounces = 1,
					Speed = 26,
					Lifetime = 4,
					Damage = 12,
					Color = MAGIC,
				},
				-- Se teletransporta y dispara enseguida
				{
					Type = "Teleport",
					Telegraph = 0.4,
					Distance = { 12, 20 },
					Then = { Type = "Shoot", Telegraph = 0.3, Count = 5, Spread = 60, Speed = 34, Damage = 12, Color = MAGIC },
				},
			},
		},
	},
}

-- Capítulo 2 · jefe
T.StoneGolem = {
	Name = "Gólem de Piedra",
	Boss = true,
	Health = 5000,
	Size = 9,
	Color = C(120, 115, 110),
	ContactDamage = 24,
	XP = 35,
	Phases = {
		{
			Above = 0.5,
			Rest = { 1.1, 1.6 },
			Move = { Type = "Chase", Speed = 5 },
			Attacks = {
				{ Type = "Shoot", Telegraph = 0.6, Count = 5, Spread = 60, Bursts = 2, BurstDelay = 0.5, Speed = 30, Damage = 15, Size = 2.2, Color = ROCK },
				{ Type = "Dash", Telegraph = 0.9, Distance = { 35, 45 }, Speed = 60, Damage = 28 },
				-- Golpe de suelo
				{ Type = "Area", Target = "Self", Range = 16, Telegraph = 0.5, Radius = 12, Delay = 0.9, Damage = 25, Weight = 2 },
			},
		},
		{
			Above = 0,
			Rest = { 0.8, 1.2 },
			Move = { Type = "Chase", Speed = 6 },
			Attacks = {
				{ Type = "Dash", Telegraph = 0.8, RepeatTelegraph = 0.45, Repeats = 2, Distance = { 30, 40 }, Speed = 65, Damage = 28 },
				-- Golpe de suelo seguido de un anillo de rocas
				{
					Type = "Area",
					Target = "Self",
					Range = 18,
					Telegraph = 0.5,
					Radius = 12,
					Delay = 0.8,
					Damage = 25,
					Weight = 2,
					Then = {
						Type = "Shoot",
						Pattern = "Radial",
						Telegraph = 0.6,
						Count = 12,
						Speed = 24,
						Damage = 14,
						Size = 2,
						Color = ROCK,
					},
				},
				-- Lluvia de rocas por toda la arena
				{ Type = "Area", Target = "Random", Telegraph = 0.6, Count = 8, Radius = 3, Delay = 1.2, Damage = 18, Bursts = 2, BurstDelay = 0.7 },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "WhiteGolem", Count = 2, Max = 3 },
			},
		},
	},
}

-- Capítulo 3 · mini-jefe: guadañas que vuelven
T.Reaper = {
	Name = "Segador",
	Boss = true,
	Health = 2600,
	Size = 4,
	Height = 6.5,
	Color = C(60, 50, 70),
	ContactDamage = 18,
	XP = 18,
	Phases = {
		{
			Above = 0.5,
			Rest = { 0.9, 1.4 },
			Move = { Type = "Keep", Speed = 9, Min = 14, Max = 24 },
			Attacks = {
				{
					Type = "Shoot",
					Telegraph = 0.6,
					Count = 3,
					Spread = 40,
					Bursts = 2,
					BurstDelay = 0.4,
					Return = 0.9,
					Speed = 34,
					Lifetime = 2.2,
					Damage = 15,
					Size = 2,
					Color = DARK,
				},
				{ Type = "Teleport", Telegraph = 0.5, Distance = { 10, 18 }, ChainRest = 0.2 },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "SkeletonArcher", Count = 2, Max = 3 },
				-- Meteoritos de la campana
				{ Type = "Area", Target = "Random", Telegraph = 0.6, Count = 5, Radius = 3, Delay = 1.1, Damage = 16 },
			},
		},
		{
			Above = 0,
			Rest = { 0.6, 1 },
			Move = { Type = "Keep", Speed = 11, Min = 12, Max = 22 },
			Attacks = {
				{
					Type = "Shoot",
					Pattern = "Radial",
					Telegraph = 0.5,
					Count = 8,
					Return = 1,
					Speed = 30,
					Lifetime = 2.4,
					Damage = 15,
					Size = 2,
					Color = DARK,
				},
				{
					Type = "Teleport",
					Telegraph = 0.4,
					Distance = { 8, 14 },
					Then = { Type = "Shoot", Telegraph = 0.3, Count = 5, Spread = 70, Return = 0.8, Speed = 36, Lifetime = 2, Damage = 15, Size = 2, Color = DARK },
				},
				{ Type = "Summon", Telegraph = 0.6, Spawn = "RedArcher", Count = 2, Max = 3 },
				{ Type = "Area", Target = "Random", Telegraph = 0.5, Count = 8, Radius = 3, Delay = 1, Damage = 16, Bursts = 2, BurstDelay = 0.6 },
			},
		},
	},
}

-- Capítulo 3 · jefe
T.FlameDemon = {
	Name = "Demonio de Fuego",
	Boss = true,
	Health = 7000,
	Size = 9,
	Color = C(170, 30, 30),
	ContactDamage = 26,
	XP = 50,
	Phases = {
		{
			Above = 0.5,
			Rest = { 1, 1.5 },
			Move = { Type = "Chase", Speed = 6 },
			Attacks = {
				-- Meteoritos que dejan fuego
				{
					Type = "Area",
					Telegraph = 0.5,
					Count = 4,
					FirstExact = true,
					Scatter = 8,
					Radius = 3.5,
					Delay = 1.1,
					Damage = 22,
					Bursts = 2,
					BurstDelay = 0.6,
					Zone = { Duration = 3, Dps = 8 },
				},
				{ Type = "Shoot", Telegraph = 0.6, Count = 7, Spread = 80, Bursts = 3, BurstDelay = 0.4, Speed = 34, Damage = 15, Color = FIRE },
				{ Type = "Dash", Telegraph = 0.9, Distance = { 35, 45 }, Speed = 65, Damage = 30 },
				{ Type = "Shoot", Pattern = "Radial", Telegraph = 0.6, Count = 16, Bursts = 2, BurstDelay = 0.5, Rotate = 11, Speed = 26, Damage = 14, Color = FIRE },
			},
		},
		{
			Above = 0,
			Rest = { 0.7, 1.1 },
			Move = { Type = "Chase", Speed = 7 },
			Attacks = {
				-- Aliento de fuego que gira 360°
				{
					Type = "Breath",
					Telegraph = 0.7,
					Duration = 2.5,
					Spin = 150,
					Rate = 0.05,
					Spread = 12,
					Speed = 30,
					Lifetime = 1.2,
					Damage = 10,
					Size = 1.3,
					Color = FIRE,
				},
				{
					Type = "Area",
					Telegraph = 0.5,
					Count = 6,
					FirstExact = true,
					Scatter = 10,
					Radius = 3.5,
					Delay = 1,
					Damage = 22,
					Bursts = 3,
					BurstDelay = 0.5,
					Zone = { Duration = 3, Dps = 8 },
				},
				{ Type = "Dash", Telegraph = 0.8, RepeatTelegraph = 0.4, Repeats = 3, Distance = { 30, 40 }, Speed = 70, Damage = 30 },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "FireSpirit", Count = 2, Max = 4 },
				{ Type = "Shoot", Telegraph = 0.5, Count = 9, Spread = 100, Bursts = 3, BurstDelay = 0.35, Bounces = 1, Speed = 34, Damage = 15, Color = FIRE },
			},
		},
	},
}

-- Roles legibles: horda, embestida, zona, bloqueo, prioridad.
T.HordeSkeleton = { Name = "Esqueleto de horda", Role = "Horde", Health = 35, Size = 2.2, Height = 5.5,
 Color = BONE, ContactDamage = 8, XP = 1, Cost = 1, Move = { Type = "Chase", Speed = 9 } }
T.RushBeast = { Name = "Bestia veloz", Role = "Rush", Health = 65, Size = 2.8, Shape = "Ball",
 Color = C(255, 145, 60), ContactDamage = 12, XP = 2, Cost = 2, Move = { Type = "Chase", Speed = 15 },
 Attacks = { { Type = "Dash", Cooldown = { 3, 4 }, Range = 30, Telegraph = 0.8, Distance = 24, Speed = 42, Damage = 18, Recover = 0.8 } } }
T.HoodMage = { Name = "Mago encapuchado", Role = "Zone", Health = 75, Size = 2.4, Height = 4.5,
 Color = C(160, 90, 230), ContactDamage = 6, XP = 3, Cost = 3, Move = { Type = "Keep", Speed = 8, Min = 16, Max = 26 },
 Attacks = { { Type = "Area", Cooldown = { 3, 5 }, Range = 45, Target = "Player", Count = 2, Scatter = 8, Radius = 5, Delay = 1.2, Damage = 18, Telegraph = 0.5 } } }
T.HeavyKnight = { Name = "Caballero pesado", Role = "Blocker", Health = 220, Size = 4.6, Height = 5.2,
 Color = C(90, 125, 150), ContactDamage = 20, XP = 5, Cost = 5, Move = { Type = "Chase", Speed = 5 },
 Attacks = { { Type = "Area", Cooldown = { 4, 6 }, Range = 26, Target = "Player", Radius = 5, Delay = 1.3, Damage = 22, Telegraph = 0.9 } } }
T.EliteCaptain = { Name = "Capitán élite", Role = "Elite", Health = 260, Size = 3.8, Height = 5,
 Color = C(235, 65, 120), ContactDamage = 22, XP = 8, Cost = 8, Move = { Type = "Keep", Speed = 10, Min = 10, Max = 18 },
 Attacks = { { Type = "Dash", Cooldown = { 4, 6 }, Range = 28, Telegraph = 1, Distance = 20, Speed = 35, Damage = 24 },
 { Type = "Shoot", Cooldown = { 3, 4 }, Range = 40, Count = 3, Spread = 35, Speed = 24, Damage = 15, Telegraph = 0.9 } } }
---------------------------------------------------------------------
-- ❄️ Capítulo 4 · Glaciar Eterno
---------------------------------------------------------------------
local FROST = C(150, 220, 255)
local SAND = C(225, 190, 120)

T.IceSlime = {
	Name = "Slime de hielo",
	Health = 90,
	Size = 3,
	Shape = "Ball",
	Color = C(150, 215, 255),
	ContactDamage = 14,
	XP = 2,
	Cost = 2,
	Move = { Type = "Erratic", Speed = 16, Hop = { 0.4, 0.55 }, Pause = { 0.3, 0.6 }, Wobble = 45 },
	-- Deja escarcha que lastima al pisarla
	Trail = { Interval = 0.8, Radius = 2.4, Duration = 3, Dps = 8, Color = FROST },
	OnDeath = { Split = { Type = "GreenSlime", Count = 2 } },
}
T.SnowWolf = {
	Name = "Lobo de las nieves",
	Health = 120,
	Size = 3.2,
	Color = C(235, 240, 250),
	ContactDamage = 16,
	XP = 3,
	Cost = 3,
	Move = { Type = "Chase", Speed = 13 },
	Attacks = {
		{ Type = "Dash", Cooldown = { 2.2, 3 }, Range = 30, Telegraph = 0.45, RepeatTelegraph = 0.35, Repeats = 1, Distance = { 20, 26 }, Speed = 65, Damage = 20 },
	},
}
T.FrostBat = {
	Name = "Murciélago escarcha",
	Health = 60,
	Size = 2.2,
	Float = 4,
	Color = C(140, 200, 255),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	Move = { Type = "Erratic", Speed = 18, Hop = { 0.5, 0.8 }, Pause = { 0.1, 0.3 }, Wobble = 70 },
	Attacks = {
		{ Type = "Shoot", Cooldown = { 2.5, 3.5 }, Range = 40, Telegraph = 0.5, Count = 3, Spread = 30, Speed = 26, Damage = 12, Color = ICE },
	},
}
T.IceMage = {
	Name = "Mago de hielo",
	Health = 110,
	Size = 2.6,
	Height = 4,
	Color = C(90, 160, 240),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Keep", Speed = 8, Min = 18, Max = 30 },
	Attacks = {
		-- Carámbanos que caen en círculo alrededor tuyo
		{ Type = "Area", Cooldown = { 3, 4 }, Range = 55, Telegraph = 0.6, Count = 4, Scatter = 6, Radius = 3, Delay = 1.1, Damage = 16, WarnColor = FROST },
		{ Type = "Shoot", Cooldown = { 2, 3 }, Range = 45, Telegraph = 0.5, Count = 1, Speed = 34, Damage = 14, Size = 2, Color = ICE },
	},
}
T.IceGolem = {
	Name = "Gólem de hielo",
	Role = "Blocker",
	Health = 320,
	Size = 4.4,
	Height = 6,
	Color = C(170, 220, 250),
	ContactDamage = 22,
	XP = 6,
	Cost = 6,
	Move = { Type = "Chase", Speed = 5 },
	Attacks = {
		{ Type = "Area", Target = "Self", Cooldown = { 4, 5.5 }, Range = 14, Telegraph = 0.8, Radius = 10, Delay = 0.8, Damage = 24, WarnColor = FROST,
			Then = { Type = "Shoot", Pattern = "Radial", Telegraph = 0.4, Count = 8, Speed = 22, Damage = 12, Color = ICE } },
	},
}
T.Penguin = {
	Name = "Pingüino bombardero",
	Health = 50,
	Size = 2.2,
	Height = 2.8,
	Color = C(40, 45, 60),
	ContactDamage = 10,
	XP = 2,
	Cost = 2,
	Move = { Type = "Chase", Speed = 10 },
	Attacks = {
		-- Se tira de panza hacia vos
		{ Type = "Dash", Cooldown = { 2, 3 }, Range = 26, Telegraph = 0.6, Distance = { 22, 30 }, Speed = 50, Damage = 14 },
	},
}

-- Mini jefe: Yeti
T.Yeti = {
	Name = "Yeti",
	Boss = true,
	Health = 2400,
	Size = 6,
	Height = 8,
	Color = C(230, 235, 245),
	ContactDamage = 22,
	XP = 18,
	Phases = {
		{
			Above = 0.5,
			Rest = { 1, 1.5 },
			Move = { Type = "Chase", Speed = 7 },
			Attacks = {
				{ Type = "Dash", Telegraph = 0.8, Distance = { 30, 40 }, Speed = 60, Damage = 26 },
				-- Bolas de nieve gigantes
				{ Type = "Shoot", Telegraph = 0.6, Count = 3, Spread = 40, Bursts = 2, BurstDelay = 0.5, Speed = 26, Damage = 18, Size = 3, Color = C(240, 245, 255) },
			},
		},
		{
			Above = 0,
			Rest = { 0.7, 1.1 },
			Move = { Type = "Chase", Speed = 9 },
			Attacks = {
				{ Type = "Dash", Telegraph = 0.6, RepeatTelegraph = 0.4, Repeats = 2, Distance = { 30, 40 }, Speed = 65, Damage = 26 },
				{ Type = "Area", Target = "Self", Range = 16, Telegraph = 0.5, Radius = 12, Delay = 0.8, Damage = 24, WarnColor = FROST,
					Then = { Type = "Shoot", Pattern = "Radial", Telegraph = 0.4, Count = 12, Speed = 24, Damage = 14, Size = 2, Color = ICE } },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "SnowWolf", Count = 2, Max = 3 },
			},
		},
	},
}

-- Jefe: Reina de Hielo
T.FrostQueen = {
	Name = "Reina de Hielo",
	Boss = true,
	Health = 7000,
	Size = 6,
	Height = 11,
	Color = C(120, 200, 255),
	ContactDamage = 24,
	XP = 40,
	Phases = {
		{
			Above = 0.5,
			Rest = { 0.9, 1.4 },
			Move = { Type = "Keep", Speed = 9, Min = 18, Max = 28 },
			Attacks = {
				{ Type = "Shoot", Pattern = "Radial", Telegraph = 0.6, Count = 14, Bursts = 2, BurstDelay = 0.5, Rotate = 13, Speed = 24, Damage = 15, Color = ICE },
				{ Type = "Area", Telegraph = 0.5, Count = { 3, 4 }, FirstExact = true, Scatter = 8, Radius = 3.5, Delay = 1, Damage = 20, Bursts = 3, BurstDelay = 0.5, WarnColor = FROST },
				{ Type = "Teleport", Telegraph = 0.5, Distance = { 16, 24 }, ChainRest = 0.3 },
			},
		},
		{
			Above = 0,
			Rest = { 0.6, 1 },
			Move = { Type = "Keep", Speed = 11, Min = 16, Max = 26 },
			Attacks = {
				{ Type = "Shoot", Pattern = "Radial", Telegraph = 0.5, Count = 18, Bursts = 3, BurstDelay = 0.4, Rotate = 10, Bounces = 1, Speed = 26, Damage = 15, Color = ICE },
				-- Tormenta de hielo por toda la arena
				{ Type = "Area", Target = "Random", Telegraph = 0.6, Count = 10, Radius = 3, Delay = 1.2, Damage = 20, Bursts = 2, BurstDelay = 0.6, WarnColor = FROST },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "IceSlime", Count = 3, Max = 5 },
				{ Type = "Teleport", Telegraph = 0.4, Distance = { 16, 24 }, ChainRest = 0.2 },
			},
		},
	},
}

---------------------------------------------------------------------
-- 🏜️ Capítulo 5 · Desierto de los Reyes
---------------------------------------------------------------------

T.Scorpion = {
	Name = "Escorpión",
	Health = 110,
	Size = 3,
	Height = 2,
	Color = C(200, 120, 50),
	ContactDamage = 16,
	XP = 3,
	Cost = 3,
	Move = { Type = "Chase", Speed = 11 },
	Attacks = {
		-- Aguijón: tres púas venenosas
		{ Type = "Shoot", Cooldown = { 2.5, 3.5 }, Range = 30, Telegraph = 0.5, Count = 3, Spread = 25, Speed = 32, Damage = 14, Color = POISON },
		{ Type = "Dash", Cooldown = { 4, 5 }, Range = 22, Telegraph = 0.6, Distance = { 16, 22 }, Speed = 55, Damage = 18 },
	},
}
T.Mummy = {
	Name = "Momia",
	Role = "Blocker",
	Health = 260,
	Size = 2.6,
	Height = 5.5,
	Color = C(215, 200, 160),
	ContactDamage = 20,
	XP = 5,
	Cost = 5,
	Move = { Type = "Chase", Speed = 6 },
	-- Deja vendas malditas
	Trail = { Interval = 1, Radius = 2.2, Duration = 4, Dps = 8, Color = C(170, 140, 90) },
}
T.SandWorm = {
	Name = "Gusano de arena",
	Health = 150,
	Size = 3.2,
	Height = 4,
	Color = C(210, 170, 100),
	ContactDamage = 16,
	XP = 4,
	Cost = 4,
	Move = { Type = "Still" },
	Rest = 0.4,
	Attacks = {
		{ Type = "Burrow", Cooldown = { 3.5, 5 }, Telegraph = 0.5, Duration = { 1.2, 1.8 }, Emerge = { 6, 10 }, ChainRest = 0.2 },
		{ Type = "Shoot", Pattern = "Radial", Cooldown = { 3, 4 }, Telegraph = 0.5, Count = 8, Speed = 22, Damage = 14, Color = SAND },
	},
}
T.DesertArcher = {
	Name = "Arquero del desierto",
	Health = 90,
	Size = 2.4,
	Height = 5,
	Color = C(190, 140, 70),
	ContactDamage = 8,
	XP = 3,
	Cost = 3,
	Move = { Type = "Keep", Speed = 9, Min = 20, Max = 34 },
	Attacks = {
		{ Type = "Shoot", Cooldown = { 1.8, 2.4 }, Range = 55, Telegraph = 0.5, Count = 1, Bursts = 3, BurstDelay = 0.2, Speed = 46, Damage = 12, Color = BONE },
	},
}
T.SandSpirit = {
	Name = "Espíritu de arena",
	Health = 70,
	Size = 2.6,
	Float = 2,
	Color = C(240, 210, 140),
	ContactDamage = 12,
	XP = 2,
	Cost = 2,
	Move = { Type = "Chase", Speed = 12 },
	Attacks = {
		{ Type = "Teleport", Cooldown = { 3, 4.5 }, Telegraph = 0.4, Distance = { 10, 16 }, ChainRest = 0.2 },
		-- Remolino de arena bajo tus pies
		{ Type = "Area", Cooldown = { 3, 4 }, Range = 40, Telegraph = 0.4, Count = 1, Radius = 4, Delay = 1, Damage = 16, Zone = { Duration = 2, Dps = 8 }, WarnColor = SAND },
	},
}
T.Jackal = {
	Name = "Chacal",
	Health = 55,
	Size = 2.4,
	Color = C(180, 130, 80),
	ContactDamage = 12,
	XP = 2,
	Cost = 2,
	Move = { Type = "Chase", Speed = 14 },
}

-- Mini jefe: Gólem de arena
T.SandGolem = {
	Name = "Gólem de arena",
	Boss = true,
	Health = 2800,
	Size = 7,
	Height = 9,
	Color = C(215, 180, 110),
	ContactDamage = 22,
	XP = 20,
	Phases = {
		{
			Above = 0.5,
			Rest = { 1, 1.5 },
			Move = { Type = "Chase", Speed = 5 },
			Attacks = {
				{ Type = "Area", Target = "Self", Range = 16, Telegraph = 0.6, Radius = 12, Delay = 0.9, Damage = 24, WarnColor = SAND },
				{ Type = "Shoot", Telegraph = 0.6, Count = 5, Spread = 60, Bursts = 2, BurstDelay = 0.5, Speed = 28, Damage = 15, Size = 2, Color = SAND },
				{ Type = "Burrow", Telegraph = 0.6, Duration = { 1.2, 1.6 }, Emerge = { 6, 10 }, ChainRest = 0.3 },
			},
		},
		{
			Above = 0,
			Rest = { 0.7, 1.1 },
			Move = { Type = "Chase", Speed = 7 },
			Attacks = {
				{ Type = "Area", Target = "Random", Telegraph = 0.6, Count = 8, Radius = 3.5, Delay = 1.2, Damage = 18, Bursts = 2, BurstDelay = 0.7, Zone = { Duration = 2, Dps = 8 }, WarnColor = SAND },
				{ Type = "Burrow", Telegraph = 0.5, Duration = { 1, 1.4 }, Emerge = { 4, 8 }, ChainRest = 0.2,
					Then = { Type = "Shoot", Pattern = "Radial", Telegraph = 0.3, Count = 14, Speed = 24, Damage = 14, Color = SAND } },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "Jackal", Count = 3, Max = 5 },
			},
		},
	},
}

-- Jefe: Faraón Eterno
T.Pharaoh = {
	Name = "Faraón Eterno",
	Boss = true,
	Health = 9000,
	Size = 6,
	Height = 10,
	Color = C(240, 190, 60),
	ContactDamage = 26,
	XP = 50,
	Phases = {
		{
			Above = 0.5,
			Rest = { 0.9, 1.4 },
			Move = { Type = "Keep", Speed = 8, Min = 16, Max = 26 },
			Attacks = {
				-- Rayos del sol: abanico de proyectiles dorados
				{ Type = "Shoot", Telegraph = 0.6, Count = 7, Spread = 90, Bursts = 3, BurstDelay = 0.4, Speed = 30, Damage = 16, Color = SPARK },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "Mummy", Count = 2, Max = 3 },
				{ Type = "Teleport", Telegraph = 0.5, Distance = { 16, 24 }, ChainRest = 0.3 },
			},
		},
		{
			Above = 0,
			Rest = { 0.6, 1 },
			Move = { Type = "Keep", Speed = 10, Min = 14, Max = 24 },
			Attacks = {
				{ Type = "Shoot", Pattern = "Radial", Telegraph = 0.5, Count = 16, Bursts = 3, BurstDelay = 0.35, Rotate = 11, Speed = 26, Damage = 16, Color = SPARK },
				-- Tormenta de arena: zonas que queman por toda la arena
				{ Type = "Area", Target = "Random", Telegraph = 0.6, Count = 10, Radius = 3.5, Delay = 1.2, Damage = 20, Bursts = 2, BurstDelay = 0.6, Zone = { Duration = 3, Dps = 10 }, WarnColor = SAND },
				{ Type = "Dash", Telegraph = 0.7, RepeatTelegraph = 0.4, Repeats = 2, Distance = { 30, 40 }, Speed = 65, Damage = 30 },
				{ Type = "Summon", Telegraph = 0.7, Spawn = "Scorpion", Count = 2, Max = 4 },
			},
		},
	},
}

return T
