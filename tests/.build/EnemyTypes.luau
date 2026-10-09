local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
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
-- Tipos: Dash, Shoot, Area, Breath, Teleport, Burrow, Summon (ver EnemyAI).

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
	Float = 2.5,
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
	Float = 2.5,
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
	Move = { Type = "Still" },
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
	Move = { Type = "Still" },
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
	Height = 3.4,
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
	Height = 3.4,
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

return T
