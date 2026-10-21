--!strict
-- Profiles (ModuleScript)
-- Ubicación: ServerScriptService > Server > Profiles
-- Perfil permanente de cada jugador guardado con DataStore: monedas, capítulos y estadísticas.
-- Es el ÚNICO módulo que toca DataStore. El resto del juego lee y cambia el perfil con esta API.
--
-- Cómo se guarda (una entrada por jugador, clave "Player_<UserId>"):
--   { Version = 1, Data = { ...perfil... }, Lock = { JobId, Time } }
--
-- Seguridad de los datos:
--   · Reintentos: cada lectura/escritura se intenta Config.Profiles.Retries veces, con espera
--     creciente (Roblox a veces falla o limita pedidos).
--   · Sesión bloqueada: al cargar, se anota en Lock el JobId y un Id único de esta sesión. Solo
--     esa sesión puede escribir (aunque el jugador vuelva a entrar al mismo servidor). Si otro tiene el
--     perfil abierto (por ejemplo, el jugador cambió de servidor rápido), espera a que lo suelte.
--     Un bloqueo más viejo que LockExpire se considera abandonado (servidor caído) y se toma.
--     Si a este servidor le "roban" el perfil, deja de guardar para no pisar datos nuevos.
--   · Versiones: Data lleva Version. Al cargar un perfil viejo se le aplican las migraciones en
--     orden y se completan los campos que falten. Un perfil de una versión MÁS NUEVA que este
--     servidor se usa sin guardar (no se puede entender sin perderlo).
--   · Sin DataStore (Studio sin acceso, Config.Profiles.Enabled = false o Roblox caído):
--     se juega con un perfil temporal que nunca se escribe. Aviso en el lobby.
--
-- Se guarda: cada AutoSaveInterval segundos, al terminar una partida, al salir y al cerrar el server.
--
-- El cliente ve: atributos del Player "ProfileStatus" (Loading | Ready | Offline) y una por
-- moneda ("Gold", "Gems", "Stones"). Nunca escribe nada: todo cambio pasa por el servidor.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Currencies = require(Shared:WaitForChild("Currencies"))

