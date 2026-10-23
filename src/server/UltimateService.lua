--!strict
-- UltimateService (ModuleScript)
-- Ubicación: ServerScriptService > Server > UltimateService
-- Habilidades definitivas de las armas especiales (campo Ultimate en Shared/Weapons.lua).
--   · Carga: cada golpe que conecta suma 1 / ChargeHits (SkillEffects.onHit llama a addCharge).
--     Se publica en el jugador como atributo "UltCharge" (0 a 1).
--   · Uso: el cliente pide con Remotes.UltimateRequest (tecla Q / botón Y / botón en pantalla).
--     El servidor valida (en partida, vivo, sin agarre, sin pausa, carga llena), vacía la carga,
--     te hace invulnerable lo que dura y avisa a todos con Remotes.UltimateFx
--     (userId, Id del arma, origen, dirección, hora del servidor en que empieza).
--   · Daño (todo del servidor, en tiempos fijos desde el inicio):
--       FirstAt: tajo inicial alrededor (Radius × 0,6, Mult × FirstFrac)
--       PullAt (si hay Pull): atrae a los enemigos cercanos hacia el centro
--       Bolts (opcional): tormenta de rayos sobre enemigos al azar (ver bolts)
--       BlackHole (opcional): agujero negro delante del jugador que atrae y daña (ver blackHole);
--         el golpe final es en el agujero
--       FinalAt: golpe final en Radius (o en línea recta si hay Line = { Length, Width }) (Mult; jefes × BossMult) y sangrado (Bleed por segundo, 3 s)
--     Mult se multiplica por tu daño y el DamageMult del arma.
-- El dibujo (cinemática y efectos) está en Client/UltimateFx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Weapons"))
local PlayerData = require(script.Parent.PlayerData)

local UltimateService = {}

local Enemies: any = nil
local remotes: any = nil
local busy: { [Player]: boolean } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function weaponOf(player: Player): any
	local id = player:GetAttribute("Weapon")
	return if type(id) == "string" then Weapons.ById[id] else nil
end

local function ultOf(player: Player): any
	local def = weaponOf(player)
	return def and def.Ultimate
end

-- Cada golpe que conecta (melee o flecha) carga la definitiva.
function UltimateService.addCharge(player: Player?)
	if not player then
		return
	end
	local u = ultOf(player)
	if not u or busy[player] then
		return
	end
	local c = (player:GetAttribute("UltCharge") :: number?) or 0
	if c >= 1 then
		return
	end
	player:SetAttribute("UltCharge", math.min(1, c + 1 / (u.ChargeHits or 40)))
end

-- Partida nueva: la definitiva empieza vacía y se carga conectando golpes.
function UltimateService.reset()
	for _, p in game:GetService("Players"):GetPlayers() do
		p:SetAttribute("UltCharge", 0)
	end
	table.clear(busy)
end

local function hitArea(owner: Player, center: Vector3, radius: number, amount: number, bossMult: number, bleed: number?, slow: number?)
	local c = flat(center)
	for _, e: any in table.clone(Enemies.list) do
		if e.alive and not e.hidden and (flat(e.part.Position) - c).Magnitude <= radius + (e.radius or 0) then
			local dealt = if e.isBoss then amount * bossMult else amount
			Enemies.damage(e, dealt, owner, "crit")
			if slow and e.alive then
				e.slowUntil = math.max(e.slowUntil or 0, os.clock() + 3)
				e.slowAmount = math.max(e.slowAmount or 0, slow)
			end
			if bleed and e.alive then
				Enemies.applyBurn(e, dealt * bleed, 3, owner)
			end
		end
	end
end

-- Disparo en línea recta (Ultimate.Line): todos los que estén en la franja de largo Length y
-- medio ancho Width delante del jugador
local function hitLine(owner: Player, origin: Vector3, dir: Vector3, length: number, width: number, amount: number, bossMult: number)
	local o = flat(origin)
	for _, e: any in table.clone(Enemies.list) do
		if e.alive and not e.hidden then
			local rel = flat(e.part.Position) - o
			local along = rel:Dot(dir)
			local off = (rel - dir * along).Magnitude
			if along >= -2 and along <= length and off <= width + (e.radius or 0) then
				Enemies.damage(e, if e.isBoss then amount * bossMult else amount, owner, "crit")
			end
		end
	end
end

local function pull(center: Vector3, radius: number, strength: number)
	local c = flat(center)
	for _, e: any in table.clone(Enemies.list) do
		if e.alive and not e.hidden and not e.isBoss then
			local offset = c - flat(e.part.Position)
			local d = offset.Magnitude
			if d <= radius and d > 2 then
				Enemies.knockback(e, offset.Unit, math.min(d - 2, strength))
			end
		end
	end
end

