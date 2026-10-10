-- AvatarView (ModuleScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > AvatarView
-- Tu personaje en 3D dentro de un ViewportFrame: encuadrado entero (por alto y por ancho)
-- y se gira arrastrando con el mouse o el dedo. Lo usan las pantallas de Equipo y Runas.
--
--   local view = AvatarView.new(parent)   -- crea el ViewportFrame (ubicarlo con view.frame)
--   view.refresh()                        -- copia el personaje actual (al abrir la pantalla)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

local player = Players.LocalPlayer

local AvatarView = {}

local MARGIN = 1.5 -- espacio alrededor del personaje (más grande = personaje más chico)
local DRAG_SPEED = 0.012 -- radianes por píxel arrastrado

function AvatarView.new(parent: Instance)
	local viewport = Theme.make("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 170),
		LightColor = Color3.fromRGB(255, 245, 225),
		Active = true, -- recibe el arrastre para girarlo
		Parent = parent,
	})
	local camera = Theme.make("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local world = Theme.make("WorldModel", { Parent = viewport })
	Theme.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "↔ arrastrá para girar",
		TextSize = 12,
		TextColor3 = Theme.Colors.TextMuted,
		TextStrokeTransparency = 0.6,
		Parent = viewport,
	})

	local avatar: Model? = nil
	local height, width, centerY = 5, 3, 0
	local yaw = math.rad(-20) -- un poco girado al abrir

	-- Gira el personaje sobre su eje (la cámara queda fija en -Z mirándolo de frente)
	local function applyYaw()
		if avatar then
			avatar:PivotTo(CFrame.Angles(0, yaw, 0))
		end
	end

	-- Encuadra al personaje entero, con margen, según el tamaño del visor
	local function frame()
		local size = viewport.AbsoluteSize
		if size.Y < 1 then
			return
		end
		local halfV = math.rad(camera.FieldOfView / 2)
		local halfH = math.atan(math.tan(halfV) * size.X / size.Y)
		local byHeight = (height / 2) / math.tan(halfV)
		local byWidth = (width / 2) / math.tan(halfH)
		local distance = math.max(byHeight, byWidth) * MARGIN
		camera.CFrame = CFrame.lookAt(Vector3.new(0, centerY, -distance), Vector3.new(0, centerY, 0))
	end
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)

	local function refresh()
		world:ClearAllChildren()
		avatar = nil
		local character = player.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then
			return
		end
		local archivable = character.Archivable
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = archivable
		if not copy then
			return
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("ForceField") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		copy:PivotTo(CFrame.new())
		copy.Parent = world
		local box, size = copy:GetBoundingBox()
		height = size.Y
		-- Al girar puede quedar de costado: el ancho a encuadrar es el mayor de los dos lados
		width = math.max(size.X, size.Z)
		centerY = box.Position.Y
		avatar = copy
		applyYaw()
		frame()
	end

	-- Girar arrastrando (mouse o dedo)
	local dragInput: InputObject? = nil
	local lastX = 0
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			lastX = input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragInput then
			return
		end
		local isMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
		if isMouse or input == dragInput then
			yaw += (input.Position.X - lastX) * DRAG_SPEED
			lastX = input.Position.X
			applyYaw()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput or (dragInput and input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragInput = nil
		end
	end)

	-- El personaje cambia al reaparecer: si la pantalla está abierta, se vuelve a copiar
	player.CharacterAdded:Connect(function()
		task.wait(1) -- que carguen ropa y accesorios
		if viewport:FindFirstAncestorOfClass("ScreenGui") and viewport:FindFirstAncestorOfClass("ScreenGui").Enabled then
			refresh()
		end
	end)

	return { frame = viewport, refresh = refresh }
end

return AvatarView
