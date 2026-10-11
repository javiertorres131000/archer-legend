--!strict
-- Loot (ModuleScript)
-- Ubicación: ServerScriptService > Server > Loot
-- Botín que sueltan los enemigos al morir: oro siempre, y a veces gemas y piedras de mejora.
-- Lo decide y lo entrega el servidor. Lo cobran TODOS los participantes (botín compartido)
-- y va directo al perfil, así que no se pierde si alguien se va o pierde la partida.
-- Valores en Config.Loot y en Chapters.lua › Rewards.LootMult.
-- Los invocados por un jefe no dan botín (si no, se podría "farmear" dejando al jefe vivo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Currencies = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Currencies"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)

local Cfg = Config.Loot

export type Amounts = { [string]: number }

local Loot = {}

-- random(): número entre 0 y 1 (se puede pasar uno fijo en las pruebas).
function Loot.roll(cost: number, isBoss: boolean, lootMult: number, random: (() -> number)?): Amounts
	local rand: () -> number = random or function()
		return math.random()
	end
	local amounts: Amounts = {}
	local mult = math.max(0, lootMult)

	local base = math.max(1, cost) * Cfg.GoldPerCost * mult
	local variation = 1 + (rand() * 2 - 1) * Cfg.GoldVariation
	local gold = math.max(1, math.floor(base * variation + 0.5))
	amounts.Gold = gold

	if rand() < Cfg.GemChance then
		amounts.Gems = 1
	end
	if rand() < Cfg.StoneChance then
		amounts.Stones = 1
	end
	if isBoss then
		for id, n in Cfg.Boss do
			amounts[id] = (amounts[id] or 0) + math.floor(n * mult + 0.5)
		end
	end
	return amounts
end

-- Publica lo juntado en la partida (atributos RunGold, RunGems...) para el HUD.
local function publishRun(player: Player, runLoot: Amounts)
	for _, c in Currencies do
		player:SetAttribute("Run" .. c.Id, runLoot[c.Id] or 0)
	end
end

-- Entrega el botín de un enemigo a cada participante. Devuelve lo que se dio.
function Loot.grant(players: { Player }, amounts: Amounts): { [Player]: Amounts }
	local given: { [Player]: Amounts } = {}
	for _, player in players do
		local state = PlayerData.get(player)
		if state then
			local got: Amounts = {}
			for id, base in amounts do
				-- Talento Codicia: más oro para ese jugador
				local n = if id == "Gold" then math.floor(base * (1 + (state.stats.goldBonus or 0)) + 0.5) else base
				if n > 0 and Profiles.addCurrency(player, id, n) then
					got[id] = n
					state.runLoot[id] = (state.runLoot[id] or 0) + n
				end
			end
			publishRun(player, state.runLoot)
			given[player] = got
		end
	end
	return given
end

-- Al empezar la partida: contador del botín en cero.
function Loot.resetRun(players: { Player })
	for _, player in players do
		local state = PlayerData.get(player)
		if state then
			table.clear(state.runLoot)
			publishRun(player, state.runLoot)
		end
	end
end

return Loot
