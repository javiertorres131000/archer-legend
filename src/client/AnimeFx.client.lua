-- AnimeFx (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > AnimeFx
-- Efectos estilo anime (cel-shading con contorno oscuro) para las armas que tienen un estilo
-- (campo Fx en Shared/Weapons.lua → Shared/FxStyles.lua). Es solo visual: el daño ya lo
-- calculó el servidor. Escucha los mismos avisos que MeleeVisuals, que se hace a un lado
-- cuando el arma tiene estilo.
--
--   · Tajo: media luna con contorno que barre el arco del golpe (inclinada, alterna de lado),
--     con un segundo tajo fino detrás.
--   · Torbellino (golpe de 360°): remolino de tres anillos que giran en sentidos opuestos,
--     con llamas en los pies, líneas de velocidad y humo.
--   · Juicio (de una espada especial): círculo ornamental en el piso, columna de energía, onda
--     expansiva, llamas y humo.
--   · Impacto (tus golpes): llamarada, destello y líneas de velocidad; humo en los críticos.
--   · Aura: llamas suaves saliendo de la hoja en primera persona y de la mano en tercera
--     (también en tus compañeros que usan un arma con estilo).
--   · Estilos con BodyAura (Carmesí): además, llamas envolviendo a todo el personaje.
--   · Estilos con Burst (Carmesí): el Juicio y el remate del combo son una esfera gigante que
--     crece y explota, con onda, llamas y la pantalla teñida un instante si estás cerca.
--
-- En calidad baja (FxQuality) hay menos partículas, menos anillos y sin aura en primera persona.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local FxStyles = require(Shared:WaitForChild("FxStyles"))
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local SwingCombo = require(script.Parent:WaitForChild("SwingCombo"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local meleeSwing = remotes:WaitForChild("MeleeSwing") :: RemoteEvent
local combatText = remotes:WaitForChild("CombatText") :: RemoteEvent

local player = Players.LocalPlayer
local low = FxQuality.isLow()

local folder = Instance.new("Folder")
folder.Name = "AnimeFx"
folder.Parent = workspace

local lightning = require(script.Parent:WaitForChild("LightningFx")).new(folder, low)
local void = require(script.Parent:WaitForChild("VoidFx")).new(folder, low)

-- Los estilos pueden combinar efectos por evento sin depender de una variante completa.
local function usesLightning(style: any, event: string): boolean
	return style ~= nil and style.Effects ~= nil and style.Effects[event] == "Lightning"
end

local TAU = math.pi * 2

-- Precarga las texturas de los estilos: sin esto, el primer efecto sale blanco mientras bajan
task.spawn(function()
	local list = {}
	for _, style in FxStyles.Styles do
		for _, id in style.Textures do
			if type(id) == "string" and id ~= "" then
				table.insert(list, id)
			end
		end
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------

local function styleOf(weaponId: any): any
	local def = type(weaponId) == "string" and Weapons.ById[weaponId] or nil
	return def and FxStyles.get(def.Fx) or nil
end

-- Animaciones por cuadro: update(alpha 0..1, dt); al terminar, done()
type Anim = { t0: number, dur: number, update: (number, number) -> (), done: (() -> ())? }
local anims: { Anim } = {}

local function animate(dur: number, update: (number, number) -> (), done: (() -> ())?)
	table.insert(anims, { t0 = os.clock(), dur = dur, update = update, done = done })
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #anims, 1, -1 do
		local a = anims[i]
		local alpha = math.clamp((now - a.t0) / a.dur, 0, 1)
		local ok, err = pcall(a.update, alpha, dt)
		if not ok then
			warn("[AnimeFx]", err)
			alpha = 1
		end
		if alpha >= 1 then
			table.remove(anims, i)
			if a.done then
				pcall(a.done)
			end
		end
	end
end)

local function holder(cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = "FxHolder"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

local function seq(a: number, b: number?): NumberSequence
	return NumberSequence.new(a, b or a)
end

---------------------------------------------------------------------
-- Partículas
---------------------------------------------------------------------

-- Cada tipo: textura del estilo + cómo se mueve. Todas sin LightEmission para que el contorno
-- oscuro se vea (con LightEmission el negro se vuelve transparente).
local function emitter(parent: Instance, style: any, kind: string, scale: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 0
	e.LightInfluence = 0
	e.Brightness = 1.2
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Rotation = NumberRange.new(-20, 20)
	e.ZOffset = 1
	local texKey = if kind == "Speed" then "Speedline" else kind
	local tex, custom = FxStyles.texture(style, texKey)
	e.Texture = tex
	if not custom then
		e.Color = ColorSequence.new(style.Light)
		e.LightEmission = 0.6
	end
	if kind == "Flame" then
		if custom then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		e.Lifetime = NumberRange.new(0.45, 0.6)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.6 * scale),
			NumberSequenceKeypoint.new(1, 2.4 * scale),
		})
		e.Speed = NumberRange.new(4 * scale, 9 * scale)
		e.Acceleration = Vector3.new(0, 10 * scale, 0)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Drag = 3
		e.Rotation = NumberRange.new(-12, 12)
	elseif kind == "Smoke" then
		if custom then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		e.Lifetime = NumberRange.new(0.7, 0.95)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8 * scale),
			NumberSequenceKeypoint.new(1, 3.2 * scale),
		})
		e.Speed = NumberRange.new(6 * scale, 14 * scale)
		e.Drag = 5
		e.SpreadAngle = Vector2.new(180, 60)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.ZOffset = 0.5
	elseif kind == "Star" then
		e.Lifetime = NumberRange.new(0.14, 0.18)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * scale),
			NumberSequenceKeypoint.new(0.3, 3.2 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Speed = NumberRange.new(0)
		e.Rotation = NumberRange.new(0, 45)
		e.ZOffset = 2
	elseif kind == "Speed" then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Lifetime = NumberRange.new(0.12, 0.2)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35 * scale),
			NumberSequenceKeypoint.new(1, 0.05 * scale),
		})
		e.Squash = seq(-1.6) -- negativo = más largo que ancho
		e.Speed = NumberRange.new(28 * scale, 46 * scale)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0)
		e.ZOffset = 1.5
	end
	e.Parent = parent
	return e
