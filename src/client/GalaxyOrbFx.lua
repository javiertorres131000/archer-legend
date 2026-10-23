-- Recreación procedural inspirada en Galaxy Orb de Yuruzuu.
-- Referencia: https://devforum.roblox.com/t/yuruzuus-open-source-vfx/1840021
-- No incluye modelos, scripts ni texturas descargados del autor.
local Debris = game:GetService("Debris")
local GalaxyOrbFx = {}

function GalaxyOrbFx.new(parent: Instance, position: Vector3, color: Color3, low: boolean, lifetime: number)
	local root = Instance.new("Part")
	root.Name = "GalaxyOrb"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.one
	root.Position = position
	root.Parent = parent
	Debris:AddItem(root, lifetime + 1)
	local white = Color3.fromRGB(245, 225, 255)
	local rings = {}
	local segments = if low then 16 else 32
	for layer = 1, (if low then 2 else 3) do
		local points = {}
		for i = 1, segments do
			local a = Instance.new("Attachment")
			a.Parent = root
			points[i] = a
		end
		for i = 1, segments do
			local beam = Instance.new("Beam")
			beam.Attachment0 = points[i]
			beam.Attachment1 = points[i % segments + 1]
			beam.FaceCamera = true
			beam.Width0 = if layer == 1 then 0.16 else 0.09
			beam.Width1 = beam.Width0
			beam.Color = ColorSequence.new(if layer == 1 then white else color)
			beam.Transparency = NumberSequence.new(if layer == 1 then 0.1 else 0.3)
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Parent = root
		end
		rings[layer] = points
	end
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new(white, color)
	stars.LightEmission = 1
	stars.LightInfluence = 0
	stars.Lifetime = NumberRange.new(0.4, 0.9)
	stars.Speed = NumberRange.new(2, 6)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Size = NumberSequence.new(0.35, 0)
	stars.Transparency = NumberSequence.new(0.1, 1)
	stars.Rate = if low then 12 else 40
	stars.Parent = root
	local satellites = {}
	for i = 1, (if low then 1 else 2) do
		local orb = Instance.new("Part")
		orb.Name = "OrbitingStar"
		orb.Shape = Enum.PartType.Ball
		orb.Material = Enum.Material.Neon
		orb.Color = white
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.CastShadow = false
		orb.Size = Vector3.one * 0.5
		orb.Position = position
		orb.Parent = root
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0.22, 0)
		a.Parent = orb
		local b = Instance.new("Attachment")
		b.Position = -a.Position
		b.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = a
		trail.Attachment1 = b
		trail.FaceCamera = true
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(white, color)
		trail.Lifetime = 0.35
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Parent = orb
		satellites[i] = orb
	end
	local fx = {}
	function fx.Update(progress: number, diameter: number)
		if not root.Parent then return end
		local time = progress * lifetime
		local camera = workspace.CurrentCamera
		local facing = if camera and (camera.CFrame.Position - position).Magnitude > 0.01
			then CFrame.lookAt(position, camera.CFrame.Position) else CFrame.new(position)
		for layer, points in rings do
			local frame = if layer == 1 then facing
				else CFrame.new(position) * CFrame.Angles(0.5 + layer * 0.4, time * (if layer == 2 then 1 else -1), 0.4)
			local radius = diameter * (0.57 + (layer - 1) * 0.2)
			for i, point in points do
				local angle = (i - 1) / segments * math.pi * 2 + time
				point.WorldPosition = frame:PointToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0) * radius)
			end
		end
		for i, orb in satellites do
			local angle = time * 3.5 + (i - 1) * math.pi
			orb.Position = position + Vector3.new(math.cos(angle), math.sin(angle * 1.4) * 0.35, math.sin(angle)) * diameter * 1.05
			orb.Size = Vector3.one * math.max(0.08, diameter * 0.09)
		end
		root.Size = Vector3.one * math.max(0.1, diameter)
	end
	function fx.Destroy()
		root:Destroy()
	end
	fx.Update(0, 2)
	return fx
end

return GalaxyOrbFx
