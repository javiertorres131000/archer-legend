-- Diagnóstico optativo; no se envían mediciones ni datos del dispositivo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if not Config.Debug.ShowPerformance then return end
local state = ReplicatedStorage:WaitForChild("GameState")
local gui = Instance.new("ScreenGui")
gui.Name = "Performance"; gui.ResetOnSpawn = false; gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Position = UDim2.fromOffset(12, 85); label.Size = UDim2.fromOffset(290, 54)
label.BackgroundColor3 = Color3.new(0, 0, 0); label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.new(1, 1, 1); label.TextSize = 14; label.Font = Enum.Font.Code; label.Parent = gui
local elapsed, frames, worst = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
	elapsed += dt; frames += 1; worst = math.max(worst, dt)
	if elapsed >= 1 then
		label.Text = string.format("%.0f FPS · pico %.0f ms\nEnemigos %d/%d · proyectiles %d", frames / elapsed, worst * 1000, state:GetAttribute("AliveEnemies") or 0, Config.Enemy.MaxAlive, state:GetAttribute("ActiveProjectiles") or 0)
		elapsed, frames, worst = 0, 0, 0
	end
end)
