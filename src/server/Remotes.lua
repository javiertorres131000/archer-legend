-- Remotes (ModuleScript)
-- Ubicación: ServerScriptService > Server > Remotes
-- Crea los canales servidor <-> cliente y la carpeta GameState, cuyos atributos
-- (Wave, Phase, Level, XP...) se replican solos a todos los clientes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = folder
	return e
end

local Remotes = {
	-- servidor -> todos: (id, origen, dirección, velocidad, duración, userId del dueño)
	ProjectileFired = event("ProjectileFired"),
	-- servidor -> todos: (id)
	ProjectileEnded = event("ProjectileEnded"),
	-- servidor -> todos: (id, nueva posición, nueva dirección) cuando una flecha rebota
	ProjectileRedirected = event("ProjectileRedirected"),
	-- servidor -> jugador: (offerId, {skillIds}, segundos para elegir)
	SkillOffer = event("SkillOffer"),
	-- jugador -> servidor: (offerId, índice elegido 1..3)
	ChooseSkill = event("ChooseSkill"),
	-- servidor -> jugador: (skillId, stacks actuales)
	SkillGranted = event("SkillGranted"),
	-- servidor -> todos: la partida se reinició
	RunReset = event("RunReset"),
	-- servidor -> todos: (resumen) terminó la partida, mostrar resultados
	RunEnded = event("RunEnded"),
	-- jugador -> servidor: (acción, argumento) desde el lobby o los resultados.
	--   "SetReady" (boolean) · "SelectChapter" (Id del capítulo) · "ReturnToLobby"
	-- Lo valida todo MatchManager: tipos, estado de la partida, permisos y frecuencia.
	LobbyRequest = event("LobbyRequest"),
	-- servidor -> jugador: (mensaje) cuando una petición no se puede cumplir
	LobbyNotice = event("LobbyNotice"),
	-- servidor -> jugador: ({ eventos }) números flotantes: daño hecho y recibido, XP y botín.
	-- Llegan agrupados cada Config.CombatText.FlushInterval (ver CombatFeed).
	CombatText = event("CombatText"),
}

folder.Parent = ReplicatedStorage

local gameState = Instance.new("Folder")
gameState.Name = "GameState"
-- Ciclo de partida (MatchManager): LOBBY | PREPARING | STARTING | PLAYING | RESULTS | RETURNING
gameState:SetAttribute("MatchState", "LOBBY")
gameState:SetAttribute("SelectedChapter", "")
gameState:SetAttribute("LeaderId", 0)
gameState:SetAttribute("CountdownEnd", 0) -- hora del servidor (GetServerTimeNow) en que arranca
gameState:SetAttribute("ResultsEnd", 0)
-- Dentro de la partida (Waves): Waiting | Wave | Break | Victory | Defeat
gameState:SetAttribute("Phase", "Waiting")
gameState:SetAttribute("BossName", "")
gameState:SetAttribute("BossHealth", 0)
gameState:SetAttribute("BossMaxHealth", 0) -- 0 = no hay jefe
gameState:SetAttribute("BossEnraged", false)
gameState:SetAttribute("Wave", 0)
gameState:SetAttribute("TotalWaves", 0)
gameState:SetAttribute("Chapter", 1)
gameState:SetAttribute("ChapterName", "")
gameState:SetAttribute("TotalChapters", 1)
gameState:SetAttribute("RoomIndex", 1) -- sala actual (cambia al cruzar la puerta)
gameState:SetAttribute("DoorEnd", 0) -- hora del servidor en que la puerta pasa a todos (0 = cerrada)
gameState:SetAttribute("DoorInside", 0) -- cuántos están en la puerta
gameState:SetAttribute("DoorNeeded", 0) -- cuántos tienen que entrar
gameState:SetAttribute("PartySize", 1) -- jugadores con los que se escaló la oleada actual
gameState:SetAttribute("EnemiesLeft", 0)
gameState:SetAttribute("Level", 1)
gameState:SetAttribute("XP", 0)
gameState:SetAttribute("XPNeeded", 1)
gameState.Parent = ReplicatedStorage

Remotes.GameState = gameState

return Remotes
