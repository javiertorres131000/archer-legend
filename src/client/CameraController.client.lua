-- CameraController (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > CameraController
-- Cámara según dónde estés (Config.Camera.Mode elige la de la arena):
--   Lobby                 → tercera persona normal de Roblox, para pasear
--   Arena, "FirstPerson"  → primera persona: ves por los ojos de tu personaje
--   Arena, "TopDown"      → cenital fija desde arriba (mira hacia -Z)
--   Eliminado             → desde arriba, siguiendo a un compañero en pie
-- Derribado: la cámara sigue en tu personaje (para ver si viene alguien a revivirte).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CamCfg = Config.Camera

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local offset = Vector3.new(0, CamCfg.Height, CamCfg.Back)
local lastFocus = Vector3.zero
local current = "" -- modo aplicado ahora: "Lobby" | "FirstPerson" | "TopDown"

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
	current = mode
	if mode == "FirstPerson" then
		player.CameraMinZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		camera.FieldOfView = CamCfg.FirstPersonFieldOfView
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- Saca la cámara de adentro de la cabeza al volver al lobby
		player.CameraMinZoomDistance = 8
		task.delay(0.2, function()
			if current == mode then
				player.CameraMinZoomDistance = 0.5
			end
		end)
		camera.FieldOfView = CamCfg.LobbyFieldOfView
	end
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = humanoidOf(player)
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

RunService:BindToRenderStep("ArqueroCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local inMatch = player:GetAttribute("InMatch") == true
	local eliminated = player:GetAttribute("LifeState") == "ELIMINATED"

	if not inMatch then
		useRobloxCamera("Lobby")
		return
	end
	if CamCfg.Mode == "FirstPerson" and not eliminated then
		useRobloxCamera("FirstPerson")
		return
	end

	-- Cenital (modo TopDown, o mirando a un compañero cuando estás eliminado)
	if current ~= "TopDown" then
		current = "TopDown"
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
