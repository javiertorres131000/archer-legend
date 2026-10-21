-- GameServer (Script)
-- Ubicación: ServerScriptService > Server > GameServer
-- Punto de entrada del servidor. Solo conecta las piezas:
--   Lobby        zona segura donde se aparece y se prepara la partida
--   Run          una partida en la arena (reutiliza todo el motor de combate)
--   MatchManager ciclo LOBBY → PREPARING → STARTING → PLAYING → RESULTS → RETURNING
--   PlayerData / PlayerLife   estado y ciclo de vida de cada jugador
--   Profiles     perfil guardado (DataStore): monedas, capítulos y estadísticas
--   CratePlaza / CrateService   plaza volcánica del lobby y compra/apertura de cajas

local RunService = game:GetService("RunService")

local Lobby = require(script.Parent.Lobby)
local Run = require(script.Parent.Run)
local MatchManager = require(script.Parent.MatchManager)
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local Profiles = require(script.Parent.Profiles)
local DebugCommands = require(script.Parent.DebugCommands)
local CratePlaza = require(script.Parent.CratePlaza)
local CrateService = require(script.Parent.CrateService)

Run.init() -- arena y motor de combate (borra el Baseplate y el spawn de la plantilla)
Lobby.build() -- después de la arena: el único SpawnLocation del juego es el del lobby
CratePlaza.build() -- pegada al lobby (Config.Crates.Enabled)
CrateService.init()
PlayerLife.init()
MatchManager.init()
Profiles.init() -- guardado automático y al cerrar el servidor
Profiles.onLoaded(MatchManager.onProfileLoaded)
Profiles.onLoaded(CrateService.onProfileLoaded) -- monedas de prueba
DebugCommands.init() -- panel de prueba (F2): solo Studio o Config.Debug.Admins

PlayerData.init(function(player)
	PlayerLife.onPlayerAdded(player) -- aparece en el lobby
	MatchManager.onPlayerAdded(player)
	CrateService.onPlayerAdded(player) -- leaderstats
	task.spawn(Profiles.load, player) -- puede tardar: no frena al resto
end, function(player)
	MatchManager.onPlayerRemoving(player)
	PlayerLife.onPlayerRemoving(player)
	CrateService.onPlayerRemoving(player)
	Profiles.onPlayerRemoving(player) -- último: guarda y suelta el perfil
end)

RunService.Heartbeat:Connect(function(dt)
	MatchManager.update(dt)
end)