end

-- Suelta partículas en un punto del mundo y se limpia sola
local function burst(pos: Vector3, style: any, list: { { kind: string, count: number, scale: number? } })
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local longest = 0
	for _, it in list do
		local n = if low then math.ceil(it.count / 2) else it.count
		if n > 0 then
			local e = emitter(att, style, it.kind, it.scale or 1)
			e:Emit(n)
			longest = math.max(longest, e.Lifetime.Max)
		end
	end
	Debris:AddItem(att, longest + 0.2)
end

---------------------------------------------------------------------
-- Beams en arco (curvas de Bézier que aproximan un arco de círculo)
---------------------------------------------------------------------

type Arc = { beams: { Beam }, atts: { Attachment }, segs: number }

local function makeBeam(h: Part, style: any, texKey: string, wrap: boolean): (Beam, Attachment, Attachment)
	local a0 = Instance.new("Attachment")
	a0.Parent = h
	local a1 = Instance.new("Attachment")
	a1.Parent = h
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Segments = if low then 12 else 24
	b.LightEmission = 0
	b.LightInfluence = 0
	b.Brightness = 1.2
	b.ZOffset = 0
	local tex, custom = FxStyles.texture(style, texKey)
	b.Texture = tex
	if wrap then
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 10
	else
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
	end
	if not custom then
		b.Color = ColorSequence.new(style.Light)
		b.LightEmission = 0.7
	end
	b.Parent = h
	return b, a0, a1
end

local function newArc(h: Part, style: any, texKey: string, segs: number, wrap: boolean): Arc
	local arc: Arc = { beams = {}, atts = {}, segs = segs }
	for _ = 1, segs do
		local b, a0, a1 = makeBeam(h, style, texKey, wrap)
		table.insert(arc.beams, b)
		table.insert(arc.atts, a0)
		table.insert(arc.atts, a1)
	end
	return arc
end

-- Ubica el arco: centro y orientación en cf (ángulo 0 = LookVector, crece hacia RightVector)
local function placeArc(arc: Arc, cf: CFrame, radius: number, from: number, to: number)
	local look, right, up = cf.LookVector, cf.RightVector, cf.UpVector
	local step = (to - from) / arc.segs
	local k = 4 / 3 * math.tan(step / 4) * radius
	for i = 1, arc.segs do
		local a = from + (i - 1) * step
		local b = a + step
		local function frame(ang: number): CFrame
			local p = cf.Position + (look * math.cos(ang) + right * math.sin(ang)) * radius
			local tan = -look * math.sin(ang) + right * math.cos(ang)
			if step < 0 then
				tan = -tan
			end
			return CFrame.fromMatrix(p, tan, up)
		end
		arc.atts[i * 2 - 1].WorldCFrame = frame(a)
		arc.atts[i * 2].WorldCFrame = frame(b)
		local beam = arc.beams[i]
		beam.CurveSize0 = math.abs(k)
		beam.CurveSize1 = math.abs(k)
	end
end

local function styleArc(arc: Arc, width: number, transparency: number, speed: number?)
	for _, b in arc.beams do
		b.Width0 = width
		b.Width1 = width
		b.Transparency = seq(transparency)
		if speed then
			b.TextureSpeed = speed
		end
	end
end

---------------------------------------------------------------------
-- Tajo
---------------------------------------------------------------------

local function slash(userId: number, origin: Vector3, dir: Vector3, range: number, arc: number, style: any)
	-- Lado e inclinación según el paso del combo (coincide con la animación del arma)
	local step = SwingCombo.step(userId)
	local side = SwingCombo.side(step)
	local tilt = SwingCombo.tilt(step)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	-- El tuyo en primera persona: cerca y a la altura de los ojos, así cruza la pantalla en diagonal
	local mine = userId == player.UserId and player:GetAttribute("CameraView") == "FirstPerson"
	local center = origin + Vector3.new(0, if mine then 1.1 else 0.7, 0)
	local cf = CFrame.lookAt(center, center + flat) * CFrame.Angles(0, 0, math.rad(tilt * (if mine then 1 else 0.8)))
	local radius = if mine then 4.2 else range * 0.72
	local half = math.rad(math.clamp(arc, 40, 200) / 2)
	-- de un lado al otro según el lado del golpe
	local from, to = -half * side, half * side
	local h = holder(CFrame.new(center))
	local main = newArc(h, style, "Slash", 1, false)
	local thin = newArc(h, style, "Slash", 1, false)
	local W = if mine then 1.4 else math.clamp(range * 0.45, 2.5, 6)
	animate(0.34, function(t)
		local sweep = easeOut(math.clamp(t / 0.4, 0, 1))
		local fade = math.clamp((t - 0.35) / 0.65, 0, 1)
		local r = radius * (1 + 0.12 * easeOut(t))
		placeArc(main, cf, r, from, lerp(from, to, sweep))
		styleArc(main, W * (1 - 0.5 * fade), fade ^ 0.7)
		local sweep2 = easeOut(math.clamp((t - 0.08) / 0.45, 0, 1))
		placeArc(thin, cf * CFrame.Angles(0, 0, math.rad(-10 * side)), r * 1.12, from, lerp(from, to, sweep2))
		styleArc(thin, W * 0.35 * (1 - fade), math.max(fade, 1 - sweep2 * 4) ^ 0.7)
	end, function()
		h:Destroy()
	end)
