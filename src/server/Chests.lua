--!strict
-- Chests (ModuleScript)
-- Ubicación: ServerScriptService > Server > Chests
-- Cofres: aparecen durante la oleada cada Config.Frenzy.ChestEveryKills muertes del equipo.
-- Se abren pasando al lado (ChestOpenRadius). Qué dan lo decide quien llama a init (Run):
-- botín y objetos temporales para todos; ChestGivesSkill permite sumar además una oferta.
-- Al terminar la oleada, los cofres que quedan se abren solos.
-- Además, Chests.dropAt suelta uno en un lugar exacto (élites, horda y metas de equipo, ver
-- WaveEvents): no cuenta para MaxChests y tarda DropDelay en poder abrirse, así se ve caer.
--
-- El cofre es una Part del servidor en workspace.Chests (son pocos, se replica sola).
-- El brillo, el haz de luz y el cartel los agrega el cliente (Pickups.client.lua).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ground = require(script.Parent.Ground)
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarities"))

local Cfg = Config.Frenzy

type Chest = { part: Part, pos: Vector3, rarity: string, readyAt: number? }
export type Opener = { player: Player, root: BasePart }
export type OpenCallback = (pos: Vector3, opener: Player?, rarity: string) -> ()

local Chests = {}

local folder: Folder
local remote: RemoteEvent? = nil
local onOpen: OpenCallback = function() end
local half = Vector3.zero
local chests: { Chest } = {}
local kills = 0
local openedListeners: { (Vector3, Player?, string) -> () } = {}
local DROP_DELAY = 0.7

function Chests.init(openedRemote: RemoteEvent, arenaHalf: Vector3, callback: OpenCallback)
	remote = openedRemote
	half = arenaHalf
	onOpen = callback
	folder = Instance.new("Folder")
	folder.Name = "Chests"
	folder.Parent = workspace
end

local function makeChest(pos: Vector3, rarity: string, readyAt: number?)
	local part = Instance.new("Part")
	part.Name = "Chest"
	part.Size = Vector3.new(3.2, 2.4, 2.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.Wood
	part.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)) -- pos ya está en el piso
	part:SetAttribute("Rarity", rarity)
	part.Color = Rarities.Colors[rarity] or Color3.fromRGB(150, 90, 40)
	part.Parent = folder
	table.insert(chests, { part = part, pos = pos, rarity = rarity, readyAt = readyAt })
end

local function spawnChest(openers: { Opener })
	-- Cerca de algún jugador (el mapa es grande), dentro del mapa y apoyado en el piso
	local margin = Config.Arena.SpawnMargin
	local x, z
	if #openers > 0 then
		local around = openers[math.random(1, #openers)].root.Position
		local angle = math.random() * math.pi * 2
		local dist = 20 + math.random() * 30
		x = around.X + math.cos(angle) * dist
		z = around.Z + math.sin(angle) * dist
	else
		x = (math.random() * 2 - 1) * (half.X - margin)
		z = (math.random() * 2 - 1) * (half.Z - margin)
	end
	x = math.clamp(x, -half.X + margin, half.X - margin)
	z = math.clamp(z, -half.Z + margin, half.Z - margin)
	makeChest(Vector3.new(x, Ground.y(x, z), z), Rarities.roll())
end

-- Rareza al azar, pero nunca peor que `minimum`
function Chests.rollAtLeast(minimum: string?): string
	local rarity = Rarities.roll()
	local need = if minimum then Rarities.index(minimum) else nil
	if need and (Rarities.index(rarity) or 1) < need then
		rarity = minimum :: string
	end
	return rarity
end

-- Suelta un cofre en ese punto (dentro del mapa y apoyado en el piso). No cuenta para MaxChests.
function Chests.dropAt(at: Vector3, rarity: string)
	if not folder then
		return
	end
	local margin = Config.Arena.SpawnMargin
	local x = math.clamp(at.X, -half.X + margin, half.X - margin)
	local z = math.clamp(at.Z, -half.Z + margin, half.Z - margin)
	makeChest(Vector3.new(x, Ground.y(x, z), z), rarity, os.clock() + DROP_DELAY)
end

-- Avisa cada cofre abierto (metas de equipo: "abran N cofres")
function Chests.onOpened(callback: (Vector3, Player?, string) -> ())
	table.insert(openedListeners, callback)
end

-- Una muerte más del equipo (cuenta para el próximo cofre).
function Chests.onKill()
	kills += 1
end

local function open(index: number, opener: Player?)
	local chest = table.remove(chests, index) :: Chest
	chest.part:Destroy()
	local r = remote
	if r then
		r:FireAllClients(chest.pos, if opener then opener.UserId else 0, chest.rarity)
	end
	onOpen(chest.pos, opener, chest.rarity)
	for _, listener in openedListeners do
		listener(chest.pos, opener, chest.rarity)
	end
end

-- Cada frame durante la partida. canSpawn: solo aparecen mientras hay oleada.
function Chests.update(openers: { Opener }, canSpawn: boolean)
	if canSpawn and kills >= Cfg.ChestEveryKills and #chests < Cfg.MaxChests then
		kills = 0
		spawnChest(openers)
	end
	local now = os.clock()
	for i = #chests, 1, -1 do
		local chest = chests[i]
		if chest.readyAt and now < chest.readyAt then
			continue -- recién soltado: todavía no se abre
		end
		for _, o in openers do
			local p = o.root.Position
			local dx, dz = p.X - chest.pos.X, p.Z - chest.pos.Z
			if dx * dx + dz * dz <= Cfg.ChestOpenRadius * Cfg.ChestOpenRadius then
				open(i, o.player)
				break
			end
		end
	end
end

-- Fin de la oleada: se abren todos solos.
function Chests.openAll()
	for i = #chests, 1, -1 do
		open(i, nil)
	end
end

function Chests.count(): number
	return #chests
end

-- Dónde están los cofres cerrados (para las marcas de Ping)
function Chests.positions(): { Vector3 }
	local list = table.create(#chests)
	for _, c in chests do
		table.insert(list, c.pos)
	end
	return list
end

-- Fin de partida: se borran sin dar nada.
function Chests.clear()
	for _, c in chests do
		c.part:Destroy()
	end
	table.clear(chests)
	kills = 0
end

return Chests
