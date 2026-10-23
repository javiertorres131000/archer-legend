-- Modelo procedural compartido entre primera y tercera persona.
local CelestialBowModel = {}

function CelestialBowModel.build(id: string?): Model
	local model = Instance.new("Model")
	model.Name = id or "CelestialBow"
	local isVoid = id == "VoidBow"
	model:SetAttribute("AlignedBow", true) -- ejes y anclas ya definidos; evitar reorientación automática
	local gold = if isVoid then Color3.fromRGB(32, 20, 48) else Color3.fromRGB(255, 212, 110)
	local blue = if isVoid then Color3.fromRGB(170, 85, 255) else Color3.fromRGB(70, 190, 255)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	-- Curva hacia -Z, como el arco base; el agarre queda en el centro.
	part("Handle", Vector3.new(0.3, 0.85, 0.3), CFrame.new(0, 0, -0.9), Color3.fromRGB(35, 45, 70), false)
	for i = -4, 4 do
		local a = math.rad(i * 15)
		local cf = CFrame.new(0, math.sin(a) * 2.3, -math.cos(a) * 0.95) * CFrame.Angles(a, 0, 0)
		part("Limb", Vector3.new(0.25, 0.64, 0.23), cf, gold, false)
		part("Conduit", Vector3.new(0.12, 0.57, 0.26), cf, blue, true)
		if math.abs(i) >= 2 then
			part("Wing", Vector3.new(0.18, 0.48, 0.55), cf * CFrame.new(0, 0, -0.25), gold, false)
		end
	end
	part("String", Vector3.new(0.035, 4, 0.035), CFrame.new(0, 0, -0.475), if isVoid then blue else gold, true)
	part("Gem", Vector3.new(0.38, 0.38, 0.38), CFrame.new(0, 0, -1.12) * CFrame.Angles(0, 0, math.rad(45)), blue, true)
	-- Ancla invisible para el aura: no altera el tamaño del modelo.
	part("BladeAura", Vector3.new(0.08, 3.8, 0.08), CFrame.new(0, 0, -0.475), gold, false)
	local aura = model:FindFirstChild("BladeAura") :: Part
	aura.Transparency = 1
	return model
end

return CelestialBowModel
