--!strict
-- Crates (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Crates
-- Las cajas que se compran en la plaza volcánica del lobby: precio, color y tabla de premios.
-- El servidor tira el premio con estas probabilidades (CrateService); el cliente las muestra
-- en "DROP RATES". Las dos partes leen este mismo módulo, así que lo que ves es lo que hay.
--
-- Dos tipos: Type = "Crate" (cofres de skins: solo personajes y unidades) y Type = "Egg"
-- (huevos de mascotas: solo mascotas). Cada tipo tiene su fila de plataformas en la plaza, su
-- pestaña en el menú y su animación (CrateCinematic / EggCinematic). test_crates lo revisa.
--
-- CÓMO CAMBIAR:
--   · Cómo se paga: PayWith = "Coins" (monedas del juego, botón OPEN) o "Robux" (solo Robux,
--     botón R$). Una caja se paga de una sola forma.
--   · Precio en monedas: Price (moneda Config.Crates.Currency, el oro del perfil). En las de
--     Robux no se usa (dejalo en 0).
--   · Robux: ProductId = el Id de un Developer Product (Creator Dashboard › tu experiencia ›
--     Monetization › Developer Products › Create). El precio en Robux se pone ALLÁ, no acá.
--     Mientras sea 0, la caja de Robux se ve pero dice "Pronto" y no se puede abrir.
--   · Probabilidades: Chance de cada fila, en %. Pueden no sumar 100: se reparten en proporción
--     (el porcentaje que se ve es Chance / suma de la caja). test_crates.luau avisa si no suman 100.
--   · Premios: el Id tiene que existir en CrateItems.lua. Se puede repetir en varias cajas.
--   · Caja nueva: sumá una entrada con Id nuevo; la plaza agrega su plataforma sola.

local CrateItems = require(script.Parent.CrateItems)

local C = Color3.fromRGB

export type Entry = { Prize: string, Chance: number }
export type Crate = {
	Id: string,
	Name: string,
	Type: string, -- "Crate" (cofre de skins) | "Egg" (huevo de mascotas)
	PayWith: string, -- "Coins" | "Robux"
	Price: number, -- en monedas (solo PayWith = "Coins")
	ProductId: number, -- Developer Product (solo PayWith = "Robux"; 0 = todavía sin producto)
	Color: Color3, -- color principal (neón, brillo y título)
	Dark: Color3, -- madera / cuerpo del cofre
	Prizes: { Entry },
}
export type Rate = { Prize: string, Percent: number }

local Crates = {}

Crates.List = {
	-- Cofres de skins (personajes y unidades)
	{
		Id = "Common",
		Name = "Common Crate",
		Type = "Crate",
		PayWith = "Coins",
		Price = 100,
		ProductId = 0,
		Color = C(225, 228, 235),
		Dark = C(120, 120, 128),
		Prizes = {
			{ Prize = "Recruit", Chance = 40 },
			{ Prize = "Villager", Chance = 35 },
			{ Prize = "Spearman", Chance = 14 },
			{ Prize = "Lumberjack", Chance = 8.5 },
			{ Prize = "BlueArcher", Chance = 2.2 },
			{ Prize = "Knight", Chance = 0.25 },
			{ Prize = "Sorcerer", Chance = 0.05 },
		},
	},
	{
		Id = "Rare",
		Name = "Rare Crate",
		Type = "Crate",
		PayWith = "Coins",
		Price = 500,
		ProductId = 0,
		Color = C(60, 145, 255),
		Dark = C(30, 60, 130),
		Prizes = {
			{ Prize = "Spearman", Chance = 28 },
			{ Prize = "Villager", Chance = 25 },
			{ Prize = "Lumberjack", Chance = 25 },
			{ Prize = "BlueArcher", Chance = 12 },
			{ Prize = "Knight", Chance = 7 },
			{ Prize = "Sorcerer", Chance = 2.5 },
			{ Prize = "Paladin", Chance = 0.45 },
			{ Prize = "GoldenKing", Chance = 0.05 },
		},
	},
	{
		Id = "Epic",
		Name = "Epic Crate",
		Type = "Crate",
		PayWith = "Coins",
		Price = 25000,
		ProductId = 0,
		Color = C(175, 85, 255),
		Dark = C(70, 30, 120),
		Prizes = {
			{ Prize = "Lumberjack", Chance = 25 },
			{ Prize = "BlueArcher", Chance = 25 },
			{ Prize = "Knight", Chance = 25 },
			{ Prize = "Sorcerer", Chance = 15 },
			{ Prize = "Paladin", Chance = 8 },
			{ Prize = "GoldenKing", Chance = 1.7 },
			{ Prize = "FireDemon", Chance = 0.3 },
		},
	},
	{
		Id = "Legendary",
		Name = "Legendary Crate",
		Type = "Crate",
		PayWith = "Robux",
		Price = 0,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(255, 195, 45),
		Dark = C(130, 85, 20),
		Prizes = {
			{ Prize = "Knight", Chance = 30 },
			{ Prize = "Sorcerer", Chance = 25 },
			{ Prize = "Paladin", Chance = 25 },
			{ Prize = "GoldenKing", Chance = 14 },
			{ Prize = "FireDemon", Chance = 4.5 },
			{ Prize = "LavaGolem", Chance = 1.495 },
			{ Prize = "FallenAngel", Chance = 0.005 },
		},
	},
	{
		Id = "Secret",
		Name = "Secret Crate",
		Type = "Crate",
		PayWith = "Robux",
		Price = 0,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(255, 70, 150),
		Dark = C(120, 20, 50),
		Prizes = {
			{ Prize = "Paladin", Chance = 35 },
			{ Prize = "GoldenKing", Chance = 35 },
			{ Prize = "FireDemon", Chance = 18 },
			{ Prize = "LavaGolem", Chance = 11.5 },
			{ Prize = "FallenAngel", Chance = 0.5 },
		},
	},
	-- Huevos de mascotas
	{
		Id = "CommonEgg",
		Name = "Common Egg",
		Type = "Egg",
		PayWith = "Coins",
		Price = 150,
		ProductId = 0,
		Color = C(235, 240, 225),
		Dark = C(120, 170, 90),
		Prizes = {
			{ Prize = "Chicken", Chance = 30 },
			{ Prize = "Puppy", Chance = 28 },
			{ Prize = "Kitten", Chance = 22 },
			{ Prize = "BabySlime", Chance = 12 },
			{ Prize = "Fox", Chance = 5 },
			{ Prize = "Bunny", Chance = 2.5 },
			{ Prize = "IceWolf", Chance = 0.45 },
			{ Prize = "ShadowPanther", Chance = 0.05 },
		},
	},
	{
		Id = "RareEgg",
		Name = "Rare Egg",
		Type = "Egg",
		PayWith = "Coins",
		Price = 750,
		ProductId = 0,
		Color = C(70, 160, 255),
		Dark = C(25, 55, 120),
		Prizes = {
			{ Prize = "Fox", Chance = 22 },
			{ Prize = "Bunny", Chance = 20 },
			{ Prize = "Piglet", Chance = 18 },
			{ Prize = "Puppy", Chance = 15 },
			{ Prize = "Kitten", Chance = 15 },
			{ Prize = "IceWolf", Chance = 6 },
			{ Prize = "Parrot", Chance = 3.5 },
			{ Prize = "ShadowPanther", Chance = 0.45 },
			{ Prize = "Phoenix", Chance = 0.05 },
		},
	},
	{
		Id = "EpicEgg",
		Name = "Epic Egg",
		Type = "Egg",
		PayWith = "Coins",
		Price = 20000,
		ProductId = 0,
		Color = C(185, 95, 255),
		Dark = C(55, 20, 90),
		Prizes = {
			{ Prize = "IceWolf", Chance = 25 },
			{ Prize = "Parrot", Chance = 20 },
			{ Prize = "Fox", Chance = 15 },
			{ Prize = "Piglet", Chance = 15 },
			{ Prize = "LavaSlime", Chance = 15 },
			{ Prize = "ShadowPanther", Chance = 7 },
			{ Prize = "Unicorn", Chance = 2.5 },
			{ Prize = "Phoenix", Chance = 0.45 },
			{ Prize = "BabyDragon", Chance = 0.05 },
		},
	},
	{
		Id = "MythicEgg",
		Name = "Mythic Egg",
		Type = "Egg",
		PayWith = "Robux",
		Price = 0,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(255, 200, 60),
		Dark = C(25, 20, 30),
		Prizes = {
			{ Prize = "ShadowPanther", Chance = 25 },
			{ Prize = "IceWolf", Chance = 20 },
			{ Prize = "LavaSlime", Chance = 20 },
			{ Prize = "Unicorn", Chance = 18 },
			{ Prize = "Phoenix", Chance = 9 },
			{ Prize = "BabyDragon", Chance = 6 },
			{ Prize = "StormDragon", Chance = 1.995 },
			{ Prize = "CosmicCat", Chance = 0.005 },
		},
	},
} :: { Crate }

Crates.ById = {} :: { [string]: Crate }
for _, crate in Crates.List do
	Crates.ById[crate.Id] = crate
end

local function total(crate: Crate): number
	local sum = 0
	for _, e in crate.Prizes do
		if CrateItems.ById[e.Prize] and e.Chance > 0 then
			sum += e.Chance
		end
	end
	return sum
end

-- Porcentajes reales de cada premio (suman 100), en el orden de la tabla
function Crates.rates(crate: Crate): { Rate }
	local sum = total(crate)
	local list = {}
	for _, e in crate.Prizes do
		if CrateItems.ById[e.Prize] and e.Chance > 0 and sum > 0 then
			table.insert(list, { Prize = e.Prize, Percent = e.Chance / sum * 100 })
		end
	end
	return list
end

-- Premio para un número al azar r en [0, 1): tirada ponderada por Chance
function Crates.pick(crate: Crate, r: number): string?
	local sum = total(crate)
	if sum <= 0 then
		return nil
	end
	local target = math.clamp(r, 0, 0.999999999) * sum
	local last: string? = nil
	for _, e in crate.Prizes do
		if CrateItems.ById[e.Prize] and e.Chance > 0 then
			last = e.Prize
			target -= e.Chance
			if target < 0 then
				return e.Prize
			end
		end
	end
	return last -- por redondeo
end

-- ¿Es un huevo de mascotas?
function Crates.isEgg(crate: Crate): boolean
	return crate.Type == "Egg"
end

-- ¿Esta caja se abre con monedas o con Robux?
function Crates.paysWithRobux(crate: Crate): boolean
	return crate.PayWith == "Robux"
end

-- "45.00%" · "0.0050%"
function Crates.formatPercent(p: number): string
	if p >= 0.1 then
		return string.format("%.2f%%", p)
	end
	return string.format("%.4f%%", p)
end

-- "15,000"
function Crates.formatPrice(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

return Crates
