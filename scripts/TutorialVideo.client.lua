--[=[
	TutorialVideo.client.lua
	Pon este LocalScript dentro de StarterGui > TutorialGui.

	Elementos requeridos dentro de TutorialGui:
	  Panel (Frame)
	    Video (VideoFrame)
	    Fade (Frame negro sobre el contenido)
	    CloseButton (TextButton por encima de Fade en ZIndex)

	Etiqueta "TutorialPrompt" a cada ProximityPrompt que abra esta guía.
	Opcional: pon un atributo string "VideoId" en cada prompt.
]=]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TAG_NAME = "TutorialPrompt"
local FADE_TIME = 2.5 -- segundos del fade de entrada
local VIDEO_REVEAL_DELAY = 0 -- espera adicional después del fade, en segundos
local SKIP_DELAY = 4 -- segundos después de que aparece el video
local CLOSE_DELAY = 0 -- espera después de pulsar E antes de ocultar la GUI
local SKIP_ACTION = "TutorialSkip"

local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local video = panel:WaitForChild("Video")
local fade = panel:WaitForChild("Fade")
local closeButton = panel:WaitForChild("CloseButton")
local tweenInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)

local isOpen = false
local isClosing = false
local canSkip = false
local sessionId = 0
local previousMouseBehavior
local previousMouseIconEnabled
local previousPromptsEnabled
local connectedPrompts = {}
local characterSnapshots = {}
local playerControls
local closeTutorial

gui.Enabled = false
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 1
video.Visible = false
fade.Visible = true
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 0

local function setMouseForTutorial(open)
	if open then
		previousMouseBehavior = UserInputService.MouseBehavior
		previousMouseIconEnabled = UserInputService.MouseIconEnabled
		-- El cursor permanece oculto y centrado; E será el único control del menú.
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = previousMouseBehavior or Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = previousMouseIconEnabled == true
	end
end

local function setPlayerControlsEnabled(enabled)
	if not playerControls then
		local playerScripts = player:FindFirstChild("PlayerScripts")
		local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
		if playerModule then
			local ok, module = pcall(require, playerModule)
			if ok and module.GetControls then
				playerControls = module:GetControls()
			end
		end
	end

	if playerControls then
		pcall(function()
			if enabled then
				playerControls:Enable()
			else
				playerControls:Disable()
			end
		end)
	end
end

local function freezeCharacter(character)
	if characterSnapshots[character] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local snapshot = { humanoid = humanoid, root = root }
	if humanoid then
		snapshot.walkSpeed = humanoid.WalkSpeed
		snapshot.jumpPower = humanoid.JumpPower
		snapshot.jumpHeight = humanoid.JumpHeight
		snapshot.autoRotate = humanoid.AutoRotate
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end
	if root then
		snapshot.rootAnchored = root.Anchored
		root.Anchored = true
	end
	characterSnapshots[character] = snapshot
end

local function restoreCharacter()
	for character, snapshot in characterSnapshots do
		local humanoid = snapshot.humanoid
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = snapshot.walkSpeed
			humanoid.JumpPower = snapshot.jumpPower
			humanoid.JumpHeight = snapshot.jumpHeight
			humanoid.AutoRotate = snapshot.autoRotate
		end
		local root = snapshot.root
		if root and root.Parent then
			root.Anchored = snapshot.rootAnchored
		end
		characterSnapshots[character] = nil
	end
	setPlayerControlsEnabled(true)
end

local function tweenFade(transparency)
	local tween = TweenService:Create(fade, tweenInfo, {
		BackgroundTransparency = transparency,
	})
	tween:Play()
	return tween.Completed:Wait()
end

local function getVideoId(prompt)
	local value = prompt:GetAttribute("VideoId")
	if typeof(value) == "number" then
		return "rbxassetid://" .. tostring(value)
	elseif typeof(value) == "string" and value ~= "" then
		if string.find(value, "rbxassetid://", 1, true) then
			return value
		end
		return "rbxassetid://" .. value
	end
	-- Si el prompt no tiene atributo, usa la propiedad Video configurada en Studio.
	return video.Video
