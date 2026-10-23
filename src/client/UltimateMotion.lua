-- Coreografía por tiempo absoluto: el mismo movimiento a 30, 60 o 144 FPS.
local RunService = game:GetService("RunService")
local Motion = {}

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function phase(t: number, a: number, b: number): number
	return smooth((t - a) / math.max(b - a, 0.001))
end

function Motion.new(character: Model, u: any, origin: Vector3, dir: Vector3, ctx: any, poses: any)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local original = root.CFrame
	character:SetAttribute("UltimatePerforming", true)
	local visibility = {}
	local autoRotate = humanoid and humanoid.AutoRotate
	if humanoid then humanoid.AutoRotate = false end
	local animate = character:FindFirstChild("Animate") :: LocalScript?
	local animateEnabled = animate and animate.Enabled
	if animate then animate.Enabled = false end
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do track:Stop(0.15) end
	end
	local joints = {}
	local aliases = { RootJoint = "Root", ["Right Shoulder"] = "RightShoulder", ["Left Shoulder"] = "LeftShoulder",
		["Right Hip"] = "RightHip", ["Left Hip"] = "LeftHip" }
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
			table.insert(joints, { motor = item, name = aliases[item.Name] or item.Name, transform = item.Transform })
		end
	end
	local final = u.FinalAt or u.Duration - 0.6
	local first = u.FirstAt or 0.5
	local target = ctx.center or origin
	local f = Vector3.new(dir.X, 0, dir.Z)
	f = if f.Magnitude > 0.001 then f.Unit else Vector3.new(0, 0, -1)
	local side = f:Cross(Vector3.yAxis)
	local yaw = math.atan2(-f.X, -f.Z)
	local timeline
	if u.Line then
		timeline = { { 0, "readyBow" }, { first, "draw" }, { final - 0.15, "draw" }, { final + 0.12, "recoil" }, { u.Duration, "readyBow" } }
	elseif u.BlackHole then
		timeline = { { 0, "readyBow" }, { first, "aimSky" }, { first + 0.4, "hold" }, { final - 0.2, "hold" }, { final + 0.12, "clench" }, { u.Duration, "readyBow" } }
	elseif u.Leap then
		timeline = { { 0, "crouch" }, { 0.65, "raise" }, { final - 0.35, "raise" }, { final - 0.04, "plunge" }, { final + 0.12, "land" }, { u.Duration, "readySword" } }
	elseif u.Style == "Frost" then
		timeline = { { 0, "readySword" }, { 0.65, "frostWindup" }, { final - 0.4, "frostWindup" }, { final - 0.05, "frostCut" }, { final + 0.25, "frostCut" }, { u.Duration, "readySword" } }
	elseif u.Style == "Volcanic" then
		timeline = { { 0, "fistsReady" }, { 0.65, "fistsCharge" }, { final - 0.4, "fistsCharge" }, { final - 0.05, "groundPunch" }, { final + 0.25, "groundPunch" }, { u.Duration, "fistsReady" } }
	elseif u.Style == "Inferno" then
		timeline = { { 0, "readySword" }, { 0.65, "fireWindup" }, { final - 0.28, "fireWindup" }, { final, "fireStrike" }, { final + 0.25, "land" }, { u.Duration, "readySword" } }
	else
		timeline = { { 0, "readySword" }, { first - 0.08, "crouch" }, { first + 0.12, "dash" }, { final - 0.45, "sheath" }, { final + 0.1, "sheath" }, { u.Duration, "readySword" } }
	end
	local currentTime = 0
	local function samplePose(t: number)
		local a, b = timeline[1], timeline[#timeline]
		for i = 1, #timeline - 1 do
			if t <= timeline[i + 1][1] then a, b = timeline[i], timeline[i + 1]; break end
		end
		return poses[a[2]] or {}, poses[b[2]] or {}, phase(t, a[1], b[1])
	end
	-- PreSimulation corre después de Animator, evitando que la animación de caminar
	-- pise los brazos o produzca temblores durante la definitiva. Sirve en R6 y R15.
	local poseConnection = RunService.PreSimulation:Connect(function()
		local a, b, k = samplePose(currentTime)
		local fade = 1 - phase(currentTime, u.Duration - 0.2, u.Duration + 0.05)
		for _, joint in joints do
			if joint.motor.Parent then
				local cf = (a[joint.name] or CFrame.identity):Lerp(b[joint.name] or CFrame.identity, k)
				joint.motor.Transform = CFrame.identity:Lerp(cf, fade)
			end
		end
	end)
	local controller = {}
	function controller.Update(t: number)
		if not root.Parent or not character.Parent then return end
		currentTime = math.max(t, 0)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				if visibility[part] == nil then visibility[part] = part.LocalTransparencyModifier end
				part.LocalTransparencyModifier = 0
			end
		end
		local pos = origin
		local rotation = yaw
		if u.Leap then
			local up = phase(t, 0.2, 0.9)
			local down = phase(t, final - 0.35, final)
			pos += Vector3.new(0, (u.Leap.Height or 18) * up * (1 - down), 0)
			rotation += math.pi * 2 * phase(t, 0.2, 1.1)
		elseif u.Line then
			local recoil = phase(t, final, final + 0.12) * (1 - phase(t, final + 0.12, u.Duration))
			pos -= f * recoil * 1.1
		elseif not u.BlackHole and (u.Style or "Crimson") == "Crimson" then
			local path = ctx.path
			if path and #path > 0 and t >= first then
				local duration = 0.14 -- mismo ritmo que los tajos de worldSequence
				local index = math.floor((t - first) / duration) + 1
				local from = if index == 1 then origin else path[math.min(index - 1, #path)]
				local to = path[index] or origin
				if index <= #path + 1 then
					pos = from:Lerp(to, smooth(((t - first) % duration) / duration))
				else pos = origin end
			end
		end
		root.CFrame = CFrame.new(pos) * CFrame.Angles(0, rotation, 0)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	function controller.Camera(t: number, initial: CFrame, initialFov: number, aspect: number): (CFrame, number)
		-- Un encuadre estable muestra al lanzador, el trayecto y el blanco juntos.
		local endPoint = if u.Line then origin + f * u.Line.Length * 0.65 else target
		local midpoint = origin:Lerp(endPoint, 0.5) + Vector3.new(0, 2, 0)
		local spread = (endPoint - origin).Magnitude
		local portrait = math.max(1, 1 / math.max(aspect, 0.35))
		local distance = math.max(24, spread * 0.8 + u.Radius * 0.7) * portrait
		local cameraPos = midpoint - f * distance * 0.6 + side * distance * 0.8 + Vector3.new(0, distance * 0.65, 0)
		local wide = CFrame.lookAt(cameraPos, midpoint)
		local shoulder = CFrame.lookAt(origin - f * 9 + side * 5 + Vector3.new(0, 5, 0), origin + f * 6 + Vector3.new(0, 2, 0))
		local reveal = phase(t, first * 0.3, math.min(first + 0.65, final - 0.35))
		local cf = shoulder:Lerp(wide, reveal)
		-- Entrada y salida suaves, sin vueltas completas ni cambios de eje.
		cf = initial:Lerp(cf, phase(t, 0, 0.32))
		cf = cf:Lerp(initial, phase(t, u.Duration - 0.24, u.Duration + 0.1))
		local impact = math.exp(-math.max(0, t - final) * 10) * (if t >= final then 1 else 0)
		cf *= CFrame.new(math.sin(t * 53) * impact * 0.12, math.sin(t * 41) * impact * 0.08, 0)
		local fov = initialFov + (62 - initialFov) * phase(t, 0, 0.32)
		fov += impact * 2
		fov += (initialFov - fov) * phase(t, u.Duration - 0.24, u.Duration + 0.1)
		return cf, fov
	end
	function controller.Destroy()
		poseConnection:Disconnect()
		character:SetAttribute("UltimatePerforming", nil)
		for part, transparency in visibility do
			if part.Parent then part.LocalTransparencyModifier = transparency end
		end
		for _, joint in joints do
			if joint.motor.Parent then joint.motor.Transform = joint.transform end
		end
		if root.Parent then root.CFrame = original end
		if humanoid and humanoid.Parent then humanoid.AutoRotate = autoRotate end
		if animate and animate.Parent then animate.Enabled = animateEnabled end
	end
	return controller
end

return Motion
