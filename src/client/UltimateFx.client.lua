-- UltimateFx (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > UltimateFx
-- Definitivas de las armas especiales (Shared/Weapons.lua › Ultimate; el daño es de
-- Server/UltimateService). Estilo anime:
--   · Medidor arriba de la barra de vida (atributo UltCharge). Lleno: Q / botón Y / botón en
--     pantalla para lanzarla.
--   · UltimateMotion anima preparación, lanzamiento e impacto, con cámara estable que
--     muestra al personaje y el blanco. Conserva colores y evita destellos que tapen la acción.
--   · Todos ven en el mundo: estallido de aura, grietas que se abren, rocas que vuelan, tajos en
--     media luna que giran, remolino de espirales, luna de sangre, columna de energía con cristales
--     y onda expansiva.
-- Texturas: Config.Ultimate.Textures (assets/vfx/ultimate). Vacías = respaldo de Roblox.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local GalaxyOrbFx = require(script.Parent:WaitForChild("GalaxyOrbFx"))
local UltimateMotion = require(script.Parent:WaitForChild("UltimateMotion"))
local ElementalUltimateFx = require(script.Parent:WaitForChild("ElementalUltimateFx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRemote = remotes:WaitForChild("UltimateRequest") :: RemoteEvent
local fxRemote = remotes:WaitForChild("UltimateFx") :: RemoteEvent

local player = Players.LocalPlayer
local low = FxQuality.isLow()
local UCfg = (Config :: any).Ultimate or {}
local TEX = UCfg.Textures or {}
local FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function tex(name: string): string
	local id = TEX[name]
	return if type(id) == "string" and id ~= "" then id else FALLBACK
end

local function ultOf(id: any): any
	local def = if type(id) == "string" then Weapons.ById[id] else nil
	return def and def.Ultimate
end

---------------------------------------------------------------------
-- Medidor y botón
---------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Ultimate"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9
gui.Parent = player:WaitForChild("PlayerGui")

local meter = Instance.new("Frame")
meter.AnchorPoint = Vector2.new(0.5, 1)
meter.Position = UDim2.new(0.5, 0, 1, -40)
meter.Size = UDim2.fromOffset(300, 12)
meter.BackgroundColor3 = Color3.fromRGB(15, 10, 14)
meter.BackgroundTransparency = 0.25
meter.Visible = false
meter.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = meter
end
local fill = Instance.new("Frame")
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = meter
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = fill
end
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 0, -2)
label.Size = UDim2.fromOffset(300, 18)
label.Font = Enum.Font.GothamBlack
label.TextSize = 14
label.TextStrokeTransparency = 0.3
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = meter

local function canUse(): boolean
	local u = ultOf(player:GetAttribute("Weapon"))
	return u ~= nil and player:GetAttribute("InMatch") == true and ((player:GetAttribute("UltCharge") :: number?) or 0) >= 1
		and player:GetAttribute("Cinematic") ~= true
end

local aiming = false
local aimWeapon: any = nil
local aimPoint: Vector3? = nil
local marker: Part? = nil
local function stopAiming()
	aiming = false
	aimPoint = nil
	player:SetAttribute("UltimateAiming", false)
	if marker then marker:Destroy(); marker = nil end
	ContextActionService:UnbindAction("UltimateConfirm")
	ContextActionService:UnbindAction("UltimateCancel")
end
local function confirmAim()
	local point = aimPoint
	local valid = canUse() and player:GetAttribute("Weapon") == aimWeapon
	stopAiming()
	if valid and point then requestRemote:FireServer(point) end
end
RunService.RenderStepped:Connect(function()
	if not aiming then return end
	if not canUse() or player:GetAttribute("Weapon") ~= aimWeapon then stopAiming(); return end
	local cam = Workspace.CurrentCamera
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not root or not marker then return end
	local u = ultOf(aimWeapon)
	local range = u.TargetRange
	local screen = cam.ViewportSize / 2
	local ray = cam:ViewportPointToRay(screen.X, screen.Y)
	if Config.Camera.Mode == "TopDown" and UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local candidate = if hit then hit.Position else root.Position + ray.Direction * range
	local offset = Vector3.new(candidate.X - root.Position.X, 0, candidate.Z - root.Position.Z)
	if offset.Magnitude > range then offset = offset.Unit * range end
	local above = root.Position + offset + Vector3.new(0, 100, 0)
	local floorHit = Workspace:Raycast(above, Vector3.new(0, -250, 0), params)
	aimPoint = if floorHit then floorHit.Position else nil
	local surface = marker:FindFirstChildOfClass("SurfaceGui")
	if surface then surface.Enabled = aimPoint ~= nil end
	if aimPoint then
		if u.Line then
			local from = Vector3.new(root.Position.X, aimPoint.Y + 0.4, root.Position.Z)
			local delta = Vector3.new(aimPoint.X - from.X, 0, aimPoint.Z - from.Z)
			local direction = if delta.Magnitude > 0.01 then delta.Unit else Vector3.new(0, 0, -1)
			marker.CFrame = CFrame.lookAt(from + direction * u.Line.Length / 2, from + direction * (u.Line.Length / 2 + 1))
		else
			marker.Position = aimPoint + Vector3.new(0, 0.4, 0)
		end
	end
end)
local function onAction(_, state)
	if state == Enum.UserInputState.Begin and canUse() then
		if aiming then
			confirmAim()
		elseif ultOf(player:GetAttribute("Weapon")).TargetRange then
			aiming = true
			aimWeapon = player:GetAttribute("Weapon")
			player:SetAttribute("UltimateAiming", true)
			local p = Instance.new("Part")
			p.Name = "UltimateTarget"
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = ultOf(aimWeapon).Color
			local diameter = ultOf(aimWeapon).Radius * 2
			p.Size = Vector3.new(diameter, 0.05, diameter)
			local line = ultOf(aimWeapon).Line
			if line then p.Size = Vector3.new(line.Width * 2, 0.05, line.Length) end
			p.Transparency = 1
			p.Parent = Workspace
			local surface = Instance.new("SurfaceGui")
			surface.Face = Enum.NormalId.Top
			surface.CanvasSize = Vector2.new(512, 512)
			surface.LightInfluence = 0
			surface.Enabled = false
			surface.Parent = p
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = tex("Anillo")
			if line then
				image.Image = ""
				image.BackgroundTransparency = 0.45
				image.BackgroundColor3 = p.Color
			end
			image.ImageColor3 = p.Color
			image.Parent = surface
			marker = p
			ContextActionService:BindActionAtPriority("UltimateConfirm", function(_, inputState)
				if inputState == Enum.UserInputState.Begin then confirmAim() end
				return Enum.ContextActionResult.Sink
			end, false, 3000, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
			ContextActionService:BindAction("UltimateCancel", function(_, inputState)
				if inputState == Enum.UserInputState.Begin then stopAiming() end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
		else
			requestRemote:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("Ultimate", onAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Ultimate", "ULTI")
ContextActionService:SetPosition("Ultimate", UDim2.fromScale(0.6, 0.5))

RunService.RenderStepped:Connect(function()
	local u = ultOf(player:GetAttribute("Weapon"))
	local show = u ~= nil and player:GetAttribute("InMatch") == true and player:GetAttribute("Cinematic") ~= true
	meter.Visible = show
	local button = ContextActionService:GetButton("Ultimate")
	if button then
		button.Visible = show and canUse()
	end
	if not show then
		return
	end
	local c = (player:GetAttribute("UltCharge") :: number?) or 0
	if aiming then
		label.Text = "APUNTÁ · Q / CLIC: LANZAR · X: CANCELAR"
		return
	end
	fill.Size = UDim2.fromScale(math.clamp(c, 0, 1), 1)
	fill.BackgroundColor3 = u.Color
	if c >= 1 then
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
		fill.BackgroundColor3 = u.Color:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
		label.Text = string.format("%s  ·  ¡LISTA!  [Q]", string.upper(u.Name))
	else
		label.Text = string.format("%s  %d%%", string.upper(u.Name), math.floor(c * 100))
	end
end)

---------------------------------------------------------------------
-- Piezas de efectos
---------------------------------------------------------------------

local fxFolder = Instance.new("Folder")
fxFolder.Name = "UltimateFx"
fxFolder.Parent = Workspace

local function anchoredPart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

-- "Carta": plano con una textura que brilla (SurfaceGui arriba y abajo)
local function card(texture: string, size: number, cf: CFrame, color: Color3, brightness: number): (Part, { ImageLabel })
	local p = anchoredPart("Carta", Vector3.new(size, 0.05, size), cf)
	local images = {}
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.LightInfluence = 0
		sg.Brightness = brightness
		sg.CanvasSize = Vector2.new(256, 256)
		sg.Parent = p
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = texture
		img.ImageColor3 = color
		img.Parent = sg
		table.insert(images, img)
	end
	return p, images
end

local function fadeImages(images: { ImageLabel }, t: number)
	for _, img in images do
		TweenService:Create(img, TweenInfo.new(t), { ImageTransparency = 1 }):Play()
	end
end

-- Anima algo cuadro a cuadro durante `dur` segundos: fn(k de 0 a 1)
local function animate(dur: number, fn: (number) -> ())
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		fn(k)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
end

local function burst(pos: Vector3, color: Color3, count: number, speed: number, size: number)
	local p = anchoredPart("Estallido", Vector3.one, CFrame.new(pos))
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex("Destello")
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Rate = 0
	e.Parent = p
	e:Emit(if low then math.ceil(count / 3) else count)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Color = ColorSequence.new(Color3.fromRGB(20, 5, 8))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Speed = NumberRange.new(speed * 0.2, speed * 0.4)
	smoke.SpreadAngle = Vector2.new(180, 30)
	smoke.Rate = 0
	smoke.Parent = p
	smoke:Emit(if low then 3 else 10)
	Debris:AddItem(p, 2)
end

local function ground(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else pos - Vector3.new(0, 3, 0)
end

---------------------------------------------------------------------
-- Secuencia en el mundo (la ven todos)
---------------------------------------------------------------------

-- Estilo "línea" (Ultimate.Line): carga una flecha gigante y dispara un láser en línea recta
local function lineSequence(u: any, origin: Vector3, dir: Vector3, at: (number, () -> ()) -> ())
	local color: Color3 = u.Color
	local L = u.Line.Length
	local W = u.Line.Width
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	local f = if flatDir.Magnitude > 0.01 then flatDir.Unit else Vector3.new(0, 0, -1)
	local chest = origin + Vector3.new(0, 1.5, 0)
	local floor = ground(origin)
	local finalAt = u.FinalAt or (u.Duration - 0.6)
	local aim = CFrame.lookAt(chest, chest + f)
	local floorAim = CFrame.lookAt(floor + Vector3.new(0, 0.15, 0), floor + Vector3.new(0, 0.15, 0) + f)

	-- Mira en el piso: la franja que va a barrer el disparo
	at(0, function()
		burst(chest, color, 30, 20, 1.2)
		local strip = anchoredPart("Mira", Vector3.new(W * 2, 0.1, L), floorAim * CFrame.new(0, 0, -L / 2))
		strip.Material = Enum.Material.Neon
		strip.Color = color
		animate(finalAt, function(k)
			strip.Transparency = 0.85 - 0.25 * k + (if math.sin(k * 40) > 0 then 0 else 0.08)
		end)
		task.delay(finalAt + 0.1, function()
			strip:Destroy()
		end)
	end)

	-- Carga: la luz se junta delante del arco, con una espiral de frente que gira
	at(0.2, function()
		local gather = anchoredPart("Carga", Vector3.new(14, 14, 14), aim * CFrame.new(0, 0, -2))
		local inward = Instance.new("ParticleEmitter")
		inward.Shape = Enum.ParticleEmitterShape.Sphere
		inward.Texture = tex("Destello")
		inward.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		inward.LightEmission = 1
		inward.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		inward.Lifetime = NumberRange.new(0.4, 0.6)
		inward.Speed = NumberRange.new(-24, -14)
		inward.Rate = if low then 40 else 150
		inward.Parent = gather
		Debris:AddItem(gather, finalAt - 0.2)
		local sp, imgs = card(tex("Espiral"), 6, aim * CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), 0, 0), color, 4)
		animate(finalAt - 0.2, function(k)
			local s = 6 + 6 * k
			sp.Size = Vector3.new(s, 0.05, s)
			sp.CFrame = aim * CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), k * 16, 0)
		end)
		task.delay(finalAt - 0.2, function()
			fadeImages(imgs, 0.15)
			Debris:AddItem(sp, 0.2)
		end)
	end)

	-- Flecha gigante de luz que se tensa y tiembla, con anillos de carga que corren por ella
	at(u.FirstAt or 0.5, function()
		local arrow = Instance.new("Model")
		arrow.Name = "FlechaGigante"
		local function neonPart(size: Vector3, cf: CFrame, c: Color3): Part
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = c
			p.Size = size
			p.CFrame = cf
			p.Parent = arrow
			return p
		end
		local shaft = neonPart(Vector3.new(0.6, 0.6, 12), aim * CFrame.new(0, 0, -3), Color3.new(1, 1, 1))
		neonPart(Vector3.new(1.6, 1.6, 3), aim * CFrame.new(0, 0, -10) * CFrame.Angles(0, 0, math.rad(45)), color)
		for i = 0, 2 do
			neonPart(Vector3.new(0.15, 2.2, 2.4), aim * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, 0, math.rad(i * 60)), color)
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 5
		light.Parent = shaft
		arrow.Parent = fxFolder
		local base = arrow:GetPivot()
		local charge = finalAt - (u.FirstAt or 0.5)
		animate(charge, function(k)
			local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.25 * k
			arrow:PivotTo(base * CFrame.new(jitter + Vector3.new(0, 0, 2 * k)))
		end)
		for i = 1, 4 do
			task.delay(i * 0.35, function()
				local ring, rimgs = card(tex("Anillo"), 7, aim * CFrame.new(0, 0, -10) * CFrame.Angles(math.rad(90), 0, 0), color, 4)
				animate(0.35, function(k)
					ring.CFrame = aim * CFrame.new(0, 0, -10 + 12 * k) * CFrame.Angles(math.rad(90), 0, 0)
					local s = 7 - 4 * k
					ring.Size = Vector3.new(s, 0.05, s)
				end)
				task.delay(0.3, function()
					fadeImages(rimgs, 0.1)
				end)
				Debris:AddItem(ring, 0.45)
			end)
		end
		task.delay(charge, function()
			arrow:Destroy()
		end)
	end)

	-- ¡Disparo! Láser en línea recta que atraviesa todo
	at(finalAt, function()
		burst(chest, color, 60, 50, 2)
		-- Polvo del retroceso: una estela en el piso hacia atrás
		local dustAt = anchoredPart("PolvoRetroceso", Vector3.new(3, 0.5, 4), floorAim * CFrame.new(0, 0.3, 2.5))
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = SMOKE
		dust.Color = ColorSequence.new(Color3.fromRGB(200, 185, 150))
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
		dust.Lifetime = NumberRange.new(0.6, 1)
		dust.Speed = NumberRange.new(4, 9)
		dust.SpreadAngle = Vector2.new(40, 15)
		dust.EmissionDirection = Enum.NormalId.Back
		dust.Rate = 0
		dust.Parent = dustAt
		dust:Emit(if low then 6 else 20)
		Debris:AddItem(dustAt, 1.2)
		local holder = anchoredPart("Laser", Vector3.one, aim)
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0, -L)
		a1.Parent = holder
		for k = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Texture = tex("Energia")
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 20
			beam.TextureSpeed = -12 * k
			beam.Segments = 2
			beam.Color = ColorSequence.new(if k == 1 then color else Color3.new(1, 1, 1))
			local w0 = if k == 1 then W * 2.2 else W * 0.9
			beam.Width0 = w0
			beam.Width1 = w0 * 0.8
			beam.Parent = holder
			animate(0.9, function(kk)
				local s = if kk < 0.15 then kk / 0.15 else 1 - (kk - 0.15) / 0.85
				beam.Width0 = w0 * s
				beam.Width1 = w0 * 0.8 * s
			end)
		end
		Debris:AddItem(holder, 1)
		for i = 1, 6 do
			local p = chest + f * (L * i / 7)
			task.delay(i * 0.03, function()
				local ring, rimgs = card(tex("Anillo"), W * 2, CFrame.lookAt(p, p + f) * CFrame.Angles(math.rad(90), 0, 0), color, 5)
				animate(0.4, function(k)
					local s = W * (2 + 3 * k)
					ring.Size = Vector3.new(s, 0.05, s)
				end)
				task.delay(0.2, function()
					fadeImages(rimgs, 0.2)
				end)
				Debris:AddItem(ring, 0.45)
			end)
		end
		-- Surco quemado en el piso
		local scar = anchoredPart("Surco", Vector3.new(W * 1.4, 0.1, L), floorAim * CFrame.new(0, 0, -L / 2))
		scar.Transparency = 0
		scar.Material = Enum.Material.Neon
		scar.Color = color
		TweenService:Create(scar, TweenInfo.new(1.2), { Transparency = 1, Color = Color3.fromRGB(60, 40, 20) }):Play()
		Debris:AddItem(scar, 1.3)
		-- Estallido en cada enemigo que agarra el rayo
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			local n = 0
			for _, e in enemies:GetChildren() do
				if n < 20 and e:IsA("BasePart") then
					local rel = e.Position - chest
					local along = rel:Dot(f)
					local off = (Vector3.new(rel.X, 0, rel.Z) - f * along).Magnitude
					if along >= 0 and along <= L and off <= W + 2 then
						n += 1
						burst(e.Position, color, 14, 25, 0.9)
					end
				end
			end
		end
	end)
