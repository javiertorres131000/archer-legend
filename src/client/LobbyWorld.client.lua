--!strict
-- LobbyWorld (LocalScript)
-- Ubicación: StarterPlayer > StarterPlayerScripts > Client > LobbyWorld
-- Lo que pasa en tu pantalla en la Ciudadela del lobby (la arma Server/LobbyWorld):
--   · Prompts de la ciudadela (atributo LobbyAction): "Tienda" y "Misiones" abren la ventana de
--     ShopUI (atributo ShopOpen de PlayerGui); "Jugar" te pone LISTO, igual que el botón JUGAR.
--   · La vitrina gira despacio (tag "VitrinaGira").
--   · El "!" sobre el Capitán de la Guardia cuando tenés misiones para cobrar.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local lobbyRequest = remotes:WaitForChild("LobbyRequest") :: RemoteEvent

local SPIN_SPEED = math.rad(25) -- grados por segundo de la vitrina

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player then
		return
	end
	local action = prompt:GetAttribute("LobbyAction")
	if type(action) ~= "string" or player:GetAttribute("InMatch") == true then
		return
	end
	if action == "Tienda" or action == "Misiones" then
		-- se limpia primero para que vuelva a abrir aunque ya estuviera en esa pestaña
		playerGui:SetAttribute("ShopOpen", nil)
		playerGui:SetAttribute("ShopOpen", action)
	elseif action == "Jugar" then
		if player:GetAttribute("Ready") ~= true then
			lobbyRequest:FireServer("SetReady", true)
		end
	end
end)

-- Vitrina que gira
local spinning: { [Model]: CFrame } = {}
local function addSpin(inst: Instance)
	if inst:IsA("Model") then
		local base = inst:GetAttribute("BaseCFrame")
		spinning[inst] = if typeof(base) == "CFrame" then base else inst:GetPivot()
	end
end
for _, inst in CollectionService:GetTagged("VitrinaGira") do
	addSpin(inst)
end
CollectionService:GetInstanceAddedSignal("VitrinaGira"):Connect(addSpin)
CollectionService:GetInstanceRemovedSignal("VitrinaGira"):Connect(function(inst)
	spinning[inst :: any] = nil
end)

local angle = 0
RunService.RenderStepped:Connect(function(dt)
	if player:GetAttribute("InMatch") == true then
		return
	end
	angle = (angle + dt * SPIN_SPEED) % (math.pi * 2)
	for model, base in spinning do
		if model.Parent then
			model:PivotTo(base * CFrame.Angles(0, angle, 0))
		else
			spinning[model] = nil
		end
	end
end)

-- "!" de misiones para cobrar
local function updateAlerts()
	local claimable = (player:GetAttribute("MissionsClaimable") or 0) :: number
	for _, npc in CollectionService:GetTagged("LobbyNpc") do
		if npc:GetAttribute("LobbyAction") == "Misiones" then
			local alert = npc:FindFirstChild("Aviso", true)
			if alert and alert:IsA("GuiObject") then
				alert.Visible = claimable > 0
			end
		end
	end
end
player:GetAttributeChangedSignal("MissionsClaimable"):Connect(updateAlerts)
CollectionService:GetInstanceAddedSignal("LobbyNpc"):Connect(function()
	task.defer(updateAlerts)
end)
updateAlerts()
