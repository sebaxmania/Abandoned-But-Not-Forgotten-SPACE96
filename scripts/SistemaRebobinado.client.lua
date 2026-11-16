--[=[
	LocalScript: StarterPlayer > StarterPlayerScripts > SistemaRebobinado

	Tags:
	  ZonaSala: BasePart con Attribute Number NumeroSala.
	  SpriteHolograma: BasePart con Attribute String ImageId.

	Rebobinado con velocidad guardada, solo dentro de ZonaSala.
	El sprite loader crea BillboardGui locales que miran automáticamente a la cámara.
]=]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local jugador = Players.LocalPlayer
local TAG_ZONA = "ZonaSala"
local TAG_SPRITE = "SpriteHolograma"
local INTERVALO_DETECCION = 0.1
local INTERVALO_GRABACION = 0.15
local DISTANCIA_MINIMA = 2
local VELOCIDAD_REBOBINADO = 45 -- studs/segundo
local TIEMPO_MAXIMO_BASE = 2.0
local TIEMPO_MAXIMO_POR_SALA = 1.0
local COOLDOWN_REBOBINADO = 7.0
local TAMANO_SPRITE = UDim2.fromOffset(128, 128)

local personaje, humanoid, rootPart
local zonaActual, numeroSalaActual
local estaEnZona = false
local historialSala = {}
local tiemposPorSala = {}
local tiempoTotalSegundos = 0
local tiempoPublicacion = 0
local tiempoDeteccion = 0
local tiempoGrabacion = 0
local rPresionada = false
local rebobinando = false
local puedeRebobinar = true
local inicioRebobinado = 0
local tiempoMaximoActual = TIEMPO_MAXIMO_BASE
local esperandoAterrizaje = false
local reactivarDespues = nil
local puntoActual
local impulsoTransportado
local rotacionTransportada
local inerciaTransportada
local autoRotateAnterior

local parametros = OverlapParams.new()
parametros.FilterType = Enum.RaycastFilterType.Include
parametros.RespectCanCollide = false
local conexionesSprites = {}

jugador:SetAttribute("EstaEnZona", false)
jugador:SetAttribute("NumeroSalaActual", nil)
jugador:SetAttribute("Rebobinando", false)

local function publicarDatosTiempo()
	tiempoTotalSegundos = 0
	for numero, tiempo in tiemposPorSala do
		tiempoTotalSegundos += tiempo
		jugador:SetAttribute("TiempoSala_" .. tostring(numero), math.floor(tiempo))
	end
	local limite = math.clamp(math.floor((180 * tiempoTotalSegundos) / (tiempoTotalSegundos + 60)), 60, 179)
	jugador:SetAttribute("TiempoTotalSegundos", math.floor(tiempoTotalSegundos))
	jugador:SetAttribute("TiempoLimiteRebobinado", limite)
end

local function capturarPunto()
	local velocidad = rootPart.AssemblyLinearVelocity
	local inercia = jugador:GetAttribute("InerciaAerea")
	if typeof(inercia) ~= "Vector3" then
		inercia = Vector3.new(velocidad.X, 0, velocidad.Z)
	end
	return {
		cframe = rootPart.CFrame,
		velocidad = velocidad,
		velocidadAngular = rootPart.AssemblyAngularVelocity,
		inerciaAerea = inercia,
	}
end

local function detectarZona()
	if not personaje or not rootPart or not personaje.Parent then return nil, nil end
	parametros.FilterDescendantsInstances = { personaje }
	local zonaElegida, numeroElegido
	for _, zona in CollectionService:GetTagged(TAG_ZONA) do
		if zona:IsA("BasePart") and zona:IsDescendantOf(workspace) then
			local numero = zona:GetAttribute("NumeroSala")
			if typeof(numero) == "number" then
				zona.CanQuery = true
				local partes = workspace:GetPartsInPart(zona, parametros)
				if #partes > 0 then
					if zona == zonaActual then return zona, numero end
					if not zonaElegida then zonaElegida, numeroElegido = zona, numero end
				end
			end
		end
	end
	return zonaElegida, numeroElegido
end

local function interpolarPunto(a, b, alpha)
	return {
		cframe = a.cframe:Lerp(b.cframe, alpha),
		velocidad = a.velocidad:Lerp(b.velocidad, alpha),
		velocidadAngular = a.velocidadAngular:Lerp(b.velocidadAngular, alpha),
		inerciaAerea = a.inerciaAerea:Lerp(b.inerciaAerea, alpha),
	}
end

