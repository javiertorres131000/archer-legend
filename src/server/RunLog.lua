--!strict
-- RunLog (ModuleScript)
-- Ubicación: ServerScriptService > Server > RunLog
-- Registro de partidas para balancear con datos reales (Config.RunLog).
--
-- Al terminar cada partida anota una fila por jugador: capítulo, resultado, oleadas, duración,
-- jugadores, bajas, daño, caídas, oro/gemas/piedras ganados, XP de cuenta y la build (talentos,
-- equipo, runas, habilidades y objetos de la partida).
--   · Siempre queda en memoria (las últimas MemoryLimit) y, si Print está activo, en la Salida.
--   · Si SaveToDataStore está activo, se agrega a un DataStore aparte ("RunLog_v1"), una clave
--     por día (UTC) con hasta PerDayLimit filas. Una sola escritura por partida y por servidor.
--     No toca los perfiles: si falla, solo se pierde la estadística.
--
-- Para ver el resumen, en la barra de comandos del servidor (o el panel de prueba, F2):
--   require(game.ServerScriptService.Server.RunLog).report(7)   -- últimos 7 días

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Talents = require(Shared:WaitForChild("Talents"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Profiles = require(script.Parent.Profiles)

local Cfg = Config.RunLog

export type Entry = {
	t: number, -- os.time()
	ch: string, -- Id del capítulo
	r: string, -- "Victory" | "Defeat" | "Abandoned"
	w: number, -- oleadas superadas
	tw: number, -- oleadas del capítulo
	s: number, -- duración (s)
	n: number, -- jugadores
	lv: number, -- nivel alcanzado en la partida
	k: number, -- bajas
	dmg: number, -- daño hecho
	dn: number, -- veces derribado
	rv: number, -- rescates
	g: number, -- oro ganado (botín + recompensas)
	gm: number, -- gemas
	st: number, -- piedras
	xp: number, -- XP de cuenta
	al: number, -- nivel de cuenta al terminar
	tp: number, -- puntos de talento gastados
	eq: number, -- poder de equipo (suma de rango de rareza × nivel de lo equipado)
	ru: number, -- niveles de runas de colección + especiales activas
	sk: { [string]: number }, -- habilidades elegidas
	it: { [string]: number }, -- objetos de la partida
}

local RunLog = {}

local memory: { Entry } = {}
local pending: { Entry } = {}
local store: DataStore? = nil
local storeDisabled = false

function RunLog.dayKey(t: number): string
	return "day:" .. os.date("!%Y-%m-%d", t)
end

local function getStore(): DataStore?
	if storeDisabled or not Cfg.SaveToDataStore then
		return nil
	end
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Cfg.StoreName)
		end)
		if not ok then
			storeDisabled = true
			return nil
		end
		store = result
	end
	return store
end

local function power(data: any): (number, number, number)
	local spent = Talents.spent(data.Talents or {})
	local eq = 0
	local byUid = {}
	for _, item in data.Inventory or {} do
		byUid[item.Uid] = item
	end
	for _, uid in data.Equipment or {} do
		local item = byUid[uid]
		if item then
			eq += (Rarities.index(item.Rarity) or 1) * item.Level
		end
	end
	local runes = 0
	if type(data.Runes) == "table" then
		for _, level in data.Runes.Owned or {} do
			if type(level) == "number" then
				runes += level
			end
		end
	end
	return spent, eq, runes
end

-- Arma la fila de un jugador. Pura salvo por leer su perfil.
-- summary: Run.summary · personal: lo que se mandó en RunEnded · state: PlayerData del jugador
function RunLog.entry(player: Player, summary: any, personal: any, state: any): Entry
	local data: any = Profiles.get(player) or {}
	local spent, eq, runes = power(data)
	local rewards = personal.rewards or {}
	local loot = personal.loot or {}
	local function earned(id: string): number
		return (rewards[id] or 0) + (loot[id] or 0)
	end
	local ch = Chapters[summary.chapter]
	return {
		t = os.time(),
		ch = if ch then ch.Id else tostring(summary.chapter),
		r = summary.result,
		w = summary.wavesCleared,
		tw = summary.totalWaves,
		s = summary.time,
		n = summary.partySize,
		lv = summary.level,
		k = if state then state.kills else 0,
		dmg = if state then math.floor(state.damageDealt) else 0,
		dn = if state then state.downs else 0,
		rv = if state then state.revives else 0,
		g = earned("Gold"),
		gm = earned("Gems"),
		st = earned("Stones"),
		xp = personal.accountXP or 0,
		al = if data.Account then data.Account.Level else 1,
		tp = spent,
		eq = eq,
		ru = runes,
		sk = if state then table.clone(state.stats.stacks) else {},
		it = if state then table.clone(state.items) else {},
	}
end

