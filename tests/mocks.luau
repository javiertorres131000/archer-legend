-- Imitación mínima de la API de Roblox para correr los módulos del servidor fuera de Studio.
-- Solo cubre lo que usa el juego. NO reemplaza probar en Studio: sirve para probar lógica.

local M = {}

---------------------------------------------------------------------
-- Reloj y tareas
---------------------------------------------------------------------
M.now = 0
local timers = {}

M.os = setmetatable({
	clock = function() return M.now end,
	time = function() return 1700000000 + math.floor(M.now) end, -- hora "real" (segundos)
}, { __index = os })

M.task = {
	spawn = function(f, ...) f(...) end,
	defer = function(f, ...) f(...) end,
	delay = function(t, f, ...)
		table.insert(timers, { at = M.now + t, f = f, args = { ... } })
	end,
	-- No hay hilos: esperar solo hace avanzar el reloj (sin disparar los task.delay)
	wait = function(t) M.now += (t or 0) return t or 0 end,
}

-- Avanza el reloj y dispara los task.delay vencidos.
function M.advance(dt)
	M.now += dt
	local due = {}
	for i = #timers, 1, -1 do
		if timers[i].at <= M.now then
			table.insert(due, table.remove(timers, i))
		end
	end
	for _, t in due do
		t.f(table.unpack(t.args))
	end
end

---------------------------------------------------------------------
-- Tipos de valor
---------------------------------------------------------------------
local V = {}
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
vmt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
vmt.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		assert(m > 0, "Unit de un vector cero")
		return vec(t.X / m, t.Y / m, t.Z / m)
	end
	if k == "Cross" then return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	return nil
end
V.new = vec
V.zero = vec(0, 0, 0)
V.one = vec(1, 1, 1)
V.xAxis = vec(1, 0, 0)
V.yAxis = vec(0, 1, 0)
V.zAxis = vec(0, 0, 1)
M.Vector3 = V
M.Vector2 = { new = function(x, y) return { X = x, Y = y } end }

local cfmt = {}
local function cframe(pos, look)
	return setmetatable({ Position = pos or V.zero, LookVector = look or V.zAxis }, cfmt)
end
cfmt.__mul = function(a) return a end
cfmt.__add = function(a, v) return cframe(a.Position + v, a.LookVector) end
cfmt.__sub = function(a, v) return cframe(a.Position - v, a.LookVector) end
M.CFrame = {
	-- Como en Roblox: CFrame.new(x, y, z) o CFrame.new(Vector3)
	new = function(x, y, z)
		if type(x) == "table" then return cframe(x) end
		return cframe(vec(x, y, z))
	end,
	lookAt = function(a, b)
		local d = b - a
		return cframe(a, if d.Magnitude > 0 then d.Unit else V.zAxis)
	end,
	Angles = function(_, y, _)
		return {
			VectorToWorldSpace = function(_, v)
				local c, s = math.cos(y), math.sin(y)
				return vec(c * v.X + s * v.Z, v.Y, -s * v.X + c * v.Z)
			end,
		}
	end,
}

local colormt = { __index = { Lerp = function(a) return a end } }
M.Color3 = {
	new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, colormt) end,
	fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, colormt) end,
}
M.UDim2 = {
	new = function(...) return { ... } end,
	fromScale = function(x, y) return { scale = { x, y } } end,
	fromOffset = function(x, y) return { offset = { x, y } } end,
}
M.UDim = { new = function(...) return { ... } end }
-- Terreno (MapBuilder): las pruebas no dibujan nada; se anota qué se pidió
M.Region3 = {
	new = function(min, max)
		local r = { CFrame = M.CFrame.new((min + max) / 2), Size = max - min }
		function r.ExpandToGrid(self) return self end
		return r
	end,
}
M.Vector3int16 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
M.RaycastParams = { new = function() return {} end }
-- Partículas: solo guardan lo que reciben
M.NumberSequence = { new = function(...) return { ... } end }
M.NumberSequenceKeypoint = { new = function(...) return { ... } end }
M.ColorSequence = { new = function(...) return { ... } end }
M.NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
M.terrainWrites = 0

-- warn de Roblox: se guarda para que las pruebas lo revisen (y no ensucia la salida)
M.warnings = {}
M.warn = function(...)
	local parts = {}
	for _, v in { ... } do table.insert(parts, tostring(v)) end
	table.insert(M.warnings, table.concat(parts, " "))
