--!strict
-- ShopService (ModuleScript)
-- Ubicación: ServerScriptService > Server > ShopService
-- Tienda del lobby (sin Robux). Qué se vende y los precios: Shared/ShopDefs.lua. Todo lo
-- decide el servidor; el cliente (ShopUI) pide y muestra.
--
-- Remotes.ShopRequest (RemoteFunction):
--   ("Get")               → { Ok, Offers, Exchanges, RuneChestCost, ResetIn }
--   ("BuyOffer", número)  → compra la oferta del día (una vez cada una)
--   ("Exchange", Id)      → hace un cambio (con límite por día)
--   ("RuneChest")         → abre un cofre de runas (el de RunesUI, mismo precio)
--   Todo devuelve la tienda actualizada (más Message), o { Ok = false, Error = "texto" }.
-- Antes de cobrar revisa: perfil cargado, en el lobby (no en partida ni listo), límite de
-- frecuencia, que exista lo pedido, que no se haya comprado/agotado hoy, lugar en el
-- inventario (equipo) y las monedas (Profiles.addCurrency no deja saldo negativo).
-- Cobra y entrega sin esperas en el medio; si la entrega falla, devuelve lo cobrado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopDefs = require(Shared:WaitForChild("ShopDefs"))
local EquipmentDefs = require(Shared:WaitForChild("EquipmentDefs"))
local RuneDefs = require(Shared:WaitForChild("RuneDefs"))
local Missions = require(Shared:WaitForChild("Missions"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)
local Equipment = require(script.Parent.Equipment) :: any
local Runes = require(script.Parent.Runes)

local ShopService = {}

local lastRequest: { [Player]: number } = {}
local now = function(): number
	return os.time()
end

-- Para las pruebas: fijar la hora
function ShopService._setClock(f: (() -> number)?)
	now = f or function()
		return os.time()
	end
end

local function fail(message: string): { [string]: any }
	return { Ok = false, Error = message }
end

-- Si cambió el día, se borran las compras y los cambios
local function refreshDay(data: any)
	local day = Missions.day(now())
	if data.Shop.Day ~= day then
		data.Shop.Day = day
		table.clear(data.Shop.Bought)
		table.clear(data.Shop.Exchanges)
	end
end

function ShopService.view(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return fail("Tu perfil todavía está cargando.")
	end
	refreshDay(data)
	local t = now()
	local offers = {}
	for _, o in ShopDefs.offers(player.UserId, Missions.day(t)) do
		local def = EquipmentDefs.ById[o.Id]
		table.insert(offers, {
			Index = o.Index,
			Id = o.Id,
			Name = def.Name,
			Slot = def.Slot,
			Rarity = o.Rarity,
			Price = table.clone(o.Price),
			Bought = data.Shop.Bought[tostring(o.Index)] == true,
		})
	end
	local exchanges = {}
	for _, e in ShopDefs.Exchanges do
		table.insert(exchanges, {
			Id = e.Id,
			Name = e.Name,
			Give = table.clone(e.Give),
			Get = table.clone(e.Get),
			Left = math.max(0, e.PerDay - (data.Shop.Exchanges[e.Id] or 0)),
			PerDay = e.PerDay,
		})
	end
	return {
		Ok = true,
		Offers = offers,
		Exchanges = exchanges,
		RuneChestCost = RuneDefs.ChestCost,
		ResetIn = Missions.dailyResetIn(t),
	}
end

local function canShop(player: Player): string?
	local state = PlayerData.get(player)
	if not state or state.inMatch or player:GetAttribute("InMatch") == true then
		return "La tienda se usa en el lobby."
	end
	if player:GetAttribute("Ready") == true then
		return "Cancelá LISTO para comprar."
	end
	return nil
end

local function withMessage(player: Player, message: string): { [string]: any }
	local view = ShopService.view(player)
	view.Message = message
	return view
end

function ShopService.buyOffer(player: Player, index: any): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return fail("Tu perfil todavía está cargando.")
	end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > ShopDefs.OfferCount then
		return fail("Pedido inválido.")
	end
	refreshDay(data)
	local offer = ShopDefs.offers(player.UserId, data.Shop.Day)[index]
	if not offer then
		return fail("Esa oferta no existe.")
	end
	if data.Shop.Bought[tostring(index)] then
		return fail("Ya compraste esa oferta hoy.")
	end
	if #data.Inventory >= EquipmentDefs.MaxInventory then
		return fail("Inventario lleno: reciclá o fusioná piezas para hacer lugar.")
	end
	if not Profiles.addCurrency(player, offer.Price.Currency, -offer.Price.Amount) then
		return fail("No te alcanza.")
	end
	local item = Equipment.grant(player, offer.Id, offer.Rarity, true)
	if not item then
		Profiles.addCurrency(player, offer.Price.Currency, offer.Price.Amount) -- devolver
		return fail("No se pudo entregar la pieza.")
	end
	data.Shop.Bought[tostring(index)] = true
	Profiles.saveSoon(player)
	return withMessage(player, "✔ " .. EquipmentDefs.ById[offer.Id].Name .. " comprada")
end

function ShopService.exchange(player: Player, id: any): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return fail("Tu perfil todavía está cargando.")
	end
	local e = type(id) == "string" and ShopDefs.ExchangeById[id] or nil
	if not e then
		return fail("Pedido inválido.")
	end
	refreshDay(data)
	local used = data.Shop.Exchanges[e.Id] or 0
	if used >= e.PerDay then
		return fail("Ya hiciste ese cambio todas las veces de hoy.")
	end
	if not Profiles.addCurrency(player, e.Give.Currency, -e.Give.Amount) then
		return fail("No te alcanza.")
	end
	Profiles.addCurrency(player, e.Get.Currency, e.Get.Amount)
	data.Shop.Exchanges[e.Id] = used + 1
	Profiles.saveSoon(player)
	return withMessage(player, "✔ Cambio hecho")
end

function ShopService.runeChest(player: Player): { [string]: any }
	local ok, message = Runes.request(player, "OpenChest")
	if not ok then
		return fail(message or "No se pudo abrir el cofre.")
	end
	return withMessage(player, "✔ Cofre de runas abierto")
end

local function onRequest(player: Player, action: any, arg: any): { [string]: any }
	if action == "Get" then
		return ShopService.view(player)
	end
	local t = os.clock()
	if t - (lastRequest[player] or -math.huge) < 0.3 then
		return fail("Esperá un momento.")
	end
	lastRequest[player] = t
	local problem = canShop(player)
	if problem then
		return fail(problem)
	end
	if action == "BuyOffer" then
		return ShopService.buyOffer(player, arg)
	elseif action == "Exchange" then
		return ShopService.exchange(player, arg)
	elseif action == "RuneChest" then
		return ShopService.runeChest(player)
	end
	return fail("Pedido inválido.")
end

function ShopService.init(remotes: any)
	remotes.ShopRequest.OnServerInvoke = onRequest
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
