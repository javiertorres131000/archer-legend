-- AttackInput (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > AttackInput
-- Disparo manual (Config.Player.FireMode = "Manual"): click izquierdo, R2 en el joystick o el
-- botón ATACAR en el celular. Mantener apretado sigue atacando a la cadencia del arma.
-- Apunta con la mira: en primera y tercera persona, hacia donde mira la cámara; en cenital,
-- hacia el mouse. Solo avisa "apretado + dirección": el servidor (Combat.setTrigger) valida,
-- respeta la cadencia y calcula todo el daño.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttackRequest") :: RemoteEvent

local player = Players.LocalPlayer
local ACTION = "CombatAttack"
local RESEND = 1 / 15 -- mientras está apretado, actualiza la puntería cada tanto
local MIN_TURN = math.cos(math.rad(2)) -- y solo si giró más de 2°

local holding = false
local lastSent = 0
local lastDir: Vector3? = nil

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function aimDirection(): Vector3?
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return nil
	end
	if Config.Camera.Mode == "TopDown" then
		-- Hacia el punto del piso debajo del mouse
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		if ray.Direction.Y < -0.01 then
			local t = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
			local d = flat(ray.Origin + ray.Direction * t - root.Position)
			if d.Magnitude > 0.5 then
				return d.Unit
			end
		end
		local look = flat(root.CFrame.LookVector)
		return if look.Magnitude > 0.01 then look.Unit else nil
	end
	-- La cámara puede estar desplazada del personaje (vista al hombro).
	-- Converger sobre el punto de la mira desde el origen real del disparo.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local distance = math.max(Config.Player.AttackRange, 80)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * distance, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * distance
	local look = flat(point - root.Position)
	return if look.Magnitude > 0.01 then look.Unit else nil
end

local function send(force: boolean)
	local dir = aimDirection()
	if not dir then
		return
	end
	if not force and lastDir and dir:Dot(lastDir) > MIN_TURN then
		return
	end
	lastDir = dir
	lastSent = os.clock()
	remote:FireServer(holding, dir)
end

local function setHolding(value: boolean)
	if holding == value then
		return
	end
	holding = value
	send(true)
end

local function onAction(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if player:GetAttribute("InMatch") ~= true then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		setHolding(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setHolding(false)
	end
	return Enum.ContextActionResult.Pass -- no tapa otros usos del click
end

local bound = false
local function refresh()
	local active = Config.Player.FireMode == "Manual" and player:GetAttribute("InMatch") == true
	if active and not bound then
		ContextActionService:BindAction(ACTION, onAction, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "ATACAR")
		ContextActionService:SetPosition(ACTION, UDim2.fromScale(0.82, 0.5))
		bound = true
	elseif not active and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
		holding = false
	end
end
player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
refresh()

-- Mientras está apretado, la puntería sigue a la cámara
RunService.Heartbeat:Connect(function()
	if holding and os.clock() - lastSent >= RESEND then
		send(false)
	end
end)

-- Si la ventana pierde el foco con el botón apretado, se suelta
UserInputService.WindowFocusReleased:Connect(function()
	setHolding(false)
end)