end

---------------------------------------------------------------------
-- Torbellino (remolino)
---------------------------------------------------------------------

local function vortex(userId: number, origin: Vector3, range: number, style: any)
	-- El tuyo en primera persona: más bajo, fino y transparente para no tapar la vista
	local mine = userId == player.UserId and player:GetAttribute("CameraView") == "FirstPerson"
	local base = origin + Vector3.new(0, if mine then -1.4 else -0.6, 0)
	local h = holder(CFrame.new(base))
	local tiers = {
		{ y = -1.2, r = 0.55, tilt = 14, w = 2.4, spin = 9 },
		{ y = 0.6, r = 0.85, tilt = -10, w = 3.2, spin = -7 },
		{ y = 2.6, r = 0.68, tilt = 8, w = 2.2, spin = 11 },
	}
	if low or mine then
		table.remove(tiers, 3)
	end
	local widthMult = if mine then 0.55 else 1
	local minAlpha = if mine then 0.35 else 0
	local rings = {}
	for i, tier in tiers do
		local dark = newArc(h, style, "Swirl", 4, true)
		local streak = newArc(h, style, "Slash", 1, false)
		table.insert(rings, { tier = tier, dark = dark, streak = streak, rot = math.random() * TAU, phase = i })
	end
	local R = math.max(range, 6)
	animate(0.75, function(t, dt)
		local grow = easeOut(math.clamp(t / 0.3, 0, 1))
		local fade = math.clamp((t - 0.55) / 0.45, 0, 1)
		for _, ring in rings do
			local tier = ring.tier
			ring.rot += tier.spin * dt * (1.2 - 0.6 * t)
			local cf = CFrame.new(base + Vector3.new(0, tier.y, 0))
				* CFrame.Angles(math.rad(tier.tilt), ring.rot, math.rad(tier.tilt * 0.5))
			local r = R * tier.r * (0.55 + 0.45 * grow)
			placeArc(ring.dark, cf, r, 0, TAU)
			styleArc(ring.dark, tier.w * widthMult * (1 - 0.6 * fade), math.max(fade, minAlpha), 6 * math.sign(tier.spin))
			placeArc(ring.streak, cf, r * 1.06, 0.4, 0.4 + math.rad(150))
			styleArc(ring.streak, tier.w * widthMult * 0.55 * (1 - fade), math.max(fade, 0.05))
		end
	end, function()
		h:Destroy()
	end)
	-- llamas alrededor de los pies, líneas de velocidad y humo
	local n = if low then 4 else 8
	for i = 1, n do
		local a = i / n * TAU
		local p = base + Vector3.new(math.cos(a), 0, math.sin(a)) * R * 0.6
		burst(p, style, { { kind = "Flame", count = 1, scale = 1.1 } })
	end
	burst(origin + Vector3.new(0, 0.8, 0), style, {
		{ kind = "Speed", count = 14, scale = 1 },
		{ kind = "Smoke", count = 5, scale = 1.2 },
		{ kind = "Star", count = 1, scale = 1.4 },
	})
end

---------------------------------------------------------------------
-- Juicio (círculo en el piso + columna)
---------------------------------------------------------------------

local function groundY(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _ = 1, 5 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -40, 0), params)
		if not hit then
			break
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local isCreature = model and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController"))
		if hit.Instance.Anchored and not isCreature then
			return hit.Position.Y
		end
		table.insert(ignore, model or hit.Instance)
	end
	return pos.Y - 2.5
end

local function decalPart(style: any, texKey: string, cf: CFrame, size: number): (Part, Decal)
	local p = holder(cf)
	p.Size = Vector3.new(size, 0.05, size)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	local tex, custom = FxStyles.texture(style, texKey)
	d.Texture = tex
	if not custom then
		d.Color3 = style.Light
	end
	d.Parent = p
	return p, d
end

