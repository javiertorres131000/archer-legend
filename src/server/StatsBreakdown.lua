--!strict
-- StatsBreakdown (ModuleScript)
-- Ubicación: ServerScriptService > Server > StatsBreakdown
-- Panel de stats: cuánto aporta cada sistema permanente y qué stats tenés ahora.
--
--   En el lobby: base → + equipo → + talentos → + runas (el mismo orden que Run.start).
--   En partida:  además "ahora", con habilidades y objetos de la partida.
--
-- Todo lo calcula el servidor con copias de las stats (nunca toca las reales). El cliente pide
-- con Remotes.StatsRequest y recibe Remotes.StatsState: { rows, columns, values, inMatch }.

local Players = game:GetService("Players")
local PlayerData = require(script.Parent.PlayerData)
local Equipment = require(script.Parent.Equipment)
local TalentService = require(script.Parent.TalentService)
local Runes = require(script.Parent.Runes)
local CrateEquip = require(script.Parent.CrateEquip)

local StatsBreakdown = {}

-- Qué stats se muestran y cómo. kind: "num" · "pct" (0.05 → 5%) · "rate" (intervalo → disparos/s)
-- · "sec" · "bool". Los que valen lo mismo en todas las columnas y son 0 se ocultan.
StatsBreakdown.Rows = {
	{ key = "damage", label = "Daño por flecha", kind = "num" },
	{ key = "attackInterval", label = "Disparos por segundo", kind = "rate" },
	{ key = "critChance", label = "Prob. de crítico", kind = "pct" },
	{ key = "critMultiplier", label = "Daño crítico", kind = "mult" },
	{ key = "maxHealth", label = "Vida máxima", kind = "num" },
	{ key = "walkSpeed", label = "Velocidad", kind = "num" },
	{ key = "dashCooldown", label = "Recarga del dash", kind = "sec" },
	{ key = "pickupRadius", label = "Imán de orbes", kind = "num" },
	{ key = "frontArrows", label = "Flechas frontales extra", kind = "num" },
	{ key = "diagonalPairs", label = "Pares diagonales", kind = "num" },
	{ key = "pierce", label = "Atraviesa", kind = "num" },
	{ key = "ricochet", label = "Rebotes", kind = "num" },
	{ key = "burn", label = "Flechas de fuego", kind = "bool" },
	{ key = "burnBonus", label = "Daño de quemadura", kind = "pct" },
	{ key = "goldBonus", label = "Oro extra", kind = "pct" },
	{ key = "startChoices", label = "Habilidades al empezar", kind = "num" },
	{ key = "rerolls", label = "Cambios de cartas", kind = "num" },
}

local function snapshot(stats: any): { [string]: any }
	local out = {}
	for _, row in StatsBreakdown.Rows do
		out[row.key] = stats[row.key]
	end
	return out
end

-- Columnas acumuladas: { base, equipo, talentos, runas, mascota, [ahora] }. Cada una es el total hasta ese
-- paso (así se ve cuánto suma cada sistema restando la anterior).
function StatsBreakdown.compute(player: Player): { rows: { any }, columns: { string }, values: { { [string]: any } }, inMatch: boolean }
	local stats: any = PlayerData.newStats()
	local columns = { "Base" }
	local values = { snapshot(stats) }
	Equipment.apply(player, stats)
	table.insert(columns, "Equipo")
	table.insert(values, snapshot(stats))
	TalentService.apply(player, stats)
	table.insert(columns, "Talentos")
	table.insert(values, snapshot(stats))
	Runes.apply(player, stats)
	table.insert(columns, "Runas")
	table.insert(values, snapshot(stats))
	CrateEquip.apply(player, stats)
	table.insert(columns, "Mascota")
	table.insert(values, snapshot(stats))
	local state = PlayerData.get(player)
	local inMatch = state ~= nil and state.inMatch
	if state and inMatch then
		table.insert(columns, "Ahora")
		table.insert(values, snapshot(state.stats))
	end
	return { rows = StatsBreakdown.Rows, columns = columns, values = values, inMatch = inMatch }
end

local lastRequest: { [Player]: number } = {}

function StatsBreakdown.init(remotes: any)
	remotes.StatsRequest.OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < 0.5 then
			return
		end
		lastRequest[player] = now
		remotes.StatsState:FireClient(player, StatsBreakdown.compute(player))
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return StatsBreakdown
