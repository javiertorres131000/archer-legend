-- Rayos procedurales: no necesitan texturas importadas ni modifican el daño.
-- El perfil Effects de FxStyles permite reutilizarlos en otras armas.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local LightningFx = {}

function LightningFx.new(folder: Folder, low: boolean)
	local fx = {}
	local rng = Random.new()
	local function bolt(from: Vector3, to: Vector3, style: any, width: number, life: number, tint: Color3?)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - (from + to) / 2).Magnitude > 180 then return end
		local delta = to - from
		if delta.Magnitude < 0.05 then return end
		local frame = CFrame.lookAt(from, to)
		local n = if low then 4 else 7
		local previous = from
		for i = 1, n do
			local point = from + delta * (i / n)
			if i < n then
				local jitter = math.min(delta.Magnitude * 0.12, 1.5)
				point += frame.RightVector * rng:NextNumber(-jitter, jitter) + frame.UpVector * rng:NextNumber(-jitter, jitter)
			end
			local length = (point - previous).Magnitude
			for layer = 1, (if low then 1 else 2) do
				local p = Instance.new("Part")
				p.Name = "CelestialLightning"
				p.Anchored = true
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
				p.CastShadow = false
				p.Material = Enum.Material.Neon
				p.Color = if layer == 1 then (tint or style.Light) else style.Core
				local thickness = width * (if layer == 1 then 1 else 0.35)
				p.Size = Vector3.new(thickness, thickness, math.max(length, 0.01))
				p.CFrame = CFrame.lookAt((previous + point) / 2, point)
				p.Parent = folder
				TweenService:Create(p, TweenInfo.new(life), { Transparency = 1 }):Play()
				Debris:AddItem(p, life)
			end
			previous = point
		end
	end
	local function ground(pos: Vector3): Vector3
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { folder }
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(ignore, p.Character) end
		end
		for _ = 1, 5 do
			params.FilterDescendantsInstances = ignore
			local hit = workspace:Raycast(pos + Vector3.yAxis, -Vector3.yAxis * 45, params)
			if not hit then break end
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			local creature = model and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController"))
			if hit.Instance.Anchored and not creature then
				return hit.Position + Vector3.yAxis * 0.12
			end
			table.insert(ignore, model or hit.Instance)
		end
		return pos
	end
	local function spokes(center: Vector3, radius: number, style: any, count: number)
		local n = if low then math.ceil(count / 2) else count
		for i = 1, n do
			local a = i / n * math.pi * 2
			bolt(center, center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius, style, 0.14, 0.25, if i % 2 == 0 then style.Deep else style.Light)
		end
	end
	function fx.Slash(origin: Vector3, dir: Vector3, range: number, style: any, step: number)
		local flat = Vector3.new(dir.X, 0, dir.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		local center = origin + Vector3.yAxis * 1.1 + flat * range * 0.5
		local right = flat:Cross(Vector3.yAxis)
		-- Primer golpe: abanico eléctrico. Segundo: descarga recta que atraviesa el tajo.
		if step == 1 then
			for i = -1, 1 do
				bolt(origin + Vector3.yAxis, center + right * i * range * 0.4, style, 0.16, 0.22)
			end
		elseif step == 2 then
			bolt(center - right * range * 0.65 - Vector3.yAxis, center + right * range * 0.65 + Vector3.yAxis, style, 0.23, 0.28)
		else
			bolt(center + Vector3.yAxis * 7, center - Vector3.yAxis, style, 0.3, 0.25)
		end
	end
	function fx.Hit(pos: Vector3, style: any, crit: boolean)
		-- Ramificaciones locales; no simulan saltos hacia enemigos que no recibieron daño.
		local n = if low then 2 else (if crit then 6 else 3)
		for _ = 1, n do
			local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1))
			bolt(pos, pos + offset * (if crit then 3.5 else 2), style, 0.12, 0.2)
		end
	end
	function fx.Spin(origin: Vector3, range: number, style: any)
		local center = ground(origin)
		local n = if low then 6 else 10
		local previous = center + Vector3.xAxis * range * 0.75
		for i = 1, n do
			local a = i / n * math.pi * 2
			local point = center + Vector3.new(math.cos(a), 0, math.sin(a)) * range * 0.75
			bolt(previous, point, style, 0.2, 0.35)
			previous = point
		end
		spokes(center, range * 0.75, style, 6)
	end
	function fx.Finisher(origin: Vector3, dir: Vector3, range: number, style: any)
		local flat = Vector3.new(dir.X, 0, dir.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
		local at = ground(origin + flat * range * 0.45)
		bolt(at + Vector3.yAxis * 18, at, style, 0.45, 0.35)
		spokes(at, range * 0.5, style, 8)
	end
	function fx.Judgment(pos: Vector3, radius: number, style: any)
		local at = ground(pos)
		-- Un rayo central y una corona de descargas, diferente de la esfera Carmesí.
		bolt(at + Vector3.yAxis * 32, at, style, 0.65, 0.4)
		spokes(at, radius, style, 10)
		local n = if low then 3 else 6
		for i = 1, n do
			local a = i / n * math.pi * 2
			local point = at + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.8
			task.delay(i * 0.035, function()
				bolt(point + Vector3.yAxis * 20, point, style, 0.25, 0.25)
			end)
		end
	end
	function fx.Aura(part: BasePart, style: any)
		local size = part.Size
		local axis = if size.Y >= size.X and size.Y >= size.Z then Vector3.yAxis elseif size.X >= size.Z then Vector3.xAxis else Vector3.zAxis
		local half = axis * math.max(size.X, size.Y, size.Z) * 0.45
		bolt(part.CFrame:PointToWorldSpace(-half), part.CFrame:PointToWorldSpace(half), style, 0.045, 0.12)
	end
	function fx.ArrowLaunch(pos: Vector3, dir: Vector3, style: any, charged: boolean)
		local right = dir:Cross(Vector3.yAxis)
		if right.Magnitude < 0.01 then right = Vector3.xAxis else right = right.Unit end
		local radius = if charged then 2.2 else 0.8
		for _, side in { -1, 1 } do
			bolt(pos + right * radius * side, pos + dir * 2.5, style, 0.12, 0.18)
		end
	end
	function fx.ArrowFlight(pos: Vector3, dir: Vector3, style: any, scale: number)
		-- Segmentos cortos y espaciados: conserva una silueta de flecha, con electricidad detrás.
		bolt(pos + dir * scale, pos - dir * 3 * scale, style, 0.08 * math.min(scale, 2), 0.14, style.Deep)
	end
	return fx
end

return LightningFx