end
-- Random con semilla (como el de Roblox: misma semilla, misma secuencia)
M.Random = {
	new = function(seed)
		local state = math.floor(math.abs(seed or os.clock() * 1e6)) % 2147483647
		if state == 0 then state = 1 end
		local function nextFloat()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		return {
			NextInteger = function(_, a, b) return a + math.floor(nextFloat() * (b - a + 1)) end,
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + nextFloat() * (b - a)
			end,
		}
	end,
}
M.TweenInfo = { new = function(...) return { ... } end }

-- Enum.Lo.Que.Sea devuelve un texto con su nombre
local function enumNode(path)
	return setmetatable({}, {
		__index = function(_, k) return enumNode(path .. "." .. k) end,
		__tostring = function() return path end,
	})
end
M.Enum = enumNode("Enum")

M.typeof = function(v)
	if getmetatable(v) == vmt then return "Vector3" end
	return type(v)
end

---------------------------------------------------------------------
-- Señales
---------------------------------------------------------------------
local function signal()
	local s = { handlers = {} }
	function s:Connect(f)
		local entry = { f = f, connected = true }
		table.insert(self.handlers, entry)
		return { Disconnect = function() entry.connected = false end, Connected = true }
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.connected then h.f(...) end
		end
	end
	return s
end
M.signal = signal

---------------------------------------------------------------------
-- Instancias
---------------------------------------------------------------------
local SIGNAL_NAMES = {
	PromptButtonHoldBegan = true, PromptButtonHoldEnded = true, Triggered = true,
	Died = true, CharacterAdded = true, OnServerEvent = true, OnClientEvent = true,
	Heartbeat = true, PlayerAdded = true, PlayerRemoving = true,
}

local instmt = {}
local function newInstance(className, props)
	local raw = {
		ClassName = className,
		Name = className,
		_children = {},
		_attrs = {},
		_parent = nil,
		_destroyed = false,
	}
	for k, v in props or {} do raw[k] = v end
	return setmetatable({ _raw = raw }, instmt)
end

local methods = {}
function methods:Destroy()
	local raw = rawget(self, "_raw")
	raw._destroyed = true
	self.Parent = nil
end
function methods:SetNetworkOwner(owner) rawget(self, "_raw")._networkOwner = owner end
function methods:SetNetworkOwnershipAuto() rawget(self, "_raw")._networkAuto = true end
function methods:SetAttribute(k, v) rawget(self, "_raw")._attrs[k] = v end
function methods:GetAttribute(k) return rawget(self, "_raw")._attrs[k] end
function methods:GetChildren() return table.clone(rawget(self, "_raw")._children) end
function methods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, c in rawget(node, "_raw")._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods:FindFirstChild(name)
	for _, c in rawget(self, "_raw")._children do
		if c.Name == name then return c end
	end
	return nil
end
function methods:FindFirstChildOfClass(cls)
	for _, c in rawget(self, "_raw")._children do
		if c.ClassName == cls then return c end
	end
	return nil
end
function methods:WaitForChild(name)
	local c = self:FindFirstChild(name)
	assert(c, "WaitForChild no encontró " .. tostring(name))
	return c
end
function methods:IsDescendantOf(other)
	local p = self.Parent
	while p do
		if p == other then return true end
		p = p.Parent
	end
	return false
end
function methods:ClearAllChildren()
	for _, c in table.clone(rawget(self, "_raw")._children) do c:Destroy() end
end
function methods:GetAttributeChangedSignal() return signal() end
function methods:FireAllClients(...) end
function methods:GetServerTimeNow() return M.now end
function methods:PivotTo(cf)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then root.Position = cf.Position end
end
function methods:FireClient(...) end
function methods:Kick(msg) rawget(self, "_raw").kicked = msg or "" end
-- Terreno y rayos: sin geometría real (los rayos no pegan en nada)
function methods:Clear() end
function methods:WriteVoxels() M.terrainWrites += 1 end
M.terrainFills = 0
function methods:FillBlock() M.terrainFills += 1 end
function methods:FillCylinder() M.terrainFills += 1 end
function methods:FillBall() M.terrainFills += 1 end
function methods:FillWedge() M.terrainFills += 1 end
function methods:SetMaterialColor() end
function methods:PasteRegion() end
function methods:Raycast() return nil end
function methods:IsA(cls) return rawget(self, "_raw").ClassName == cls end

