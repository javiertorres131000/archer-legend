--!strict
-- ChapterUnlocks (ModuleScript)
-- Ubicación: ServerScriptService > Server > ChapterUnlocks
-- Qué capítulos tiene disponibles cada jugador. Es la única puerta para preguntarlo.
-- Se guarda en el perfil (Profiles: Chapters[Id].Unlocked). Mientras el perfil carga, solo
-- están los capítulos UnlockedByDefault.
--
-- El cliente recibe la lista en el atributo "UnlockedChapters" del Player ("forest,ruins")
-- y los récords en "ChapterRecords" ("forest=2/10": ganado 2 veces, mejor oleada 10).
-- Los modos (Shared/Modes.lua) van en las mismas listas: "daily" siempre; "tower" cuando ganaste
-- su capítulo Requires. Su récord también ("tower=0/37": piso 37).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Chapters = require(Shared:WaitForChild("Chapters"))
local Modes = require(Shared:WaitForChild("Modes"))
local Profiles = require(script.Parent.Profiles)

local ChapterUnlocks = {}

local unlocked: { [Player]: { [string]: boolean } } = {}

local function publish(player: Player)
	local set = unlocked[player]
	if not set then
		return
	end
	local ids = {}
	for _, ch in Chapters do
		if set[ch.Id] then
			table.insert(ids, ch.Id)
		end
	end
	for _, m in Modes.List do
		if set[m.Id] then
			table.insert(ids, m.Id)
		end
	end
	player:SetAttribute("UnlockedChapters", table.concat(ids, ","))
	-- Récords para el lobby: "forest=2/10,ruins=0/4" (veces ganado / mejor oleada)
	local data = Profiles.get(player)
	local records = {}
	if data then
		local all = table.clone(Chapters) :: { any }
		for _, m in Modes.List do
			table.insert(all, m)
		end
		for _, ch in all do
			local rec = data.Chapters[ch.Id]
			if rec and (rec.Clears > 0 or rec.BestWave > 0) then
				table.insert(records, string.format("%s=%d/%d", ch.Id, rec.Clears, rec.BestWave))
			end
		end
	end
	player:SetAttribute("ChapterRecords", table.concat(records, ","))
end

-- Vuelve a mandar desbloqueos y récords (por ejemplo, después de una partida).
function ChapterUnlocks.publish(player: Player)
	publish(player)
end

-- Arma el conjunto: los de siempre + los guardados en el perfil (si ya cargó).
function ChapterUnlocks.refresh(player: Player)
	local set: { [string]: boolean } = {}
	local data = Profiles.get(player)
	for _, ch in Chapters do
		local rec = data and data.Chapters[ch.Id]
		if ch.UnlockedByDefault or Config.Debug.UnlockAllChapters or (rec and rec.Unlocked) then
			set[ch.Id] = true
		end
	end
	-- Modos: sin Requires, siempre; con Requires, cuando ganaste ese capítulo (o ya tenés
	-- desbloqueado el que venía después: así también funciona "Desbloquear capítulos" del F2)
	for _, m in Modes.List do
		local rec = m.Requires and data and data.Chapters[m.Requires]
		local open = not m.Requires or Config.Debug.UnlockAllChapters or (rec ~= nil and rec.Clears > 0)
		for _, ch in Chapters do
			if m.Requires and ch.Requires == m.Requires and set[ch.Id] then
				open = true
			end
		end
		if open then
			set[m.Id] = true
		end
	end
	unlocked[player] = set
	publish(player)
end

function ChapterUnlocks.onPlayerAdded(player: Player)
	ChapterUnlocks.refresh(player)
end

function ChapterUnlocks.onPlayerRemoving(player: Player)
	unlocked[player] = nil
end

function ChapterUnlocks.isUnlocked(player: Player, chapterId: string): boolean
	local set = unlocked[player]
	return set ~= nil and set[chapterId] == true
end

-- Un capítulo se puede elegir si TODOS los integrantes lo tienen desbloqueado.
function ChapterUnlocks.partyCanPlay(players: { Player }, chapterId: string): boolean
	if #players == 0 then
		return false
	end
	for _, p in players do
		if not ChapterUnlocks.isUnlocked(p, chapterId) then
			return false
		end
	end
	return true
end

-- Al ganar un capítulo se desbloquea el que lo requiere (y queda guardado en el perfil).
function ChapterUnlocks.onChapterCleared(player: Player, chapterId: string)
	local set = unlocked[player]
	if not set then
		return
	end
	for _, ch in Chapters do
		if ch.Requires == chapterId then
			set[ch.Id] = true
			local rec = Profiles.chapter(player, ch.Id)
			if rec then
				rec.Unlocked = true
			end
		end
	end
	for _, m in Modes.List do
		if m.Requires == chapterId then
			set[m.Id] = true -- se calcula de las victorias (refresh): no hace falta guardarlo
		end
	end
	publish(player)
end

return ChapterUnlocks
