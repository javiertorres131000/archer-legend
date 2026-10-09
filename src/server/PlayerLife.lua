--!strict
-- PlayerLife (ModuleScript)
-- Ubicación: ServerScriptService > Server > PlayerLife
-- Único dueño del ciclo de vida de los jugadores: aparición (en el lobby o en la arena),
-- daño, derribo, rescate, eliminación y reaparición en el descanso.
-- Nadie más toca Humanoid.Health para dañar.
--
--   ALIVE ──vida en 0──> DOWNED ──lo reviven──> ALIVE
--                          │
--                          └──se acaba el tiempo──> ELIMINATED ──descanso──> ALIVE
--
-- Solo los participantes de la partida (state.inMatch) reciben daño, cuentan para la
-- derrota y para el escalado. Quien está en el lobby está a salvo.
--
-- El rescate usa un ProximityPrompt (mantener 3 s), que ya funciona en PC, móvil y gamepad.
-- El cliente solo muestra el botón: el servidor valida estado, distancia y tiempo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local CombatFeed = require(script.Parent.CombatFeed)

local CoopCfg = Config.Coop
local PlayerCfg = Config.Player

type LifeState = PlayerData.LifeState
type State = PlayerData.State

-- Datos de un jugador derribado
type Downed = {
	player: Player,
	timeLeft: number,
	holders: { [Player]: number }, -- quién está manteniendo el botón y desde cuándo (os.clock)
	prompt: ProximityPrompt,
	gui: BillboardGui,
	timerFill: Frame,
	reviveFill: Frame,
	highlight: Highlight,
	connections: { RBXScriptConnection },
	publishTimer: number,
	jumpHeight: number, -- para devolvérsela al revivir
	jumpPower: number,
}

local PlayerLife = {}

local downed: { [Player]: Downed } = {}
-- Dónde ubicar el próximo personaje de cada jugador (si no, aparece en el SpawnLocation del lobby)
local pendingSpawn: { [Player]: CFrame } = {}

-- Estado visible para los clientes (HUD): atributos en el Player, que se replican solos.
local function setLife(player: Player, state: State, life: LifeState)
	state.life = life
	player:SetAttribute("LifeState", life)
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function flatDistance(a: BasePart, b: BasePart): number
	local d = a.Position - b.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

-- Carga el personaje en otro hilo (LoadCharacterAsync espera).
local function loadCharacter(player: Player)
	task.spawn(function()
		if not player.Parent then
			return
		end
		local ok = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok and player.Parent then
			player:LoadCharacter()
		end
	end)
end

-- Pide la aparición. Se lo considera ALIVE desde ya para que la derrota no se dispare
-- mientras el personaje carga (tarda una fracción de segundo).
-- at: dónde ubicarlo (en la arena); sin `at` aparece en el lobby.
local function respawn(player: Player, at: CFrame?)
	local state = PlayerData.get(player)
	if not state then
		return
	end
	setLife(player, state, "ALIVE")
	if at then
		pendingSpawn[player] = at
	else
		pendingSpawn[player] = nil
	end
	loadCharacter(player)
end

local function setInMatch(player: Player, state: State, value: boolean)
	state.inMatch = value
	player:SetAttribute("InMatch", value)
end

local function addShield(character: Model, name: string, duration: number)
	local shield = Instance.new("ForceField")
	shield.Name = name
	shield.Parent = character
	task.delay(duration, function()
		if shield.Parent then
			shield:Destroy()
		end
	end)
end

---------------------------------------------------------------------
-- Derribo
---------------------------------------------------------------------

local function clearDowned(player: Player)
	local d = downed[player]
	if not d then
		return
	end
	downed[player] = nil
	for _, c in d.connections do
		c:Disconnect()
	end
	d.prompt:Destroy()
	d.gui:Destroy()
	d.highlight:Destroy()
	player:SetAttribute("DownedLeft", nil)
	player:SetAttribute("ReviveProgress", nil)
	player:SetAttribute("RevivedBy", nil)
