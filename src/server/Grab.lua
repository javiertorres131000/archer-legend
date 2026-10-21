-- Grab (ModuleScript)
-- Ubicación: ServerScriptService > Server > Grab
-- Agarre: un enemigo con el ataque "Grab" (el Atrapador) te salta encima y te inmoviliza.
-- Mientras te tiene: no te movés (la raíz queda anclada), no atacás ni hacés dash, y te saca
-- vida cada Config.Grab.TickTime. Te suelta cuando:
--   · un compañero le hace Config.Grab.ReleaseDamageFraction de su vida (o lo mata) → rescate
--   · machacás el botón de forcejeo Config.Grab.StrugglePresses veces (Remotes.StruggleRequest)
--   · te derriban, te vas, se termina la partida o pasa Config.Grab.MaxHold
-- Al soltarte sale despedido y queda aturdido, y por Config.Grab.ImmuneAfter no te puede agarrar
-- ningún otro (con dos Atrapadores te agarraban en cadena). Todo lo decide el servidor; el cliente solo
-- avisa que tocó el botón (con límite de frecuencia) y muestra los atributos:
--   Grabbed (bool), GrabProgress (0..1 del forcejeo)
--   SavedBy / Rescued ("contador|nombre"): quién te salvó / a quién salvaste

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local PlayerLife = require(script.Parent.PlayerLife)

local Cfg = Config.Grab
local flat = PlayerData.flat

type Hold = {
	enemy: any,
	target: PlayerData.Target,
	dps: number,
	startHealth: number,
	time: number, -- segundos agarrado (no corre en pausa)
	tick: number, -- tiempo hasta el próximo mordisco
	presses: number,
	lastPress: number,
	side: Vector3, -- de qué lado del jugador se quedó el enemigo
}

local Grab = {}

local holds: { [Player]: Hold } = {}
local knockback: ((any, Vector3, number) -> ())? = nil
local noticeCount = 0

function Grab.setKnockback(fn: (any, Vector3, number) -> ())
	knockback = fn
end

local function setNetworkAuto(root: BasePart)
	pcall(function()
		root:SetNetworkOwnershipAuto()
	end)
end

function Grab.isGrabbed(player: Player): boolean
	return holds[player] ~= nil
end

-- Intenta agarrar a `target`. Falla si ya está agarrado, no está en pie, está protegido
-- (escudo de aparición o dash) o el enemigo ya tiene a alguien / no puede agarrar todavía.
function Grab.try(enemy: any, target: PlayerData.Target, dps: number): boolean
	local state = target.state
	local player = target.player
	if holds[player] or enemy.grabbing or not enemy.alive or enemy.hidden then
		return false
	end
	if os.clock() < (enemy.grabLockUntil or 0) then
		return false
	end
	if PlayerData.isPaused() or state.life ~= "ALIVE" or not state.inMatch or state.grabbed then
		return false
	end
	if os.clock() < (state.grabImmuneUntil or 0) then
		return false -- recién soltado: que no lo agarre otro Atrapador enseguida
	end
	if os.clock() < state.dashUntil then
		return false -- el dash te hace intocable
	end
	local character = player.Character
	if not character or character:FindFirstChildOfClass("ForceField") then
		return false
	end
	local offset = flat(enemy.part.Position) - flat(target.root.Position)
	local side = if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(0, 0, 1)
	holds[player] = {
		enemy = enemy,
		target = target,
		dps = dps,
		startHealth = enemy.health,
		time = 0,
		tick = 0, -- el primer mordisco sale enseguida
		presses = 0,
		lastPress = -math.huge,
		side = side,
	}
	enemy.grabbing = player
	enemy.grabHits = {}
	state.grabbed = true
	target.root.Anchored = true -- no se mueve (y el servidor pasa a mandar sobre su posición)
	player:SetAttribute("Grabbed", true)
	player:SetAttribute("GrabProgress", 0)
	return true
end

