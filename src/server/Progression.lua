-- Progression (ModuleScript)
-- Ubicación: ServerScriptService > Server > Progression
-- XP compartida por todo el equipo, niveles y ofertas de "elegí 1 de 3 habilidades".
-- Carta dorada (Config.Progression.GoldenCardChance): la decide el servidor al armar la oferta;
-- si la elegís, la habilidad se aplica 2 veces. Viaja como 6º dato de Remotes.SkillOffer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Skills = require(Shared:WaitForChild("Skills"))
local Synergies = require(Shared:WaitForChild("Synergies"))
local PlayerData = require(script.Parent.PlayerData)

local ProgCfg = Config.Progression

local Progression = {}

local remotes
local gameState: Folder
local level = 1
local xp = 0
local xpScale = 1 -- con más jugadores hay más enemigos: se pide más XP por nivel

local function xpNeeded(lvl: number): number
	local early = ProgCfg.EarlyLevelMult and ProgCfg.EarlyLevelMult[lvl] or 1 -- arranque rápido
	return math.max(1, math.floor((ProgCfg.BaseXP + (lvl - 1) * ProgCfg.XPGrowth) * early * xpScale + 0.5))
end

local function publish()
	gameState:SetAttribute("Level", level)
	-- El HUD avisa una vez cuando se abre la segunda tanda de habilidades
	gameState:SetAttribute("SecondTier", level >= (ProgCfg.SecondTierLevel or 6))
	gameState:SetAttribute("XP", xp)
	gameState:SetAttribute("XPNeeded", xpNeeded(level))
end

-- Peso de una habilidad en el sorteo: rareza, y más si es del mazo del arma.
local function weightOf(def: any): number
	local w = ProgCfg.RarityWeights[def.Rarity] or 5
	return if def.Weapon then w * (ProgCfg.WeaponDeckWeight or 1) else w
end

-- Elige hasta N habilidades distintas, ponderadas por rareza, que no estén al máximo:
-- comunes + las del mazo del arma; las legendarias, solo con Requires habilidades del mazo.
local function rollChoices(stats: PlayerData.Stats): { string }
	local stacks = stats.stacks
	local deck = Skills.deckCount(stacks, stats.weapon)
	local pool = {}
	for _, def in Skills.List do
		local tierOk = (def.Tier or 1) < 2 or level >= (ProgCfg.SecondTierLevel or 6) -- segunda tanda
		local unlocked = not (stats.lockedSkills and stats.lockedSkills[def.Id]) -- candado de maestría
		if (stacks[def.Id] or 0) < def.Max and Skills.forWeapon(def, stats.weapon) and deck >= (def.Requires or 0) and tierOk and unlocked then
			table.insert(pool, def)
		end
	end

	local choices = {}
	while #choices < ProgCfg.ChoicesPerLevel and #pool > 0 do
		local total = 0
		for _, def in pool do
			total += weightOf(def)
		end
		local roll = math.random() * total
		for i, def in pool do
			roll -= weightOf(def)
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

-- ¿Alguna carta sale dorada? Solo habilidades que todavía pueden subir 2 niveles (no la curación).
-- Devuelve el índice de la carta dorada, o 0.
local function rollGolden(stats: PlayerData.Stats, choices: { string }): number
	if math.random() >= (ProgCfg.GoldenCardChance or 0) then
		return 0
	end
	local candidates = {}
	for i, id in choices do
		local def = Skills.ById[id]
		if def and id ~= Skills.Heal.Id and def.Max - (stats.stacks[id] or 0) >= 2 then
			table.insert(candidates, i)
		end
	end
	return if #candidates > 0 then candidates[math.random(#candidates)] else 0
end

