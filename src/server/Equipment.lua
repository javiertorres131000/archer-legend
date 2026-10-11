local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Defs = require(Shared:WaitForChild("EquipmentDefs"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local HttpService = game:GetService("HttpService")
local Equipment = {}
local remotes
local lastRequest = {}
local function isEquipped(data, uid)
	for _, equippedUid in data.Equipment do if equippedUid == uid then return true end end
	return false
end
local function find(data, uid)
	for index, item in data.Inventory do if item.Uid == uid then return item, index end end
	return nil
end
function Equipment.publish(player, message)
	local data = Profiles.get(player)
	if not data or not remotes then return end
	-- FireClient serializa una copia: el cliente nunca recibe acceso mutable al perfil.
	remotes.EquipmentState:FireClient(player, data.Inventory, data.Equipment, message)
end
function Equipment.grant(player, id, rarity, announce)
	local data = Profiles.get(player)
	local def = Defs.ById[id]
	if not data or not def or not Rarities.index(rarity) then return nil end
	if #data.Inventory >= Defs.MaxInventory then
		Equipment.publish(player, "Inventario lleno: fusioná o reciclá piezas en el lobby para hacer espacio.")
		return nil
	end
	local item = { Uid = HttpService:GenerateGUID(false), Id = id, Rarity = rarity, Level = 1 }
	table.insert(data.Inventory, item)
	if announce ~= false then
		remotes.RewardNotice:FireClient(player, def.Name, rarity, "Equipo permanente")
	end
	Equipment.publish(player)
	return item
end
function Equipment.drop(player, guaranteed)
	if not guaranteed and math.random() >= 0.15 then return end
	local def = Defs.List[math.random(#Defs.List)]
	Equipment.grant(player, def.Id, Rarities.roll())
end
function Equipment.apply(player, stats)
	local data = Profiles.get(player)
	if not data then return end
	local bonus, sets = Defs.summary(data.Inventory, data.Equipment, Rarities.index)
	stats.damage *= 1 + bonus.damage
	stats.maxHealth *= 1 + bonus.maxHealth
	stats.walkSpeed *= 1 + bonus.walkSpeed
	stats.pickupRadius *= 1 + bonus.pickupRadius
	stats.critChance += bonus.critChance
	if (sets.Hunter or 0) >= 3 then stats.pickupRadius *= 1.1 end
	if (sets.Hunter or 0) >= 6 then stats.critChance += 0.03 end
	if (sets.Ember or 0) >= 3 then stats.burnBonus = 0.15 end
	if (sets.Ember or 0) >= 6 then stats.burn = true end
end
function Equipment.request(player, action, arg)
	local data = Profiles.get(player)
	if not data then return false, "El perfil sigue cargando." end
	if action == "Get" then Equipment.publish(player); return true end
	local state = PlayerData.get(player)
	if not state or state.inMatch or player:GetAttribute("Ready") or player:GetAttribute("InMatch") then
		return false, "Cancelá LISTO y volvé al lobby para cambiar tu equipo."
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.25 then return false, "Esperá un momento." end
	lastRequest[player] = now
	if action == "Unequip" and type(arg) == "string" and table.find(Defs.Slots, arg) then
		data.Equipment[arg] = nil
	elseif action == "Equip" and type(arg) == "string" then
		local item = find(data, arg)
		if not item then return false, "Ese objeto no pertenece a tu inventario." end
		data.Equipment[Defs.ById[item.Id].Slot] = item.Uid
	elseif action == "Upgrade" and type(arg) == "string" then
		local item = find(data, arg)
		if not item or item.Level >= Defs.MaxLevel then return false, "No se puede mejorar ese objeto." end
		local gold, stones = Defs.cost(item)
		if data.Currencies.Gold < gold or data.Currencies.Stones < stones then return false, "Faltan oro o piedras." end
		-- Sin yields entre validación, cobro y mejora: una única transacción del servidor.
		Profiles.addCurrency(player, "Gold", -gold)
		Profiles.addCurrency(player, "Stones", -stones)
		item.Level += 1
	elseif action == "Fuse" and type(arg) == "table" and #arg == 3 then
		local items, ids = {}, {}
		for key in arg do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 3 then return false, "Se requieren exactamente tres objetos." end
		end
		for index = 1, 3 do
			local uid = arg[index]
			if type(uid) ~= "string" or ids[uid] then return false, "Elegí tres objetos distintos." end
			ids[uid] = true
			local item = find(data, uid)
			if not item then return false, "No tenés los tres objetos." end
			table.insert(items, item)
		end
		local first = items[1]
		local rank = Rarities.index(first.Rarity)
		if rank >= #Rarities.Order then return false, "La rareza mítica es la máxima." end
		for _, item in items do
			if item.Id ~= first.Id or item.Rarity ~= first.Rarity then return false, "Deben ser del mismo tipo y rareza." end
		end
		-- Se conserva el nivel mayor y el UID del objeto principal, incluido su espacio equipado.
		for _, item in items do first.Level = math.max(first.Level, item.Level) end
		for slot, uid in data.Equipment do if ids[uid] then data.Equipment[slot] = first.Uid end end
		for i = #data.Inventory, 1, -1 do if ids[data.Inventory[i].Uid] and data.Inventory[i] ~= first then table.remove(data.Inventory, i) end end
		first.Rarity = Rarities.Order[rank + 1]
		remotes.RewardNotice:FireClient(player, Defs.ById[first.Id].Name, first.Rarity, "Fusión completada")
	elseif action == "Recycle" and type(arg) == "string" then
		local item, index = find(data, arg)
		if not item or not index then return false, "Ese objeto no pertenece a tu inventario." end
		if isEquipped(data, item.Uid) then return false, "Quitate el objeto antes de reciclarlo." end
		local gold, stones = Defs.recycleValue(item, Rarities.index(item.Rarity))
		table.remove(data.Inventory, index)
		Profiles.addCurrency(player, "Gold", gold)
		if stones > 0 then Profiles.addCurrency(player, "Stones", stones) end
		Equipment.publish(player, string.format("♻ Reciclado: +%d oro%s", gold, if stones > 0 then " y +" .. stones .. " piedras" else ""))
		Profiles.saveSoon(player)
		return true
	elseif action == "RecycleRarity" and type(arg) == "string" and table.find(Defs.BulkRecycle, arg) then
		local rank = Rarities.index(arg)
		local count, gold, stones = 0, 0, 0
		-- De atrás para adelante: table.remove no saltea elementos. Nunca toca lo equipado.
		for i = #data.Inventory, 1, -1 do
			local item = data.Inventory[i]
			if item.Rarity == arg and not isEquipped(data, item.Uid) then
				local g, st = Defs.recycleValue(item, rank)
				gold += g; stones += st; count += 1
				table.remove(data.Inventory, i)
			end
		end
		if count == 0 then return false, "No tenés piezas sin equipar de esa rareza." end
		Profiles.addCurrency(player, "Gold", gold)
		if stones > 0 then Profiles.addCurrency(player, "Stones", stones) end
		Equipment.publish(player, string.format("♻ %d piezas recicladas: +%d oro%s", count, gold, if stones > 0 then " y +" .. stones .. " piedras" else ""))
		Profiles.saveSoon(player)
		return true
	else return false, "Petición de equipo inválida." end
	Equipment.publish(player, "Equipo actualizado")
	Profiles.saveSoon(player)
	return true
end
function Equipment.init(r)
	remotes = r
	Profiles.onLoaded(function(player, data)
		if not data.EquipmentInitialized then
			for i = 1, 6 do
				local item = Equipment.grant(player, Defs.List[i].Id, "Common", false)
				if item then data.Equipment[Defs.List[i].Slot] = item.Uid end
			end
			data.EquipmentInitialized = true
		end
		Equipment.publish(player)
	end)
	r.EquipmentRequest.OnServerEvent:Connect(function(player, action, arg)
		if type(action) ~= "string" then return end
		if action == "Get" then
			local now = os.clock()
			if now - (lastRequest[player] or -math.huge) < 0.25 then return end
			lastRequest[player] = now
		end
		local ok, message = Equipment.request(player, action, arg)
		if not ok then Equipment.publish(player, message) end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)
end
return Equipment
