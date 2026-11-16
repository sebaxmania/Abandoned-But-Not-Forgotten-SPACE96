--[=[
	Intro.client.lua
	Pon este LocalScript directamente dentro de StarterGui.
	Genera la interfaz por código y hace un corte seco al gameplay.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ajustes de ritmo y aspecto
local SEGUNDOS_POR_LETRA = 0.03
local PAUSA_ENTRE_BLOQUES = 1.2
local PAUSA_FINAL = 0.8
local COLOR_TEXTO = Color3.fromRGB(205, 255, 210) -- verde fósforo suave

local BLOQUES = {
	[[> [TELEMETRY LOG: 1977 - PRESENT]
AT A DISTANCE OF 24 BILLION KILOMETERS, VOYAGER 1 IS STILL TRANSMITTING FROM INTERSTELLAR SPACE.]],
	[[> FOR DECADES, HUMANITY LEFT DOZENS OF MACHINES ON THE MOON AND MARS.
THEY BELIEVED THEY WERE DEAD.]],
	[[> C:\N.A.V.I.\KERNEL> RUNNING INTRUSION...
> WARNING: UNAUTHORIZED ACCESS DETECTED IN THE CORE.]],
	[[> YOU DID NOT COME TO RESCUE THIS SHIP.
YOU CAME TO REWRITE YOUR OWN MISTAKES... BEFORE THE LIGHTS GO OUT.]],
}

local gui = Instance.new("ScreenGui")
gui.Name = "IntroGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local saltar = false
local conexionEnter = UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
		saltar = true
	end
end)

local fondo = Instance.new("Frame")
fondo.Name = "Fondo"
fondo.Size = UDim2.fromScale(1, 1)
fondo.Position = UDim2.fromScale(0, 0)
fondo.BackgroundColor3 = Color3.new(0, 0, 0)
fondo.BorderSizePixel = 0
fondo.Active = true
fondo.ZIndex = 100
fondo.Parent = gui

local texto = Instance.new("TextLabel")
texto.Name = "TextoTerminal"
texto.AnchorPoint = Vector2.new(0.5, 0.5)
texto.Position = UDim2.fromScale(0.5, 0.48)
texto.Size = UDim2.fromScale(0.82, 0.72)
texto.BackgroundTransparency = 1
texto.BorderSizePixel = 0
texto.Font = Enum.Font.Code
texto.Text = ""
texto.TextColor3 = COLOR_TEXTO
texto.TextSize = 24
texto.TextWrapped = true
texto.TextXAlignment = Enum.TextXAlignment.Left
texto.TextYAlignment = Enum.TextYAlignment.Center
texto.ZIndex = 101
texto.Parent = fondo

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MinTextSize = 14
textConstraint.MaxTextSize = 28
textConstraint.Parent = texto

local terminado = false

-- Inmoviliza el personaje mientras se lee la intro.
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local jumpPowerAnterior = humanoid.JumpPower
local jumpHeightAnterior = humanoid.JumpHeight
local controls
local playerScripts = player:FindFirstChild("PlayerScripts")
local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
if playerModule then
	local ok, module = pcall(require, playerModule)
	if ok and module.GetControls then
		controls = module:GetControls()
		controls:Disable()
	end
end
humanoid.WalkSpeed = 0
humanoid.JumpPower = 0
humanoid.JumpHeight = 0

-- Mouse oculto y centrado durante toda la intro.
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false

local function escribir(bloque)
	texto.Text = ""
	for indice = 1, #bloque do
		if saltar then
			return
		end
		texto.Text = string.sub(bloque, 1, indice)
		task.wait(SEGUNDOS_POR_LETRA)
	end
end

local function esperarOSaltar(duracion)
	local fin = os.clock() + duracion
	while not saltar do
		local restante = fin - os.clock()
		if restante <= 0 then
			return
		end
		task.wait(math.min(0.05, restante))
	end
end

local function cerrarIntro()
	if terminado then
		return
	end
	terminado = true
	if humanoid.Parent then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = jumpPowerAnterior
		humanoid.JumpHeight = jumpHeightAnterior
	end
	if controls then
		controls:Enable()
	end
	conexionEnter:Disconnect()
	-- RetroCamera.client.lua usa este modo durante el gameplay.
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

for indice, bloque in ipairs(BLOQUES) do
	if saltar then
		break
	end
	escribir(bloque)
	if saltar then
		break
	elseif indice < #BLOQUES then
		esperarOSaltar(PAUSA_ENTRE_BLOQUES)
	end
end

if not saltar then
	esperarOSaltar(PAUSA_FINAL)
end

cerrarIntro()
fondo.Visible = false -- Hard cut: el gameplay aparece sin desvanecerse.
gui:Destroy()
