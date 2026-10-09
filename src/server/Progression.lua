-- Progression (ModuleScript)
-- Ubicación: ServerScriptService > Server > Progression
-- XP compartida por todo el equipo, niveles y ofertas de "elegí 1 de 3 habilidades".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Skills = require(Shared:WaitForChild("Skills"))
local PlayerData = require(script.Parent.PlayerData)

local ProgCfg = Config.Progression

local Progression = {}

local remotes
local gameState: Folder
local level = 1
local xp = 0
local xpScale = 1 -- con más jugadores hay más enemigos: se pide más XP por nivel

local function xpNeeded(lvl: number): number
	return math.max(1, math.floor((ProgCfg.BaseXP + (lvl - 1) * ProgCfg.XPGrowth) * xpScale + 0.5))
end

local function publish()
	gameState:SetAttribute("Level", level)
	gameState:SetAttribute("XP", xp)
	gameState:SetAttribute("XPNeeded", xpNeeded(level))
end

-- Elige hasta N habilidades distintas, ponderadas por rareza, que no estén al máximo.
local function rollChoices(stacks: { [string]: number }): { string }
	local pool = {}
	for _, def in Skills.List do
		if (stacks[def.Id] or 0) < def.Max then
			table.insert(pool, def)
		end
	end

	local choices = {}
	while #choices < ProgCfg.ChoicesPerLevel and #pool > 0 do
		local total = 0
		for _, def in pool do
			total += ProgCfg.RarityWeights[def.Rarity]
		end
		local roll = math.random() * total
		for i, def in pool do
			roll -= ProgCfg.RarityWeights[def.Rarity]
			if roll <= 0 then
				table.insert(choices, def.Id)
				table.remove(pool, i)
				break
			end
		end
	end

	if #choices < ProgCfg.ChoicesPerLevel then
		table.insert(choices, Skills.Heal.Id)
	end
	return choices
end

local function openNextOffer(player: Player)
	local state = PlayerData.get(player)
	if not state or state.currentOffer or state.pendingOffers <= 0 then
		return
	end
	state.pendingOffers -= 1
	state.offerId += 1
	state.currentOffer = rollChoices(state.stats.stacks)
	state.offerDeadline = os.clock() + ProgCfg.ChoiceTimeout
	PlayerData.setChoosingShield(player, true)
	remotes.SkillOffer:FireClient(player, state.offerId, state.currentOffer, ProgCfg.ChoiceTimeout)
end

local function grant(player: Player, skillId: string)
	local state = PlayerData.get(player)
	local def = Skills.ById[skillId]
	if not state or not def then
		return
	end
	local stacks = (state.stats.stacks[skillId] or 0) + 1
	state.stats.stacks[skillId] = stacks
	def.Apply(state.stats)

	local heal = def.Heal or 0
	if def.HealFraction then
		heal += state.stats.maxHealth * def.HealFraction
	end
	PlayerData.applyToCharacter(player, heal)
	remotes.SkillGranted:FireClient(player, skillId, stacks)
end

local function resolveOffer(player: Player, index: number)
	local state = PlayerData.get(player)
	if not state or not state.currentOffer then
		return
	end
	local skillId = state.currentOffer[index]
	state.currentOffer = nil
	PlayerData.setChoosingShield(player, false)
	if skillId then
		grant(player, skillId)
	end
	openNextOffer(player) -- si subió varios niveles juntos, sigue la próxima
end

function Progression.init(r, state: Folder)
	remotes = r
	gameState = state
	publish()

	-- El cliente manda (offerId, índice). Nunca confiamos en lo que manda: validamos todo.
	remotes.ChooseSkill.OnServerEvent:Connect(function(player: Player, offerId: any, index: any)
		local s = PlayerData.get(player)
		if not s or not s.currentOffer then
			return
		end
		if typeof(offerId) ~= "number" or offerId ~= s.offerId then
			return
		end
		if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #s.currentOffer then
			return
		end
		resolveOffer(player, index)
	end)
end

function Progression.addXP(amount: number)
	xp += amount
	while xp >= xpNeeded(level) do
		xp -= xpNeeded(level)
		level += 1
		-- Solo los participantes de la partida eligen (los del lobby no juegan esta)
		for player, state in PlayerData.all() do
			if state.inMatch then
				state.pendingOffers += 1
				openNextOffer(player)
			end
		end
	end
	publish()
end

-- Cierra ofertas vencidas eligiendo una al azar.
function Progression.update(now: number)
	for player, state in PlayerData.all() do
		if state.currentOffer and now >= state.offerDeadline then
			resolveOffer(player, math.random(#state.currentOffer))
		end
	end
end

-- true si hay jugadores vivos y TODOS están eligiendo: el juego se pausa.
-- Jugando solo, esto equivale a la pausa de Archero.
function Progression.allChoosing(targets: { PlayerData.Target }): boolean
	if #targets == 0 then
		return false
	end
	for _, t in targets do
		if not t.state.currentOffer then
			return false
		end
	end
	return true
end

-- Lo fija Waves al empezar cada oleada según la cantidad de jugadores.
function Progression.setXPScale(scale: number)
	xpScale = scale
	publish()
end

function Progression.level(): number
	return level
end

function Progression.reset()
	level = 1
	xp = 0
	xpScale = 1
	publish()
end

return Progression
