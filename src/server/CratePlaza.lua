--!strict
-- CratePlaza (ModuleScript)
-- Ubicación: ServerScriptService > Server > CratePlaza
-- Construye la plaza volcánica de las cajas, pegada al muro este del lobby (hay una puerta):
--   · piso de roca con grietas de lava (CrackedLava + líneas de neón), charcos de lava y rocas
--   · muros de basalto alrededor y un arco de entrada con el cartel "CRATES"
--   · una plataforma hexagonal por caja (Shared/Crates.lua), con borde de neón de su color,
--     el cofre flotando encima, antorchas a los costados, un cartel (nombre y precio) y un
--     ProximityPrompt que abre el menú de cajas en el cliente (CrateUI). El prompt no compra
--     nada: comprar es un pedido aparte que valida CrateService.
-- La luz rojiza y la niebla las pone cada cliente al entrar (Atmosphere.client).
-- Dónde va cada cosa: Shared/CratePlazaLayout.lua. Solo escenario: nada acá tiene lógica.
-- Con la Ciudadela del lobby (Workspace > Ciudadela, armada en Studio) el piso, las murallas y el
-- arco ya están hechos (el patio del tesoro): acá se arman solo las plataformas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Crates = require(Shared:WaitForChild("Crates"))
local CrateModels = require(Shared:WaitForChild("CrateModels"))
local CrateItems = require(Shared:WaitForChild("CrateItems"))
local CratePlazaLayout = require(Shared:WaitForChild("CratePlazaLayout"))

local C = Color3.fromRGB
local part = CrateModels.part

local ROCK = C(42, 34, 32)
local ROCK_DARK = C(28, 22, 22)
local LAVA = C(225, 70, 12)

local CratePlaza = {}

local built: Folder? = nil

local function solid(p: Part): Part
	p.CanCollide = true
	p.CanQuery = true
	return p
end

local function lavaLight(parent: Instance, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = C(255, 110, 40)
	light.Range = range
	light.Brightness = brightness
	light.Parent = parent
end

-- Grieta de lava: una línea quebrada de barras de neón sobre el piso
local function crack(parent: Instance, rng: Random, start: Vector3, segments: number)
	local pos = start
	local angle = rng:NextNumber(0, math.pi * 2)
	for _ = 1, segments do
		angle += rng:NextNumber(-0.9, 0.9)
		local len = rng:NextNumber(2.5, 6)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local nextPos = pos + dir * len
		local mid = (pos + nextPos) / 2
		local width = rng:NextNumber(0.35, 0.8)
		local p = part(parent, "LavaCrack", Vector3.new(width, 0.08, len + width), CFrame.lookAt(mid, mid + dir), LAVA, Enum.Material.Neon)
		p.CastShadow = false
		pos = nextPos
	end
end

local function wallSegment(parent: Instance, rng: Random, from: Vector3, to: Vector3, thickness: number)
	local dir = to - from
	local len = dir.Magnitude
	local unit = dir.Unit
	local x = 0
	while x < len - 0.5 do
		local seg = math.min(rng:NextNumber(5, 9), len - x)
		local h = rng:NextNumber(6, 11)
		local mid = from + unit * (x + seg / 2)
		local cf = CFrame.lookAt(mid, mid + unit) * CFrame.new(0, h / 2 - 0.5, 0) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.06, 0.06))
		solid(part(parent, "Wall", Vector3.new(thickness + rng:NextNumber(0, 1.5), h, seg + 0.6), cf, if rng:NextNumber(0, 1) < 0.5 then ROCK else ROCK_DARK, Enum.Material.Basalt))
		-- Una veta de lava en algunas piedras
		if rng:NextNumber(0, 1) < 0.35 then
			local vein = part(parent, "Vein", Vector3.new(thickness + 1.7, 0.25, seg * 0.6), cf * CFrame.new(0, rng:NextNumber(-h / 4, h / 4), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0), LAVA, Enum.Material.Neon)
			vein.CastShadow = false
		end
		x += seg
	end
end

