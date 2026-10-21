-- Skills (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Skills
-- Definición de las habilidades. El servidor usa Apply; el cliente solo nombre y descripción.
-- Para agregar una habilidad: sumá una entrada a List y, si hace falta, un campo nuevo en
-- PlayerData.newStats() y su efecto en Combat.
--
-- Mazos por arma (Shared/Weapons.lua): Weapon = nil → común (cualquier arma); "Bow", "Sword" o
-- "Fists" → solo aparece si jugás con esa arma. Las del mazo del arma salen más seguido
-- (Config.Progression.WeaponDeckWeight).
-- Requires = N: legendarias; solo aparecen si ya tenés N habilidades distintas del mazo de tu arma.

local Skills = {}
local Rarities = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rarities"))

Skills.RarityColors = Rarities.Colors
Skills.RarityNames = Rarities.Names

Skills.List = {
	{
		Id = "Damage",
		Name = "Fuerza",
		Description = "+20% de daño.",
		Rarity = "Common",
		Max = 5,
		Apply = function(s)
			s.damage *= 1.2
		end,
	},
	{
		Id = "AttackSpeed",
		Name = "Cadencia",
		Description = "Atacás un 15% más rápido.",
		Rarity = "Common",
		Max = 5,
		Apply = function(s)
			s.attackInterval *= 0.85
		end,
	},
	{
		Id = "Vitality",
		Name = "Vitalidad",
		Description = "+20 de vida máxima y te cura 20.",
		Rarity = "Common",
		Max = 5,
		Heal = 20,
		Apply = function(s)
			s.maxHealth += 20
		end,
	},
	{
		Id = "Magnet",
		Name = "Imán",
		Description = "Atraés los orbes de XP desde un 40% más lejos.",
		Rarity = "Common",
		Max = 3,
		Apply = function(s)
			s.pickupRadius *= 1.4
		end,
	},
	{
		Id = "Crit",
		Name = "Ojo de halcón",
		Description = "+8% de probabilidad de crítico.",
		Rarity = "Rare",
		Max = 4,
		Apply = function(s)
			s.critChance += 0.08
		end,
	},
	{
		Id = "CritDamage",
		Name = "Golpe brutal",
		Description = "Los críticos hacen +50% de daño.",
		Rarity = "Epic",
		Max = 2,
		Apply = function(s)
			s.critMultiplier += 0.5
		end,
	},
	{
		Id = "Fire",
		Name = "Encantamiento ígneo",
		Description = "Tus golpes queman: 30% del daño por segundo durante 3 s.",
		Rarity = "Epic",
		Max = 1,
		Apply = function(s)
			s.burn = true
		end,
	},

	-------------------------------------------------------------------
	-- 🏹 Arco
	-------------------------------------------------------------------
	{
		Id = "FrontArrow",
		Name = "Flecha frontal",
		Description = "+1 flecha en paralelo.",
		Rarity = "Rare",
		Weapon = "Bow",
		Max = 3,
		Apply = function(s)
			s.frontArrows += 1
		end,
	},
	{
		Id = "Diagonal",
		Name = "Abanico",
		Description = "+2 flechas en diagonal.",
		Rarity = "Rare",
		Weapon = "Bow",
		Max = 2,
		Apply = function(s)
			s.diagonalPairs += 1
		end,
	},
	{
		Id = "Pierce",
		Name = "Perforación",
		Description = "Las flechas atraviesan 1 enemigo más.",
		Rarity = "Rare",
		Weapon = "Bow",
		Max = 3,
		Apply = function(s)
			s.pierce += 1
		end,
	},
	{
		Id = "Ricochet",
		Name = "Rebote",
		Description = "Las flechas rebotan a 1 enemigo cercano más.",
		Rarity = "Epic",
		Weapon = "Bow",
		Max = 3,
		Apply = function(s)
			s.ricochet += 1
		end,
	},
	{
		Id = "BackArrow",
		Name = "Flecha trasera",
		Description = "También disparás una flecha hacia atrás: cubrí tu espalda.",
		Rarity = "Rare",
		Weapon = "Bow",
		Max = 2,
		Apply = function(s)
			s.backArrows += 1
		end,
	},
	{
		Id = "ChargedShot",
		Name = "Tiro cargado",
		Description = "Cada 4º disparo es una flecha gigante: triple de daño y atraviesa todo.",
		Rarity = "Epic",
		Weapon = "Bow",
		Max = 1,
		Apply = function(s)
			s.chargedEvery = 4
		end,
	},
	{
		Id = "HunterEye",
		Name = "Ojo del cazador",
		Description = "+25% de daño a enemigos lejanos (a más de 30 studs).",
		Rarity = "Rare",
		Weapon = "Bow",
		Max = 2,
		Apply = function(s)
			s.farDamage += 0.25
		end,
	},
	{
		Id = "ArrowRain",
		Name = "Lluvia de flechas",
		Description = "Cada 6 s caen flechas del cielo sobre hasta 8 enemigos cercanos.",
		Rarity = "Legendary",
		Weapon = "Bow",
		Requires = 2,
		Max = 1,
		Apply = function(s)
			s.arrowRain = true
		end,
	},

	-------------------------------------------------------------------
	-- ⚔️ Espada
	-------------------------------------------------------------------
	{
		Id = "WideBlade",
		Name = "Hoja ancha",
		Description = "+20° de arco en cada tajo.",
		Rarity = "Common",
		Weapon = "Sword",
		Max = 3,
		Apply = function(s)
			s.meleeArc += 20
		end,
	},
	{
		Id = "LongBlade",
		Name = "Hoja larga",
		Description = "+2 studs de alcance.",
		Rarity = "Rare",
		Weapon = "Sword",
		Max = 3,
		Apply = function(s)
			s.meleeRange += 2
		end,
	},
	{
		Id = "Whirlwind",
		Name = "Torbellino",
		Description = "Cada 5º golpe es un giro de 360° alrededor tuyo.",
		Rarity = "Epic",
		Weapon = "Sword",
		Max = 1,
		Apply = function(s)
			s.whirlEvery = 5
		end,
	},
	{
		Id = "Execute",
		Name = "Ejecución",
		Description = "+60% de daño a enemigos con menos del 30% de vida.",
		Rarity = "Rare",
		Weapon = "Sword",
		Max = 2,
		Apply = function(s)
			s.executeBonus += 0.6
		end,
	},
	{
		Id = "Bloodlust",
		Name = "Sed de sangre",
		Description = "Cada enemigo que matás con la espada te cura 2 de vida.",
		Rarity = "Rare",
		Weapon = "Sword",
		Max = 3,
		Apply = function(s)
			s.healOnKill += 2
		end,
	},
	{
		Id = "Judgment",
		Name = "Juicio",
		Description = "Cada 8 s, una espada gigante cae frente a vos y aplasta todo en un círculo grande.",
		Rarity = "Legendary",
		Weapon = "Sword",
		Requires = 2,
		Max = 1,
		Apply = function(s)
			s.judgment = true
		end,
	},

	-------------------------------------------------------------------
	-- 👊 Puños
	-------------------------------------------------------------------
	{
		Id = "Combo",
		Name = "Combo",
		Description = "Cada golpe seguido suma +5% de daño (hasta +50%). Se corta si pasás 1,5 s sin pegar.",
		Rarity = "Common",
		Weapon = "Fists",
		Max = 2,
		Apply = function(s)
			s.comboStep += 0.05
		end,
	},
	{
		Id = "Uppercut",
		Name = "Uppercut",
		Description = "Cada 3er golpe lanza lejos al enemigo y lo aturde 0,5 s.",
		Rarity = "Rare",
		Weapon = "Fists",
		Max = 1,
		Apply = function(s)
			s.uppercutEvery = 3
		end,
	},
	{
		Id = "SwiftFeet",
		Name = "Pies veloces",
		Description = "+8% de velocidad de movimiento.",
		Rarity = "Common",
		Weapon = "Fists",
		Max = 3,
		Apply = function(s)
			s.walkSpeed *= 1.08
		end,
	},
	{
		Id = "ThousandFists",
		Name = "Ráfaga de mil puños",
		Description = "Cada 10 s: 2 segundos de golpes al triple de velocidad y con arco de 120°.",
		Rarity = "Legendary",
		Weapon = "Fists",
		Requires = 2,
		Max = 1,
		Apply = function(s)
			s.thousandFists = true
		end,
	},
}

-- Relleno cuando ya no quedan habilidades por subir.
Skills.Heal = {
	Id = "Heal",
	Name = "Curación",
	Description = "Recuperás el 40% de la vida.",
	Rarity = "Common",
	Max = math.huge,
	HealFraction = 0.4,
	Apply = function(_s) end,
}

Skills.ById = {}
for _, def in Skills.List do
	Skills.ById[def.Id] = def
end

-- ¿Esta habilidad puede salir con esta arma? (común o del mazo del arma)
function Skills.forWeapon(def: any, weapon: string?): boolean
	return def.Weapon == nil or def.Weapon == (weapon or "Bow")
end

-- Habilidades distintas del mazo del arma que ya tiene (para las legendarias)
function Skills.deckCount(stacks: { [string]: number }, weapon: string?): number
	local n = 0
	for id, count in stacks do
		local def = Skills.ById[id]
		if def and count > 0 and def.Weapon ~= nil and def.Weapon == (weapon or "Bow") and def.Rarity ~= "Legendary" then
			n += 1
		end
	end
	return n
end
Skills.ById[Skills.Heal.Id] = Skills.Heal

return Skills