instmt.__index = function(self, k)
	local raw = rawget(self, "_raw")
	if k == "Parent" then return raw._parent end
	local v = raw[k] -- lo propio de la instancia (o lo que reemplace una prueba) va primero
	if v ~= nil then return v end
	if methods[k] then return methods[k] end
	if SIGNAL_NAMES[k] then
		raw[k] = signal()
		return raw[k]
	end
	-- un hijo con ese nombre (como en Roblox)
	for _, c in raw._children do
		if c.Name == k then return c end
	end
	return nil
end
instmt.__newindex = function(self, k, v)
	local raw = rawget(self, "_raw")
	if k == "Parent" then
		local old = raw._parent
		if old then
			local list = rawget(old, "_raw")._children
			for i, c in list do
				if c == self then table.remove(list, i) break end
			end
		end
		raw._parent = v
		if v then table.insert(rawget(v, "_raw")._children, self) end
		return
	end
	if k == "CFrame" and type(v) == "table" and v.Position then
		raw.CFrame = v
		raw.Position = v.Position
		return
	end
	if k == "Health" and raw.ClassName == "Humanoid" then
		local was = raw.Health or 0
		raw.Health = math.clamp(v, 0, raw.MaxHealth or 100)
		if was > 0 and raw.Health <= 0 then
			raw.Died = raw.Died or signal()
			raw.Died:Fire()
		end
		return
	end
	raw[k] = v
end

M.Instance = {
	new = function(className, parent)
		local inst = newInstance(className)
		if parent then inst.Parent = parent end
		return inst
	end,
}

---------------------------------------------------------------------
-- Servicios
---------------------------------------------------------------------
local workspaceInst = newInstance("Workspace", { Name = "Workspace" })
-- Las pruebas usan el lobby de antes (todo el servidor es un equipo) salvo que lo apaguen
-- antes de cargar el juego (ver Server/Places y test_parties.luau).
workspaceInst:SetAttribute("TestClassicLobby", true)
newInstance("Terrain", { Name = "Terrain" }).Parent = workspaceInst
function methods:BulkMoveTo(parts, cframes)
	for i, p in parts do
		p.CFrame = cframes[i]
		p.Position = cframes[i].Position
	end
end
M.workspace = workspaceInst

local Players = newInstance("Players", { Name = "Players", CharacterAutoLoads = true })
M.playerList = {}
function methods:GetPlayers() return table.clone(M.playerList) end
function methods:GetPlayerByUserId(id)
	for _, p in M.playerList do
		if p.UserId == id then return p end
	end
	return nil
end

local replicated = newInstance("ReplicatedStorage", { Name = "ReplicatedStorage" })
newInstance("Folder", { Name = "Shared" }).Parent = replicated
---------------------------------------------------------------------
-- DataStore en memoria, con fallas a pedido
--   M.dataStore.failNext = n      las próximas n llamadas fallan (error 502)
--   M.dataStore.accessDenied      todas fallan como Studio sin acceso a las APIs
--   M.dataStore.calls             llamadas hechas
--   M.dataStore.onCall(key)       se llama antes de cada pedido (para simular cosas a mitad)
-- Copia los valores al guardar y leer (como Roblox, que los serializa) y rechaza lo que no
-- se puede guardar (funciones, instancias, Color3...).
---------------------------------------------------------------------
local function dsCopy(v, path)
	local t = type(v)
	if t == "nil" or t == "string" or t == "boolean" then return v end
	if t == "number" then
		assert(v == v, "DataStore: NaN en " .. path)
		return v
	end
	assert(t == "table" and getmetatable(v) == nil, "DataStore: no se puede guardar " .. t .. " en " .. path)
	local out = {}
	for k, x in v do
		assert(type(k) == "string" or type(k) == "number", "DataStore: clave inválida en " .. path)
		out[k] = dsCopy(x, path .. "." .. tostring(k))
	end
	return out
end
M.dataStore = { failNext = 0, accessDenied = false, calls = 0, data = {}, onCall = nil }
local function dsCheck(key)
	M.dataStore.calls += 1
	if M.dataStore.onCall then M.dataStore.onCall(key) end
	if M.dataStore.accessDenied then
		error("StudioAccessToApisNotAllowed: You must publish this place to the web to access DataStore.")
	end
	if M.dataStore.failNext > 0 then
		M.dataStore.failNext -= 1
		error("502: API Services rejected request (simulado)")
	end
