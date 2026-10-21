local M = require("./mocks")
require("./Config").Crates.TestGold = 0 -- sin las monedas de prueba de las cajas
require("./GameServer")
local Profiles = require("./Profiles")
local Equipment = require("./Equipment")
local PlayerData = require("./PlayerData")
local Defs = require("./EquipmentDefs")
local Remotes = require("./Remotes")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local p = M.addPlayer("Equipo")
local data = Profiles.get(p)
local function request(action, arg) M.advance(1); return Equipment.request(p, action, arg) end
test("perfil nuevo: seis piezas iniciales equipadas", function()
	assert(#data.Inventory == 6)
	for _, slot in Defs.Slots do assert(data.Equipment[slot]) end
end)
test("no cambia equipo listo ni durante una partida", function()
	p:SetAttribute("Ready", true); assert(not request("Unequip", "Weapon")); p:SetAttribute("Ready", false)
	PlayerData.get(p).inMatch = true; assert(not request("Upgrade", data.Inventory[1].Uid)); PlayerData.get(p).inMatch = false
end)
test("mejoras cobran recursos una sola vez y rechazan saldo insuficiente", function()
	local item = data.Inventory[1]
	assert(not request("Upgrade", item.Uid)); assert(item.Level == 1)
	Profiles.addCurrency(p, "Gold", 300); Profiles.addCurrency(p, "Stones", 10)
	assert(request("Upgrade", item.Uid)); assert(item.Level == 2)
	assert(data.Currencies.Gold == 240 and data.Currencies.Stones == 9)
	assert(not Equipment.request(p, "Upgrade", item.Uid)); assert(item.Level == 2)
end)
test("fusión valida propiedad, duplicados y rareza; conserva nivel y espacio", function()
	local first = data.Inventory[1]
	local second = Equipment.grant(p, first.Id, "Common")
	local third = Equipment.grant(p, first.Id, "Common")
	assert(not request("Fuse", { first.Uid, first.Uid, third.Uid }))
	assert(not request("Fuse", { first.Uid, second.Uid, "ajeno" }))
	assert(not request("Fuse", { first.Uid, second.Uid, data.Inventory[2].Uid }))
	assert(request("Fuse", { first.Uid, second.Uid, third.Uid }))
	assert(first.Rarity == "Uncommon" and first.Level == 2 and #data.Inventory == 6)
	assert(data.Equipment.Weapon == first.Uid)
end)
test("rechaza IDs ajenos, peticiones malformadas y nivel máximo", function()
	assert(not request("Equip", "ajeno")); assert(not request("Unequip", "Otro"))
	local bad = { data.Inventory[1].Uid, data.Inventory[2].Uid, data.Inventory[3].Uid, extra = "ajeno" }
	assert(not request("Fuse", bad))
	assert(not request("Fuse", "objeto")); assert(not request("Equip", {}))
	data.Inventory[1].Level = Defs.MaxLevel; assert(not request("Upgrade", data.Inventory[1].Uid))
end)
test("las bonificaciones tienen tope y no acumulan entre partidas", function()
	for _, item in data.Inventory do item.Rarity = "Mythic"; item.Level = 10 end
	local stats = PlayerData.newStats(); Equipment.apply(p, stats)
	assert(stats.damage <= 25 * 1.3 + 0.01 and stats.maxHealth <= 100 * 1.4 + 0.01)
	assert(stats.walkSpeed <= 20 * 1.15 + 0.01)
	local other = PlayerData.newStats(); Equipment.apply(p, other); assert(other.damage == stats.damage)
end)
test("guardar y volver conserva inventario, mejoras y espacios", function()
	local uid = data.Inventory[1].Uid
	Profiles.saveSoon(p); Profiles.onPlayerRemoving(p)
	local returned = M.addPlayer("Equipo2", p.UserId)
	local loaded = Profiles.get(returned)
	assert(#loaded.Inventory == 6 and loaded.Inventory[1].Level == 10 and loaded.Equipment.Weapon == uid)
end)
test("reconciliación repara equipo roto sin perder monedas anteriores", function()
	local clean = Profiles.reconcile({ Currencies = { Gold = 777 }, Inventory = {
		{ Uid = "a", Id = "HunterBow", Rarity = "Epic", Level = 99 },
		{ Uid = "a", Id = "HunterBow", Rarity = "Common", Level = 1 },
		{ Uid = "b", Id = "Fake", Rarity = "Epic", Level = 1 },
	}, Equipment = { Weapon = "a", Boots = "a", Helmet = "ajeno" } })
	assert(clean.Currencies.Gold == 777 and #clean.Inventory == 1 and clean.Inventory[1].Level == 10)
	assert(clean.Equipment.Weapon == "a" and not clean.Equipment.Boots and not clean.Equipment.Helmet)
end)
test("reciclar: devuelve oro y piedras, nunca lo equipado ni lo ajeno", function()
	local r = M.addPlayer("Reciclador")
	local d = Profiles.get(r)
	local function req(action, arg) M.advance(1); return Equipment.request(r, action, arg) end
	local equippedUid = d.Equipment.Weapon
	assert(not req("Recycle", equippedUid)); assert(#d.Inventory == 6)
	assert(not req("Recycle", "ajeno")); assert(not req("Recycle", {}))
	local spare = Equipment.grant(r, "EmberRing", "Epic"); spare.Level = 3
	local gold0, stones0 = d.Currencies.Gold, d.Currencies.Stones
	local g, st = Defs.recycleValue(spare, 4)
	assert(g == 20 * 4 + math.floor(180 * 0.4) and st == 3 + 1)
	assert(req("Recycle", spare.Uid))
	assert(#d.Inventory == 6 and d.Currencies.Gold == gold0 + g and d.Currencies.Stones == stones0 + st)
	assert(not req("Recycle", spare.Uid)) -- no se cobra dos veces
	-- En partida o listo: rechaza
	local other = Equipment.grant(r, "EmberRing", "Common")
	r:SetAttribute("Ready", true); assert(not req("Recycle", other.Uid)); r:SetAttribute("Ready", false)
end)
test("reciclar en lote: solo comunes/poco comunes sin equipar", function()
	local r = M.addPlayer("Lote")
	local d = Profiles.get(r)
	local function req(action, arg) M.advance(1); return Equipment.request(r, action, arg) end
	for _ = 1, 4 do Equipment.grant(r, "HunterRing", "Common", false) end
	local epic = Equipment.grant(r, "HunterRing", "Epic", false)
	assert(not req("RecycleRarity", "Epic")) -- las altas, de a una
	assert(not req("RecycleRarity", "Mythic")); assert(not req("RecycleRarity", 5))
	local gold0 = d.Currencies.Gold
	assert(req("RecycleRarity", "Common"))
	-- Quedan las 6 iniciales (equipadas, comunes) + la épica
	assert(#d.Inventory == 7 and d.Currencies.Gold == gold0 + 4 * 20)
	for _, slot in Defs.Slots do
		local found = false
		for _, item in d.Inventory do if item.Uid == d.Equipment[slot] then found = true end end
		assert(found, "se recicló una pieza equipada")
	end
	assert(epic and d.Inventory[7].Uid == epic.Uid)
	assert(not req("RecycleRarity", "Common")) -- ya no queda nada sin equipar
end)
print(passed .. " pruebas, 0 fallas")