end

-- Iaido (Carmesí): camino en zigzag por los enemigos de la zona (los más cercanos, uno tras otro)
local HOP = 0.14 -- segundos por salto
local function iaidoPath(origin: Vector3, radius: number, dir: Vector3): { Vector3 }
	local list = {}
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		for _, e in enemies:GetChildren() do
			if e:IsA("BasePart") and (e.Position - origin).Magnitude <= radius then
				table.insert(list, e.Position)
			end
		end
	end
	local path = {}
	local from = origin
	while #path < 6 and #list > 0 do
		local bi, bd = 1, math.huge
		for i, p in list do
			local d = (p - from).Magnitude
			if d < bd then
				bi, bd = i, d
			end
		end
		local p = table.remove(list, bi)
		table.insert(path, Vector3.new(p.X, origin.Y, p.Z))
		from = p
	end
	-- Pocos enemigos: completa con un zigzag hacia adelante
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local f = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local side = f:Cross(Vector3.yAxis)
	local k = 1
	while #path < 4 do
		table.insert(path, origin + f * (radius * 0.25 * k) + side * (if k % 2 == 0 then -1 else 1) * radius * 0.3)
		k += 1
	end
	return path
end

-- Poses simples del personaje (R15) moviendo las articulaciones; nil = vuelve a la normal
local POSES = {
	crouch = { Root = CFrame.new(0, -0.8, 0) * CFrame.Angles(math.rad(-12), 0, 0), Waist = CFrame.Angles(math.rad(-22), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(-35), 0, math.rad(-35)), LeftShoulder = CFrame.Angles(math.rad(-20), 0, math.rad(25)) },
	dash = { Root = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-25), 0, 0), Waist = CFrame.Angles(math.rad(-20), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(10), 0, math.rad(80)), LeftShoulder = CFrame.Angles(math.rad(10), 0, math.rad(-60)) },
	raise = { Waist = CFrame.Angles(math.rad(12), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(165), 0, math.rad(-10)), LeftShoulder = CFrame.Angles(math.rad(165), 0, math.rad(10)) },
	plunge = { Root = CFrame.new(0, 0.3, 0), Waist = CFrame.Angles(math.rad(-30), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(-30), 0, math.rad(-15)), LeftShoulder = CFrame.Angles(math.rad(-30), 0, math.rad(15)) },
	land = { Root = CFrame.new(0, -1.1, 0) * CFrame.Angles(math.rad(-18), 0, 0), Waist = CFrame.Angles(math.rad(-25), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(-75), 0, math.rad(-10)), LeftShoulder = CFrame.Angles(math.rad(-75), 0, math.rad(10)) },
	draw = { Root = CFrame.Angles(math.rad(6), 0, 0), Waist = CFrame.Angles(0, math.rad(-35), 0), Neck = CFrame.Angles(0, math.rad(30), 0),
		LeftShoulder = CFrame.Angles(math.rad(90), math.rad(-10), 0), LeftElbow = CFrame.new(),
		RightShoulder = CFrame.Angles(math.rad(85), 0, math.rad(-25)), RightElbow = CFrame.Angles(math.rad(120), 0, 0) },
	recoil = { Root = CFrame.Angles(math.rad(22), 0, 0), Waist = CFrame.Angles(math.rad(12), math.rad(-30), 0), Neck = CFrame.Angles(math.rad(-10), math.rad(25), 0),
		LeftShoulder = CFrame.Angles(math.rad(120), 0, math.rad(15)), LeftElbow = CFrame.new(),
		RightShoulder = CFrame.Angles(math.rad(30), 0, math.rad(45)), RightElbow = CFrame.Angles(math.rad(15), 0, 0) },
	aimSky = { Root = CFrame.Angles(math.rad(10), 0, 0), Waist = CFrame.Angles(math.rad(15), math.rad(-30), 0), Neck = CFrame.Angles(math.rad(25), math.rad(25), 0),
		LeftShoulder = CFrame.Angles(math.rad(150), 0, 0), LeftElbow = CFrame.new(),
		RightShoulder = CFrame.Angles(math.rad(140), 0, math.rad(-20)), RightElbow = CFrame.Angles(math.rad(100), 0, 0) },
	hold = { Root = CFrame.Angles(math.rad(-8), 0, 0), Waist = CFrame.Angles(math.rad(-10), math.rad(-20), 0), Neck = CFrame.Angles(0, math.rad(15), 0),
		LeftShoulder = CFrame.Angles(math.rad(95), 0, 0), LeftElbow = CFrame.new(),
		RightShoulder = CFrame.Angles(math.rad(20), 0, math.rad(30)), RightElbow = CFrame.Angles(math.rad(40), 0, 0) },
	clench = { Root = CFrame.Angles(math.rad(5), 0, 0), Waist = CFrame.Angles(math.rad(5), math.rad(-25), 0),
		LeftShoulder = CFrame.Angles(math.rad(60), 0, math.rad(10)), LeftElbow = CFrame.Angles(math.rad(110), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(15), 0, math.rad(30)), RightElbow = CFrame.Angles(math.rad(30), 0, 0) },
	sheath = { Root = CFrame.new(0, -0.3, 0), Waist = CFrame.Angles(math.rad(-6), math.rad(15), 0),
		RightShoulder = CFrame.Angles(math.rad(-50), 0, math.rad(-45)), LeftShoulder = CFrame.Angles(math.rad(-25), 0, math.rad(30)) },
}
-- Posturas de preparaci?n y golpe distintas para espadas y arcos.
POSES.readySword = { RightShoulder = CFrame.Angles(math.rad(-30), 0, math.rad(18)), LeftShoulder = CFrame.Angles(math.rad(-15), 0, math.rad(-12)), RightHip = CFrame.Angles(math.rad(-8), 0, 0) }
POSES.readyBow = { Waist = CFrame.Angles(0, math.rad(-20), 0), LeftShoulder = CFrame.Angles(math.rad(65), 0, 0), RightShoulder = CFrame.Angles(math.rad(45), 0, math.rad(-15)) }
POSES.fireWindup = { Root = CFrame.new(0, -0.25, 0), Waist = CFrame.Angles(math.rad(12), math.rad(-25), 0), RightShoulder = CFrame.Angles(math.rad(155), 0, math.rad(15)), RightElbow = CFrame.Angles(math.rad(40), 0, 0), LeftShoulder = CFrame.Angles(math.rad(65), 0, math.rad(-20)), RightHip = CFrame.Angles(math.rad(-20), 0, 0), LeftHip = CFrame.Angles(math.rad(15), 0, 0) }
POSES.fireStrike = { Root = CFrame.new(0, -0.45, 0), Waist = CFrame.Angles(math.rad(-32), math.rad(20), 0), RightShoulder = CFrame.Angles(math.rad(-65), 0, math.rad(-15)), LeftShoulder = CFrame.Angles(math.rad(-35), 0, math.rad(20)), RightHip = CFrame.Angles(math.rad(-30), 0, 0), LeftHip = CFrame.Angles(math.rad(25), 0, 0) }
POSES.frostWindup = { Waist = CFrame.Angles(0, math.rad(-50), 0), RightShoulder = CFrame.Angles(math.rad(40), 0, math.rad(75)), RightElbow = CFrame.Angles(math.rad(65), 0, 0), LeftShoulder = CFrame.Angles(math.rad(25), 0, math.rad(-30)) }
POSES.frostCut = { Waist = CFrame.Angles(math.rad(-10), math.rad(40), 0), RightShoulder = CFrame.Angles(math.rad(25), 0, math.rad(-70)), LeftShoulder = CFrame.Angles(math.rad(-15), 0, math.rad(20)) }
POSES.fistsReady = { RightShoulder = CFrame.Angles(math.rad(45), 0, math.rad(15)), LeftShoulder = CFrame.Angles(math.rad(45), 0, math.rad(-15)), RightElbow = CFrame.Angles(math.rad(95), 0, 0), LeftElbow = CFrame.Angles(math.rad(95), 0, 0) }
POSES.fistsCharge = { Root = CFrame.new(0, -0.3, 0), Waist = CFrame.Angles(math.rad(15), math.rad(-30), 0), RightShoulder = CFrame.Angles(math.rad(-40), 0, math.rad(40)), RightElbow = CFrame.Angles(math.rad(100), 0, 0), LeftShoulder = CFrame.Angles(math.rad(55), 0, math.rad(-15)), LeftElbow = CFrame.Angles(math.rad(85), 0, 0), RightHip = CFrame.Angles(math.rad(-15), 0, 0) }
POSES.groundPunch = { Root = CFrame.new(0, -0.7, 0), Waist = CFrame.Angles(math.rad(-40), math.rad(25), 0), RightShoulder = CFrame.Angles(math.rad(-65), 0, math.rad(-10)), RightElbow = CFrame.Angles(math.rad(10), 0, 0), LeftShoulder = CFrame.Angles(math.rad(25), 0, math.rad(-25)), LeftElbow = CFrame.Angles(math.rad(75), 0, 0), RightHip = CFrame.Angles(math.rad(-35), 0, 0), LeftHip = CFrame.Angles(math.rad(25), 0, 0) }

