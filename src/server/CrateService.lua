--!strict
-- CrateService (ModuleScript)
-- Ubicación: ServerScriptService > Server > CrateService
-- Compra y apertura de cajas. Todo se decide acá; el cliente solo pide y muestra.
--
-- Remotes.CrateRequest (RemoteFunction), pedidos del jugador:
--   ("Open", crateId)      → abrir pagando monedas: { Ok = true, Crate, Prize, Count, New, Gold }
--   ("BuyRobux", crateId)  → muestra la compra de Roblox de esa caja: { Ok = true }
--   ("Collection")         → { Ok = true, Owned = { [prizeId] = n }, Opened, Equipped }
--   ("Equip", prizeId) · ("Unequip", "Pet" | "Character")  → ver CrateEquip
--   Si algo no se puede: { Ok = false, Error = "texto para mostrar" }
-- Para abrir con monedas, el servidor revisa en este orden:
--   1. que el pedido tenga la forma correcta y la caja exista (Shared/Crates.lua)
--   2. que el perfil esté cargado y el jugador esté en el lobby (no en partida)
--   3. el límite de frecuencia (Config.Crates.OpenCooldown)
--   4. que esté cerca de una plataforma de la plaza (Config.Crates.StationRange)
--   5. que tenga las monedas (Profiles.addCurrency no deja saldo negativo)
-- Después descuenta, tira el premio con Random del servidor (ponderado por Chance), lo suma al
-- perfil (Profiles: Crates.Owned) y pide guardar pronto. El cliente recién ahí arranca la
-- animación, con el premio que le dijo el servidor.
--
-- Con Robux: el servidor revisa lo mismo (menos las monedas) y además que la caja tenga
-- ProductId, que el perfil se pueda guardar y que Roblox permita cajas pagas al azar en el país
-- del jugador (PolicyService.ArePaidRandomItemsRestricted; si no se puede saber, no se vende).
-- Recién ahí le muestra la compra. El premio se entrega cuando llega el recibo (Receipts):
-- se anota el PurchaseId en el perfil, se guarda y se le avisa al cliente (Remotes.CrateOpened)
-- para la animación. Un recibo repetido no entrega dos veces.
--
-- También: leaderstats con las monedas (Config.Crates.LeaderstatName) y las monedas de prueba
-- (Config.Crates.TestGold, una vez por perfil).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Crates = require(Shared:WaitForChild("Crates"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local CratePlazaLayout = require(Shared:WaitForChild("CratePlazaLayout"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Receipts = require(script.Parent.Receipts)
local CrateEquip = require(script.Parent.CrateEquip)

local Cfg = Config.Crates

local CrateService = {}

local lastOpen: { [Player]: number } = {}
local lastInfo: { [Player]: number } = {}
local connections: { [Player]: RBXScriptConnection } = {}
local paidAllowed: { [Player]: boolean } = {} -- true solo si PolicyService dijo que se puede
local stations: { Vector3 } = {}
local rng = Random.new()

-- Para las pruebas: tirada fija (número en [0, 1)) o nil para volver al azar
local forcedRoll: number? = nil
function CrateService._forceRoll(r: number?)
	forcedRoll = r
end

local function fail(message: string): { [string]: any }
	return { Ok = false, Error = message }
end

local function nearStation(player: Player): boolean
	if #stations == 0 then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, pos in stations do
		local d = root.Position - pos
		if Vector3.new(d.X, 0, d.Z).Magnitude <= Cfg.StationRange then
			return true
		end
	end
	return false
end

-- Lo que comparten las dos formas de abrir: caja válida, perfil, lobby, frecuencia, cercanía
local function check(player: Player, crateId: any): (Crates.Crate?, Profiles.Data?, string?)
	if not Cfg.Enabled then
		return nil, nil, "Las cajas están desactivadas."
	end
	if type(crateId) ~= "string" or #crateId > 40 then
		return nil, nil, "Pedido inválido."
	end
	local crate = Crates.ById[crateId]
	if not crate then
		return nil, nil, "Esa caja no existe."
	end
	local data = Profiles.get(player)
	if not data then
		return nil, nil, "Tu perfil todavía está cargando."
	end
	local state = PlayerData.get(player)
	if not state or state.inMatch then
		return nil, nil, "Las cajas se abren en el lobby."
	end
	if os.clock() - (lastOpen[player] or -math.huge) < Cfg.OpenCooldown then
		return nil, nil, "Esperá un momento."
	end
	if not nearStation(player) then
		return nil, nil, "Acercate a una plataforma de cajas."
	end
	return crate, data, nil
end

-- Tira el premio y lo suma al perfil. Devuelve el resultado para el cliente.
local function grant(player: Player, data: Profiles.Data, crate: Crates.Crate): { [string]: any }?
	local prizeId = Crates.pick(crate, forcedRoll or rng:NextNumber())
	if not prizeId or not CrateItems.ById[prizeId] then
		return nil
	end
	local owned = data.Crates.Owned
	local count = (owned[prizeId] or 0) + 1
	owned[prizeId] = count
	data.Crates.Opened += 1
	return {
		Ok = true,
		Crate = crate.Id,
		Prize = prizeId,
		Count = count,
		New = count == 1,
		Gold = data.Currencies[Cfg.Currency] or 0,
	}
end

function CrateService.open(player: Player, crateId: any): { [string]: any }
	local crate, data, problem = check(player, crateId)
	if problem or not crate or not data then
		return fail(problem or "No se pudo abrir.")
	end
	local gold = data.Currencies[Cfg.Currency] or 0
	if gold < crate.Price then
		local missing = string.format("Te faltan %s monedas.", Crates.formatPrice(crate.Price - gold))
		if CrateService.robuxAvailable(player, crate) then
			missing ..= " También podés abrirla con Robux."
		end
		return fail(missing)
	end
	if #crate.Prizes == 0 then
		return fail("Esta caja no tiene premios.")
	end
	-- Recién acá cuenta como intento (un pedido rechazado no gasta el límite)
	lastOpen[player] = os.clock()
	if not Profiles.addCurrency(player, Cfg.Currency, -crate.Price) then
		return fail("No tenés monedas suficientes.")
	end
	local result = grant(player, data, crate)
	if not result then
		Profiles.addCurrency(player, Cfg.Currency, crate.Price) -- devolver
		return fail("Esta caja no tiene premios.")
	end
	Profiles.saveSoon(player)
	return result
end

---------------------------------------------------------------------
-- Robux
---------------------------------------------------------------------

-- ¿Puede este jugador comprar esta caja con Robux?
function CrateService.robuxAvailable(player: Player, crate: Crates.Crate): boolean
	return Cfg.RobuxEnabled and crate.ProductId > 0 and paidAllowed[player] == true
end

function CrateService.buyRobux(player: Player, crateId: any): { [string]: any }
	local crate, _, problem = check(player, crateId)
	if problem or not crate then
		return fail(problem or "No se pudo comprar.")
	end
	if not Cfg.RobuxEnabled or crate.ProductId <= 0 then
		return fail("Esta caja no se vende con Robux.")
	end
	if paidAllowed[player] ~= true then
		return fail("Las cajas con Robux no están disponibles en tu región.")
	end
	if Profiles.status(player) ~= "Ready" then
		return fail("Ahora no se puede guardar tu progreso: probá en un rato.")
	end
	lastOpen[player] = os.clock()
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, crate.ProductId)
	end)
	if not ok then
		warn("[CrateService] No se pudo mostrar la compra:", err)
		return fail("No se pudo mostrar la compra. Probá de nuevo.")
	end
	return { Ok = true }
end

-- Llega el recibo de Roblox: entregar una vez, guardar y recién ahí confirmar.
local function onReceipt(crate: Crates.Crate)
	return function(player: Player, receipt: Receipts.Receipt): any
		local data = Profiles.get(player)
		if not data or Profiles.status(player) ~= "Ready" then
			return Receipts.NOT_YET -- sin perfil guardable todavía: Roblox reintenta después
		end
		local purchaseId = tostring(receipt.PurchaseId)
		local list = data.Crates.Receipts
		if table.find(list, purchaseId) then
			-- Ya se entregó (por ejemplo, falló el guardado la otra vez): solo falta guardar
			return if Profiles.saveNow(player) then Receipts.GRANTED else Receipts.NOT_YET
		end
		local result = grant(player, data, crate)
		if not result then
			return Receipts.NOT_YET
		end
		table.insert(list, purchaseId)
		while #list > Cfg.MaxSavedReceipts do
			table.remove(list, 1)
		end
		result.Paid = true
		Remotes.CrateOpened:FireClient(player, result)
		return if Profiles.saveNow(player) then Receipts.GRANTED else Receipts.NOT_YET
	end
end

local function checkPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	-- Si no se puede saber, se toma como prohibido (más seguro)
	local allowed = ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == false
	paidAllowed[player] = allowed
	if player.Parent then
		player:SetAttribute("PaidCratesAllowed", allowed)
	end
end

---------------------------------------------------------------------
-- Colección y pedidos
---------------------------------------------------------------------

function CrateService.collection(player: Player): { [string]: any }
	local now = os.clock()
	if now - (lastInfo[player] or -math.huge) < Cfg.InfoCooldown then
		return fail("Esperá un momento.")
	end
	lastInfo[player] = now
	local data = Profiles.get(player)
	if not data then
		return fail("Tu perfil todavía está cargando.")
	end
	return {
		Ok = true,
		Owned = table.clone(data.Crates.Owned),
		Opened = data.Crates.Opened,
		Equipped = table.clone(data.Crates.Equipped),
	}
end

local function onRequest(player: Player, action: any, arg: any): { [string]: any }
	if action == "Open" then
		return CrateService.open(player, arg)
	elseif action == "BuyRobux" then
		return CrateService.buyRobux(player, arg)
	elseif action == "Collection" then
		return CrateService.collection(player)
	elseif action == "Equip" then
		return CrateEquip.equip(player, arg)
	elseif action == "Unequip" then
		return CrateEquip.unequip(player, arg)
	end
	return fail("Pedido inválido.")
end

---------------------------------------------------------------------
-- Leaderstats y monedas de prueba
---------------------------------------------------------------------

function CrateService.onPlayerAdded(player: Player)
	player:SetAttribute("PaidCratesAllowed", false)
	task.spawn(checkPolicy, player)
	CrateEquip.onPlayerAdded(player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = Cfg.LeaderstatName
	coins.Value = (player:GetAttribute(Cfg.Currency) :: number?) or 0
	coins.Parent = stats
	stats.Parent = player
	-- Profiles publica cada moneda como atributo del Player: la columna lo copia
	connections[player] = player:GetAttributeChangedSignal(Cfg.Currency):Connect(function()
		coins.Value = (player:GetAttribute(Cfg.Currency) :: number?) or 0
	end)
end

function CrateService.onPlayerRemoving(player: Player)
	local conn = connections[player]
	if conn then
		conn:Disconnect()
		connections[player] = nil
	end
	lastOpen[player] = nil
	lastInfo[player] = nil
	paidAllowed[player] = nil
	CrateEquip.onPlayerRemoving(player)
end

function CrateService.onProfileLoaded(player: Player, data: Profiles.Data)
	CrateEquip.onProfileLoaded(player, data)
	if Cfg.TestGold <= 0 or data.Crates.TestGoldGiven then
		return
	end
	if Cfg.TestGoldOnlyInStudio and not RunService:IsStudio() then
		return
	end
	if Profiles.addCurrency(player, Cfg.Currency, Cfg.TestGold) then
		data.Crates.TestGoldGiven = true
		Profiles.saveSoon(player)
	end
end

-- Para las pruebas y Studio: dejar a un jugador comprar con Robux sin consultar a Roblox
function CrateService._setPaidAllowed(player: Player, allowed: boolean)
	paidAllowed[player] = allowed
	player:SetAttribute("PaidCratesAllowed", allowed)
end

-- Anota el Developer Product de cada caja en Receipts (se llama solo al iniciar)
function CrateService.registerProducts()
	for _, crate in Crates.List do
		if crate.ProductId > 0 then
			Receipts.register(crate.ProductId, onReceipt(crate))
		end
	end
end

function CrateService.init()
	stations = {}
	if Cfg.Enabled then
		for _, s in CratePlazaLayout.get().Stations do
			table.insert(stations, s.Position)
		end
	end
	CrateService.registerProducts()
	Receipts.init()
	Remotes.CrateRequest.OnServerInvoke = onRequest
end

return CrateService
