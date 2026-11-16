--[=[
	LocalScript: StarterPlayer > StarterPlayerScripts > ImpulsadorPortal.client.lua

	Pon el Tag "ImpulsadorPortal" en cada Part/MeshPart de lanzamiento.
	Attributes numéricos opcionales en la placa:
	  FuerzaAdelante (default 90)
	  FuerzaArriba (default 75)
	Ajusta la orientación de la placa: LookVector apunta hacia donde quieres lanzar.
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local jugador = Players.LocalPlayer
local TAG_IMPULSADOR = "ImpulsadorPortal"
local FUERZA_ADELANTE_DEFAULT = 90
local FUERZA_ARRIBA_DEFAULT = 75
local COOLDOWN = 0.35
local UMBRAL_INERCIA = 16
local RETENCION_INERCIA_POR_FRAME = 0.9992 -- a 60 FPS; menor valor = pierde velocidad más rápido
local ACELERACION_AEREA = 24 -- studs/s² de control direccional en el aire
local VELOCIDAD_AEREA_MAXIMA = 120

local personajeActual
local humanoidActual
local raizActual
local ultimaActivacion = {}
local conexiones = {}
local inerciaAerea = Vector3.zero
local yaDespego = false

local function conectarPlaca(placa)
	if conexiones[placa] or not placa:IsA("BasePart") then
		return
	end
	conexiones[placa] = true

	placa.Touched:Connect(function(parteTocada)
		if jugador:GetAttribute("Rebobinando") == true then
			return
		end
		if not personajeActual or not parteTocada:IsDescendantOf(personajeActual) then
			return
		end
		if not humanoidActual or humanoidActual.Health <= 0 or not raizActual then
			return
		end

		local ahora = os.clock()
		if ahora - (ultimaActivacion[placa] or 0) < COOLDOWN then
			return
		end

		local adelante = placa:GetAttribute("FuerzaAdelante")
		local arriba = placa:GetAttribute("FuerzaArriba")
		if typeof(adelante) ~= "number" then
			adelante = FUERZA_ADELANTE_DEFAULT
		end
		if typeof(arriba) ~= "number" then
			arriba = FUERZA_ARRIBA_DEFAULT
		end

		ultimaActivacion[placa] = ahora
		local direccion = placa.CFrame.LookVector
		local impulso = direccion * adelante + Vector3.new(0, arriba, 0)
		inerciaAerea = Vector3.new(impulso.X, 0, impulso.Z)
		jugador:SetAttribute("InerciaAerea", inerciaAerea)
		yaDespego = false
		raizActual.AssemblyLinearVelocity = impulso
		humanoidActual:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
end

local function asignarPersonaje(personaje)
	personajeActual = personaje
	humanoidActual = personaje:WaitForChild("Humanoid")
	raizActual = personaje:WaitForChild("HumanoidRootPart")
	inerciaAerea = Vector3.zero
	jugador:SetAttribute("InerciaAerea", inerciaAerea)
	yaDespego = false
end

for _, placa in CollectionService:GetTagged(TAG_IMPULSADOR) do
	conectarPlaca(placa)
end
CollectionService:GetInstanceAddedSignal(TAG_IMPULSADOR):Connect(conectarPlaca)
jugador.CharacterAdded:Connect(asignarPersonaje)
if jugador.Character then
	asignarPersonaje(jugador.Character)
end

RunService.Heartbeat:Connect(function(deltaTime)
	if not personajeActual or not humanoidActual or not raizActual then
		return
	end
	if jugador:GetAttribute("Rebobinando") == true then
		return
	end
	local inerciaGuardada = jugador:GetAttribute("InerciaAerea")
	if typeof(inerciaGuardada) == "Vector3" then
		inerciaAerea = inerciaGuardada
	end

	if humanoidActual.FloorMaterial == Enum.Material.Air then
		yaDespego = true
		if inerciaAerea.Magnitude > UMBRAL_INERCIA then
			-- El input acelera poco a poco la inercia; no suma 8 studs/s cada frame.
			local direccionMovimiento = humanoidActual.MoveDirection
			local aceleracionHorizontal = Vector3.new(direccionMovimiento.X, 0, direccionMovimiento.Z)
			inerciaAerea += aceleracionHorizontal * ACELERACION_AEREA * deltaTime
			if inerciaAerea.Magnitude > VELOCIDAD_AEREA_MAXIMA then
				inerciaAerea = inerciaAerea.Unit * VELOCIDAD_AEREA_MAXIMA
			end

			-- Mantiene una retención equivalente por segundo aunque cambien los FPS.
			inerciaAerea *= RETENCION_INERCIA_POR_FRAME ^ (deltaTime * 60)
			local velocidadActual = raizActual.AssemblyLinearVelocity
			raizActual.AssemblyLinearVelocity = Vector3.new(
				inerciaAerea.X,
				velocidadActual.Y,
				inerciaAerea.Z
			)
		elseif inerciaAerea.Magnitude > 0 then
			inerciaAerea = Vector3.zero
		end
	elseif yaDespego then
		-- Solo cuenta como aterrizaje después de haber estado realmente en el aire.
		inerciaAerea = Vector3.zero
		yaDespego = false
	end
	jugador:SetAttribute("InerciaAerea", inerciaAerea)
end)
