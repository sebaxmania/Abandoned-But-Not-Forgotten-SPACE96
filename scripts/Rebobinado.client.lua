--[=[
	LocalScript: StarterPlayer > StarterPlayerScripts > Rebobinado
	R solo funciona dentro de una ZonaSala. Las rutas viejas nunca se borran:
	cada rebobinado o nueva visita crea otro tramo guardado en memoria.
]=]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local jugador = Players.LocalPlayer
local TAG_ZONA = "ZonaSala"
local INTERVALO_GRABACION = 0.2
local DISTANCIA_MINIMA = 2
local PUNTOS_REBOBINADOS_POR_SEGUNDO = 10
local INTERVALO_DETECCION = 0.1

-- [NumeroSala] = { { snapshots... }, { otra visita/rama... } }
local rutasPorSala = {}
local acumuladorGrabacion = 0
local acumuladorDeteccion = 0
local personaje, humanoid, raiz
local zonaActual, salaActual, rutaActiva
local rebobinando = false
local indiceRebobinado = 0
local rutaRebobinada
local autoRotateAnterior, ancladoAnterior

local parametros = OverlapParams.new()
parametros.FilterType = Enum.RaycastFilterType.Include
parametros.RespectCanCollide = false

local function capturarSnapshot()
	local inercia = jugador:GetAttribute("InerciaAerea")
	if typeof(inercia) ~= "Vector3" then inercia = Vector3.zero end
	return {
		cframe = raiz.CFrame,
		velocidad = raiz.AssemblyLinearVelocity,
		velocidadAngular = raiz.AssemblyAngularVelocity,
		inerciaAerea = inercia,
	}
end

local function crearRuta(numeroSala, snapshotInicial)
	local rutas = rutasPorSala[numeroSala]
	if not rutas then
		rutas = {}
		rutasPorSala[numeroSala] = rutas
	end
	local nuevaRuta = {}
	table.insert(rutas, nuevaRuta)
	if snapshotInicial then table.insert(nuevaRuta, snapshotInicial) end
	return nuevaRuta
end

local function detectarZonaLocal()
	if not personaje or not raiz or not personaje.Parent then return nil, nil end
	parametros.FilterDescendantsInstances = { personaje }
	local zonaElegida, salaElegida
	local zonaAnterior = zonaActual

	for _, zona in CollectionService:GetTagged(TAG_ZONA) do
		if zona:IsA("BasePart") and zona:IsDescendantOf(workspace) then
			local numeroSala = zona:GetAttribute("NumeroSala")
			if typeof(numeroSala) == "number" then
				zona.CanQuery = true
				local superpuestos = workspace:GetPartsInPart(zona, parametros)
				if #superpuestos > 0 then
					if zona == zonaAnterior then
						return zona, numeroSala
					elseif not zonaElegida then
						zonaElegida, salaElegida = zona, numeroSala
					end
				end
			end
		end
	end
	return zonaElegida, salaElegida
end

local function actualizarZonaLocal()
	local nuevaZona, nuevoNumero = detectarZonaLocal()
	if nuevaZona == zonaActual and nuevoNumero == salaActual then return end
	zonaActual, salaActual = nuevaZona, nuevoNumero
	rutaActiva = nil
	if zonaActual and salaActual ~= nil and raiz then
		rutaActiva = crearRuta(salaActual, capturarSnapshot())
	end
end