-- Dónde se queda el enemigo mientras te tiene: pegado a vos, del lado del que vino.
function Grab.holdPosition(enemy: any): Vector3?
	local player = enemy.grabbing
	local hold = player and holds[player]
	if not hold then
		return nil
	end
	return flat(hold.target.root.Position) + hold.side * (enemy.radius + 1)
end

-- Quién lo salvó: el que más daño le hizo al agarrador mientras lo tenía
local function savior(enemy: any, grabbed: Player): Player?
	local best, bestDamage = nil, 0
	for p, dmg in enemy.grabHits or {} do
		if p ~= grabbed and dmg > bestDamage then
			best, bestDamage = p, dmg
		end
	end
	return best
end

-- reason: "rescue" | "struggle" | "downed" | "timeout" | "gone" | "clear"
function Grab.release(player: Player, reason: string)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil
	local enemy = hold.enemy
	local state = PlayerData.get(player)
	if state then
		state.grabbed = false
		state.grabImmuneUntil = os.clock() + Cfg.ImmuneAfter
	end
	local root = hold.target.root
	if root.Parent then
		root.Anchored = false
		setNetworkAuto(root)
	end
	player:SetAttribute("Grabbed", false)
	player:SetAttribute("GrabProgress", 0)

	if reason == "rescue" then
		local hero = savior(enemy, player)
		if hero then
			noticeCount += 1
			player:SetAttribute("SavedBy", string.format("%d|%s", noticeCount, hero.DisplayName))
			hero:SetAttribute("Rescued", string.format("%d|%s", noticeCount, player.DisplayName))
		end
	end

	enemy.grabbing = nil
	enemy.grabHits = nil
	enemy.grabLockUntil = os.clock() + Cfg.RegrabCooldown
	if enemy.alive then
		enemy.stunUntil = os.clock() + Cfg.StunAfter
		if knockback and reason ~= "clear" then
			knockback(enemy, hold.side, Cfg.Knockback)
		end
	end
end

-- El jugador tocó el botón de forcejeo
function Grab.struggle(player: Player)
	local hold = holds[player]
	if not hold then
		return
	end
	local now = os.clock()
	if now - hold.lastPress < 1 / Cfg.StruggleMaxRate then
		return -- demasiado rápido: no cuenta
	end
	hold.lastPress = now
	hold.presses += 1
	player:SetAttribute("GrabProgress", math.min(1, hold.presses / Cfg.StrugglePresses))
	if hold.presses >= Cfg.StrugglePresses then
		Grab.release(player, "struggle")
	end
end

-- Un frame (no se llama durante la pausa de elegir habilidad)
function Grab.update(dt: number)
	for player, hold in table.clone(holds) do
		local enemy = hold.enemy
		local state = PlayerData.get(player)
		if not player.Parent or not state or not state.inMatch or not hold.target.root.Parent then
			Grab.release(player, "gone")
		elseif state.life ~= "ALIVE" then
			Grab.release(player, "downed")
		elseif not enemy.alive or enemy.hidden then
			Grab.release(player, "rescue") -- lo mataron (o se escondió): libre
		elseif hold.startHealth - enemy.health >= enemy.maxHealth * Cfg.ReleaseDamageFraction then
			Grab.release(player, "rescue")
		else
			hold.time += dt
			if hold.time >= Cfg.MaxHold then
				Grab.release(player, "timeout")
			else
				hold.tick -= dt
				if hold.tick <= 0 then
					hold.tick = Cfg.TickTime
					PlayerLife.damage(hold.target, hold.dps * Cfg.TickTime)
				end
			end
		end
	end
end

function Grab.clear()
	for player in table.clone(holds) do
		Grab.release(player, "clear")
	end
end

function Grab.onPlayerRemoving(player: Player)
	if holds[player] then
		Grab.release(player, "gone")
	end
end

function Grab.init(remotes)
	remotes.StruggleRequest.OnServerEvent:Connect(function(player: Player)
		Grab.struggle(player)
	end)
end

return Grab
