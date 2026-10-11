-- Runas: conseguirlas, subirlas de nivel, espacios activos, cofre con gemas, guardado y bonus.
local M = require("./mocks")
require("./GameServer")
local Profiles = require("./Profiles")
local Runes = require("./Runes")
local PlayerData = require("./PlayerData")
local Defs = require("./RuneDefs")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end

print("Runas")
local p = M.addPlayer("Runero")
local data = Profiles.get(p)
local function request(action, a, b) M.advance(1); return Runes.request(p, action, a, b) end

test("perfil nuevo: sin runas, 3 espacios vacíos y solo el primero abierto", function()
	assert(next(data.Runes.Owned) == nil)
	assert(#data.Runes.Active == Defs.ActiveSlots and data.Runes.Active[1] == "")
	assert(Runes.slots(p) == 1)
end)

test("repetidas: suben de nivel hasta el máximo y después dan piedras", function()
	assert(Runes.grant(p, "Fury") == "New" and data.Runes.Owned.Fury == 1)
	for _ = 2, Defs.MaxLevel do assert(Runes.grant(p, "Fury") == "LevelUp") end
	assert(data.Runes.Owned.Fury == Defs.MaxLevel)
	local stones = data.Currencies.Stones
	assert(Runes.grant(p, "Fury") == "Duplicate" and data.Runes.Owned.Fury == Defs.MaxLevel)
	assert(data.Currencies.Stones == stones + Defs.DuplicateStones)
	assert(Runes.grant(p, "NoExiste") == nil)
end)

test("especiales: no suben de nivel; repetida da piedras", function()
	assert(Runes.grant(p, "Multishot") == "New" and data.Runes.Owned.Multishot == 1)
	assert(Runes.grant(p, "Multishot") == "Duplicate" and data.Runes.Owned.Multishot == 1)
end)

test("equipar: solo especiales que tenés, en espacios abiertos; mover entre espacios", function()
	assert(not request("Equip", 1, "Fury"), "una de colección no se equipa")
	assert(not request("Equip", 1, "Pierce"), "no la tiene")
	assert(not request("Equip", 2, "Multishot"), "espacio 2 bloqueado")
	assert(not request("Equip", 1.5, "Multishot") and not request("Equip", "1", "Multishot"))
	assert(request("Equip", 1, "Multishot") and data.Runes.Active[1] == "Multishot")
	-- Ganar el Bosque abre el espacio 2
	Profiles.chapter(p, "forest").Clears = 1
	assert(Runes.slots(p) == 2)
	assert(request("Equip", 2, "Multishot"))
	assert(data.Runes.Active[1] == "" and data.Runes.Active[2] == "Multishot", "se movió, no se duplicó")
	assert(request("Unequip", 2) and data.Runes.Active[2] == "")
	assert(not request("Unequip", 9))
end)

test("no se cambian listo ni en partida", function()
	p:SetAttribute("Ready", true); assert(not request("Equip", 1, "Multishot")); p:SetAttribute("Ready", false)
	PlayerData.get(p).inMatch = true; assert(not request("OpenChest")); PlayerData.get(p).inMatch = false
end)

test("cofre: cobra gemas una vez y da una runa; sin gemas no abre", function()
	data.Currencies.Gems = 0
	assert(not request("OpenChest"))
	Profiles.addCurrency(p, "Gems", Defs.ChestCost + 10)
	local before = 0
	for _, lv in data.Runes.Owned do before += lv end
	local stones = data.Currencies.Stones
	assert(request("OpenChest"))
	assert(data.Currencies.Gems == 10)
	local after = 0
	for _, lv in data.Runes.Owned do after += lv end
	assert(after == before + 1 or data.Currencies.Stones > stones, "dio una runa (o piedras si era repetida)")
	assert(not request("OpenChest"), "ya no alcanza")
end)

test("bonus: colección siempre, especiales solo en espacios abiertos", function()
	local owned = { Fury = 2, Rapid = 1, Multishot = 1, Inferno = 1 }
	local stats = PlayerData.newStats()
	local damage, interval = stats.damage, stats.attackInterval
	Defs.apply(stats, owned, { "Multishot", "Inferno", "" }, 1)
	assert(math.abs(stats.damage - damage * 1.04) < 1e-6, "Furia Nv.2 = +4%")
	assert(math.abs(stats.attackInterval - interval * 0.985) < 1e-6, "Cadencia Nv.1 = -1,5%")
	assert(stats.frontArrows == 1, "Flecha extra en el espacio 1")
	assert(stats.burn == false, "Infierno está en el espacio 2, bloqueado")
	local other = PlayerData.newStats()
	Defs.apply(other, owned, { "Multishot", "Multishot", "Inferno" }, 3)
	assert(other.frontArrows == 1 and other.burn == true, "la misma runa en dos espacios cuenta una vez")
end)

test("guardar y volver conserva runas y espacios; datos rotos se descartan", function()
	assert(request("Equip", 1, "Multishot"))
	Profiles.saveSoon(p); Profiles.onPlayerRemoving(p)
	local back = M.addPlayer("Runero2", p.UserId)
	local loaded = Profiles.get(back)
	assert(loaded.Runes.Owned.Fury == Defs.MaxLevel and loaded.Runes.Active[1] == "Multishot")
	local clean = Profiles.reconcile({ Runes = {
		Owned = { Fury = 99, Fake = 3, Multishot = 4, Pierce = -1 },
		Active = { "Fake", "Pierce", "Multishot", "Multishot" },
	} })
	assert(clean.Runes.Owned.Fury == Defs.MaxLevel and clean.Runes.Owned.Fake == nil)
	assert(clean.Runes.Owned.Multishot == 1 and clean.Runes.Owned.Pierce == nil)
	assert(clean.Runes.Active[1] == "" and clean.Runes.Active[2] == "" and clean.Runes.Active[3] == "Multishot")
	assert(#clean.Runes.Active == Defs.ActiveSlots)
end)

test("sorteo: siempre una runa que existe, de la clase pedida", function()
	for _ = 1, 200 do
		local id = Defs.roll(0.5)
		assert(Defs.ById[id], id)
	end
	assert(Defs.ById[Defs.roll(1)].Kind == "Special")
	assert(Defs.ById[Defs.roll(0)].Kind == "Collection")
end)

test("la pantalla de Equipo calcula las mismas stats que el servidor (equipo + talentos + runas)", function()
	local Equipment = require("./Equipment")
	local TalentService = require("./TalentService")
	local Talents = require("./Talents")
	local EquipmentDefs = require("./EquipmentDefs")
	local BaseStats = require("./BaseStats")
	local Rarities = require("./Rarities")
	local q = M.addPlayer("Comparar")
	local d = Profiles.get(q)
	-- Un poco de todo: equipo mejorado, talentos y runas
	for _, item in d.Inventory do item.Level = 4; item.Rarity = "Epic" end
	for _, def in Talents.List do d.Talents[def.Id] = math.min(2, def.Max) end
	Runes.grant(q, "Fury"); Runes.grant(q, "Fury"); Runes.grant(q, "Vitality"); Runes.grant(q, "Hawk")
	Runes.grant(q, "Multishot")
	d.Runes.Active[1] = "Multishot"
	-- Servidor (como Run.start)
	local server = PlayerData.newStats()
	Equipment.apply(q, server)
	TalentService.apply(q, server)
	Runes.apply(q, server)
	-- Pantalla (EquipmentUI)
	local client = BaseStats.new()
	EquipmentDefs.apply(client, d.Inventory, d.Equipment, Rarities.index)
	for _, def in Talents.List do
		local level = d.Talents[def.Id] or 0
		if level > 0 then def.Apply(client, math.min(level, def.Max)) end
	end
	Defs.apply(client, d.Runes.Owned, d.Runes.Active, Runes.slots(q))
	for stat, value in server do
		if type(value) ~= "table" then
			assert(client[stat] == value, stat .. ": servidor " .. tostring(value) .. " / pantalla " .. tostring(client[stat]))
		end
	end
	assert(server.damage > BaseStats.new().damage, "las runas y el equipo suben el daño")
end)

print(passed .. " pruebas, 0 fallas")
