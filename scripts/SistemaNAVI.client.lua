--[=[
	SistemaNAVI.client.lua
	LocalScript directamente dentro de StarterGui.
	Tag requerido: TerminalNAVI en un BasePart o Model dentro de Workspace.
	Attribute Number opcional en la MISMA instancia: NumeroNAVI (0 a 5; default 0).
	Attribute String opcional: ImageId (ID de una imagen subida a Roblox).
	Si no existe un ProximityPrompt, el script crea uno con E.
]=]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local TAG_TERMINAL = "TerminalNAVI"
local DISTANCIA_CIERRE = 15
local SEGUNDOS_POR_LETRA = 0.02
local DEMORA_SKIP = 7
local IMAGE_ID_PREDETERMINADO = "" -- Pega aquí rbxassetid://TU_ID después de subir NAV.png.
local ACCION_SKIP = "NaviSkipRegistro"

local REGISTROS = {
	[0] = [=[[ARCHIVO N.A.V.I. #00 - ROVER SOJOURNER (1997)]: En Marte, la sonda Sojourner quedó atrapada girando en círculos alrededor de su base muerta buscando una señal perdida. Un sistema cerrado sin salida exige retroceder sobre tus propias coordenadas [MANTÉN R] para reescribir tu trayectoria. Desplaza la masa frente a ti para liberar el acceso.]=],
	[1] = [=[[ARCHIVO N.A.V.I. #01 - APOLLO 11 / ERROR 1202 (1969)]: Durante el alunizaje del módulo Eagle, la computadora de navegación sufrió un desbordamiento de búfer por exceso de datos simultáneos. El peso estático no basta para vulnerar este sector; aplica velocidad e impacto cinético sobre el sensor hasta saturar su límite al 100%.]=],
	[2] = [=[[ARCHIVO N.A.V.I. #02 - SONDA INSIGHT (2018-2022)]: Equipado con el sismómetro SEIS, InSight midió más de 1,300 vibraciones internas bajo la corteza marciana antes de cubrirse de polvo. Toda caída genera una onda de choque vertical; convierte tu energía de descenso en impulso ascendente sobre las placas de rebote.]=],
	[3] = [=[[ARCHIVO N.A.V.I. #03 - ROVER OPPORTUNITY (2004-2018)]: Diseñado para sobrevivir 90 días, resistió 14 años en la oscuridad hasta enviar su última telemetría: "Mi batería está baja y está oscureciendo". No puedes borrar los errores ni el polvo acumulado en tu historial, pero cada fallo te impulsa más lejos hacia el núcleo.]=],
	[4] = [=[[ARCHIVO N.A.V.I. #04 - VOYAGER 1 (1977-PRESENTE)]: A 24,000 millones de kilómetros, la Voyager 1 abandona el sistema solar impulsada por asistencia gravitatoria, llevando el Disco de Oro al vacío eterno. Usa los vectores de lanzamiento direccional para cruzar el abismo sin perder tu inercia hacia el Kernel.]=],
	[5] = [=[[SISTEMA CENTRAL - ACCESO ROOT CONCEDIDO]: Creíste que estabas hackeando una nave abandonada para escapar de tus errores, pero la telemetría no miente. Tú no eres el rescatista. El sistema no colapsó por una falla técnica... FUISTE TÚ QUIEN APAGÓ LAS LUCES. Bienvenido de vuelta a tu propia celda.]=],
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Apaga la GUI vieja de video para que su Fade no tape esta interfaz.
local guiVieja = playerGui:FindFirstChild("TutorialGui")
if guiVieja and guiVieja:IsA("ScreenGui") then
	guiVieja.Enabled = false
end
local habiaScriptVideo = false
for _, objeto in ipairs(playerGui:GetDescendants()) do
	if objeto ~= script and objeto:IsA("LocalScript") and objeto.Name == "TutorialVideo" then
		habiaScriptVideo = true
		objeto.Enabled = false
	end
end
if habiaScriptVideo then
	ContextActionService:UnbindAction("TutorialSkip")
	ProximityPromptService.Enabled = true
end

-- Evita duplicar la interfaz si el LocalScript vuelve a ejecutarse al reaparecer.
local guiAnterior = playerGui:FindFirstChild("NaviGui")
if guiAnterior then
	guiAnterior:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "NaviGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = playerGui

local fondo = Instance.new("Frame")
fondo.Name = "FondoOscuro"
fondo.Size = UDim2.fromScale(1, 1)
fondo.BackgroundColor3 = Color3.new(0, 0, 0)
fondo.BackgroundTransparency = 0.38
fondo.BorderSizePixel = 0
fondo.Visible = false
fondo.Active = true
fondo.ZIndex = 1
fondo.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Registro"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.86, 0.84)
panel.BackgroundColor3 = Color3.fromRGB(3, 9, 13)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.ZIndex = 2
panel.Parent = fondo

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(300, 400)
panelConstraint.MaxSize = Vector2.new(1100, 720)
panelConstraint.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(70, 220, 255)
panelStroke.Thickness = 2
panelStroke.Parent = panel

local header = Instance.new("TextLabel")
header.Name = "Encabezado"
header.Position = UDim2.new(0, 18, 0, 10)
header.Size = UDim2.new(1, -36, 0, 26)
header.BackgroundTransparency = 1
header.Font = Enum.Font.Code
header.Text = "N.A.V.I. // HISTORICAL ARCHIVE"
header.TextColor3 = Color3.fromRGB(70, 220, 255)
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.ZIndex = 3
header.Parent = panel

local image = Instance.new("ImageLabel")
image.Name = "ImagenNAVI"
image.AnchorPoint = Vector2.new(0.5, 0)
image.Position = UDim2.new(0.5, 0, 0, 42)
image.Size = UDim2.new(0.72, 0, 0.31, 0)
image.BackgroundTransparency = 1
image.Image = IMAGE_ID_PREDETERMINADO
image.ScaleType = Enum.ScaleType.Fit
image.ResampleMode = Enum.ResamplerMode.Pixelated
image.ZIndex = 3
image.Parent = panel

local body = Instance.new("TextLabel")
body.Name = "RegistroTexto"
body.Position = UDim2.new(0, 18, 0.38, 0)
body.Size = UDim2.new(1, -36, 0.55, -30)
body.BackgroundTransparency = 1
body.Font = Enum.Font.Code
body.Text = ""
body.TextColor3 = Color3.fromRGB(220, 245, 235)
body.TextSize = 16
body.TextWrapped = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.ZIndex = 3
body.Parent = panel

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MinTextSize = 14
textConstraint.MaxTextSize = 17
textConstraint.Parent = body

local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -16, 1, -12)
skip.Size = UDim2.fromOffset(112, 30)
skip.BackgroundColor3 = Color3.fromRGB(4, 18, 23)
skip.BorderSizePixel = 0
skip.Font = Enum.Font.Code
skip.Text = "[ E ]  SKIP"
skip.TextColor3 = Color3.fromRGB(70, 220, 255)
skip.TextSize = 16
skip.AutoButtonColor = false
skip.Visible = false
skip.ZIndex = 4
skip.Parent = panel

local skipStroke = Instance.new("UIStroke")
skipStroke.Color = Color3.fromRGB(70, 220, 255)
skipStroke.Thickness = 1
skipStroke.Parent = skip

local terminalesConectadas = {}
local sesion = 0
local registroAbierto = false
local puedeOmitir = false
local promptsHabilitadosAntes = true
local terminalActual
local parteActual

local function obtenerParte(terminal)
	if terminal:IsA("BasePart") then
		return terminal
	elseif terminal:IsA("Model") then
		return terminal.PrimaryPart or terminal:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function obtenerPrompt(terminal, parte)
	local existente = terminal:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existente then
		return existente, false
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NaviPrompt"
	prompt.ActionText = "Leer registro"
	prompt.ObjectText = "N.A.V.I."
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parte
	return prompt, true
end

local function cerrarRegistro(token)
	if not registroAbierto or token ~= sesion then
		return
	end
	registroAbierto = false
	sesion += 1
	puedeOmitir = false
	fondo.Visible = false
	body.Text = ""
	skip.Visible = false
	ContextActionService:UnbindAction(ACCION_SKIP)
	ProximityPromptService.Enabled = promptsHabilitadosAntes
	terminalActual = nil
	parteActual = nil
end

local function omitirConE(_, inputState)
	if not registroAbierto then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin and puedeOmitir then
		cerrarRegistro(sesion)
	end
	return Enum.ContextActionResult.Sink
end

skip.Activated:Connect(function()
	if puedeOmitir then
		cerrarRegistro(sesion)
	end
end)

local function distanciaAlJugador(parte)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not parte.Parent then
		return math.huge
	end
	return (root.Position - parte.Position).Magnitude
end

local function normalizarImageId(valor)
	if typeof(valor) == "number" then
		return "rbxassetid://" .. tostring(math.floor(valor))
	elseif typeof(valor) == "string" and valor ~= "" then
		if string.find(valor, "rbxassetid://", 1, true) then
			return valor
		end
		return "rbxassetid://" .. valor
	end
	return IMAGE_ID_PREDETERMINADO
end

local function mostrarRegistro(terminal, parte)
	if registroAbierto then
		cerrarRegistro(sesion)
	end

	local numero = terminal:GetAttribute("NumeroNAVI")
	if typeof(numero) ~= "number" then
		numero = 0
	end
	numero = math.floor(numero)
	local mensaje = REGISTROS[numero] or REGISTROS[0]

	sesion += 1
	local miSesion = sesion
	registroAbierto = true
	puedeOmitir = false
	terminalActual = terminal
	parteActual = parte
	body.Text = ""
	image.Image = normalizarImageId(terminal:GetAttribute("ImageId"))
	skip.Visible = false
	fondo.Visible = true

	promptsHabilitadosAntes = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	ContextActionService:BindActionAtPriority(
		ACCION_SKIP,
		omitirConE,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E
	)

	task.delay(DEMORA_SKIP, function()
		if registroAbierto and miSesion == sesion then
			puedeOmitir = true
			skip.Visible = true
		end
	end)

	task.spawn(function()
		local letras = {}
		for _, codigoPunto in utf8.codes(mensaje) do
			table.insert(letras, utf8.char(codigoPunto))
		end
		local escrito = {}

		for _, letra in ipairs(letras) do
			if not registroAbierto or miSesion ~= sesion then
				return
			end
			if distanciaAlJugador(parte) > DISTANCIA_CIERRE then
				cerrarRegistro(miSesion)
				return
			end
			table.insert(escrito, letra)
			body.Text = table.concat(escrito)
			task.wait(SEGUNDOS_POR_LETRA)
		end

		while registroAbierto and miSesion == sesion do
			if distanciaAlJugador(parte) > DISTANCIA_CIERRE then
				cerrarRegistro(miSesion)
				return
			end
			task.wait(0.15)
		end
	end)
end

local function conectarTerminal(terminal)
	if terminalesConectadas[terminal] then
		return
	end
	local parte = obtenerParte(terminal)
	if not parte then
		warn(("SistemaNAVI: %s necesita ser un BasePart o Model con una BasePart.")
			:format(terminal:GetFullName()))
		return
	end

	local prompt, creadoPorScript = obtenerPrompt(terminal, parte)
	local conexion = prompt.Triggered:Connect(function()
		mostrarRegistro(terminal, parte)
	end)
	terminalesConectadas[terminal] = {
		prompt = prompt,
		conexion = conexion,
		creadoPorScript = creadoPorScript,
	}
end

local function desconectarTerminal(terminal)
	local datos = terminalesConectadas[terminal]
	if not datos then
		return
	end
	datos.conexion:Disconnect()
	if datos.creadoPorScript and datos.prompt.Parent then
		datos.prompt:Destroy()
	end
	terminalesConectadas[terminal] = nil
	if terminal == terminalActual then
		cerrarRegistro(sesion)
	end
end

for _, terminal in ipairs(CollectionService:GetTagged(TAG_TERMINAL)) do
	conectarTerminal(terminal)
end
CollectionService:GetInstanceAddedSignal(TAG_TERMINAL):Connect(conectarTerminal)
CollectionService:GetInstanceRemovedSignal(TAG_TERMINAL):Connect(desconectarTerminal)
