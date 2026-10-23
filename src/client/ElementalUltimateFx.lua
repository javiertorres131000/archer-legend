-- Dos ataques distintos: corte de hielo y fractura de magma.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Fx = {}

function Fx.play(u: any, source: Vector3, target: Vector3, at: any, env: any)
	local frost = u.Style == "Frost"
	local final = u.FinalAt
	local radius = u.Radius
	local color = u.Color
	local low = env.low
	local function piece(name: string, pos: Vector3, size: Vector3, material: Enum.Material, tint: Color3): Part
		local p = env.part(name, size, CFrame.new(pos))
		p.Transparency = 0
		p.Material = material
		p.Color = tint
		return p
	end
	-- La preparación se ve en el arma, no como otra explosión en el blanco.
	at(u.FirstAt, function()
		local caster = env.caster
		local ch = caster and caster.Character
		local hand = ch and (ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm"))
		if not hand then return end
		local attachment = Instance.new("Attachment")
		attachment.Parent = hand
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = if frost then "rbxasset://textures/particles/sparkles_main.dds" else "rbxasset://textures/particles/fire_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Rate = if low then 10 else 25
		emitter.Lifetime = NumberRange.new(0.15, 0.3)
		emitter.Speed = NumberRange.new(0.5, 2)
		emitter.Size = NumberSequence.new(if frost then 0.6 else 1.3, 0)
		emitter.Parent = attachment
		Debris:AddItem(attachment, final - u.FirstAt)
	end)
	at(final - 0.4, function()
		local from = env.ground(source) + Vector3.new(0, 0.25, 0)
		local to = env.ground(target) + Vector3.new(0, 0.25, 0)
		local segments = if low then 6 else 12
		for i = 1, segments do
			task.delay((i - 1) / segments * 0.4, function()
				local a = env.ground(from:Lerp(to, (i - 1) / segments)) + Vector3.new(0, 0.2, 0)
				local b = env.ground(from:Lerp(to, i / segments)) + Vector3.new(0, 0.2, 0)
				local delta = b - a
				if delta.Magnitude < 0.01 then return end
				local p = piece(if frost then "IceWave" else "MagmaFissure", (a + b) / 2,
					Vector3.new(if frost then 2 else 0.8, 0.3, delta.Magnitude + 0.4), Enum.Material.Neon, color)
				p.CFrame = CFrame.lookAt((a + b) / 2, b)
				TweenService:Create(p, TweenInfo.new(0.65), { Transparency = 1 }):Play()
				Debris:AddItem(p, 0.7)
				if frost then
					local shard = piece("TravelingIce", b, Vector3.new(0.5, 0.2, 0.5), Enum.Material.Ice, color)
					TweenService:Create(shard, TweenInfo.new(0.15), { Size = Vector3.new(0.7, 3, 0.7), Position = b + Vector3.new(0, 1.5, 0) }):Play()
					task.delay(0.3, function() TweenService:Create(shard, TweenInfo.new(0.3), { Transparency = 1 }):Play() end)
					Debris:AddItem(shard, 0.65)
				else
					env.burst(b, color, if low then 3 else 6, 10, 0.5)
				end
			end)
		end
	end)
	at(final, function()
		local count = if low then 8 else 20
		for i = 1, count do
			local angle = i / count * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local distance = radius * (0.25 + 0.65 * ((i % 3 + 1) / 3))
			local base = env.ground(target + offset * distance)
			if frost then
				-- Cristales escalonados, luego se quiebran: nada de columna de fuego azul.
				task.delay((i % 4) * 0.035, function()
					local h = 5 + (i % 5) * 1.6
					local crystal = piece("GlacialCrystal", base, Vector3.new(0.3, 0.2, 0.3), Enum.Material.Ice, color)
					local tilt = CFrame.Angles(math.rad(12), angle, math.rad(15))
					TweenService:Create(crystal, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
						Size = Vector3.new(1.3, h, 1.3), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * tilt,
					}):Play()
					task.delay(0.65, function()
						env.burst(crystal.Position, color, if low then 3 else 6, 12, 0.5)
						TweenService:Create(crystal, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.1, h * 0.5, 0.1) }):Play()
					end)
					Debris:AddItem(crystal, 1.1)
				end)
			else
				-- Rocas suspendidas y desplazadas con Tween: no dependen de la física pausada.
				local rock = piece("VolcanicRock", base, Vector3.new(2, 1.5, 2), Enum.Material.Basalt, Color3.fromRGB(45, 28, 22))
				TweenService:Create(rock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = CFrame.new(base + offset * 5 + Vector3.new(0, 8 + i % 5, 0)) * CFrame.Angles(angle, angle, 1),
				}):Play()
				task.delay(0.4, function()
					TweenService:Create(rock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = base + offset * 9 + Vector3.new(0, -2, 0), Transparency = 1,
					}):Play()
				end)
				Debris:AddItem(rock, 0.9)
				local vent = piece("MagmaVent", base + Vector3.new(0, 0.1, 0), Vector3.new(1.2, 0.2, 3), Enum.Material.Neon, color)
				vent.CFrame *= CFrame.Angles(0, angle, 0)
				TweenService:Create(vent, TweenInfo.new(1), { Transparency = 1 }):Play()
				Debris:AddItem(vent, 1.1)
				env.burst(base, color, if low then 5 else 12, 28, 1)
			end
		end
		env.burst(target + Vector3.new(0, 1, 0), color, if low then 18 else 45, if frost then 22 else 38, if frost then 1 else 1.5)
	end)
end

return Fx