local function guardarPunto()
	if rebobinando or not raiz or not humanoid or humanoid.Health <= 0 then return end
	actualizarZonaLocal()
	if not zonaActual or not rutaActiva then return end
	local ultimo = rutaActiva[#rutaActiva]
	if not ultimo or (raiz.Position - ultimo.cframe.Position).Magnitude > DISTANCIA_MINIMA then
		table.insert(rutaActiva, capturarSnapshot())
	end
end

local function interpolar(ruta, indice)
	local inferior = math.floor(indice)
	local superior = math.min(inferior + 1, #ruta)
	local alpha = indice - inferior
	local a, b = ruta[inferior], ruta[superior]
	return {
		cframe = a.cframe:Lerp(b.cframe, alpha),
		velocidad = a.velocidad:Lerp(b.velocidad, alpha),
		velocidadAngular = a.velocidadAngular:Lerp(b.velocidadAngular, alpha),
		inerciaAerea = a.inerciaAerea:Lerp(b.inerciaAerea, alpha),
	}
end

local function detenerRebobinado()
	if not rebobinando then return end
	rebobinando = false
	RunService:UnbindFromRenderStep("RebobinadoDirecto")
	local ruta = rutaRebobinada
	local estado = interpolar(ruta, math.clamp(indiceRebobinado, 1, #ruta))

	if raiz and raiz.Parent then
		raiz.CFrame = estado.cframe
		raiz.Anchored = ancladoAnterior or false
		if not raiz.Anchored then
			raiz.AssemblyLinearVelocity = estado.velocidad
			raiz.AssemblyAngularVelocity = estado.velocidadAngular
		end
	end
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = autoRotateAnterior
		if humanoid.FloorMaterial == Enum.Material.Air then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
	jugador:SetAttribute("InerciaAerea", estado.inerciaAerea)
	jugador:SetAttribute("Rebobinando", false)

	-- No se elimina nada: el nuevo recorrido queda en una rama nueva de la sala.
	actualizarZonaLocal()
	if zonaActual and salaActual ~= nil then
		rutaActiva = crearRuta(salaActual, estado)
	else
		rutaActiva = nil
	end
	rutaRebobinada = nil
end

local function iniciarRebobinado()
	actualizarZonaLocal()
	if rebobinando or not zonaActual or not salaActual or not rutaActiva or #rutaActiva < 2 then return end
	if not humanoid or humanoid.Health <= 0 or not raiz then return end

	rebobinando = true
	rutaRebobinada = rutaActiva
	indiceRebobinado = #rutaRebobinada
	autoRotateAnterior = humanoid.AutoRotate
	ancladoAnterior = raiz.Anchored
	jugador:SetAttribute("Rebobinando", true)
	humanoid.AutoRotate = false
	-- La inercia queda en los snapshots y se reactiva solo al soltar R.
	jugador:SetAttribute("InerciaAerea", Vector3.zero)
	raiz.AssemblyLinearVelocity = Vector3.zero
	raiz.AssemblyAngularVelocity = Vector3.zero
	raiz.Anchored = true
end

local function avanzarRebobinado(dt)
	if not rebobinando or not raiz or not raiz.Parent then return end
	indiceRebobinado = math.max(1, indiceRebobinado - dt * PUNTOS_REBOBINADOS_POR_SEGUNDO)
	raiz.CFrame = interpolar(rutaRebobinada, indiceRebobinado).cframe
end

RunService:BindToRenderStep("RebobinadoDirecto", Enum.RenderPriority.Character.Value + 1, avanzarRebobinado)
UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.R then iniciarRebobinado() end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.R then detenerRebobinado() end
end)

local function asignarPersonaje(nuevo)
	if rebobinando then detenerRebobinado() end
	personaje = nuevo
	humanoid = nuevo:WaitForChild("Humanoid")
	raiz = nuevo:WaitForChild("HumanoidRootPart")
	acumuladorGrabacion, acumuladorDeteccion = 0, 0
	zonaActual, salaActual, rutaActiva = nil, nil, nil
end
jugador.CharacterAdded:Connect(asignarPersonaje)
if jugador.Character then asignarPersonaje(jugador.Character) end

RunService.Heartbeat:Connect(function(dt)
	if not personaje or not raiz then return end
	acumuladorDeteccion += dt
	if acumuladorDeteccion >= INTERVALO_DETECCION then
		acumuladorDeteccion %= INTERVALO_DETECCION
		local zonaAntes = zonaActual
		actualizarZonaLocal()
		if rebobinando and (not zonaActual or zonaActual ~= zonaAntes) then
			detenerRebobinado()
		end
	end
	if rebobinando then return end
	acumuladorGrabacion += dt
	if acumuladorGrabacion >= INTERVALO_GRABACION then
		acumuladorGrabacion %= INTERVALO_GRABACION
		guardarPunto()
	end
end)
