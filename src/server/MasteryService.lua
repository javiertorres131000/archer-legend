--!strict
-- MasteryService (ModuleScript)
-- Ubicación: ServerScriptService > Server > MasteryService
-- Maestría por arma (reglas en Shared/Mastery.lua). Guarda la XP en el perfil (Data.Mastery),
-- la publica en el atributo "Mastery" del jugador, aplica el bono y los candados al empezar la
-- partida y suma la XP al terminarla (lo llama Rewards.grant).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mastery = require(Shared:WaitForChild("Mastery"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Skills = require(Shared:WaitForChild("Skills"))
local Profiles = require(script.Parent.Profiles)

local MasteryService = {}

export type Result = {
	family: string,
	gained: number,
	xp: number,
	levelBefore: number,
	level: number,
	into: number, -- XP dentro del nivel
	needed: number, -- XP que pide el nivel (0 = máximo)
	unlocked: { string }, -- textos: "Danza de espadas", "Título: Experto", "+2% de crítico"
}

-- Familia de un arma (las especiales, la de su base)
function MasteryService.familyOf(weaponId: string?): string
	local def = Weapons.get(weaponId)
	return def.Base or def.Id
end

function MasteryService.publish(player: Player)
	local data = Profiles.get(player)
	player:SetAttribute("Mastery", Mastery.encode(if data then data.Mastery else {}))
end

-- Al empezar la partida (después de WeaponService.apply, que fija stats.weapon)
function MasteryService.apply(player: Player, stats: any)
	local data = Profiles.get(player)
	local xpByFamily = if data then data.Mastery else {}
	stats.lockedSkills = Mastery.lockedSkills(xpByFamily)
	local level = Mastery.levelOf(xpByFamily[stats.weapon] or 0)
	local damage, crit = Mastery.bonus(level)
	stats.damage *= 1 + damage
	stats.critChance += crit
	stats.masteryLevel = level
end

local function unlockTexts(family: string, from: number, to: number): { string }
	local out = {}
	for _, u in Mastery.unlocksBetween(family, from, to) do
		if u.Kind == "Skill" then
			local def = Skills.ById[u.Id]
			table.insert(out, "✔ Desbloqueaste " .. (if def then def.Name else u.Id))
		elseif u.Kind == "Title" then
			table.insert(out, "🏅 Título: " .. u.Name)
		elseif u.Kind == "Crit" then
			table.insert(out, string.format("+%d%% de crítico", math.floor(u.Amount * 100 + 0.5)))
		end
	end
	return out
end

-- Suma la XP de una partida a la familia del arma. info: { result, kills, wavesCleared, bosses }
function MasteryService.grant(player: Player, weaponId: string?, info: any): Result?
	local data = Profiles.get(player)
	if not data then
		return nil
	end
	local family = MasteryService.familyOf(weaponId)
	if not Mastery.isFamily(family) then
		return nil
	end
	local before = data.Mastery[family] or 0
	local gained = Mastery.runXP(info)
	local after = before + gained
	data.Mastery[family] = after
	local levelBefore, level = Mastery.levelOf(before), Mastery.levelOf(after)
	local into, needed = Mastery.progress(after)
	MasteryService.publish(player)
	return {
		family = family,
		gained = gained,
		xp = after,
		levelBefore = levelBefore,
		level = level,
		into = into,
		needed = needed,
		unlocked = unlockTexts(family, levelBefore, level),
	}
end

function MasteryService.init()
	Profiles.onLoaded(function(player)
		MasteryService.publish(player)
	end)
end

return MasteryService
