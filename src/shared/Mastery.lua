-- Mastery (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Mastery
-- Maestría por arma: cuanto más jugás con un arma, más la dominás. Es por FAMILIA (arco,
-- espada, puños): las especiales suman a su base (la Katana de escarcha sube la maestría de
-- Espada), porque usan el mismo mazo de habilidades.
--
--   · XP: se gana al terminar cada partida (Mastery.runXP): bajas, oleadas, jefes y victoria.
--     Abandonar no da. Se guarda en el perfil (Data.Mastery[familia] = XP total).
--   · Niveles 1 a MaxLevel (Mastery.Levels: XP total para llegar a cada nivel).
--   · Bono: +DamagePerLevel de daño por cada nivel después del 1, y crítico extra en los niveles
--     de CritLevels. Solo con esa familia de arma (MasteryService.apply al empezar la partida).
--   · Candados (Locks): algunas habilidades de la segunda tanda de cada arma no salen en las
--     partidas hasta tener ese nivel de maestría. En el menú Arma se ven con 🔒.
--   · Títulos (Titles) y color del borde de la carta del arma (TierColors) según el nivel.
--
-- El cliente recibe la XP en el atributo "Mastery" del Player: "Bow=1200,Sword=0,Fists=40".

local Mastery = {}

Mastery.Families = { "Bow", "Sword", "Fists" }
Mastery.FamilyNames = { Bow = "Arco", Sword = "Espada", Fists = "Puños" }

-- XP total para llegar a cada nivel (índice = nivel)
Mastery.Levels = { 0, 600, 1500, 3000, 5000, 8000, 12000, 17000, 23000, 30000 }
Mastery.MaxLevel = #Mastery.Levels
-- Perfiles de antes de la maestría: arrancan con XP según sus bajas, hasta este nivel
Mastery.MigrationCapLevel = 5

Mastery.DamagePerLevel = 0.02 -- +2% de daño por nivel (nivel 10: +18%)
Mastery.CritLevels = { [5] = 0.02, [10] = 0.03 } -- crítico extra al llegar a esos niveles

-- XP de una partida (cálculo puro)
Mastery.XP = { PerKill = 1, PerWave = 15, PerBoss = 40, Victory = 100, MaxKills = 2500 }

-- Habilidad -> nivel de maestría que la desbloquea (solo de su arma)
Mastery.Locks = {
	Bow = { ArrowRing = 3, PhantomArrow = 5 },
	Sword = { DashSlash = 3, BladeDance = 5 },
	Fists = { Shockwave = 3, DragonFist = 5 },
}

-- Títulos por nivel (el más alto alcanzado)
Mastery.Titles = {
	{ Level = 3, Name = "Aprendiz" },
	{ Level = 6, Name = "Experto" },
	{ Level = 10, Name = "Maestro" },
}
Mastery.TierColors = {
	{ Level = 3, Color = Color3.fromRGB(205, 130, 70) }, -- bronce
	{ Level = 6, Color = Color3.fromRGB(200, 210, 225) }, -- plata
	{ Level = 10, Color = Color3.fromRGB(255, 205, 70) }, -- oro
}

function Mastery.isFamily(id: any): boolean
	return type(id) == "string" and Mastery.FamilyNames[id] ~= nil
end

-- Nivel con esa XP total
function Mastery.levelOf(xp: number): number
	local level = 1
	for i, need in Mastery.Levels do
		if xp >= need then
			level = i
		end
	end
	return level
end

-- Progreso dentro del nivel: (XP hecha en este nivel, XP que pide el nivel). Al máximo: (0, 0).
function Mastery.progress(xp: number): (number, number)
	local level = Mastery.levelOf(xp)
	if level >= Mastery.MaxLevel then
		return 0, 0
	end
	local from, to = Mastery.Levels[level], Mastery.Levels[level + 1]
	return xp - from, to - from
end

-- Bono de ese nivel: daño extra (0.1 = +10%) y crítico extra
function Mastery.bonus(level: number): (number, number)
	local crit = 0
	for at, extra in Mastery.CritLevels do
		if level >= at then
			crit += extra
		end
	end
	return (math.max(1, level) - 1) * Mastery.DamagePerLevel, crit
end

function Mastery.title(level: number): string?
	local name = nil
	for _, t in Mastery.Titles do
		if level >= t.Level then
			name = t.Name
		end
	end
	return name
end

function Mastery.tierColor(level: number): Color3?
	local color = nil
	for _, t in Mastery.TierColors do
		if level >= t.Level then
			color = t.Color
		end
	end
	return color
end

-- ¿Esta habilidad está bloqueada con este nivel de maestría de su arma?
function Mastery.lockLevel(skillId: string): (string?, number?)
	for family, list in Mastery.Locks do
		if list[skillId] then
			return family, list[skillId]
		end
	end
	return nil, nil
end

-- Habilidades bloqueadas con estas XP ({ familia = xp }): set de Id
function Mastery.lockedSkills(xpByFamily: { [string]: number }): { [string]: boolean }
	local locked = {}
	for family, list in Mastery.Locks do
		local level = Mastery.levelOf(xpByFamily[family] or 0)
		for skillId, need in list do
			if level < need then
				locked[skillId] = true
			end
		end
	end
	return locked
end

-- Lo que se desbloquea al llegar a cada nivel entre `from` (exclusivo) y `to` (inclusivo):
-- lista de { Kind = "Skill" | "Title" | "Crit", Id/Name, Level }
function Mastery.unlocksBetween(family: string, from: number, to: number): { any }
	local out = {}
	for level = from + 1, to do
		for skillId, need in Mastery.Locks[family] or {} do
			if need == level then
				table.insert(out, { Kind = "Skill", Id = skillId, Level = level })
			end
		end
		for _, t in Mastery.Titles do
			if t.Level == level then
				table.insert(out, { Kind = "Title", Name = t.Name, Level = level })
			end
		end
		if Mastery.CritLevels[level] then
			table.insert(out, { Kind = "Crit", Amount = Mastery.CritLevels[level], Level = level })
		end
	end
	return out
end

-- XP de maestría de una partida. info: { result, kills, wavesCleared, bosses }
function Mastery.runXP(info: any): number
	if info.result ~= "Victory" and info.result ~= "Defeat" then
		return 0
	end
	local x = Mastery.XP
	local kills = math.clamp(math.floor(info.kills or 0), 0, x.MaxKills)
	local waves = math.clamp(math.floor(info.wavesCleared or 0), 0, 30)
	local total = kills * x.PerKill + waves * x.PerWave + math.max(0, info.bosses or 0) * x.PerBoss
	if info.result == "Victory" then
		total += x.Victory
	end
	return math.floor(total)
end

-- Atributo "Mastery": "Bow=1200,Sword=0,Fists=40"
function Mastery.encode(xpByFamily: { [string]: number }): string
	local parts = {}
	for _, family in Mastery.Families do
		table.insert(parts, family .. "=" .. tostring(math.floor(xpByFamily[family] or 0)))
	end
	return table.concat(parts, ",")
end

function Mastery.decode(text: any): { [string]: number }
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	for _, pair in string.split(text, ",") do
		local family, value = string.match(pair, "^(%w+)=(%d+)$")
		if family and Mastery.isFamily(family) then
			out[family] = tonumber(value) or 0
		end
	end
	return out
end

return Mastery