local function finalizarRebobinado(conservarImpulso)
	if not rebobinando then return end
	rebobinando = false
	puedeRebobinar = false
	esperandoAterrizaje = true
	reactivarDespues = nil
	if humanoid and humanoid.Parent and humanoid.FloorMaterial ~= Enum.Material.Air then
		esperandoAterrizaje = false
		reactivarDespues = os.clock() + COOLDOWN_REBOBINADO
	end
	RunService:UnbindFromRenderStep("SistemaRebobinado")

	-- Si se soltó R entre dos puntos, conserva esa posición como extremo actual.
	if puntoActual and rootPart and rootPart.Parent then
		if #historialSala >= 2 and (rootPart.Position - puntoActual.cframe.Position).Magnitude > 0.01 then
			table.remove(historialSala, #historialSala)
			table.insert(historialSala, puntoActual)
		end
		rootPart.CFrame = puntoActual.cframe
		rootPart.Anchored = false
		-- La posición rebobina; el momentum viene del instante en que empezó R.
		rootPart.AssemblyLinearVelocity = conservarImpulso and impulsoTransportado or Vector3.zero
		rootPart.AssemblyAngularVelocity = conservarImpulso and rotacionTransportada or Vector3.zero
	end
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = autoRotateAnterior
		if conservarImpulso or humanoid.FloorMaterial == Enum.Material.Air then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
	-- El ImpulsadorPortal lee estos atributos, sin compartir ni mezclar sus scripts.
	jugador:SetAttribute("InerciaAerea", conservarImpulso and inerciaTransportada or Vector3.zero)
	jugador:SetAttribute("Rebobinando", false)
	impulsoTransportado, rotacionTransportada, inerciaTransportada = nil, nil, nil
end

local function avanzarRebobinado(dt)
	if not rebobinando then return end
	if os.clock() - inicioRebobinado >= tiempoMaximoActual then
		rPresionada = false
		finalizarRebobinado(true)
		return
	end
	if not rPresionada or not estaEnZona or not rootPart or not rootPart.Parent
		or not humanoid or humanoid.Health <= 0 or #historialSala < 2 then
		finalizarRebobinado(true)
		return
	end

	local indiceObjetivo = #historialSala - 1
	local objetivo = historialSala[indiceObjetivo]
	local distancia = (objetivo.cframe.Position - rootPart.Position).Magnitude
	local paso = VELOCIDAD_REBOBINADO * dt
	if distancia <= math.max(paso, 0.02) then
		rootPart.CFrame = objetivo.cframe
		puntoActual = objetivo
		table.remove(historialSala, #historialSala)
		if #historialSala <= 1 then
			rPresionada = false
			finalizarRebobinado(true)
		end
	else
		local alpha = math.clamp(paso / distancia, 0, 1)
		local puntoAnterior = puntoActual or capturarPunto()
		rootPart.CFrame = rootPart.CFrame:Lerp(objetivo.cframe, alpha)
		puntoActual = interpolarPunto(puntoAnterior, objetivo, alpha)
	end
end

local function iniciarRebobinado()
	if rebobinando or not puedeRebobinar or not estaEnZona or #historialSala < 2 then return end
	if not rootPart or not humanoid or humanoid.Health <= 0 then return end

	-- Incluye la posición más reciente por si R se presionó entre dos muestras.
	local ultimo = historialSala[#historialSala]
	if (rootPart.Position - ultimo.cframe.Position).Magnitude > 0.05 then
		table.insert(historialSala, capturarPunto())
	end
	puntoActual = historialSala[#historialSala]
	local salaDeUso = math.max(0, numeroSalaActual)
	tiempoMaximoActual = TIEMPO_MAXIMO_BASE + salaDeUso * TIEMPO_MAXIMO_POR_SALA
	-- Conserva el impulso actual como una carga y transpórtalo hasta la posición antigua.
	impulsoTransportado = rootPart.AssemblyLinearVelocity
	rotacionTransportada = rootPart.AssemblyAngularVelocity
	inerciaTransportada = jugador:GetAttribute("InerciaAerea")
	if typeof(inerciaTransportada) ~= "Vector3" then
		inerciaTransportada = Vector3.new(impulsoTransportado.X, 0, impulsoTransportado.Z)
	end
	rebobinando = true
	rPresionada = true
	inicioRebobinado = os.clock()
	autoRotateAnterior = humanoid.AutoRotate
	jugador:SetAttribute("Rebobinando", true)
	humanoid.AutoRotate = false
	rootPart.Anchored = true
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	RunService:BindToRenderStep("SistemaRebobinado", Enum.RenderPriority.Character.Value + 1, avanzarRebobinado)
end

local function actualizarZona()
	local nuevaZona, nuevoNumero = detectarZona()
	if nuevaZona == zonaActual and nuevoNumero == numeroSalaActual then
		estaEnZona = nuevaZona ~= nil
		return
	end
	zonaActual, numeroSalaActual = nuevaZona, nuevoNumero
	estaEnZona = nuevaZona ~= nil
	jugador:SetAttribute("EstaEnZona", estaEnZona)
	jugador:SetAttribute("NumeroSalaActual", numeroSalaActual)
	if not estaEnZona then
		if rebobinando then finalizarRebobinado(true) end
		table.clear(historialSala)
		tiempoGrabacion = 0
	elseif rootPart then
		table.clear(historialSala)
		table.insert(historialSala, capturarPunto())
		tiempoGrabacion = 0
	end
	publicarDatosTiempo()
end

local function guardarPosicion()
	if not estaEnZona or rebobinando or not rootPart or not humanoid or humanoid.Health <= 0 then return end
	local ultimo = historialSala[#historialSala]
	if not ultimo or (rootPart.Position - ultimo.cframe.Position).Magnitude > DISTANCIA_MINIMA then
		table.insert(historialSala, capturarPunto())
	end
end

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.R then
		rPresionada = true
		-- Actualiza la detección antes de permitir el rebobinado.
		actualizarZona()
		iniciarRebobinado()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.R then
		rPresionada = false
		finalizarRebobinado(true)
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	rPresionada = false
	finalizarRebobinado(true)
end)

local function asignarPersonaje(nuevo)
	if rebobinando then finalizarRebobinado(false) end
	personaje = nuevo
	humanoid = nuevo:WaitForChild("Humanoid")
	rootPart = nuevo:WaitForChild("HumanoidRootPart")
	zonaActual, numeroSalaActual, estaEnZona = nil, nil, false
	tiempoGrabacion = 0
	humanoid.Died:Connect(function()
		rPresionada = false
		finalizarRebobinado(false)
		table.clear(historialSala)
	end)
end
jugador.CharacterAdded:Connect(asignarPersonaje)
if jugador.Character then asignarPersonaje(jugador.Character) end

RunService.Heartbeat:Connect(function(dt)
	if not personaje or not rootPart then return end
	if not puedeRebobinar and humanoid and humanoid.Parent then
		if esperandoAterrizaje and humanoid.FloorMaterial ~= Enum.Material.Air then
			esperandoAterrizaje = false
			reactivarDespues = os.clock() + COOLDOWN_REBOBINADO
		elseif reactivarDespues and os.clock() >= reactivarDespues then
			puedeRebobinar = true
			reactivarDespues = nil
		end
	end
	tiempoDeteccion += dt
	if tiempoDeteccion >= INTERVALO_DETECCION then
		tiempoDeteccion %= INTERVALO_DETECCION
		actualizarZona()
	end
	if estaEnZona and numeroSalaActual ~= nil then
		tiempoGrabacion += dt
		tiempoPublicacion += dt
		tiempoTotalSegundos += dt
		tiemposPorSala[numeroSalaActual] = (tiemposPorSala[numeroSalaActual] or 0) + dt
		if tiempoGrabacion >= INTERVALO_GRABACION then
			tiempoGrabacion %= INTERVALO_GRABACION
			guardarPosicion()
		end
		if tiempoPublicacion >= 1 then
			tiempoPublicacion %= 1
			publicarDatosTiempo()
		end
	end
end)

-- Cargador local de sprites: BillboardGui mira automáticamente a la cámara.
local function actualizarSprite(parte)
	if not parte:IsA("BasePart") then return end
	local imageId = parte:GetAttribute("ImageId")
	if typeof(imageId) ~= "string" or imageId == "" then
		warn(("SpriteHolograma: falta el Attribute String ImageId en %s"):format(parte:GetFullName()))
		return
	end
	if imageId:match("^%d+$") then imageId = "rbxassetid://" .. imageId end

	local billboard = parte:FindFirstChild("SpriteHologramaBillboard")
	if billboard and not billboard:IsA("BillboardGui") then
		billboard:Destroy()
		billboard = nil
	end
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "SpriteHologramaBillboard"
		billboard.Adornee = parte
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.Size = TAMANO_SPRITE
		billboard.MaxDistance = 250
		billboard.Parent = parte
	end
	local imagen = billboard:FindFirstChild("Imagen")
	if imagen and not imagen:IsA("ImageLabel") then
		imagen:Destroy()
		imagen = nil
	end
	if not imagen then
		imagen = Instance.new("ImageLabel")
		imagen.Name = "Imagen"
		imagen.BackgroundTransparency = 1
		imagen.BorderSizePixel = 0
		imagen.Size = UDim2.fromScale(1, 1)
		imagen.ScaleType = Enum.ScaleType.Fit
		imagen.Parent = billboard
	end
	imagen.Image = imageId
end

local function registrarSprite(instancia)
	if not instancia:IsA("BasePart") or conexionesSprites[instancia] then return end
	conexionesSprites[instancia] = instancia:GetAttributeChangedSignal("ImageId"):Connect(function()
		actualizarSprite(instancia)
	end)
	actualizarSprite(instancia)
end

local function quitarSprite(instancia)
	local conexion = conexionesSprites[instancia]
	if conexion then conexion:Disconnect() end
	conexionesSprites[instancia] = nil
	local billboard = instancia:FindFirstChild("SpriteHologramaBillboard")
	if billboard then billboard:Destroy() end
end

for _, parte in CollectionService:GetTagged(TAG_SPRITE) do registrarSprite(parte) end
CollectionService:GetInstanceAddedSignal(TAG_SPRITE):Connect(registrarSprite)
CollectionService:GetInstanceRemovedSignal(TAG_SPRITE):Connect(quitarSprite)
