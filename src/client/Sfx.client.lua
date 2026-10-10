-- Sfx (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > Sfx
-- Sonidos del combate. Qué suena con qué está en Shared/Sounds.lua (ahí se cambian los sonidos).
-- Escucha los mismos eventos que los efectos visuales. Cada sonido tiene un mínimo de tiempo
-- entre reproducciones, así 100 enemigos muriendo no se vuelven un ruido continuo.
-- El oro suena cada vez más agudo si lo juntás seguido (racha).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
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
			play("XP")
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

gameState:GetAttributeChangedSignal("DoorEnd"):Connect(function()
	if (gameState:GetAttribute("DoorEnd") or 0) > 0 then
		play("Door")
	end
end)