end

-- Vuelve a ALIVE con una fracción de vida y escudo. rescuer = quien lo revivió (o nil en el descanso).
local function revive(player: Player, rescuer: Player?)
	local state = PlayerData.get(player)
	local d = downed[player]
	if not state or state.life ~= "DOWNED" or not d then
		return
	end
	clearDowned(player)
	local humanoid = getHumanoid(player)
	local character = player.Character
	if not humanoid or not character or humanoid.Health <= 0 then
		-- El personaje ya no sirve: que aparezca de nuevo
		respawn(player)
		return
	end
	setLife(player, state, "ALIVE")
	humanoid.WalkSpeed = PlayerCfg.WalkSpeed
	humanoid.JumpHeight = d.jumpHeight
	humanoid.JumpPower = d.jumpPower
	humanoid.Health = math.max(1, humanoid.MaxHealth * CoopCfg.ReviveHealthFraction)
	addShield(character, "ReviveShield", CoopCfg.ReviveInvulnerability)

	if rescuer then
		local rescuerState = PlayerData.get(rescuer)
		if rescuerState then
			rescuerState.revives += 1
		end
	end
end

-- Se acabó el tiempo (o se reseteó): afuera hasta el próximo descanso.
local function eliminate(player: Player)
	local state = PlayerData.get(player)
	if not state then
		return
	end
	clearDowned(player)
	setLife(player, state, "ELIMINATED")
	local humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function createDownedVisuals(player: Player, character: Model, root: BasePart): (ProximityPrompt, BillboardGui, Frame, Frame, Highlight)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	local gui = Instance.new("BillboardGui")
	gui.Name = "DownedGui"
	gui.Size = UDim2.fromOffset(110, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = root
	gui.Parent = character

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Text = "¡AYUDA!"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 90, 90)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local function bar(y: number, color: Color3): Frame
		local back = Instance.new("Frame")
		back.Position = UDim2.fromOffset(5, y)
		back.Size = UDim2.new(1, -10, 0, 8)
		back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		back.BorderSizePixel = 0
		back.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Parent = back
		return fill
	end
	local timerFill = bar(22, Color3.fromRGB(255, 90, 90)) -- tiempo que le queda
	local reviveFill = bar(33, Color3.fromRGB(90, 220, 120)) -- progreso del rescate
	reviveFill.Size = UDim2.fromScale(0, 1)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revivir"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = CoopCfg.ReviveTime
	prompt.MaxActivationDistance = CoopCfg.ReviveRadius
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root

	return prompt, gui, timerFill, reviveFill, highlight
end

-- ¿Este jugador puede estar rescatando a `target` ahora mismo?
local function validRescuer(rescuer: Player, target: Player): boolean
	if rescuer == target then
		return false
	end
	local s = PlayerData.get(rescuer)
	local rescuerRoot = getRoot(rescuer)
	local targetRoot = getRoot(target)
	local humanoid = getHumanoid(rescuer)
	if not s or s.life ~= "ALIVE" or not s.inMatch or not rescuerRoot or not targetRoot or not humanoid or humanoid.Health <= 0 then
		return false
	end
	return flatDistance(rescuerRoot, targetRoot) <= CoopCfg.ReviveRadius + CoopCfg.ReviveTolerance
end