local EquipmentDefs = require(Shared:WaitForChild("EquipmentDefs"))
local Talents = require(Shared:WaitForChild("Talents"))
local RuneDefs = require(Shared:WaitForChild("RuneDefs"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local Cfg = Config.Profiles

export type ChapterRecord = { Unlocked: boolean, Clears: number, BestWave: number }
export type Stats = { Runs: number, Victories: number, Kills: number, BossKills: number }
-- Cajas: cuántos de cada premio tenés (Id de Shared/CrateItems.lua), cajas abiertas, si ya
-- se dieron las monedas de prueba (Config.Crates.TestGold), lo equipado (un premio por espacio,
-- CrateItems.Slots) y las últimas compras con Robux ya entregadas (PurchaseId de cada recibo)
export type CrateData = {
	Owned: { [string]: number },
	Opened: number,
	TestGoldGiven: boolean,
	Equipped: { [string]: string },
	Receipts: { string },
}
export type Data = {
	Inventory: { { Uid: string, Id: string, Rarity: string, Level: number } },
	Equipment: { [string]: string },
	EquipmentInitialized: boolean,
	Talents: { [string]: number }, -- árbol de talentos: Id del nodo -> rango (Shared/Talents.lua)
	Account: { Level: number, XP: number }, -- nivel de cuenta: da los puntos del árbol
	-- Runas: nivel de cada una que tenés y las especiales puestas ("" = espacio vacío)
	Runes: { Owned: { [string]: number }, Active: { string } },
	Weapon: string, -- arma elegida (Shared/Weapons.lua)
	Currencies: { [string]: number },
	Chapters: { [string]: ChapterRecord },
	Stats: Stats,
	Crates: CrateData,
	CreatedAt: number,
	LastSeen: number,
}
export type Status = "Loading" | "Ready" | "Offline"

type Session = {
	player: Player,
	key: string,
	data: Data?,
	status: Status,
	canSave: boolean, -- false: perfil temporal o de otra versión, nunca se escribe
	saving: boolean,
	lastSave: number, -- os.clock()
	leaving: boolean,
	id: string, -- Id único de esta sesión (va en Lock)
}

local Profiles = {}

Profiles.SCHEMA_VERSION = 8

-- Migraciones: Migrations[n] recibe los datos guardados con la versión n y devuelve los de n + 1.
-- Para cambiar el formato: subí SCHEMA_VERSION y agregá la migración de la versión anterior.
-- (Los campos nuevos con valor por defecto no necesitan migración: los completa reconcile.)
Profiles.Migrations = {
	[1] = function(data: any): any return data end, -- inventario: reconcile agrega campos sin tocar el progreso
	-- 2 → 3: talentos. reconcile crea Talents vacío. Subir la versión evita que un servidor con
	-- código viejo (que no conoce Talents) cargue el perfil, lo guarde y borre los talentos.
	[2] = function(data: any): any return data end,
	-- 3 → 4: árbol de talentos. Los talentos de la lista anterior se borran (sin reembolso,
	-- decidido en desarrollo). reconcile agrega Account (nivel 1).
	[3] = function(data: any): any
		if type(data) == "table" then
			data.Talents = {}
		end
		return data
	end,
	-- 4 → 5: runas. reconcile crea Runes vacío; se sube la versión por lo mismo que en 2 → 3.
	[4] = function(data: any): any return data end,
	-- 5 → 6: arma elegida. reconcile pone el arco; se sube la versión por lo mismo que en 2 → 3.
	[5] = function(data: any): any return data end,
	-- 6 → 7: cajas (premios conseguidos). reconcile crea Crates vacío; se sube por lo mismo que en 2 → 3.
	[6] = function(data: any): any return data end,
	-- 7 → 8: premios equipados y recibos de Robux. reconcile los completa; se sube por lo mismo.
	[7] = function(data: any): any return data end,
	-- 0 = guardado sin versión: lo que haya se aprovecha y se completa
	[0] = function(data: any): any
		return if type(data) == "table" then data else {}
	end,
} :: { [number]: (any) -> any }

local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Data) -> () } = {}
local store: DataStore? = nil
local storeChecked = false
local storeDisabled = false -- Studio sin acceso a las APIs: no se vuelve a intentar
local inFlight = 0 -- cargas y guardados en curso (el cierre del servidor los espera)
local closing = false

local function serverTime(): number
	return os.time()
end

local function jobId(): string
	return game.JobId
end

local function newLock(session: Session): { [string]: any }
	return { JobId = jobId(), Session = session.id, Time = serverTime() }
end

-- ¿Este bloqueo es de esta sesión?
local function ownsLock(session: Session, lock: any): boolean
	return type(lock) == "table" and lock.Session == session.id
end

---------------------------------------------------------------------
-- Formato del perfil
---------------------------------------------------------------------

function Profiles.defaultData(): Data
	local currencies = {}
	for _, c in Currencies do
		currencies[c.Id] = 0
	end
	return {
		Inventory = {}, Equipment = {}, EquipmentInitialized = false,
		Talents = {},
		Account = { Level = 1, XP = 0 },
		Runes = { Owned = {}, Active = table.create(RuneDefs.ActiveSlots, "") },
		Weapon = Weapons.Default,
		Currencies = currencies,
		Chapters = {},
		Stats = { Runs = 0, Victories = 0, Kills = 0, BossKills = 0 },
		Crates = { Owned = {}, Opened = 0, TestGoldGiven = false, Equipped = {}, Receipts = {} },
		CreatedAt = serverTime(),
		LastSeen = serverTime(),
	}
end

local function count(v: any): number?
	if type(v) == "number" and v == v and v >= 0 and v < 1e12 then
		return math.floor(v)
	end
	return nil
end

