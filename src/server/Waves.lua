-- Waves (ModuleScript)
-- Ubicación: ServerScriptService > Server > Waves
-- Máquina de estados de la partida: Waiting -> Wave -> Break -> Wave ... y al final
-- Victory o Defeat (los decide GameServer).
-- Las oleadas se generan al azar a partir del capítulo actual (Data > Chapters).

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local EnemyTypes = require(script.Parent.Data.EnemyTypes)
local Chapters = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Chapters"))
local Enemies = require(script.Parent.Enemies)
local PlayerData = require(script.Parent.PlayerData)

local WavesCfg = Config.Waves
local Scaling = Config.Coop.Scaling

type Scale = { Health: number, Count: number, XP: number }

local Waves = {}

local gameState: Folder
local onAllCleared: (() -> ())? = nil
local getPartySize: () -> number = function()
	return 1
end
local onWaveStart: ((number, Scale) -> ())? = nil
local scale: Scale = Scaling[1] -- escalado vigente: se fija al empezar cada oleada

local chapterIndex = 1
local phase = "Waiting"
local wave = 0
local spawnQueue: { string } = {}
local spawnTimer = 0
local phaseTimer = 0
local runStart = 0

local function chapter()
	return Chapters[chapterIndex]
end

local function setPhase(newPhase: string)
	phase = newPhase
	gameState:SetAttribute("Phase", newPhase)
end

