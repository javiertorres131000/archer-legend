--!strict
-- MissionService (ModuleScript)
-- Ubicación: ServerScriptService > Server > MissionService
-- Misiones diarias y semanales (lista y premios en Shared/Missions.lua). Todo lo decide el
-- servidor: el progreso sale de lo que pasó en la partida (MatchManager llama a onRunEnded con
-- los números del servidor) y de las cajas abiertas (CrateService llama a add). El cliente
-- solo pide ver y cobrar.
--
-- Remotes.MissionRequest (RemoteFunction):
--   ("Get")                  → { Ok, Daily = {...}, Weekly = {...}, DailyResetIn, WeeklyResetIn }
--   ("Claim", "Daily" | "Weekly", número 1..3) → lo mismo, ya cobrada (o { Ok = false, Error })
-- Cada misión: { Id, Text, Kind, Progress, Target, Reward, Claimed, Done }
-- Atributo del Player "MissionsClaimable": cuántas están completas sin cobrar (para el aviso
-- del botón Misiones en el lobby).
--
-- Reinicio: si cambió el día o la semana (UTC), se sortean nuevas al cargar el perfil, al
-- pedirlas o al sumar progreso. Las completas sin cobrar de un período que ya pasó se pierden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Missions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Missions"))
local Profiles = require(script.Parent.Profiles)

local MissionService = {}

-- Lo que pasó en una partida para un jugador (lo arma MatchManager con datos del servidor)
export type RunInfo = {
	kills: number,
	weapon: string, -- arma base con la que jugó ("Bow" | "Sword" | "Fists")
	wavesCleared: number,
	bosses: number,
	victory: boolean,
	finished: boolean, -- terminó la partida (ganó o perdió; abandonar no cuenta)
	chests: number,
	gold: number,
}

local lastRequest: { [Player]: number } = {}
local now = function(): number
	return os.time()
end

-- Para las pruebas: fijar la hora
function MissionService._setClock(f: (() -> number)?)
	now = f or function()
		return os.time()
	end
end

local function fresh(list: { Missions.Def }, userId: number, period: number, salt: number): { any }
	local out = {}
	for _, pick in Missions.pick(list, userId, period, salt) do
		table.insert(out, { Id = pick.Id, Weapon = pick.Weapon, Progress = 0, Claimed = false })
	end
	return out
end

-- Si cambió el día o la semana, sortea misiones nuevas. Devuelve true si cambió algo.
function MissionService.refresh(player: Player): boolean
	local data = Profiles.get(player)
	if not data then
		return false
	end
	local m = data.Missions
	local t = now()
	local changed = false
	local day, week = Missions.day(t), Missions.week(t)
	if m.Day ~= day or #m.Daily == 0 then
		m.Day = day
		m.Daily = fresh(Missions.Daily, player.UserId, day, 1)
		changed = true
	end
	if m.Week ~= week or #m.Weekly == 0 then
		m.Week = week
		m.Weekly = fresh(Missions.Weekly, player.UserId, week, 2)
		changed = true
	end
	return changed
end

local function claimable(data: any): number
	local n = 0
	for _, list in { data.Missions.Daily, data.Missions.Weekly } do
		for _, e in list do
			local def = Missions.ById[e.Id]
			if def and not e.Claimed and e.Progress >= def.Target then
				n += 1
			end
		end
	end
	return n
end

function MissionService.publish(player: Player)
	local data = Profiles.get(player)
	if data and player.Parent then
		player:SetAttribute("MissionsClaimable", claimable(data))
	end
end

