local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- Health (Script)
-- Ubicación: StarterPlayer > StarterCharacterScripts > Health
-- Reemplaza el script "Health" que Roblox pone por defecto en cada personaje, que regenera
-- vida sola con el tiempo. Lo dejamos vacío a propósito:
--   · En este género la vida solo se recupera con habilidades o al revivir.
--   · Un derribado queda con 1 de vida; la regeneración lo "curaría" por debajo del sistema
--     de derribo y confundiría la barra de vida.
-- Si querés regeneración, borrá este archivo (y Roblox vuelve a usar el suyo).

return {}
