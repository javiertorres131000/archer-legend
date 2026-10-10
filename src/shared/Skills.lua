-- Skills (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Skills
-- Definición de las habilidades. El servidor usa Apply; el cliente solo nombre y descripción.
-- Para agregar una habilidad: sumá una entrada a List y, si hace falta, un campo nuevo en
-- PlayerData.newStats() y su efecto en Combat.

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
		Description = "Disparás un 15% más rápido.",
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
		Id = "FrontArrow",
		Name = "Flecha frontal",
		Description = "+1 flecha en paralelo.",
		Rarity = "Rare",
		Max = 3,
		Apply = function(s)
			s.frontArrows += 1
		end,
	},
	{
		Id = "Diagonal",
		Name = "Flechas diagonales",
		Description = "+2 flechas en diagonal.",
		Rarity = "Rare",
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
		Max = 3,
		Apply = function(s)
			s.ricochet += 1
		end,
	},
	{
		Id = "Fire",
		Name = "Flechas de fuego",
		Description = "Queman: 30% del daño por segundo durante 3 s.",
		Rarity = "Epic",
		Max = 1,
		Apply = function(s)
			s.burn = true
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
Skills.ById[Skills.Heal.Id] = Skills.Heal

return Skills