end
local DataStoreService = newInstance("DataStoreService", { Name = "DataStoreService" })
rawget(DataStoreService, "_raw").GetDataStore = function(_, name)
	local data = M.dataStore.data
	return {
		GetAsync = function(_, key)
			dsCheck(key)
			return dsCopy(data[key], key)
		end,
		UpdateAsync = function(_, key, transform)
			dsCheck(key)
			local new = transform(dsCopy(data[key], key))
			if new ~= nil then
				data[key] = dsCopy(new, key)
			end
			return dsCopy(new, key)
		end,
	}
end

local guidCount = 0
local HttpService = newInstance("HttpService", { Name = "HttpService" })
rawget(HttpService, "_raw").GenerateGUID = function()
	guidCount += 1
	return string.format("guid-%04d", guidCount)
end
M.isStudio = true -- RunService:IsStudio()

local services = {
	DataStoreService = DataStoreService,
	HttpService = HttpService,
	Players = Players,
	Workspace = workspaceInst,
	ReplicatedStorage = replicated,
	RunService = newInstance("RunService", { IsStudio = function() return M.isStudio end }),
	TweenService = { Create = function() return { Play = function() end } end },
	Debris = { AddItem = function() end },
}
M.game = {
	JobId = "servidor-de-prueba",
	GetService = function(_, name)
		if not services[name] then services[name] = newInstance(name, { Name = name }) end
		return services[name]
	end,
	BindToClose = function(_, f) table.insert(M.closeHandlers, f) end,
}
M.closeHandlers = {}
-- Simula el cierre del servidor (game:BindToClose)
function M.closeServer()
	for _, f in M.closeHandlers do f() end
end
M.Players = Players

-- Como Roblox: sin posición pedida, el personaje aparece sobre el SpawnLocation (si hay uno).
local function findSpawn(inst)
	for _, c in rawget(inst, "_raw")._children do
		if c.ClassName == "SpawnLocation" then return c end
		local found = findSpawn(c)
		if found then return found end
	end
	return nil
end

-- Crea un personaje con Humanoid y HumanoidRootPart en `pos`.
local function makeCharacter(player, pos)
	if not pos then
		local spawn = findSpawn(workspaceInst)
		if spawn and spawn.CFrame then pos = spawn.CFrame.Position + V.new(0, 3, 0) end
	end
	local character = newInstance("Model", { Name = player.Name })
	local humanoid = newInstance("Humanoid", { Name = "Humanoid", MaxHealth = 100, WalkSpeed = 16, JumpHeight = 7.2, JumpPower = 50 })
	rawget(humanoid, "_raw").Health = 100
	humanoid.Parent = character
	local root = newInstance("Part", { Name = "HumanoidRootPart", Position = pos or V.new(0, 3, 0), AssemblyLinearVelocity = V.zero })
	root.Parent = character
	character.Parent = workspaceInst
	return character
end

-- Agrega un jugador falso. Se lo puede mover con M.moveTo(player, Vector3).
local lastUserId = 0
function M.addPlayer(name, userId)
	if not userId then
		lastUserId += 1 -- cada jugador nuevo, un UserId nuevo (como en Roblox)
		userId = lastUserId
	end
	local p = newInstance("Player", { Name = name, DisplayName = name, UserId = userId })
	rawget(p, "_raw")._parent = Players
	rawget(p, "_raw").LoadCharacterAsync = function(self)
		local old = self.Character
		if old then old:Destroy() end
		local c = makeCharacter(self, rawget(self, "_raw").spawnAt)
		rawget(self, "_raw").Character = c
		self.CharacterAdded:Fire(c)
	end
	rawget(p, "_raw").LoadCharacter = rawget(p, "_raw").LoadCharacterAsync
	table.insert(M.playerList, p)
	Players.PlayerAdded:Fire(p)
	return p
end

function M.removePlayer(p)
	Players.PlayerRemoving:Fire(p)
	for i, q in M.playerList do
		if q == p then table.remove(M.playerList, i) break end
	end
	rawget(p, "_raw")._parent = nil
end

function M.moveTo(p, pos)
	local c = p.Character
	if c then c.HumanoidRootPart.Position = pos end
end

-- script.Parent no se usa: el armador de pruebas reescribe los require.
M.script = newInstance("Script")

return M
