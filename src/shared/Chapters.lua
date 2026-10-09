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
		-- Recompensas (Rewards.lua). Se ganan aunque pierdas, por oleada superada y jefe vencido.
		Rewards = {
			GoldPerWave = 10,
			VictoryGold = 100,
			VictoryGems = 5,
			FirstClearGems = 50, -- solo la primera vez que lo ganás
			MiniBoss = { Gold = 30, Stones = 1 },
			Boss = { Gold = 60, Stones = 2 },
		},
		MiniBoss = { Wave = 5, Type = "KingSlime" },
		Boss = { Wave = 10, Type = "Treant" },
		Pool = {
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
			VictoryGold = 160,
			VictoryGems = 8,
			FirstClearGems = 75,
			MiniBoss = { Gold = 50, Stones = 2 },
			Boss = { Gold = 100, Stones = 3 },
		},
		MiniBoss = { Wave = 5, Type = "CyclopsMage" },
		Boss = { Wave = 10, Type = "StoneGolem" },
		Pool = {
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
			VictoryGold = 250,
			VictoryGems = 12,
			FirstClearGems = 100,
			MiniBoss = { Gold = 80, Stones = 3 },
			Boss = { Gold = 150, Stones = 5 },
		},
		MiniBoss = { Wave = 5, Type = "Reaper" },
		Boss = { Wave = 10, Type = "FlameDemon" },
		Pool = {
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
}
