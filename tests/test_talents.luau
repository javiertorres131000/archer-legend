local M = require("./mocks")
require("./GameServer")
local Profiles = require("./Profiles")
local PlayerData = require("./PlayerData")
local TalentService = require("./TalentService")
local Talents = require("./Talents")
local Loot = require("./Loot")
local Progression = require("./Progression")
local Rewards = require("./Rewards")
local Chapters = require("./Chapters")
local Remotes = require("./Remotes")
print("Árbol de talentos")
local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local p = M.addPlayer("Talentoso")
local data = Profiles.get(p)
local function buy(id) M.advance(1); return TalentService.buy(p, id) end
local function levelUpTo(level)
	while data.Account.Level < level do
		Profiles.addAccountXP(p, Talents.xpNeeded(data.Account.Level) - data.Account.XP)
	end
end

test("catálogo: ids únicos, enlaces válidos y todo se alcanza desde el núcleo", function()
	local seen = {}
	for _, def in Talents.List do
		assert(not seen[def.Id], def.Id); seen[def.Id] = true
		assert(Talents.Branches[def.Branch], def.Id)
		assert(def.Max >= 1 and def.Points >= 1)
		assert(def.X >= 40 and def.X <= 960 and def.Y >= 40 and def.Y <= 700, def.Id)
		assert(type(def.Bonus(1)) == "string" and type(def.Description) == "string")
		for _, link in def.Links do assert(Talents.ById[link], def.Id .. " → " .. link) end
	end
	-- Comprar todo al máximo en orden: si algún nodo no se alcanza, queda afuera
	local all, changed = {}, true
	while changed do
		changed = false
		for _, def in Talents.List do
			if not all[def.Id] and Talents.reachable(all, def) then all[def.Id] = def.Max; changed = true end
		end
	end
	for _, def in Talents.List do assert(all[def.Id], "inalcanzable: " .. def.Id) end
end)

test("progresión: XP por nivel y oro por punto crecen; el árbol completo es caro", function()
	for level = 1, 50 do assert(Talents.xpNeeded(level + 1) > Talents.xpNeeded(level)) end
	for spent = 0, 100 do assert(Talents.goldCost(spent + 1, 1) >= Talents.goldCost(spent, 1)) end
	local total = 0
	for _, def in Talents.List do total += def.Max * def.Points end
	local gold = Talents.goldCost(0, total)
	assert(total >= 80, "puntos totales " .. total)
	assert(gold >= 200000, "oro total " .. gold) -- 4000 por partida no alcanza ni de cerca
	assert(Talents.goldCost(0, 5) <= 1000) -- los primeros puntos son accesibles
	print(string.format("         árbol completo: %d puntos (nivel %d) · %d oro", total, total, gold))
end)

test("perfil nuevo: nivel 1 con un punto, solo el núcleo disponible", function()
	assert(data.Account.Level == 1 and data.Account.XP == 0)
	assert(p:GetAttribute("AccountLevel") == 1 and p:GetAttribute("TalentPoints") == 1)
	data.Currencies.Gold = 100000
	assert(not buy("Edge")) -- no conectado
	assert(not buy("Volley")); assert(not buy("Inventado")); assert(not buy(nil)); assert(not buy({}))
	assert(buy("Core")); assert(data.Talents.Core == 1)
	assert(p:GetAttribute("TalentPoints") == 0)
	local ok, msg = buy("Edge") -- conectado pero sin puntos
	assert(not ok and string.find(msg, "puntos"))
end)

test("comprar cobra oro creciente, una sola vez", function()
	levelUpTo(4) -- 3 puntos más
	assert(p:GetAttribute("TalentPoints") == 3)
	data.Currencies.Gold = Talents.goldCost(1, 1) - 1
	local ok, msg = buy("Edge"); assert(not ok and string.find(msg, "oro"))
	data.Currencies.Gold = 100000
	local first = Talents.goldCost(1, 1)
	assert(buy("Edge")); assert(data.Currencies.Gold == 100000 - first)
	local second = Talents.goldCost(2, 1)
	assert(second > first)
	assert(buy("Edge")); assert(data.Currencies.Gold == 100000 - first - second)
	assert(data.Talents.Edge == 2 and p:GetAttribute("TalentPoints") == 1)
end)

