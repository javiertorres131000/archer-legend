-- Run (ModuleScript)
-- Ubicación: ServerScriptService > Server > Run
-- Una partida (corrida) en la arena: la prepara, la hace avanzar frame a frame y la limpia.
-- Reutiliza el motor de combate tal como estaba (Waves, Enemies, Combat, Hazards, Boss,
-- Progression, PlayerLife). Quién juega y cuándo empieza lo decide MatchManager.

local Remotes = require(script.Parent.Remotes)
local Arena = require(script.Parent.Arena)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local Enemies = require(script.Parent.Enemies)
local Combat = require(script.Parent.Combat)
local Hazards = require(script.Parent.Hazards)
local Boss = require(script.Parent.Boss)
local Progression = require(script.Parent.Progression)
local Waves = require(script.Parent.Waves)
local Loot = require(script.Parent.Loot)
local CombatFeed = require(script.Parent.CombatFeed)
local Orbs = require(script.Parent.Orbs)
local Ground = require(script.Parent.Ground)
local Chests = require(script.Parent.Chests)
local ItemService = require(script.Parent.ItemService)
local Equipment = require(script.Parent.Equipment)
local TalentService = require(script.Parent.TalentService)
local Runes = require(script.Parent.Runes)
local Dash = require(script.Parent.Dash)
local Rarities = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rarities"))

export type Result = "Victory" | "Defeat" | "Abandoned"

export type PlayerSummary = { name: string, kills: number, damage: number, revives: number, downs: number }

export type Summary = {
	result: string,
	chapter: number,
	chapterName: string,
	nextText: string,
	wave: number,
	wavesCleared: number,
	totalWaves: number,
	bossesKilled: { string }, -- tipos de jefe vencidos (para las recompensas)
	level: number,
	time: number,
	partySize: number,
	players: { PlayerSummary },
}

local Run = {}

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local RoomCfg = Config.Rooms

local chapterIndex = 1
local result: Result? = nil
local lastPhase = "Waiting"
local active = false
local bossesKilled: { string } = {}

-- Salas y puerta (entre oleadas, con Config.Waves.UseDoors)
local roomIndex = 1
local doorOpenedAt = 0
local performanceTimer = 0
local enteringUntil: number? = nil -- mientras llega a la sala nueva, la oleada todavía no arranca