local function updateEnemiesLeft()
	gameState:SetAttribute("EnemiesLeft", #spawnQueue + Enemies.aliveCount())
end

local function bossFor(ch, n: number): string?
	if ch.Boss and ch.Boss.Wave == n then
		return ch.Boss.Type
	elseif ch.MiniBoss and ch.MiniBoss.Wave == n then
		return ch.MiniBoss.Type
	end
	return nil
end

-- Arma la lista de enemigos de la oleada n gastando su presupuesto al azar.
-- countMult agranda el presupuesto según la cantidad de jugadores (1 = solo).
-- Es una función pura (no toca el juego), así se puede probar sola.
function Waves.buildQueue(ch, n: number, countMult: number?): { string }
	local budget = (ch.Budget.Base + (n - 1) * ch.Budget.PerWave) * (countMult or 1) * WavesCfg.EnemyCountMultiplier
	if bossFor(ch, n) then
		budget *= ch.Budget.BossWaveFactor or 0.35
	end

	local pool = {}
	local queue = {}
	for _, entry in ch.Pool do
		if entry.From <= n and (not entry.To or entry.To >= n) then
			table.insert(pool, entry)
		end
		-- Debut: el enemigo nuevo aparece al menos una vez en su primera oleada
		if entry.From == n then
			table.insert(queue, entry.Type)
			budget -= EnemyTypes[entry.Type].Cost or 1
		end
	end

	while budget > 0 do
		local affordable = {}
		local total = 0
		for _, entry in pool do
			if (EnemyTypes[entry.Type].Cost or 1) <= budget then
				table.insert(affordable, entry)
				total += entry.Weight or 1
			end
		end
		if #affordable == 0 then
			break
		end
		local roll = math.random() * total
		local picked = affordable[#affordable]
		for _, entry in affordable do
			roll -= entry.Weight or 1
			if roll <= 0 then
				picked = entry
				break
			end
		end
		table.insert(queue, picked.Type)
		budget -= EnemyTypes[picked.Type].Cost or 1
	end

	-- Mezclar
	for i = #queue, 2, -1 do
		local j = math.random(i)
		queue[i], queue[j] = queue[j], queue[i]
	end
	return queue
end

local function healthMultFor(n: number): number
	return chapter().HealthMult * (1 + (n - 1) * WavesCfg.HealthGrowth) * scale.Health * Config.Frenzy.EnemyHealthMult
end

local function spawnInterval(n: number): number
	local ch = chapter()
	local t = if ch.Waves > 1 then (n - 1) / (ch.Waves - 1) else 0
	return (ch.Interval[1] + (ch.Interval[2] - ch.Interval[1]) * t) * Config.Frenzy.SpawnIntervalMult
end

-- Desde todos lados: ángulo base de la próxima aparición. A veces, la espalda del jugador;
-- si no, va girando (ángulo áureo) para que cada aparición venga de otro lado.
local sideRotation = math.random() * math.pi * 2
local function nextSpawnAngle(anchor: PlayerData.Target): number
	local cf = anchor.root.CFrame
	local look = cf and PlayerData.flat(cf.LookVector)
	if look and look.Magnitude > 0.01 and math.random() < (Config.Frenzy.BehindSpawnChance or 0) then
		return math.atan2(-look.Z, -look.X) -- detrás
	end
	sideRotation = (sideRotation + 2.39996) % (math.pi * 2)
	return sideRotation
end

-- Cuántos enemigos van a cada lado (reparto parejo; los primeros lados llevan el resto)
function Waves.splitSides(total: number, sides: number): { number }
	local n = math.max(1, math.min(sides, total))
	local list = {}
	for i = 1, n do
		list[i] = total // n + (if i <= total % n then 1 else 0)
	end
	return list
end

local function startWave(n: number, targets: { PlayerData.Target })
	wave = n
	if runStart == 0 then
		runStart = os.clock()
	end
	local ch = chapter()

	-- Dificultad según los jugadores presentes AHORA. Queda fija toda la oleada:
	-- si alguien entra o sale a mitad, recién cambia en la próxima.
	local partySize = math.clamp(getPartySize(), 1, #Scaling)
	scale = Scaling[partySize]
	gameState:SetAttribute("PartySize", partySize)
	if onWaveStart then
		onWaveStart(partySize, scale)
	end

	spawnQueue = Waves.buildQueue(ch, n, scale.Count)
	spawnTimer = 0
	gameState:SetAttribute("Wave", n)

	-- El jefe aparece antes de anunciar la oleada, así el HUD ya sabe su nombre.
	local bossType = bossFor(ch, n)
	if bossType then
		local half = Enemies.getHalf()
		local pos = Enemies.findSpawnPosition(targets) or Vector3.new(0, 0, -half.Z * 0.6)
		Enemies.spawn(bossType, pos, { healthMult = ch.HealthMult * scale.Health, dmgMult = ch.DamageMult })
	end

	setPhase("Wave")
	updateEnemiesLeft()
end

-- allCleared: se termina la última oleada (victoria).
-- partySize: cuántos jugadores hay (para el escalado).
-- waveStart: avisa el escalado elegido al empezar cada oleada.
function Waves.init(state: Folder, allCleared: () -> (), partySize: () -> number, waveStart: (number, Scale) -> ())
	gameState = state
	onAllCleared = allCleared
	getPartySize = partySize
	onWaveStart = waveStart
end

function Waves.setChapter(index: number)
	chapterIndex = math.clamp(index, 1, #Chapters)
	local ch = chapter()
	gameState:SetAttribute("Chapter", chapterIndex)
	gameState:SetAttribute("ChapterName", ch.Name)
	gameState:SetAttribute("TotalChapters", #Chapters)
	gameState:SetAttribute("TotalWaves", ch.Waves)
end

function Waves.chapterCount(): number
	return #Chapters
end

function Waves.chapterInfo(index: number)
	return Chapters[index]
end

-- Índice del capítulo con ese Id (o nil si no existe).
function Waves.chapterIndexById(id: string): number?
	for i, ch in Chapters do
		if ch.Id == id then
			return i
		end
	end
	return nil
end

function Waves.phase(): string
	return phase
end

function Waves.current(): number
	return wave
end

-- Segundos desde que arrancó la partida.
function Waves.pauseTime(dt: number)
	if wave > 0 then runStart += dt end
end

function Waves.elapsed(): number
	return if wave > 0 then os.clock() - runStart else 0
end

-- Termina la partida ("Victory" o "Defeat"). Desde acá no avanza más hasta Waves.reset().
function Waves.finish(result: string)
	table.clear(spawnQueue)
	setPhase(result)
	updateEnemiesLeft()
end

-- Arranca la oleada siguiente (la llama Run cuando el equipo cruzó la puerta).
function Waves.nextWave(targets: { PlayerData.Target })
	if phase == "Break" then
		startWave(wave + 1, targets)
	end
end

-- Panel de prueba: termina la oleada actual (sin enemigos por salir ni vivos).
function Waves.debugSkip()
	if phase ~= "Wave" then
		return
	end
	table.clear(spawnQueue)
	Enemies.clear()
	updateEnemiesLeft()
end

function Waves.reset()
	wave = 0
	runStart = 0
	table.clear(spawnQueue)
	gameState:SetAttribute("Wave", 0)
	setPhase("Waiting")
	updateEnemiesLeft()
end

function Waves.update(dt: number, targets: { PlayerData.Target }, frozen: boolean)
	if frozen or #targets == 0 then
		return
	end
	local ch = chapter()

	if phase == "Waiting" then
		startWave(math.clamp(Config.Debug.StartWave, 1, ch.Waves), targets)
	elseif phase == "Wave" then
		spawnTimer += dt
		if #spawnQueue > 0 and spawnTimer >= spawnInterval(wave) and Enemies.aliveCount() < Config.Enemy.MaxAlive then
			spawnTimer = 0
			-- Desde todos lados: el grupo se reparte en varios lados alrededor de un jugador
			local total = math.min(Config.Frenzy.SpawnGroup, #spawnQueue, Config.Enemy.MaxAlive - Enemies.aliveCount())
			local split = Waves.splitSides(total, Config.Frenzy.SpawnSides or 1)
			local anchor = targets[math.random(1, #targets)]
			local base = nextSpawnAngle(anchor)
			for side, count in split do
				local pos = Enemies.findSpawnPositionAt(targets, anchor, base + (side - 1) * math.pi * 2 / #split)
				if pos then
					for i = 1, count do
						local angle = i * 2.4
						local offset = if i == 1 then Vector3.zero else Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4
						Enemies.spawn(table.remove(spawnQueue) :: string, pos + offset, {
							healthMult = healthMultFor(wave),
							dmgMult = ch.DamageMult * Config.Frenzy.EnemyDamageMult,
							golden = math.random() < Config.Frenzy.GoldenChance,
						})
					end
				end
			end
		end
		updateEnemiesLeft()

		if #spawnQueue == 0 and Enemies.aliveCount() == 0 then
			if wave >= ch.Waves then
				if onAllCleared then
					onAllCleared()
				end
			else
				phaseTimer = WavesCfg.BreakTime
				setPhase("Break")
			end
		end
	elseif phase == "Break" then
		-- Con puertas, la oleada siguiente la arranca Run cuando el equipo pasa (Waves.nextWave)
		if not WavesCfg.UseDoors then
			phaseTimer -= dt
			if phaseTimer <= 0 then
				startWave(wave + 1, targets)
			end
		end
	end
end

return Waves
