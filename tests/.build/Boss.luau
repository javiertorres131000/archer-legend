local __M = require("./mocks")
local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, task, os, typeof, TweenInfo = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, __M.typeof, __M.TweenInfo
-- Boss (ModuleScript)
-- Ubicación: ServerScriptService > Server > Boss
-- Publica en GameState la barra de vida del jefe vivo (si hay uno) para el HUD.
-- La IA de los jefes vive en EnemyAI y sus definiciones en Data > EnemyTypes (Boss = true).

local Enemies = require("./Enemies")

local Boss = {}

local gameState: Folder

function Boss.init(state: Folder)
	gameState = state
end

function Boss.update()
	local boss = nil
	for _, e in Enemies.list do
		if e.alive and e.isBoss then
			boss = e
			break
		end
	end
	if boss then
		gameState:SetAttribute("BossName", boss.def.Name)
		gameState:SetAttribute("BossHealth", math.max(0, math.ceil(boss.health)))
		gameState:SetAttribute("BossMaxHealth", math.ceil(boss.maxHealth))
		-- Furia = cualquier fase después de la primera
		gameState:SetAttribute("BossEnraged", boss.ai.phase > 1)
	else
		gameState:SetAttribute("BossName", "")
		gameState:SetAttribute("BossHealth", 0)
		gameState:SetAttribute("BossMaxHealth", 0)
		gameState:SetAttribute("BossEnraged", false)
	end
end

return Boss
