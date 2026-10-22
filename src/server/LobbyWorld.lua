--!strict
-- LobbyWorld (ModuleScript)
-- Ubicación: ServerScriptService > Server > LobbyWorld
-- Le da vida a la Ciudadela del lobby (Workspace > Ciudadela, armada en Studio). Sin Ciudadela no
-- hace nada. Todo es escenario: lo que pide un jugador lo validan los servicios de siempre.
--   · NPCs: en Ciudadela > Puntos, cada parte NPC_* tiene los atributos Action ("Tienda" o
--     "Misiones"), Title, Subtitle y Model (nombre del personaje ya puesto en Ciudadela >
--     Personajes) o, si no hay, Prize (se arma el modelo de bloques de ese premio). Se le suma el
--     cartel y un ProximityPrompt; el cliente (LobbyWorld.client) abre la ventana.
--   · Portal: la parte Portal_Prompt tiene un ProximityPrompt "JUGAR" (el cliente pide SetReady,
--     igual que el botón JUGAR).
--   · Vitrina: cada modelo Pedestal_* (atributo Skin) muestra ese premio parado en su Ancla, con el
--     tag "VitrinaGira" (el cliente lo hace girar).
--   · Tablas de récords: cada parte Pantalla (atributo Board = "Nivel" o "Torre") muestra el top 10
--     global (OrderedDataStore). Sin acceso a DataStore (Studio sin APIs) muestra los jugadores
--     del servidor.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateModels = require(Shared:WaitForChild("CrateModels"))
local Profiles = require(script.Parent.Profiles)

local LobbyWorld = {}

local C = Color3.fromRGB
local GOLD = C(255, 210, 110)

local BOARD_REFRESH = 60 -- segundos entre lecturas del top 10
local SCORE_SAVE = 150 -- segundos entre guardados del puntaje de cada jugador
local TOP = 10

type BoardDef = { Store: string, Title: string, Unit: string, Value: (Profiles.Data) -> number }
local BOARDS: { [string]: BoardDef } = {
	Nivel = {
		Store = "LB_NivelCuenta_v1",
		Title = "🏆 MEJORES NIVELES",
		Unit = "Nv.",
		Value = function(data)
			return data.Account.Level
		end,
	},
	Torre = {
		Store = "LB_TorrePiso_v1",
		Title = "🗼 RÉCORD DE LA TORRE",
		Unit = "Piso",
		Value = function(data)
			local rec = (data.Chapters :: any).tower
			return if type(rec) == "table" and type(rec.BestWave) == "number" then rec.BestWave else 0
		end,
	},
}

local citadel: Model? = nil
local stores: { [string]: OrderedDataStore? } = {}
local storesOff = false
local names: { [number]: string } = {}

---------------------------------------------------------------------
-- NPCs y portal
---------------------------------------------------------------------