local function sign(parent: BasePart, offset: Vector3, size: UDim2, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = parent
	return gui
end

local function label(parent: Instance, text: string, color: Color3, pos: UDim2, size: UDim2, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextStrokeTransparency = 0.2
	l.TextStrokeColor3 = C(20, 8, 6)
	l.Parent = parent
	return l
end

local function station(parent: Instance, crate: Crates.Crate, top: CFrame, radius: number)
	local model = Instance.new("Model")
	model.Name = crate.Id
	model:SetAttribute("CrateId", crate.Id)
	local tier = CratePlazaLayout.PlatformHeight / 2
	local ground = top * CFrame.new(0, -CratePlazaLayout.PlatformHeight, 0)
	-- Dos escalones de basalto, cada uno con su borde de neón
	for _, p in CrateModels.hex(model, "Base", ground * CFrame.new(0, tier, 0), radius + 1.2, tier, ROCK_DARK, Enum.Material.Basalt, true) do
		p.Name = "Base"
	end
	local neonColor = crate.Color:Lerp(C(0, 0, 0), 0.25) -- un poco más oscuro: el neón no encandila
	CrateModels.hexRim(model, ground * CFrame.new(0, tier, 0), radius + 1.2, 0.35, 0.18, neonColor)
	CrateModels.hex(model, "Top", top, radius, tier, C(36, 30, 34), Enum.Material.Slate, true)
	CrateModels.hexRim(model, top, radius, 0.45, 0.22, neonColor)
	-- Círculo de luz en el centro
	local glow = part(model, "Glow", Vector3.new(0.1, radius * 1.1, radius * 1.1), top * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), crate.Color, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.Transparency = 0.88
	glow.CastShadow = false
	-- El cofre flotando (el cliente lo hace subir, bajar y girar)
	local chest = if Crates.isEgg(crate) then CrateModels.egg(crate) else CrateModels.crate(crate)
	chest.Name = "Display"
	if Crates.isEgg(crate) and (chest :: any).ScaleTo then
		chest:ScaleTo(1.4) -- los huevos son más chicos que los cofres
	end
	chest:SetAttribute("CrateDisplay", true)
	chest:PivotTo(top * CFrame.new(0, 1.1, 0))
	chest.Parent = model
	local light = Instance.new("PointLight")
	light.Color = crate.Color
	light.Range = 16
	light.Brightness = 2.2
	light.Parent = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
	-- Prompt y cartel (en una pieza invisible en el medio)
	local anchor = part(model, "PromptAnchor", Vector3.new(1, 1, 1), top * CFrame.new(0, 2.5, 0), crate.Color)
	anchor.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CratePrompt"
	prompt.ActionText = if Crates.isEgg(crate) then "Ver huevos" else "Ver cajas"
	prompt.ObjectText = crate.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = radius + 6
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("CrateId", crate.Id)
	prompt.Parent = anchor
	local billboard = sign(anchor, Vector3.new(0, 5.2, 0), UDim2.fromScale(11, 4.2), 90) -- en studs: se achica con la distancia
	label(billboard, CrateItems.upper(crate.Name), crate.Color, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.56), Enum.Font.GothamBlack)
	local robux = Crates.paysWithRobux(crate)
	local priceText = if robux then "R$ ..." else "💰 " .. Crates.formatPrice(crate.Price)
	local price = label(billboard, priceText, if robux then C(80, 230, 150) else C(255, 215, 90), UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.42), Enum.Font.GothamBold)
	price.Name = "Price"
	if robux then
		-- El precio en Robux está en el Developer Product (se cambia en el Creator Dashboard)
		task.spawn(function()
			if crate.ProductId <= 0 then
				price.Text = "R$ · Pronto"
				return
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(crate.ProductId, Enum.InfoType.Product)
			end)
			price.Text = if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then "R$ " .. Crates.formatPrice(info.PriceInRobux) else "R$"
		end)
	end
	model.Parent = parent
end

