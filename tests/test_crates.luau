-- Cajas: tablas de premios, tirada ponderada, compra segura en el servidor, inventario
-- guardado, leaderstats, monedas de prueba y la plaza del lobby.
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local Remotes = require("./Remotes")
local Crates = require("./Crates")
local CrateItems = require("./CrateItems")
local CrateService = require("./CrateService")
local CratePlazaLayout = require("./CratePlazaLayout")
local CrateEquip = require("./CrateEquip")
local Receipts = require("./Receipts")
local Weapons = require("./Weapons")

local Cfg = Config.Crates
local V = M.Vector3.new
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end
local invoke = Remotes.CrateRequest.OnServerInvoke

print("Cajas")
local layout = CratePlazaLayout.get()
local p = M.addPlayer("Cajero")
local data = Profiles.get(p)
local state = PlayerData.get(p)
local function atStation(i) M.moveTo(p, layout.Stations[i or 1].Position + V(-3, 3, 0)) end
local function setGold(n)
	data.Currencies.Gold = n
	Profiles.refresh(p)
end
local function open(id)
	M.advance(Cfg.OpenCooldown + 0.1)
	return invoke(p, "Open", id)
end

test("6 cajas con su precio y 7 rarezas, de menor a mayor", function()
	local expected = { Common = 100, Rare = 500, Epic = 1500, Legendary = 5000, Secret = 15000, Weapons = 10000 }
	eq(#Crates.List, 6, "cajas")
	for id, price in expected do
		assert(Crates.ById[id], "falta " .. id)
		eq(Crates.ById[id].Price, price, id)
	end
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
	for i, id in order do
		eq(CrateItems.RarityById[id].Order, i, id)
	end
end)

test("tablas: todo premio existe, Ids únicos y cada caja suma 100%", function()
	local seen = {}
	for _, prize in CrateItems.List do
		assert(not seen[prize.Id], "repetido " .. prize.Id)
		seen[prize.Id] = true
		assert(CrateItems.RarityById[prize.Rarity], prize.Id .. ": rareza")
		assert(prize.Kind == "Unit" or prize.Kind == "Pet" or prize.Kind == "Character" or prize.Kind == "Weapon", prize.Id .. ": tipo")
		if prize.Kind == "Weapon" then
			local w = Weapons.ById[prize.Weapon]
			assert(w and w.Prize == prize.Id, prize.Id .. ": su arma no existe o no apunta al premio")
		end
	end
	for _, crate in Crates.List do
		local sum, rates = 0, 0
		for _, e in crate.Prizes do
			assert(CrateItems.ById[e.Prize], crate.Id .. ": no existe " .. e.Prize)
			assert(e.Chance > 0, crate.Id .. ": chance")
			sum += e.Chance
		end
		assert(math.abs(sum - 100) < 1e-6, crate.Id .. " suma " .. sum)
		-- La caja de armas solo da armas; las otras, nunca
		for _, e in crate.Prizes do
			eq(CrateItems.ById[e.Prize].Kind == "Weapon", crate.Id == "Weapons", crate.Id .. ": " .. e.Prize)
		end
		for _, r in Crates.rates(crate) do rates += r.Percent end
		assert(math.abs(rates - 100) < 1e-6)
	end
end)

test("porcentajes y precios se muestran bien", function()
	eq(Crates.formatPercent(45), "45.00%")
	eq(Crates.formatPercent(0.005), "0.0050%")
	eq(Crates.formatPercent(0.45), "0.45%")
	eq(Crates.formatPrice(15000), "15,000")
	eq(Crates.formatPrice(100), "100")
	eq(Crates.formatPrice(1500), "1,500")
end)

test("tirada ponderada: los extremos y la proporción con muchas tiradas", function()
	local crate = Crates.ById.Common
	eq(Crates.pick(crate, 0), crate.Prizes[1].Prize, "r = 0")
	eq(Crates.pick(crate, 0.99999999), crate.Prizes[#crate.Prizes].Prize, "r ≈ 1")
	local rng = M.Random.new(42)
	local counts, n = {}, 100000
	for _ = 1, n do
		local id = Crates.pick(crate, rng:NextNumber())
		counts[id] = (counts[id] or 0) + 1
	end
	for _, r in Crates.rates(crate) do
		if r.Percent >= 3 then
			local got = (counts[r.Prize] or 0) / n * 100
			assert(math.abs(got - r.Percent) < r.Percent * 0.06, string.format("%s: %.2f%% vs %.2f%%", r.Prize, got, r.Percent))
		end
	end
	-- Chance que no suman 100: se reparten en proporción
	local custom = { Id = "X", Name = "X", Price = 1, Color = crate.Color, Dark = crate.Color, Prizes = { { Prize = "Recruit", Chance = 1 }, { Prize = "Fox", Chance = 3 } } }
	eq(Crates.rates(custom)[2].Percent, 75, "proporción")
	eq(Crates.pick(custom, 0.24), "Recruit")
	eq(Crates.pick(custom, 0.26), "Fox")
end)

test("leaderstats con las monedas y monedas de prueba una sola vez", function()
	local stats = p:FindFirstChild("leaderstats")
	assert(stats, "sin leaderstats")
	local coins = stats:FindFirstChild(Cfg.LeaderstatName)
	assert(coins, "sin columna de monedas")
	assert(data.Crates.TestGoldGiven, "en Studio se dan las monedas de prueba")
	eq(data.Currencies.Gold, Cfg.TestGold, "monedas de prueba")
	CrateService.onProfileLoaded(p, data)
	eq(data.Currencies.Gold, Cfg.TestGold, "no se dan dos veces")
	-- Fuera de Studio no se dan
	M.isStudio = false
	local q = M.addPlayer("Publicado")
	eq(Profiles.get(q).Currencies.Gold, 0, "fuera de Studio")
	M.isStudio = true
	M.removePlayer(q)
end)

test("abrir: cobra, da el premio que dice el servidor y lo guarda en el perfil", function()
	atStation(2)
	setGold(1000)
	CrateService._forceRoll(0) -- primer premio de la tabla
	local res = open("Rare")
	CrateService._forceRoll(nil)
	assert(res.Ok, res.Error)
	eq(res.Prize, Crates.ById.Rare.Prizes[1].Prize, "premio")
	eq(res.Gold, 500, "cobró")
	eq(data.Currencies.Gold, 500)
	eq(p:GetAttribute("Gold"), 500, "atributo")
	eq(data.Crates.Owned[res.Prize], 1)
	assert(res.New and res.Count == 1)
	eq(data.Crates.Opened, 1)
	-- El mismo premio otra vez suma
	CrateService._forceRoll(0)
	local again = open("Rare")
	CrateService._forceRoll(nil)
	assert(again.Ok and again.Count == 2 and not again.New)
	eq(data.Currencies.Gold, 0)
end)

test("sin monedas suficientes no cobra ni da nada", function()
	setGold(99)
	local res = open("Common")
	assert(not res.Ok and string.find(res.Error, "1 monedas", 1, true), res.Error)
	eq(data.Currencies.Gold, 99, "no cobró")
	eq(data.Crates.Opened, 2, "no abrió")
end)

test("pedidos inválidos: caja que no existe, tipos raros, acción desconocida", function()
	setGold(100000)
	for _, bad in { "Nope", 5, {}, nil, string.rep("a", 100) } do
		local res = open(bad)
		assert(not res.Ok, "aceptó " .. tostring(bad))
	end
	assert(not invoke(p, "Hack", "Common").Ok)
	assert(not invoke(p, nil).Ok)
	eq(data.Currencies.Gold, 100000, "nada cobrado")
end)

test("límite de frecuencia: dos aperturas seguidas no pasan", function()
	setGold(1000)
	local first = open("Common")
	assert(first.Ok, first.Error)
	local second = invoke(p, "Open", "Common") -- sin esperar
	assert(not second.Ok, "debería frenar")
	eq(data.Currencies.Gold, 900, "cobró una sola")
	M.advance(Cfg.OpenCooldown + 0.1)
	assert(invoke(p, "Open", "Common").Ok, "después del límite, sí")
end)

test("lejos de las plataformas o en partida no se abre", function()
	setGold(1000)
	M.moveTo(p, layout.Center + V(-200, 3, 0))
	local far = open("Common")
	assert(not far.Ok and string.find(far.Error, "Acercate", 1, true), far.Error)
	atStation(5)
	state.inMatch = true
	local inMatch = open("Common")
	state.inMatch = false
	assert(not inMatch.Ok, "en partida")
	eq(data.Currencies.Gold, 1000)
	assert(open("Common").Ok, "en la plataforma, sí")
end)

test("colección: devuelve lo que tenés (una copia) y respeta su límite", function()
	M.advance(1)
	local res = invoke(p, "Collection")
	assert(res.Ok)
	assert(res.Owned ~= data.Crates.Owned, "debe ser una copia")
	for id, n in data.Crates.Owned do eq(res.Owned[id], n, id) end
	eq(res.Opened, data.Crates.Opened)
	assert(not invoke(p, "Collection").Ok, "demasiado seguido")
end)

-- Compras de Roblox simuladas
local Market = M.game:GetService("MarketplaceService")
local prompted = {}
rawget(Market, "_raw").PromptProductPurchase = function(_, who, productId)
	table.insert(prompted, { who, productId })
end
local PRODUCT = 987654
Crates.ById.Rare.ProductId = PRODUCT
CrateService.registerProducts()
local function receipt(id, productId, userId)
	return Receipts.process({ PlayerId = userId or p.UserId, ProductId = productId or PRODUCT, PurchaseId = id })
end

test("Robux: sin permiso de Roblox (PolicyService) no se vende; con permiso muestra la compra", function()
	atStation(2)
	eq(p:GetAttribute("PaidCratesAllowed"), false, "sin respuesta de PolicyService = no permitido")
	M.advance(Cfg.OpenCooldown + 0.1)
	local blocked = invoke(p, "BuyRobux", "Rare")
	assert(not blocked.Ok and string.find(blocked.Error, "región", 1, true), blocked.Error)
	CrateService._setPaidAllowed(p, true)
	M.advance(Cfg.OpenCooldown + 0.1)
	local res = invoke(p, "BuyRobux", "Rare")
	assert(res.Ok, res.Error)
	eq(#prompted, 1)
	eq(prompted[1][1], p)
	eq(prompted[1][2], PRODUCT)
	M.advance(Cfg.OpenCooldown + 0.1)
	assert(not invoke(p, "BuyRobux", "Common").Ok, "caja sin ProductId")
	assert(not invoke(p, "BuyRobux", "Nope").Ok, "caja que no existe")
	state.inMatch = true
	M.advance(Cfg.OpenCooldown + 0.1)
	assert(not invoke(p, "BuyRobux", "Rare").Ok, "en partida")
	state.inMatch = false
end)

test("recibo: entrega una vez, guarda, avisa al cliente y no cobra monedas", function()
	local fired = {}
	local old = Remotes.CrateOpened.FireClient
	Remotes.CrateOpened.FireClient = function(_, who, res) table.insert(fired, { who, res }) end
	local gold = data.Currencies.Gold
	local opened = data.Crates.Opened
	CrateService._forceRoll(0)
	eq(receipt("compra-1"), Receipts.GRANTED, "primera vez")
	CrateService._forceRoll(nil)
	local prize = Crates.ById.Rare.Prizes[1].Prize
	eq(data.Crates.Opened, opened + 1)
	eq(data.Currencies.Gold, gold, "no toca las monedas")
	eq(#fired, 1)
	eq(fired[1][2].Prize, prize)
	assert(fired[1][2].Paid)
	local saved = M.dataStore.data["Player_" .. p.UserId].Data
	assert(table.find(saved.Crates.Receipts, "compra-1"), "el recibo quedó guardado")
	-- El mismo recibo otra vez (Roblox reintenta): no entrega de nuevo
	local count = data.Crates.Owned[prize]
	eq(receipt("compra-1"), Receipts.GRANTED, "repetido")
	eq(data.Crates.Owned[prize], count, "no duplicó")
	eq(#fired, 1)
	Remotes.CrateOpened.FireClient = old
end)

test("recibo: si no se puede guardar no se confirma, y el reintento no duplica", function()
	local before = data.Crates.Opened
	M.dataStore.failNext = Config.Profiles.Retries
	eq(receipt("compra-2"), Receipts.NOT_YET, "sin guardar no se confirma")
	eq(data.Crates.Opened, before + 1)
	eq(receipt("compra-2"), Receipts.GRANTED, "al reintentar se guarda")
	eq(data.Crates.Opened, before + 1, "no se entregó dos veces")
end)

test("recibo: producto desconocido o jugador fuera del servidor quedan pendientes", function()
	eq(receipt("x", 1234), Receipts.NOT_YET)
	eq(receipt("y", PRODUCT, 999999), Receipts.NOT_YET)
end)

test("recibos guardados: solo los últimos MaxSavedReceipts", function()
	for i = 1, Cfg.MaxSavedReceipts + 5 do
		table.insert(data.Crates.Receipts, "viejo-" .. i)
	end
	receipt("compra-nueva")
	assert(#data.Crates.Receipts <= Cfg.MaxSavedReceipts)
	eq(data.Crates.Receipts[#data.Crates.Receipts], "compra-nueva")
end)

test("equipar: mascota y personaje en su espacio, solo lo que tenés y en el lobby", function()
	data.Crates.Owned.Fox = 1
	data.Crates.Owned.Knight = 2
	data.Crates.Owned.Chicken = nil
	M.advance(1)
	local res = invoke(p, "Equip", "Fox")
	assert(res.Ok, res.Error)
	eq(data.Crates.Equipped.Pet, "Fox")
	eq(p:GetAttribute("EquippedPet"), "Fox")
	M.advance(1)
	assert(invoke(p, "Equip", "Knight").Ok)
	eq(data.Crates.Equipped.Character, "Knight")
	eq(data.Crates.Equipped.Pet, "Fox", "no pisa la mascota")
	eq(p:GetAttribute("EquippedCharacter"), "Knight")
	M.advance(1)
	assert(not invoke(p, "Equip", "Chicken").Ok, "no la tiene")
	assert(not invoke(p, "Equip", "Nope").Ok)
	assert(not invoke(p, "Equip", 5).Ok)
	assert(not invoke(p, "Unequip", "Hat").Ok)
	-- Límite de frecuencia
	M.advance(1)
	data.Crates.Owned.Phoenix = 1
	assert(invoke(p, "Equip", "Phoenix").Ok)
	assert(not invoke(p, "Equip", "Fox").Ok, "demasiado seguido")
	-- En partida no
	M.advance(1)
	state.inMatch = true
	assert(not invoke(p, "Equip", "Fox").Ok, "en partida")
	state.inMatch = false
	M.advance(1)
	assert(invoke(p, "Unequip", "Character").Ok)
	eq(data.Crates.Equipped.Character, nil)
	eq(p:GetAttribute("EquippedCharacter"), "")
end)

test("mascota: da daño extra según su rareza (en partida y en el panel de stats)", function()
	local stats = PlayerData.newStats()
	local base = stats.damage
	CrateEquip.apply(p, stats) -- Phoenix, Legendary
	local expected = base * (1 + Cfg.PetDamageBonus.Legendary)
	assert(math.abs(stats.damage - expected) < 1e-9, stats.damage .. " vs " .. expected)
	eq(CrateEquip.petBonus("Recruit"), Cfg.PetDamageBonus.Common)
	eq(CrateEquip.petBonus(nil), 0)
	M.advance(1)
	invoke(p, "Unequip", "Pet")
	local plain = PlayerData.newStats()
	CrateEquip.apply(p, plain)
	eq(plain.damage, base, "sin mascota no suma")
	-- La colección dice qué está equipado
	M.advance(1)
	local col = invoke(p, "Collection")
	assert(col.Ok and col.Equipped)
end)

test("perfil: lo equipado que no tenés se descarta; recibos válidos", function()
	local rec = Profiles.reconcile({ Crates = {
		Owned = { Fox = 1, Knight = 1 },
		Equipped = { Pet = "Fox", Character = "GoldenKing" },
		Receipts = { "a", 5, string.rep("b", 200), "c" },
	} })
	eq(rec.Crates.Equipped.Pet, "Fox")
	eq(rec.Crates.Equipped.Character, nil, "no lo tiene")
	local bad = Profiles.reconcile({ Crates = { Owned = { Fox = 1 }, Equipped = { Character = "Fox" } } })
	eq(bad.Crates.Equipped.Character, nil, "una mascota no va en el espacio de personaje")
	eq(#rec.Crates.Receipts, 2)
	eq(Profiles.SCHEMA_VERSION >= 8, true) -- 9: misiones y tienda
end)

test("perfil: los premios se guardan y los Ids desconocidos se descartan", function()
	local raw = { Crates = { Owned = { Recruit = 3, NoExiste = 2, Fox = -1, Knight = "x" }, Opened = 7, TestGoldGiven = true } }
	local rec = Profiles.reconcile(raw)
	eq(rec.Crates.Owned.Recruit, 3)
	eq(rec.Crates.Owned.NoExiste, nil)
	eq(rec.Crates.Owned.Fox, nil)
	eq(rec.Crates.Owned.Knight, nil)
	eq(rec.Crates.Opened, 7)
	assert(rec.Crates.TestGoldGiven)
	local empty = Profiles.reconcile({})
	assert(next(empty.Crates.Owned) == nil and empty.Crates.Opened == 0 and not empty.Crates.TestGoldGiven)
	-- Al salir se guarda con lo abierto
	local owned = table.clone(data.Crates.Owned)
	M.removePlayer(p)
	local saved = M.dataStore.data["Player_" .. p.UserId]
	assert(saved, "no se guardó")
	for id, n in owned do eq(saved.Data.Crates.Owned[id], n, "guardado " .. id) end
end)

test("plaza: una plataforma por caja con prompt, cartel y cofre; puerta en el lobby", function()
	local plaza = M.workspace:FindFirstChild("CratePlaza")
	assert(plaza, "no se armó la plaza")
	local stations = plaza:FindFirstChild("Stations")
	for _, crate in Crates.List do
		local st = stations:FindFirstChild(crate.Id)
		assert(st, "falta la plataforma de " .. crate.Id)
		local anchor = st:FindFirstChild("PromptAnchor")
		local prompt = anchor:FindFirstChild("CratePrompt")
		assert(prompt and prompt:GetAttribute("CrateId") == crate.Id, crate.Id .. ": prompt")
		assert(anchor:FindFirstChild("Sign"), crate.Id .. ": cartel")
		assert(st:FindFirstChild("Display"), crate.Id .. ": cofre")
	end
	-- El muro este del lobby tiene dos tramos (la puerta en el medio)
	local walls = 0
	for _, c in M.workspace:FindFirstChild("Lobby"):GetChildren() do
		if c.Name == "Wall" then walls += 1 end
	end
	eq(walls, 5, "muros del lobby (4 + el este partido en 2)")
	assert(CratePlazaLayout.contains(layout, layout.Stations[1].Position))
	assert(not CratePlazaLayout.contains(layout, Config.Lobby.Center))
end)

test("caja de armas: no repite, se elige como arma y no se abre si ya tenés todas", function()
	state.inMatch = false
	p:SetAttribute("Ready", false)
	local idx
	for i, s in layout.Stations do
		if s.Id == "Weapons" then idx = i end
	end
	assert(idx, "no hay plataforma de la caja de armas")
	atStation(idx)
	data.Crates.Owned.FrostKatana = nil
	data.Crates.Owned.InfernoBlade = nil
	data.Weapon = "Bow"
	setGold(100000)
	-- Sin la katana no se puede elegir (ni pidiéndola a mano)
	M.advance(1)
	local res = invoke(p, "Equip", "FrostKatana")
	assert(not res.Ok, "equipó un arma que no tiene")
	-- Con la tirada en 0 sale la primera (katana); la segunda vez, aunque la tirada sea la
	-- misma, sale la que falta: la caja de armas no repite
	CrateService._forceRoll(0)
	local r = open("Weapons")
	assert(r.Ok, tostring(r.Error))
	eq(r.Prize, "FrostKatana", "premio")
	eq(data.Crates.Owned.FrostKatana, 1, "inventario")
	eq(p:GetAttribute("OwnedWeapons"), "FrostKatana", "atributo OwnedWeapons")
	M.advance(Cfg.OpenCooldown + 0.1)
	r = open("Weapons")
	CrateService._forceRoll(nil)
	assert(r.Ok, tostring(r.Error))
	eq(r.Prize, "InfernoBlade", "segunda arma")
	eq(data.Crates.Owned.FrostKatana, 1, "no repitió")
	eq(p:GetAttribute("OwnedWeapons"), "FrostKatana,InfernoBlade", "OwnedWeapons con las dos")
	-- Ya la tiene toda: no deja abrir de nuevo ni cobra
	local gold = data.Currencies.Gold
	local again = open("Weapons")
	assert(not again.Ok and string.find(again.Error, "todas"), "dejó abrir otra vez")
	eq(data.Currencies.Gold, gold, "cobró igual")
	-- Equipar desde el Index = elegirla como arma
	M.advance(1)
	res = invoke(p, "Equip", "FrostKatana")
	assert(res.Ok, tostring(res.Error))
	eq(data.Weapon, "FrostKatana", "arma guardada")
	eq(p:GetAttribute("Weapon"), "FrostKatana", "atributo Weapon")
	eq(p:GetAttribute("EquippedWeapon"), "FrostKatana", "atributo EquippedWeapon")
	-- No queda como aspecto ni como mascota
	assert(data.Crates.Equipped.Character ~= "FrostKatana" and data.Crates.Equipped.Pet ~= "FrostKatana")
	-- Sacarla vuelve a la espada común
	M.advance(1)
	res = invoke(p, "Unequip", "Weapon")
	assert(res.Ok, tostring(res.Error))
	eq(data.Weapon, "Sword", "vuelve a la base")
	eq(p:GetAttribute("EquippedWeapon"), "", "EquippedWeapon vacío")
	eq(Weapons.baseOf("FrostKatana"), "Sword", "base")
end)

print(passed .. " pruebas, 0 fallas")