test("frecuencia, listo y partida", function()
	M.advance(1)
	local a = TalentService.buy(p, "Edge")
	local b = TalentService.buy(p, "Edge")
	assert(a and not b and data.Talents.Edge == 3)
	levelUpTo(6)
	p:SetAttribute("Ready", true); assert(not buy("Edge")); p:SetAttribute("Ready", false)
	PlayerData.get(p).inMatch = true; assert(not buy("Edge")); PlayerData.get(p).inMatch = false
	assert(data.Talents.Edge == 3)
end)

test("máximo y nodos clave con puntos y gemas", function()
	levelUpTo(30)
	for _ = 1, 2 do assert(buy("Edge")) end
	local ok, msg = buy("Edge"); assert(not ok and string.find(msg, "máximo"))
	assert(buy("Magnet")); assert(buy("Scout"))
	data.Currencies.Gems = 0
	ok, msg = buy("HeadStart"); assert(not ok and string.find(msg, "gemas"))
	data.Currencies.Gems = 100
	local before = p:GetAttribute("TalentPoints")
	assert(buy("HeadStart")); assert(data.Currencies.Gems == 40)
	assert(p:GetAttribute("TalentPoints") == before - Talents.ById.HeadStart.Points)
end)

test("reiniciar devuelve los puntos, no el oro", function()
	local gold = data.Currencies.Gold
	assert(TalentService.reset(p) == false) -- frecuencia: pedido recién hecho
	M.advance(1)
	assert(TalentService.reset(p))
	assert(next(data.Talents) == nil and data.Currencies.Gold == gold)
	assert(p:GetAttribute("TalentPoints") == Talents.pointsForLevel(data.Account.Level))
	M.advance(1); assert(not TalentService.reset(p)) -- ya vacío
end)

test("aplicar suma a las stats de la partida (sin acumular entre partidas)", function()
	data.Talents = { Core = 1, Edge = 5, Tough = 2, Greed = 2, Reroll = 1, Piercing = 1, EternalFlame = 1 }
	local base = PlayerData.newStats()
	local a = PlayerData.newStats(); TalentService.apply(p, a)
	assert(math.abs(a.damage - base.damage * 1.03 * 1.15) < 1e-6)
	assert(a.maxHealth == base.maxHealth + 5 + 16)
	assert(math.abs(a.goldBonus - 0.08) < 1e-6 and a.rerolls == 1 and a.pierce == base.pierce + 1 and a.burn == true)
	local b = PlayerData.newStats(); TalentService.apply(p, b)
	assert(b.damage == a.damage and b.rerolls == 1)
	data.Talents = {}
end)

test("perfil: v3 → v4 borra la lista vieja; reconcile repara nivel y árbol", function()
	local migrated = Profiles.migrate(3, { Talents = { Might = 5, Greed = 3 }, Currencies = { Gold = 50 } })
	local clean = Profiles.reconcile(migrated)
	assert(next(clean.Talents) == nil and clean.Currencies.Gold == 50 and clean.Account.Level == 1)
	-- Rangos de más se recortan; ids falsos se borran
	clean = Profiles.reconcile({ Account = { Level = 40, XP = 5 }, Talents = { Core = 9, Edge = 99, Fake = 3, Hawk = -1 } })
	assert(clean.Talents.Core == 1 and clean.Talents.Edge == 5 and clean.Talents.Fake == nil and clean.Talents.Hawk == nil)
	-- Más puntos gastados que los del nivel: el árbol se vacía (los puntos vuelven)
	clean = Profiles.reconcile({ Account = { Level = 2 }, Talents = { Core = 1, Edge = 5 } })
	assert(next(clean.Talents) == nil)
	-- Nivel y XP rotos
	clean = Profiles.reconcile({ Account = { Level = -4, XP = 1e9 } })
	assert(clean.Account.Level == 1 and clean.Account.XP < Talents.xpNeeded(1))
end)

