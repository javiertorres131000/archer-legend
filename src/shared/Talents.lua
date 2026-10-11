-- Talents (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > Talents
-- Árbol de talentos permanente: un núcleo arriba y tres ramas (Ataque, Defensa, Utilidad).
-- Lo comparten servidor y cliente: el servidor (TalentService) valida y cobra; el cliente solo dibuja.
--
-- Cómo se sube (pensado para que sea lento y progresivo):
--   · PUNTOS: se ganan subiendo el nivel de cuenta (XP de cada partida, Talents.accountXP).
--     Cada nivel pide más XP que el anterior (Talents.xpNeeded).
--   · ORO: cada punto cuesta más que el anterior según cuántos puntos tengas gastados en total
--     (Talents.goldCost), sin importar en qué nodo. Tener mucho oro no alcanza: hacen falta niveles.
--   · Algunos nodos clave cuestan además gemas.
--   · Solo se desbloquea un nodo conectado (Links) a otro que ya tengas.
--
-- Campos de cada nodo:
--   Id (no cambiar: es la clave en el perfil) · Name · Icon · Branch · Kind
--   Kind: "root" (núcleo) · "minor" (stat chica, varios rangos) · "keystone" (efecto grande)
--   X, Y: posición en el lienzo del árbol (TalentsUI; 1000 × 760)
--   Links: ids previos; alcanza con tener UNO de ellos
--   Max: rangos · Points: puntos por rango · Gems: gemas por rango (opcional)
--   Apply(stats, rank) · Bonus(rank): texto del efecto con ese rango

local Talents = {}

Talents.Config = {
	StartingPoints = 1, -- puntos con nivel 1 (para el núcleo)
	PointsPerLevel = 1,
	XPBase = 300, -- XP para pasar de nivel 1 a 2
	XPGrowth = 100, -- cada nivel pide esto más que el anterior
	GoldBase = 150, -- oro del primer punto
	GoldGrowth = 1.06, -- cada punto gastado encarece el siguiente un 6%
	-- XP de cuenta al terminar una partida (× LootMult del capítulo). También si perdés.
	XPPerWave = 20,
	XPPerKill = 1,
	XPKillCap = 600, -- tope de bajas que cuentan por partida
	XPMiniBoss = 60,
	XPBoss = 120,
	XPVictory = 150,
}

Talents.Branches = {
	Core = { Name = "Núcleo", Color = Color3.fromRGB(255, 214, 120) },
	Attack = { Name = "Ataque", Color = Color3.fromRGB(255, 92, 72) },
	Defense = { Name = "Defensa", Color = Color3.fromRGB(90, 180, 255) },
	Utility = { Name = "Utilidad", Color = Color3.fromRGB(120, 230, 140) },
}

local function pct(n: number): string
	return string.format("%g%%", math.floor(n * 1000 + 0.5) / 10)
end

Talents.List = {
	-- Núcleo
	{
		Id = "Core", Name = "Corazón del arquero", Icon = "🏹", Branch = "Core", Kind = "root",
		X = 500, Y = 70, Links = {}, Max = 1, Points = 1,
		Description = "El comienzo del árbol. Abre las tres ramas.",
		Apply = function(s, _r) s.damage *= 1.03; s.maxHealth += 5 end,
		Bonus = function(_r) return "+3% daño · +5 vida" end,
	},

	-- Ataque
	{
		Id = "Edge", Name = "Filo", Icon = "🗡", Branch = "Attack", Kind = "minor",
		X = 390, Y = 150, Links = { "Core" }, Max = 5, Points = 1,
		Description = "Más daño por flecha.",
		Apply = function(s, r) s.damage *= 1 + 0.03 * r end,
		Bonus = function(r) return "+" .. pct(0.03 * r) .. " daño" end,
	},
	{
		Id = "Hawk", Name = "Ojo de halcón", Icon = "🎯", Branch = "Attack", Kind = "minor",
		X = 270, Y = 215, Links = { "Edge" }, Max = 5, Points = 1,
		Description = "Más probabilidad de crítico.",
		Apply = function(s, r) s.critChance += 0.01 * r end,
		Bonus = function(r) return "+" .. pct(0.01 * r) .. " crítico" end,
	},
	{
		Id = "Draw", Name = "Tensión", Icon = "🏹", Branch = "Attack", Kind = "minor",
		X = 365, Y = 275, Links = { "Edge" }, Max = 5, Points = 1,
		Description = "Disparás más rápido.",
		Apply = function(s, r) s.attackInterval *= 1 - 0.02 * r end,
		Bonus = function(r) return "+" .. pct(0.02 * r) .. " cadencia" end,
	},
	{
		Id = "Strike", Name = "Golpe certero", Icon = "💥", Branch = "Attack", Kind = "minor",
		X = 170, Y = 310, Links = { "Hawk" }, Max = 3, Points = 1,
		Description = "Los críticos pegan más.",
		Apply = function(s, r) s.critMultiplier += 0.1 * r end,
		Bonus = function(r) return "+" .. pct(0.1 * r) .. " daño crítico" end,
	},
	{
		Id = "Cinder", Name = "Brasas", Icon = "🔥", Branch = "Attack", Kind = "minor",
		X = 300, Y = 375, Links = { "Draw" }, Max = 3, Points = 1,
		Description = "La quemadura hace más daño.",
		Apply = function(s, r) s.burnBonus += 0.05 * r end,
		Bonus = function(r) return "+" .. pct(0.05 * r) .. " quemadura" end,
	},
	{
		Id = "Piercing", Name = "Flecha perforante", Icon = "➶", Branch = "Attack", Kind = "keystone",
		X = 95, Y = 410, Links = { "Strike" }, Max = 1, Points = 3,
		Description = "Tus flechas atraviesan un enemigo más desde el principio.",
		Apply = function(s, _r) s.pierce += 1 end,
		Bonus = function(_r) return "+1 enemigo atravesado" end,
	},
	{
		Id = "EternalFlame", Name = "Llama eterna", Icon = "☄", Branch = "Attack", Kind = "keystone",
		X = 255, Y = 475, Links = { "Cinder" }, Max = 1, Points = 3,
		Description = "Empezás cada partida con flechas de fuego.",
		Apply = function(s, _r) s.burn = true end,
		Bonus = function(_r) return "Flechas de fuego" end,
	},
	{
		Id = "Fury", Name = "Furia", Icon = "😤", Branch = "Attack", Kind = "minor",
		X = 175, Y = 550, Links = { "Piercing", "EternalFlame" }, Max = 5, Points = 1,
		Description = "Todavía más daño.",
		Apply = function(s, r) s.damage *= 1 + 0.04 * r end,
		Bonus = function(r) return "+" .. pct(0.04 * r) .. " daño" end,
	},
	{
		Id = "Volley", Name = "Maestro arquero", Icon = "🎇", Branch = "Attack", Kind = "keystone",
		X = 155, Y = 665, Links = { "Fury" }, Max = 1, Points = 5,
		Description = "Disparás una flecha frontal extra desde el principio.",
		Apply = function(s, _r) s.frontArrows += 1 end,
		Bonus = function(_r) return "+1 flecha frontal" end,
	},

	-- Defensa
	{
		Id = "Tough", Name = "Robustez", Icon = "❤", Branch = "Defense", Kind = "minor",
		X = 500, Y = 170, Links = { "Core" }, Max = 5, Points = 1,
		Description = "Más vida máxima.",
		Apply = function(s, r) s.maxHealth += 8 * r end,
		Bonus = function(r) return "+" .. 8 * r .. " vida" end,
	},
	{
		Id = "Vigor", Name = "Vigor", Icon = "💪", Branch = "Defense", Kind = "minor",
		X = 445, Y = 285, Links = { "Tough" }, Max = 3, Points = 1,
		Description = "Vida máxima en porcentaje.",
		Apply = function(s, r) s.maxHealth *= 1 + 0.04 * r end,
		Bonus = function(r) return "+" .. pct(0.04 * r) .. " vida" end,
	},
	{
		Id = "Reflex", Name = "Reflejos", Icon = "💨", Branch = "Defense", Kind = "minor",
		X = 555, Y = 285, Links = { "Tough" }, Max = 5, Points = 1,
		Description = "El dash recarga más rápido.",
		Apply = function(s, r) s.dashCooldown *= 1 - 0.04 * r end,
		Bonus = function(r) return "-" .. pct(0.04 * r) .. " recarga del dash" end,
	},
	{
		Id = "Colossus", Name = "Coloso", Icon = "🗿", Branch = "Defense", Kind = "keystone",
		X = 445, Y = 405, Links = { "Vigor" }, Max = 1, Points = 3,
		Description = "Mucha más vida máxima.",
		Apply = function(s, _r) s.maxHealth *= 1.2 end,
		Bonus = function(_r) return "+20% vida" end,
	},
	{
		Id = "Phantom", Name = "Paso fantasma", Icon = "👻", Branch = "Defense", Kind = "keystone",
		X = 555, Y = 405, Links = { "Reflex" }, Max = 1, Points = 3,
		Description = "Te movés más rápido y el dash recarga mucho antes.",
		Apply = function(s, _r) s.walkSpeed *= 1.06; s.dashCooldown *= 0.85 end,
		Bonus = function(_r) return "+6% velocidad · -15% recarga del dash" end,
	},
	{
		Id = "Guard", Name = "Guardia", Icon = "🛡", Branch = "Defense", Kind = "minor",
		X = 500, Y = 530, Links = { "Colossus", "Phantom" }, Max = 5, Points = 1,
		Description = "Más vida máxima.",
		Apply = function(s, r) s.maxHealth += 10 * r end,
		Bonus = function(r) return "+" .. 10 * r .. " vida" end,
	},
	{
		Id = "Bastion", Name = "Bastión", Icon = "🏰", Branch = "Defense", Kind = "keystone",
		X = 500, Y = 665, Links = { "Guard" }, Max = 1, Points = 5,
		Description = "La cima de la defensa: vida y velocidad.",
		Apply = function(s, _r) s.maxHealth += 40; s.walkSpeed *= 1.04 end,
		Bonus = function(_r) return "+40 vida · +4% velocidad" end,
	},

	-- Utilidad
	{
		Id = "Magnet", Name = "Magnetismo", Icon = "🧲", Branch = "Utility", Kind = "minor",
		X = 610, Y = 150, Links = { "Core" }, Max = 5, Points = 1,
		Description = "Juntás orbes desde más lejos.",
		Apply = function(s, r) s.pickupRadius *= 1 + 0.06 * r end,
		Bonus = function(r) return "+" .. pct(0.06 * r) .. " imán" end,
	},
	{
		Id = "Greed", Name = "Codicia", Icon = "💰", Branch = "Utility", Kind = "minor",
		X = 730, Y = 215, Links = { "Magnet" }, Max = 5, Points = 1,
		Description = "Los enemigos te dan más oro (solo a vos).",
		Apply = function(s, r) s.goldBonus += 0.04 * r end,
		Bonus = function(r) return "+" .. pct(0.04 * r) .. " oro" end,
	},
	{
		Id = "Scout", Name = "Explorador", Icon = "👟", Branch = "Utility", Kind = "minor",
		X = 635, Y = 275, Links = { "Magnet" }, Max = 3, Points = 1,
		Description = "Te movés más rápido.",
		Apply = function(s, r) s.walkSpeed *= 1 + 0.02 * r end,
		Bonus = function(r) return "+" .. pct(0.02 * r) .. " velocidad" end,
	},
	{
		Id = "Midas", Name = "Toque de oro", Icon = "🪙", Branch = "Utility", Kind = "minor",
		X = 830, Y = 310, Links = { "Greed" }, Max = 3, Points = 1,
		Description = "Todavía más oro de los enemigos.",
		Apply = function(s, r) s.goldBonus += 0.06 * r end,
		Bonus = function(r) return "+" .. pct(0.06 * r) .. " oro" end,
	},
	{
		Id = "HeadStart", Name = "Ventaja", Icon = "⭐", Branch = "Utility", Kind = "keystone",
		X = 700, Y = 410, Links = { "Scout" }, Max = 2, Points = 3, Gems = 60,
		Description = "Empezás cada partida eligiendo habilidades gratis.",
		Apply = function(s, r) s.startChoices += r end,
		Bonus = function(r) return r .. (if r == 1 then " habilidad" else " habilidades") .. " al empezar" end,
	},
	{
		Id = "Reroll", Name = "Otra mano", Icon = "🎲", Branch = "Utility", Kind = "keystone",
		X = 860, Y = 420, Links = { "Midas" }, Max = 3, Points = 2, Gems = 40,
		Description = "Podés cambiar las cartas de habilidad (botón 🎲), una vez por rango y por partida.",
		Apply = function(s, r) s.rerolls += r end,
		Bonus = function(r) return r .. (if r == 1 then " cambio" else " cambios") .. " de cartas" end,
	},
	{
		Id = "Collector", Name = "Coleccionista", Icon = "💎", Branch = "Utility", Kind = "minor",
		X = 780, Y = 530, Links = { "HeadStart", "Reroll" }, Max = 3, Points = 1,
		Description = "Imán y oro.",
		Apply = function(s, r) s.pickupRadius *= 1 + 0.05 * r; s.goldBonus += 0.03 * r end,
		Bonus = function(r) return "+" .. pct(0.05 * r) .. " imán · +" .. pct(0.03 * r) .. " oro" end,
	},
	{
		Id = "Fortune", Name = "Rey de la fortuna", Icon = "👑", Branch = "Utility", Kind = "keystone",
		X = 800, Y = 665, Links = { "Collector" }, Max = 1, Points = 5,
		Description = "La cima de la utilidad: mucho más oro y un cambio de cartas extra.",
		Apply = function(s, _r) s.goldBonus += 0.15; s.rerolls += 1 end,
		Bonus = function(_r) return "+15% oro · +1 cambio de cartas" end,
	},
}

Talents.ById = {}
for _, def in Talents.List do
	Talents.ById[def.Id] = def
end

local Cfg = Talents.Config

-- XP de cuenta para pasar del nivel `level` al siguiente.
function Talents.xpNeeded(level: number): number
	return Cfg.XPBase + Cfg.XPGrowth * (level - 1)
end

-- Puntos que da un nivel de cuenta (en total, antes de gastar).
function Talents.pointsForLevel(level: number): number
	return Cfg.StartingPoints + Cfg.PointsPerLevel * (level - 1)
end

-- Puntos gastados en el árbol.
function Talents.spent(levels: { [string]: number }): number
	local total = 0
	for id, rank in levels do
		local def = Talents.ById[id]
		if def then
			total += rank * def.Points
		end
	end
	return total
end

-- Oro de los próximos `points` puntos teniendo `spent` gastados (cada punto encarece el siguiente).
function Talents.goldCost(spent: number, points: number): number
	local total = 0
	for i = 0, points - 1 do
		total += math.floor(Cfg.GoldBase * Cfg.GoldGrowth ^ (spent + i) / 10 + 0.5) * 10
	end
	return total
end

-- ¿Está conectado? (el núcleo siempre; el resto, si tenés alguno de sus Links)
function Talents.reachable(levels: { [string]: number }, def: any): boolean
	if #def.Links == 0 then
		return true
	end
	for _, id in def.Links do
		if (levels[id] or 0) > 0 then
			return true
		end
	end
	return false
end

export type Check = { ok: boolean, reason: string?, points: number, gold: number, gems: number }

-- Revisa si se puede subir un rango. La usa el servidor para validar y el cliente para mostrar.
-- wallet = { Gold = n, Gems = n }
function Talents.check(levels: { [string]: number }, accountLevel: number, wallet: { [string]: number }, id: any): Check
	local def = type(id) == "string" and Talents.ById[id]
	if not def then
		return { ok = false, reason = "Talento inválido.", points = 0, gold = 0, gems = 0 }
	end
	local rank = levels[def.Id] or 0
	local spent = Talents.spent(levels)
	local cost = {
		ok = false,
		points = def.Points,
		gold = Talents.goldCost(spent, def.Points),
		gems = def.Gems or 0,
	} :: Check
	if rank >= def.Max then
		cost.reason = def.Name .. " ya está al máximo."
	elseif not Talents.reachable(levels, def) then
		cost.reason = "Desbloqueá antes un talento conectado."
	elseif Talents.pointsForLevel(accountLevel) - spent < def.Points then
		cost.reason = "Te faltan puntos: subí de nivel jugando partidas."
	elseif (wallet.Gold or 0) < cost.gold then
		cost.reason = "Te falta oro."
	elseif (wallet.Gems or 0) < cost.gems then
		cost.reason = "Te faltan gemas."
	else
		cost.ok = true
	end
	return cost
end

-- XP de cuenta por una partida (cálculo puro).
function Talents.accountXP(info: { result: string, wavesCleared: number, bosses: number, miniBosses: number, kills: number }, mult: number?): number
	local xp = info.wavesCleared * Cfg.XPPerWave
		+ math.min(info.kills, Cfg.XPKillCap) * Cfg.XPPerKill
		+ info.miniBosses * Cfg.XPMiniBoss
		+ info.bosses * Cfg.XPBoss
		+ (if info.result == "Victory" then Cfg.XPVictory else 0)
	return math.max(0, math.floor(xp * (mult or 1)))
end

return Talents
