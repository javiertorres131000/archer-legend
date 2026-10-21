-- MeleeVisuals (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > MeleeVisuals
-- Dibuja los golpes cuerpo a cuerpo y los poderes que avisa el servidor (Remotes.MeleeSwing):
--   · Espada: una media luna brillante que barre el arco del golpe (360° = Torbellino).
--   · Puños: un destello corto delante del jugador.
--   · "Rain": una flecha que cae del cielo (Lluvia de flechas).
--   · "Judgment": una espada gigante que cae y una onda en el piso (Juicio).
--   · "Burst": un anillo de energía alrededor del jugador (Ráfaga de mil puños).
-- Es solo visual: el daño ya lo calculó el servidor.
-- Las armas con estilo anime (campo Fx en Shared/Weapons.lua) las dibuja AnimeFx, no este script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FxQuality = require(Shared:WaitForChild("FxQuality"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local FxStyles = require(Shared:WaitForChild("FxStyles"))

-- ¿Lo dibuja AnimeFx? (el arma tiene un estilo anime)
local function hasAnimeFx(weaponId: string): boolean
	local def = Weapons.ById[weaponId]
	return def ~= nil and FxStyles.get(def.Fx) ~= nil
end
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MeleeSwing") :: RemoteEvent

local low = FxQuality.isLow()
local folder = Instance.new("Folder")
folder.Name = "MeleeFx"
folder.Parent = workspace

local COLORS = {
	Sword = Color3.fromRGB(200, 230, 255),
	Fists = Color3.fromRGB(255, 190, 110),
}

local function piece(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Transparency = 0.15
	p.Parent = folder
	return p
end

local function fade(p: BasePart, time: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = p.Size + grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.05)
end

local function sword(origin: Vector3, dir: Vector3, range: number, arc: number)
	local color = COLORS.Sword
	local segments = if low then 6 else 12
	local radius = range * 0.75
	local base = math.atan2(dir.X, dir.Z)
	local half = math.rad(arc / 2)
	for i = 0, segments do
		local t = i / segments
		local angle = base - half + t * 2 * half
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * radius
		local pos = origin + offset + Vector3.new(0, 0.5, 0)
		local length = radius * 2 * half / segments + 0.4
		local p = piece(Vector3.new(0.25, 0.6, length), CFrame.lookAt(pos, pos + Vector3.new(math.cos(angle), 0, -math.sin(angle))), color)
		-- La media luna aparece de un lado al otro (barrido)
		p.Transparency = 1
		task.delay(t * 0.06, function()
			p.Transparency = 0.1
			fade(p, 0.18)
		end)
	end
end

local function fists(origin: Vector3, dir: Vector3, range: number)
	local color = COLORS.Fists
	local side = dir:Cross(Vector3.yAxis).Unit * (if math.random() < 0.5 then 0.8 else -0.8)
	local pos = origin + dir * range * 0.6 + side + Vector3.new(0, 0.8, 0)
	local p = piece(Vector3.one * 1.2, CFrame.new(pos), color, Enum.PartType.Ball)
	fade(p, 0.15, Vector3.one * 2.2)
end

local function rain(pos: Vector3)
	local color = Color3.fromRGB(255, 230, 120)
	local arrow = piece(Vector3.new(0.35, 4, 0.35), CFrame.new(pos + Vector3.new(0, 28, 0)), color)
	TweenService:Create(arrow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) }):Play()
	task.delay(0.22, function()
		fade(arrow, 0.15)
		local ring = piece(Vector3.new(0.2, 3, 3), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		fade(ring, 0.25, Vector3.new(0, 3, 3))
	end)
end

local function judgment(pos: Vector3, radius: number)
	local color = Color3.fromRGB(255, 240, 200)
	local blade = piece(Vector3.new(1.5, 18, 4), CFrame.new(pos + Vector3.new(0, 40, 0)), color)
	TweenService:Create(blade, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) }):Play()
	task.delay(0.3, function()
		fade(blade, 0.5)
		local ring = piece(Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		fade(ring, 0.4, Vector3.new(0, radius * 2, radius * 2))
	end)
end

local function burst(pos: Vector3, radius: number)
	local ring = piece(Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), COLORS.Fists, Enum.PartType.Cylinder)
	fade(ring, 0.5, Vector3.new(0, radius * 2, radius * 2))
end

-- Arma de quien lanzó el poder (el Juicio de una espada especial lo dibuja AnimeFx)
local function weaponOf(userId: any): string
	local owner = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	local id = owner and owner:GetAttribute("Weapon")
	return if type(id) == "string" then id else "Sword"
end

remote.OnClientEvent:Connect(function(userId, origin, dir, range, arc, weaponId)
	if weaponId == "Rain" and typeof(origin) == "Vector3" then
		rain(origin)
		return
	elseif weaponId == "Judgment" and typeof(origin) == "Vector3" then
		if hasAnimeFx(weaponOf(userId)) then
			return
		end
		judgment(origin, if type(range) == "number" then range else 10)
		return
	elseif weaponId == "Burst" and typeof(origin) == "Vector3" then
		burst(origin, if type(range) == "number" then range else 6)
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or type(range) ~= "number" then
		return
	end
	if type(weaponId) == "string" and hasAnimeFx(weaponId) then
		return
	end
	if weaponId == "Fists" then
		fists(origin, dir, range)
	else
		sword(origin, dir, range, if type(arc) == "number" then arc else 120)
	end
end)