-- Tormenta (Bolts): cada Every segundos entre From y To caen rayos sobre Targets enemigos al
-- azar dentro de la zona (Frac del daño). Se dibujan con SkillFx "Chain" desde el cielo.
local function bolts(player: Player, origin: Vector3, u: any, base: number)
	local b = u.Bolts
	task.wait(b.From)
	local t = b.From
	local c = flat(origin)
	while t < b.To do
		local pool = {}
		for _, e: any in Enemies.list do
			if e.alive and not e.hidden and (flat(e.part.Position) - c).Magnitude <= u.Radius * 1.3 then
				table.insert(pool, e)
			end
		end
		for _ = 1, math.min(b.Targets, #pool) do
			local e = table.remove(pool, math.random(1, #pool))
			local pos = e.part.Position
			if remotes.SkillFx then
				remotes.SkillFx:FireAllClients("Chain", pos + Vector3.new(math.random(-6, 6), 45, math.random(-6, 6)), pos)
				remotes.SkillFx:FireAllClients("Blast", pos, 3, u.Color)
			end
			Enemies.damage(e, base * b.Frac * (if e.isBoss then (u.BossMult or 0.5) else 1), player, "crit")
		end
		task.wait(b.Every)
		t += b.Every
	end
end

-- Agujero negro (BlackHole): entre From y To, cada Every segundos, atrae (Pull studs) y daña
-- (Frac del daño) a todos dentro de Radius alrededor del centro. Los jefes no se mueven.
local function blackHole(player: Player, center: Vector3, u: any, base: number)
	local h = u.BlackHole
	task.wait(h.From)
	local t = h.From
	local c = flat(center)
	while t < h.To do
		for _, e: any in table.clone(Enemies.list) do
			if e.alive and not e.hidden then
				local offset = c - flat(e.part.Position)
				local d = offset.Magnitude
				if d <= u.Radius + (e.radius or 0) then
					Enemies.damage(e, base * h.Frac * (if e.isBoss then (u.BossMult or 0.5) else 1), player, "hit")
					if e.alive and not e.isBoss and d > 1.5 then
						Enemies.knockback(e, offset.Unit, math.min(d - 1, h.Pull))
					end
				end
			end
		end
		task.wait(h.Every)
		t += h.Every
	end
end

local function request(player: Player, target: any)
	local state = PlayerData.get(player)
	if not state or not state.inMatch or state.life ~= "ALIVE" or (state :: any).grabbed or PlayerData.isPaused() or PlayerData.inCinematic() then
		return
	end
	local def = weaponOf(player)
	local u = def and def.Ultimate
	if not u or busy[player] or ((player:GetAttribute("UltCharge") :: number?) or 0) < 1 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local origin = root.Position
	local selected: Vector3? = nil
	if u.TargetRange then
		if typeof(target) ~= "Vector3" then return end
		if target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z
			or math.abs(target.X) == math.huge or math.abs(target.Y) == math.huge or math.abs(target.Z) == math.huge then return end
		if (target - origin).Magnitude > u.TargetRange + 10 then return end
		local offset = flat(target - origin)
		if offset.Magnitude > u.TargetRange then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(origin + offset + Vector3.new(0, 100, 0), Vector3.new(0, -250, 0), params)
		if not hit then return end
		selected = hit.Position
	end
	busy[player] = true
	player:SetAttribute("UltCharge", 0)
	local look = if selected then flat(selected - origin) else flat(root.CFrame.LookVector)
	local dir = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	-- Invulnerable mientras dura (PlayerLife.damage ignora el daño durante dashUntil)
	state.dashUntil = math.max(state.dashUntil, os.clock() + u.Duration + 0.3)
	-- Pausa autoritativa para todo el grupo; los golpes de la definitiva
	-- siguen sus tiempos propios mientras Run suspende enemigos y proyectiles.
	-- Incluye el cierre de la cámara (Duration + 0.1 en UltimateFx).
	PlayerData.startCinematic(u.Duration + 0.3)
	PlayerData.setPaused(true)
	remotes.UltimateFx:FireAllClients(player.UserId, def.Id, origin, dir, workspace:GetServerTimeNow(), selected)
	local base = state.stats.damage * (def.DamageMult or 1) * u.Mult
	-- Centro del golpe: el jugador, o el agujero negro delante de él (BlackHole.Distance)
	local center = if u.Line then origin else selected or (if u.BlackHole then origin + dir * u.BlackHole.Distance else origin)
	if u.BlackHole then
		task.spawn(blackHole, player, center, u, base)
	end
	task.spawn(function()
		local t = 0
		local function waitUntil(at: number)
			if at > t then
				task.wait(at - t)
				t = at
			end
		end
		waitUntil(u.FirstAt or 0.5)
		if u.FirstFrac then
			hitArea(player, selected or origin, u.Radius * 0.6, base * u.FirstFrac, u.BossMult or 0.5, nil)
		end
		if u.Bolts then
			task.spawn(bolts, player, center, u, base)
		end
		if u.Pull then
			waitUntil(u.PullAt or 1.2)
			pull(center, u.Radius * 1.3, u.Pull)
		end
		waitUntil(u.FinalAt or (u.Duration - 0.6))
		if u.Line then
			hitLine(player, origin, dir, u.Line.Length, u.Line.Width, base, u.BossMult or 0.5)
		else
			hitArea(player, center, u.Radius, base, u.BossMult or 0.5, u.Burn or u.Bleed, u.Slow)
		end
		waitUntil(u.Duration)
		busy[player] = nil
	end)
end

function UltimateService.init(r: any, enemies: any)
	remotes = r
	Enemies = enemies
	r.UltimateRequest.OnServerEvent:Connect(request)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
end

return UltimateService