-- Arma un perfil válido a partir de lo guardado: completa lo que falte y descarta lo roto.
function Profiles.reconcile(raw: any): Data
	local data = Profiles.defaultData()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.Currencies) == "table" then
		for id in data.Currencies do
			data.Currencies[id] = count(raw.Currencies[id]) or 0
		end
	end
	if type(raw.Chapters) == "table" then
		for id, rec in raw.Chapters do
			if type(id) == "string" and type(rec) == "table" then
				data.Chapters[id] = {
					Unlocked = rec.Unlocked == true,
					Clears = count(rec.Clears) or 0,
					BestWave = count(rec.BestWave) or 0,
				}
			end
		end
	end
	if type(raw.Stats) == "table" then
		local stats = data.Stats :: any
		for k in stats do
			stats[k] = count(raw.Stats[k]) or 0
		end
	end
	local seen = {}
	if type(raw.Inventory) == "table" then
		for _, item in raw.Inventory do
			if #data.Inventory >= EquipmentDefs.MaxInventory then break end
			if type(item) == "table" and type(item.Uid) == "string" and #item.Uid <= 80 and not seen[item.Uid]
				and type(item.Id) == "string" and EquipmentDefs.ById[item.Id] and Rarities.index(item.Rarity) then
				seen[item.Uid] = item.Id
				table.insert(data.Inventory, { Uid = item.Uid, Id = item.Id, Rarity = item.Rarity, Level = math.clamp(count(item.Level) or 1, 1, EquipmentDefs.MaxLevel) })
			end
		end
	end
	if type(raw.Equipment) == "table" then
		for _, slot in EquipmentDefs.Slots do
			local uid = raw.Equipment[slot]
			if type(uid) == "string" and seen[uid] and EquipmentDefs.ById[seen[uid]].Slot == slot then data.Equipment[slot] = uid end
		end
	end
	data.EquipmentInitialized = raw.EquipmentInitialized == true or #data.Inventory > 0
	-- Nivel de cuenta
	if type(raw.Account) == "table" then
		data.Account.Level = math.clamp(count(raw.Account.Level) or 1, 1, 10000)
		data.Account.XP = math.min(count(raw.Account.XP) or 0, Talents.xpNeeded(data.Account.Level) - 1)
	end
	-- Talentos: solo nodos que existen, con rango entre 1 y su máximo
	if type(raw.Talents) == "table" then
		for id, level in raw.Talents do
			local def = type(id) == "string" and Talents.ById[id]
			local n = count(level)
			if def and n and n > 0 then
				data.Talents[id] = math.min(n, def.Max)
			end
		end
	end
	-- Si hay más puntos gastados que los que da el nivel (datos rotos o cambio de costos), el
	-- árbol se vacía: los puntos se recuperan enteros para volver a repartirlos.
	if Talents.spent(data.Talents) > Talents.pointsForLevel(data.Account.Level) then
		data.Talents = {}
	end
	if type(raw.Runes) == "table" then
		if type(raw.Runes.Owned) == "table" then
			for id, level in raw.Runes.Owned do
				local def = type(id) == "string" and RuneDefs.ById[id]
				local n = count(level)
				if def and n and n > 0 then
					data.Runes.Owned[id] = if def.Kind == "Special" then 1 else math.min(n, RuneDefs.MaxLevel)
				end
			end
		end
		if type(raw.Runes.Active) == "table" then
			local used = {}
			for i = 1, RuneDefs.ActiveSlots do
				local id = raw.Runes.Active[i]
				local def = type(id) == "string" and RuneDefs.ById[id]
				if def and def.Kind == "Special" and data.Runes.Owned[id] and not used[id] then
					used[id] = true
					data.Runes.Active[i] = id
				end
			end
		end
	end
	-- Arma: solo una que exista
	if type(raw.Weapon) == "string" and Weapons.ById[raw.Weapon] then
		data.Weapon = raw.Weapon
	end
	-- Cajas: solo premios que existen
	if type(raw.Crates) == "table" then
		if type(raw.Crates.Owned) == "table" then
			for id, n in raw.Crates.Owned do
				local amount = count(n)
				if type(id) == "string" and CrateItems.ById[id] and amount and amount > 0 then
					data.Crates.Owned[id] = amount
				end
			end
		end
		data.Crates.Opened = count(raw.Crates.Opened) or 0
		data.Crates.TestGoldGiven = raw.Crates.TestGoldGiven == true
		-- Equipado: solo premios que tenés, cada uno en su espacio
		if type(raw.Crates.Equipped) == "table" then
			for _, slot in CrateItems.Slots do
				local id = raw.Crates.Equipped[slot]
				local prize = if type(id) == "string" then CrateItems.ById[id] else nil
				if prize and CrateItems.slotOf(prize) == slot and data.Crates.Owned[id] then
					data.Crates.Equipped[slot] = id
				end
			end
		end
		if type(raw.Crates.Receipts) == "table" then
			for _, id in raw.Crates.Receipts do
				if type(id) == "string" and #id <= 100 and #data.Crates.Receipts < 500 then
					table.insert(data.Crates.Receipts, id)
				end
			end
		end
	end
	data.CreatedAt = count(raw.CreatedAt) or data.CreatedAt
	return data
