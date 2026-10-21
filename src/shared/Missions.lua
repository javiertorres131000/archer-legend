--!strict
-- Missions (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Missions
-- Misiones diarias y semanales: cuáles hay, qué piden y qué dan. El servidor (MissionService)
-- elige 3 de cada lista por jugador, cuenta el progreso al terminar cada partida y paga al
-- cobrar; el cliente (ShopUI, pestaña Misiones) solo muestra.
--
-- Reinicio: las diarias a las 00:00 UTC; las semanales los lunes a las 00:00 UTC.
-- Cada jugador recibe sus misiones al azar, pero siempre las mismas en ese período (la tirada
-- usa su UserId y el número de día/semana): cambiar de servidor no las vuelve a sortear.
--
-- Cómo se mide cada tipo (Kind), al terminar la partida (lo que pasó en ella):
--   Kills       enemigos que derrotaste vos
--   WeaponKills enemigos que derrotaste con un arma (Arco, Espada o Puños; las especiales
--               cuentan como su arma base). El arma se sortea con la misión.
--   Waves       oleadas superadas (también si perdés)
--   Bosses      jefes y mini jefes vencidos por el equipo
--   Wins        partidas ganadas
--   Runs        partidas jugadas hasta el final (ganadas o perdidas; abandonar no cuenta)
--   Chests      cofres abiertos en la partida (cualquiera del equipo: el botín es compartido)
--   Gold        oro juntado en la partida (botín de enemigos y cofres)
--   Crates      cajas abiertas en la plaza volcánica (cuenta al momento, en el lobby)
--
-- Para cambiar metas o premios: Target y Reward abajo. Para agregar una misión: sumala a la
-- lista con un Id nuevo y un Kind de los de arriba (no cambies el Id de una ya publicada: el
-- progreso guardado lo usa). Balance de referencia (Config.Economy, README): una victoria del
-- capítulo 1 da ~1.600 oro y ~45 gemas; las 3 diarias juntas dan ~900 oro y ~10 gemas y las
-- 3 semanales ~6.000 oro, ~70 gemas y algunas piedras.

export type Reward = { [string]: number } -- Id de moneda -> cantidad
export type Def = {
	Id: string,
	Kind: string,
	Target: number,
	Reward: Reward,
	Text: string, -- "%d" se reemplaza por la meta; "%s" por el arma (WeaponKills)
}

local Missions = {}

Missions.PerPeriod = 3 -- misiones diarias y semanales que recibe cada jugador
Missions.Weapons = { "Bow", "Sword", "Fists" } -- armas que pueden pedir las WeaponKills

Missions.Daily = {
	{ Id = "D_Kills", Kind = "Kills", Target = 300, Reward = { Gold = 250 }, Text = "Derrotá %d enemigos" },
	{ Id = "D_WeaponKills", Kind = "WeaponKills", Target = 200, Reward = { Gold = 300 }, Text = "Derrotá %d enemigos con %s" },
	{ Id = "D_Waves", Kind = "Waves", Target = 8, Reward = { Gold = 250 }, Text = "Superá %d oleadas" },
	{ Id = "D_Bosses", Kind = "Bosses", Target = 2, Reward = { Gold = 350, Gems = 5 }, Text = "Vencé %d jefes o mini jefes" },
	{ Id = "D_Runs", Kind = "Runs", Target = 2, Reward = { Gold = 200, Gems = 3 }, Text = "Jugá %d partidas completas" },
	{ Id = "D_Chests", Kind = "Chests", Target = 8, Reward = { Gold = 300, Gems = 5 }, Text = "Abrí %d cofres en partida" },
	{ Id = "D_Gold", Kind = "Gold", Target = 800, Reward = { Gold = 250 }, Text = "Juntá %d de oro en partidas" },
	{ Id = "D_Crates", Kind = "Crates", Target = 1, Reward = { Gold = 150, Gems = 3 }, Text = "Abrí %d caja en la plaza" },
} :: { Def }

Missions.Weekly = {
	{ Id = "W_Kills", Kind = "Kills", Target = 4000, Reward = { Gold = 2000, Gems = 20 }, Text = "Derrotá %d enemigos" },
	{ Id = "W_WeaponKills", Kind = "WeaponKills", Target = 2500, Reward = { Gold = 2200, Gems = 20 }, Text = "Derrotá %d enemigos con %s" },
	{ Id = "W_Wins", Kind = "Wins", Target = 3, Reward = { Gold = 2500, Gems = 30 }, Text = "Ganá %d partidas" },
	{ Id = "W_Waves", Kind = "Waves", Target = 60, Reward = { Gold = 2000, Gems = 20 }, Text = "Superá %d oleadas" },
	{ Id = "W_Bosses", Kind = "Bosses", Target = 12, Reward = { Gold = 2000, Gems = 25, Stones = 10 }, Text = "Vencé %d jefes o mini jefes" },
	{ Id = "W_Chests", Kind = "Chests", Target = 60, Reward = { Gold = 1800, Gems = 20 }, Text = "Abrí %d cofres en partida" },
	{ Id = "W_Runs", Kind = "Runs", Target = 12, Reward = { Gold = 1500, Gems = 15, Stones = 5 }, Text = "Jugá %d partidas completas" },
	{ Id = "W_Gold", Kind = "Gold", Target = 10000, Reward = { Gold = 2000, Gems = 15 }, Text = "Juntá %d de oro en partidas" },
} :: { Def }

Missions.ById = {} :: { [string]: Def }
for _, list in { Missions.Daily, Missions.Weekly } do
	for _, def in list do
		Missions.ById[def.Id] = def
	end
end

Missions.WeaponNames = { Bow = "el arco", Sword = "la espada", Fists = "los puños" }

local DAY = 86400

-- Número de día (UTC) y de semana (lunes a domingo, UTC) para una hora Unix
function Missions.day(t: number): number
	return math.floor(t / DAY)
end

function Missions.week(t: number): number
	-- El 1/1/1970 fue jueves: corriendo 3 días, las semanas arrancan el lunes
	return math.floor((t / DAY + 3) / 7)
end

-- Segundos que faltan para el próximo reinicio
function Missions.dailyResetIn(t: number): number
	return (Missions.day(t) + 1) * DAY - t
end

function Missions.weeklyResetIn(t: number): number
	return ((Missions.week(t) + 1) * 7 - 3) * DAY - t
end

-- Texto de una misión ("Derrotá 200 enemigos con la espada")
function Missions.describe(def: Def, weapon: string?): string
	if def.Kind == "WeaponKills" then
		return string.format(def.Text, def.Target, Missions.WeaponNames[weapon or "Bow"] or "tu arma")
	end
	return string.format(def.Text, def.Target)
end

-- Sorteo de las misiones de un jugador en un período: siempre el mismo para (UserId, período).
-- Devuelve { { Id, Weapon? } } sin repetir.
function Missions.pick(list: { Def }, userId: number, period: number, salt: number): { { Id: string, Weapon: string? } }
	local rng = Random.new((userId % 2147483647) * 31 + period * 7919 + salt)
	local pool = table.clone(list)
	local out = {}
	for _ = 1, math.min(Missions.PerPeriod, #pool) do
		local i = rng:NextInteger(1, #pool)
		local def = table.remove(pool, i) :: Def
		local entry: { Id: string, Weapon: string? } = { Id = def.Id }
		if def.Kind == "WeaponKills" then
			entry.Weapon = Missions.Weapons[rng:NextInteger(1, #Missions.Weapons)]
		end
		table.insert(out, entry)
	end
	return out
end

-- "12 h 05 min" / "3 d 4 h"
function Missions.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // DAY
	local h = (seconds % DAY) // 3600
	local m = (seconds % 3600) // 60
	if d > 0 then
		return string.format("%d d %d h", d, h)
	elseif h > 0 then
		return string.format("%d h %02d min", h, m)
	end
	return string.format("%d min", math.max(1, m))
end

return Missions