local function openNextOffer(player: Player)
	local state = PlayerData.get(player)
	if not state or state.currentOffer or state.pendingOffers <= 0 then
		return
	end
	state.pendingOffers -= 1
	state.offerId += 1
	state.currentOffer = rollChoices(state.stats)
	state.offerGolden = rollGolden(state.stats, state.currentOffer :: { string })
	state.offerDeadline = os.clock() + ProgCfg.ChoiceTimeout
	PlayerData.setChoosingShield(player, true)
	Progression.syncPause()
	remotes.SkillOffer:FireClient(player, state.offerId, state.currentOffer, ProgCfg.ChoiceTimeout, state.stats.rerolls, state.offerGolden)
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
	-- Sinergias: el par completo da su bono una vez por partida
	for _, syn in Synergies.completedBy(skillId, state.stats.stacks, state.stats.synergies) do
		state.stats.synergies[syn.Name] = true
		syn.Apply(state.stats)
	end

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
	local golden = state.offerGolden == index
	state.currentOffer = nil
	state.offerGolden = 0
	PlayerData.setChoosingShield(player, false)
	if skillId then
		grant(player, skillId)
		-- Carta dorada: un nivel más (si todavía entra)
		local def = Skills.ById[skillId]
		if golden and def and (state.stats.stacks[skillId] or 0) < def.Max then
			grant(player, skillId)
		end
	end
	openNextOffer(player) -- si subió varios niveles juntos, sigue la próxima
	Progression.syncPause()
end

function Progression.init(r, state: Folder)
	remotes = r
	gameState = state
	publish()

	-- El cliente manda (offerId, índice). Nunca confiamos en lo que manda: validamos todo.
	remotes.ChooseSkill.OnServerEvent:Connect(function(player: Player, offerId: any, index: any)
		local s = PlayerData.get(player)
		if not s or not s.inMatch or not s.currentOffer or s.life ~= "ALIVE" then
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

	-- Talento Otra mano: cambia las 3 cartas por otras (gasta un cambio de esta partida)
	remotes.RerollSkills.OnServerEvent:Connect(function(player: Player, offerId: any)
		local s = PlayerData.get(player)
		if not s or not s.inMatch or not s.currentOffer or s.life ~= "ALIVE" then
			return
		end
		if typeof(offerId) ~= "number" or offerId ~= s.offerId or s.stats.rerolls <= 0 then
			return
		end
		s.stats.rerolls -= 1
		s.offerId += 1
		s.currentOffer = rollChoices(s.stats)
		s.offerGolden = rollGolden(s.stats, s.currentOffer :: { string })
		s.offerDeadline = os.clock() + ProgCfg.ChoiceTimeout
		remotes.SkillOffer:FireClient(player, s.offerId, s.currentOffer, ProgCfg.ChoiceTimeout, s.stats.rerolls, s.offerGolden)
	end)
end

-- Para las pruebas: sortea cartas para estas stats y XP que pide cada nivel
Progression.rollChoices = rollChoices
Progression.xpNeeded = xpNeeded
Progression.rollGolden = rollGolden

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
-- Una habilidad gratis para este jugador (cofres). Se suma a las que tenga pendientes.
function Progression.giveChoice(player: Player)
	local state = PlayerData.get(player)
	if not state or not state.inMatch then
		return
	end
	state.pendingOffers += 1
	openNextOffer(player)
end

function Progression.update(now: number)
	for player, state in PlayerData.all() do
		if state.currentOffer and now >= state.offerDeadline then
			resolveOffer(player, math.random(#state.currentOffer))
		end
	end
end

-- Pausa global mientras cualquier jugador vivo tiene una oferta abierta.
function Progression.allChoosing(targets: { PlayerData.Target }): boolean
	if not ProgCfg.PauseWhileChoosing then return false end
	for _, target in targets do
		if target.state.currentOffer then return true end
	end
	return false
end
function Progression.syncPause(): boolean
	local choosing = Progression.allChoosing(PlayerData.getAliveTargets())
	local paused = choosing or PlayerData.inCinematic() -- la entrada de un jefe también congela
	PlayerData.setPaused(paused)
	gameState:SetAttribute("ChoosingPaused", choosing)
	return paused
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
	PlayerData.setPaused(false)
	gameState:SetAttribute("ChoosingPaused", false)
	level = 1
	xp = 0
	xpScale = 1
	publish()
end

return Progression
