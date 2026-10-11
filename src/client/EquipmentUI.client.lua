local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared:WaitForChild("EquipmentDefs"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Theme = require(Shared:WaitForChild("UITheme"))
local Visuals = require(script.Parent.RarityVisuals)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("EquipmentRequest")
local gui = Theme.make("ScreenGui", { Name = "EquipmentUI", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false, Parent = playerGui })
local backdrop = Theme.make("TextButton", { Size = UDim2.fromScale(1, 1), Text = "", Modal = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, AutoButtonColor = false, Parent = gui })
local window = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.86), Parent = backdrop })
Theme.make("UISizeConstraint", { MaxSize = Vector2.new(930, 700), Parent = window })
local title = Theme.text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -90, 0, 32), Text = "INVENTARIO Y EQUIPO", TextSize = 23, TextXAlignment = Enum.TextXAlignment.Left, Parent = window })
local close = Theme.button({ Position = UDim2.new(1, -54, 0, 8), Size = UDim2.fromOffset(40, 32), Text = "×", Parent = window })
close.Activated:Connect(function() gui.Enabled = false; playerGui:SetAttribute("EquipmentTab", nil) end)
local summary = Theme.text({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 80), TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = window })
local message = Theme.text({ Position = UDim2.fromOffset(16, 129), Size = UDim2.new(1, -330, 0, 42), TextSize = 14, TextWrapped = true, TextColor3 = Theme.Colors.GoldBright, Parent = window })
local list = Theme.make("ScrollingFrame", { Position = UDim2.fromOffset(12, 178), Size = UDim2.new(1, -24, 1, -190), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = window })
Theme.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
local inventory, equipped = {}, {}
local function send(action, arg) request:FireServer(action, arg) end
local function isEquipped(uid) for _, other in equipped do if other == uid then return true end end; return false end
-- Reciclar en lote (solo comunes y poco comunes, nunca lo equipado). Doble clic para confirmar.
local bulkButtons = {}
for i, rarity in Defs.BulkRecycle do
	local button = Theme.button({ Position = UDim2.new(1, -316 + (i - 1) * 154, 0, 134), Size = UDim2.fromOffset(148, 32), TextSize = 13, Parent = window })
	local confirmUntil = 0
	button.Activated:Connect(function()
		if not button.Active then return end
		if os.clock() < confirmUntil then confirmUntil = 0; send("RecycleRarity", rarity)
		else confirmUntil = os.clock() + 3; button.Text = "¿Seguro? Tocá de nuevo" end
	end)
	bulkButtons[rarity] = button
