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

local function func(name: string): RemoteFunction
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = folder
	return f
end

local Remotes = {
	-- jugador -> servidor (RemoteFunction): ("Open", Id de la caja) → resultado de la tirada ·
	-- ("Collection") → premios que tenés. Lo valida todo CrateService (ver ahí el formato).
	CrateRequest = func("CrateRequest"),
	-- servidor -> jugador: (resultado) se abrió una caja pagada con Robux (llega con el recibo)
	CrateOpened = event("CrateOpened"),
	-- jugador -> servidor (RemoteFunction): ("Get") · ("Claim", "Daily" | "Weekly", número).
	-- Misiones diarias y semanales; lo valida todo MissionService (ver ahí el formato).
	MissionRequest = func("MissionRequest"),
	-- jugador -> servidor (RemoteFunction): ("Get") · ("BuyOffer", número) · ("Exchange", Id) ·
	-- ("RuneChest"). Tienda del lobby; lo valida todo ShopService (ver ahí el formato).
	ShopRequest = func("ShopRequest"),
	ItemGranted = event("ItemGranted"),
	ItemEffect = event("ItemEffect"),
	RewardNotice = event("RewardNotice"),
	EquipmentState = event("EquipmentState"),
	EquipmentRequest = event("EquipmentRequest"),
	-- jugador -> servidor: ("Get") o ("Buy", Id del talento). Lo valida TalentService.
	TalentRequest = event("TalentRequest"),
	-- servidor -> jugador: ({ Id = nivel }, mensaje?) talentos del perfil
	TalentState = event("TalentState"),
	-- jugador -> servidor: (offerId) cambiar las cartas de habilidad (talento Otra mano)
	RerollSkills = event("RerollSkills"),
	-- servidor -> jugador: (runas {Id = nivel}, activas {Id | ""}, espacios abiertos, aviso?, Id recién conseguida?)
	RuneState = event("RuneState"),
	-- jugador -> servidor: ("Get") · ("Equip", espacio, Id) · ("Unequip", espacio) · ("OpenChest")
	RuneRequest = event("RuneRequest"),
	DashRequest = event("DashRequest"),
	-- jugador -> servidor: (apretado: boolean, dirección: Vector3) disparo manual. Lo valida Combat.
	AttackRequest = event("AttackRequest"),
	-- jugador -> servidor: () tocó el botón de forcejeo mientras lo tienen agarrado. Lo valida Grab.
	StruggleRequest = event("StruggleRequest"),
	-- jugador -> servidor: (origen de la cámara: Vector3, dirección de la mira: Vector3) marcar. Lo valida Ping.
	PingRequest = event("PingRequest"),
	-- servidor -> participantes: ("Add", marca) · ("Remove", id) · ("Clear"). Ver Ping.Mark
	Ping = event("Ping"),
	-- servidor -> todos: (id, origen, dirección, velocidad, duración, userId del dueño)
	ProjectileFired = event("ProjectileFired"),
	-- servidor -> todos: (id)
	ProjectileEnded = event("ProjectileEnded"),
	-- servidor -> todos: (id, nueva posición, nueva dirección) cuando una flecha rebota
	ProjectileRedirected = event("ProjectileRedirected"),
	-- servidor -> jugador: (offerId, {skillIds}, segundos para elegir, cambios, índice de la carta dorada o 0)
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
	--   "PlayAgain" (botón OTRA en resultados: vuelve y queda listo solo, mismo capítulo)
	-- Lo valida todo MatchManager: tipos, estado de la partida, permisos y frecuencia.
	LobbyRequest = event("LobbyRequest"),
	-- servidor -> jugador: (mensaje) cuando una petición no se puede cumplir
	LobbyNotice = event("LobbyNotice"),
	-- servidor -> jugador: ({ eventos }) números flotantes: daño hecho y recibido, XP y botín.
	-- Llegan agrupados cada Config.CombatText.FlushInterval (ver CombatFeed).
	CombatText = event("CombatText"),
	-- servidor -> todos: ({ spawn = {{id, pos, valor}}, take = {{id, userId}}, clear = bool })
	-- orbes de XP que aparecen y que alguien juntó (ver Orbs)
	Orbs = event("Orbs"),
	-- servidor -> todos: (posición, userId de quien lo abrió o 0) se abrió un cofre
	ChestOpened = event("ChestOpened"),
	-- jugador -> servidor: () pedir el panel de stats · servidor -> jugador: (desglose) ver StatsBreakdown
	StatsRequest = event("StatsRequest"),
	StatsState = event("StatsState"),
	-- jugador -> servidor: (acción) panel de prueba · servidor -> jugador: (ok, mensaje). Ver DebugCommands
	DebugCommand = event("DebugCommand"),
	-- jugador -> servidor: ("Select", Id del arma) en el lobby. Lo valida WeaponService.
	WeaponRequest = event("WeaponRequest"),
	-- servidor -> todos: (userId, origen, dirección, alcance, arco en grados, Id del arma) golpe
	-- cuerpo a cuerpo, para dibujarlo
	MeleeSwing = event("MeleeSwing"),
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