-- Esfera que crece y explota (estilos con Burst). big: el Juicio (más grande y con columna)
local function sphereBurst(pos: Vector3, radius: number, style: any, big: boolean)
	local ground = Vector3.new(pos.X, groundY(pos) + 0.6, pos.Z)
	local R = math.max(radius, 4) * (if big then 1.1 else 0.75)
	local center = ground + Vector3.new(0, R * 0.35, 0)
	local function ball(color: Color3, material: Enum.Material, transparency: number): Part
		local b = holder(CFrame.new(center))
		b.Shape = Enum.PartType.Ball
		b.Material = material
		b.Color = color
		b.Transparency = transparency
		b.Size = Vector3.one
		return b
	end
	-- Cáscara de energía, núcleo claro y un borde oscuro de contorno (look cel-shading)
	local shell = ball(style.Light, Enum.Material.Neon, 0.25)
	local core = ball(style.Core or Color3.new(1, 1, 1), Enum.Material.Neon, 0.1)
	local rim = ball(style.Deep or style.Light, Enum.Material.ForceField, 0)
	local grow = if big then 0.4 else 0.28
	animate(grow + 0.35, function(t)
		local g = math.clamp(t / (grow / (grow + 0.35)), 0, 1)
		local fade = math.clamp((t - grow / (grow + 0.35)) / (1 - grow / (grow + 0.35)), 0, 1)
		local s = R * 2 * (0.15 + 0.85 * easeOut(g)) * (1 + 0.15 * fade)
		shell.Size = Vector3.one * s
		rim.Size = Vector3.one * s * 1.06
		core.Size = Vector3.one * s * (0.55 - 0.4 * fade)
		shell.Transparency = 0.25 + 0.75 * fade
		core.Transparency = 0.1 + 0.9 * fade
		rim.Transparency = fade
	end, function()
		shell:Destroy()
		core:Destroy()
		rim:Destroy()
	end)
	-- Onda en el piso
	local ring, ringDecal = decalPart(style, "Ring", CFrame.new(ground), R)
	animate(0.55, function(t)
		local s = R * (1 + 2.2 * easeOut(t))
		ring.Size = Vector3.new(s, 0.05, s)
		ringDecal.Transparency = t ^ 1.4
	end, function()
		ring:Destroy()
	end)
	if big then
		local circle, circleDecal = decalPart(style, "Circle", CFrame.new(ground + Vector3.new(0, 0.02, 0)), R * 2.4)
		animate(1, function(t, dt)
			circle.CFrame *= CFrame.Angles(0, dt * 2, 0)
			circleDecal.Transparency = math.clamp((t - 0.5) / 0.5, 0, 1)
		end, function()
			circle:Destroy()
		end)
	end
	-- Llamas alrededor, humo, chispas y destello
	local n = if low then 5 else (if big then 12 else 8)
	for i = 1, n do
		local a = i / n * TAU
		burst(ground + Vector3.new(math.cos(a), 0.6, math.sin(a)) * R * 0.9, style, {
			{ kind = "Flame", count = 1, scale = if big then 1.8 else 1.3 },
		})
	end
	burst(center, style, {
		{ kind = "Smoke", count = if big then 10 else 6, scale = 1.6 },
		{ kind = "Speed", count = if big then 16 else 10, scale = 1.4 },
		{ kind = "Star", count = 1, scale = if big then 3 else 2.2 },
	})
	local light = Instance.new("PointLight")
	light.Color = style.Light
	light.Range = R * 3
	light.Brightness = 5
	light.Parent = ring
	-- Pantalla teñida si la explosión es cerca tuyo
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if root and camera and (root.Position - center).Magnitude <= R * 3 and not low then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.TintColor = style.BurstTint or style.Light
		cc.Saturation = 0.3
		cc.Contrast = 0.25
		cc.Parent = camera
		animate(0.45, function(t)
			cc.TintColor = (style.BurstTint or style.Light):Lerp(Color3.new(1, 1, 1), t)
		end, function()
			cc:Destroy()
		end)
	end
end

local meteor: (Vector3, number, any) -> ()
local thornRing: (Vector3, number, any, number) -> ()

local function judgment(pos: Vector3, radius: number, style: any)
	if usesLightning(style, "Judgment") then
		lightning.Judgment(pos, radius, style)
		return
	end
	if style.Variant == "Inferno" then
		meteor(pos, radius, style)
		return
	end
	if style.Burst then
		sphereBurst(pos, radius, style, true)
		if style.Variant == "Crimson" then
			task.delay(0.2, function()
				thornRing(pos, math.max(radius, 4) * 1.3, style, 14)
			end)
		end
		return
	end
	local y = groundY(pos)
	-- un poco por encima del piso para que el pasto alto no tape el círculo
	local ground = Vector3.new(pos.X, y + 0.6, pos.Z)
	local R = math.max(radius, 4)
	-- círculo ornamental
	local circle, circleDecal = decalPart(style, "Circle", CFrame.new(ground), R * 2)
	local spin = 0
	animate(1.4, function(t, dt)
		spin += dt * (2.5 - 1.8 * t)
		local s = R * 2 * (0.3 + 0.7 * easeOut(math.clamp(t / 0.15, 0, 1)))
		circle.Size = Vector3.new(s, 0.05, s)
		circle.CFrame = CFrame.new(ground) * CFrame.Angles(0, spin, 0)
		circleDecal.Transparency = math.clamp((t - 0.6) / 0.4, 0, 1)
	end, function()
		circle:Destroy()
	end)
	-- impacto un instante después (cuando "cae" el golpe)
	task.delay(0.18, function()
		-- onda expansiva
		local ring, ringDecal = decalPart(style, "Ring", CFrame.new(ground + Vector3.new(0, 0.05, 0)), R)
		animate(0.5, function(t)
			local s = R * (1 + 1.8 * easeOut(t))
			ring.Size = Vector3.new(s, 0.05, s)
			ringDecal.Transparency = t ^ 1.5
		end, function()
			ring:Destroy()
		end)
		-- columna
		local h = holder(CFrame.new(ground))
		local col, a0, a1 = makeBeam(h, style, "Swirl", true)
		local core, c0, c1 = makeBeam(h, style, "Speedline", false)
		local top = ground + Vector3.new(0, 34, 0)
		a0.WorldCFrame = CFrame.lookAt(ground, top)
		a1.WorldCFrame = CFrame.lookAt(top, top + Vector3.yAxis)
		c0.WorldCFrame = a0.WorldCFrame
		c1.WorldCFrame = a1.WorldCFrame
		col.TextureLength = 12
		col.TextureSpeed = -4
		animate(0.6, function(t)
			local w = R * 0.9 * (1 - easeOut(t)) + 0.2
			col.Width0 = w
			col.Width1 = w * 0.35
			col.Transparency = seq(t ^ 1.3)
			core.Width0 = w * 0.35
			core.Width1 = w * 0.1
			core.Transparency = seq(t)
		end, function()
			h:Destroy()
		end)
		-- llamas en el borde, humo hacia afuera y destello
		local n = if low then 5 else 10
		for i = 1, n do
			local a = i / n * TAU
			burst(ground + Vector3.new(math.cos(a), 0.5, math.sin(a)) * R * 0.85, style, {
				{ kind = "Flame", count = 1, scale = 1.5 },
			})
		end
		burst(ground + Vector3.new(0, 1, 0), style, {
			{ kind = "Smoke", count = 8, scale = 1.6 },
			{ kind = "Speed", count = 12, scale = 1.3 },
			{ kind = "Star", count = 1, scale = 2.4 },
		})
		local light = Instance.new("PointLight")
		light.Color = style.Light
		light.Range = R * 2.5
		light.Brightness = 4
		light.Parent = h
	end)
