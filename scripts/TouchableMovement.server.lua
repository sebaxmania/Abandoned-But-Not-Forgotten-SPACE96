--[=[
	TouchableMovement.server.lua
	Pon este Script dentro de la pieza "hitbox".
	Al tocar una hitbox etiquetada "Touchable", el jugador puede empujar el objeto
	con movimiento hacia adelante. El empuje termina al salir de la hitbox.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local hitbox = script.Parent
local container = hitbox.Parent
local TAG_NAME = "Touchable"
local pushStateChanged = ServerScriptService:WaitForChild("PushStateChanged")

assert(hitbox:IsA("BasePart"), "TouchableMovement debe estar dentro de la BasePart hitbox")

local blockPart
if container:IsA("BasePart") then
	blockPart = container
elseif container:IsA("Model") then
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
assert(blockPart and blockPart ~= hitbox, "La hitbox necesita un bloque padre con otra BasePart")

local function isTouchable()
	return CollectionService:HasTag(hitbox, TAG_NAME)
		or CollectionService:HasTag(blockPart, TAG_NAME)
		or (container:IsA("Model") and CollectionService:HasTag(container, TAG_NAME))
end

local function getPlayerFromPart(part)
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return Players:GetPlayerFromCharacter(current), current
		end
		current = current.Parent
	end
	return nil, nil
end

local function moveObject(delta)
	if container:IsA("Model") then
		container:PivotTo(container:GetPivot() + delta)
	else
		blockPart.CFrame = blockPart.CFrame + delta
	end
end

local activePlayers = {}
local movementStates = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.RespectCanCollide = false
overlapParams.MaxParts = 64

RunService.Heartbeat:Connect(function()
	if not isTouchable() then
		for player in activePlayers do
			pushStateChanged:Fire(player, hitbox, false)
		end
		table.clear(activePlayers)
		table.clear(movementStates)
		return
	end

	local characterModels = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 then
			table.insert(characterModels, character)
		end
	end
	overlapParams.FilterDescendantsInstances = characterModels

	local contacts = {}
	for _, part in workspace:GetPartsInPart(hitbox, overlapParams) do
		local player, character = getPlayerFromPart(part)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if player and root then
			contacts[player] = { character = character, root = root }
		end
	end

	-- El estado de empuje/velocidad/red dura exactamente mientras haya contacto.
	for player in activePlayers do
		if not contacts[player] then
			pushStateChanged:Fire(player, hitbox, false)
			activePlayers[player] = nil
			movementStates[player] = nil
		end
	end

	local nextStates = {}
	for player, contact in contacts do
		if not activePlayers[player] then
			activePlayers[player] = true
			pushStateChanged:Fire(player, hitbox, true)
		end

		local root = contact.root
		local state = movementStates[player]
		if not state or state.character ~= contact.character then
			local towardObject = blockPart.Position - root.Position
			local direction = Vector3.new(towardObject.X, 0, towardObject.Z)
			if direction.Magnitude < 0.01 then
				local look = root.CFrame.LookVector
				direction = Vector3.new(look.X, 0, look.Z)
			end
			if direction.Magnitude < 0.01 then
				continue
			end

			state = {
				character = contact.character,
				lastPosition = root.Position,
				direction = direction.Unit,
			}
			local velocity = root.AssemblyLinearVelocity
			local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
			local firstStep = math.min(horizontalVelocity:Dot(state.direction) / 60, 0.5)
			if firstStep > 0 then
				moveObject(state.direction * firstStep)
			end
		end

		local movement = root.Position - state.lastPosition
		state.lastPosition = root.Position
		local horizontalMovement = Vector3.new(movement.X, 0, movement.Z)
		local forwardStep = horizontalMovement:Dot(state.direction)
		if forwardStep > 0 then
			moveObject(state.direction * forwardStep)
		end
		nextStates[player] = state
	end

	movementStates = nextStates
end)

Players.PlayerRemoving:Connect(function(player)
	if activePlayers[player] then
		pushStateChanged:Fire(player, hitbox, false)
	end
	activePlayers[player] = nil
	movementStates[player] = nil
end)
