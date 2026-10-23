-- Portales y grietas con centro oscuro; comparte la interfaz de proyectiles con LightningFx.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VoidFx = {}

function VoidFx.new(folder: Folder, low: boolean)
	local fx = {}
	local function line(a: Vector3, b: Vector3, color: Color3, width: number, life: number)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - a).Magnitude > 180 then return end
		if (b - a).Magnitude < 0.01 then return end
		local p = Instance.new("Part")
		p.Name = "VoidRift"
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(width, width, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = folder
		TweenService:Create(p, TweenInfo.new(life), { Transparency = 1, Size = Vector3.new(0.01, 0.01, p.Size.Z * 1.15) }):Play()
		Debris:AddItem(p, life)
		return p
	end
	local function ring(cf: CFrame, radius: number, style: any, life: number)
		local n = if low then 6 else 10
		for i = 1, n do
			local a, b = (i - 1) / n * math.pi * 2, i / n * math.pi * 2
			local p = line(cf:PointToWorldSpace(Vector3.new(math.cos(a), math.sin(a), 0) * radius), cf:PointToWorldSpace(Vector3.new(math.cos(b), math.sin(b), 0) * radius), style.Light, 0.06, life)
			if p then
				local localFrame = cf:ToObjectSpace(p.CFrame)
				local target = cf * CFrame.Angles(0, 0, 0.65) * (localFrame.Rotation + localFrame.Position * 1.7)
				TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = target, Size = Vector3.new(0.015, 0.015, p.Size.Z * 1.7), Transparency = 1,
				}):Play()
			end
		end
	end
	local function implosion(pos: Vector3, style: any, size: number)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - pos).Magnitude > 180 then return end
		local core = Instance.new("Part")
		core.Name = "VoidImplosion"
		core.Shape = Enum.PartType.Ball
		core.Material = Enum.Material.SmoothPlastic
		core.Color = style.Core
		core.Anchored = true
		core.CanCollide = false
		core.CanQuery = false
		core.CanTouch = false
		core.CastShadow = false
		core.Size = Vector3.one * size
		core.Position = pos
		core.Parent = folder
		TweenService:Create(core, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.one * 0.05, Transparency = 1 }):Play()
		Debris:AddItem(core, 0.32)
	end
	function fx.ArrowLaunch(pos: Vector3, dir: Vector3, style: any, charged: boolean)
		local cf = CFrame.lookAt(pos + dir * 1.5, pos + dir * 2.5)
		ring(cf, if charged then 1.5 else 0.8, style, 0.38)
		if not low then ring(cf * CFrame.new(0, 0, -0.6) * CFrame.Angles(0, 0, 0.3), if charged then 1 else 0.5, style, 0.3) end
		if charged then
			implosion(pos + dir * 2, style, 1.4)
			for _, side in { -1, 1 } do
				line(cf:PointToWorldSpace(Vector3.new(side * 2, -1, 0)), cf:PointToWorldSpace(Vector3.new(-side * 2, 1, 0)), style.Light, 0.15, 0.35)
			end
		end
	end
	function fx.ArrowFlight(pos: Vector3, dir: Vector3, style: any, scale: number)
		local cf = CFrame.lookAt(pos, pos + dir)
		for _, side in { -1, 1 } do
			local phase = os.clock() * 14 + (if side == 1 then 0 else math.pi)
			local radius = 0.3 * scale
			local a = cf:PointToWorldSpace(Vector3.new(math.cos(phase) * radius, math.sin(phase) * radius, 0))
			local mid = cf:PointToWorldSpace(Vector3.new(math.cos(phase + 1.4) * radius, math.sin(phase + 1.4) * radius, scale))
			local b = cf:PointToWorldSpace(Vector3.new(math.cos(phase + 2.8) * radius, math.sin(phase + 2.8) * radius, 2 * scale))
			line(a, mid, style.Light, 0.09, 0.24)
			line(mid, b, style.Deep, 0.11, 0.24)
		end
	end
	function fx.Hit(pos: Vector3, style: any, crit: boolean)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local cf = CFrame.lookAt(pos, camera.CFrame.Position)
		local size = if crit then 2.8 else 1.6
		ring(cf, size * 0.7, style, 0.4)
		implosion(pos, style, if crit then 2.4 else 1.3)
		local n = if low then 2 else 4
		for i = 1, n do
			local a = i / n * math.pi * 2 + 0.4
			local mid = cf:PointToWorldSpace(Vector3.new(math.cos(a + 0.3), math.sin(a + 0.3), 0) * size * 0.5)
			local tip = cf:PointToWorldSpace(Vector3.new(math.cos(a), math.sin(a), 0) * size)
			line(pos, mid, style.Light, 0.16, 0.3)
			line(mid, tip, style.Light, 0.1, 0.3)
			if not low then line(pos, mid, style.Core, 0.07, 0.22) end
			local shard = line(tip, tip + cf.UpVector * 0.45, style.Light, 0.14, 0.4)
			if shard then
				TweenService:Create(shard, TweenInfo.new(0.4), { CFrame = shard.CFrame + (tip - pos) * 0.8, Transparency = 1 }):Play()
			end
		end
	end
	function fx.Aura(part: BasePart, style: any)
		ring(part.CFrame, math.min(part.Size.Magnitude * 0.15, 0.3), style, 0.2)
	end
	return fx
end

return VoidFx
