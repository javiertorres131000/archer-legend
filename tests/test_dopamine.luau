-- "Dopamina": arranque rápido de niveles y marca de jefe en las muertes (pausa de impacto).
local M = require("./mocks")
require("./GameServer")
local Config = require("./Config")
local Progression = require("./Progression")
local CombatFeed = require("./CombatFeed")
local PlayerData = require("./PlayerData")
local Skills = require("./Skills")
local Remotes = require("./Remotes")
local Synergies = require("./Synergies")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end

print("Dopamina")

test("primeros niveles baratos y después la fórmula de siempre", function()
	Progression.reset()
	local P = Config.Progression
	local expected = { 4, 9, 16, 25 }
	for lvl, xp in expected do
		assert(Progression.xpNeeded(lvl) == xp, string.format("nivel %d: %d", lvl, Progression.xpNeeded(lvl)))
	end
	for lvl = 5, 12 do
		assert(Progression.xpNeeded(lvl) == P.BaseXP + (lvl - 1) * P.XPGrowth, "fórmula normal en nivel " .. lvl)
	end
	-- Siempre sube (nunca un nivel más barato que el anterior)
	for lvl = 2, 20 do
		assert(Progression.xpNeeded(lvl) >= Progression.xpNeeded(lvl - 1), "curva creciente en " .. lvl)
	end
	-- Hasta el nivel 5 se necesita bastante menos que antes (54 contra 90)
	local total = 0
	for lvl = 1, 4 do total += Progression.xpNeeded(lvl) end
	assert(total == 54, "XP hasta el nivel 5: " .. total)
end)

test("sin multiplicadores vuelve a la curva original", function()
	local old = Config.Progression.EarlyLevelMult
	Config.Progression.EarlyLevelMult = nil
	assert(Progression.xpNeeded(1) == Config.Progression.BaseXP)
	Config.Progression.EarlyLevelMult = old
end)

test("subir varios niveles juntos con poca XP al principio", function()
	Progression.reset()
	Progression.addXP(4 + 9)
	assert(Progression.level() == 3, "nivel " .. Progression.level())
	Progression.reset()
end)

test("la muerte de un jefe viaja marcada (b = true); la de un común, no", function()
	local p = M.addPlayer("Mira")
	CombatFeed.clear()
	CombatFeed.kill({ p }, M.Vector3.new(0, 0, 0), M.Color3.new(1, 1, 1), 14, false, true)
	CombatFeed.kill({ p }, M.Vector3.new(0, 0, 0), M.Color3.new(1, 1, 1), 3, false)
	local sent = CombatFeed.collect()[p] or {}
	local boss, common = nil, nil
	for _, e in sent do
		if e.k == "kill" then
			if e.s == 14 then boss = e else common = e end
		end
	end
	assert(boss and boss.b == true, "jefe marcado")
	assert(common and common.b == nil, "común sin marca")
end)

-- Carta dorada: el servidor la elige y, si la tomás, aplica la habilidad 2 veces
local offers = {}
Remotes.SkillOffer.FireClient = function(_, player, offerId, choices, _timeout, _rerolls, golden)
	table.insert(offers, { player = player, offerId = offerId, choices = choices, golden = golden })
