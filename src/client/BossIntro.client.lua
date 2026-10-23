--!strict
-- BossIntro (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > BossIntro
-- Cinemática de entrada de un jefe (hoy Azrakoth, campo Intro en Data/EnemyTypes). El servidor
-- congela el combate y publica en GameState el atributo BossIntro = "Título|Subtítulo|hora|duración";
-- acá cada jugador ve su propia cámara: franjas de cine, plano bajo, primer plano del casco,
-- plano abierto cuando se levanta y despliega las alas, y el rugido con el título. Solo visual.
-- Espacio / botón A / tocar la pantalla: saltear.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gameState = ReplicatedStorage:WaitForChild("GameState") -- (Remotes.GameState en el servidor = ReplicatedStorage.GameState)

local activa = false

local function tween(obj: Instance, t: number, props: { [string]: any }, estilo: Enum.EasingStyle?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function buscarJefe(): BasePart?
	local carpeta = Workspace:FindFirstChild("Enemies")
	if not carpeta then
		return nil
	end
	for _, c in carpeta:GetChildren() do
		if c:IsA("BasePart") and c:GetAttribute("ThreatRole") == "Boss" then
			return c
		end
	end
	return nil
end

-- Pantalla: franjas negras, título, viñeta roja y botón de saltear
local function armarGui(titulo: string, subtitulo: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossIntro"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	local function franja(arriba: boolean): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, if arriba then 0 else 1)
		f.Position = UDim2.fromScale(0, if arriba then 0 else 1)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local sup, inf = franja(true), franja(false)
	local tit = Instance.new("TextLabel")
	tit.BackgroundTransparency = 1
	tit.AnchorPoint = Vector2.new(0.5, 0.5)
	tit.Position = UDim2.fromScale(0.5, 0.72)
	tit.Size = UDim2.fromScale(0.9, 0.12)
	tit.Font = Enum.Font.Fantasy
	tit.Text = titulo
	tit.TextScaled = true
	tit.TextColor3 = Color3.fromRGB(255, 225, 190)
	tit.TextStrokeColor3 = Color3.fromRGB(150, 10, 10)
	tit.TextStrokeTransparency = 0
	tit.TextTransparency = 1
	tit.Parent = gui
	local sub = tit:Clone()
	sub.Position = UDim2.fromScale(0.5, 0.8)
	sub.Size = UDim2.fromScale(0.7, 0.045)
	sub.Font = Enum.Font.GothamBold
	sub.Text = string.upper(subtitulo)
	sub.TextColor3 = Color3.fromRGB(255, 120, 90)
	sub.TextStrokeColor3 = Color3.new(0, 0, 0)
	sub.Parent = gui
	local saltar = Instance.new("TextLabel")
	saltar.BackgroundTransparency = 1
	saltar.AnchorPoint = Vector2.new(1, 1)
	saltar.Position = UDim2.new(1, -24, 1, -18)
	saltar.Size = UDim2.fromOffset(220, 24)
	saltar.Font = Enum.Font.GothamBold
	saltar.TextSize = 14
	saltar.TextXAlignment = Enum.TextXAlignment.Right
	saltar.Text = "ESPACIO · Saltear"
	saltar.TextColor3 = Color3.fromRGB(200, 200, 200)
	saltar.TextTransparency = 0.4
	saltar.ZIndex = 3
	saltar.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	tween(sup, 0.6, { Size = UDim2.fromScale(1, 0.12) })
	tween(inf, 0.6, { Size = UDim2.fromScale(1, 0.12) })
	return gui, sup, inf, tit, sub
end

local function reproducir(texto: string)
	local campos = string.split(texto, "|")
	local titulo, subtitulo, hora, dura, grito, gritoAt = campos[1], campos[2], campos[3], campos[4], campos[5], campos[6]
	if not titulo or activa then
		return
	end
	local duracion = tonumber(dura) or 7
	local inicio = tonumber(hora) or Workspace:GetServerTimeNow()
	if Workspace:GetServerTimeNow() - inicio > duracion - 1 then
		return -- llegó tarde (entró a mitad): no vale la pena
	end
	-- esperar a que el jefe y su modelo existan en este cliente
	local jefe: BasePart? = nil
	for _ = 1, 40 do
		jefe = buscarJefe()
		if jefe and jefe:FindFirstChild("Look") then
			break
		end
		task.wait(0.05)
	end
	if not jefe then
		return
	end
	local boss = jefe :: BasePart
	local look = boss:FindFirstChild("Look") :: Model?
	activa = true
	player:SetAttribute("Cinematic", true) -- CameraController suelta la cámara (como en CrateCinematic)

	local cam = Workspace.CurrentCamera
	local fovAntes = cam.FieldOfView
	-- ocultar el HUD mientras dura
	local ocultas: { ScreenGui } = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "BossIntro" then
			g.Enabled = false
			table.insert(ocultas, g)
		end
	end
	local gui, sup, inf, tit, sub = armarGui(titulo :: string, subtitulo :: string)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BossIntroColor"
	cc.Parent = Lighting
	tween(cc, 1, { Brightness = -0.12, Contrast = 0.15, Saturation = -0.25, TintColor = Color3.fromRGB(255, 200, 190) })

	local terminado = false
	local tituloMostrado = false
	local function cerrar()
		if terminado then
			return
		end
		terminado = true
		RunService:UnbindFromRenderStep("BossIntroCam")
		ContextActionService:UnbindAction("BossIntroSkip")
		cam.FieldOfView = fovAntes
		player:SetAttribute("Cinematic", false) -- la cámara del juego vuelve a su modo
		-- arrancar la pelea mirando al jefe (sobre todo en primera persona)
		task.spawn(function()
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
			local char = player.Character
			local head = char and char:FindFirstChild("Head") :: BasePart?
			if head and boss.Parent then
				local objetivo = boss.Position + Vector3.new(0, boss.Size.Y * 0.15, 0)
				cam.CFrame = CFrame.lookAt(head.Position, objetivo)
			end
		end)
		tween(sup, 0.5, { Size = UDim2.fromScale(1, 0) })
		tween(inf, 0.5, { Size = UDim2.fromScale(1, 0) })
		tween(tit, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween(sub, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween(cc, 0.8, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		for _, g in ocultas do
			if g.Parent then
				g.Enabled = true
			end
		end
		task.delay(0.9, function()
			gui:Destroy()
			cc:Destroy()
			activa = false
		end)
	end
	ContextActionService:BindActionAtPriority("BossIntroSkip", function(_, estado)
		if estado == Enum.UserInputState.Begin then
			cerrar()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA,
		Enum.UserInputType.Touch)

	-- Planos (t en segundos desde que empezó la entrada)
	RunService:BindToRenderStep("BossIntroCam", Enum.RenderPriority.Last.Value, function()
		if not boss.Parent then
			cerrar()
			return
		end
		local t = Workspace:GetServerTimeNow() - inicio
		if t >= duracion then
			cerrar()
			return
		end
		local h = boss.Size.Y
		local suelo = boss.Position - Vector3.new(0, h / 2, 0)
		local f = boss.CFrame.LookVector
		f = Vector3.new(f.X, 0, f.Z).Unit
		local lado = f:Cross(Vector3.yAxis)
		local pecho = suelo + Vector3.new(0, h * 0.5, 0)
		local cabeza = if look and look:FindFirstChild("Head") then (look :: any).Head.Position else suelo + Vector3.new(0, h * 0.75, 0)
		local pos, mira, fov
		local temblor = 0
		if t < 2.3 then -- plano bajo: sube despacio desde el piso
			local k = suave(t / 2.3)
			pos = suelo + f * (h * 1.25 - k * h * 0.15) + lado * (h * 0.25) + Vector3.new(0, 1.5 + k * h * 0.15, 0)
			mira = suelo + Vector3.new(0, h * (0.3 + 0.2 * k), 0)
			fov = 55
		elseif t < 3.5 then -- primer plano del casco (se encienden los ojos)
			local k = suave((t - 2.3) / 1.2)
			pos = cabeza + f * (h * (0.42 - 0.06 * k)) + lado * (h * 0.06) + Vector3.new(0, -h * 0.03, 0)
			mira = cabeza
			fov = 38
		elseif t < 5.3 then -- se levanta y despliega las alas: la cámara se aleja
			local k = suave((t - 3.5) / 1.8)
			pos = suelo + f * (h * (1.0 + 0.8 * k)) - lado * (h * (0.5 - 0.3 * k)) + Vector3.new(0, h * (0.25 + 0.2 * k), 0)
			mira = pecho + Vector3.new(0, h * 0.1, 0)
			fov = 60
			temblor = if t > 4.4 then 0.25 else 0
		else -- rugido: contrapicado, gira despacio, tiembla
			local k = suave((t - 5.3) / 1.9)
			local giro = CFrame.Angles(0, math.rad(-18 + 30 * k), 0)
			pos = suelo + (giro:VectorToWorldSpace(f) * h * 0.95) + Vector3.new(0, 2, 0)
			mira = pecho + Vector3.new(0, h * 0.25, 0)
			fov = 64 - 6 * k
			temblor = 0.6 * (1 - k)
			if not tituloMostrado then
				tituloMostrado = true
				tween(tit, 0.35, { TextTransparency = 0 }, Enum.EasingStyle.Back)
				tween(sub, 0.6, { TextTransparency = 0 })
			end
		end
		local now = os.clock()
		local sacudon = Vector3.new(math.noise(now * 22, 1), math.noise(now * 22, 2), 0) * temblor
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(pos + sacudon, mira)
		cam.FieldOfView = fov
	end)

	-- Grito del jefe en el rugido (se escucha aunque se saltee la cinemática)
	if grito and grito ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = grito
		s.Volume = 3
		s.RollOffMaxDistance = 1000 -- se escucha en toda la arena
		s.Parent = boss
		local espera = (tonumber(gritoAt) or 0) - (Workspace:GetServerTimeNow() - inicio)
		task.delay(math.max(espera, 0), function()
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end)
		task.delay(20, function()
			if s.Parent then s:Destroy() end
		end)
	end
	task.delay(duracion + 0.1, cerrar)
end

gameState:GetAttributeChangedSignal("BossIntro"):Connect(function()
	local v = gameState:GetAttribute("BossIntro")
	if type(v) == "string" and v ~= "" then
		task.spawn(reproducir, v)
	end
end)