end

-- Remate del combo (paso 3): la hoja pega contra el piso adelante: onda, llamas y humo
local eruption: (Vector3, Vector3, number, any) -> ()

local function finisher(origin: Vector3, dir: Vector3, range: number, style: any)
	if usesLightning(style, "Finisher") then
		lightning.Finisher(origin, dir, range, style)
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local at = origin + flat * math.max(range * 0.45, 3)
	if style.Variant == "Inferno" then
		eruption(origin, dir, range, style)
		return
	end
	if style.Burst then
		sphereBurst(at, range * 0.5, style, false)
		return
	end
	local ground = Vector3.new(at.X, groundY(at) + 0.6, at.Z)
	local R = math.max(range * 0.5, 4)
	local ring, ringDecal = decalPart(style, "Ring", CFrame.new(ground), R * 0.6)
	animate(0.4, function(t)
		local s = R * (0.6 + 1.6 * easeOut(t))
		ring.Size = Vector3.new(s, 0.05, s)
		ringDecal.Transparency = t ^ 1.4
	end, function()
		ring:Destroy()
	end)
	local n = if low then 3 else 6
	for i = 1, n do
		local a = i / n * TAU
		burst(ground + Vector3.new(math.cos(a), 0.3, math.sin(a)) * R * 0.45, style, {
			{ kind = "Flame", count = 1, scale = 1.2 },
		})
	end
	burst(ground + Vector3.new(0, 0.8, 0), style, {
		{ kind = "Smoke", count = 6, scale = 1.3 },
		{ kind = "Speed", count = 10, scale = 1.1 },
		{ kind = "Star", count = 1, scale = 2 },
	})
end

---------------------------------------------------------------------
-- Efectos propios de cada estilo (Variant en FxStyles): no son un cambio de color, cada arma
-- tiene su forma de pegar.
--   Inferno: el tajo deja fuego en el piso, el remate hace erupciones de fuego en línea, el
--     torbellino levanta un tornado de fuego, el Juicio es un meteorito y cada golpe explota.
--   Crimson: el tajo deja un corte en el aire que se rompe en esquirlas, los golpes marcan una
--     X, el torbellino hace brotar espinas del piso y el Juicio suma un anillo de espinas.
---------------------------------------------------------------------