local function down(player: Player, state: State, humanoid: Humanoid)
	local character = player.Character
	local root = getRoot(player)
	if not character or not root then
		eliminate(player)
		return
	end
	setLife(player, state, "DOWNED")
	state.downs += 1
	PlayerData.setChoosingShield(player, false)

	-- Queda en el piso con 1 de vida: nunca llega a 0, así el Humanoid no muere.
	local jumpHeight, jumpPower = humanoid.JumpHeight, humanoid.JumpPower
	humanoid.Health = 1
	humanoid.WalkSpeed = CoopCfg.DownedWalkSpeed
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0

	local prompt, gui, timerFill, reviveFill, highlight = createDownedVisuals(player, character, root)
	local d: Downed = {
		player = player,
		timeLeft = CoopCfg.DownedTime,
		holders = {},
		prompt = prompt,
		gui = gui,
		timerFill = timerFill,
		reviveFill = reviveFill,
		highlight = highlight,
		connections = {},
		publishTimer = 0,
		jumpHeight = jumpHeight,
		jumpPower = jumpPower,
	}
	downed[player] = d
	player:SetAttribute("DownedLeft", d.timeLeft)
	player:SetAttribute("ReviveProgress", 0)

	-- El cliente avisa cuándo empieza y suelta el botón; el servidor lleva el tiempo.
	table.insert(
		d.connections,
		prompt.PromptButtonHoldBegan:Connect(function(rescuer: Player)
			if validRescuer(rescuer, player) and not d.holders[rescuer] then
				d.holders[rescuer] = os.clock()
			end
		end)
	)
	table.insert(
		d.connections,
		prompt.PromptButtonHoldEnded:Connect(function(rescuer: Player)
			d.holders[rescuer] = nil
		end)
	)
	table.insert(
		d.connections,
		prompt.Triggered:Connect(function(rescuer: Player)
			local started = d.holders[rescuer]
			-- Solo cuenta si el servidor vio todo el tiempo de rescate y sigue siendo válido.
			-- Como revive() cambia el estado a ALIVE, un segundo rescate llega tarde y se ignora.
			if
				started
				and downed[player] == d
				and validRescuer(rescuer, player)
				and os.clock() - started >= CoopCfg.ReviveTime - 0.25
			then
				revive(player, rescuer)
			end
		end)
	)
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------

function PlayerLife.init()
	-- Sin aparición automática de Roblox: este módulo decide cuándo aparece cada uno.
	Players.CharacterAutoLoads = false
end

-- Única forma de dañar a un jugador. Respeta escudos (ForceField), el estado y el lobby.
function PlayerLife.damage(target: PlayerData.Target, amount: number)
	local state = target.state
	if state.life ~= "ALIVE" or not state.inMatch or amount <= 0 then
		return
	end
	local character = target.player.Character
	if not character or character:FindFirstChildOfClass("ForceField") then
		return
	end
	local humanoid = target.humanoid
	CombatFeed.hurt(target.player, amount) -- número rojo en su pantalla
	if humanoid.Health - amount <= 0 then
		down(target.player, state, humanoid)
	else
		humanoid.Health -= amount
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local state = PlayerData.get(player)
	if not state then
		return
	end
	setLife(player, state, "ALIVE")
	local at = pendingSpawn[player]
	if at then
		pendingSpawn[player] = nil
		character:PivotTo(at)
	end
	humanoid.WalkSpeed = PlayerCfg.WalkSpeed
	humanoid.MaxHealth = state.stats.maxHealth
	humanoid.Health = humanoid.MaxHealth
	addShield(character, "SpawnShield", PlayerCfg.SpawnInvulnerability)
	-- Si tiene una elección de habilidad abierta, el escudo de elección vuelve con el personaje.
	if state.currentOffer then
		PlayerData.setChoosingShield(player, true)
	end

	-- Muerte "de verdad" (reset, caída al vacío...). Lo normal es no llegar acá:
	-- la vida en 0 lleva a DOWNED con 1 de vida.
	humanoid.Died:Connect(function()
		local s = PlayerData.get(player)
		if not s or player.Character ~= character then
			return
		end
		if not s.inMatch then
			-- En el lobby no hay derrota: vuelve a aparecer enseguida
			task.delay(2, function()
				local now = PlayerData.get(player)
				if now and not now.inMatch and player.Character == character then
					respawn(player)
				end
			end)
		elseif s.life ~= "ELIMINATED" then
			clearDowned(player)
			setLife(player, s, "ELIMINATED")
		end
	end)
