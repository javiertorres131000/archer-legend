--!strict
-- Rewards (ModuleScript)
-- Ubicación: ServerScriptService > Server > Rewards
-- Recompensas al terminar una partida. Las calcula y entrega SOLO el servidor, a partir de lo
-- que pasó en la partida (nunca de algo que mande el cliente). Los valores están en
-- Chapters.lua › Rewards de cada capítulo.
--
--   · Por cada oleada superada: GoldPerWave (también si perdés).
--   · Por cada jefe vencido: MiniBoss / Boss (oro y piedras de mejora).
--   · Victoria: VictoryGold y VictoryGems; la primera vez, además FirstClearGems.
--   · Abandonar (se van todos) no da nada; irse a mitad de partida tampoco.
--   · Torre infinita (Endless): oro por piso superado y por jefe; la primera vez que llegás a
--     cada piso múltiplo de 10, gemas, piedras y oro (Modes.towerMilestones). El récord es
--     Chapters.tower.BestWave.
--   · Desafío diario: lo normal del capítulo y, la primera victoria del día, Modes.Daily.Reward.

local Profiles = require(script.Parent.Profiles)
local MasteryService = require(script.Parent.MasteryService)
local Talents = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Talents"))
local Modes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modes"))

export type Amounts = { [string]: number } -- Id de moneda -> cantidad
export type RunInfo = {
	result: string, -- "Victory" | "Defeat"
	wavesCleared: number,
	bossesKilled: { string }, -- tipos de enemigo jefe vencidos
	kills: number, -- bajas de este jugador
	weapon: string?, -- arma con que jugó (maestría); si falta, la elegida en el perfil
}
-- Progreso de la cuenta antes y después (para la barra "te faltan X" de los resultados)
export type AccountProgress = { levelBefore: number, xpBefore: number, level: number, xp: number, needed: number }
export type Granted = {
	amounts: Amounts,
	firstClear: boolean,
	accountXP: number,
	levelsGained: number,
	bestWaveBefore: number, -- mejor oleada en este capítulo antes de esta partida
	newRecord: boolean, -- superó su mejor oleada
	dailyBonus: boolean?, -- desafío diario: cobró el premio del día
	account: AccountProgress,
	mastery: MasteryService.Result?, -- maestría del arma (Shared/Mastery.lua)
}

local Rewards = {}

local function add(amounts: Amounts, id: string, n: number?)
	if n and n > 0 then
		amounts[id] = (amounts[id] or 0) + math.floor(n)
	end
end

-- Cálculo puro (sin tocar el perfil): sirve para probarlo solo.
function Rewards.compute(chapter: any, info: RunInfo, firstClear: boolean): Amounts
	local r = chapter.Rewards
	local amounts: Amounts = {}
	if not r then
		return amounts
	end
	local victory = info.result == "Victory"
	if chapter.Endless then
		-- Torre: sin tope de pisos; cada jefe (de cualquier ambientación) da lo mismo
		add(amounts, "Gold", math.max(0, info.wavesCleared) * (r.GoldPerWave or 0))
		add(amounts, "Gold", #info.bossesKilled * (r.BossGold or 0))
		return amounts
	end
	local waves = math.clamp(info.wavesCleared, 0, chapter.Waves)
	add(amounts, "Gold", waves * (r.GoldPerWave or 0))
	for _, bossType in info.bossesKilled do
		local reward = if chapter.Boss and chapter.Boss.Type == bossType
			then r.Boss
			elseif chapter.MiniBoss and chapter.MiniBoss.Type == bossType then r.MiniBoss
			else nil
		if reward then
			for id, n in reward do
				add(amounts, id, n)
			end
		end
	end
	if victory then
		add(amounts, "Gold", r.VictoryGold)
		add(amounts, "Gems", r.VictoryGems)
		if firstClear then
			add(amounts, "Gems", r.FirstClearGems)
		end
	end
	return amounts
end

-- XP de cuenta de una partida (árbol de talentos). Cálculo puro.
function Rewards.accountXP(chapter: any, info: RunInfo): number
	local bosses, minis = 0, 0
	for _, bossType in info.bossesKilled do
		if chapter.Boss and chapter.Boss.Type == bossType then
			bosses += 1
		elseif chapter.MiniBoss and chapter.MiniBoss.Type == bossType then
			minis += 1
		end
	end
	return Talents.accountXP({
		result = info.result,
		-- En la torre cuenta hasta 3 tramos (si no, la XP de cuenta se dispararía)
		wavesCleared = math.clamp(info.wavesCleared, 0, if chapter.Endless then 30 else (chapter.Waves or info.wavesCleared)),
		bosses = bosses,
		miniBosses = minis,
		kills = math.max(0, math.floor(info.kills)),
	}, chapter.Rewards and chapter.Rewards.LootMult or 1)
end

-- Entrega las recompensas al perfil y anota estadísticas. Devuelve lo que se dio
-- (para mostrarlo en los resultados), o nil si el perfil todavía no está cargado.
function Rewards.grant(player: Player, chapter: any, info: RunInfo): Granted?
	local data = Profiles.get(player)
	local record = Profiles.chapter(player, chapter.Id)
	if not data or not record then
		return nil
	end
	local victory = info.result == "Victory"
	local firstClear = victory and record.Clears == 0 and chapter.Mode == nil
	local amounts = Rewards.compute(chapter, info, firstClear)
	-- Torre: hitos (primera vez en cada piso múltiplo de 10)
	if chapter.Endless then
		for id, n in Modes.towerMilestones(record.BestWave, math.max(record.BestWave, info.wavesCleared)) do
			add(amounts, id, n)
		end
	end
	-- Desafío diario: premio extra la primera victoria del día
	local dailyBonus = false
	if chapter.Mode == "daily" and victory and data.Modes then
		local today = Modes.day(os.time())
		if data.Modes.DailyWonDay ~= today then
			data.Modes.DailyWonDay = today
			dailyBonus = true
			for id, n in Modes.Daily.Reward do
				add(amounts, id, n)
			end
		end
	end
	for id, n in amounts do
		Profiles.addCurrency(player, id, n)
	end

	-- Estadísticas
	data.Stats.Runs += 1
	data.Stats.Kills += math.max(0, math.floor(info.kills))
	data.Stats.BossKills += #info.bossesKilled
	local bestWaveBefore = record.BestWave
	record.BestWave = math.max(record.BestWave, info.wavesCleared)
	if victory then
		data.Stats.Victories += 1
		record.Clears += 1
	end
	local accountXP = Rewards.accountXP(chapter, info)
	local levelBefore, xpBefore = data.Account.Level, data.Account.XP
	local levelsGained = Profiles.addAccountXP(player, accountXP)
	local mastery = MasteryService.grant(player, info.weapon or data.Weapon, {
		result = info.result,
		kills = info.kills,
		wavesCleared = info.wavesCleared,
		bosses = #info.bossesKilled,
	})
	return {
		mastery = mastery,
		amounts = amounts,
		firstClear = firstClear,
		accountXP = accountXP,
		levelsGained = levelsGained,
		bestWaveBefore = bestWaveBefore,
		newRecord = info.wavesCleared > bestWaveBefore,
		dailyBonus = dailyBonus,
		account = {
			levelBefore = levelBefore,
			xpBefore = xpBefore,
			level = data.Account.Level,
			xp = data.Account.XP,
			needed = Talents.xpNeeded(data.Account.Level),
		},
	}
end

return Rewards
