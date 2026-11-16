--[=[
	RetroCamera.client.lua
	Place this LocalScript in StarterPlayer > StarterPlayerScripts.

	Direct, unsmoothed first-person camera for a restrained 90s/PS1-style feel.
	It replaces Roblox's default camera while this script is running. Remove or
	disable any other LocalScript that also controls the camera.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Tweak these to taste.
local SENSITIVITY = 0.0025 -- radians per mouse pixel
local FIELD_OF_VIEW = 80
local CAMERA_HEIGHT = 0.15 -- above the character's head center
local MIN_PITCH = math.rad(-85)
local MAX_PITCH = math.rad(85)

local character
local rootPart
local head
local cameraHeightFromRoot = 2.5
local yaw = 0
local pitch = 0

local function bindCharacter(newCharacter)
	character = newCharacter
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")
	head = newCharacter:WaitForChild("Head")
	-- Measure the rig once. Reading Head.Position every frame would copy subtle
	-- animation bob into the view; the root part is the stable hitbox anchor.
	cameraHeightFromRoot = head.Position.Y - rootPart.Position.Y + CAMERA_HEIGHT

	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(math.clamp(look.Y, -1, 1))
	
	-- Keep the avatar facing the same direction as the view, without a
	-- second Roblox camera controller trying to ease the camera behind it.
	local humanoid = newCharacter:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
	end
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = FIELD_OF_VIEW
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false

UserInputService.InputChanged:Connect(function(input)
	-- Allow mouse clicks in the tutorial UI without rotating the camera.
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local tutorialGui = playerGui and playerGui:FindFirstChild("TutorialGui")
	if tutorialGui and tutorialGui.Enabled then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	-- Apply mouse movement directly. No Lerp, Tween, spring, or frame-rate
	-- dependent smoothing is used, so the view does not trail behind input.
	yaw -= input.Delta.X * SENSITIVITY
	pitch = math.clamp(pitch - input.Delta.Y * SENSITIVITY, MIN_PITCH, MAX_PITCH)
end)

RunService:BindToRenderStep("RetroFirstPersonCamera", Enum.RenderPriority.Camera.Value + 1, function()
	if not character or not rootPart or not head or not rootPart.Parent then
		return
	end

	local position = rootPart.Position + Vector3.new(0, cameraHeightFromRoot, 0)
	local rotation = CFrame.fromOrientation(pitch, yaw, 0)
	camera.CFrame = CFrame.new(position) * rotation

	-- Turning the avatar with yaw keeps WASD movement and the visible body
	-- aligned with the first-person view.
	rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, yaw, 0)
end)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep("RetroFirstPersonCamera")
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	camera.CameraType = Enum.CameraType.Custom
end)