function RunLog.record(entry: Entry)
	table.insert(memory, entry)
	while #memory > Cfg.MemoryLimit do
		table.remove(memory, 1)
	end
	table.insert(pending, entry)
	if Cfg.Print then
		print(string.format(
			"[RunLog] %s %s · oleadas %d/%d · %ds · %d jug · bajas %d · daño %d · oro %d · XP %d · cuenta nv %d · talentos %d · equipo %d · runas %d",
			entry.ch, entry.r, entry.w, entry.tw, entry.s, entry.n, entry.k, entry.dmg, entry.g, entry.xp, entry.al, entry.tp, entry.eq, entry.ru
		))
	end
end

-- Guarda lo pendiente (una escritura). Corre aparte: no frena el fin de partida.
function RunLog.flush()
	if #pending == 0 then
		return
	end
	local batch = pending
	pending = {}
	local ds = getStore()
	if not ds then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ds:UpdateAsync(RunLog.dayKey(os.time()), function(old: any)
				local list = if type(old) == "table" then old else {}
				for _, e in batch do
					if #list >= Cfg.PerDayLimit then
						break
					end
					table.insert(list, e)
				end
				return list
			end)
		end)
		if not ok then
			local msg = tostring(err)
			-- En Studio sin acceso a las APIs no se reintenta más
			if RunService:IsStudio() and (string.find(msg, "StudioAccessToApisNotAllowed", 1, true) or string.find(msg, "publish", 1, true)) then
				storeDisabled = true
			else
				warn("[RunLog] No se pudo guardar el registro:", msg)
			end
		end
	end)
end

function RunLog.recent(): { Entry }
	return memory
end

export type ChapterReport = {
	runs: number,
	victories: number,
	avgWaves: number,
	avgTime: number,
	avgGold: number,
	avgXP: number,
	avgKills: number,
	avgDps: number,
	avgDowns: number,
	avgPlayers: number,
}

-- Promedios por capítulo. Pura: sirve para probarla y para cualquier lista de filas.
function RunLog.aggregate(entries: { Entry }): { [string]: ChapterReport }
	local sums: { [string]: any } = {}
	for _, e in entries do
		if e.r == "Abandoned" then
			continue
		end
		local s = sums[e.ch]
		if not s then
			s = { runs = 0, victories = 0, w = 0, s = 0, g = 0, xp = 0, k = 0, dps = 0, dn = 0, n = 0 }
			sums[e.ch] = s
		end
		s.runs += 1
		s.victories += if e.r == "Victory" then 1 else 0
		s.w += e.w
		s.s += e.s
		s.g += e.g
		s.xp += e.xp
		s.k += e.k
		s.dps += e.dmg / math.max(1, e.s)
		s.dn += e.dn
		s.n += e.n
	end
	local out = {}
	for ch, s in sums do
		local n = s.runs
		out[ch] = {
			runs = n,
			victories = s.victories,
			avgWaves = s.w / n,
			avgTime = s.s / n,
			avgGold = s.g / n,
			avgXP = s.xp / n,
			avgKills = s.k / n,
			avgDps = s.dps / n,
			avgDowns = s.dn / n,
			avgPlayers = s.n / n,
		}
	end
	return out
end

-- Junta las filas de los últimos `days` días (DataStore si se puede; si no, la memoria).
function RunLog.load(days: number?): { Entry }
	local ds = getStore()
	if not ds then
		return table.clone(memory)
	end
	local all = {}
	local now = os.time()
	for i = 0, math.max(1, days or 7) - 1 do
		local ok, list = pcall(function()
			return ds:GetAsync(RunLog.dayKey(now - i * 86400))
		end)
		if ok and type(list) == "table" then
			for _, e in list do
				table.insert(all, e)
			end
		end
	end
	if #all == 0 then
		return table.clone(memory)
	end
	return all
end

-- Imprime el resumen en la Salida (y lo devuelve como texto).
function RunLog.report(days: number?): string
	local entries = RunLog.load(days)
	local report = RunLog.aggregate(entries)
	local lines = { string.format("[RunLog] Resumen de %d partidas", #entries) }
	for _, ch in Chapters do
		local r = report[ch.Id]
		if r then
			table.insert(lines, string.format(
				"  %s: %d partidas · %d%% victorias · oleadas %.1f · %ds · oro %d · XP %d · bajas %d · DPS %d · caídas %.1f · %.1f jug",
				ch.Name, r.runs, math.floor(r.victories / r.runs * 100 + 0.5), r.avgWaves, math.floor(r.avgTime),
				math.floor(r.avgGold), math.floor(r.avgXP), math.floor(r.avgKills), math.floor(r.avgDps), r.avgDowns, r.avgPlayers
			))
		end
	end
	local text = table.concat(lines, "\n")
	print(text)
	return text
end

-- Para las pruebas
function RunLog.reset()
	table.clear(memory)
	table.clear(pending)
	store = nil
	storeDisabled = false
end

return RunLog