local function solidPart(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = holder(cf)
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = 0
	return p
end

-- Inferno · fuego que queda en el piso a lo largo del tajo
local function fireTrail(origin: Vector3, dir: Vector3, range: number, arc: number, style: any)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local half = math.rad(math.clamp(arc, 40, 200) / 2)
	local n = if low then 3 else 6
	for wave = 0, 1 do
		task.delay(wave * 0.18, function()
			for i = 0, n - 1 do
				local a = -half + (i + 0.5) / n * 2 * half
				local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(flat)
				local at = origin + d * range * 0.7
				burst(Vector3.new(at.X, groundY(at) + 0.5, at.Z), style, {
					{ kind = "Flame", count = 1, scale = 0.8 + 0.3 * wave },
				})
			end
		end)
	end
end

-- Inferno · columna de fuego (erupción / tornado)
local function firePillar(ground: Vector3, height: number, width: number, dur: number, style: any, spin: number?)
	local h = holder(CFrame.new(ground))
	local col, a0, a1 = makeBeam(h, style, "Swirl", true)
	local top = ground + Vector3.new(0, height, 0)
	a0.WorldCFrame = CFrame.lookAt(ground, top)
	a1.WorldCFrame = CFrame.lookAt(top, top + Vector3.yAxis)
	col.TextureLength = height * 0.8
	col.TextureSpeed = spin or 3
	col.FaceCamera = true
	animate(dur, function(t)
		local rise = easeOut(math.clamp(t / 0.25, 0, 1))
		a1.WorldCFrame = CFrame.lookAt(ground + Vector3.new(0, height * rise, 0), top + Vector3.yAxis)
		col.Width0 = width * (1 - 0.3 * t)
		col.Width1 = width * 0.55 * (1 - t)
		col.Transparency = seq(math.clamp((t - 0.55) / 0.45, 0, 1))
	end, function()
		h:Destroy()
	end)
end

function eruption(origin: Vector3, dir: Vector3, range: number, style: any)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local count = if low then 2 else 4
	for i = 1, count do
		task.delay(i * 0.06, function()
			local at = origin + flat * (2 + range * 0.9 * i / count)
			local ground = Vector3.new(at.X, groundY(at), at.Z)
			firePillar(ground, 7 + i, 2.6 + i * 0.4, 0.5, style, 5)
			burst(ground + Vector3.new(0, 1, 0), style, {
				{ kind = "Star", count = 1, scale = 1.4 },
				{ kind = "Smoke", count = 2, scale = 0.9 },
			})
		end)
	end
end

function meteor(pos: Vector3, radius: number, style: any)
	local ground = Vector3.new(pos.X, groundY(pos), pos.Z)
	local R = math.max(radius, 4)
	local from = ground + Vector3.new(-14, 46, -10)
	local rock = solidPart(Vector3.one * 3.2, CFrame.new(from), style.Light)
	rock.Shape = Enum.PartType.Ball
	local shell = solidPart(Vector3.one * 4.2, CFrame.new(from), style.Deep or style.Light, Enum.Material.ForceField)
	shell.Shape = Enum.PartType.Ball
	local fall = 0.38
	animate(fall, function(t)
		local p = from:Lerp(ground + Vector3.new(0, 1.5, 0), t ^ 1.6)
		rock.CFrame = CFrame.new(p)
		shell.CFrame = CFrame.new(p)
		if not low and math.random() < 0.6 then
			burst(p, style, { { kind = "Flame", count = 1, scale = 1.1 } })
		end
	end, function()
		rock:Destroy()
		shell:Destroy()
		-- impacto: cráter que queda, onda, explosión y columna corta
		local crater, craterDecal = decalPart(style, "Circle", CFrame.new(ground + Vector3.new(0, 0.6, 0)), R * 2.2)
		animate(1.6, function(t)
			craterDecal.Transparency = math.clamp((t - 0.55) / 0.45, 0, 1)
		end, function()
			crater:Destroy()
		end)
		local ring, ringDecal = decalPart(style, "Ring", CFrame.new(ground + Vector3.new(0, 0.65, 0)), R)
		animate(0.5, function(t)
			local s = R * (1 + 2.4 * easeOut(t))
			ring.Size = Vector3.new(s, 0.05, s)
			ringDecal.Transparency = t ^ 1.3
		end, function()
			ring:Destroy()
		end)
		firePillar(ground, 12, R * 0.9, 0.55, style, 6)
		local n = if low then 5 else 10
		for i = 1, n do
			local a = i / n * TAU
			burst(ground + Vector3.new(math.cos(a), 0.6, math.sin(a)) * R * 0.8, style, { { kind = "Flame", count = 1, scale = 1.6 } })
		end
		burst(ground + Vector3.new(0, 1.5, 0), style, {
			{ kind = "Star", count = 1, scale = 3.2 },
			{ kind = "Smoke", count = 10, scale = 1.8 },
			{ kind = "Speed", count = 8, scale = 0.9 },
		})
		local light = Instance.new("PointLight")
		light.Color = style.Light
		light.Range = R * 3
		light.Brightness = 5
		light.Parent = ring
	end)
end

-- Crimson · corte en el aire que queda un instante y se rompe en esquirlas
local function spaceCut(origin: Vector3, dir: Vector3, range: number, style: any, tilt: number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local center = origin + flat * range * 0.55 + Vector3.new(0, 1.2, 0)
	local len = range * 1.3
	local cuts = {}
	for i, ang in { tilt, tilt + (if tilt >= 0 then -35 else 35) } do
		local cf = CFrame.lookAt(center, center + flat) * CFrame.Angles(0, 0, math.rad(ang)) * CFrame.Angles(0, math.rad(90), 0)
		local glow = solidPart(Vector3.new(0.05, 0.42, len), cf, style.Light)
		glow.Transparency = 0.15
		local core = solidPart(Vector3.new(0.08, 0.14, len * 0.98), cf, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		table.insert(cuts, { glow = glow, core = core, cf = cf, delay = (i - 1) * 0.05 })
	end
	for _, c in cuts do
		-- se abre de golpe, queda y se rompe
		animate(0.32 + c.delay, function(t)
			local open = math.clamp(t / 0.15, 0, 1)
			c.glow.Size = Vector3.new(0.05, 0.42 * (0.4 + 0.6 * open), len * easeOut(open))
			c.core.Size = Vector3.new(0.08, 0.14, len * 0.98 * easeOut(open))
		end, function()
			local cf = c.cf
			c.glow:Destroy()
			c.core:Destroy()
			local shards = if low then 4 else 9
			for k = 1, shards do
				local along = (k / (shards + 1) - 0.5) * len
				local p = (cf * CFrame.new(0, 0, along)).Position
				local shard = solidPart(Vector3.new(0.12, 0.5, 0.9), CFrame.new(p) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), if k % 2 == 0 then style.Light else (style.Deep or style.Light))
				local vel = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * (6 + math.random() * 6)
				animate(0.35, function(t, dt)
					shard.CFrame = shard.CFrame + vel * dt
					shard.Transparency = t
					shard.Size = Vector3.new(0.12, 0.5, 0.9) * (1 - 0.6 * t)
				end, function()
					shard:Destroy()
				end)
			end
		end)
	end
end

-- Crimson · X marcada sobre el enemigo golpeado
local function crossMark(pos: Vector3, style: any, crit: boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local face = CFrame.lookAt(pos, camera.CFrame.Position)
	local size = if crit then 3.4 else 2.2
	local bars = {}
	for _, a in { 45, -45 } do
		local b = solidPart(Vector3.new(0.22, size, 0.05), face * CFrame.Angles(0, 0, math.rad(a)), if crit then style.Core or style.Light else style.Light)
		table.insert(bars, b)
	end
	animate(0.28, function(t)
		for i, b in bars do
			local grow = easeOut(math.clamp(t / 0.25, 0, 1))
			b.Size = Vector3.new(0.22 * (1 - t), size * (0.3 + 0.7 * grow), 0.05)
			b.Transparency = math.clamp((t - 0.4) / 0.6, 0, 1)
		end
	end, function()
		for _, b in bars do
			b:Destroy()
		end
	end)
end

-- Crimson · espinas que brotan del piso en círculo
function thornRing(origin: Vector3, radius: number, style: any, count: number)
	local n = if low then math.ceil(count / 2) else count
	for i = 1, n do
		local a = i / n * TAU + math.random() * 0.2
		local at = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
		local y = groundY(at)
		local h = 3 + math.random() * 2.5
		local lean = CFrame.Angles(math.rad(math.random(-15, 15)), 0, math.rad(math.random(-15, 15)))
		local spike = solidPart(Vector3.new(0.7, h, 0.7), CFrame.new(at.X, y - h / 2, at.Z) * lean, style.Deep or style.Light, Enum.Material.SmoothPlastic)
		local tip = solidPart(Vector3.new(0.45, h * 0.35, 0.45), CFrame.new(at.X, y - h * 0.1, at.Z) * lean, style.Light)
		local base = spike.CFrame
		local baseTip = tip.CFrame
		task.delay(i * 0.015, function()
			animate(0.55, function(t)
				local up = if t < 0.2 then easeOut(t / 0.2) elseif t < 0.6 then 1 else 1 - (t - 0.6) / 0.4
				spike.CFrame = base + Vector3.new(0, h * up, 0)
				tip.CFrame = baseTip + Vector3.new(0, h * up, 0)
			end, function()
				spike:Destroy()
				tip:Destroy()
			end)
		end)
	end
	burst(origin + Vector3.new(0, 1, 0), style, { { kind = "Star", count = 1, scale = 2 }, { kind = "Smoke", count = 4, scale = 1.2 } })
end

---------------------------------------------------------------------
-- Impactos (tus golpes)
---------------------------------------------------------------------

local MAX_HITS = if low then 3 else 6 -- por tanda (el servidor junta los golpes cada 0,1 s)

combatText.OnClientEvent:Connect(function(events)
	if typeof(events) ~= "table" or player:GetAttribute("InMatch") ~= true then
		return
	end
	local style = styleOf(player:GetAttribute("Weapon"))
	if not style then
		return
	end
	local shown = 0
	for _, e in events do
		if shown >= MAX_HITS then
			break
		end
		if (e.k == "hit" or e.k == "crit") and typeof(e.p) == "Vector3" then
			shown += 1
			local crit = e.k == "crit"
			local p = e.p + Vector3.new(0, 1, 0)
			if style.Effects and style.Effects.Hit == "Void" then
				void.Hit(p, style, crit)
				continue
			elseif usesLightning(style, "Hit") then
				lightning.Hit(p, style, crit)
				continue -- no agregar llamas al impacto eléctrico
			elseif style.Variant == "Crimson" then
				crossMark(p, style, crit)
			elseif style.Variant == "Inferno" then
				burst(p, style, { { kind = "Star", count = 1, scale = if crit then 1.8 else 1.1 }, { kind = "Smoke", count = if crit then 3 else 1, scale = 0.8 } })
			end
			if crit then
				burst(p, style, {
					{ kind = "Flame", count = 2, scale = 0.9 },
					{ kind = "Star", count = 1, scale = 1.2 },
					{ kind = "Speed", count = 6, scale = 0.8 },
					{ kind = "Smoke", count = 2, scale = 0.7 },
				})
			else
				burst(p, style, {
					{ kind = "Flame", count = 1, scale = 0.6 },
					{ kind = "Star", count = 1, scale = 0.7 },
					{ kind = "Speed", count = 3, scale = 0.6 },
				})
			end
		end
	end
end)

---------------------------------------------------------------------
-- Golpes (de todos: el servidor avisa a todos los clientes)
---------------------------------------------------------------------

meleeSwing.OnClientEvent:Connect(function(userId, origin, dir, range, arc, weaponId)
	if typeof(origin) ~= "Vector3" then
		return
	end
	if weaponId == "Judgment" then
		-- El estilo es el del arma de quien lo lanzó (una espada común no tiene)
		local owner = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
		local style = owner and styleOf(owner:GetAttribute("Weapon")) or nil
		if style then
			judgment(origin, if type(range) == "number" then range else 10, style)
		end
		return
	end
	local style = styleOf(weaponId)
	if not style or typeof(dir) ~= "Vector3" or type(range) ~= "number" then
		return
	end
	if arc == 360 then
		if usesLightning(style, "Spin") then
			lightning.Spin(origin, range, style)
		else
			vortex(if type(userId) == "number" then userId else 0, origin, range, style)
		end
		if style.Variant == "Inferno" then
			firePillar(Vector3.new(origin.X, groundY(origin), origin.Z), 16, range * 0.55, 0.7, style, 8) -- tornado de fuego
		elseif style.Variant == "Crimson" then
			thornRing(origin, range * 0.75, style, 10)
		end
	else
		-- El tajo sale cuando el arma termina de cargar el golpe (tiempos de SwingCombo)
		local uid = if type(userId) == "number" then userId else 0
		local step = SwingCombo.step(uid)
		task.delay(SwingCombo.strikeDelay(uid, step), function()
			if usesLightning(style, "Slash") then
				lightning.Slash(origin, dir, range, style, step)
			else
				slash(uid, origin, dir, range, if type(arc) == "number" then arc else 120, style)
			end
			if style.Variant == "Inferno" then
				fireTrail(origin, dir, range, if type(arc) == "number" then arc else 120, style)
			elseif style.Variant == "Crimson" then
				spaceCut(origin, dir, range, style, SwingCombo.tilt(step) * SwingCombo.side(step))
			end
			if step == 3 then
				finisher(origin, dir, range, style)
			end
		end)
	end
end)

---------------------------------------------------------------------
-- Aura
---------------------------------------------------------------------

local AURA = "AnimeAura"

local function auraEmitter(parent: BasePart, style: any, scale: number, rate: number): ParticleEmitter
	local e = emitter(parent, style, "Flame", scale)
	e.Name = AURA
	e.Lifetime = NumberRange.new(0.3, 0.45)
	e.Speed = NumberRange.new(0.5 * scale, 1.5 * scale)
	e.Acceleration = Vector3.new(0, 6 * scale, 0)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9 * scale),
		NumberSequenceKeypoint.new(1, 0.5 * scale),
	})
	e.Rate = rate
	e.Enabled = true
	return e