-- Arma el motor de combate (una sola vez, al arrancar el servidor).
function Run.init()
	ItemService.init(Remotes)
	Dash.init(Remotes)
	Equipment.init(Remotes)
	TalentService.init(Remotes)
	Runes.init(Remotes)
	Arena.build()
	Hazards.init()
	Combat.init(Remotes, Arena.Half)
	Enemies.init(Arena.Half, Combat, Hazards)
	Boss.init(Remotes.GameState)
	Progression.init(Remotes, Remotes.GameState)
	CombatFeed.init(Remotes.CombatText)
	Orbs.init(Remotes.Orbs, Progression.addXP)
	-- Cofre abierto: botín para todos y, si está activado, una habilidad gratis para cada uno
	Chests.init(Remotes.ChestOpened, Arena.Half, function(pos, _opener, rarity)
		local participants = PlayerLife.participants()
		local ch = Waves.chapterInfo(chapterIndex)
		local mult = ch.Rewards and ch.Rewards.LootMult or 1
		local amounts = { Gold = math.floor(Config.Frenzy.ChestGold * mult * (0.8 + math.random() * 0.4) + 0.5) }
		if math.random() < Config.Frenzy.ChestGemChance then
			amounts.Gems = math.random(1, 3)
		end
		for player, got in Loot.grant(participants, amounts) do
			CombatFeed.loot(player, pos, got)
		end
		for _, p in participants do
			ItemService.roll(p, rarity)
			Equipment.drop(p, false)
		end
		if Config.Frenzy.ChestGivesSkill then
			for _, p in participants do
				Progression.giveChoice(p)
			end
		end
	end)

	-- Cada golpe suma a las estadísticas del jugador; cada muerte, XP y botín al equipo.
	Enemies.onDamaged(function(enemy, attacker, dealt, killed, kind)
		local pos = enemy.part.Position
		local state = attacker and PlayerData.get(attacker)
		if state then
			state.damageDealt += dealt
			if killed then
				state.kills += 1
			end
		end
		if attacker and active then
			local feedKind = if kind == "burn" or kind == "crit" or kind == "poison" then kind else "hit"
			CombatFeed.dealt(attacker, enemy, pos, dealt, feedKind :: any, enemy.part)
			if Config.CombatText.ShowTeammateDamage then
				for _, p in PlayerLife.participants() do
					if p ~= attacker then
						CombatFeed.dealt(p, enemy, pos, dealt, "ally")
					end
				end
			end
		end
		if killed then
			if active then ItemService.onKill(enemy, attacker, kind) end
			if not active then
				Progression.addXP(enemy.xp)
			else
				local participants = PlayerLife.participants()
				-- La XP cae como orbe (el dorado da mucha más)
				Orbs.drop(Ground.place(pos), enemy.xp * (if enemy.golden then 5 else 1))
				Chests.onKill()
				CombatFeed.kill(participants, pos, enemy.color, enemy.radius * 2, enemy.golden)
				if enemy.isBoss then
					table.insert(bossesKilled, enemy.typeId)
					Runes.onBossKilled(participants)
				end
				-- Botín (los invocados por un jefe no dan)
				if not enemy.summoner then
					local ch = Waves.chapterInfo(chapterIndex)
					local mult = ch.Rewards and ch.Rewards.LootMult or 1
					if enemy.golden then
						mult *= Config.Frenzy.GoldenLootMult
					end
					local amounts = Loot.roll(enemy.def.Cost or 1, enemy.isBoss, mult)
					if enemy.isBoss or enemy.golden then
						for _, p in participants do
							ItemService.roll(p, if enemy.isBoss then "Epic" else Rarities.roll())
							Equipment.drop(p, enemy.isBoss)
						end
					end
					if enemy.golden then
						amounts.Gems = (amounts.Gems or 0) + 2
					end
					for player, got in Loot.grant(participants, amounts) do
						CombatFeed.loot(player, pos, got)
					end
				end
			end
		end
	end)

	Waves.init(Remotes.GameState, function()
		result = "Victory"
	end, PlayerLife.partySize, function(_partySize, scale)
		Progression.setXPScale(scale.XP)
	end)
	Waves.setChapter(1)
end

-- Deja la arena vacía y todo en cero (sirve antes de empezar y al terminar).
local function clearWorld()
	ItemService.reset()
	Enemies.clear()
	Hazards.clear()
	Combat.clear()
	Boss.update()
	Waves.reset()
	Progression.reset()
	PlayerData.resetStats()
end

