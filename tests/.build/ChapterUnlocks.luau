local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- ChapterUnlocks (ModuleScript)
-- Ubicación: ServerScriptService > Server > ChapterUnlocks
-- Qué capítulos tiene disponibles cada jugador.
--
-- IMPORTANTE: por ahora vive solo en memoria y se pierde al salir del servidor.
-- No hay guardado permanente hasta la etapa 6 (DataStore). Este módulo es la única puerta:
-- en la etapa 6 se cambia por dentro para leer y escribir el perfil, sin tocar a quien lo usa.
--
-- El cliente recibe la lista en el atributo "UnlockedChapters" del Player ("forest,ruins").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require("./Config")
local Chapters = require("./Chapters")

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
	player:SetAttribute("UnlockedChapters", table.concat(ids, ","))
end

function ChapterUnlocks.onPlayerAdded(player: Player)
	local set: { [string]: boolean } = {}
	for _, ch in Chapters do
		if ch.UnlockedByDefault or Config.Debug.UnlockAllChapters then
			set[ch.Id] = true
		end
	end
	unlocked[player] = set
	publish(player)
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

-- Al ganar un capítulo se desbloquea el que lo requiere (solo para esta sesión, ver arriba).
function ChapterUnlocks.onChapterCleared(player: Player, chapterId: string)
	local set = unlocked[player]
	if not set then
		return
	end
	for _, ch in Chapters do
		if ch.Requires == chapterId then
			set[ch.Id] = true
		end
	end
	publish(player)
end

return ChapterUnlocks