end

-- Pieza de donde sale el aura: la hoja (la más grande que se llame "Blade..."; si no hay, la
-- más grande del modelo)
local function largestPart(model: Instance): BasePart?
	local best, size = nil, 0
	local blade, bladeSize = nil, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local s = d.Size.X * d.Size.Y * d.Size.Z
			if s > size then
				best, size = d, s
			end
			if string.sub(d.Name, 1, 5) == "Blade" and s > bladeSize then
				blade, bladeSize = d, s
			end
		end
	end
	return blade or best
end

local function setAura(part: BasePart?, style: any, scale: number, rate: number)
	if not part then
		return
	end
	local current = part:FindFirstChild(AURA)
	if style and style.Effects and style.Effects.Aura == "Void" then
		if current then current:Destroy() end
		void.Aura(part, style)
		return
	end
	if usesLightning(style, "Aura") then
		if current then current:Destroy() end
		lightning.Aura(part, style)
		return
	end
	if style and not current then
		auraEmitter(part, style, scale, rate)
	elseif not style and current then
		current:Destroy()
	end
end

local BODY_AURA = "AnimeBodyAura"

-- Llamas envolviendo a todo el personaje (estilos con BodyAura): torso y piernas
local function setBodyAura(character: Model, style: any?)
	for _, name in { "UpperTorso", "Torso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm" } do
		local part = character:FindFirstChild(name) :: BasePart?
		if part then
			local current = part:FindFirstChild(BODY_AURA)
			if style and not current then
				local big = name == "UpperTorso" or name == "Torso"
				local e = auraEmitter(part, style, if big then 2.2 else 1.4, if low then 4 else (if big then 26 else 12))
				e.Name = BODY_AURA
				e.Lifetime = NumberRange.new(0.4, 0.7)
				e.Speed = NumberRange.new(1.5, 4)
				e.SpreadAngle = Vector2.new(70, 70)
				e.Acceleration = Vector3.new(0, 14, 0)
				e.EmissionDirection = Enum.NormalId.Top
			elseif not style and current then
				current:Destroy()
			end
		end
	end
