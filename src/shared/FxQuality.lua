--!strict
-- FxQuality (ModuleScript)
-- Ubicación: ReplicatedStorage > Shared > FxQuality
-- ¿Efectos en calidad baja? Lo usan los scripts visuales del cliente para no trabar celulares.
-- Se elige en Config.Effects.Quality: "Auto" (baja si es táctil sin teclado), "High" o "Low".

local UserInputService = game:GetService("UserInputService")
local Config = require(script.Parent.Config)

local FxQuality = {}

function FxQuality.isLow(): boolean
	local q = Config.Effects.Quality
	if q == "Low" then
		return true
	elseif q == "High" then
		return false
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return FxQuality
