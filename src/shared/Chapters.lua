-- Chapters (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Chapters
-- Definición de los capítulos. Está en Shared porque el lobby (cliente) muestra nombre,
-- descripción y estado de bloqueo; el servidor usa el resto para generar las oleadas.
--
-- Campos de presentación:
--   Id: identificador estable: es la clave con la que se guarda en el perfil (no cambiarlo)
--   Name, Description, Icon
--   UnlockedByDefault: disponible desde el principio
--   Requires: Id del capítulo que hay que ganar para desbloquearlo
--   Theme: decoración y materiales del mapa (Server/Arena.Props y Config.Map.Materials)
--   Lighting (opcional): luz propia en la partida (Client/Atmosphere): ClockTime, Ambient,
--     Brightness, HazeColor, HazeDensity, Weather ("Snow" | "Sand" | "Ash": partículas en la cámara)
--
-- Las oleadas no están escritas a mano: se generan al azar en cada partida.
-- Cada oleada tiene un "presupuesto" (Budget.Base + Budget.PerWave por oleada) que se gasta
-- comprando enemigos del Pool (cada uno cuesta su Cost en EnemyTypes).
--   Pool: Type = enemigo, From = primera oleada en la que puede salir, Weight = qué tan seguido.
--   Un enemigo nuevo sale al menos una vez en su oleada de debut, así se presenta.
--   En las oleadas de jefe el presupuesto se multiplica por Budget.BossWaveFactor.

local C = Color3.fromRGB

return {
	{
		Id = "forest",
		Theme = "forest", -- decoración de las salas (Arena.lua)
		Accent = C(90, 255, 160), -- neón de la sala y tinte de la luz (modo frenético)
		Name = "Bosque Maldito",
		Description = "Slimes, murciélagos y plantas venenosas. Lo protege el Guardián Treant.",
		Icon = "🌲",
		UnlockedByDefault = true,
		Floor = C(70, 100, 60),
		Wall = C(70, 50, 35),
		Waves = 10,
		HealthMult = 1,
		DamageMult = 1,
		Budget = { Base = 6, PerWave = 2, BossWaveFactor = 0.35 },
		Interval = { 1.3, 0.75 }, -- segundos entre spawns: primera oleada -> última
		-- Bosque quemado: atardecer naranja, bruma de humo y ceniza que cae. El mapa hecho a mano
		-- vive en el place de la Arena (ServerStorage/Maps/forest)
		Lighting = {
			ClockTime = 17.2,
			Ambient = C(105, 92, 88),
			Brightness = 2.5,
			HazeColor = C(125, 100, 85),
			HazeDensity = 0.3,
			Weather = "Ash",
		},
		-- Recompensas (Rewards.lua). Se ganan aunque pierdas, por oleada superada y jefe vencido.
		Rewards = {
			GoldPerWave = 10,
			LootMult = 1, -- multiplica el botín de los enemigos (Config.Loot)
			VictoryGold = 100,
			VictoryGems = 5,
			FirstClearGems = 50, -- solo la primera vez que lo ganás
			MiniBoss = { Gold = 30, Stones = 1 },
			Boss = { Gold = 60, Stones = 2 },
		},
		MiniBoss = { Wave = 5, Type = "KingSlime" },
		Boss = { Wave = 10, Type = "Treant" },
		Pool = {
			{ Type = "Grabber", From = 3, Weight = 0.6 }, -- te agarra: hace falta el compañero
			{ Type = "HordeSkeleton", From = 1, Weight = 3 },
			{ Type = "RushBeast", From = 2, Weight = 1.5 },
			{ Type = "HoodMage", From = 3, Weight = 1 },
			{ Type = "HeavyKnight", From = 4, Weight = 0.7 },
			{ Type = "EliteCaptain", From = 6, Weight = 0.4 },
			{ Type = "GreenSlime", From = 1, Weight = 4 },
			{ Type = "GreenBat", From = 1, Weight = 3 },
			{ Type = "WhiteSkull", From = 2, Weight = 3 },
			{ Type = "GreenPlant", From = 3, Weight = 2 },
			{ Type = "GreenStump", From = 4, Weight = 2 },
			{ Type = "Snake", From = 6, Weight = 2 },
			{ Type = "RedSlime", From = 6, Weight = 2 },
			{ Type = "GreyWolf", From = 7, Weight = 2 },
			{ Type = "Cactus", From = 8, Weight = 1 },
		},
	},
	{
		Id = "ruins",
		Theme = "ruins",
		Accent = C(255, 190, 60), -- neón de la sala y tinte de la luz (modo frenético)
		Name = "Ruinas Perdidas",
		Description = "Esqueletos, gólems y magos entre piedras antiguas. Duerme ahí el Gólem de Piedra.",
		Icon = "🏛",
		Requires = "forest",
		Floor = C(75, 72, 85),
		Wall = C(45, 40, 55),
		Waves = 10,
		HealthMult = 1.4,
		DamageMult = 1.15,
		Budget = { Base = 8, PerWave = 2.4, BossWaveFactor = 0.35 },
		Interval = { 1.2, 0.7 },
		Rewards = {
			GoldPerWave = 16,
			LootMult = 1.6, -- multiplica el botín de los enemigos (Config.Loot)
			VictoryGold = 160,
			VictoryGems = 8,
			FirstClearGems = 75,
			MiniBoss = { Gold = 50, Stones = 2 },
			Boss = { Gold = 100, Stones = 3 },
		},
		MiniBoss = { Wave = 5, Type = "CyclopsMage" },
		Boss = { Wave = 10, Type = "StoneGolem" },
		Pool = {
			{ Type = "Grabber", From = 3, Weight = 0.6 }, -- te agarra: hace falta el compañero
			{ Type = "HordeSkeleton", From = 1, Weight = 3 },
			{ Type = "RushBeast", From = 2, Weight = 1.5 },
			{ Type = "HoodMage", From = 3, Weight = 1 },
			{ Type = "HeavyKnight", From = 4, Weight = 0.7 },
			{ Type = "EliteCaptain", From = 6, Weight = 0.4 },
			{ Type = "WhiteSkull", From = 1, Weight = 3 },
			{ Type = "SkeletonArcher", From = 1, Weight = 3 },
			{ Type = "Spider", From = 2, Weight = 2 },
			{ Type = "WhiteGolem", From = 3, Weight = 2 },
			{ Type = "YellowSkull", From = 3, Weight = 2 },
			{ Type = "Worm", From = 4, Weight = 2 },
			{ Type = "BlueStump", From = 6, Weight = 2 },
			{ Type = "RedArcher", From = 6, Weight = 2 },
			{ Type = "TornadoMage", From = 7, Weight = 2 },
			{ Type = "BlueGolem", From = 8, Weight = 1 },
		},
	},
	{
		Id = "fortress",
		Theme = "fortress",
		Accent = C(255, 60, 120), -- neón de la sala y tinte de la luz (modo frenético)
		Name = "Fortaleza Demoníaca",
		Description = "Fuego, bombas y torres arcanas. Te espera el Demonio de Fuego.",
		Icon = "🔥",
		Requires = "ruins",
		Floor = C(75, 45, 40),
		Wall = C(40, 25, 25),
		Waves = 10,
		HealthMult = 1.8,
		DamageMult = 1.3,
		Budget = { Base = 9, PerWave = 2.6, BossWaveFactor = 0.35 },
		Interval = { 1.1, 0.65 },
		Rewards = {
			GoldPerWave = 25,
			LootMult = 2.5, -- multiplica el botín de los enemigos (Config.Loot)
			VictoryGold = 250,
			VictoryGems = 12,
			FirstClearGems = 100,
			MiniBoss = { Gold = 80, Stones = 3 },
			Boss = { Gold = 150, Stones = 5 },
		},
		MiniBoss = { Wave = 5, Type = "Reaper" },
		Boss = { Wave = 10, Type = "FlameDemon" },
		Pool = {
			{ Type = "Grabber", From = 3, Weight = 0.6 }, -- te agarra: hace falta el compañero
			{ Type = "HordeSkeleton", From = 1, Weight = 3 },
			{ Type = "RushBeast", From = 2, Weight = 1.5 },
			{ Type = "HoodMage", From = 3, Weight = 1 },
			{ Type = "HeavyKnight", From = 4, Weight = 0.7 },
			{ Type = "EliteCaptain", From = 6, Weight = 0.4 },
			{ Type = "FireSpirit", From = 1, Weight = 3 },
			{ Type = "RedBat", From = 1, Weight = 3 },
			{ Type = "WhiteBomb", From = 2, Weight = 2 },
			{ Type = "Crocodile", From = 3, Weight = 2 },
			{ Type = "BrownWolf", From = 3, Weight = 2 },
			{ Type = "BlueBomb", From = 4, Weight = 2 },
			{ Type = "FireMage", From = 6, Weight = 2 },
			{ Type = "OrbTower", From = 6, Weight = 1 },
			{ Type = "RedBomb", From = 7, Weight = 2 },
			{ Type = "ElectricTower", From = 8, Weight = 1 },
			{ Type = "BluePlant", From = 8, Weight = 1 },
		},
	},
	{
		Id = "glacier",
		Theme = "glacier",
		Accent = C(120, 210, 255), -- neón de la sala y tinte de la luz
		Name = "Glaciar Eterno",
		Description = "Lobos de las nieves, gólems de hielo y una tormenta que no para. Reina ahí la Reina de Hielo.",
		Icon = "❄️",
		Requires = "fortress",
		Floor = C(200, 225, 240),
		Wall = C(90, 120, 150),
		Waves = 10,
		HealthMult = 2.3,
		DamageMult = 1.45,
		Budget = { Base = 10, PerWave = 2.8, BossWaveFactor = 0.35 },
		Interval = { 1.05, 0.6 },
		Lighting = {
			ClockTime = 16.5,
			Ambient = C(150, 170, 200),
			Brightness = 2.4,
			HazeColor = C(215, 235, 255),
			HazeDensity = 0.38,
			Weather = "Snow",
		},
		Rewards = {
			GoldPerWave = 35,
			LootMult = 3.3,
			VictoryGold = 350,
			VictoryGems = 16,
			FirstClearGems = 125,
			MiniBoss = { Gold = 110, Stones = 4 },
			Boss = { Gold = 200, Stones = 6 },
		},
		MiniBoss = { Wave = 5, Type = "Yeti" },
		Boss = { Wave = 10, Type = "FrostQueen" },
		Pool = {
			{ Type = "Grabber", From = 3, Weight = 0.6 },
			{ Type = "HordeSkeleton", From = 1, Weight = 2 },
			{ Type = "HeavyKnight", From = 4, Weight = 0.7 },
			{ Type = "EliteCaptain", From = 6, Weight = 0.5 },
			{ Type = "IceSlime", From = 1, Weight = 4 },
			{ Type = "FrostBat", From = 1, Weight = 3 },
			{ Type = "Penguin", From = 2, Weight = 3 },
			{ Type = "SnowWolf", From = 3, Weight = 2 },
			{ Type = "IceMage", From = 4, Weight = 2 },
			{ Type = "IceGolem", From = 6, Weight = 1.2 },
			{ Type = "WhiteGolem", From = 7, Weight = 1 },
			{ Type = "BlueGolem", From = 8, Weight = 1 },
		},
	},
	{
		Id = "desert",
		Theme = "desert",
		Accent = C(255, 200, 80), -- neón de la sala y tinte de la luz
		Name = "Desierto de los Reyes",
		Description = "Escorpiones, momias y gusanos bajo la arena. En la pirámide espera el Faraón Eterno.",
		Icon = "🏜️",
		Requires = "glacier",
		Floor = C(225, 190, 130),
		Wall = C(150, 110, 70),
		Waves = 10,
		HealthMult = 2.9,
		DamageMult = 1.6,
		Budget = { Base = 11, PerWave = 3, BossWaveFactor = 0.35 },
		Interval = { 1, 0.55 },
		Lighting = {
			ClockTime = 13,
			Ambient = C(200, 170, 130),
			Brightness = 3.2,
			HazeColor = C(240, 210, 160),
			HazeDensity = 0.32,
			Weather = "Sand",
		},
		Rewards = {
			GoldPerWave = 48,
			LootMult = 4.3,
			VictoryGold = 480,
			VictoryGems = 20,
			FirstClearGems = 150,
			MiniBoss = { Gold = 150, Stones = 5 },
			Boss = { Gold = 280, Stones = 8 },
		},
		MiniBoss = { Wave = 5, Type = "SandGolem" },
		Boss = { Wave = 10, Type = "Pharaoh" },
		Pool = {
			{ Type = "Grabber", From = 3, Weight = 0.6 },
			{ Type = "HordeSkeleton", From = 1, Weight = 2 },
			{ Type = "RushBeast", From = 2, Weight = 1.5 },
			{ Type = "EliteCaptain", From = 6, Weight = 0.5 },
			{ Type = "Jackal", From = 1, Weight = 4 },
			{ Type = "SandSpirit", From = 1, Weight = 2.5 },
			{ Type = "Scorpion", From = 2, Weight = 2.5 },
			{ Type = "DesertArcher", From = 3, Weight = 2 },
			{ Type = "SandWorm", From = 4, Weight = 1.5 },
			{ Type = "Mummy", From = 5, Weight = 1.2 },
			{ Type = "Cactus", From = 6, Weight = 1.5 },
			{ Type = "Snake", From = 7, Weight = 2 },
		},
	},
}