-- Rayo en zigzag entre dos puntos (núcleo blanco y halo del color), se apaga solo
local function zigzag(from: Vector3, to: Vector3, width: number, segments: number, color: Color3, life: number?)
	local m = Instance.new("Model")
	m.Name = "Rayo"
	local prev = from
	for i = 1, segments do
		local nextP = from:Lerp(to, i / segments)
		if i < segments then
			nextP += Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.5, math.random() - 0.5) * width * 4
		end
		local len = (nextP - prev).Magnitude
		for layer = 1, 2 do
			local seg = Instance.new("Part")
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CastShadow = false
			seg.Material = Enum.Material.Neon
			seg.Color = if layer == 1 then color else Color3.new(1, 1, 1)
			seg.Transparency = if layer == 1 then 0.35 else 0
			local w = if layer == 1 then width * 2.2 else width
			seg.Size = Vector3.new(w, w, len)
			seg.CFrame = CFrame.lookAt((prev + nextP) / 2, nextP)
			seg.Parent = m
		end
		prev = nextP
	end
	m.Parent = fxFolder
	task.delay(life or 0.1, function()
		for _, s in m:GetChildren() do
			TweenService:Create(s :: Part, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(m, (life or 0.1) + 0.3)
end

-- Silueta roja del personaje que queda atrás al moverse rápido
local function afterimage(character: Model, color: Color3)
	if low then
		return
	end
	local ghost = Instance.new("Model")
	ghost.Name = "Estela"
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			local c = d:Clone()
			for _, x in c:GetChildren() do
				x:Destroy()
			end
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.Material = Enum.Material.Neon
			c.Color = color
			c.Transparency = 0.35
			if c:IsA("MeshPart") then
				c.TextureID = ""
			end
			c.Parent = ghost
			TweenService:Create(c, TweenInfo.new(0.45), { Transparency = 1 }):Play()
		end
	end
	ghost.Parent = fxFolder
	Debris:AddItem(ghost, 0.5)
end

-- origin = centro de los efectos (el jugador, o el agujero negro); playerPos = dónde está el jugador
local function worldSequence(u: any, origin: Vector3, dir: Vector3, at: (number, () -> ()) -> (), playerPos: Vector3?, ctx: any)
	if u.Line then
		lineSequence(u, origin, dir, at)
		return
	end
	local color: Color3 = u.Color
	local floor = ground(origin)
	local R = u.Radius

	-- Zona de efecto: anillo rojo en el piso con el radio real, hasta el golpe final
	at(0, function()
		local zone, zimgs = card(tex("Anillo"), R * 2, CFrame.new(floor + Vector3.new(0, 0.2, 0)), color, 2)
		task.delay((u.FinalAt or (u.Duration - 0.6)) + 0.2, function()
			fadeImages(zimgs, 0.3)
			Debris:AddItem(zone, 0.4)
		end)
	end)

	if u.Style == "Frost" or u.Style == "Volcanic" then
		ElementalUltimateFx.play(u, playerPos or origin, origin, at, {
			low = low, ground = ground, part = anchoredPart, burst = burst, caster = ctx and ctx.caster,
		})
		return
	end

	-- Atracción: cadenas rojas desde el centro hasta cada enemigo que tira hacia adentro
	at(u.PullAt or 1.2, function()
		local enemies = Workspace:FindFirstChild("Enemies")
		if not enemies or not (u.Pull or u.BlackHole) then
			return
		end
		local center = anchoredPart("CentroAtraccion", Vector3.one, CFrame.new(origin + Vector3.new(0, 3, 0)))
		local a0 = Instance.new("Attachment")
		a0.Parent = center
		local n = 0
		for _, e in enemies:GetChildren() do
			if n >= 20 then
				break
			end
			if e:IsA("BasePart") and (e.Position - origin).Magnitude <= R * 1.3 and e:GetAttribute("ThreatRole") ~= "Boss" then
				n += 1
				local a1 = Instance.new("Attachment")
				a1.Parent = e
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.FaceCamera = true
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Texture = tex("Energia")
				beam.TextureSpeed = -6
				beam.Color = ColorSequence.new(color)
				beam.Width0 = 0.9
				beam.Width1 = 0.4
				beam.Parent = center
				Debris:AddItem(a1, 0.8)
			end
		end
		Debris:AddItem(center, 0.8)
	end)

	-- 0,0: estallido de aura y grietas que se abren (el Carmesí tiene su propia entrada)
	if (u.Style or "Crimson") ~= "Crimson" and u.Style ~= "Inferno" and not u.Leap then
	at(0, function()
		burst(origin, color, 40, 30, 1.6)
		local crack, imgs = card(tex("Grietas"), 4, CFrame.new(floor + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.random() * 6, 0), color, 2.5)
		animate(0.5, function(k)
			local s = 4 + (R * 2.2 - 4) * (1 - (1 - k) ^ 3)
			crack.Size = Vector3.new(s, 0.05, s)
		end)
		task.delay(u.Duration, function()
			fadeImages(imgs, 0.8)
			Debris:AddItem(crack, 0.9)
		end)
		-- Rocas que vuelan
		for _ = 1, (if low then 5 else 16) do
			local r = Instance.new("Part")
			r.Name = "Roca"
			r.Material = Enum.Material.Basalt
			r.Color = Color3.fromRGB(35, 25, 25)
			local s = 0.6 + math.random() * 1.6
			r.Size = Vector3.new(s, s * 0.8, s)
			r.CanQuery = false
			r.CanTouch = false
			r.CanCollide = false
			local a = math.random() * math.pi * 2
			r.CFrame = CFrame.new(floor + Vector3.new(math.cos(a) * 4, 0.5, math.sin(a) * 4)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			r.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 14, 35 + math.random() * 25, math.sin(a) * 14)
			r.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, 0)
			r.Parent = fxFolder
			Debris:AddItem(r, 2.5)
		end
	end)
	end

	-- Parte del medio según el estilo de la definitiva (Ultimate.Style)
	local style = u.Style or "Crimson"
	if style == "Crimson" then
	-- Carmesí (iaido): luna de sangre en el cielo; el personaje cruza a los enemigos en zigzag
	-- dejando cortes rojos colgados en el aire; enfunda y todos los cortes estallan a la vez
	local finalAtC = u.FinalAt or (u.Duration - 0.6)
	local flatC = Vector3.new(dir.X, 0, dir.Z)
	local fC = if flatC.Magnitude > 0.01 then flatC.Unit else Vector3.new(0, 0, -1)
	at(0, function()
		local moon = Instance.new("Part")
		moon.Name = "LunaDeSangre"
		moon.Shape = Enum.PartType.Ball
		moon.Material = Enum.Material.Neon
		moon.Color = color:Lerp(Color3.new(0, 0, 0), 0.15)
		moon.Anchored = true
		moon.CanCollide = false
		moon.CanQuery = false
		moon.CanTouch = false
		moon.CastShadow = false
		moon.Size = Vector3.one * 34
		moon.Transparency = 1
		moon.CFrame = CFrame.new(origin - fC * 90 + Vector3.new(0, 55, 0))
		moon.Parent = fxFolder
		TweenService:Create(moon, TweenInfo.new(0.6), { Transparency = 0.05 }):Play()
		task.delay(u.Duration, function()
			TweenService:Create(moon, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(moon, u.Duration + 0.6)
		-- Aura roja que sube de los pies mientras se agacha
		local feet = anchoredPart("AuraPies", Vector3.new(4, 0.5, 4), CFrame.new(ground(playerPos or origin) + Vector3.new(0, 0.3, 0)))
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = SMOKE
		aura.Color = ColorSequence.new(color, Color3.fromRGB(40, 0, 5))
		aura.LightEmission = 0.6
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0.5) })
		aura.Lifetime = NumberRange.new(0.5, 0.8)
		aura.Speed = NumberRange.new(6, 10)
		aura.EmissionDirection = Enum.NormalId.Top
		aura.Rate = if low then 20 else 60
		aura.Parent = feet
		Debris:AddItem(feet, (u.FirstAt or 0.6) + 0.1)
	end)
	at(u.FirstAt or 0.6, function()
		local path = iaidoPath(origin, R, dir)
		-- El centro elegido está en el suelo; el pivote del avatar queda sobre él.
		for i, point in path do path[i] = ground(point) + Vector3.new(0, 3, 0) end
		if ctx then
			ctx.path = path
		end
		local lines: { Part } = {}
		local prev = (playerPos or origin)
		for i, p in path do
			local a = prev + Vector3.new(0, 1.5, 0)
			local c = p + Vector3.new(0, 1.5, 0)
			prev = p
			task.delay((i - 1) * HOP + HOP * 0.6, function()
				local len = (c - a).Magnitude
				local line = Instance.new("Part")
				line.Name = "CorteColgado"
				line.Anchored = true
				line.CanCollide = false
				line.CanQuery = false
				line.CanTouch = false
				line.CastShadow = false
				line.Material = Enum.Material.Neon
				line.Color = Color3.new(1, 1, 1)
				line.Size = Vector3.new(0.35, 0.35, len)
				line.CFrame = CFrame.lookAt((a + c) / 2, c)
				line.Parent = fxFolder
				TweenService:Create(line, TweenInfo.new(0.25), { Color = color, Size = Vector3.new(0.18, 0.18, len) }):Play()
				table.insert(lines, line)
				burst(c, color, 10, 18, 0.7)
			end)
		end
		-- Enfundar: los cortes colgados estallan a la vez
		task.delay(finalAtC - (u.FirstAt or 0.6), function()
			for _, line in lines do
				line.Color = Color3.new(1, 1, 1)
				line.Size = Vector3.new(0.9, 0.9, line.Size.Z)
				TweenService:Create(line, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(2.5, 2.5, line.Size.Z) }):Play()
				Debris:AddItem(line, 0.35)
			end
			for _, p in path do
				local at3 = p + Vector3.new(0, 2, 0)
				local camPos = Workspace.CurrentCamera.CFrame.Position
				for k = 1, 2 do
					local x, imgs = card(tex("Tajo"), 10, CFrame.lookAt(at3, camPos) * CFrame.Angles(math.rad(90), 0, math.rad(if k == 1 then 45 else -45)), color, 5)
					task.delay(0.2, function()
						fadeImages(imgs, 0.3)
					end)
					Debris:AddItem(x, 0.55)
				end
				burst(at3, color, 24, 30, 1.2)
			end
		end)
	end)
	elseif style == "Inferno" then
	-- Recreación procedural de la referencia Scorched Earth de Yuruzuu.
	-- El círculo de selección estalla en una erupción con ondas concéntricas.
	at((u.FinalAt or 2.4) - 0.28, function()
		-- El tajo envía fuego al punto marcado: se ve qué provoca la erupción.
		local from = (playerPos or origin) + Vector3.new(0, 2, 0)
		local to = floor + Vector3.new(0, 1, 0)
		local wave = anchoredPart("TajoInfernal", Vector3.one, CFrame.new(from))
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 235, 130), color)
		fire.LightEmission = 1
		fire.Lifetime = NumberRange.new(0.15, 0.3)
		fire.Speed = NumberRange.new(2, 5)
		fire.Size = NumberSequence.new(3, 0)
		fire.Rate = if low then 30 else 90
		fire.Parent = wave
		TweenService:Create(wave, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to }):Play()
		task.delay(0.28, function() fire.Enabled = false end)
		Debris:AddItem(wave, 0.65)
	end)
	at(u.FinalAt or 2.4, function()
		local base = anchoredPart("TierraQuemada", Vector3.new(R * 1.6, 0.2, R * 1.6), CFrame.new(floor + Vector3.new(0, 0.3, 0)))
		for i = 1, (if low then 2 else 4) do
			task.delay((i - 1) * 0.09, function()
				local ring, imgs = card(tex("Anillo"), R * 2, CFrame.new(floor + Vector3.new(0, 0.3 + i * 0.15, 0)), if i % 2 == 0 then Color3.fromRGB(255, 235, 150) else color, 5)
				animate(0.85, function(k)
					local size = R * 2 * (1 + 0.6 * (1 - (1 - k) ^ 3))
					ring.Size = Vector3.new(size, 0.05, size)
				end)
				task.delay(0.3, function() fadeImages(imgs, 0.55) end)
				Debris:AddItem(ring, 0.95)
			end)
		end
		local flash = anchoredPart("InfernoFlash", Vector3.one, CFrame.new(floor + Vector3.new(0, 6, 0)))
		flash.Shape = Enum.PartType.Ball
		flash.Material = Enum.Material.Neon
		flash.Color = Color3.fromRGB(255, 235, 160)
		flash.Transparency = 0.15
		TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * R * 2, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.5)
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 195)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 190, 30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 35, 5)) })
		fire.LightEmission = 1
		fire.LightInfluence = 0
		fire.EmissionDirection = Enum.NormalId.Top
		fire.SpreadAngle = Vector2.new(12, 12)
		fire.Speed = NumberRange.new(35, 65)
		fire.Acceleration = Vector3.new(0, 12, 0)
		fire.Lifetime = NumberRange.new(0.7, 1.2)
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(0.3, 15), NumberSequenceKeypoint.new(1, 0) })
		fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.65, 0.25), NumberSequenceKeypoint.new(1, 1) })
		fire.Rate = if low then 50 else 220
		fire.Parent = base
		fire:Emit(if low then 35 else 120)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = R * 2
		light.Brightness = 8
		light.Parent = base
		TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
		for i = 1, (if low then 6 else 18) do
			local a = i / (if low then 6 else 18) * math.pi * 2
			local edge = floor + Vector3.new(math.cos(a) * R * 0.8, 0.5, math.sin(a) * R * 0.8)
			zigzag(edge, edge + Vector3.new(-math.sin(a) * 7, 18 + math.random() * 16, math.cos(a) * 7), 0.3, 7, color, 0.3)
			burst(edge, color, if low then 6 else 20, 38, 1.2)
		end
		task.delay(0.8, function() fire.Enabled = false end)
		Debris:AddItem(base, 2.1)
	end)
	elseif style == "Void" then
	-- Vacío: flecha oscura hasta el punto, se abre un agujero negro que se traga todo e implota
	local finalAtV = u.FinalAt or (u.Duration - 0.6)
	-- Flecha al cielo y cometa violeta que cae justo en el punto donde se abre el agujero
	at(u.FirstAt or 0.35, function()
		local from = (playerPos or origin) + Vector3.new(0, 2.5, 0)
		zigzag(from, from + Vector3.new(0, 70, 0), 0.25, 3, color, 0.08)
		burst(from + Vector3.new(0, 2, 0), color, 16, 25, 0.9)
		task.delay(0.12, function()
			local sky = origin + Vector3.new(-dir.X * 10, 70, -dir.Z * 10)
			local land = origin + Vector3.new(0, 1, 0)
			local comet = Instance.new("Part")
			comet.Name = "Cometa"
			comet.Shape = Enum.PartType.Ball
			comet.Material = Enum.Material.Neon
			comet.Color = color
			comet.Anchored = true
			comet.CanCollide = false
			comet.CanQuery = false
			comet.CanTouch = false
			comet.CastShadow = false
			comet.Size = Vector3.one * 2.4
			comet.CFrame = CFrame.new(sky)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 1, 0)
			a0.Parent = comet
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -1, 0)
			a1.Parent = comet
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
			trail.LightEmission = 1
			trail.Lifetime = 0.25
			trail.FaceCamera = true
			trail.WidthScale = NumberSequence.new(1, 0)
			trail.Parent = comet
			comet.Parent = fxFolder
			TweenService:Create(comet, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land) }):Play()
			task.delay(0.22, function()
				burst(land + Vector3.new(0, 2, 0), color, 40, 30, 1.5)
				comet:Destroy()
			end)
		end)
	end)
	-- La mano del arquero "sostiene" el agujero: un hilo de energía de la mano al centro
	at((u.BlackHole and u.BlackHole.From) or 0.7, function()
		local caster: Player? = ctx and ctx.caster
		local ch = caster and caster.Character
		local hand = ch and (ch:FindFirstChild("LeftHand") or ch:FindFirstChild("Left Arm")) :: BasePart?
		if not hand then
			return
		end
		local holdEnd = (u.FinalAt or (u.Duration - 0.6)) - ((u.BlackHole and u.BlackHole.From) or 0.7)
		local target = anchoredPart("CentroAgujero", Vector3.one, CFrame.new(origin + Vector3.new(0, 4, 0)))
		local a0 = Instance.new("Attachment")
		a0.Parent = hand
		local a1 = Instance.new("Attachment")
		a1.Parent = target
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Texture = tex("Energia")
		beam.TextureSpeed = 6
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		beam.Width0 = 0.5
		beam.Width1 = 2.5
		beam.CurveSize0 = 3
		beam.Parent = target
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = tex("Destello")
		glow.Color = ColorSequence.new(color)
		glow.LightEmission = 1
		glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		glow.Lifetime = NumberRange.new(0.2, 0.4)
		glow.Speed = NumberRange.new(1, 3)
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.Rate = if low then 10 else 30
		glow.Parent = a0
		task.delay(holdEnd, function()
			a0:Destroy()
			target:Destroy()
		end)
	end)
	at((u.BlackHole and u.BlackHole.From) or 0.6, function()
		local holePos = origin + Vector3.new(0, 4, 0)
		local dur = finalAtV - ((u.BlackHole and u.BlackHole.From) or 0.6)
		local galaxy = GalaxyOrbFx.new(fxFolder, holePos, color, low, dur)
		-- Núcleo negro
		local core = Instance.new("Part")
		core.Name = "AgujeroNegro"
		core.Shape = Enum.PartType.Ball
		core.Material = Enum.Material.SmoothPlastic
		core.Color = Color3.new(0, 0, 0)
		core.Anchored = true
		core.CanCollide = false
		core.CanQuery = false
		core.CanTouch = false
		core.CastShadow = false
		core.Size = Vector3.one
		core.CFrame = CFrame.new(holePos)
		core.Parent = fxFolder
		-- Borde violeta que brilla
		local rim = Instance.new("Part")
		rim.Name = "Borde"
		rim.Shape = Enum.PartType.Ball
		rim.Material = Enum.Material.ForceField
		rim.Color = color
		rim.Anchored = true
		rim.CanCollide = false
		rim.CanQuery = false
		rim.CanTouch = false
		rim.CastShadow = false
		rim.Size = Vector3.one * 1.3
		rim.CFrame = CFrame.new(holePos)
		rim.Parent = fxFolder
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 40
		glow.Brightness = 3
		glow.Parent = rim
		-- Disco de acreción: espirales planas que giran rápido alrededor
		local disks = {}
		for i = 1, 2 do
			local d, imgs = card(tex(if i == 1 then "Espiral" else "Anillo"), 6, CFrame.new(holePos) * CFrame.Angles(math.rad(15), 0, 0), color, 4)
			table.insert(disks, { part = d, imgs = imgs, dir = if i == 1 then 1 else -1 })
		end
		-- Partículas que caen hacia adentro desde toda la zona
		local shell = anchoredPart("Absorcion", Vector3.new(R * 2, 10, R * 2), CFrame.new(holePos))
		local inward = Instance.new("ParticleEmitter")
		inward.Shape = Enum.ParticleEmitterShape.Sphere
		inward.Texture = tex("Destello")
		inward.Color = ColorSequence.new(color, Color3.fromRGB(20, 0, 40))
		inward.LightEmission = 1
		inward.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		inward.Lifetime = NumberRange.new(0.6, 0.9)
		inward.Speed = NumberRange.new(-34, -22)
		inward.Rate = if low then 50 else 180
		inward.Parent = shell
		local dust = Instance.new("ParticleEmitter")
		dust.Shape = Enum.ParticleEmitterShape.Sphere
		dust.Texture = SMOKE
		dust.Color = ColorSequence.new(Color3.fromRGB(30, 10, 50))
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.8, 1.1)
		dust.Speed = NumberRange.new(-20, -14)
		dust.Rate = if low then 8 else 30
		dust.Parent = shell
		animate(dur, function(k)
			-- Crece, palpita y al final se encoge de golpe (implosión)
			local s = if k < 0.85 then 2 + 7 * (k / 0.85) + math.sin(k * 40) * 0.3 else 9 * (1 - (k - 0.85) / 0.15)
			s = math.max(s, 0.2)
			galaxy.Update(k, s * 1.35)
			core.Size = Vector3.one * s
			rim.Size = Vector3.one * s * 1.35
			for _, d in disks do
				local ds = s * 3.2
				d.part.Size = Vector3.new(ds, 0.05, ds)
				d.part.CFrame = CFrame.new(holePos) * CFrame.Angles(math.rad(15), d.dir * k * 30, 0)
			end
		end)
		task.delay(dur, function()
			inward.Rate = 0
			dust.Rate = 0
			for _, d in disks do
				d.part:Destroy()
			end
			core:Destroy()
			rim:Destroy()
			galaxy.Destroy()
			Debris:AddItem(shell, 1.2)
		end)
	end)
	else
	-- Celestial: flecha al cielo, nubes de tormenta y lanza de luz (los rayos sobre cada enemigo
	-- los dibuja SkillVisuals con los avisos "Chain" del servidor)
	at(0.15, function()
		burst(origin + Vector3.new(0, 3, 0), color, 30, 20, 1.2)
	end)
	if u.Leap then
		-- La espada en alto junta los rayos de la nube mientras flotás
		local caster: Player? = ctx and ctx.caster
		local function swordTip(): Vector3
			local ch = caster and caster.Character
			local hand = ch and (ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm")) :: BasePart?
			return if hand then hand.Position + Vector3.new(0, 3, 0) else origin + Vector3.new(0, (u.Leap.Height or 18) + 4, 0)
		end
		local finalAtS = u.FinalAt or (u.Duration - 0.6)
		at(1.0, function()
			local t0 = os.clock()
			while os.clock() - t0 < finalAtS - 1.0 - 0.2 do
				local tip = swordTip()
				local a = math.random() * math.pi * 2
				local from = origin + Vector3.new(math.cos(a) * R * 0.6, 38, math.sin(a) * R * 0.6)
				zigzag(from, tip, 0.35, 6, color, 0.06)
				burst(tip, color, 6, 10, 0.6)
				task.wait(if low then 0.25 else 0.12)
			end
		end)
		-- Aterrizaje: cráter con grietas y rocas
		at(finalAtS, function()
			local crack, imgs = card(tex("Grietas"), 6, CFrame.new(floor + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.random() * 6, 0), color, 3)
			animate(0.3, function(k)
				local s = 6 + R * 1.6 * (1 - (1 - k) ^ 3)
				crack.Size = Vector3.new(s, 0.05, s)
			end)
			task.delay(0.8, function()
				fadeImages(imgs, 0.6)
				Debris:AddItem(crack, 0.7)
			end)
			for _ = 1, (if low then 5 else 14) do
				local r = Instance.new("Part")
				r.Name = "Roca"
				r.Material = Enum.Material.Basalt
				r.Color = Color3.fromRGB(45, 40, 35)
				local s = 0.6 + math.random() * 1.4
				r.Size = Vector3.new(s, s * 0.8, s)
				r.CanQuery = false
				r.CanTouch = false
				r.CanCollide = false
				local a = math.random() * math.pi * 2
				r.CFrame = CFrame.new(floor + Vector3.new(math.cos(a) * 3, 0.5, math.sin(a) * 3))
				r.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 18, 30 + math.random() * 20, math.sin(a) * 18)
				r.Parent = fxFolder
				Debris:AddItem(r, 2.2)
			end
		end)
	end
	at(u.FirstAt or 0.5, function()
		if u.Leap then
			-- Al despegar: destello en los pies
			burst(floor + Vector3.new(0, 1, 0), color, 30, 25, 1.2)
			return
		end
		local p = anchoredPart("FlechaAlCielo", Vector3.one, CFrame.new(origin + Vector3.new(0, 3, 0)))
		local a0 = Instance.new("Attachment")
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 140, 0)
		a1.Parent = p
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Texture = tex("Energia")
		beam.TextureSpeed = 8
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		beam.Width0 = 3
		beam.Width1 = 1
		beam.Parent = p
		animate(0.6, function(k)
			beam.Width0 = 3 * (1 - k)
			beam.Width1 = 1 * (1 - k)
		end)
		Debris:AddItem(p, 0.7)
		burst(origin + Vector3.new(0, 40, 0), color, 40, 40, 2)
	end)
	at(0.85, function()
		local finalAt = u.FinalAt or (u.Duration - 0.6)
		local dur = finalAt - 0.85 + 0.4
		local cloudPos = origin + Vector3.new(0, 38, 0)
		local cloud = anchoredPart("Tormenta", Vector3.new(R * 2.6, 4, R * 2.6), CFrame.new(cloudPos))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = SMOKE
		smoke.Color = ColorSequence.new(Color3.fromRGB(40, 45, 70), Color3.fromRGB(90, 95, 130))
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 1) })
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 22) })
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Speed = NumberRange.new(1, 3)
		smoke.RotSpeed = NumberRange.new(-20, 20)
		smoke.Rate = if low then 15 else 50
		smoke.Parent = cloud
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 60
		glow.Brightness = 0
		glow.Parent = cloud
		local sp, imgs = card(tex("Espiral"), R * 2.2, CFrame.new(cloudPos - Vector3.new(0, 3, 0)), color, 3)
		animate(dur, function(k)
			sp.CFrame = CFrame.new(cloudPos - Vector3.new(0, 3, 0)) * CFrame.Angles(0, k * 10, 0)
			glow.Brightness = if math.random() < 0.15 then 6 else glow.Brightness * 0.8 -- relámpagos
		end)
		task.delay(dur, function()
			smoke.Rate = 0
			fadeImages(imgs, 0.4)
			Debris:AddItem(sp, 0.5)
			Debris:AddItem(cloud, 2.6)
		end)
		-- Rayo gigante del cielo justo en el golpe final, con un círculo de rayos alrededor
		if u.GiantBolt then
			task.delay(finalAt - 0.85 - 0.05, function()
				local function bolt(from: Vector3, to: Vector3, width: number, segments: number)
					local m = Instance.new("Model")
					m.Name = "Rayo"
					local prev = from
					for i = 1, segments do
						local k = i / segments
						local nextP = from:Lerp(to, k)
						if i < segments then
							nextP += Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * width * 4
						end
						local len = (nextP - prev).Magnitude
						for layer = 1, 2 do
							local seg = Instance.new("Part")
							seg.Anchored = true
							seg.CanCollide = false
							seg.CanQuery = false
							seg.CanTouch = false
							seg.CastShadow = false
							seg.Material = Enum.Material.Neon
							seg.Color = if layer == 1 then color else Color3.new(1, 1, 1)
							seg.Transparency = if layer == 1 then 0.35 else 0
							local w = if layer == 1 then width * 2.2 else width
							seg.Size = Vector3.new(w, w, len)
							seg.CFrame = CFrame.lookAt((prev + nextP) / 2, nextP)
							seg.Parent = m
						end
						prev = nextP
					end
					m.Parent = fxFolder
					task.delay(0.12, function()
						for _, s in m:GetChildren() do
							TweenService:Create(s :: Part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
						end
					end)
					Debris:AddItem(m, 0.5)
				end
				bolt(cloudPos + Vector3.new(0, 20, 0), floor, 1.6, 9)
				local fp = anchoredPart("Fogonazo", Vector3.one, CFrame.new(floor + Vector3.new(0, 4, 0)))
				local flash = Instance.new("PointLight")
				flash.Color = color
				flash.Range = 60
				flash.Brightness = 10
				flash.Parent = fp
				TweenService:Create(flash, TweenInfo.new(0.5), { Brightness = 0 }):Play()
				Debris:AddItem(fp, 0.6)
				for i = 1, 8 do
					local a = i / 8 * math.pi * 2
					local to = ground(origin + Vector3.new(math.cos(a), 0, math.sin(a)) * R * 0.7)
					task.delay(0.05 + i * 0.025, function()
						bolt(cloudPos + Vector3.new(math.cos(a) * R * 0.5, 0, math.sin(a) * R * 0.5), to, 0.7, 6)
						burst(to + Vector3.new(0, 1, 0), color, 10, 20, 0.8)
					end)
				end
			end)
			return
		end
		-- Lanza de luz que cae justo antes del golpe final
		task.delay(finalAt - 0.85 - 0.2, function()
			local spear = Instance.new("Part")
			spear.Name = "LanzaDeLuz"
			spear.Material = Enum.Material.Neon
			spear.Color = color
			spear.Anchored = true
			spear.CanCollide = false
			spear.CanQuery = false
			spear.CanTouch = false
			spear.Size = Vector3.new(2.2, 26, 2.2)
			spear.CFrame = CFrame.new(cloudPos + Vector3.new(0, 10, 0))
			spear.Parent = fxFolder
			TweenService:Create(spear, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(floor + Vector3.new(0, 8, 0)) }):Play()
			task.delay(0.25, function()
				TweenService:Create(spear, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(6, 30, 6) }):Play()
			end)
			Debris:AddItem(spear, 0.7)
		end)
	end)
	end

	-- Golpe final: columna de energía, cristales y onda expansiva
	at(u.FinalAt or (u.Duration - 0.6), function()
		burst(floor + Vector3.new(0, 2, 0), color, 80, 70, 2.4)
		if u.Column ~= false then
		-- Columna
		local col = anchoredPart("Columna", Vector3.one, CFrame.new(floor))
		local a0 = Instance.new("Attachment")
		a0.Parent = col
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 120, 0)
		a1.Parent = col
		for k = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Texture = tex("Energia")
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 18
			beam.TextureSpeed = 4 * k
			beam.Color = ColorSequence.new(if k == 1 then color else Color3.new(1, 1, 1))
			beam.Width0 = if k == 1 then 14 else 5
			beam.Width1 = if k == 1 then 8 else 2
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
			beam.Parent = col
			animate(0.8, function(kk)
				beam.Width0 = (if k == 1 then 14 else 5) * (1 - kk)
				beam.Width1 = (if k == 1 then 8 else 2) * (1 - kk)
			end)
		end
		Debris:AddItem(col, 0.9)
		-- Cristales que brotan
		for i = 1, (if low then 6 else 14) do
			local a = i / 14 * math.pi * 2 + math.random() * 0.3
			local d = R * (0.25 + math.random() * 0.55)
			local base = floor + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)
			local h = 4 + math.random() * 7
			local s = Instance.new("Part")
			s.Name = "Cristal"
			s.Material = Enum.Material.Neon
			s.Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.4)
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.CanTouch = false
			local w = h * 0.22
			s.Size = Vector3.new(w, 0.2, w)
			local tilt = CFrame.Angles(math.rad(math.random(-30, 30)), a, math.rad(math.random(-30, 30)))
			s.CFrame = CFrame.new(base) * tilt
			s.Parent = fxFolder
			TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = Vector3.new(w, h, w), CFrame = CFrame.new(base) * tilt * CFrame.new(0, h / 2, 0) }):Play()
			task.delay(0.9 + math.random() * 0.4, function()
				TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end)
			Debris:AddItem(s, 1.6)
		end
		end
		-- Marca de corte en cada enemigo que agarra el golpe final
		local enemies = Workspace:FindFirstChild("Enemies")
		if enemies then
			local n = 0
			for _, e in enemies:GetChildren() do
				if n < 20 and e:IsA("BasePart") and (e.Position - origin).Magnitude <= R + 2 then
					n += 1
					local mark, mimgs = card(tex("Tajo"), 7, CFrame.lookAt(e.Position, Workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(math.rad(90), 0, math.rad(math.random(-40, 40))), color, 5)
					task.delay(0.25, function()
						fadeImages(mimgs, 0.3)
					end)
					Debris:AddItem(mark, 0.6)
					burst(e.Position, color, 12, 25, 0.8)
				end
			end
		end
		-- Tierra Quemada ya dibuja sus propias ondas de fuego.
		if u.Style == "Inferno" then return end
		-- Onda expansiva
		local ring, imgs = card(tex("Anillo"), 4, CFrame.new(floor + Vector3.new(0, 0.3, 0)), color, 5)
		animate(0.6, function(k)
			local s = 4 + R * 3.2 * (1 - (1 - k) ^ 2)
			ring.Size = Vector3.new(s, 0.05, s)
		end)
		task.delay(0.3, function()
			fadeImages(imgs, 0.3)
		end)
		Debris:AddItem(ring, 0.7)
	end)
