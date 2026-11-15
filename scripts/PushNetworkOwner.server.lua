--[=[
	PushNetworkOwner.server.lua
	Place this Script in ServerScriptService beside PlayerPushSpeed.
	It assigns an unanchored pushed assembly to the active player, then returns
	ownership to Roblox's automatic system when the player leaves the hitbox.
]=]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local pushStateChanged = ServerScriptService:WaitForChild("PushStateChanged")
local assemblyOwners = {} -- [assemblyRoot] = { player, hitboxes }
local sessionsByPlayer = {} -- [player] = { [hitbox] = assemblyRoot }

local function getAssemblyRoot(hitbox)
	if typeof(hitbox) ~= "Instance" or not hitbox:IsA("BasePart") then
		return nil
	end

	local container = hitbox.Parent
	local blockPart
	if container and container:IsA("BasePart") then
		blockPart = container
	elseif container and container:IsA("Model") then
		blockPart = container.PrimaryPart
		if not blockPart then
			for _, descendant in container:GetDescendants() do
				if descendant:IsA("BasePart") and descendant ~= hitbox then
					blockPart = descendant
					break
				end
			end
		end
	end

	if not blockPart or blockPart.Anchored then
		return nil
	end
	return blockPart.AssemblyRootPart or blockPart
end

local function endSession(player, hitbox)
	local playerSessions = sessionsByPlayer[player]
	local assemblyRoot = playerSessions and playerSessions[hitbox]
	if not assemblyRoot then
		return
	end

	playerSessions[hitbox] = nil
	if not next(playerSessions) then
		sessionsByPlayer[player] = nil
	end

	local ownership = assemblyOwners[assemblyRoot]
	if not ownership or ownership.player ~= player then
		return
	end
	ownership.hitboxes[hitbox] = nil
	if not next(ownership.hitboxes) then
		if assemblyRoot.Parent and not assemblyRoot.Anchored then
			pcall(function()
				assemblyRoot:SetNetworkOwnershipAuto()
			end)
		end
		assemblyOwners[assemblyRoot] = nil
	end
end

local function startSession(player, hitbox)
	local assemblyRoot = getAssemblyRoot(hitbox)
	if not assemblyRoot then
		return -- anchored parts can't be assigned network ownership
	end

	local ownership = assemblyOwners[assemblyRoot]
	if ownership then
		if ownership.player ~= player then
			return -- one client owns a physics assembly at a time
		end
		ownership.hitboxes[hitbox] = true
	else
		local canSetOwnership = false
		local ok, result = pcall(function()
			return assemblyRoot:CanSetNetworkOwnership()
		end)
		if ok then
			canSetOwnership = result
		end
		if not canSetOwnership then
			return
		end

		local assigned = pcall(function()
			assemblyRoot:SetNetworkOwner(player)
		end)
		if not assigned then
			return
		end
		ownership = { player = player, hitboxes = { [hitbox] = true } }
		assemblyOwners[assemblyRoot] = ownership
	end

	sessionsByPlayer[player] = sessionsByPlayer[player] or {}
	sessionsByPlayer[player][hitbox] = assemblyRoot
end

pushStateChanged.Event:Connect(function(player, hitbox, isPushing)
	if isPushing then
		startSession(player, hitbox)
	else
		endSession(player, hitbox)
	end
end)

local function clearPlayer(player)
	local playerSessions = sessionsByPlayer[player]
	if not playerSessions then
		return
	end
	local hitboxes = {}
	for hitbox in playerSessions do
		table.insert(hitboxes, hitbox)
	end
	for _, hitbox in hitboxes do
		endSession(player, hitbox)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		clearPlayer(player)
	end)
end)
for _, player in Players:GetPlayers() do
	player.CharacterRemoving:Connect(function()
		clearPlayer(player)
	end)
end
Players.PlayerRemoving:Connect(clearPlayer)
