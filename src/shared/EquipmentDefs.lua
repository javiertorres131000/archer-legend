-- Bonificaciones permanentes acotadas; las habilidades de partida multiplican esta base.
local Defs = {}
Defs.Slots = { "Weapon", "Helmet", "Armor", "Ring", "Amulet", "Boots" }
Defs.SlotNames = { Weapon = "Arma", Helmet = "Casco", Armor = "Armadura", Ring = "Anillo", Amulet = "Amuleto", Boots = "Botas" }
Defs.List = {
	{ Id = "HunterBow", Name = "Arco del cazador", Slot = "Weapon", Stat = "damage", Bonus = 0.035, Set = "Hunter" },
	{ Id = "HunterHood", Name = "Capucha del cazador", Slot = "Helmet", Stat = "maxHealth", Bonus = 0.025, Set = "Hunter" },
	{ Id = "HunterVest", Name = "Chaleco del cazador", Slot = "Armor", Stat = "maxHealth", Bonus = 0.035, Set = "Hunter" },
	{ Id = "HunterRing", Name = "Anillo del cazador", Slot = "Ring", Stat = "critChance", Bonus = 0.005, Set = "Hunter" },
	{ Id = "HunterCharm", Name = "Amuleto del cazador", Slot = "Amulet", Stat = "pickupRadius", Bonus = 0.035, Set = "Hunter" },
	{ Id = "HunterBoots", Name = "Botas del cazador", Slot = "Boots", Stat = "walkSpeed", Bonus = 0.015, Set = "Hunter" },
	{ Id = "EmberBow", Name = "Arco de las brasas", Slot = "Weapon", Stat = "damage", Bonus = 0.035, Set = "Ember" },
	{ Id = "EmberHelm", Name = "Yelmo de las brasas", Slot = "Helmet", Stat = "maxHealth", Bonus = 0.025, Set = "Ember" },
	{ Id = "EmberPlate", Name = "Coraza de las brasas", Slot = "Armor", Stat = "maxHealth", Bonus = 0.035, Set = "Ember" },
	{ Id = "EmberRing", Name = "Anillo de las brasas", Slot = "Ring", Stat = "critChance", Bonus = 0.005, Set = "Ember" },
	{ Id = "EmberCharm", Name = "Amuleto de las brasas", Slot = "Amulet", Stat = "pickupRadius", Bonus = 0.035, Set = "Ember" },
	{ Id = "EmberBoots", Name = "Botas de las brasas", Slot = "Boots", Stat = "walkSpeed", Bonus = 0.015, Set = "Ember" },
}
Defs.ById = {}
for _, def in Defs.List do Defs.ById[def.Id] = def end
Defs.MaxLevel = 10
Defs.MaxInventory = 150
function Defs.cost(item) return 60 * item.Level, item.Level end
function Defs.power(item, rank) return rank * (1 + (item.Level - 1) * 0.08) end

-- Para la interfaz
Defs.SlotIcons = { Weapon = "🏹", Helmet = "⛑️", Armor = "🛡️", Ring = "💍", Amulet = "📿", Boots = "👢" }
Defs.StatNames = { damage = "daño", maxHealth = "vida", critChance = "crítico", pickupRadius = "imán", walkSpeed = "velocidad" }
Defs.SetNames = { Hunter = "Cazador", Ember = "Brasas" }
Defs.SetBonusText = {
	Hunter = { [3] = "+10% imán", [6] = "+3% crítico" },
	Ember = { [3] = "+15% quemadura", [6] = "flechas de fuego" },
}
-- Tope de cada bonificación sumada (para que el equipo no rompa el balance)
Defs.Caps = { damage = 0.3, maxHealth = 0.4, walkSpeed = 0.15, pickupRadius = 0.4, critChance = 0.1 }

-- Bonificación de una pieza (sin topes): 0.035 = +3,5%
function Defs.itemBonus(item, rarityRank)
	local def = Defs.ById[item.Id]
	return if def then def.Bonus * Defs.power(item, rarityRank) else 0
end

-- Suma lo equipado: bonificaciones por stat (ya con tope) y piezas de cada conjunto.
-- La usan el servidor (Equipment.apply) y la pantalla de equipo, así muestran lo mismo.
function Defs.summary(inventory, equipment, rarityIndex)
	local byUid = {}
	for _, item in inventory do byUid[item.Uid] = item end
	local bonus, sets = {}, {}
	for _, slot in Defs.Slots do
		local item = byUid[equipment[slot]]
		local def = item and Defs.ById[item.Id]
		if def and def.Slot == slot then
			bonus[def.Stat] = (bonus[def.Stat] or 0) + Defs.itemBonus(item, rarityIndex(item.Rarity))
			sets[def.Set] = (sets[def.Set] or 0) + 1
		end
	end
	for stat, cap in Defs.Caps do
		bonus[stat] = math.min(cap, bonus[stat] or 0)
	end
	return bonus, sets
end
return Defs
