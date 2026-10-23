-- Energía adherida a la flecha; también se ve mientras está apoyada en el arco.
local ArrowEnergyFx = {}

function ArrowEnergyFx.new(root: BasePart, style: any, low: boolean)
	local void = style.Effects.Projectile == "Void"
	local owned = {}
	local function keep(item)
		table.insert(owned, item)
		item.Parent = root
		return item
	end
	local points, beams, motes = {}, {}, {}
	local length = root.Size.Z
	for i = 1, (if low then 4 else 6) do
		points[i] = keep(Instance.new("Attachment"))
		if i > 1 then
			local beam = keep(Instance.new("Beam"))
			beam.Attachment0 = points[i - 1]
			beam.Attachment1 = points[i]
			beam.FaceCamera = true
			beam.Width0 = if void then 0.06 else 0.035
			beam.Width1 = beam.Width0 * 0.5
			beam.Color = ColorSequence.new(if void then style.Light else style.Core, style.Deep)
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beams[#beams + 1] = beam
		end
	end
	local emitter = keep(Instance.new("ParticleEmitter"))
	emitter.Texture = if void then "rbxasset://textures/particles/smoke_main.dds" else "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(if void then style.Deep else style.Core, style.Light)
	emitter.LightEmission = if void then 0.45 else 1
	emitter.LightInfluence = 0
	emitter.Lifetime = NumberRange.new(0.12, 0.3)
	emitter.Speed = NumberRange.new(0.1, 0.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(if void then 0.3 else 0.12, 0)
	emitter.Transparency = NumberSequence.new(if void then 0.45 else 0.1, 1)
	emitter.Rate = if low then 3 else if void then 12 else 18
	for i = 1, (if low then 1 else 2) do
		local mote = keep(Instance.new("Part"))
		mote.Name = if void then "VoidSatellite" else "ElectricSpark"
		mote.Shape = Enum.PartType.Ball
		mote.Size = Vector3.one * (if void then 0.13 else 0.07)
		mote.Anchored = true
		mote.CanCollide = false
		mote.CanTouch = false
		mote.CanQuery = false
		mote.CastShadow = false
		mote.Material = Enum.Material.Neon
		mote.Color = style.Light
		motes[i] = mote
	end
	local fx = {}
	function fx.Update(time: number, visible: boolean)
		if not root.Parent then return end
		local phase = time * (if void then 5 else 22)
		local radius = if void then 0.22 else 0.09
		for i, point in points do
			local k = (i - 1) / (#points - 1)
			local angle = phase + k * (if void then math.pi * 3 else 13)
			point.Position = Vector3.new(math.cos(angle) * radius, math.sin(angle * (if void then 1 else 1.7)) * radius, length * (0.5 - k))
		end
		for _, beam in beams do beam.Enabled = visible end
		emitter.Enabled = visible
		if not visible then emitter:Clear() end
		for i, mote in motes do
			local a = phase + i * math.pi
			mote.CFrame = root.CFrame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, math.sin(a * 0.7) * length * 0.4)
			mote.Transparency = if visible then (if void then 0.1 else 0.25 + 0.25 * math.sin(phase * 3)) else 1
		end
	end
	function fx.Destroy()
		for _, item in owned do item:Destroy() end
	end
	fx.Update(0, false)
	return fx
end

return ArrowEnergyFx