local function billboard(adornee: BasePart, title: string, subtitle: string, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Cartel"
	gui.Size = UDim2.fromOffset(220, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local name = Instance.new("TextLabel")
	name.Name = "Nombre"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.Font = Enum.Font.Fantasy
	name.TextScaled = true
	name.TextColor3 = GOLD
	name.TextStrokeTransparency = 0.3
	name.Text = title
	name.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Name = "Rol"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.new(1, 0, 0.4, 0)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = C(240, 236, 228)
	sub.TextStrokeTransparency = 0.4
	sub.Text = subtitle
	sub.Parent = gui
	-- "!" para avisar que hay algo para cobrar (lo prende el cliente)
	local alert = Instance.new("TextLabel")
	alert.Name = "Aviso"
	alert.BackgroundTransparency = 1
	alert.AnchorPoint = Vector2.new(0.5, 1)
	alert.Position = UDim2.fromScale(0.5, 0)
	alert.Size = UDim2.fromOffset(40, 40)
	alert.Font = Enum.Font.GothamBlack
	alert.TextScaled = true
	alert.TextColor3 = C(255, 215, 60)
	alert.TextStrokeTransparency = 0
	alert.Text = "!"
	alert.Visible = false
	alert.Parent = gui
	gui.Adornee = adornee
	gui.Parent = adornee
end

local function prompt(parent: BasePart, action: string, actionText: string, objectText: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = "LobbyPrompt"
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p:SetAttribute("LobbyAction", action)
	p.Parent = parent
end

local function buildNpc(point: BasePart, folder: Instance)
	local action = point:GetAttribute("Action")
	if type(action) ~= "string" then
		return
	end
	-- Personaje armado en Studio, o el modelo de bloques de un premio
	local model: Model
	local placed = citadel and citadel:FindFirstChild("Personajes")
	local named = point:GetAttribute("Model")
	local existing = placed and type(named) == "string" and placed:FindFirstChild(named)
	if existing and existing:IsA("Model") then
		model = existing
	else
		local prizeId = point:GetAttribute("Prize")
		if type(prizeId) ~= "string" then
			return
		end
		model = CrateModels.prize(prizeId)
		model.Name = "NPC_" .. action
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		-- El modelo del premio está con los pies en su origen y mirando a -Z
		model:PivotTo(point.CFrame)
		model.Parent = folder
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	-- El cartel va un poco arriba de la cabeza (medido desde la pieza a la que se pega)
	local box, size = model:GetBoundingBox()
	local above = box.Position.Y + size.Y / 2 - root.Position.Y + 1.4
	billboard(root, tostring(point:GetAttribute("Title") or action), tostring(point:GetAttribute("Subtitle") or ""), above)
	-- El prompt va a la altura del pecho
	local hit = Instance.new("Part")
	hit.Name = "Interaccion"
	hit.Anchored = true
	hit.CanCollide = false
	hit.CanQuery = false
	hit.CanTouch = false
	hit.Transparency = 1
	hit.Size = Vector3.new(2, 2, 2)
	hit.CFrame = point.CFrame * CFrame.new(0, 3, 0)
	hit.Parent = model
	prompt(hit, action, if action == "Misiones" then "Ver misiones" else "Comprar", tostring(point:GetAttribute("Title") or action))
	model:SetAttribute("LobbyAction", action)
	CollectionService:AddTag(model, "LobbyNpc")
end

---------------------------------------------------------------------
-- Vitrina
---------------------------------------------------------------------

local function buildShowcase(pedestal: Instance)
	local skin = pedestal:GetAttribute("Skin")
	local anchor = pedestal:FindFirstChild("Ancla")
	if type(skin) ~= "string" or not anchor or not anchor:IsA("BasePart") then
		return
	end
	local old = pedestal:FindFirstChild("Exhibido")
	if old then
		old:Destroy()
	end
	local ok, model = pcall(CrateModels.prize, skin)
	if not ok or not model then
		return
	end
	model.Name = "Exhibido"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	model:PivotTo(anchor.CFrame)
	model:SetAttribute("BaseCFrame", anchor.CFrame)
	CollectionService:AddTag(model, "VitrinaGira")
	model.Parent = pedestal
end

---------------------------------------------------------------------
-- Tablas de récords
---------------------------------------------------------------------

local function storeFor(board: string): OrderedDataStore?
	if storesOff then
		return nil
	end
	if stores[board] then
		return stores[board]
	end
	local def = BOARDS[board]
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(def.Store)
	end)
	if not ok then
		storesOff = true
		return nil
	end
	stores[board] = store
	return store
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and type(n) == "string" then n else "Jugador"
	return names[userId]
end

type Row = { Name: string, Value: number }

-- Top 10 global; si DataStore no anda, los jugadores de este servidor
local function readTop(board: string): ({ Row }, boolean)
	local def = BOARDS[board]
	local store = storeFor(board)
	if store then
		local ok, pageOrErr = pcall(function()
			return store:GetSortedAsync(false, TOP):GetCurrentPage()
		end)
		if ok then
			local rows = {}
			for _, entry in pageOrErr do
				local userId = tonumber(entry.key)
				if userId then
					table.insert(rows, { Name = nameOf(userId), Value = entry.value })
				end
			end
			return rows, true
		end
		storesOff = true
	end
	local rows = {}
	for _, p in Players:GetPlayers() do
		local data = Profiles.get(p)
		if data then
			table.insert(rows, { Name = p.DisplayName, Value = def.Value(data) })
		end
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	while #rows > TOP do
		table.remove(rows)
	end
	return rows, false
end

local function saveScores()
	for name, def in BOARDS do
		local store = storeFor(name)
		if not store then
			return
		end
		for _, p in Players:GetPlayers() do
			local data = Profiles.get(p)
			local value = if data then def.Value(data) else 0
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(p.UserId), math.floor(value))
				end)
			end
		end
	end
end

local RANK_COLORS = { C(255, 210, 80), C(220, 225, 235), C(220, 150, 90) }