end
local G = M.addPlayer("Goldie")
local gState = PlayerData.get(G)
gState.inMatch = true
local function freshOffer()
	table.clear(offers)
	gState.currentOffer = nil
	gState.pendingOffers = 0
	Progression.giveChoice(G)
	return offers[#offers]
end
local function choose(offer, index)
	Remotes.ChooseSkill.OnServerEvent:Fire(G, offer.offerId, index)
end

test("carta dorada: con 100% viaja en la oferta y solo en habilidades con lugar para 2 niveles", function()
	local old = Config.Progression.GoldenCardChance
	Config.Progression.GoldenCardChance = 1
	for _ = 1, 30 do
		gState.stats = PlayerData.newStats()
		local offer = freshOffer()
		assert(offer and offer.golden and offer.golden >= 1, "debería haber carta dorada")
		local id = offer.choices[offer.golden]
		local def = Skills.ById[id]
		assert(id ~= Skills.Heal.Id and def.Max - (gState.stats.stacks[id] or 0) >= 2, "dorada sin lugar: " .. id)
		gState.currentOffer = nil
		gState.offerGolden = 0
	end
	Config.Progression.GoldenCardChance = old
end)

test("elegir la dorada da 2 niveles; otra carta, 1; y no se repite en la siguiente oferta", function()
	local old = Config.Progression.GoldenCardChance
	Config.Progression.GoldenCardChance = 1
	gState.stats = PlayerData.newStats()
	local offer = freshOffer()
	local goldenId = offer.choices[offer.golden]
	choose(offer, offer.golden)
	assert(gState.stats.stacks[goldenId] == 2, "dorada: " .. tostring(gState.stats.stacks[goldenId]))
	assert(gState.offerGolden == 0 and gState.currentOffer == nil, "oferta cerrada")
	-- Otra oferta: elegimos una que no sea la dorada
	gState.stats = PlayerData.newStats()
	offer = freshOffer()
	local other = if offer.golden == 1 then 2 else 1
	local otherId = offer.choices[other]
	choose(offer, other)
	assert((gState.stats.stacks[otherId] or 0) == 1, "común: 1 nivel")
	Config.Progression.GoldenCardChance = old
end)

test("sin probabilidad no hay cartas doradas", function()
	local old = Config.Progression.GoldenCardChance
	Config.Progression.GoldenCardChance = 0
	for _ = 1, 30 do
		gState.stats = PlayerData.newStats()
		local offer = freshOffer()
		assert(offer.golden == 0, "no debería haber dorada")
		gState.currentOffer = nil
	end
	Config.Progression.GoldenCardChance = old
end)

test("si ninguna carta tiene lugar para 2 niveles, no hay dorada aunque toque", function()
	local stats = PlayerData.newStats()
	for _, def in Skills.List do
		stats.stacks[def.Id] = math.max(0, def.Max - 1)
	end
	local old = Config.Progression.GoldenCardChance
	Config.Progression.GoldenCardChance = 1
	assert(Progression.rollGolden(stats, { "Damage", "Crit", Skills.Heal.Id }) == 0)
	Config.Progression.GoldenCardChance = old
end)

test("sinergias: Ids reales, distintos, del mismo mazo y sin pares repetidos", function()
	local seen = {}
	for _, syn in Synergies.List do
		local a, b = Skills.ById[syn.A], Skills.ById[syn.B]
		assert(a and b, "Id inexistente en " .. tostring(syn.Name))
		assert(syn.A ~= syn.B, "par con la misma habilidad: " .. syn.Name)
		assert(type(syn.Name) == "string" and #syn.Name > 0, "sin nombre")
		assert(a.Weapon == nil or b.Weapon == nil or a.Weapon == b.Weapon, "no pueden salir juntas: " .. syn.Name)
		local key = if syn.A < syn.B then syn.A .. "+" .. syn.B else syn.B .. "+" .. syn.A
		assert(not seen[key], "par repetido: " .. key)
		seen[key] = true
	end
end)

test("sinergias: se completan con la nueva + una que ya tenías, y no se repiten", function()
	local owned = { Pierce = 1 }
	local done = Synergies.completedBy("Ricochet", owned)
	assert(#done == 1 and done[1].Name == "Flecha imparable", "Perforación + Rebote")
	assert(#Synergies.completedBy("Ricochet", {}) == 0, "sin la otra no hay sinergia")
	local shown = { [done[1]] = true }
	assert(#Synergies.completedBy("Ricochet", owned, shown) == 0, "ya mostrada")
	-- Una habilidad puede completar varias a la vez
	local many = Synergies.completedBy("Pierce", { Ricochet = 1, ChargedShot = 2 })
	assert(#many == 2, "dos sinergias: " .. #many)
end)

print(passed .. " pruebas, 0 fallas")
