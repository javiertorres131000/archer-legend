--!strict
-- CrateEquip (ModuleScript)
-- Ubicación: ServerScriptService > Server > CrateEquip
-- Premios de las cajas equipados: un espacio "Pet" (mascota) y uno "Character" (personaje o
-- unidad). Se eligen en la pestaña Index del menú CRATES y se guardan en el perfil.
--   · Mascota: te sigue (la dibuja cada cliente, PetFollow) y da daño extra según su rareza
--     (Config.Crates.PetDamageBonus), sumado al arrancar cada partida como equipo y talentos.
--   · Personaje: cambia cómo se ve tu avatar para todos (colores de bloques con
--     HumanoidDescription, sin ropa ni accesorios de Roblox) y le suma sus accesorios (corona,
--     cuernos, alas...). Es solo aspecto. Al sacarlo vuelve tu avatar de siempre.
-- El cliente pide ("Equip", prizeId) o ("Unequip", espacio) por Remotes.CrateRequest; acá se
-- valida que lo tengas, que estés en el lobby y el límite de frecuencia.
-- Atributos del Player: EquippedPet y EquippedCharacter (Id del premio o "").
-- Armas especiales (Kind = "Weapon"): "Equip" las elige como arma (WeaponService.select) y
-- "Unequip" con el espacio "Weapon" vuelve a su arma común. Su atributo es EquippedWeapon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local CrateModels = require(Shared:WaitForChild("CrateModels"))
local CrateLooks = require(Shared:WaitForChild("CrateLooks"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Profiles = require(script.Parent.Profiles)
local PlayerData = require(script.Parent.PlayerData)
local WeaponService = require(script.Parent.WeaponService)

local Cfg = Config.Crates

local CrateEquip = {}

local lastChange: { [Player]: number } = {}
local originals: { [Player]: HumanoidDescription } = {}
local connections: { [Player]: RBXScriptConnection } = {}

-- Piezas del modelo de bloques que pasan al avatar, según dónde van pegadas
local HEAD_PARTS = { Eye = true, Helmet = true, Plume = true, Crown = true, Spike = true, Gem = true, Brim = true, Hat = true, Horn = true, HornTip = true, Halo = true }
local BODY_PARTS = { Cape = true, Wing = true, AuraCore = true }

local function fail(message: string): { [string]: any }
	return { Ok = false, Error = message }
end

function CrateEquip.publish(player: Player)
	local data = Profiles.get(player)
	local equipped: { [string]: string } = if data then data.Crates.Equipped else {}
	player:SetAttribute("EquippedPet", equipped.Pet or "")
	player:SetAttribute("EquippedCharacter", equipped.Character or "")
end

-- Daño extra de una mascota (0.06 = +6%)
function CrateEquip.petBonus(prizeId: string?): number
	local prize = prizeId and CrateItems.ById[prizeId]
	if not prize then
		return 0
	end
	return (Cfg.PetDamageBonus :: any)[prize.Rarity] or 0
end

-- Suma el bono de la mascota a las stats de la partida (lo llama Run al empezar)
function CrateEquip.apply(player: Player, stats: any)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local bonus = CrateEquip.petBonus(data.Crates.Equipped.Pet)
	if bonus > 0 then
		stats.damage *= 1 + bonus
	end
end

---------------------------------------------------------------------
-- Aspecto del avatar
---------------------------------------------------------------------

local function waitAppearance(player: Player)
	for _ = 1, 50 do
		local ok, loaded = pcall(function()
			return player:HasAppearanceLoaded()
		end)
		if not ok or loaded then
			return
		end
		task.wait(0.1)
	end
end

-- Pega al avatar las piezas de accesorios del modelo del premio (con soldaduras)
local function attachParts(character: Model, prizeId: string)
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not head or not torso then
		return
	end
	local model = CrateModels.prize(prizeId)
	local modelHead = model:FindFirstChild("Head") :: BasePart?
	local modelTorso = model:FindFirstChild("Torso") :: BasePart?
	if not modelHead or not modelTorso then
		model:Destroy()
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CrateLook"
	local headRatio = head.Size.X / modelHead.Size.X
	local torsoRatio = torso.Size.X / modelTorso.Size.X
	-- El centro del torso del modelo queda un poco más abajo que el UpperTorso de R15
	local torsoCenter = torso.CFrame * CFrame.new(0, -0.3, 0)
	local hasEyes = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (HEAD_PARTS[d.Name] or BODY_PARTS[d.Name]) then
			local onHead = HEAD_PARTS[d.Name] == true
			local from = if onHead then modelHead else modelTorso
			local ratio = if onHead then headRatio else torsoRatio
			local rel = from.CFrame:ToObjectSpace(d.CFrame)
			local target = if onHead then head.CFrame else torsoCenter
			d.Size *= ratio
			d.CFrame = target * (rel - rel.Position + rel.Position * ratio)
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = if onHead then head else torso
			weld.Part1 = d
			weld.Parent = d
			d.Parent = folder
			if d.Name == "Eye" then
				hasEyes = true
			end
		end
	end
	model:Destroy()
	if hasEyes then
		-- Los ojos del premio reemplazan la cara de Roblox
		for _, d in head:GetChildren() do
			if d:IsA("Decal") then
				d.Transparency = 1
			end
		end
	end
	folder.Parent = character
end

-- Arma la descripción de bloques con los colores del premio
local function blockyDescription(base: HumanoidDescription, look: CrateItems.Look): HumanoidDescription
	local desc = base:Clone()
	desc:SetAccessories({}, true)
	for _, prop in { "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory" } do
		(desc :: any)[prop] = ""
	end
	for _, prop in { "Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		(desc :: any)[prop] = 0
	end
	desc.HeightScale = 1
	desc.WidthScale = 1
	desc.DepthScale = 1
	desc.HeadScale = 1
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	local skin = look.Skin or Color3.fromRGB(255, 214, 170)
	local pants = look.Pants or look.Body:Lerp(Color3.new(0, 0, 0), 0.35)
	desc.HeadColor = skin
	desc.TorsoColor = look.Body
	desc.LeftArmColor = look.Body
	desc.RightArmColor = look.Body
	desc.LeftLegColor = pants
	desc.RightLegColor = pants
	return desc
end

-- Pone (o saca) el aspecto del personaje equipado en el avatar actual
function CrateEquip.refreshLook(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local data = Profiles.get(player)
	local id = if data then data.Crates.Equipped.Character else nil
	local current = character:GetAttribute("CrateLook")
	if current == id then
		return
	end
	local ok, err = pcall(function()
		-- El avatar original de este personaje (antes de cambiarlo nosotros)
		if not current then
			originals[player] = humanoid:GetAppliedDescription()
		end
		local old = character:FindFirstChild("CrateLook")
		if old then
			old:Destroy()
		end
		local original = originals[player]
		local prize = if id then CrateItems.ById[id] else nil
		-- Un traje detallado cambia el material de la piel: volver al de siempre
		if type(current) == "string" and CrateLooks.has(current) then
			for _, d in character:GetChildren() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					d.Material = Enum.Material.Plastic
				end
			end
		end
		if not id then
			if original then
				humanoid:ApplyDescriptionAsync(original)
			end
			character:SetAttribute("CrateLook", nil)
		elseif prize and original then
			humanoid:ApplyDescriptionAsync(blockyDescription(original, prize.Look))
			if CrateLooks.has(id) then
				CrateLooks.applyToCharacter(id, character) -- traje detallado (CrateLooks)
				local head = character:FindFirstChild("Head")
				if head then
					for _, d in head:GetChildren() do
						if d:IsA("Decal") then
							d.Transparency = 1 -- la cara la ponen las piezas del traje
						end
					end
				end
			else
				attachParts(character, id)
			end
			character:SetAttribute("CrateLook", id)
		end
	end)
	if not ok then
		warn("[CrateEquip] No se pudo cambiar el aspecto de " .. player.Name .. ":", err)
	end
end

---------------------------------------------------------------------
-- Pedidos
---------------------------------------------------------------------

local function canChange(player: Player): string?
	local now = os.clock()
	if now - (lastChange[player] or -math.huge) < Cfg.EquipCooldown then
		return "Esperá un momento."
	end
	local state = PlayerData.get(player)
	if not state or state.inMatch then
		return "Se equipa en el lobby."
	end
	lastChange[player] = now
	return nil
end

function CrateEquip.equip(player: Player, prizeId: any): { [string]: any }
	if type(prizeId) ~= "string" or #prizeId > 40 then
		return fail("Pedido inválido.")
	end
	local prize = CrateItems.ById[prizeId]
	if not prize then
		return fail("Ese premio no existe.")
	end
	local data = Profiles.get(player)
	if not data then
		return fail("Tu perfil todavía está cargando.")
	end
	if (data.Crates.Owned[prizeId] or 0) <= 0 then
		return fail("No tenés ese premio.")
	end
	local problem = canChange(player)
	if problem then
		return fail(problem)
	end
	if prize.Kind == "Weapon" then
		local ok, message = WeaponService.select(player, prize.Weapon)
		if not ok then
			return fail(message)
		end
		return { Ok = true, Equipped = table.clone(data.Crates.Equipped), Weapon = data.Weapon }
	end
	local slot = CrateItems.slotOf(prize)
	data.Crates.Equipped[slot] = prizeId
	CrateEquip.publish(player)
	Profiles.saveSoon(player)
	if slot == "Character" then
		task.spawn(CrateEquip.refreshLook, player)
	end
	return { Ok = true, Equipped = table.clone(data.Crates.Equipped) }
end

function CrateEquip.unequip(player: Player, slot: any): { [string]: any }
	if type(slot) ~= "string" or (slot ~= "Weapon" and not table.find(CrateItems.Slots, slot)) then
		return fail("Pedido inválido.")
	end
	local data = Profiles.get(player)
	if not data then
		return fail("Tu perfil todavía está cargando.")
	end
	local problem = canChange(player)
	if problem then
		return fail(problem)
	end
	if slot == "Weapon" then
		-- Sacar el arma especial: vuelve a la común de la que es variante
		local ok, message = WeaponService.select(player, Weapons.baseOf(data.Weapon))
		if not ok then
			return fail(message)
		end
		return { Ok = true, Equipped = table.clone(data.Crates.Equipped), Weapon = data.Weapon }
	end
	data.Crates.Equipped[slot] = nil
	CrateEquip.publish(player)
	Profiles.saveSoon(player)
	if slot == "Character" then
		task.spawn(CrateEquip.refreshLook, player)
	end
	return { Ok = true, Equipped = table.clone(data.Crates.Equipped) }
end

function CrateEquip.onProfileLoaded(player: Player, _data: Profiles.Data)
	CrateEquip.publish(player)
	task.spawn(function()
		waitAppearance(player)
		CrateEquip.refreshLook(player)
	end)
end

function CrateEquip.onPlayerAdded(player: Player)
	player:SetAttribute("EquippedPet", "")
	player:SetAttribute("EquippedCharacter", "")
	-- Cada vez que reaparece, el avatar viene con su aspecto de Roblox: volver a ponerle el premio
	connections[player] = player.CharacterAdded:Connect(function()
		task.spawn(function()
			waitAppearance(player)
			CrateEquip.refreshLook(player)
		end)
	end)
end

function CrateEquip.onPlayerRemoving(player: Player)
	local conn = connections[player]
	if conn then
		conn:Disconnect()
		connections[player] = nil
	end
	lastChange[player] = nil
	originals[player] = nil
end

return CrateEquip