local function render(screen: BasePart, board: string, rows: { Row }, global: boolean)
	local def = BOARDS[board]
	local gui = screen:FindFirstChild("Lista") :: SurfaceGui?
	if not gui then
		local g = Instance.new("SurfaceGui")
		g.Name = "Lista"
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.LightInfluence = 0
		g.Parent = screen
		gui = g
	end
	local surface = gui :: SurfaceGui
	surface:ClearAllChildren()
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.06, 0.04)
	list.Size = UDim2.fromScale(0.88, 0.92)
	list.Parent = surface
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local sub = Instance.new("TextLabel")
	sub.LayoutOrder = 0
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, 0, 0.06, 0)
	sub.Font = Enum.Font.GothamMedium
	sub.TextScaled = true
	sub.TextColor3 = C(170, 160, 200)
	sub.Text = if global then "Top " .. TOP .. " de todos los servidores" else "Jugadores en este servidor"
	sub.Parent = list
	if #rows == 0 then
		local empty = sub:Clone()
		empty.LayoutOrder = 1
		empty.Size = UDim2.new(1, 0, 0.08, 0)
		empty.Text = "Todavía no hay récords"
		empty.Parent = list
	end
	for i, row in rows do
		local line = Instance.new("Frame")
		line.LayoutOrder = i
		line.Size = UDim2.new(1, 0, 0.078, 0)
		line.BackgroundColor3 = if i % 2 == 1 then C(44, 36, 66) else C(34, 28, 52)
		line.BorderSizePixel = 0
		line.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = line
		local rank = Instance.new("TextLabel")
		rank.BackgroundTransparency = 1
		rank.Size = UDim2.fromScale(0.14, 1)
		rank.Font = Enum.Font.GothamBlack
		rank.TextScaled = true
		rank.TextColor3 = RANK_COLORS[i] or C(200, 195, 215)
		rank.Text = "#" .. i
		rank.Parent = line
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.16, 0)
		name.Size = UDim2.fromScale(0.54, 1)
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = C(240, 236, 228)
		name.Text = row.Name
		name.Parent = line
		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.Position = UDim2.fromScale(0.7, 0)
		value.Size = UDim2.fromScale(0.28, 1)
		value.Font = Enum.Font.GothamBlack
		value.TextScaled = true
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = GOLD
		value.Text = def.Unit .. " " .. tostring(math.floor(row.Value))
		value.Parent = line
		for _, label in { rank, name, value } do
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.18, 0)
			pad.PaddingBottom = UDim.new(0.18, 0)
			pad.PaddingLeft = UDim.new(0.02, 0)
			pad.PaddingRight = UDim.new(0.02, 0)
			pad.Parent = label
		end
	end
end

local function refreshBoards()
	local root = citadel
	if not root then
		return
	end
	for _, d in root:GetDescendants() do
		local board = d:GetAttribute("Board")
		if d:IsA("BasePart") and type(board) == "string" and BOARDS[board] then
			local rows, global = readTop(board)
			render(d, board, rows, global)
		end
	end
end

---------------------------------------------------------------------

function LobbyWorld.init()
	local m = workspace:FindFirstChild("Ciudadela")
	if not m or not m:IsA("Model") then
		return
	end
	citadel = m
	local npcs = Instance.new("Folder")
	npcs.Name = "NPCs"
	npcs.Parent = m
	local points = m:FindFirstChild("Puntos")
	if points then
		for _, point in points:GetChildren() do
			if point:IsA("BasePart") then
				if string.sub(point.Name, 1, 4) == "NPC_" then
					buildNpc(point, npcs)
				elseif point:GetAttribute("Action") == "Jugar" then
					prompt(point, "Jugar", "JUGAR", "Portal de batalla")
				end
			end
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Model") and type(d:GetAttribute("Skin")) == "string" then
			buildShowcase(d)
		end
	end
	task.spawn(function()
		refreshBoards() -- puede esperar a DataStore: no frena el arranque del servidor
		local sinceSave = 0
		while true do
			task.wait(BOARD_REFRESH)
			sinceSave += BOARD_REFRESH
			if sinceSave >= SCORE_SAVE then
				sinceSave = 0
				saveScores()
			end
			refreshBoards()
		end
	end)
end

-- Al cargar un perfil se refrescan las tablas (para verse en la lista de este servidor)
function LobbyWorld.onProfileLoaded(_player: Player, _data: Profiles.Data)
	if citadel then
		task.spawn(refreshBoards)
	end
end

-- Al salir se guarda su puntaje (si hay DataStore)
function LobbyWorld.onPlayerRemoving(player: Player)
	if not citadel or storesOff then
		return
	end
	local data = Profiles.get(player)
	if not data then
		return
	end
	for name, def in BOARDS do
		local store = storeFor(name)
		local value = def.Value(data)
		if store and value > 0 then
			task.spawn(pcall, function()
				store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
end

return LobbyWorld
