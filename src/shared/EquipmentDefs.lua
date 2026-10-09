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
return Defs