end

---------------------------------------------------------------------
-- Cinemática (solo quien la lanza)
---------------------------------------------------------------------

local function cinematic(u: any, origin: Vector3, dir: Vector3, start: number, ctx: any)
	local cam = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local color: Color3 = u.Color
	local fovBefore = cam.FieldOfView
	player:SetAttribute("Cinematic", true)
	local cameraBefore = cam.CFrame
	local cameraTypeBefore = cam.CameraType
	local motion = UltimateMotion.new(character, u, origin, dir, ctx, POSES)

	-- Pantalla limpia: se esconden todos los carteles (HUD, metas, objetos, marcadores, barras de
	-- vida de los enemigos y el menú de Roblox) y vuelven al terminar
	local hiddenGuis: { Instance } = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "UltimateBars" then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	for _, g in Workspace:GetDescendants() do
		if g:IsA("BillboardGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	local StarterGui = game:GetService("StarterGui")
	local coreBefore: { [Enum.CoreGuiType]: boolean } = {}
	for _, t in Enum.CoreGuiType:GetEnumItems() do
		if t ~= Enum.CoreGuiType.All then
			coreBefore[t] = StarterGui:GetCoreGuiEnabled(t)
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)

	-- Pantalla de un solo color
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "UltimateGrade"
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.25), { Saturation = 0.05, Contrast = 0.08, TintColor = Color3.new(1, 1, 1):Lerp(color, 0.08) }):Play()
	-- Franjas de cine
	local bars = Instance.new("ScreenGui")
	bars.Name = "UltimateBars"
	bars.IgnoreGuiInset = true
	bars.DisplayOrder = 60
	bars.Parent = player:WaitForChild("PlayerGui")
	local function bar(top: boolean): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		f.Position = UDim2.fromScale(0, if top then 0 else 1)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = bars
		TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.fromScale(1, 0.11) }):Play()
		return f
	end
	bar(true)
	bar(false)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0, 40, 1, -24)
	title.Size = UDim2.fromScale(0.6, 0.07)
	title.Font = Enum.Font.Fantasy
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = string.upper(u.Name)
	title.TextColor3 = color
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.TextTransparency = 1
	title.ZIndex = 2
	title.Parent = bars
	TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	-- Qué está pasando, paso a paso (arriba, sobre la franja de cine)
	local step = Instance.new("TextLabel")
	step.BackgroundTransparency = 1
	step.AnchorPoint = Vector2.new(0.5, 0)
	step.Position = UDim2.fromScale(0.5, 0.13)
	step.Size = UDim2.fromScale(0.8, 0.06)
	step.Font = Enum.Font.GothamBlack
	step.TextScaled = true
	step.TextColor3 = Color3.new(1, 1, 1)
	step.TextStrokeColor3 = color
	step.TextStrokeTransparency = 0
	step.TextTransparency = 1
	step.ZIndex = 3
	step.Parent = bars
	-- Textos de cada paso: Ultimate.Steps (3 textos) en Shared/Weapons
	local texts = u.Steps or { "1 · TAJO CARMESÍ: corta a todos alrededor", "2 · ATRACCIÓN: junta a los enemigos", "3 · LUNA SANGRIENTA: golpe final y sangrado" }
	local steps = {
		{ at = u.FirstAt or 0.5, text = texts[1] },
		{ at = u.Step2At or (u.Bolts and u.Bolts.From) or u.PullAt or 1.2, text = texts[2] },
		{ at = (u.FinalAt or (u.Duration - 0.6)) - 0.35, text = texts[3] },
	}
	for _, s in steps do
		task.delay(math.max(0, start + s.at - Workspace:GetServerTimeNow()), function()
			if step.Parent then
				step.Text = s.text
				step.TextTransparency = 0
				step.Size = UDim2.fromScale(0.9, 0.07)
				TweenService:Create(step, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.8, 0.06) }):Play()
			end
		end)
	end

	RunService:BindToRenderStep("UltimateCam", Enum.RenderPriority.Last.Value, function()
		local t = Workspace:GetServerTimeNow() - start
		motion.Update(t)
		local cf, fov = motion.Camera(t, cameraBefore, fovBefore, cam.ViewportSize.X / math.max(1, cam.ViewportSize.Y))
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf
		cam.FieldOfView = fov
	end)

	task.delay(math.max(0, start + u.Duration + 0.1 - Workspace:GetServerTimeNow()), function()
		RunService:UnbindFromRenderStep("UltimateCam")
		motion.Destroy()
		cam.FieldOfView = fovBefore
		cam.CameraType = cameraTypeBefore
		player:SetAttribute("Cinematic", false)
		for _, g in hiddenGuis do
			if g.Parent then
				(g :: any).Enabled = true
			end
		end
		for t, on in coreBefore do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(t, on)
			end)
		end
		TweenService:Create(cc, TweenInfo.new(0.4), { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		Debris:AddItem(cc, 0.5)
		bars:Destroy()
	end)
end

---------------------------------------------------------------------
-- Aviso del servidor
---------------------------------------------------------------------

fxRemote.OnClientEvent:Connect(function(userId: number, weaponId: string, origin: Vector3, dir: Vector3, start: number, target: Vector3?)
	local u = ultOf(weaponId)
	if not u or typeof(origin) ~= "Vector3" then
		return
	end
	local mine = userId == player.UserId
	if not mine and (origin - Workspace.CurrentCamera.CFrame.Position).Magnitude > 250 then
		return
	end
	local function at(offset: number, fn: () -> ())
		task.delay(math.max(0, start + offset - Workspace:GetServerTimeNow()), fn)
	end
	-- Con agujero negro, los efectos del área van en el agujero (delante del jugador)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	local center = if u.TargetRange and not u.Line and typeof(target) == "Vector3" then target
		elseif u.BlackHole and flatDir.Magnitude > 0.01 then origin + flatDir.Unit * u.BlackHole.Distance else origin
	local ctx = {} -- datos compartidos entre los efectos y la cinemática (p. ej. el camino del iaido)
	ctx.caster = Players:GetPlayerByUserId(userId)
	ctx.center = center
	worldSequence(u, center, dir, at, origin, ctx)
	if mine then
		cinematic(u, origin, dir, start, ctx)
	elseif ctx.caster and ctx.caster.Character and ctx.caster.Character:FindFirstChild("HumanoidRootPart") then
		local motion = UltimateMotion.new(ctx.caster.Character, u, origin, dir, ctx, POSES)
		local connection = RunService.RenderStepped:Connect(function()
			motion.Update(Workspace:GetServerTimeNow() - start)
		end)
		task.delay(math.max(0, start + u.Duration + 0.1 - Workspace:GetServerTimeNow()), function()
			connection:Disconnect()
			motion.Destroy()
		end)
	end
end)
