--!strict
-- CrateItems (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > CrateItems
-- Rarezas y premios que pueden salir de las cajas (Crates.lua dice qué sale de cada caja).
-- Lo usan el servidor (tirada e inventario) y el cliente (menú, índice y animación).
--
-- Para agregar un premio: sumalo a la lista con un Id nuevo (no cambies el Id de uno ya
-- publicado: el inventario guardado usa ese Id) y ponelo en la tabla de alguna caja.
--   Kind: "Unit" (unidad con arma) | "Pet" (mascota de 4 patas) | "Character" (personaje)
--         | "Weapon" (arma especial: desbloquea el arma Weapon de Shared/Weapons.lua; se equipa
--           como arma, no como aspecto. Solo sale en la caja de armas)
--   Look: colores y accesorios del modelo de bloques que arma CrateModels:
--     Body / Accent / Skin / Pants: colores · Weapon: "Sword" | "Bow" | "Spear" | "Staff" | "Shield"
--     Acc: lista de "Crown" | "Horns" | "Halo" | "Wings" | "WizardHat" | "Helmet" | "Cape" | "Ears" | "Aura"
--          (mascotas, además: "LongEars" conejo · "Horn" cuerno de unicornio · "Snout" hocico de cerdo)
--     Neon = true: el color Accent brilla · Shape (mascotas): "Slime" | "Bird" (sin esto, de 4 patas)
-- Modelo propio: poné un Model con el Id exacto en ReplicatedStorage > CrateAssets > Prizes
-- y se usa ese en vez del de bloques (mirando hacia -Z, como el resto del juego).

local C = Color3.fromRGB

export type Rarity = { Id: string, Name: string, Color: Color3, Order: number }
export type Look = {
	Body: Color3,
	Accent: Color3?,
	Skin: Color3?,
	Pants: Color3?,
	Weapon: string?,
	Acc: { string }?,
	Neon: boolean?,
	Shape: string?, -- solo mascotas: "Slime" | "Bird" (sin esto, de 4 patas)
}
export type Prize = { Id: string, Name: string, Rarity: string, Kind: string, Look: Look, Weapon: string? }

local CrateItems = {}

-- De menor a mayor. Order sirve para comparar ("Legendary o más" = Order >= 5).
CrateItems.Rarities = {
	{ Id = "Common", Name = "Common", Color = C(200, 202, 210), Order = 1 },
	{ Id = "Uncommon", Name = "Uncommon", Color = C(90, 225, 115), Order = 2 },
	{ Id = "Rare", Name = "Rare", Color = C(60, 150, 255), Order = 3 },
	{ Id = "Epic", Name = "Epic", Color = C(178, 92, 255), Order = 4 },
	{ Id = "Legendary", Name = "Legendary", Color = C(255, 192, 40), Order = 5 },
	{ Id = "Mythic", Name = "Mythic", Color = C(255, 60, 60), Order = 6 },
	{ Id = "Secret", Name = "Secret", Color = C(255, 80, 190), Order = 7 },
} :: { Rarity }

CrateItems.RarityById = {} :: { [string]: Rarity }
for _, r in CrateItems.Rarities do
	CrateItems.RarityById[r.Id] = r
end

-- A partir de esta rareza el reveal es más fuerte (sacudón de cámara, más partículas)
CrateItems.BigRevealFrom = 5 -- Legendary

local SKIN = C(255, 214, 170)

CrateItems.List = {
	-- Common
	{ Id = "Recruit", Name = "Recluta", Rarity = "Common", Kind = "Unit", Look = { Body = C(130, 130, 140), Pants = C(80, 70, 60), Skin = SKIN, Weapon = "Sword" } },
	{ Id = "Chicken", Name = "Gallina", Rarity = "Common", Kind = "Pet", Look = { Body = C(245, 245, 240), Accent = C(230, 60, 50), Shape = "Bird" } },
	{ Id = "Villager", Name = "Aldeano", Rarity = "Common", Kind = "Character", Look = { Body = C(150, 110, 70), Pants = C(90, 80, 60), Skin = SKIN } },
	{ Id = "BabySlime", Name = "Slime Bebé", Rarity = "Common", Kind = "Pet", Look = { Body = C(110, 220, 90), Accent = C(60, 160, 50), Shape = "Slime" } },
	{ Id = "Squire", Name = "Escudero", Rarity = "Common", Kind = "Unit", Look = { Body = C(150, 120, 80), Pants = C(70, 60, 50), Skin = SKIN, Weapon = "Shield" } },
	{ Id = "Bunny", Name = "Conejo", Rarity = "Common", Kind = "Pet", Look = { Body = C(235, 225, 215), Accent = C(255, 170, 190), Acc = { "Ears" } } },
	-- Uncommon
	{ Id = "Spearman", Name = "Lancero", Rarity = "Uncommon", Kind = "Unit", Look = { Body = C(70, 150, 80), Pants = C(60, 60, 70), Skin = SKIN, Weapon = "Spear", Acc = { "Helmet" } } },
	{ Id = "Fox", Name = "Zorro", Rarity = "Uncommon", Kind = "Pet", Look = { Body = C(235, 130, 40), Accent = C(250, 245, 235), Acc = { "Ears" } } },
	{ Id = "Lumberjack", Name = "Leñador", Rarity = "Uncommon", Kind = "Character", Look = { Body = C(190, 40, 40), Accent = C(40, 30, 30), Pants = C(50, 70, 120), Skin = SKIN } },
	{ Id = "Owl", Name = "Búho", Rarity = "Uncommon", Kind = "Pet", Look = { Body = C(140, 100, 60), Accent = C(240, 200, 90), Shape = "Bird" } },
	{ Id = "Pirate", Name = "Pirata", Rarity = "Uncommon", Kind = "Character", Look = { Body = C(230, 230, 220), Accent = C(180, 30, 40), Pants = C(40, 40, 60), Skin = SKIN, Weapon = "Sword" } },
	-- Rare
	{ Id = "BlueArcher", Name = "Arquero Azul", Rarity = "Rare", Kind = "Unit", Look = { Body = C(50, 110, 220), Pants = C(40, 50, 90), Skin = SKIN, Weapon = "Bow", Acc = { "Cape" }, Accent = C(30, 70, 160) } },
	{ Id = "IceWolf", Name = "Lobo de Hielo", Rarity = "Rare", Kind = "Pet", Look = { Body = C(200, 230, 255), Accent = C(90, 180, 255), Acc = { "Ears" }, Neon = true } },
	{ Id = "Knight", Name = "Caballero", Rarity = "Rare", Kind = "Character", Look = { Body = C(170, 175, 190), Accent = C(60, 120, 230), Pants = C(110, 115, 130), Skin = SKIN, Acc = { "Helmet", "Cape" } } },
	{ Id = "Druid", Name = "Druida", Rarity = "Rare", Kind = "Unit", Look = { Body = C(60, 110, 50), Accent = C(150, 230, 90), Pants = C(70, 55, 35), Skin = SKIN, Weapon = "Staff", Acc = { "Cape" } } },
	-- Epic
	{ Id = "Sorcerer", Name = "Hechicero", Rarity = "Epic", Kind = "Character", Look = { Body = C(110, 50, 180), Accent = C(200, 120, 255), Pants = C(60, 30, 100), Skin = SKIN, Weapon = "Staff", Acc = { "WizardHat" }, Neon = true } },
	{ Id = "ShadowPanther", Name = "Pantera Sombría", Rarity = "Epic", Kind = "Pet", Look = { Body = C(35, 25, 50), Accent = C(190, 90, 255), Acc = { "Ears", "Aura" }, Neon = true } },
	{ Id = "Paladin", Name = "Paladín", Rarity = "Epic", Kind = "Unit", Look = { Body = C(240, 240, 245), Accent = C(240, 190, 60), Pants = C(200, 200, 210), Skin = SKIN, Weapon = "Shield", Acc = { "Helmet", "Cape" } } },
	{ Id = "Valkyrie", Name = "Valquiria", Rarity = "Epic", Kind = "Unit", Look = { Body = C(210, 215, 230), Accent = C(120, 200, 255), Pants = C(150, 155, 175), Skin = SKIN, Weapon = "Spear", Acc = { "Helmet", "Wings" } } },
	-- Legendary
	{ Id = "GoldenKing", Name = "Rey Dorado", Rarity = "Legendary", Kind = "Character", Look = { Body = C(250, 200, 60), Accent = C(180, 30, 40), Pants = C(140, 20, 30), Skin = SKIN, Acc = { "Crown", "Cape" } } },
	{ Id = "Phoenix", Name = "Fénix", Rarity = "Legendary", Kind = "Pet", Look = { Body = C(255, 120, 30), Accent = C(255, 220, 60), Acc = { "Wings", "Aura" }, Neon = true, Shape = "Bird" } },
	{ Id = "BabyDragon", Name = "Dragoncito", Rarity = "Legendary", Kind = "Pet", Look = { Body = C(60, 160, 90), Accent = C(255, 210, 70), Acc = { "Horns", "Wings" }, Neon = true } },
	-- Mythic
	{ Id = "FireDemon", Name = "Demonio Ígneo", Rarity = "Mythic", Kind = "Unit", Look = { Body = C(140, 20, 20), Accent = C(255, 110, 20), Pants = C(50, 10, 10), Skin = C(200, 50, 40), Weapon = "Sword", Acc = { "Horns", "Wings", "Aura" }, Neon = true } },
	{ Id = "CosmicMage", Name = "Mago Cósmico", Rarity = "Mythic", Kind = "Character", Look = { Body = C(40, 25, 80), Accent = C(150, 120, 255), Pants = C(30, 20, 60), Skin = C(25, 18, 40), Acc = { "Aura" }, Neon = true } },
	{ Id = "Seraphiel", Name = "Seraphiel", Rarity = "Mythic", Kind = "Character", Look = { Body = C(236, 232, 222), Accent = C(255, 200, 80), Pants = C(220, 220, 228), Skin = C(236, 232, 222), Acc = { "Aura" }, Neon = true } },
	{ Id = "Necromancer", Name = "Necromante", Rarity = "Mythic", Kind = "Character", Look = { Body = C(20, 60, 30), Accent = C(80, 255, 120), Pants = C(15, 35, 20), Skin = C(150, 200, 160), Acc = { "Aura" }, Neon = true } },
	{ Id = "LavaGolem", Name = "Gólem de Lava", Rarity = "Mythic", Kind = "Character", Look = { Body = C(60, 45, 40), Accent = C(255, 90, 10), Pants = C(45, 35, 30), Skin = C(70, 55, 50), Acc = { "Horns", "Aura" }, Neon = true } },
	{ Id = "VoidKnight", Name = "Caballero del Vacío", Rarity = "Mythic", Kind = "Character", Look = { Body = C(25, 20, 40), Accent = C(120, 60, 255), Pants = C(20, 15, 30), Skin = C(60, 50, 80), Weapon = "Sword", Acc = { "Helmet", "Cape", "Aura" }, Neon = true } },
	-- Secret
	{ Id = "FallenAngel", Name = "Ángel Caído", Rarity = "Secret", Kind = "Character", Look = { Body = C(255, 120, 190), Accent = C(255, 175, 220), Pants = C(120, 30, 70), Skin = SKIN, Weapon = "Staff", Acc = { "Halo", "Wings", "Aura" }, Neon = true } },
	{ Id = "CosmicCat", Name = "Gato Cósmico", Rarity = "Secret", Kind = "Pet", Look = { Body = C(60, 30, 110), Accent = C(255, 90, 200), Acc = { "Ears", "Halo", "Aura" }, Neon = true } },
	-- Armas especiales (caja de armas). Weapon = Id en Shared/Weapons.lua. En Look, Body es el
	-- metal de la empuñadura y Accent el color de la hoja (que brilla con Neon).
	{ Id = "CelestialBow", Name = "Arco Celestial", Rarity = "Mythic", Kind = "Weapon", Weapon = "CelestialBow", Look = { Body = C(35, 45, 70), Accent = C(255, 212, 110), Neon = true, Acc = { "Aura" } } },
	{ Id = "VoidBow", Name = "Arco del Vacío", Rarity = "Mythic", Kind = "Weapon", Weapon = "VoidBow", Look = { Body = C(24, 15, 40), Accent = C(170, 85, 255), Neon = true, Acc = { "Aura" } } },
	{ Id = "FrostKatana", Name = "Katana de Escarcha", Rarity = "Mythic", Kind = "Weapon", Weapon = "FrostKatana", Look = { Body = C(40, 55, 90), Accent = C(130, 215, 255), Neon = true, Acc = { "Aura" } } },
	{ Id = "InfernoBlade", Name = "Hoja Infernal", Rarity = "Mythic", Kind = "Weapon", Weapon = "InfernoBlade", Look = { Body = C(40, 18, 14), Accent = C(255, 120, 40), Neon = true, Acc = { "Aura" } } },
	{ Id = "CrimsonKatana", Name = "Katana Carmesí", Rarity = "Mythic", Kind = "Weapon", Weapon = "CrimsonKatana", Look = { Body = C(20, 12, 14), Accent = C(230, 20, 45), Neon = true, Acc = { "Aura" } } },
	{ Id = "VolcanicGauntlets", Name = "Guanteletes Volcánicos", Rarity = "Mythic", Kind = "Weapon", Weapon = "VolcanicGauntlets", Look = { Body = C(40, 26, 20), Accent = C(255, 110, 30), Neon = true, Acc = { "Aura" } } },
	-- Mascotas que salen solo de los huevos (Crates.lua, Type = "Egg")
	{ Id = "Puppy", Name = "Perrito", Rarity = "Common", Kind = "Pet", Look = { Body = C(196, 140, 90), Accent = C(245, 225, 200), Acc = { "Ears" } } },
	{ Id = "Kitten", Name = "Gatito", Rarity = "Common", Kind = "Pet", Look = { Body = C(150, 150, 160), Accent = C(255, 190, 200), Acc = { "Ears" } } },
	{ Id = "Piglet", Name = "Cerdito", Rarity = "Uncommon", Kind = "Pet", Look = { Body = C(255, 175, 190), Accent = C(240, 120, 150), Acc = { "Snout", "Ears" } } },
	{ Id = "Parrot", Name = "Loro", Rarity = "Rare", Kind = "Pet", Look = { Body = C(40, 200, 90), Accent = C(255, 60, 40), Shape = "Bird" } },
	{ Id = "LavaSlime", Name = "Slime de Lava", Rarity = "Rare", Kind = "Pet", Look = { Body = C(255, 110, 30), Accent = C(255, 220, 80), Shape = "Slime", Neon = true } },
	{ Id = "Unicorn", Name = "Unicornio", Rarity = "Epic", Kind = "Pet", Look = { Body = C(255, 250, 255), Accent = C(220, 130, 255), Acc = { "Horn", "Ears", "Aura" }, Neon = true } },
	{ Id = "StormDragon", Name = "Dragón de Tormenta", Rarity = "Mythic", Kind = "Pet", Look = { Body = C(30, 40, 90), Accent = C(90, 220, 255), Acc = { "Horns", "Wings", "Aura" }, Neon = true } },
} :: { Prize }

CrateItems.ById = {} :: { [string]: Prize }
for _, p in CrateItems.List do
	CrateItems.ById[p.Id] = p
end

-- Espacio donde se equipa: las mascotas en "Pet"; personajes y unidades en "Character".
-- Las armas van en "Weapon", que no se guarda acá: es el arma elegida (Data.Weapon, WeaponService).
CrateItems.Slots = { "Pet", "Character" }
function CrateItems.slotOf(prize: Prize): string
	if prize.Kind == "Weapon" then
		return "Weapon"
	end
	return if prize.Kind == "Pet" then "Pet" else "Character"
end

-- Mayúsculas que respetan los acentos (string.upper deja "Dragón" como "DRAGóN")
local ACCENTS: { { string } } = { { "á", "Á" }, { "é", "É" }, { "í", "Í" }, { "ó", "Ó" }, { "ú", "Ú" }, { "ñ", "Ñ" }, { "ü", "Ü" } }
function CrateItems.upper(s: string): string
	local out = string.upper(s)
	for _, pair in ACCENTS do
		out = string.gsub(out, pair[1], pair[2])
	end
	return out
end

function CrateItems.rarity(id: string): Rarity
	return CrateItems.RarityById[id] or CrateItems.Rarities[1]
end

function CrateItems.rarityOf(prizeId: string): Rarity
	local prize = CrateItems.ById[prizeId]
	return CrateItems.rarity(if prize then prize.Rarity else "Common")
end

-- Color de una rareza; Secret pasa por rosa → rojo → violeta con el tiempo (now en segundos)
function CrateItems.color(rarityId: string, now: number?): Color3
	local r = CrateItems.rarity(rarityId)
	if rarityId == "Secret" and now then
		local t = (math.sin(now * 2.2) + 1) / 2
		return C(255, 70, 160):Lerp(C(255, 40, 70), t)
	end
	return r.Color
end

return CrateItems
