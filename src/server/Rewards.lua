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

local Profiles = require(script.Parent.Profiles)

export type Amounts = { [string]: number } -- Id de moneda -> cantidad
export type RunInfo = {
	result: string, -- "Victory" | "Defeat"
	wavesCleared: number,
	bossesKilled: { string }, -- tipos de enemigo jefe vencidos
	kills: number, -- bajas de este jugador
}
export type Granted = { amounts: Amounts, firstClear: boolean }

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

-- Entrega las recompensas al perfil y anota estadísticas. Devuelve lo que se dio
-- (para mostrarlo en los resultados), o nil si el perfil todavía no está cargado.
function Rewards.grant(player: Player, chapter: any, info: RunInfo): Granted?
	local data = Profiles.get(player)
	local record = Profiles.chapter(player, chapter.Id)
	if not data or not record then
		return nil
	end
	local victory = info.result == "Victory"
	local firstClear = victory and record.Clears == 0
	local amounts = Rewards.compute(chapter, info, firstClear)
	for id, n in amounts do
		Profiles.addCurrency(player, id, n)
	end

	-- Estadísticas
	data.Stats.Runs += 1
	data.Stats.Kills += math.max(0, math.floor(info.kills))
	data.Stats.BossKills += #info.bossesKilled
	record.BestWave = math.max(record.BestWave, info.wavesCleared)
	if victory then
		data.Stats.Victories += 1
		record.Clears += 1
	end
	return { amounts = amounts, firstClear = firstClear }
end

return Rewards
