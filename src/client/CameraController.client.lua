-- CameraController (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > CameraController
-- Cámara según dónde estés (Config.Camera.Mode elige la de la arena):
--   Lobby                 → tercera persona normal de Roblox, para pasear
--   Arena, "FirstPerson"  → vista del jugador; con Config.Camera.ToggleKeys (V) alterna entre:
--       primera persona: ves por los ojos de tu personaje
--       tercera persona: detrás del hombro, con el mouse trabado al centro (como shift-lock)
--     En las dos el personaje mira hacia donde mira la cámara (el servidor apunta con eso).
--   Arena, "TopDown"      → cenital fija desde arriba (mira hacia -Z)
--   Eliminado             → desde arriba, siguiendo a un compañero en pie
-- Apertura de cajas (atributo "Cinematic" del jugador): no toca la cámara.
-- Derribado: la cámara sigue en tu personaje (para ver si viene alguien a revivirte).
-- Mouse: en la arena (primera o tercera persona) no se ve el cursor, como en Megabonk: el mouse
-- mueve la cámara y queda la mira. Vuelve a aparecer en el lobby y cuando hay un menú abierto
-- (cartas de habilidad, resultados): el HUD lo avisa con el atributo CursorFree del jugador.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CamCfg = Config.Camera

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local offset = Vector3.new(0, CamCfg.Height, CamCfg.Back)
local lastFocus = Vector3.zero
local current = "" -- modo aplicado ahora: "Lobby" | "FirstPerson" | "ThirdPerson" | "TopDown"
local view = CamCfg.DefaultView or "FirstPerson" -- vista elegida para la arena
local defaultMaxZoom = player.CameraMaxZoomDistance

local function humanoidOf(p: Player): Humanoid?
	local character = p.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(p: Player): BasePart?
	local character = p.Character
	local humanoid = humanoidOf(p)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function getFocus(): Vector3
	local life = player:GetAttribute("LifeState")
	if life ~= "ELIMINATED" then
		local own = rootOf(player)
		if own then
			return own.Position
		end
	end
	-- Espectador: primero un compañero en pie, si no, cualquiera con personaje
	local fallback: Vector3? = nil
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local root = rootOf(other)
			if root then
				if other:GetAttribute("LifeState") == "ALIVE" then
					return root.Position
				end
				fallback = fallback or root.Position
			end
		end
	end
	return fallback or lastFocus
end

-- Deja el personaje como lo maneja Roblox (sin hombro, girando hacia donde camina)
local function resetShoulder()
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
		humanoid.AutoRotate = true
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Saca la cámara de adentro de la cabeza: fuerza un zoom mínimo un momento y después lo libera
local function pushCameraOut(minZoom: number, thenMin: number, mode: string)
	player.CameraMinZoomDistance = minZoom
	task.delay(0.2, function()
		if current == mode then
			player.CameraMinZoomDistance = thenMin
		end
	end)
end

-- Tercera persona en la arena: el personaje gira con la cámara, como en primera persona
local function updateShoulder()
	local humanoid = humanoidOf(player)
	local root = rootOf(player)
	if not humanoid or not root then
		return
	end
	-- (Se repite cada cuadro porque el personaje cambia al reaparecer)
	humanoid.CameraOffset = CamCfg.ThirdPersonShoulder
	humanoid.AutoRotate = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	if player:GetAttribute("LifeState") == "DOWNED" then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

-- Cámara normal de Roblox que sigue al personaje (tercera o primera persona).
local function useRobloxCamera(mode: string)
	if current == mode and camera.CameraType == Enum.CameraType.Custom then
		-- El personaje cambia al reaparecer: que la cámara lo siga
		local humanoid = humanoidOf(player)
		if humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
		return
	end
	if current == "ThirdPerson" then
		resetShoulder()
	end
	current = mode
	player:SetAttribute("CameraView", mode) -- lo usa WeaponFx (arma en primera persona)
	if mode == "FirstPerson" then
		player.CameraMaxZoomDistance = defaultMaxZoom
		player.CameraMinZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		camera.FieldOfView = CamCfg.FirstPersonFieldOfView
	elseif mode == "ThirdPerson" then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = CamCfg.ThirdPersonMaxZoom
		pushCameraOut(CamCfg.ThirdPersonDistance, CamCfg.ThirdPersonMinZoom, mode)
		camera.FieldOfView = CamCfg.ThirdPersonFieldOfView
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = defaultMaxZoom
		pushCameraOut(8, 0.5, mode)
		camera.FieldOfView = CamCfg.LobbyFieldOfView
	end
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = humanoidOf(player)
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Alternar primera / tercera persona (solo tiene efecto en la arena con Mode = "FirstPerson")
local toggleKeys = {}
for _, key in CamCfg.ToggleKeys or {} do
	toggleKeys[key] = true
end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not toggleKeys[input.KeyCode] then
		return
	end
	view = if view == "FirstPerson" then "ThirdPerson" else "FirstPerson"
end)

-- Cursor visible solo donde hace falta (ver arriba)
local cursorShown = true
local function syncCursor(inMatch: boolean, eliminated: boolean)
	local hide = inMatch
		and CamCfg.Mode == "FirstPerson"
		and not eliminated
		and player:GetAttribute("CursorFree") ~= true
		and player:GetAttribute("PanelCursor") ~= true -- panel de prueba (F2) abierto
	if cursorShown == hide then
		cursorShown = not hide
		UserInputService.MouseIconEnabled = cursorShown
	end
end

RunService:BindToRenderStep("ArqueroCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local inMatch = player:GetAttribute("InMatch") == true
	local eliminated = player:GetAttribute("LifeState") == "ELIMINATED"
	syncCursor(inMatch, eliminated)
	-- Animación de apertura de cajas: la cámara la maneja CrateCinematic
	if player:GetAttribute("Cinematic") == true then
		current = ""
		return
	end

	if not inMatch then
		useRobloxCamera("Lobby")
		return
	end
	if CamCfg.Mode == "FirstPerson" and not eliminated then
		useRobloxCamera(view)
		if view == "ThirdPerson" then
			updateShoulder()
		end
		return
	end

	-- Cenital (modo TopDown, o mirando a un compañero cuando estás eliminado)
	if current ~= "TopDown" then
		if current == "ThirdPerson" then
			resetShoulder()
		end
		current = "TopDown"
		player:SetAttribute("CameraView", current)
		player.CameraMode = Enum.CameraMode.Classic
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CamCfg.FieldOfView
	local target = getFocus()
	if (target - lastFocus).Magnitude > 100 then
		lastFocus = target -- recién llegado a la arena: sin deslizarse desde el lobby
	end
	-- Suavizado: al pasar a mirar a otro jugador, la cámara se desliza en vez de saltar
	lastFocus = lastFocus:Lerp(target, math.clamp(dt * 12, 0, 1))
	camera.CFrame = CFrame.lookAt(lastFocus + offset, lastFocus)
end)