end

-- Lleva datos de cualquier versión anterior a la actual.
function Profiles.migrate(version: number, data: any): any
	local v = version
	while v < Profiles.SCHEMA_VERSION do
		local step = Profiles.Migrations[v]
		if step then
			data = step(data)
		end
		v += 1
	end
	return data
end

---------------------------------------------------------------------
-- DataStore
---------------------------------------------------------------------

local function getStore(): DataStore?
	if storeChecked then
		return store
	end
	storeChecked = true
	if not Cfg.Enabled then
		return nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Cfg.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[Profiles] No hay DataStore, se juega sin guardar:", result)
	end
	return store
end

-- Error de Studio sin permiso: no tiene sentido reintentar. Solo en Studio: en un servidor
-- real cualquier error se reintenta (nunca se apaga el guardado).
local function isAccessError(err: any): boolean
	if not RunService:IsStudio() then
		return false
	end
	local msg = tostring(err)
	return string.find(msg, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(msg, "publish this place", 1, true) ~= nil
		or string.find(msg, "^403:") ~= nil
end

-- Corre f con reintentos y espera creciente. Devuelve (ok, resultado o error).
local function withRetries(f: () -> any): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, Cfg.Retries do
		local ok, result = pcall(f)
		if ok then
			return true, result
		end
		lastErr = result
		if isAccessError(result) then
			storeDisabled = true
			warn("[Profiles] Studio sin acceso a DataStore: activá Game Settings › Security › Enable Studio Access to API Services. Se juega sin guardar.")
			break
		end
		if attempt < Cfg.Retries then
			task.wait(Cfg.RetryDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastErr
end

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = copy(x)
	end
	return t
end

---------------------------------------------------------------------
-- Publicar al cliente
---------------------------------------------------------------------

local function publish(session: Session)
	local player = session.player
	player:SetAttribute("ProfileStatus", session.status)
	local data = session.data
	for _, c in Currencies do
		player:SetAttribute(c.Id, if data then data.Currencies[c.Id] or 0 else 0)
	end
	local level = if data then data.Account.Level else 1
	player:SetAttribute("AccountLevel", level)
	player:SetAttribute("AccountXP", if data then data.Account.XP else 0)
	player:SetAttribute("AccountXPNeeded", Talents.xpNeeded(level))
	player:SetAttribute("TalentPoints", if data then Talents.pointsForLevel(level) - Talents.spent(data.Talents) else 0)
end

local function finishLoad(session: Session, data: Data, status: Status, canSave: boolean)
	session.data = data
	session.status = status
	session.canSave = canSave
	session.lastSave = os.clock()
	publish(session)
	for _, cb in loadedCallbacks do
		task.spawn(cb, session.player, data)
	end
end

---------------------------------------------------------------------
-- Cargar y guardar
---------------------------------------------------------------------

-- Escribe el perfil. release = soltar el bloqueo (el jugador se va o cierra el servidor).
local function save(session: Session, release: boolean): boolean
	local ds = getStore()
	local data = session.data
	if not session.canSave or not ds or storeDisabled or not data then
		return false
	end
	while session.saving do
		task.wait(0.1)
	end
	if not session.canSave then
		return false
	end
	session.saving = true
	inFlight += 1
	data.LastSeen = serverTime()
	local snapshot = copy(data)
	local lost = false
	local ok, err = withRetries(function()
		return (ds :: DataStore):UpdateAsync(session.key, function(old: any)
			lost = false
			if type(old) == "table" and not ownsLock(session, old.Lock) then
				lost = true -- otro servidor/sesión tomó el perfil (o ya lo soltó): no pisarlo
				return nil
			end
			return {
				Version = Profiles.SCHEMA_VERSION,
				Data = snapshot,
				Lock = if release then nil else newLock(session),
			}
		end)
	end)
	session.saving = false
	inFlight -= 1
	session.lastSave = os.clock()
	if release then
		session.canSave = false -- soltado: nada más puede escribir con esta sesión
	end
	if lost then
		session.canSave = false
		warn("[Profiles] El perfil de " .. session.player.Name .. " se abrió en otro servidor; este deja de guardarlo.")
		if not release and session.player.Parent then
			session.player:Kick("Tu perfil se abrió en otro servidor. Volvé a entrar.")
		end
		return false
	end
	if not ok then
		warn("[Profiles] No se pudo guardar el perfil de " .. session.player.Name .. ":", err)
	end
	return ok
end

-- Carga (o crea) el perfil del jugador y toma el bloqueo de sesión. Puede tardar: llamalo en task.spawn.
function Profiles.load(player: Player)
	if sessions[player] then
		return
	end
	local session: Session = {
		player = player,
		key = "Player_" .. player.UserId,
		data = nil,
		status = "Loading",
		canSave = false,
		saving = false,
		lastSave = os.clock(),
		leaving = closing,
		id = HttpService:GenerateGUID(false),
	}
	sessions[player] = session
	publish(session)
	if closing then
		sessions[player] = nil
		return
	end

	local ds = getStore()
	if not ds or storeDisabled then
		finishLoad(session, Profiles.defaultData(), "Offline", false)
		return
	end

	local steal = false
	local waits = 0
	inFlight += 1
	local function done()
		inFlight -= 1
	end
	while true do
		local outcome = "ok"
		local loaded: Data? = nil
		local ok, err = withRetries(function()
			return (ds :: DataStore):UpdateAsync(session.key, function(old: any)
				local now = serverTime()
				local rec = if type(old) == "table" then old else nil
				local lock = rec and rec.Lock
				-- Otro bloqueo (otro servidor, o la sesión anterior de este mismo que todavía guarda)
				if type(lock) == "table" and not ownsLock(session, lock) and not steal then
					local age = now - (tonumber(lock.Time) or 0)
					if age < Cfg.LockExpire then
						outcome = "locked"
						return nil
					end
				end
				local version = if rec and type(rec.Version) == "number" then rec.Version else 0
				if version > Profiles.SCHEMA_VERSION then
					-- Guardado por un servidor más nuevo: se usa sin tocarlo
					outcome = "future"
					loaded = Profiles.reconcile(rec and rec.Data)
					return nil
				end
				outcome = "ok"
				local data = Profiles.reconcile(Profiles.migrate(version, rec and rec.Data))
				loaded = data
				return {
					Version = Profiles.SCHEMA_VERSION,
					Data = copy(data),
					Lock = newLock(session),
				}
			end)
		end)

		if session.leaving then
			-- Se fue mientras cargaba: si llegamos a tomar el perfil, soltarlo enseguida
			if ok and outcome == "ok" and loaded then
				session.data = loaded
				session.canSave = true
				save(session, true)
			end
			sessions[player] = nil
			done()
			return
		end
		if not ok then
			warn("[Profiles] No se pudo cargar el perfil de " .. player.Name .. ", se juega sin guardar:", err)
			finishLoad(session, Profiles.defaultData(), "Offline", false)
			done()
			return
		elseif outcome == "locked" then
			-- Otro servidor lo tiene abierto: esperar a que lo suelte (o tomarlo al final)
			waits += 1
			if waits >= Cfg.LockRetries then
				steal = true
			end
			task.wait(Cfg.LockRetryDelay)
			if session.leaving or not player.Parent then
				sessions[player] = nil
				done()
				return
			end
		elseif outcome == "future" then
			warn("[Profiles] El perfil de " .. player.Name .. " es de una versión más nueva; no se guarda en este servidor.")
			finishLoad(session, loaded or Profiles.defaultData(), "Offline", false)
			done()
			return
		else
			finishLoad(session, loaded or Profiles.defaultData(), "Ready", true)
			done()
			return
		end
	end
end

-- Guarda ahora y ESPERA el resultado (true = quedó escrito en DataStore). Lo usan las compras
-- con Robux: no se confirma un recibo hasta que lo que se entregó está guardado.
function Profiles.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session or not session.canSave then
		return false
	end
	return save(session, false)
end

-- Guarda ahora, sin esperar (por ejemplo, al terminar una partida).
function Profiles.saveSoon(player: Player)
	local session = sessions[player]
	if session and session.canSave then
		task.spawn(save, session, false)
	end
end

function Profiles.onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.leaving = true
	if session.status == "Loading" then
		return -- lo suelta load() cuando termina
	end
	sessions[player] = nil
	if session.canSave then
		task.spawn(save, session, true)
	end
end

-- Cierre del servidor: guarda y suelta todos los perfiles (Roblox espera hasta 30 s).
function Profiles.closeAll()
	closing = true
	for player, session in sessions do
		session.leaving = true
		if session.status ~= "Loading" then -- las que cargan las suelta load() al terminar
			sessions[player] = nil
			if session.canSave then
				task.spawn(save, session, true)
			end
		end
	end
	-- Esperar TODO lo que esté en curso: estos guardados, los de jugadores que ya se fueron,
	-- autoguardados y cargas a medio terminar.
	local started = os.clock()
	while inFlight > 0 and os.clock() - started < Cfg.CloseTimeout do
		task.wait(0.5)
	end
end

function Profiles.init()
	game:BindToClose(Profiles.closeAll)
	-- Guardado automático
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, session in sessions do
			if session.canSave and not session.saving and now - session.lastSave >= Cfg.AutoSaveInterval then
				session.lastSave = now
				task.spawn(save, session, false)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Leer y cambiar el perfil
---------------------------------------------------------------------

-- Llamado cuando el perfil de un jugador queda listo (cargado o temporal).
function Profiles.onLoaded(callback: (Player, Data) -> ())
	table.insert(loadedCallbacks, callback)
end

-- El perfil, o nil si todavía está cargando.
function Profiles.get(player: Player): Data?
	local session = sessions[player]
	return session and session.data
end

function Profiles.status(player: Player): Status?
	local session = sessions[player]
	return session and session.status
end

function Profiles.isLoaded(player: Player): boolean
	return Profiles.get(player) ~= nil
end

-- Suma (o resta, con amount negativo) una moneda. No deja saldos negativos.
function Profiles.addCurrency(player: Player, currencyId: string, amount: number): boolean
	local session = sessions[player]
	local data = session and session.data
	if not session or not data or type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 then
		return false
	end
	local current = data.Currencies[currencyId]
	if current == nil or current + amount < 0 then
		return false
	end
	data.Currencies[currencyId] = current + amount
	publish(session)
	return true
end

-- Suma XP de cuenta y sube de nivel las veces que haga falta. Devuelve los niveles ganados.
function Profiles.addAccountXP(player: Player, amount: number): number
	local session = sessions[player]
	local data = session and session.data
	if not session or not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local account = data.Account
	account.XP += math.floor(amount)
	local gained = 0
	while account.XP >= Talents.xpNeeded(account.Level) do
		account.XP -= Talents.xpNeeded(account.Level)
		account.Level += 1
		gained += 1
	end
	publish(session)
	return gained
end

-- Vuelve a publicar monedas, nivel y puntos (después de comprar talentos).
function Profiles.refresh(player: Player)
	local session = sessions[player]
	if session then
		publish(session)
	end
end

-- El registro del capítulo (lo crea si no existe).
function Profiles.chapter(player: Player, chapterId: string): ChapterRecord?
	local data = Profiles.get(player)
	if not data then
		return nil
	end
	local rec = data.Chapters[chapterId]
	if not rec then
		rec = { Unlocked = false, Clears = 0, BestWave = 0 }
		data.Chapters[chapterId] = rec
	end
	return rec
end

-- Para las pruebas: olvida el estado (como un servidor nuevo).
function Profiles._resetForTests()
	table.clear(sessions)
	store = nil
	storeChecked = false
	storeDisabled = false
	inFlight = 0
	closing = false
end

return Profiles
