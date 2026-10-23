-- Rayos que recorren la silueta del arco, con piezas persistentes y sin luces extra.
local Aura = {}

function Aura.new(model: Model, low: boolean)
	local box, size = model:GetBoundingBox()
	local anchor = model:FindFirstChild("Handle", true)
	if not anchor or not anchor:IsA("BasePart") then anchor = model:FindFirstChildWhichIsA("BasePart", true) end
	if not anchor then return nil end
	local offset = anchor.CFrame:ToObjectSpace(box)
	local height = math.max(size.Y, 0.1)
	local arcs, owned = {}, {}
	local function keep(item, parent)
		table.insert(owned, item)
		item.Parent = parent
		return item
	end
	for i = 1, (if low then 2 else 3) do
		local points = {}
		for j = 1, (if low then 4 else 6) do
			points[j] = keep(Instance.new("Attachment"), anchor)
			if j > 1 then
				local beam = keep(Instance.new("Beam"), anchor)
				beam.Attachment0, beam.Attachment1 = points[j - 1], points[j]
				beam.FaceCamera = true
				beam.Width0 = height * 0.012
				beam.Width1 = height * 0.005
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255), Color3.fromRGB(70, 175, 255))
				beam.Transparency = NumberSequence.new(0.05, 0.55)
			end
		end
		local sparks = keep(Instance.new("ParticleEmitter"), points[1])
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255), Color3.fromRGB(80, 185, 255))
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Lifetime = NumberRange.new(0.1, 0.25)
		sparks.Speed = NumberRange.new(0.1, 0.5)
		sparks.Size = NumberSequence.new(height * 0.04, 0)
		sparks.Rate = if low then 3 else 7
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Transparency = NumberSequence.new(0.1, 1)
		arcs[i] = points
	end
	local fx = {}
	function fx.Update(time: number)
		if not anchor.Parent or not model.Parent then return end
		local frame = anchor.CFrame * offset
		for i, points in arcs do
			local phase = time * 2.8 + (i - 1) * math.pi * 2 / #arcs
			for j, point in points do
				local a = phase - (j - 1) * 0.16
				local jitter = math.sin(time * 35 + j * 9 + i) * height * 0.018
				point.WorldPosition = frame:PointToWorldSpace(Vector3.new(
					math.cos(a) * height * 0.16 + jitter,
					math.sin(a) * height * 0.49,
					math.sin(a * 2 + i) * height * 0.12 + jitter
				))
			end
		end
	end
	function fx.Destroy()
		for _, item in owned do item:Destroy() end
	end
	fx.Update(0)
	return fx
end

return Aura