-- Suma progreso a todas las misiones (sin cobrar) de un tipo. filter: para WeaponKills, el arma.
function MissionService.add(player: Player, kind: string, amount: number, filter: string?)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local data = Profiles.get(player)
	if not data then
		return
	end
	MissionService.refresh(player)
	local changed = false
	for _, list in { data.Missions.Daily, data.Missions.Weekly } do
		for _, e in list do
			local def = Missions.ById[e.Id]
			if def and def.Kind == kind and not e.Claimed and e.Progress < def.Target then
				if kind ~= "WeaponKills" or e.Weapon == filter then
					e.Progress = math.min(def.Target, e.Progress + math.floor(amount))
					changed = true
				end
			end
		end
	end
	if changed then
		MissionService.publish(player)
		Profiles.saveSoon(player)
	end
end

-- Al terminar la partida (ganada o perdida)
function MissionService.onRunEnded(player: Player, info: RunInfo)
	if not info.finished then
		return
	end
	MissionService.add(player, "Kills", info.kills)
	MissionService.add(player, "WeaponKills", info.kills, info.weapon)
	MissionService.add(player, "Waves", info.wavesCleared)
	MissionService.add(player, "Bosses", info.bosses)
	MissionService.add(player, "Runs", 1)
	MissionService.add(player, "Chests", info.chests)
	MissionService.add(player, "Gold", info.gold)
	if info.victory then
		MissionService.add(player, "Wins", 1)
	end
end

-- Lo que ve el cliente
function MissionService.view(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { Ok = false, Error = "Tu perfil todavía está cargando." }
	end
	if MissionService.refresh(player) then
		Profiles.saveSoon(player)
	end
	local function list(entries: { any }): { any }
		local out = {}
		for _, e in entries do
			local def = Missions.ById[e.Id]
			if def then
				table.insert(out, {
					Id = def.Id,
					Kind = def.Kind,
					Text = Missions.describe(def, e.Weapon),
					Progress = e.Progress,
					Target = def.Target,
					Reward = table.clone(def.Reward),
					Claimed = e.Claimed,
					Done = e.Progress >= def.Target,
				})
			end
		end
		return out
	end
	local t = now()
	MissionService.publish(player)
	return {
		Ok = true,
		Daily = list(data.Missions.Daily),
		Weekly = list(data.Missions.Weekly),
		DailyResetIn = Missions.dailyResetIn(t),
		WeeklyResetIn = Missions.weeklyResetIn(t),
	}
end

function MissionService.claim(player: Player, period: any, index: any): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { Ok = false, Error = "Tu perfil todavía está cargando." }
	end
	if period ~= "Daily" and period ~= "Weekly" then
		return { Ok = false, Error = "Pedido inválido." }
	end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Missions.PerPeriod then
		return { Ok = false, Error = "Pedido inválido." }
	end
	MissionService.refresh(player)
	local entry = (data.Missions :: any)[period][index]
	local def = entry and Missions.ById[entry.Id]
	if not entry or not def then
		return { Ok = false, Error = "Esa misión no existe." }
	end
	if entry.Claimed then
		return { Ok = false, Error = "Ya la cobraste." }
	end
	if entry.Progress < def.Target then
		return { Ok = false, Error = "Todavía no la completaste." }
	end
	-- Sin yields entre marcarla y pagar
	entry.Claimed = true
	for id, n in def.Reward do
		Profiles.addCurrency(player, id, n)
	end
	Profiles.saveSoon(player)
	local view = MissionService.view(player)
	view.Claimed = def.Reward
	return view
end

local function onRequest(player: Player, action: any, a: any, b: any): { [string]: any }
	local t = os.clock()
	if t - (lastRequest[player] or -math.huge) < 0.25 then
		return { Ok = false, Error = "Esperá un momento." }
	end
	lastRequest[player] = t
	if action == "Get" then
		return MissionService.view(player)
	elseif action == "Claim" then
		return MissionService.claim(player, a, b)
	end
	return { Ok = false, Error = "Pedido inválido." }
end

function MissionService.init(remotes: any)
	remotes.MissionRequest.OnServerInvoke = onRequest
	Profiles.onLoaded(function(player)
		if MissionService.refresh(player) then
			Profiles.saveSoon(player)
		end
		MissionService.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return MissionService