end

local function openTutorial(prompt)
	if isOpen or isClosing then
		return
	end

	isOpen = true
	sessionId += 1
	local thisSession = sessionId
	setMouseForTutorial(true)
	previousPromptsEnabled = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	setPlayerControlsEnabled(false)
	if player.Character then
		freezeCharacter(player.Character)
	end
	ContextActionService:BindActionAtPriority(SKIP_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and canSkip then
			closeTutorial()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.E)
	gui.Enabled = true
	closeButton.Visible = false
	video:Pause()
	video.Visible = false
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 1

	local videoId = getVideoId(prompt)
	if videoId ~= "" then
		video.Video = videoId
	end

	fade.Visible = true
	fade.BackgroundTransparency = 1
	local fadeInState = tweenFade(0)
	if fadeInState ~= Enum.PlaybackState.Completed or sessionId ~= thisSession then
		return
	end

	-- El video aparece tras el fade y esta espera adicional.
	if VIDEO_REVEAL_DELAY > 0 then
		task.wait(VIDEO_REVEAL_DELAY)
	end
	if not isOpen or sessionId ~= thisSession then
		return
	end

	-- El Panel toma el relevo como fondo negro permanente detrás del video.
	panel.BackgroundTransparency = 0
	if video.Video == "" then
		warn("TutorialVideo: asigna VideoId al prompt o configura la propiedad Video en el VideoFrame")
	else
		if not video.IsLoaded then
			warn("TutorialVideo: el video todavía no cargó; se revelará al cumplirse el segundo")
		end
		video.TimePosition = 0
		video:Play()
		video.Visible = true
	end
	fade.Visible = false -- El Panel negro queda detrás del video.

	-- Habilita E y muestra el aviso unos segundos después del video.
	if SKIP_DELAY > 0 then
		task.wait(SKIP_DELAY)
	end
	if not isOpen or sessionId ~= thisSession then
		return
	end
	canSkip = true
	closeButton.Visible = true
end

closeTutorial = function()
	if not isOpen or isClosing or not canSkip then
		return
	end

	isOpen = false
	isClosing = true
	canSkip = false
	sessionId += 1
	if CLOSE_DELAY > 0 then
		task.wait(CLOSE_DELAY)
	end

	video:Pause()
	video.Visible = false
	gui.Enabled = false
	ContextActionService:UnbindAction(SKIP_ACTION)
	ProximityPromptService.Enabled = previousPromptsEnabled ~= false
	restoreCharacter()
	setMouseForTutorial(false)
	isClosing = false
end

local function connectPrompt(instance)
	if not instance:IsA("ProximityPrompt") then
		warn(("TutorialVideo: el tag %q está en %s, pero debe estar en un ProximityPrompt")
			:format(TAG_NAME, instance:GetFullName()))
		return
	end
	if connectedPrompts[instance] then
		return
	end
	connectedPrompts[instance] = true
	print("TutorialVideo: prompt conectado:", instance:GetFullName())
	instance.Triggered:Connect(function()
		print("TutorialVideo: prompt activado:", instance:GetFullName())
		openTutorial(instance)
	end)
end

local taggedPrompts = CollectionService:GetTagged(TAG_NAME)
print(("TutorialVideo: LocalScript iniciado; encontré %d instancias con el tag %q")
	:format(#taggedPrompts, TAG_NAME))
for _, instance in taggedPrompts do
	connectPrompt(instance)
end
CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(function(instance)
	connectPrompt(instance)
end)
-- El botón puede seguir dibujado como parte del diseño; el control real es E.
player.CharacterAdded:Connect(function(character)
	if isOpen then
		task.defer(freezeCharacter, character)
	end
end)
