-- Tienda del lobby: ofertas del día estables, compra segura (cobra una vez, entrega o devuelve),
-- cambios con límite diario, cofre de runas y reinicio a las 00:00 UTC.
local M = require("./mocks")
require("./GameServer")
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local Remotes = require("./Remotes")
local ShopDefs = require("./ShopDefs")
local ShopService = require("./ShopService")
local EquipmentDefs = require("./EquipmentDefs")
local RuneDefs = require("./RuneDefs")

local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end
local invoke = Remotes.ShopRequest.OnServerInvoke

print("Tienda")
local DAY0 = 1772452800 -- 2/3/2026 12:00 UTC
local clock = DAY0
ShopService._setClock(function() return clock end)
local p = M.addPlayer("Comprador", 777)
local data = Profiles.get(p)
local function ask(action, arg) M.advance(1); return invoke(p, action, arg) end
local function setCurrency(id, n)
	data.Currencies[id] = n
	Profiles.refresh(p)
end

test("precios y pesos definidos para cada rareza; cambios válidos", function()
	for _, w in ShopDefs.OfferWeights do
		local price = ShopDefs.OfferPrices[w.Rarity]
		assert(price and price.Amount > 0, w.Rarity)
	end
	for _, e in ShopDefs.Exchanges do
		assert(e.Give.Amount > 0 and e.Get.Amount > 0 and e.PerDay > 0 and ShopDefs.ExchangeById[e.Id] == e)
	end
end)

test("ofertas: 4 piezas distintas, las mismas para (jugador, día), otras al día siguiente", function()
	local day = math.floor(DAY0 / 86400)
	local a, b = ShopDefs.offers(777, day), ShopDefs.offers(777, day)
	eq(#a, ShopDefs.OfferCount, "cantidad")
	local seen = {}
	for i, o in a do
		eq(o.Id, b[i].Id, "estable")
		eq(o.Rarity, b[i].Rarity, "estable")
		assert(EquipmentDefs.ById[o.Id], o.Id)
		assert(not seen[o.Id], "repetida")
		seen[o.Id] = true
	end
	local different = false
	for d = 1, 5 do
		local c = ShopDefs.offers(777, day + d)
		for i = 1, #a do
			if c[i].Id ~= a[i].Id or c[i].Rarity ~= a[i].Rarity then different = true end
		end
	end
	assert(different, "nunca cambian")
	local r = ask("Get")
	assert(r.Ok)
	eq(r.Offers[1].Id, a[1].Id, "lo que ve el cliente")
end)

test("comprar: cobra, entrega la pieza y no deja comprarla de nuevo; sin plata no cobra", function()
	local offer = ShopDefs.offers(777, math.floor(DAY0 / 86400))[1]
	local cur = offer.Price.Currency
	setCurrency(cur, 0)
	local items = #data.Inventory
	assert(not ask("BuyOffer", 1).Ok, "compró sin plata")
	eq(#data.Inventory, items, "entregó sin cobrar")
	setCurrency(cur, offer.Price.Amount + 5)
	local r = ask("BuyOffer", 1)
	assert(r.Ok, tostring(r.Error))
	eq(data.Currencies[cur], 5, "cobró justo")
	eq(#data.Inventory, items + 1, "entregó")
	local item = data.Inventory[#data.Inventory]
	eq(item.Id, offer.Id, "pieza")
	eq(item.Rarity, offer.Rarity, "rareza")
	assert(r.Offers[1].Bought)
	setCurrency(cur, 100000)
	assert(not ask("BuyOffer", 1).Ok, "la compró dos veces")
	eq(data.Currencies[cur], 100000, "cobró de nuevo")
	assert(not ask("BuyOffer", 0).Ok and not ask("BuyOffer", 5).Ok and not ask("BuyOffer", 1.5).Ok and not ask("BuyOffer", "2").Ok)
end)

test("inventario lleno: no cobra", function()
	local offer = ShopDefs.offers(777, math.floor(DAY0 / 86400))[2]
	setCurrency(offer.Price.Currency, 100000)
	local saved = data.Inventory
	local full = table.clone(saved)
	while #full < EquipmentDefs.MaxInventory do table.insert(full, saved[1]) end
	data.Inventory = full
	assert(not ask("BuyOffer", 2).Ok, "compró con el inventario lleno")
	eq(data.Currencies[offer.Price.Currency], 100000, "cobró")
	data.Inventory = saved
end)

test("cambios: cobran, dan y tienen límite por día", function()
	local e = ShopDefs.ExchangeById.GemsToGold
	setCurrency("Gems", e.Give.Amount * (e.PerDay + 2))
	setCurrency("Gold", 0)
	for _ = 1, e.PerDay do assert(ask("Exchange", "GemsToGold").Ok) end
	eq(data.Currencies.Gold, e.Get.Amount * e.PerDay, "oro")
	local r = ask("Exchange", "GemsToGold")
	assert(not r.Ok, "pasó el límite")
	eq(data.Currencies.Gems, e.Give.Amount * 2, "gemas restantes")
	setCurrency("Gold", 0)
	assert(not ask("Exchange", "GoldToStones").Ok, "cambió sin oro")
	assert(not ask("Exchange", "NoExiste").Ok)
end)

test("cofre de runas: cobra gemas y da una runa", function()
	setCurrency("Gems", RuneDefs.ChestCost)
	local before = 0
	for _ in data.Runes.Owned do before += 1 end
	local stones = data.Currencies.Stones
	assert(ask("RuneChest").Ok)
	eq(data.Currencies.Gems, 0, "gemas")
	local after = 0
	for _ in data.Runes.Owned do after += 1 end
	assert(after > before or data.Currencies.Stones > stones, "no dio nada")
	assert(not ask("RuneChest").Ok, "abrió sin gemas")
end)

test("solo en el lobby: listo o en partida no compra", function()
	setCurrency("Gems", 1000)
	p:SetAttribute("Ready", true)
	assert(not ask("Exchange", "GoldToStones").Ok)
	p:SetAttribute("Ready", false)
	PlayerData.get(p).inMatch = true
	assert(not ask("RuneChest").Ok)
	PlayerData.get(p).inMatch = false
	eq(data.Currencies.Gems, 1000, "cobró igual")
end)

test("día nuevo: ofertas y cambios se renuevan", function()
	clock = DAY0 + 86400
	local r = ask("Get")
	assert(r.Ok)
	for _, o in r.Offers do assert(not o.Bought) end
	for _, e in r.Exchanges do eq(e.Left, e.PerDay, e.Id) end
end)

ShopService._setClock(nil)
print(passed .. " pruebas, 0 fallas")