end

local function handOf(character: Model): BasePart?
	return (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
end

task.spawn(function()
	while true do
		task.wait(0.5)
		-- primera persona: la hoja del arma en pantalla (la arma WeaponFx dentro de la cámara)
		local camera = workspace.CurrentCamera
		local rig = camera and camera:FindFirstChild("FirstPersonWeapon")
		local view = rig and rig:FindFirstChild("ViewModel")
		local myStyle = player:GetAttribute("InMatch") == true and styleOf(player:GetAttribute("Weapon")) or nil
		if view and not low then
			setAura(largestPart(view), myStyle, 0.22, 9)
		end
		-- tercera persona y compañeros: en la hoja del arma que tienen en la mano (HeldWeapon),
		-- también en el lobby; si no hay modelo, en la mano durante la partida
		for _, p in Players:GetPlayers() do
			local character = p.Character
			local hand = character and handOf(character)
			if character then
				-- Aura de cuerpo entero (no en tu propia primera persona: taparía la vista)
				local bodyStyle = styleOf(p:GetAttribute("Weapon"))
				if not (bodyStyle and bodyStyle.BodyAura) then
					bodyStyle = nil
				end
				if p == player and player:GetAttribute("CameraView") == "FirstPerson" and player:GetAttribute("InMatch") == true then
					bodyStyle = nil
				end
				setBodyAura(character, bodyStyle)
			end
			if hand then
				local style = styleOf(p:GetAttribute("Weapon"))
				local heldModel = character:FindFirstChild("HeldWeapon")
				local blade = heldModel and heldModel:FindFirstChild("BladeAura") :: BasePart?
				if blade then
					setAura(blade, style, 0.55, if low then 6 else 14)
					setAura(hand, nil, 0, 0)
				else
					if p:GetAttribute("InMatch") ~= true then
						style = nil
					end
					if p == player and player:GetAttribute("CameraView") == "FirstPerson" then
						style = nil -- en primera persona la llevás en la hoja
					end
					setAura(hand, style, 0.8, if low then 4 else 8)
				end
			end
		end
	end
end)