end

function PlayerLife.onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local state = PlayerData.get(player)
	if not state then
		return
	end
	-- Siempre se entra al lobby. Si hay una partida en curso, se suma a la siguiente.
	setInMatch(player, state, false)
	respawn(player)
end

function PlayerLife.onPlayerRemoving(player: Player)
	clearDowned(player)
	pendingSpawn[player] = nil
	for _, d in downed do
		d.holders[player] = nil
	end
end

-- Por frame: relojes de derribo, validación de rescatadores y barras.
function PlayerLife.update(dt: number)
	for player, d in downed do
		-- Saca a los que dejaron de ser válidos (se alejaron, cayeron, se fueron)
		local best = 0
		for rescuer, started in d.holders do
			if validRescuer(rescuer, player) then
				best = math.max(best, (os.clock() - started) / CoopCfg.ReviveTime)
			else
				d.holders[rescuer] = nil
			end
		end
		local beingRevived = best > 0

		if not (beingRevived and CoopCfg.PauseTimerWhileReviving) then
			d.timeLeft -= dt
		end
		if d.timeLeft <= 0 then
			eliminate(player)
			continue
		end

		-- Barras y atributos a 10 Hz (no hace falta más)
		d.publishTimer -= dt
		if d.publishTimer <= 0 then
			d.publishTimer = 0.1
			local progress = math.clamp(best, 0, 1)
			d.timerFill.Size = UDim2.fromScale(d.timeLeft / CoopCfg.DownedTime, 1)
			d.reviveFill.Size = UDim2.fromScale(progress, 1)
			player:SetAttribute("DownedLeft", math.ceil(d.timeLeft * 10) / 10)
			player:SetAttribute("ReviveProgress", progress)
			local name = ""
			if beingRevived then
				for rescuer in d.holders do
					name = rescuer.DisplayName
					break
				end
			end
			player:SetAttribute("RevivedBy", name)
		end
	end
end

-- Descanso entre oleadas: los derribados se levantan y los eliminados vuelven a la arena.
-- arenaPoint: dónde reaparece un eliminado (dentro de la arena).
function PlayerLife.onBreak(arenaPoint: CFrame)
	for player, state in PlayerData.all() do
		if not state.inMatch then
			continue
		end
		if state.life == "DOWNED" then
			revive(player, nil)
		elseif state.life == "ELIMINATED" then
			respawn(player, arenaPoint)
		end
	end
end

-- Empieza la partida: los participantes aparecen de cero en la arena, cada uno en su punto.
function PlayerLife.beginMatch(participants: { Player }, points: { CFrame })
	for i, player in participants do
		local state = PlayerData.get(player)
		if state then
			setInMatch(player, state, true)
			respawn(player, points[i] or points[1])
		end
	end
end

-- Termina la partida: se limpian los derribos y todos los participantes vuelven al lobby.
function PlayerLife.endMatch()
	for player in downed do
		clearDowned(player)
	end
	for player, state in PlayerData.all() do
		if state.inMatch then
			setInMatch(player, state, false)
			respawn(player)
		end
	end
end

-- Participantes de la partida en curso.
function PlayerLife.participants(): { Player }
	local list = {}
	for player, state in PlayerData.all() do
		if state.inMatch then
			table.insert(list, player)
		end
	end
	return list
end

-- true si hay participantes pero ninguno está ALIVE (nadie puede pelear ni rescatar).
function PlayerLife.noneActive(): boolean
	local any = false
	for _, state in PlayerData.all() do
		if state.inMatch then
			any = true
			if state.life == "ALIVE" then
				return false
			end
		end
	end
	return any
end

-- Cantidad de participantes para el escalado de dificultad (1 a 4).
function PlayerLife.partySize(): number
	return math.clamp(#PlayerLife.participants(), 1, #CoopCfg.Scaling)
end

return PlayerLife
