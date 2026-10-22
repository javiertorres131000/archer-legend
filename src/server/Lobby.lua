--!strict
-- Lobby (ModuleScript)
-- Ubicación: ServerScriptService > Server > Lobby
-- Construye la zona segura donde se aparece y se prepara la partida.
-- Está lejos de la arena (Config.Lobby.Center): nunca se ven entre sí.
-- Es solo escenario: acá nadie recibe daño porque PlayerLife solo daña a participantes.
--
-- Ciudadela: si en el place existe Workspace > Ciudadela (armada en Studio: murallas, portal,
-- mercado, vitrina, tablas de récords y el patio de las cajas), se usa esa y no se arma la plaza
-- de abajo. Su SpawnLocation se llama LobbySpawn. La vida de la ciudadela (NPCs, vitrina,
-- tablas y portal) está en LobbyWorld.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local LobbyCfg = Config.Lobby

local STONE = Color3.fromRGB(38, 36, 48)
local STONE_LIGHT = Color3.fromRGB(58, 54, 70)
local GOLD = Color3.fromRGB(212, 168, 70)
local BANNER = Color3.fromRGB(90, 30, 40)

local Lobby = {}

local spawnLocation: SpawnLocation? = nil

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Lobby armado en Studio (Workspace > Ciudadela), o nil
function Lobby.citadel(): Model?
	local m = workspace:FindFirstChild("Ciudadela")
	return if m and m:IsA("Model") then m else nil
end

function Lobby.build()
	local citadel = Lobby.citadel()
	if citadel then
		local spawn = citadel:FindFirstChild("LobbySpawn", true)
		if spawn and spawn:IsA("SpawnLocation") then
			spawnLocation = spawn
			return
		end
		warn("[Lobby] La Ciudadela no tiene LobbySpawn: se arma el lobby simple")
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	local c = LobbyCfg.Center
	local size = LobbyCfg.Size
	local half = size / 2

	-- Piso con un borde dorado
	part(folder, "Floor", size, CFrame.new(c - Vector3.new(0, size.Y / 2, 0)), STONE)
	local trim = 1.2
	for _, side in { -1, 1 } do
		part(folder, "TrimX", Vector3.new(size.X, 0.3, trim), CFrame.new(c + Vector3.new(0, 0.15, side * (half.Z - trim / 2))), GOLD, Enum.Material.Metal)
		part(folder, "TrimZ", Vector3.new(trim, 0.3, size.Z), CFrame.new(c + Vector3.new(side * (half.X - trim / 2), 0.15, 0)), GOLD, Enum.Material.Metal)
	end

	-- Muros bajos para no caerse del borde. El muro este tiene una puerta a la plaza de las
	-- cajas (CratePlaza) si está activada.
	local wallH = 4
	local crates = Config.Crates
	local door = if crates and crates.Enabled then crates.Plaza else nil
	for _, side in { -1, 1 } do
		part(folder, "Wall", Vector3.new(size.X + 2, wallH, 1), CFrame.new(c + Vector3.new(0, wallH / 2, side * (half.Z + 0.5))), STONE_LIGHT)
		local x = side * (half.X + 0.5)
		if side == 1 and door then
			-- Dos tramos, uno a cada lado de la puerta
			local z0, z1 = door.DoorZ - door.DoorWidth / 2, door.DoorZ + door.DoorWidth / 2
			for _, span in { { -half.Z, z0 }, { z1, half.Z } } do
				local len = span[2] - span[1]
				if len > 0 then
					part(folder, "Wall", Vector3.new(1, wallH, len), CFrame.new(c + Vector3.new(x, wallH / 2, (span[1] + span[2]) / 2)), STONE_LIGHT)
				end
			end
		else
			part(folder, "Wall", Vector3.new(1, wallH, size.Z), CFrame.new(c + Vector3.new(x, wallH / 2, 0)), STONE_LIGHT)
		end
	end

	-- Columnas con capitel dorado y estandartes
	local pillarH = 16
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local pos = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (math.min(half.X, half.Z) - 8)
		part(folder, "Pillar", Vector3.new(3, pillarH, 3), CFrame.new(pos + Vector3.new(0, pillarH / 2, 0)), STONE_LIGHT)
		part(folder, "PillarCap", Vector3.new(4, 1, 4), CFrame.new(pos + Vector3.new(0, pillarH + 0.5, 0)), GOLD, Enum.Material.Metal)
		local toCenter = (c - pos).Unit
		local banner = part(
			folder,
			"Banner",
			Vector3.new(2.4, 6, 0.2),
			CFrame.lookAt(pos + toCenter * 1.7 + Vector3.new(0, pillarH - 5, 0), pos + toCenter * 3 + Vector3.new(0, pillarH - 5, 0)),
			BANNER,
			Enum.Material.Fabric
		)
		banner.CanCollide = false
	end

	-- Estrado central con un portal dorado (por donde "se sale" a la partida)
	part(folder, "Dais", Vector3.new(18, 1, 18), CFrame.new(c + Vector3.new(0, 0.5, -20)), STONE_LIGHT)
	local ring = part(
		folder,
		"Portal",
		Vector3.new(1, 14, 14),
		CFrame.new(c + Vector3.new(0, 8, -24)) * CFrame.Angles(0, math.rad(90), 0),
		GOLD,
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.35
	ring.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 24
	light.Brightness = 2
	light.Parent = ring

	-- Punto de aparición (el único del juego)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(c + Vector3.new(0, 0.5, 10))
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = folder
	spawnLocation = spawn
end

-- Dónde aparece alguien que vuelve al lobby.
function Lobby.spawnCFrame(): CFrame
	return if spawnLocation then spawnLocation.CFrame + Vector3.new(0, 3, 0) else CFrame.new(LobbyCfg.Center + Vector3.new(0, 3, 0))
end

return Lobby