-- Empieza una partida en el capítulo `index` con estos participantes.
function Run.start(index: number, participants: { Player })
	clearWorld()
	chapterIndex = index
	result = nil
	lastPhase = "Waiting"
	active = true
	table.clear(bossesKilled)
	Waves.setChapter(chapterIndex)
	local ch = Waves.chapterInfo(chapterIndex)
	roomIndex = 1
	enteringUntil = nil
	Arena.closeDoor()
	Arena.buildRoom(ch, roomIndex)
	Remotes.GameState:SetAttribute("RoomIndex", roomIndex)
	-- Cada uno en su punto de la entrada, con vida, XP y habilidades de partida en cero
	for _, p in participants do
		local s = PlayerData.get(p)
		if s then
			Equipment.apply(p, s.stats)
			TalentService.apply(p, s.stats)
			Runes.apply(p, s.stats)
		end
		p:SetAttribute("DashReadyAt", 0)
	end
	PlayerLife.beginMatch(participants, Arena.spawnPoints(#participants))
	Loot.resetRun(participants)
	-- Talento Ventaja: habilidades para elegir apenas empieza
	for _, p in participants do
		local s = PlayerData.get(p)
		for _ = 1, if s then s.stats.startChoices else 0 do
			Progression.giveChoice(p)
		end
	end
end

function Run.isActive(): boolean
	return active
end

function Run.chapterIndex(): number
	return chapterIndex
end

-- Un frame de partida. Devuelve el resultado cuando termina (y nil mientras sigue).
function Run.step(dt: number): Result?
	if not active then
		return nil
	end
	if #PlayerLife.participants() == 0 then
		return "Abandoned" -- se fueron todos los participantes
	end
	if result then
		return result
	end

	local now = os.clock()
	local targets = PlayerData.getAliveTargets()
	Progression.update(now)
	local frozen = Progression.syncPause()
	if frozen then
		-- Relojes absolutos de combate también se suspenden.
		for _, enemy in Enemies.list do
			if enemy.burnDps > 0 then enemy.burnUntil += dt end
			if enemy.poisonFraction > 0 then enemy.poisonUntil += dt end
			enemy.lastContact += dt
		end
		for _, state in PlayerData.all() do
			if state.inMatch then
				state.lastShot += dt
				state.lastHurt += dt
				state.nextStorm += dt
				state.nextLightning += dt
				state.nextMeteor += dt
				state.dashReady += dt
			end
		end
		PlayerLife.pauseTime(dt)
		Waves.pauseTime(dt)
		CombatFeed.update(now)
		Orbs.flush(now)
		return result
	end
	local phase = Waves.phase()

	-- Derrota: nadie queda en pie (los derribados no pueden rescatarse entre sí).
	if phase == "Wave" and PlayerLife.noneActive() then
		result = "Defeat"
		return result
	end

	-- Al empezar el descanso: se juntan los orbes y se abren los cofres que quedan, se levantan
	-- los derribados, vuelven los eliminados y se abre la puerta.
	if phase == "Break" and lastPhase ~= "Break" then
		Orbs.collectAll(targets)
		Chests.openAll()
		-- Los que vuelven aparecen al lado de un compañero (el mapa es grande), o en el centro
		local near = targets[1]
		local back = if near
			then CFrame.new(Ground.place(near.root.Position + Vector3.new(4, 0, 0), 3))
			else Arena.spawnPoints(1)[1]
		PlayerLife.onBreak(back)
		if Config.Waves.UseDoors then
			Arena.openDoor()
			doorOpenedAt = now
			Remotes.GameState:SetAttribute("DoorEnd", workspace:GetServerTimeNow() + RoomCfg.DoorTimeout)
		end
	end
	lastPhase = phase
	if phase == "Break" and Config.Waves.UseDoors then
		Run.updateDoor(now, targets)
	end

	if not frozen then
		Dash.update(targets, now)
		ItemService.update(dt, targets, now)
		PlayerLife.update(dt)
	end
	Waves.update(dt, targets, frozen)
	Enemies.update(dt, targets, now, frozen)
	Combat.update(dt, targets, now, frozen)
	if not frozen then
		Hazards.update(dt, targets)
	end
	if not frozen then
		Orbs.update(targets)
		Chests.update(targets, phase == "Wave")
	end
	Boss.update()
	CombatFeed.update(now)
	Orbs.flush(now)
	if Config.Debug.ShowPerformance then
		performanceTimer += dt
		if performanceTimer >= 0.5 then
			performanceTimer = 0
			Remotes.GameState:SetAttribute("AliveEnemies", Enemies.aliveCount())
			Remotes.GameState:SetAttribute("ActiveProjectiles", Combat.count())
		end
	end
	return result
end

-- Durante los resultados: el combate está detenido, solo terminan los proyectiles en vuelo.
function Run.frozenStep(dt: number)
	Combat.update(dt, PlayerData.getAliveTargets(), os.clock(), true)
	CombatFeed.update(os.clock())
end

-- Fija el resultado y detiene las oleadas.
function Run.finish(final: Result)
	result = final
	if final ~= "Abandoned" then
		Waves.finish(final)
	end
end

-- Oleadas superadas: la actual cuenta si ya se terminó (descanso o victoria).
function Run.wavesCleared(final: Result): number
	local wave = Waves.current()
	if final == "Victory" then
		return Waves.chapterInfo(chapterIndex).Waves
	elseif Waves.phase() == "Break" then
		return wave
	end
	return math.max(0, wave - 1)
end

function Run.summary(final: Result): Summary
	local players = {}
	for _, player in PlayerLife.participants() do
		local state = PlayerData.get(player)
		if state then
			table.insert(players, {
				name = player.DisplayName,
				kills = state.kills,
				damage = math.floor(state.damageDealt),
				revives = state.revives,
				downs = state.downs,
			})
		end
	end
	table.sort(players, function(a, b)
		return a.damage > b.damage
	end)

	local ch = Waves.chapterInfo(chapterIndex)
	local nextText
	if final == "Victory" then
		local nextInfo = Waves.chapterInfo(chapterIndex + 1)
		nextText = if nextInfo
			then string.format("¡Desbloqueaste el Capítulo %d · %s!", chapterIndex + 1, nextInfo.Name)
			else "¡Completaste todos los capítulos!"
	else
		nextText = "Preparate y volvé a intentarlo desde el lobby"
	end

	return {
		result = final,
		chapter = chapterIndex,
		chapterName = ch.Name,
		nextText = nextText,
		wave = Waves.current(),
		wavesCleared = Run.wavesCleared(final),
		totalWaves = ch.Waves,
		bossesKilled = table.clone(bossesKilled),
		level = Progression.level(),
		time = math.floor(Waves.elapsed()),
		partySize = PlayerLife.partySize(),
		players = players,
	}
end

-- Termina todo: arena limpia y participantes de vuelta al lobby.
-- Puerta abierta: espera a que entren todos los que están en pie (o a que se acabe el tiempo)
-- y después lleva al equipo a la sala siguiente.
function Run.updateDoor(now: number, targets)
	if enteringUntil then
		if now >= enteringUntil then
			enteringUntil = nil
			Waves.nextWave(targets)
		end
		return
	end
	local inside = 0
	for _, t in targets do
		if Arena.inDoorZone(t.root.Position) then
			inside += 1
		end
	end
	Remotes.GameState:SetAttribute("DoorInside", inside)
	Remotes.GameState:SetAttribute("DoorNeeded", #targets)
	local everyone = #targets > 0 and inside == #targets
	if everyone or now - doorOpenedAt >= RoomCfg.DoorTimeout then
		-- A la sala siguiente: nueva decoración y todos en la entrada
		Arena.closeDoor()
		Combat.clear()
		Hazards.clear()
		roomIndex += 1
		Arena.buildRoom(Waves.chapterInfo(chapterIndex), roomIndex)
		Remotes.GameState:SetAttribute("RoomIndex", roomIndex)
		Remotes.GameState:SetAttribute("DoorEnd", 0)
		local points = Arena.spawnPoints(#targets)
		for i, t in targets do
			local character = t.player.Character
			if character then
				character:PivotTo(points[i])
			end
		end
		enteringUntil = now + RoomCfg.EnterDelay
	end
end

function Run.roomIndex(): number
	return roomIndex
end

function Run.cleanup()
	active = false
	result = nil
	enteringUntil = nil
	Arena.closeDoor()
	Remotes.GameState:SetAttribute("DoorEnd", 0)
	CombatFeed.clear()
	Orbs.clear()
	Chests.clear()
	clearWorld()
	PlayerLife.endMatch()
	Remotes.RunReset:FireAllClients()
end

return Run
