local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DashRequest")
local function dash(_, inputState)
	if inputState ~= Enum.UserInputState.Begin or not player:GetAttribute("InMatch") then return Enum.ContextActionResult.Pass end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		local direction = humanoid.MoveDirection
		if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude > 0.1 then remote:FireServer(direction.Unit) end
	end
	return Enum.ContextActionResult.Sink
end
local bound = false
local function refresh()
	local inMatch = player:GetAttribute("InMatch") == true
	if inMatch and not bound then
		ContextActionService:BindAction("CombatDash", dash, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("CombatDash", "DASH")
		ContextActionService:SetPosition("CombatDash", UDim2.fromScale(0.72, 0.68))
		bound = true
	elseif not inMatch and bound then ContextActionService:UnbindAction("CombatDash"); bound = false end
end
player:GetAttributeChangedSignal("InMatch"):Connect(refresh)
refresh()
local gui = Instance.new("ScreenGui")
gui.Name = "DashHUD"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1); label.Position = UDim2.fromScale(0.5, 0.64)
label.Size = UDim2.fromOffset(220, 22); label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold; label.TextSize = 15; label.TextColor3 = Color3.fromRGB(140, 235, 255); label.Parent = gui
RunService.Heartbeat:Connect(function()
	label.Visible = player:GetAttribute("InMatch") == true
	if not label.Visible then return end
	local left = (player:GetAttribute("DashReadyAt") or 0) - workspace:GetServerTimeNow()
	label.Text = if left > 0 then string.format("DASH · %.1f s", left) else "DASH · Shift / B"
end)
