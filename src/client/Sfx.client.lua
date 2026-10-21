-- Sfx (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Sfx
-- Sonidos del combate. Qué suena con qué está en Shared/Sounds.lua (ahí se cambian los sonidos).
-- Escucha los mismos eventos que los efectos visuales. Cada sonido tiene un mínimo de tiempo
-- entre reproducciones, así 100 enemigos muriendo no se vuelven un ruido continuo.
-- El oro suena cada vez más agudo si lo juntás seguido (racha), y los orbes de XP suben en
-- escalera (Config.Effects.OrbLadderNotes / OrbLadderWindow).
-- Racha de muertes: con cada muerte del combo (atributo local "Combo" que publica Juice) suena
-- una nota más aguda de una escala pentatónica; en los hitos (10, 25, 50...), un arpegio.
-- Legendaria: redoble que se acelera hasta el momento de la revelación (atributo
-- "LegendaryReveal" que pone el Hud) y acorde final. Carta dorada ("GoldenCardAt") y
-- sinergias ("Synergy"): arpegios propios.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local Config = require(Shared:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatText = remotes:WaitForChild("CombatText") :: RemoteEvent
local projectileFired = remotes:WaitForChild("ProjectileFired") :: RemoteEvent
local chestOpened = remotes:WaitForChild("ChestOpened") :: RemoteEvent
local gameState = ReplicatedStorage:WaitForChild("GameState")

local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService

-- Un pequeño grupo de Sound por cada sonido, para que puedan superponerse
local POOL = 4
local pools: { [string]: { Sound } } = {}
local nextIndex: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}

for name, def in Sounds.List do
	local list = {}
	for i = 1, POOL do
		local s = Instance.new("Sound")
		s.Name = name .. i
		s.SoundId = def.Id
		s.Volume = def.Volume * Sounds.MasterVolume
		s.Parent = folder
		list[i] = s
	end
	pools[name] = list
	nextIndex[name] = 1
end

local function play(name: string, pitchMult: number?)
	local def = Sounds.List[name]
	local list = pools[name]
	if not def or not list or player:GetAttribute("InMatch") ~= true then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < def.MinGap then
		return
	end
	lastPlayed[name] = now
	local i = nextIndex[name]
	nextIndex[name] = i % #list + 1
	local s = list[i]
	s.PlaybackSpeed = def.Pitch * (pitchMult or 1) * (1 + (math.random() * 2 - 1) * def.PitchVariation)
	s.TimePosition = 0
	s:Play()
end

-- Arpegio (subir de nivel, cofres, dorados): varias notas seguidas, cada vez más agudas
local function arpeggio(notes: { number })
	for i, pitch in notes do
		task.delay((i - 1) * 0.07, function()
			lastPlayed.Chime = -math.huge
			play("Chime", pitch)
		end)
	end
end

-- Racha de monedas: cuanto más seguido, más agudo
local coinStreak = 0
local lastCoin = 0

-- Escala pentatónica mayor (siempre suena bien, suba lo que suba): racha de muertes y orbes
local PENTATONIC = { 0, 2, 4, 7, 9 }
local function streakPitch(step: number): number
	local semitones = 12 * (step // 5) + PENTATONIC[step % 5 + 1]
	return 2 ^ (semitones / 12)
end

-- Orbes de XP en escalera
local orbStep = -1
local lastOrb = 0

combatText.OnClientEvent:Connect(function(events)
	if typeof(events) ~= "table" then
		return
	end
	for _, e in events do
		local kind = e.k
		if kind == "hit" then
			play("Hit")
		elseif kind == "crit" then
			play("Crit")
		elseif kind == "kill" then
			if e.x == true then
				arpeggio({ 1, 1.26, 1.5, 2, 2.5 })
			else
				play("Kill")
			end
		elseif kind == "loot" then
			local now = os.clock()
			coinStreak = if now - lastCoin < 0.6 then math.min(coinStreak + 1, 12) else 0
			lastCoin = now
			play("Coin", 1 + coinStreak * 0.08)
		elseif kind == "xp" then
			local now = os.clock()
			local fx = Config.Effects
			orbStep = if now - lastOrb < (fx.OrbLadderWindow or 0.8) then math.min(orbStep + 1, fx.OrbLadderNotes or 7) else 0
			lastOrb = now
			play("XP", streakPitch(orbStep))
		elseif kind == "hurt" then
			play("Hurt")
		end
	end
end)

projectileFired.OnClientEvent:Connect(function(_id, _origin, _dir, _speed, _lifetime, ownerUserId)
	if ownerUserId == player.UserId then
		play("Shoot")
	end
end)

chestOpened.OnClientEvent:Connect(function()
	play("Chest")
	arpeggio({ 1, 1.26, 1.5, 1.26, 2 })
end)

local lastLevel = gameState:GetAttribute("Level") or 1
gameState:GetAttributeChangedSignal("Level"):Connect(function()
	local level = gameState:GetAttribute("Level") or 1
	if level > lastLevel then
		arpeggio({ 1, 1.26, 1.5, 2 })
	end
	lastLevel = level
end)

local COMBO_MILESTONES = { [10] = true, [25] = true, [50] = true, [100] = true, [200] = true, [400] = true }
local lastCombo = 0
player:GetAttributeChangedSignal("Combo"):Connect(function()
	local n = player:GetAttribute("Combo") or 0
	if n > lastCombo or (n == 1 and lastCombo ~= 1) then
		local steps = math.max(1, Config.Effects.StreakNotes or 10)
		play("Streak", streakPitch(math.min(n - 1, steps)))
		if COMBO_MILESTONES[n] then
			arpeggio({ 1, 1.26, 1.5, 2, 2.52 })
		end
	end
	lastCombo = n
end)

-- Redoble de la legendaria: golpes cada vez más seguidos hasta la revelación, después el acorde
player:GetAttributeChangedSignal("LegendaryReveal"):Connect(function()
	local revealAt = player:GetAttribute("LegendaryReveal")
	if typeof(revealAt) ~= "number" then
		return
	end
	local total = revealAt - workspace:GetServerTimeNow()
	if total <= 0 or total > 5 then
		return
	end
	local t, gap, i = 0, 0.22, 0
	while t < total - 0.05 do
		local at, pitch = t, 1 + i * 0.04
		task.delay(at, function()
			lastPlayed.Drum = -math.huge
			play("Drum", pitch)
		end)
		t += gap
		gap = math.max(0.05, gap * 0.82)
		i += 1
	end
	task.delay(total, function()
		arpeggio({ 1, 1.26, 1.5, 2, 2.52, 3 })
	end)
end)

-- Carta dorada: destello de notas agudas cuando se da vuelta (atributo "GoldenCardAt" del Hud)
player:GetAttributeChangedSignal("GoldenCardAt"):Connect(function()
	local at = player:GetAttribute("GoldenCardAt")
	if typeof(at) ~= "number" then
		return
	end
	local inSeconds = at - workspace:GetServerTimeNow()
	if inSeconds < -0.5 or inSeconds > 5 then
		return
	end
	task.delay(math.max(0, inSeconds), function()
		arpeggio({ 1.5, 2, 2.52, 3, 4 })
	end)
end)

-- Agarre: golpe grave al quedar atrapado; arpegio al rescatar o ser rescatado
player:GetAttributeChangedSignal("Grabbed"):Connect(function()
	if player:GetAttribute("Grabbed") == true then
		lastPlayed.Drum = -math.huge
		play("Drum", 0.55)
		play("Hurt")
	end
end)
for _, attr in { "SavedBy", "Rescued" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		arpeggio({ 1, 1.26, 1.5, 2, 2.52 })
	end)
end

-- Sinergia: dos habilidades que combinan (atributo "Synergy" que publica el Hud)
player:GetAttributeChangedSignal("Synergy"):Connect(function()
	if (player:GetAttribute("Synergy") or "") ~= "" then
		arpeggio({ 1, 1.5, 1.26, 2 })
	end
end)

gameState:GetAttributeChangedSignal("DoorEnd"):Connect(function()
	if (gameState:GetAttribute("DoorEnd") or 0) > 0 then
		play("Door")
	end
end)
