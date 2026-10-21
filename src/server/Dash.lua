local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local Ground = require(script.Parent.Ground)
local Dash = {}
function Dash.request(player, direction)
	if PlayerData.isPaused() then return false end
	local state = PlayerData.get(player)
	if not state or not state.inMatch or state.life ~= "ALIVE" or state.grabbed or typeof(direction) ~= "Vector3" then return false end
	if direction.X ~= direction.X or direction.Z ~= direction.Z or math.abs(direction.X) > 1.01 or math.abs(direction.Z) > 1.01 then return false end
	local dir = PlayerData.flat(direction)
	if dir.Magnitude < 0.1 or dir.Magnitude > 1.1 then return false end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or os.clock() < state.dashReady then return false end
	state.dashReady = os.clock() + state.stats.dashCooldown
	state.dashUntil = os.clock() + Config.Dash.Duration
	state.dashDirection = dir.Unit
	root:SetNetworkOwner(nil) -- autoridad del servidor durante el impulso
	state.dashOwned = true
	player:SetAttribute("DashReadyAt", workspace:GetServerTimeNow() + state.stats.dashCooldown)
	return true
end
function Dash.update(targets, now)
	for _, target in targets do
		local state, root = target.state, target.root
		if state.dashOwned and now >= state.dashUntil then
			state.dashOwned = false
			local movement = target.humanoid.MoveDirection or Vector3.zero
			root.AssemblyLinearVelocity = movement * state.stats.walkSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			root:SetNetworkOwnershipAuto()
		end
		if now < state.dashUntil then
			local ahead = root.Position + state.dashDirection * 4
			if math.abs(ahead.X) >= Config.Arena.Size.X / 2 - 5 or math.abs(ahead.Z) >= Config.Arena.Size.Z / 2 - 5
				or Ground.y(ahead.X, ahead.Z) - Ground.y(root.Position.X, root.Position.Z) > 4 then
				state.dashUntil = 0
			else
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = state.dashDirection * Config.Dash.Speed + Vector3.new(0, velocity.Y, 0)
			end
		end
	end
end
function Dash.init(remotes)
	remotes.DashRequest.OnServerEvent:Connect(Dash.request)
end
return Dash
