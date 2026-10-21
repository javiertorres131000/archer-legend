-- Modes (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Modes
-- Modos de juego además de los capítulos. Se eligen en el lobby como un capítulo más (su Id
-- viaja por "SelectChapter"). Está en Shared porque el lobby muestra qué toca hoy y el servidor
-- arma las oleadas con lo mismo.
--
--   · Torre infinita ("tower"): pisos sin fin. Cada piso es una oleada; cada 10 pisos cambia la
--     ambientación (Bosque → Ruinas → Fortaleza → Glaciar → Desierto y vuelta a empezar, más
--     difícil), con mini jefe en el piso 5 y jefe en el 10 de cada tramo. Se juega hasta caer.
--     Se desbloquea ganando el Capítulo 1. Récord: el piso más alto (perfil, Chapters.tower).
--     Premios: oro por piso y jefe, y la primera vez que llegás a cada piso múltiplo de 10,
--     gemas y piedras (Tower.Milestone).
--   · Desafío diario ("daily"): un capítulo con 2 modificadores, distintos cada día (00:00 UTC),
--     iguales para todos. Siempre disponible. Ganarlo da el premio normal y, la primera vez del
--     día, el premio del desafío (Daily.Reward).

local Chapters = require(script.Parent.Chapters)

local Modes = {}

Modes.List = {
	{
		Id = "tower",
		Name = "Torre infinita",
		Icon = "🗼",
		Description = "Pisos sin fin que se ponen cada vez más difíciles. Jefe cada 10 pisos. ¿Hasta dónde llegás?",
		Requires = "forest", -- hay que ganar este capítulo
	},
	{
		Id = "daily",
		Name = "Desafío diario",
		Icon = "📅",
		Description = "Un capítulo con modificadores que cambian cada día. Premio extra la primera victoria del día.",
	},
}

Modes.ById = {}
for _, m in Modes.List do
	Modes.ById[m.Id] = m
end

function Modes.isMode(id: any): boolean
	return type(id) == "string" and Modes.ById[id] ~= nil
end

local function clone(t: any): any
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then clone(v) else v
	end
	return out
end

---------------------------------------------------------------------
-- Torre infinita
---------------------------------------------------------------------

Modes.Tower = {
	FloorsPerTheme = 10, -- pisos de cada ambientación (mini jefe en el 5, jefe en el 10)
	LapHealth = 1.8, -- cada vuelta completa a las 5 ambientaciones: vida × esto
	LapDamage = 1.3, -- y daño × esto
	GoldPerFloor = 30,
	BossGold = 120, -- por cada jefe o mini jefe
	-- Primera vez que llegás a cada piso múltiplo de 10
	Milestone = { Every = 10, Gems = 25, Stones = 5, Gold = 500 },
}

-- Ambientación (índice de capítulo) de un piso
function Modes.towerTheme(floor: number): number
	local block = (math.max(1, floor) - 1) // Modes.Tower.FloorsPerTheme
	return block % #Chapters + 1
end

-- Definición "de capítulo" para un piso de la torre (la usa Waves en vez de un capítulo)
function Modes.towerChapter(floor: number): any
	floor = math.max(1, math.floor(floor))
	local per = Modes.Tower.FloorsPerTheme
	local themeIndex = Modes.towerTheme(floor)
	local base = Chapters[themeIndex]
	local lap = (floor - 1) // (per * #Chapters)
	local def = clone(base)
	def.Id = "tower"
	def.Mode = "tower"
	def.ThemeIndex = themeIndex
	def.Name = string.format("Torre · Piso %d", floor)
	def.Endless = true -- sin victoria: se juega hasta caer
	def.Waves = per
	def.LocalWave = (floor - 1) % per + 1 -- piso dentro del tramo (pool, presupuesto, jefes)
	def.HealthMult = base.HealthMult * Modes.Tower.LapHealth ^ lap
	def.DamageMult = base.DamageMult * Modes.Tower.LapDamage ^ lap
	def.Rewards = {
		GoldPerWave = Modes.Tower.GoldPerFloor,
		LootMult = (base.Rewards and base.Rewards.LootMult or 1),
		BossGold = Modes.Tower.BossGold,
	}
	return def
end

-- Premios de hito: lo que se gana la primera vez al pasar de `before` a `after` pisos
function Modes.towerMilestones(before: number, after: number): { [string]: number }
	local m = Modes.Tower.Milestone
	local out: { [string]: number } = {}
	local count = after // m.Every - before // m.Every
	if count > 0 then
		out.Gems = m.Gems * count
		out.Stones = m.Stones * count
		out.Gold = m.Gold * count
	end
	return out
end

---------------------------------------------------------------------
-- Desafío diario
---------------------------------------------------------------------

-- Modificadores: Chapter cambia la definición del capítulo; Player, las stats del jugador
-- (Server/PlayerData.newStats) al empezar la partida.
Modes.Modifiers = {
	{ Id = "Horde", Name = "Horda", Text = "+40% de enemigos", Chapter = function(c) c.Budget.Base *= 1.4; c.Budget.PerWave *= 1.4 end },
	{ Id = "Giants", Name = "Gigantes", Text = "Enemigos con +50% de vida", Chapter = function(c) c.HealthMult *= 1.5 end },
	{ Id = "Fury", Name = "Furia", Text = "Enemigos con +35% de daño", Chapter = function(c) c.DamageMult *= 1.35 end },
	{ Id = "Glass", Name = "Cañón de cristal", Text = "Tenés la mitad de vida y +60% de daño", Player = function(s) s.maxHealth *= 0.5; s.damage *= 1.6 end },
	{ Id = "Greed", Name = "Codicia", Text = "Botín ×2, enemigos +25% de vida", Chapter = function(c) c.Rewards.LootMult *= 2; c.HealthMult *= 1.25 end },
	{ Id = "Rush", Name = "Contrarreloj", Text = "Los enemigos aparecen el doble de rápido", Chapter = function(c) c.Interval = { c.Interval[1] * 0.5, c.Interval[2] * 0.5 } end },
	{ Id = "Swift", Name = "Pies ligeros", Text = "+25% de velocidad y cadencia", Player = function(s) s.walkSpeed *= 1.25; s.attackInterval *= 0.8 end },
	{ Id = "Elite", Name = "Élite", Text = "Más capitanes élite desde la oleada 2", Chapter = function(c) table.insert(c.Pool, { Type = "EliteCaptain", From = 2, Weight = 2 }) end },
}

Modes.ModifierById = {}
for _, m in Modes.Modifiers do
	Modes.ModifierById[m.Id] = m
end

Modes.Daily = {
	ModifierCount = 2,
	-- Dificultad base del desafío (sin modificadores): la del Capítulo 2, sea cual sea la
	-- ambientación, para que cualquiera pueda intentarlo
	HealthMult = 1.4,
	DamageMult = 1.15,
	Reward = { Gems = 30, Gold = 1500, Stones = 5 }, -- primera victoria del día
}

-- Día UTC de una hora Unix (igual que las misiones)
function Modes.day(t: number): number
	return math.floor(t / 86400)
end

-- Qué toca un día: ambientación (índice de capítulo) y los Id de los modificadores
function Modes.dailyInfo(day: number): { chapter: number, modifiers: { string } }
	local rng = Random.new(day * 7349 + 11)
	local index = rng:NextInteger(1, #Chapters)
	local pool = {}
	for _, m in Modes.Modifiers do
		table.insert(pool, m.Id)
	end
	local mods = {}
	for _ = 1, math.min(Modes.Daily.ModifierCount, #pool) do
		table.insert(mods, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return { chapter = index, modifiers = mods }
end

-- Definición "de capítulo" del desafío de ese día
function Modes.dailyChapter(day: number): any
	local info = Modes.dailyInfo(day)
	local base = Chapters[info.chapter]
	local def = clone(base)
	def.Id = "daily"
	def.Mode = "daily"
	def.ThemeIndex = info.chapter
	def.Name = "Desafío diario · " .. base.Name
	def.HealthMult = Modes.Daily.HealthMult
	def.DamageMult = Modes.Daily.DamageMult
	def.Modifiers = info.modifiers
	def.Rewards.FirstClearGems = 0 -- el premio del desafío es el diario (Modes.Daily.Reward)
	for _, id in info.modifiers do
		local m = Modes.ModifierById[id]
		if m and m.Chapter then
			m.Chapter(def)
		end
	end
	return def
end

-- Aplica los modificadores del día a las stats de un jugador (al empezar)
function Modes.applyDailyPlayer(stats: any, day: number)
	for _, id in Modes.dailyInfo(day).modifiers do
		local m = Modes.ModifierById[id]
		if m and m.Player then
			m.Player(stats)
		end
	end
end

-- Texto para el lobby: "Ruinas Perdidas · Horda + Furia"
function Modes.dailyText(day: number): string
	local info = Modes.dailyInfo(day)
	local names = {}
	for _, id in info.modifiers do
		local m = Modes.ModifierById[id]
		table.insert(names, m and m.Name or id)
	end
	return Chapters[info.chapter].Name .. " · " .. table.concat(names, " + ")
end

return Modes