function CratePlaza.build(): Folder?
	if not Config.Crates.Enabled then
		return nil
	end
	if built then
		return built
	end
	local layout = CratePlazaLayout.get()
	local cfg = Config.Crates.Plaza
	local folder = Instance.new("Folder")
	folder.Name = "CratePlaza"
	local rng = Random.new(1337) -- la plaza es igual en todos los servidores
	local c = layout.Center
	local half = layout.Size / 2

	local citadel = workspace:FindFirstChild("Ciudadela") ~= nil
	if not citadel then
		-- Piso de roca con lava en las grietas
		local floor = solid(part(folder, "Floor", Vector3.new(layout.Size.X, 2, layout.Size.Z), CFrame.new(c - Vector3.new(0, 1, 0)), C(95, 70, 62), Enum.Material.CrackedLava))
		floor.CanTouch = true
		local decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = folder
		for _ = 1, 16 do
			local start = c + Vector3.new(rng:NextNumber(-half.X + 6, half.X - 20), 0.04, rng:NextNumber(-half.Z + 6, half.Z - 6))
			crack(decor, rng, start, rng:NextInteger(3, 6))
		end
		-- Charcos de lava
		for _, spot in { Vector3.new(4, 0, half.Z - 10), Vector3.new(-half.X + 14, 0, half.Z - 12), Vector3.new(half.X - 8, 0, half.Z - 6) } do
			local d = rng:NextNumber(7, 10)
			local pos = c + spot
			local rim = part(decor, "PoolRim", Vector3.new(0.4, d + 2, d + 2), CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), ROCK_DARK, Enum.Material.Basalt)
			rim.Shape = Enum.PartType.Cylinder
			local lava = part(decor, "Lava", Vector3.new(0.4, d, d), CFrame.new(pos + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90)), LAVA, Enum.Material.Neon)
			lava.Shape = Enum.PartType.Cylinder
			lava.CastShadow = false
			lavaLight(lava, 22, 2.2)
			CrateModels.embers(lava, C(255, 170, 60), 6, 30)
		end
		-- Rocas sueltas cerca de los muros
		for _ = 1, 14 do
			local onX = rng:NextNumber(0, 1) < 0.5
			local x = if onX then rng:NextNumber(-half.X + 4, half.X - 4) else (if rng:NextNumber(0, 1) < 0.5 then -1 else 1) * (half.X - 4)
			local z = if onX then (if rng:NextNumber(0, 1) < 0.5 then -1 else 1) * (half.Z - 4) else rng:NextNumber(-half.Z + 4, half.Z - 4)
			local s = rng:NextNumber(1.8, 4.5)
			solid(part(decor, "Rock", Vector3.new(s, s * rng:NextNumber(0.6, 1.1), s * rng:NextNumber(0.8, 1.3)), CFrame.new(c + Vector3.new(x, s * 0.3, z)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), ROCK, Enum.Material.Basalt))
		end

		-- Muros (con la puerta del lado del lobby)
		local walls = Instance.new("Folder")
		walls.Name = "Walls"
		walls.Parent = folder
		local x0, x1 = c.X - half.X, c.X + half.X
		local z0, z1 = c.Z - half.Z, c.Z + half.Z
		local t = 3
		wallSegment(walls, rng, Vector3.new(x0, 0, z0 - t / 2), Vector3.new(x1 + t, 0, z0 - t / 2), t)
		wallSegment(walls, rng, Vector3.new(x0, 0, z1 + t / 2), Vector3.new(x1 + t, 0, z1 + t / 2), t)
		wallSegment(walls, rng, Vector3.new(x1 + t / 2, 0, z0), Vector3.new(x1 + t / 2, 0, z1), t)
		local doorHalf = layout.DoorWidth / 2
		local wx = x0 + t / 2
		wallSegment(walls, rng, Vector3.new(wx, 0, z0), Vector3.new(wx, 0, c.Z - doorHalf), t)
		wallSegment(walls, rng, Vector3.new(wx, 0, c.Z + doorHalf), Vector3.new(wx, 0, z1), t)

		-- Arco de entrada con el cartel
		local archH = 12
		for _, side in { -1, 1 } do
			solid(part(folder, "ArchPillar", Vector3.new(3.5, archH, 3.5), CFrame.new(Vector3.new(wx, archH / 2, c.Z + side * (doorHalf + 1.5))), ROCK_DARK, Enum.Material.Basalt))
			local brazier = CrateModels.torch(folder, CFrame.new(Vector3.new(wx, archH + 2.4, c.Z + side * (doorHalf + 1.5))), 0.4)
			brazier.model.Name = "ArchFire"
		end
		local lintel = solid(part(folder, "ArchTop", Vector3.new(4, 2.4, layout.DoorWidth + 7), CFrame.new(Vector3.new(wx, archH + 1.2, c.Z)), ROCK, Enum.Material.Basalt))
		part(folder, "ArchLava", Vector3.new(4.2, 0.3, layout.DoorWidth + 5), CFrame.new(Vector3.new(wx, archH + 0.4, c.Z)), LAVA, Enum.Material.Neon).CastShadow = false
		local archSign = sign(lintel, Vector3.new(0, 4.5, 0), UDim2.fromScale(20, 5), 160)
		label(archSign, "🔥 CRATES 🔥", C(255, 150, 60), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Enum.Font.GothamBlack)

	end

	-- Plataformas
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = folder
	for i, s in layout.Stations do
		station(stations, Crates.ById[s.Id], s.Top, cfg.StationRadius)
		-- Antorchas a los costados (una entre cada par de plataformas de la fila y en las puntas)
		local ground = s.Top * CFrame.new(0, -CratePlazaLayout.PlatformHeight, 0)
		local look = s.Top.LookVector
		local along = Vector3.new(look.Z, 0, -look.X) -- dirección de la fila
		local back = ground.Position - Vector3.new(look.X, 0, look.Z) * 2
		local gap = cfg.StationSpacing / 2
		local prev = layout.Stations[i - 1]
		if not prev or prev.Type ~= s.Type then
			CrateModels.torch(stations, CFrame.new(back - along * gap), 7)
		end
		CrateModels.torch(stations, CFrame.new(back + along * gap), 7)
	end

	folder.Parent = workspace
	built = folder
	return folder
end

return CratePlaza
