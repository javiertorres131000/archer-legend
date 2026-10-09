local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- Skills (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Skills
-- Definición de las habilidades. El servidor usa Apply; el cliente solo nombre y descripción.
-- Para agregar una habilidad: sumá una entrada a List y, si hace falta, un campo nuevo en
-- PlayerData.newStats() y su efecto en Combat.

local Skills = {}

Skills.RarityColors = {
	Common = Color3.fromRGB(170, 170, 180),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
}

Skills.RarityNames = {
	Common = "Común",
	Rare = "Rara",
	Epic = "Épica",
}

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