test("XP de cuenta al terminar: por oleadas, bajas, jefes y victoria; sube niveles", function()
	local forest = Chapters[1]
	local defeat = Rewards.accountXP(forest, { result = "Defeat", wavesCleared = 3, bossesKilled = {}, kills = 50 })
	assert(defeat == 3 * Talents.Config.XPPerWave + 50 * Talents.Config.XPPerKill)
	local win = Rewards.accountXP(forest, { result = "Victory", wavesCleared = 10, bossesKilled = { forest.MiniBoss.Type, forest.Boss.Type }, kills = 99999 })
	local C = Talents.Config
	assert(win == 10 * C.XPPerWave + C.XPKillCap * C.XPPerKill + C.XPMiniBoss + C.XPBoss + C.XPVictory)
	assert(Rewards.accountXP(Chapters[3], { result = "Defeat", wavesCleared = 3, bossesKilled = {}, kills = 50 }) > defeat)
	local q = M.addPlayer("Novato")
	local granted = Rewards.grant(q, forest, { result = "Victory", wavesCleared = 10, bossesKilled = { forest.MiniBoss.Type, forest.Boss.Type }, kills = 300 })
	assert(granted and granted.accountXP > 0 and granted.levelsGained >= 1)
	local qd = Profiles.get(q)
	assert(qd.Account.Level == 1 + granted.levelsGained and q:GetAttribute("AccountLevel") == qd.Account.Level)
	assert(Profiles.addAccountXP(q, -5) == 0 and Profiles.addAccountXP(q, 0 / 0) == 0)
end)

test("Codicia: más oro solo para quien la tiene", function()
	local q = M.addPlayer("SinCodicia")
	local sp, sq = PlayerData.get(p), PlayerData.get(q)
	sp.stats = PlayerData.newStats(); sq.stats = PlayerData.newStats()
	sp.stats.goldBonus = 0.5
	local got = Loot.grant({ p, q }, { Gold = 10 })
	assert(got[p].Gold == 15 and got[q].Gold == 10)
end)

test("Ventaja y Otra mano: carta gratis y cambio de cartas validado por el servidor", function()
	local s = PlayerData.get(p)
	s.stats = PlayerData.newStats(); s.stats.rerolls = 1
	s.inMatch = true; s.life = "ALIVE"; s.currentOffer = nil; s.pendingOffers = 0
	local offers = {}
	local old = Remotes.SkillOffer.FireClient
	Remotes.SkillOffer.FireClient = function(_, _, offerId, choices, _, rerolls) table.insert(offers, { offerId, choices, rerolls }) end
	Progression.giveChoice(p)
	assert(s.currentOffer and #offers == 1 and offers[1][3] == 1)
	local first = s.offerId
	Remotes.RerollSkills.OnServerEvent:Fire(p, first + 7) -- offerId viejo/falso
	assert(#offers == 1 and s.stats.rerolls == 1)
	Remotes.RerollSkills.OnServerEvent:Fire(p, first)
	assert(#offers == 2 and s.offerId == first + 1 and s.stats.rerolls == 0 and offers[2][3] == 0)
	Remotes.RerollSkills.OnServerEvent:Fire(p, s.offerId) -- sin cambios restantes
	assert(#offers == 2)
	Remotes.ChooseSkill.OnServerEvent:Fire(p, first, 1); assert(s.currentOffer) -- offerId anterior: no vale
	Remotes.ChooseSkill.OnServerEvent:Fire(p, s.offerId, 1); assert(not s.currentOffer)
	Remotes.SkillOffer.FireClient = old
	s.inMatch = false
	Progression.syncPause()
end)

test("pedido remoto: Get, Buy y Reset responden con mensaje", function()
	local sent = {}
	local old = Remotes.TalentState.FireClient
	Remotes.TalentState.FireClient = function(_, _, levels, message) table.insert(sent, { levels, message }) end
	Remotes.TalentRequest.OnServerEvent:Fire(p, "Get")
	assert(#sent == 1 and next(sent[1][1]) == nil)
	M.advance(1)
	Remotes.TalentRequest.OnServerEvent:Fire(p, "Buy", "Core")
	assert(#sent == 2 and string.sub(sent[2][2], 1, 3) == "✔" and sent[2][1].Core == 1)
	M.advance(1)
	Remotes.TalentRequest.OnServerEvent:Fire(p, "Reset")
	assert(#sent == 3 and string.sub(sent[3][2], 1, 3) == "✔")
	Remotes.TalentRequest.OnServerEvent:Fire(p, "Hackear", "Core")
	assert(#sent == 3)
	Remotes.TalentState.FireClient = old
end)

print(passed .. " pruebas, 0 fallas")