end
local function refresh()
	for _, child in list:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
	local byUid, sets = {}, {}
	for _, item in inventory do byUid[item.Uid] = item end
	local slots = {}
	for _, slot in Defs.Slots do
		local item = byUid[equipped[slot]]
		local def = item and Defs.ById[item.Id]
		table.insert(slots, Defs.SlotNames[slot] .. ": " .. (if def then def.Name else "Vacío"))
		if def then sets[def.Set] = (sets[def.Set] or 0) + 1 end
	end
	summary.Text = table.concat(slots, "  ·  ") .. "\nConjuntos: Cazador " .. (sets.Hunter or 0) .. "/6 · Brasas " .. (sets.Ember or 0) .. "/6\n3 Cazador: +10% imán; 6: +3% crítico. 3 Brasas: +15% quemadura; 6: flechas de fuego."
	for rarity, button in bulkButtons do
		local count, gold = 0, 0
		for _, item in inventory do
			if item.Rarity == rarity and not isEquipped(item.Uid) then count += 1; gold += (Defs.recycleValue(item, Rarities.index(rarity))) end
		end
		button.Text = "♻ " .. Rarities.Names[rarity] .. " (" .. count .. ")"
		button.Active = count > 0
		button.BackgroundColor3 = if count > 0 then Theme.Colors.Gold else Theme.Colors.Locked
	end
	title.Text = (playerGui:GetAttribute("EquipmentTab") or "Inventario"):upper() .. " · " .. #inventory .. "/" .. Defs.MaxInventory
	for index, item in inventory do
		local def = Defs.ById[item.Id]
		if not def then continue end
		local row = Theme.panel({ Size = UDim2.new(1, -8, 0, 118), LayoutOrder = index, Parent = list })
		local name = Theme.text({ Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -20, 0, 26), Text = def.Name .. " · " .. Rarities.Names[item.Rarity] .. " · Nv. " .. item.Level, TextSize = 16, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		Visuals.bind(name, item.Rarity)
		local gold, stones = Defs.cost(item)
		Theme.text({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 30), Text = Defs.SlotNames[def.Slot] .. " · Conjunto " .. (if def.Set == "Hunter" then "Cazador" else "Brasas") .. " · +" .. string.format("%.1f%%", def.Bonus * Defs.power(item, Rarities.index(item.Rarity)) * 100) .. " " .. ({ damage = "daño", maxHealth = "vida", critChance = "crítico", pickupRadius = "imán", walkSpeed = "velocidad" })[def.Stat], TextSize = 13, TextWrapped = true, Parent = row })
		local isEquipped = equipped[def.Slot] == item.Uid
		local equip = Theme.button({ Position = UDim2.new(0.02, 0, 0, 72), Size = UDim2.new(0.21, 0, 0, 32), Text = if isEquipped then "Quitar" else "Equipar", TextSize = 14, Parent = row })
		equip.Activated:Connect(function() send(if isEquipped then "Unequip" else "Equip", if isEquipped then def.Slot else item.Uid) end)
		local upgrade = Theme.button({ Position = UDim2.new(0.25, 0, 0, 72), Size = UDim2.new(0.27, 0, 0, 32), Text = if item.Level >= Defs.MaxLevel then "Nivel máximo" else "↑ " .. gold .. " oro + " .. stones .. " piedras", TextSize = 12, Parent = row })
		upgrade.Active = item.Level < Defs.MaxLevel
		upgrade.Activated:Connect(function() if upgrade.Active then send("Upgrade", item.Uid) end end)
		local candidates = { item.Uid }
		for _, other in inventory do
			if #candidates < 3 and other.Uid ~= item.Uid and other.Id == item.Id and other.Rarity == item.Rarity then table.insert(candidates, other.Uid) end
		end
		local fuse = Theme.button({ Position = UDim2.new(0.55, 0, 0, 72), Size = UDim2.new(0.2, 0, 0, 32), Text = "Fusionar " .. #candidates .. "/3", TextSize = 13, Parent = row })
		fuse.Active = #candidates == 3 and item.Rarity ~= "Mythic"
		local confirming = false
		fuse.Activated:Connect(function()
			if not fuse.Active then return end
			if not confirming then confirming = true; fuse.Text = "Confirmar fusión"
			else send("Fuse", candidates) end
		end)
		local recycleGold, recycleStones = Defs.recycleValue(item, Rarities.index(item.Rarity))
		local recycle = Theme.button({ Position = UDim2.new(0.78, 0, 0, 72), Size = UDim2.new(0.2, 0, 0, 32), TextSize = 12,
			Text = if isEquipped then "Equipado" else "♻ +" .. recycleGold .. " oro" .. (if recycleStones > 0 then " +" .. recycleStones .. "🔷" else ""), Parent = row })
		recycle.Active = not isEquipped
		if isEquipped then recycle.BackgroundColor3 = Theme.Colors.Locked end
		local recycleConfirm = false
		recycle.Activated:Connect(function()
			if not recycle.Active then return end
			if not recycleConfirm then recycleConfirm = true; recycle.Text = "¿Reciclar? Tocá de nuevo"
			else send("Recycle", item.Uid) end
		end)
	end
end
remotes:WaitForChild("EquipmentState").OnClientEvent:Connect(function(items, slots, notice)
	inventory, equipped = items, slots
	message.Text = notice or "Mejorá con oro y piedras. Fusioná 3 iguales (conserva el nivel mayor). Reciclá lo que sobra para recuperar oro y piedras."
	refresh()
end)
playerGui:GetAttributeChangedSignal("EquipmentTab"):Connect(function()
	gui.Enabled = playerGui:GetAttribute("EquipmentTab") ~= nil and player:GetAttribute("InMatch") ~= true
	if gui.Enabled then request:FireServer("Get"); refresh() end
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then gui.Enabled = false; playerGui:SetAttribute("EquipmentTab", nil) end
end)
