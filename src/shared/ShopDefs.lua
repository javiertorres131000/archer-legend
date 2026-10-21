--!strict
-- ShopDefs (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > ShopDefs
-- Tienda del lobby (sin Robux): qué se vende y a cuánto. El servidor (ShopService) cobra y
-- entrega; el cliente (ShopUI) solo muestra. Las dos partes arman las ofertas con este módulo,
-- así que lo que ves es lo que hay.
--
--   · Ofertas del día: OfferCount piezas de equipo al azar (pieza y rareza), cada una se compra
--     una vez por día. Cambian a las 00:00 UTC y son las mismas para ese jugador ese día
--     (la tirada usa su UserId y el número de día).
--   · Cambios: gemas por oro y oro por piedras, con un límite por día.
--   · Cofre de runas: el de siempre (Shared/RuneDefs.lua › ChestCost gemas), también desde acá.
--
-- Precios de referencia (README › Economía): una victoria del capítulo 1 da ~1.600 oro,
-- ~45 gemas y ~19 piedras; la del capítulo 3, ~4.500 oro.

local EquipmentDefs = require(script.Parent.EquipmentDefs)

export type Price = { Currency: string, Amount: number }
export type Offer = { Index: number, Id: string, Rarity: string, Price: Price }
export type Exchange = { Id: string, Name: string, Give: Price, Get: Price, PerDay: number }

local ShopDefs = {}

ShopDefs.OfferCount = 4

-- Rareza de las ofertas (pesos; sin míticas: esas se ganan jugando)
ShopDefs.OfferWeights = {
	{ Rarity = "Common", Weight = 30 },
	{ Rarity = "Uncommon", Weight = 30 },
	{ Rarity = "Rare", Weight = 22 },
	{ Rarity = "Epic", Weight = 13 },
	{ Rarity = "Legendary", Weight = 5 },
}

-- Precio de una pieza según su rareza
ShopDefs.OfferPrices = {
	Common = { Currency = "Gold", Amount = 150 },
	Uncommon = { Currency = "Gold", Amount = 350 },
	Rare = { Currency = "Gold", Amount = 800 },
	Epic = { Currency = "Gold", Amount = 1800 },
	Legendary = { Currency = "Gems", Amount = 90 },
} :: { [string]: Price }

ShopDefs.Exchanges = {
	{ Id = "GemsToGold", Name = "Gemas por oro", Give = { Currency = "Gems", Amount = 10 }, Get = { Currency = "Gold", Amount = 400 }, PerDay = 5 },
	{ Id = "GoldToStones", Name = "Piedras de mejora", Give = { Currency = "Gold", Amount = 300 }, Get = { Currency = "Stones", Amount = 5 }, PerDay = 5 },
} :: { Exchange }

ShopDefs.ExchangeById = {} :: { [string]: Exchange }
for _, e in ShopDefs.Exchanges do
	ShopDefs.ExchangeById[e.Id] = e
end

-- Ofertas del día de un jugador: siempre las mismas para (UserId, día). Sin piezas repetidas.
function ShopDefs.offers(userId: number, day: number): { Offer }
	local rng = Random.new((userId % 2147483647) * 17 + day * 104729 + 3)
	local pool = table.clone(EquipmentDefs.List)
	local total = 0
	for _, w in ShopDefs.OfferWeights do
		total += w.Weight
	end
	local out = {}
	for i = 1, math.min(ShopDefs.OfferCount, #pool) do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		local roll = rng:NextNumber() * total
		local rarity = ShopDefs.OfferWeights[#ShopDefs.OfferWeights].Rarity
		for _, w in ShopDefs.OfferWeights do
			roll -= w.Weight
			if roll <= 0 then
				rarity = w.Rarity
				break
			end
		end
		table.insert(out, { Index = i, Id = def.Id, Rarity = rarity, Price = ShopDefs.OfferPrices[rarity] })
	end
	return out
end

return ShopDefs
