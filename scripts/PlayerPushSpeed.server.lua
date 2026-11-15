--[=[
	PlayerPushSpeed.server.lua
	Place this Script in ServerScriptService.
	It creates the BindableEvent used by TouchableMovement and halves the
	player's WalkSpeed until all Touchable hitboxes have released them.
]=]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local event = ServerScriptService:FindFirstChild("PushStateChanged")
if not event then
	event = Instance.new("BindableEvent")
	event.Name = "PushStateChanged"
	event.Parent = ServerScriptService
end
assert(event:IsA("BindableEvent"), "PushStateChanged must be a BindableEvent")

local activePushes = {} -- [player] = { humanoid, originalSpeed, hitboxes }

local function restoreSpeed(player)
	local state = activePushes[player]
	if not state then
		return
	end
	if state.humanoid and state.humanoid.Parent then
		state.humanoid.WalkSpeed = state.originalSpeed
	end
	activePushes[player] = nil
end

event.Event:Connect(function(player, hitbox, isPushing)
	if not player or not player:IsA("Player") then
		return
	end

	local state = activePushes[player]
	if isPushing then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		if state and state.humanoid ~= humanoid then
			restoreSpeed(player)
			state = nil
		end
		if not state then
			state = {
				humanoid = humanoid,
				originalSpeed = humanoid.WalkSpeed,
				hitboxes = {},
			}
			activePushes[player] = state
		end

		state.hitboxes[hitbox] = true
		humanoid.WalkSpeed = state.originalSpeed * 0.5
	else
		if state then
			state.hitboxes[hitbox] = nil
			if not next(state.hitboxes) then
				restoreSpeed(player)
			end
		end
	end
end)

local function bindPlayer(player)
	player.CharacterRemoving:Connect(function()
		restoreSpeed(player)
	end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in Players:GetPlayers() do
	bindPlayer(player)
end
Players.PlayerRemoving:Connect(restoreSpeed)
