-- RuneDefs (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > RuneDefs
-- Runas permanentes. Las lee el servidor (Runes.lua: guardar, equipar, aplicar) y el cliente
-- (RunesUI: mostrarlas). Dos clases:
--   · Colección (12): cada una que tenés da un bonus pasivo chico. Los duplicados la suben de nivel.
--   · Especiales (5): efectos fuertes. Solo cuentan las que pongas en los 3 espacios activos;
--     el 1º está libre y los otros se desbloquean ganando capítulos (SlotUnlocks).
-- Para agregar una runa: sumala a Collection o Special con un Id nuevo (no cambiar los Id publicados).

local Runes = {}

Runes.MaxLevel = 5
Runes.ActiveSlots = 3
-- Capítulo que hay que ganar para abrir cada espacio activo (nil = libre desde el principio)
Runes.SlotUnlocks = { nil, "forest", "ruins" }
Runes.ChestCost = 60 -- gemas por cofre de runas
Runes.ChestSpecialChance = 0.15 -- chance de que el cofre dé una runa especial
Runes.BossDropChance = 0.35 -- chance de que un jefe o mini-jefe suelte una runa a cada jugador
Runes.DuplicateStones = 5 -- piedras de mejora por una runa repetida que ya no puede subir

-- Stat: campo de PlayerData.Stats. PerLevel: cuánto suma por nivel.
-- Mode "mult" multiplica (0.02 = +2%), "add" suma, "reduce" baja (0.015 = -1,5%).
Runes.Collection = {
	{ Id = "Fury", Name = "Furia", Icon = "🔥", Rarity = "Epic", Stat = "damage", Mode = "mult", PerLevel = 0.02, Text = "daño" },
	{ Id = "Vitality", Name = "Vitalidad", Icon = "💗", Rarity = "Epic", Stat = "maxHealth", Mode = "mult", PerLevel = 0.03, Text = "vida" },
	{ Id = "Eagle", Name = "Ojo de águila", Icon = "🎯", Rarity = "Epic", Stat = "critChance", Mode = "add", PerLevel = 0.01, Text = "prob. de crítico" },
	{ Id = "Brutal", Name = "Golpe brutal", Icon = "💥", Rarity = "Epic", Stat = "critMultiplier", Mode = "add", PerLevel = 0.05, Text = "daño crítico" },
	{ Id = "Swift", Name = "Pies ligeros", Icon = "🍃", Rarity = "Epic", Stat = "walkSpeed", Mode = "mult", PerLevel = 0.015, Text = "velocidad" },
	{ Id = "Magnet", Name = "Imán", Icon = "🧲", Rarity = "Epic", Stat = "pickupRadius", Mode = "mult", PerLevel = 0.05, Text = "imán de XP" },
	{ Id = "Rapid", Name = "Cadencia", Icon = "⏱️", Rarity = "Epic", Stat = "attackInterval", Mode = "reduce", PerLevel = 0.015, Text = "tiempo entre disparos" },
	{ Id = "Embers", Name = "Brasas", Icon = "♨️", Rarity = "Epic", Stat = "burnBonus", Mode = "add", PerLevel = 0.03, Text = "daño de quemadura" },
	{ Id = "Blink", Name = "Paso fugaz", Icon = "💨", Rarity = "Epic", Stat = "dashCooldown", Mode = "reduce", PerLevel = 0.04, Text = "espera del dash" },
	{ Id = "Dragon", Name = "Corazón de dragón", Icon = "🐉", Rarity = "Legendary", Stat = "damage", Mode = "mult", PerLevel = 0.035, Text = "daño" },
	{ Id = "Bastion", Name = "Bastión", Icon = "🛡️", Rarity = "Legendary", Stat = "maxHealth", Mode = "mult", PerLevel = 0.05, Text = "vida" },
	{ Id = "Hawk", Name = "Halcón", Icon = "🦅", Rarity = "Legendary", Stat = "critChance", Mode = "add", PerLevel = 0.015, Text = "prob. de crítico" },
}

-- Especiales: un efecto fijo (no suben de nivel)
Runes.Special = {
	{ Id = "Multishot", Name = "Flecha extra", Icon = "🏹", Rarity = "Mythic", Stat = "frontArrows", Add = 1, Text = "+1 flecha al frente" },
	{ Id = "Fan", Name = "Abanico", Icon = "🪶", Rarity = "Legendary", Stat = "diagonalPairs", Add = 1, Text = "+1 par de flechas diagonales" },
	{ Id = "Pierce", Name = "Perforación", Icon = "🗡️", Rarity = "Legendary", Stat = "pierce", Add = 1, Text = "las flechas atraviesan 1 enemigo" },
	{ Id = "Ricochet", Name = "Rebote", Icon = "🔁", Rarity = "Legendary", Stat = "ricochet", Add = 1, Text = "las flechas rebotan a 1 enemigo" },
	{ Id = "Inferno", Name = "Infierno", Icon = "☄️", Rarity = "Mythic", Stat = "burn", Text = "flechas de fuego desde el principio" },
}

Runes.ById = {}
for _, def in Runes.Collection do
	def.Kind = "Collection"
	Runes.ById[def.Id] = def
end
for _, def in Runes.Special do
	def.Kind = "Special"
	Runes.ById[def.Id] = def
end

-- Bonus total de una runa de colección en ese nivel (0.06 = 6%)
function Runes.amount(def, level: number): number
	return def.PerLevel * math.clamp(level, 0, Runes.MaxLevel)
end

-- Texto del bonus: "+6% daño", "-4,5% tiempo entre disparos", "+0.15 daño crítico"
function Runes.describe(def, level: number?): string
	if def.Kind == "Special" then
		return def.Text
	end
	local x = Runes.amount(def, level or 1)
	if def.Stat == "critMultiplier" then
		return string.format("+%.2f× %s", x, def.Text)
	end
	return string.format("%s%.1f%% %s", if def.Mode == "reduce" then "-" else "+", x * 100, def.Text)
end

-- ¿Cuántos espacios activos tiene abiertos? chapterCleared(id) dice si ganó ese capítulo.
function Runes.unlockedSlots(chapterCleared: (string) -> boolean): number
	local n = 0
	for i = 1, Runes.ActiveSlots do
		local need = Runes.SlotUnlocks[i]
		if need == nil or chapterCleared(need) then
			n = i
		else
			break
		end
	end
	return n
end

-- Aplica las runas a las stats de la partida. owned: { [Id] = nivel } · active: { [espacio] = Id }
-- Pura (sin estado): la usan el servidor y las pruebas.
function Runes.apply(stats: any, owned: { [string]: number }, active: { [number]: string }, slots: number)
	for _, def in Runes.Collection do
		local level = owned[def.Id]
		if level and level > 0 then
			local x = Runes.amount(def, level)
			if def.Mode == "mult" then
				stats[def.Stat] *= 1 + x
			elseif def.Mode == "reduce" then
				stats[def.Stat] *= 1 - x
			else
				stats[def.Stat] += x
			end
		end
	end
	local used = {}
	for i = 1, math.min(slots, Runes.ActiveSlots) do
		local id = active[i]
		local def = id and Runes.ById[id]
		if def and def.Kind == "Special" and owned[id] and not used[id] then
			used[id] = true
			if def.Stat == "burn" then
				stats.burn = true
			else
				stats[def.Stat] += def.Add
			end
		end
	end
end

-- Elige una runa al azar para un cofre o botín. specialChance: probabilidad de que sea especial.
-- Las legendarias y míticas salen la mitad de seguido que las épicas.
function Runes.roll(specialChance: number, random: (() -> number)?): string
	local rnd = random or math.random
	local pool = if rnd() < specialChance then Runes.Special else Runes.Collection
	local total = 0
	for _, def in pool do
		total += if def.Rarity == "Epic" then 2 else 1
	end
	local pick = rnd() * total
	for _, def in pool do
		pick -= if def.Rarity == "Epic" then 2 else 1
		if pick <= 0 then
			return def.Id
		end
	end
	return pool[#pool].Id
end

return Runes
