--!strict
-- Receipts (ModuleScript)
-- Ubicación: ServerScriptService > Server > Receipts
-- Compras con Robux (Developer Products). Es el ÚNICO módulo que asigna
-- MarketplaceService.ProcessReceipt (Roblox permite uno solo por juego): cada sistema registra
-- acá su producto con Receipts.register(productId, entregar).
--
-- Reglas de Roblox para no perder ni duplicar compras:
--   · `entregar` devuelve Receipts.GRANTED solo cuando lo comprado YA quedó guardado.
--   · Si devuelve otra cosa (o falla), Roblox vuelve a mandar el mismo recibo más tarde (incluso
--     en otro servidor). Por eso cada entrega anota el PurchaseId y no entrega dos veces el mismo.
--   · Si el jugador no está en este servidor, el recibo queda para cuando vuelva.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Receipts = {}

Receipts.GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
Receipts.NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet

export type Receipt = { PlayerId: number, ProductId: number, PurchaseId: string, CurrencySpent: number? }
type Handler = (Player, Receipt) -> any

local handlers: { [number]: Handler } = {}

function Receipts.register(productId: number, handler: Handler)
	if type(productId) == "number" and productId > 0 then
		handlers[productId] = handler
	end
end

function Receipts.isRegistered(productId: number): boolean
	return handlers[productId] ~= nil
end

function Receipts.process(receipt: Receipt): any
	local handler = handlers[receipt.ProductId]
	if not handler then
		warn("[Receipts] Producto sin registrar:", receipt.ProductId)
		return Receipts.NOT_YET
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Receipts.NOT_YET
	end
	local ok, result = pcall(handler, player, receipt)
	if not ok then
		warn("[Receipts] Error al entregar el producto", receipt.ProductId, result)
		return Receipts.NOT_YET
	end
	return if result == Receipts.GRANTED then Receipts.GRANTED else Receipts.NOT_YET
end

function Receipts.init()
	MarketplaceService.ProcessReceipt = Receipts.process
end

return Receipts
