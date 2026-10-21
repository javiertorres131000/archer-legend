-- Misiones diarias y semanales: sorteo estable, progreso desde la partida, cobro seguro y
-- reinicio por día/semana (UTC).
local M = require("./mocks")
require("./GameServer")
local Profiles = require("./Profiles")
local Remotes = require("./Remotes")
local Missions = require("./Missions")
local MissionService = require("./MissionService")

local passed = 0
local function test(name, f) f(); passed += 1; print("  ok   " .. name) end
local function eq(a, b, msg)
	if a ~= b then error(string.format("%s: esperaba %s, obtuvo %s", msg or "", tostring(b), tostring(a)), 2) end
end
local invoke = Remotes.MissionRequest.OnServerInvoke

print("Misiones")
-- Lunes 2 de marzo de 2026, 12:00 UTC
local MONDAY = 1772452800
local clock = MONDAY
MissionService._setClock(function() return clock end)
local p = M.addPlayer("Misionero", 4242)
local data = Profiles.get(p)
local function get() M.advance(1); return invoke(p, "Get") end
local function claim(period, i) M.advance(1); return invoke(p, "Claim", period, i) end

test("listas válidas: Id únicos, metas y premios positivos", function()
	local seen = {}
	for _, list in { Missions.Daily, Missions.Weekly } do
		assert(#list >= Missions.PerPeriod)
		for _, d in list do
			assert(not seen[d.Id], "Id repetido " .. d.Id)
			seen[d.Id] = true
			assert(d.Target > 0 and next(d.Reward) ~= nil, d.Id)
			assert(Missions.describe(d, "Sword") ~= "")
		end
	end
end)

test("días y semanas UTC: la semana arranca el lunes", function()
	eq(Missions.week(MONDAY), Missions.week(MONDAY + 6 * 86400), "misma semana hasta el domingo")
	eq(Missions.week(MONDAY + 7 * 86400), Missions.week(MONDAY) + 1, "otra semana el lunes siguiente")
	eq(Missions.week(MONDAY - 13 * 3600), Missions.week(MONDAY) - 1, "el domingo es de la anterior")
	eq(Missions.dailyResetIn(MONDAY), 12 * 3600, "faltan 12 h")
	eq(Missions.weeklyResetIn(MONDAY), 6 * 86400 + 12 * 3600, "faltan 6 d 12 h")
end)

test("perfil: 3 diarias y 3 semanales distintas, siempre las mismas en el período", function()
	local r = get()
	assert(r.Ok, tostring(r.Error))
	eq(#r.Daily, 3, "diarias")
	eq(#r.Weekly, 3, "semanales")
	assert(r.Daily[1].Id ~= r.Daily[2].Id and r.Daily[2].Id ~= r.Daily[3].Id and r.Daily[1].Id ~= r.Daily[3].Id)
	local a = Missions.pick(Missions.Daily, 4242, Missions.day(MONDAY), 1)
	local b = Missions.pick(Missions.Daily, 4242, Missions.day(MONDAY), 1)
	for i = 1, 3 do
		eq(a[i].Id, b[i].Id, "mismo sorteo")
		eq(r.Daily[i].Id, a[i].Id, "el del perfil")
	end
end)

-- Para probar con misiones conocidas
local function setDaily(ids)
	data.Missions.Daily = {}
	for _, id in ids do
		table.insert(data.Missions.Daily, { Id = id, Weapon = if id == "D_WeaponKills" then "Sword" else nil, Progress = 0, Claimed = false })
	end
end

test("progreso al terminar la partida: kills, arma, partidas; abandonar no cuenta", function()
	setDaily({ "D_Kills", "D_WeaponKills", "D_Runs" })
	local info = { kills = 150, weapon = "Bow", wavesCleared = 5, bosses = 1, victory = false, finished = false, chests = 3, gold = 400 }
	MissionService.onRunEnded(p, info)
	eq(data.Missions.Daily[1].Progress, 0, "abandonó")
	info.finished = true
	MissionService.onRunEnded(p, info)
	eq(data.Missions.Daily[1].Progress, 150, "kills")
	eq(data.Missions.Daily[2].Progress, 0, "con arco no cuenta para la espada")
	eq(data.Missions.Daily[3].Progress, 1, "partidas")
	info.weapon = "Sword"
	info.kills = 400
	MissionService.onRunEnded(p, info)
	eq(data.Missions.Daily[1].Progress, 300, "tope en la meta")
	eq(data.Missions.Daily[2].Progress, 200, "con espada")
	eq(data.Missions.Daily[3].Progress, 2, "dos partidas")
	eq(p:GetAttribute("MissionsClaimable"), 3, "aviso del lobby")
end)

test("cobrar: paga una vez; incompletas y pedidos raros no", function()
	local gold, gems = data.Currencies.Gold, data.Currencies.Gems
	local r = claim("Daily", 1)
	assert(r.Ok, tostring(r.Error))
	eq(data.Currencies.Gold, gold + 250, "oro")
	assert(r.Daily[1].Claimed and r.Claimed.Gold == 250)
	assert(not claim("Daily", 1).Ok, "cobró dos veces")
	eq(data.Currencies.Gold, gold + 250, "no pagó de nuevo")
	r = claim("Daily", 3)
	assert(r.Ok)
	eq(data.Currencies.Gems, gems + 3, "gemas")
	assert(not claim("Daily", 4).Ok and not claim("Daily", 1.5).Ok and not claim("Monthly", 1).Ok and not claim("Daily", "1").Ok)
	setDaily({ "D_Bosses", "D_Waves", "D_Gold" })
	assert(not claim("Daily", 1).Ok, "incompleta")
	-- Muy seguido: límite de frecuencia
	M.advance(1)
	invoke(p, "Get")
	assert(not invoke(p, "Get").Ok, "sin límite de frecuencia")
end)

test("cajas cuentan al abrirlas; las ya cobradas no suman", function()
	setDaily({ "D_Crates", "D_Kills", "D_Runs" })
	MissionService.add(p, "Crates", 1)
	eq(data.Missions.Daily[1].Progress, 1)
	MissionService.add(p, "Crates", -5)
	MissionService.add(p, "Crates", 0 / 0)
	eq(data.Missions.Daily[1].Progress, 1, "valores raros")
end)

test("reinicio: al día siguiente diarias nuevas, las semanales siguen", function()
	local weekly = data.Missions.Weekly[1].Id
	data.Missions.Weekly[1].Progress = 5
	clock = MONDAY + 86400
	local r = get()
	assert(r.Ok)
	eq(data.Missions.Day, Missions.day(clock), "día nuevo")
	for _, m in r.Daily do assert(m.Progress == 0 and not m.Claimed) end
	eq(data.Missions.Weekly[1].Id, weekly, "misma semanal")
	eq(data.Missions.Weekly[1].Progress, 5, "progreso semanal")
	clock = MONDAY + 7 * 86400
	get()
	eq(data.Missions.Weekly[1].Progress, 0, "semana nueva")
end)

test("perfil guardado: el reconcile limpia misiones rotas", function()
	local raw = { Missions = { Day = 3, Daily = { { Id = "NoExiste", Progress = 1, Claimed = false }, { Id = "D_Kills", Progress = 99999, Claimed = false } }, Week = 1, Weekly = "x" } }
	local rec = Profiles.reconcile(raw)
	eq(#rec.Missions.Daily, 1, "sacó la que no existe")
	eq(rec.Missions.Daily[1].Progress, Missions.ById.D_Kills.Target, "progreso con tope")
	eq(#rec.Missions.Weekly, 0, "semanales inválidas")
end)

MissionService._setClock(nil)
print(passed .. " pruebas, 0 fallas")
