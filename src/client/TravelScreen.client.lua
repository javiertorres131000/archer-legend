--!strict
-- TravelScreen (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > TravelScreen
-- Pantalla de viaje entre la Ciudadela y la Arena (los teletransporta Server/Teleporter).
--   · Cuando el servidor marca Traveling = "Arena" o "Lobby", tapa la pantalla con el cartel del
--     viaje y se lo pasa a TeleportService:SetTeleportGui, así se sigue viendo durante el viaje.
--   · Al llegar al otro place, la pantalla que vino con el viaje (GetArrivingTeleportGui) se
--     queda unos instantes y se desvanece cuando ya cargó tu personaje.
--   · Si el viaje falla, el servidor borra Traveling y la pantalla se va.
--   · En la Arena (PlaceRole = "Arena") la pantalla tapa todo mientras no estás jugando: así
--     nunca se ve la sala de espera, solo "Preparando la batalla" hasta que arranca la partida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local Chapters = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Chapters"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors, Fonts = Theme.Colors, Theme.Fonts
local make = Theme.make
local C = Color3.fromRGB

local TIPS = {
	"Consejo: el dash te salva de casi todo. Usalo para esquivar, no solo para correr.",
	"Consejo: en el descanso entre oleadas, juntá a tu grupo en la puerta.",
	"Consejo: las runas se combinan. Probá mezclas raras.",
	"Consejo: si un compañero cae, rescatalo antes de que se termine el tiempo.",
	"Consejo: los jefes avisan antes de atacar. Mirá el piso.",
}

local function chapterName(id: string?): string
	for i, ch in Chapters do
		if ch.Id == id then
			return string.format("Capítulo %d · %s", i, ch.Name)
		end
	end
	return ""
end

-- Arma la pantalla (también es la que viaja con TeleportService)
local function build(destination: string): ScreenGui
	local toArena = destination == "Arena"
	local gui = make("ScreenGui", {
		Name = "TravelScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local bg = make("Frame", {
		Name = "Fondo",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C(10, 8, 16),
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		make("UIGradient", {
			Rotation = 90,
			Color = if toArena
				then ColorSequence.new(C(60, 24, 18), C(8, 6, 12))
				else ColorSequence.new(C(34, 30, 64), C(8, 6, 12)),
		}),
	})
	local center = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(700, 260),
		BackgroundTransparency = 1,
		Parent = bg,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 700 / 260, Parent = center })
	make("UISizeConstraint", { MaxSize = Vector2.new(700, 260), Parent = center })
	-- anillo que gira
	local ring = make("Frame", {
		Name = "Anillo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(70, 70),
		BackgroundTransparency = 1,
		Parent = center,
	}, {
		Theme.corner(35),
		make("UIStroke", { Color = Colors.GoldBright, Thickness = 4 }, {
			make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.6, 0.9),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = if toArena then "⚔" else "🏰",
		TextSize = 30,
		Font = Fonts.Bold,
		TextColor3 = Colors.GoldBright,
		Parent = ring,
	})
	make("TextLabel", {
		Position = UDim2.new(0, 0, 0, 92),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Name = "Titulo",
		Text = if toArena then "Viajando a la Arena" else "Volviendo a la Ciudadela",
		Font = Fonts.Title,
		TextScaled = true,
		TextColor3 = Colors.GoldBright,
		TextStrokeTransparency = 0.5,
		Parent = center,
	}, { make("UITextSizeConstraint", { MaxTextSize = 52 }) })
	make("TextLabel", {
		Position = UDim2.new(0, 0, 0, 152),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Name = "Subtitulo",
		Text = if toArena then chapterName(player:GetAttribute("PartyChapter") :: string?) else "Guardando tu progreso…",
		Font = Fonts.Heading,
		TextScaled = true,
		TextColor3 = Colors.Text,
		Parent = center,
	}, { make("UITextSizeConstraint", { MaxTextSize = 24 }) })
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(0.8, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = TIPS[math.random(1, #TIPS)],
		Font = Fonts.Body,
		TextScaled = true,
		TextColor3 = Colors.TextMuted,
		Parent = bg,
	}, { make("UITextSizeConstraint", { MaxTextSize = 18 }) })
	return gui
end

-- Animación del anillo (en la pantalla local y en la que llega del viaje)
local spinning: { GuiObject } = {}
RunService.RenderStepped:Connect(function(dt)
	for i = #spinning, 1, -1 do
		local ring = spinning[i]
		if ring.Parent then
			ring.Rotation = (ring.Rotation + dt * 240) % 360
		else
			table.remove(spinning, i)
		end
	end
end)
local function spin(gui: ScreenGui)
	local ring = gui:FindFirstChild("Anillo", true)
	if ring and ring:IsA("GuiObject") then
		table.insert(spinning, ring)
	end
end

local function fadeOut(gui: ScreenGui, delaySeconds: number)
	task.delay(delaySeconds, function()
		local info = TweenInfo.new(0.6)
		for _, d in gui:GetDescendants() do
			if d:IsA("Frame") then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.7, function()
			gui:Destroy()
		end)
	end)
end

-- Salida
local current: ScreenGui? = nil
local function onTraveling()
	local where = player:GetAttribute("Traveling")
	if where == "Arena" or where == "Lobby" then
		if current then
			current:Destroy()
		end
		local gui = build(where :: string)
		gui.Parent = playerGui
		spin(gui)
		current = gui
		pcall(function()
			TeleportService:SetTeleportGui(build(where :: string))
		end)
	elseif current then
		-- El viaje falló (o terminó sin salir): se saca la pantalla
		fadeOut(current, 0)
		current = nil
	end
end
player:GetAttributeChangedSignal("Traveling"):Connect(onTraveling)

-- Llegada y cortina de la Arena
local gameState = ReplicatedStorage:WaitForChild("GameState")
local arenaCover: ScreenGui? = nil

local function setLabel(gui: ScreenGui, name: string, value: string)
	local label = gui:FindFirstChild(name, true)
	if label and label:IsA("TextLabel") then
		label.Text = value
	end
end

local function updateArenaCover()
	local isArena = gameState:GetAttribute("PlaceRole") == "Arena"
	local need = isArena and player:GetAttribute("InMatch") ~= true and player:GetAttribute("Traveling") == nil
	if need and not arenaCover then
		local gui = build("Arena")
		gui.Name = "ArenaCover"
		gui.Parent = playerGui
		spin(gui)
		arenaCover = gui
	elseif not need and arenaCover then
		fadeOut(arenaCover, 0.2)
		arenaCover = nil
	end
	local cover = arenaCover
	if cover then
		local state = gameState:GetAttribute("MatchState")
		local waiting = (gameState:GetAttribute("ArenaWaiting") or "") :: string
		if state == "STARTING" then
			setLabel(cover, "Titulo", "¡Arranca la batalla!")
		elseif state == "RESULTS" or state == "RETURNING" then
			setLabel(cover, "Titulo", "Preparando la revancha")
		else
			setLabel(cover, "Titulo", "Preparando la batalla")
		end
		local chapter = chapterName(gameState:GetAttribute("SelectedChapter") :: string?)
		setLabel(cover, "Subtitulo", chapter .. (if waiting ~= "" then "  ·  llegaron " .. waiting else ""))
	end
end
for _, attr in { "PlaceRole", "MatchState", "ArenaWaiting", "SelectedChapter" } do
	gameState:GetAttributeChangedSignal(attr):Connect(updateArenaCover)
end
player:GetAttributeChangedSignal("InMatch"):Connect(updateArenaCover)
player:GetAttributeChangedSignal("Traveling"):Connect(updateArenaCover)
updateArenaCover()

local ok, arriving = pcall(function()
	return TeleportService:GetArrivingTeleportGui()
end)
if ok and arriving and arriving:IsA("ScreenGui") then
	arriving.Parent = playerGui
	spin(arriving)
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		-- en la Arena la cortina ya tapa la espera: esta se va enseguida, sin parpadeo
		fadeOut(arriving, if arenaCover then 0.3 else 1)
	end)
end
