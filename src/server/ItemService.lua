local PlayerData = require(script.Parent.PlayerData)
local Enemies = require(script.Parent.Enemies)
local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RunItems"))
local RunItems = {}
local remotes
local accumulator = 0
function RunItems.init(r) remotes = r end
function RunItems.grant(player, id)
	local state = PlayerData.get(player)
	local def = Items.ById[id]
	if not state or not state.inMatch or not def or (state.items[id] or 0) >= def.Max then return false end
	state.items[id] = (state.items[id] or 0) + 1
	Items.apply(state.stats, id)
	PlayerData.applyToCharacter(player, if id == "Heart" then 10 else 0)
	remotes.ItemGranted:FireClient(player, id, state.items[id])
	return true
end
function RunItems.roll(player, rarity)
	local state = PlayerData.get(player)
	if not state or not state.inMatch then return end
	local def = Items.roll(state.items, rarity)
	if def then RunItems.grant(player, def.Id) end
end
local function pulse(player, origin, radius, damage, kind, limit)
	local hit = 0
	for _, enemy in Enemies.list do
		if enemy.alive and not enemy.hidden and math.abs(enemy.part.Position.Y - origin.Y) < 10
			and PlayerData.flat(enemy.part.Position - origin).Magnitude <= radius then
			Enemies.damage(enemy, damage, player, kind)
			hit += 1
			if hit >= limit then break end
		end
	end
	if hit > 0 then remotes.ItemEffect:FireAllClients(kind, origin, radius) end
end
function RunItems.onKill(enemy, player, kind)
	local state = player and PlayerData.get(player)
	-- Explosiones secundarias no generan otra cadena de explosiones.
	if not state or not state.inMatch or kind == "explosion" then return end
	local copies = (state.items.Powder or 0) + (state.items.Prism or 0)
	if copies == 0 then return end
	local synergy = if state.stats.burn or (state.items.Ember or 0) > 0 then 1.5 else 1
	pulse(player, enemy.part.Position, 7 + copies, state.stats.damage * 0.3 * copies * synergy, "explosion", 12)
end
function RunItems.update(dt, targets, now)
	accumulator += dt
	if accumulator < 0.5 then return end
	local elapsed = accumulator
	accumulator = 0
	for _, target in targets do
		local state, pos = target.state, target.root.Position
		local mult = if state.items.Prism then 2 else 1
		local ember = state.items.Ember or 0
		if ember > 0 then pulse(target.player, pos, 7 + ember * 2, state.stats.damage * 0.12 * ember * mult * elapsed, "aura", 16) end
		local storm = state.items.Storm or 0
		if storm > 0 and now >= state.nextStorm then
			state.nextStorm = now + 3
			-- Cadena: cada salto busca otro objetivo cerca del anterior.
			local previous, seen = pos, {}
			for _ = 1, (2 + storm) * mult do
				local enemy = Enemies.nearest(previous, seen, 24)
				if not enemy then break end
				seen[enemy] = true
				if math.abs(enemy.part.Position.Y - previous.Y) > 10 then continue end
				local destination = enemy.part.Position
				Enemies.damage(enemy, state.stats.damage * 0.45 * storm, target.player, "lightning")
				remotes.ItemEffect:FireAllClients("lightning", previous, 1, destination)
				previous = destination
			end
		end
	end
end
function RunItems.reset() accumulator = 0 end
return RunItems
