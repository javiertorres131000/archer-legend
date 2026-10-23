-- Hazards (ModuleScript)
-- Ubicación: ServerScriptService > Server > Hazards
-- Todo lo que se dibuja en el piso: avisos de área (círculo que se llena y después
-- explota), zonas que dañan con el tiempo (fuego, veneno), marcadores sin daño
-- (teletransporte, aparición) y franjas (embestidas, líneas de apuntado).

local Debris = game:GetService("Debris")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)
local Ground = require(script.Parent.Ground)

local HazCfg = Config.Hazards
local hitRadius = Config.EnemyProjectile.PlayerHitRadius
local flat = PlayerData.flat

export type ZoneSpec = { Duration: number, Dps: number, Color: Color3? }

type Warning = {
	duration: number,
	pos: Vector3,
	radius: number,
	timeLeft: number,
	damage: number,
	zone: ZoneSpec?,
	parts: { BasePart },
	cause: string?,
}

type Zone = {
	pos: Vector3,
	radius: number,
	timeLeft: number,
	dps: number,
	tick: number,
	part: BasePart,
	cause: string?,
}

local Hazards = {}

local folder: Folder
local warnings: { Warning } = {}
local zones: { Zone } = {}

function Hazards.init()
	folder = Instance.new("Folder")
	folder.Name = "Hazards"
	folder.Parent = workspace
end

local function basePart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	return p
end

-- Disco plano en el piso. Un cilindro de Roblox tiene el eje en X: lo acostamos.
local function disc(pos: Vector3, radius: number, color: Color3, transparency: number, height: number): Part
	local p = basePart()
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos.X, Ground.y(pos.X, pos.Z) + height / 2 + 0.02, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Transparency = transparency
	p.Parent = folder
	return p
end

-- Franja en el piso desde `from` en dirección `dir`. La destruye quien la pide.
function Hazards.strip(from: Vector3, dir: Vector3, length: number, width: number, color: Color3?, transparency: number?): Part
	local p = basePart()
	local mid = flat(from) + dir * (length / 2)
	local center = mid + Vector3.new(0, Ground.y(mid.X, mid.Z) + 0.06, 0)
	p.Size = Vector3.new(width, 0.1, length)
	p.CFrame = CFrame.lookAt(center, center + dir)
	p.Color = color or HazCfg.WarningColor
	p.Transparency = transparency or 0.55
	p.Parent = folder
	return p
end

-- Círculo sin daño que desaparece solo (teletransportes, apariciones).
function Hazards.marker(pos: Vector3, radius: number, duration: number, color: Color3?)
	local p = disc(pos, radius, color or HazCfg.MarkerColor, 0.5, 0.1)
	Debris:AddItem(p, duration)
end

-- Aviso de área: un círculo que se llena durante `delay` segundos y después daña a
-- quien esté adentro. Si trae `zone`, deja una zona que sigue dañando.
-- cause (opcional): nombre para el aviso de daño ("Carámbano"...)
function Hazards.warn(pos: Vector3, radius: number, delay: number, damage: number, zone: ZoneSpec?, color: Color3?, cause: string?)
	local c = color or HazCfg.WarningColor
	local outer = disc(pos, radius, c, 0.75, 0.08)
	-- Para el aviso en pantalla de cada jugador (Client/HazardAlert): sirve en primera persona
	if (outer :: any).SetAttribute then
		outer:SetAttribute("Warning", true)
		outer:SetAttribute("Radius", radius)
		outer:SetAttribute("EndsAt", workspace:GetServerTimeNow() + delay)
		outer:SetAttribute("Total", delay)
	end
	local inner = disc(pos, 0.2, c, 0.35, 0.1)

	table.insert(warnings, {
		duration = math.max(delay, 0.001),
		pos = flat(pos),
		radius = radius,
		timeLeft = delay,
		damage = damage,
		zone = zone,
		parts = { outer, inner },
		cause = cause,
	})
end

-- Zona que daña Dps por segundo a quien esté adentro.
function Hazards.zone(pos: Vector3, radius: number, duration: number, dps: number, color: Color3?, cause: string?)
	local p = disc(pos, radius, color or Color3.fromRGB(255, 110, 30), 0.5, 0.12)
	table.insert(zones, { pos = flat(pos), radius = radius, timeLeft = duration, dps = dps, tick = 0, part = p, cause = cause })
end

local function damageInside(center: Vector3, radius: number, amount: number, targets: { PlayerData.Target }, cause: string?)
	for _, t in targets do
		if (flat(t.root.Position) - center).Magnitude <= radius + hitRadius * 0.5 then
			PlayerLife.damage(t, amount, cause)
		end
	end
end

function Hazards.update(dt: number, targets: { PlayerData.Target })
	for i = #warnings, 1, -1 do
		local w = warnings[i]
		w.timeLeft -= dt
		local fill = math.max(0.2, w.radius * math.clamp(1 - w.timeLeft / w.duration, 0, 1))
		w.parts[2].Size = Vector3.new(0.1, fill * 2, fill * 2)
		if w.timeLeft <= 0 then
			table.remove(warnings, i)
			for _, p in w.parts do
				p:Destroy()
			end
			damageInside(w.pos, w.radius, w.damage, targets, w.cause or "Círculo rojo")
			-- Destello breve del impacto
			local flash = disc(w.pos, w.radius, Color3.new(1, 1, 1), 0.3, 0.15)
			Debris:AddItem(flash, 0.15)
			if w.zone then
				Hazards.zone(w.pos, w.radius, w.zone.Duration, w.zone.Dps, w.zone.Color, "Zona en el piso")
			end
		end
	end

	for i = #zones, 1, -1 do
		local z = zones[i]
		z.timeLeft -= dt
		z.tick -= dt
		if z.tick <= 0 then
			z.tick = HazCfg.ZoneTick
			damageInside(z.pos, z.radius, z.dps * HazCfg.ZoneTick, targets, z.cause or "Zona en el piso")
		end
		if z.timeLeft <= 0 then
			z.part:Destroy()
			table.remove(zones, i)
		end
	end
end

function Hazards.clear()
	for _, w in warnings do
		for _, p in w.parts do
			p:Destroy()
		end
	end
	for _, z in zones do
		z.part:Destroy()
	end
	table.clear(warnings)
	table.clear(zones)
	folder:ClearAllChildren()
end

return Hazards
