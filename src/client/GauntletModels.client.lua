-- GauntletModels (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > GauntletModels
-- Guanteletes especiales (armas con Base = "Fists" y modelo en ReplicatedStorage > WeaponModels
-- > <Id>) en las DOS manos de cada jugador, en tercera persona. Solo visual.
-- (HeldWeapon se encarga de las armas de una mano; la vista en primera persona es de WeaponFx.)
--
-- El modelo tiene que tener el pivote así: LookVector (-Z) = hacia donde apunta el puño,
-- UpVector (+Y) = el dorso de la mano. Atributo opcional "Length" (studs, por defecto 2.1):
-- largo del guantelete puesto (del puño hasta el medio del antebrazo).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weapons"))

local worn: { [Player]: { id: string, character: Model, models: { Model } } } = {}

local function clear(p: Player)
	local w = worn[p]
	if w then
		for _, m in w.models do
			m:Destroy()
		end
		worn[p] = nil
	end
end

local function limb(character: Model, side: string): BasePart?
	return (character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")) :: any
end

local function wear(template: Model, part: BasePart, side: string, length: number): Model
	local model = template:Clone()
	model.Name = "Guantelete" .. side
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0.01 then
		pcall(function()
			model:ScaleTo(model:GetScale() * length / longest)
		end)
	end
	-- Ejes: el puño hacia abajo de la mano/brazo, el dorso hacia afuera
	local up = part.CFrame.UpVector
	local look = -up
	local back = if side == "Right" then part.CFrame.RightVector else -part.CFrame.RightVector
	local isHand = part.Name:find("Hand") ~= nil
	local fistEnd = part.Position - up * (if isHand then part.Size.Y * 0.5 else part.Size.Y * 0.5)
	local center = fistEnd + up * (length / 2)
	local vZ = -look
	local vX = back:Cross(vZ)
	model:PivotTo(CFrame.fromMatrix(center, vX, back)) -- el izquierdo usa el mismo modelo con el dorso hacia su lado
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = part
			w.Part1 = d
			w.Parent = d
		end
	end
	model.Parent = part.Parent
	return model
end

local function refresh(p: Player)
	local id = p:GetAttribute("Weapon")
	local character = p.Character
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local template = if type(id) == "string" and folder then folder:FindFirstChild(id) else nil
	local ok = type(id) == "string" and Weapons.ById[id] ~= nil and Weapons.baseOf(id) == "Fists"
		and template ~= nil and template:IsA("Model") and character ~= nil
	local w = worn[p]
	if not ok then
		clear(p)
		return
	end
	if w and w.id == id and w.character == character and w.models[1].Parent then
		return
	end
	clear(p)
	local models = {}
	local length = ((template :: Model):GetAttribute("Length") :: number?) or 2.1
	for _, side in { "Right", "Left" } do
		local part = limb(character :: Model, side)
		if part then
			table.insert(models, wear(template :: Model, part, side, length))
		end
	end
	if #models > 0 then
		worn[p] = { id = id :: string, character = character :: Model, models = models }
	end
end

Players.PlayerRemoving:Connect(clear)
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local ok, err = pcall(refresh, p)
			if not ok then
				warn("[GauntletModels]", err)
			end
		end
		task.wait(0.5)
	end
end)
