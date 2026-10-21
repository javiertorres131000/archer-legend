--!strict
-- Crates (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Crates
-- Las cajas que se compran en la plaza volcánica del lobby: precio, color y tabla de premios.
-- El servidor tira el premio con estas probabilidades (CrateService); el cliente las muestra
-- en "DROP RATES". Las dos partes leen este mismo módulo, así que lo que ves es lo que hay.
--
-- CÓMO CAMBIAR:
--   · Precio: Price (en la moneda Config.Crates.Currency, el oro del perfil).
--   · Robux: ProductId = el Id de un Developer Product (Creator Dashboard › tu experiencia ›
--     Monetization › Developer Products › Create). El precio en Robux se pone ALLÁ, no acá.
--     0 = esa caja no se vende por Robux (no aparece el botón).
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
	Price: number,
	ProductId: number, -- Developer Product para abrirla con Robux (0 = sin Robux)
	Color: Color3, -- color principal (neón, brillo y título)
	Dark: Color3, -- madera / cuerpo del cofre
	Prizes: { Entry },
}
export type Rate = { Prize: string, Percent: number }

local Crates = {}

Crates.List = {
	{
		Id = "Common",
		Name = "Common Crate",
		Price = 100,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(225, 228, 235),
		Dark = C(120, 120, 128),
		Prizes = {
			{ Prize = "Recruit", Chance = 30 },
			{ Prize = "Chicken", Chance = 25 },
			{ Prize = "Villager", Chance = 20 },
			{ Prize = "BabySlime", Chance = 15 },
			{ Prize = "Spearman", Chance = 6 },
			{ Prize = "Fox", Chance = 3.5 },
			{ Prize = "BlueArcher", Chance = 0.45 },
			{ Prize = "Sorcerer", Chance = 0.05 },
		},
	},
	{
		Id = "Rare",
		Name = "Rare Crate",
		Price = 500,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(60, 145, 255),
		Dark = C(30, 60, 130),
		Prizes = {
			{ Prize = "Spearman", Chance = 25 },
			{ Prize = "Villager", Chance = 20 },
			{ Prize = "Fox", Chance = 20 },
			{ Prize = "BabySlime", Chance = 15 },
			{ Prize = "Lumberjack", Chance = 12 },
			{ Prize = "BlueArcher", Chance = 5 },
			{ Prize = "IceWolf", Chance = 2.5 },
			{ Prize = "ShadowPanther", Chance = 0.45 },
			{ Prize = "GoldenKing", Chance = 0.05 },
		},
	},
	{
		Id = "Epic",
		Name = "Epic Crate",
		Price = 1500,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(175, 85, 255),
		Dark = C(70, 30, 120),
		Prizes = {
			{ Prize = "Lumberjack", Chance = 30 },
			{ Prize = "BlueArcher", Chance = 25 },
			{ Prize = "Fox", Chance = 15 },
			{ Prize = "IceWolf", Chance = 15 },
			{ Prize = "Knight", Chance = 9 },
			{ Prize = "Sorcerer", Chance = 4 },
			{ Prize = "ShadowPanther", Chance = 1.5 },
			{ Prize = "Paladin", Chance = 0.45 },
			{ Prize = "Phoenix", Chance = 0.05 },
		},
	},
	{
		Id = "Legendary",
		Name = "Legendary Crate",
		Price = 5000,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(255, 195, 45),
		Dark = C(130, 85, 20),
		Prizes = {
			{ Prize = "Knight", Chance = 35 },
			{ Prize = "IceWolf", Chance = 20 },
			{ Prize = "Sorcerer", Chance = 20 },
			{ Prize = "ShadowPanther", Chance = 12 },
			{ Prize = "Paladin", Chance = 8 },
			{ Prize = "GoldenKing", Chance = 3.5 },
			{ Prize = "Phoenix", Chance = 1.2 },
			{ Prize = "FireDemon", Chance = 0.295 },
			{ Prize = "FallenAngel", Chance = 0.005 },
		},
	},
	{
		Id = "Secret",
		Name = "Secret Crate",
		Price = 15000,
		ProductId = 0, -- pegá acá el Id del Developer Product
		Color = C(255, 70, 150),
		Dark = C(120, 20, 50),
		Prizes = {
			{ Prize = "Paladin", Chance = 40 },
			{ Prize = "ShadowPanther", Chance = 20 },
			{ Prize = "GoldenKing", Chance = 20 },
			{ Prize = "Phoenix", Chance = 12 },
			{ Prize = "FireDemon", Chance = 5 },
			{ Prize = "LavaGolem", Chance = 2.5 },
			{ Prize = "FallenAngel", Chance = 0.45 },
			{ Prize = "CosmicCat", Chance = 0.05 },
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
