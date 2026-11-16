--[=[
	Script: ServerScriptService > SistemaFuerza

	Tags y Attributes Number:
	  ObjetoPesado    -> Valor (fuerza base del objeto)
	  BasculaReceptor -> Valor (porcentaje requerido; RequisitoPorcentaje es alternativa)

	Usa consultas de solapamiento cada Heartbeat para detectar también piezas
	movidas por CFrame. Cada objeto aporta una lectura al entrar y ese aporte
	se retira cuando sale; la báscula representa el peso presente ahora.
]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DatosJuego = require(ServerStorage:WaitForChild("DatosJuego"))

local TAG_OBJETO = "ObjetoPesado"
local TAG_RECEPTOR = "BasculaReceptor"
local ATRIBUTO_VALOR = "Valor"

-- CALIBRACIÓN DEL IMPACTO (studs y segundos)
local VENTANA_PICO = 0.8 -- segundos: cuánto tiempo se conserva la velocidad pico
local VELOCIDAD_MINIMA = 5 -- studs/s: por debajo de esto no hay bono de impacto
local ALTURA_PARA_BONO_MAXIMO = 20.65 -- studs de caída libre equivalentes al bono máximo
local VELOCIDAD_MAXIMA = math.sqrt(2 * workspace.Gravity * ALTURA_PARA_BONO_MAXIMO)
-- La velocidad se convierte en un progreso 0..1 entre VELOCIDAD_MINIMA y VELOCIDAD_MAXIMA.
-- Curva 1 = lineal; >1 hace que el bono crezca más lentamente al principio.
local CURVA_VELOCIDAD = 1.5
local VELOCIDAD_REPOSO = 0.5
local REQUISITO_SI_FALTA = 100

local objetosPesados = {}
local muestrasVelocidad = {}
local suprimidoHastaReposo = {}
local receptores = {} -- [instancia] = { partes = { [BasePart] = true } }
local contactos = {} -- [receptor] = { [objetoPesado] = aporteGuardado }

local function obtenerPiezaFisica(instancia)
	if instancia:IsA("BasePart") then
		return instancia.AssemblyRootPart or instancia
	elseif instancia:IsA("Model") then
		if instancia.PrimaryPart then
			return instancia.PrimaryPart.AssemblyRootPart or instancia.PrimaryPart
		end
		for _, descendiente in instancia:GetDescendants() do
			if descendiente:IsA("BasePart") then
				return descendiente.AssemblyRootPart or descendiente
			end
		end
	end
	return nil
end

local function obtenerPartes(instancia)
	if instancia:IsA("BasePart") then
		return { instancia }
	end

	local partes = {}
	if instancia:IsA("Model") then
		for _, descendiente in instancia:GetDescendants() do
			if descendiente:IsA("BasePart") then
				table.insert(partes, descendiente)
			end
		end
	end
	return partes
end

local function registrarObjetoPesado(objeto)
	if objetosPesados[objeto] then
		return
	end
	if not obtenerPiezaFisica(objeto) then
		warn(("SistemaFuerza: %s necesita ser BasePart o Model con BasePart")
			:format(objeto:GetFullName()))
		return
	end

	objetosPesados[objeto] = true
	muestrasVelocidad[objeto] = {}
	for _, parte in obtenerPartes(objeto) do
		parte.CanQuery = true
	end
	print("SistemaFuerza: objeto registrado:", objeto:GetFullName())
end

local function buscarObjetoPesado(pieza)
	local actual = pieza
	while actual and actual ~= workspace do
		if CollectionService:HasTag(actual, TAG_OBJETO) then
			registrarObjetoPesado(actual)
			return objetosPesados[actual] and actual or nil
		end
		actual = actual.Parent
	end
	return nil
end

local function obtenerValor(instancia, valorPorDefecto)
	local valor = instancia:GetAttribute(ATRIBUTO_VALOR)
	if typeof(valor) == "number" then
		return valor
	end
	warn(("SistemaFuerza: %s no tiene el Attribute Number %q; se usará %s")
		:format(instancia:GetFullName(), ATRIBUTO_VALOR, tostring(valorPorDefecto)))
	return valorPorDefecto
end

local function obtenerRequisito(receptor)
	local requisito = receptor:GetAttribute(ATRIBUTO_VALOR)
	if typeof(requisito) == "number" then
		return requisito
	end
	requisito = receptor:GetAttribute("RequisitoPorcentaje")
	if typeof(requisito) == "number" then
		return requisito
	end
	warn(("SistemaFuerza: %s no tiene el Attribute Number %q; se usará %s")
		:format(receptor:GetFullName(), ATRIBUTO_VALOR, tostring(REQUISITO_SI_FALTA)))
	return REQUISITO_SI_FALTA
end

local function calcularPorcentaje(objeto, fuerzaBase)
	local pieza = obtenerPiezaFisica(objeto)
	if not pieza then
		return 0
	end

	local velocidadActual = pieza.AssemblyLinearVelocity.Magnitude
	local pico = velocidadActual
	local ahora = os.clock()
	local muestras = muestrasVelocidad[objeto] or {}

	for indice = #muestras, 1, -1 do
		local muestra = muestras[indice]
		if ahora - muestra.tiempo > VENTANA_PICO then
			table.remove(muestras, indice)
		elseif muestra.velocidad > pico then
			pico = muestra.velocidad
		end
	end

	local progreso = math.clamp(
		(pico - VELOCIDAD_MINIMA) / (VELOCIDAD_MAXIMA - VELOCIDAD_MINIMA),
		0,
		1
	)
	local curva = progreso ^ CURVA_VELOCIDAD
	local porcentajeRestante = 100 - math.clamp(fuerzaBase, 0, 100)
	return math.clamp(fuerzaBase + porcentajeRestante * curva, 0, 100)
end

local function reiniciarBono(objeto)
	-- Ignora velocidad residual del impacto hasta que el objeto vuelva al reposo.
	suprimidoHastaReposo[objeto] = true
	muestrasVelocidad[objeto] = {}
end

local function calcularAporteImpacto(objeto)
	local fuerzaBase = obtenerValor(objeto, 0)
	local aporteImpacto = calcularPorcentaje(objeto, fuerzaBase)
	reiniciarBono(objeto)
	return aporteImpacto
end

local function registrarParteReceptora(receptor, parte)
	local config = receptores[receptor]
	if not config or config.partes[parte] then
		return
	end
	config.partes[parte] = true
	parte.CanQuery = true
end

local function registrarReceptor(receptor)
	if receptores[receptor] then
		return
	end

	local partes = obtenerPartes(receptor)
	if #partes == 0 then
		warn(("SistemaFuerza: %s necesita ser BasePart o Model con BasePart")
			:format(receptor:GetFullName()))
		return
	end

	DatosJuego.ObtenerEstado(receptor)
	receptores[receptor] = { partes = {} }
	for _, parte in partes do
		registrarParteReceptora(receptor, parte)
	end
	if receptor:IsA("Model") then
		receptor.DescendantAdded:Connect(function(descendiente)
			if descendiente:IsA("BasePart") then
				registrarParteReceptora(receptor, descendiente)
			end
		end)
	end
	print("SistemaFuerza: receptor registrado:", receptor:GetFullName())
end

for _, objeto in CollectionService:GetTagged(TAG_OBJETO) do
	registrarObjetoPesado(objeto)
end
for _, receptor in CollectionService:GetTagged(TAG_RECEPTOR) do
	registrarReceptor(receptor)
end
CollectionService:GetInstanceAddedSignal(TAG_OBJETO):Connect(registrarObjetoPesado)
CollectionService:GetInstanceAddedSignal(TAG_RECEPTOR):Connect(registrarReceptor)

CollectionService:GetInstanceRemovedSignal(TAG_OBJETO):Connect(function(objeto)
	objetosPesados[objeto] = nil
	muestrasVelocidad[objeto] = nil
	suprimidoHastaReposo[objeto] = nil
end)
CollectionService:GetInstanceRemovedSignal(TAG_RECEPTOR):Connect(function(receptor)
	receptores[receptor] = nil
	contactos[receptor] = nil
end)

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.RespectCanCollide = false

RunService.Heartbeat:Connect(function()
	local ahora = os.clock()
	local filtroObjetos = {}
	for objeto in objetosPesados do
		if objeto:IsDescendantOf(workspace) then
			table.insert(filtroObjetos, objeto)
			local pieza = obtenerPiezaFisica(objeto)
			if pieza then
				local velocidad = pieza.AssemblyLinearVelocity.Magnitude
				if suprimidoHastaReposo[objeto] then
					if velocidad <= VELOCIDAD_REPOSO then
						suprimidoHastaReposo[objeto] = nil
						muestrasVelocidad[objeto] = {}
					end
				else
					local muestras = muestrasVelocidad[objeto] or {}
					muestrasVelocidad[objeto] = muestras
					table.insert(muestras, { tiempo = ahora, velocidad = velocidad })
					while muestras[1] and ahora - muestras[1].tiempo > VENTANA_PICO do
						table.remove(muestras, 1)
					end
				end
			end
		end
	end

	overlapParams.FilterDescendantsInstances = filtroObjetos
	for receptor, config in receptores do
		if DatosJuego.ObtenerEstado(receptor).Bloqueada then
			-- Al alcanzar el requisito, congela el resultado aunque los objetos salgan.
			contactos[receptor] = nil
			continue
		end

		local superpuestos = {}
		if #filtroObjetos > 0 then
			for parteReceptora in config.partes do
				if parteReceptora.Parent then
					for _, parteTocando in workspace:GetPartsInPart(parteReceptora, overlapParams) do
						local objeto = buscarObjetoPesado(parteTocando)
						if objeto then
							superpuestos[objeto] = true
						end
					end
				end
			end
		end

		local anteriores = contactos[receptor] or {}
		local nuevosContactos = {}
		local cambio = false

		for objeto in superpuestos do
			local aporte = anteriores[objeto]
			if aporte == nil then
				aporte = calcularAporteImpacto(objeto)
				cambio = true
				print(("SistemaFuerza: %s entra en %s y aporta %.2f%%")
					:format(objeto:GetFullName(), receptor:GetFullName(), aporte))
			end
			nuevosContactos[objeto] = aporte
		end

		for objeto, aporte in anteriores do
			if not superpuestos[objeto] then
				cambio = true
				print(("SistemaFuerza: %s sale de %s; retira %.2f%%")
					:format(objeto:GetFullName(), receptor:GetFullName(), aporte))
			end
		end

		if cambio then
			local totalBruto = 0
			for _, aporte in nuevosContactos do
				totalBruto += aporte
			end
			local porcentajeAnterior = DatosJuego.ObtenerEstado(receptor).PorcentajeRegistrado
			local porcentajeTotal = math.clamp(totalBruto, 0, 100)
			local requisito = math.clamp(obtenerRequisito(receptor), 0, 100)
			receptor:SetAttribute("PorcentajeBase", porcentajeAnterior)
			local estado = DatosJuego.EstablecerEstado(receptor, porcentajeTotal, requisito)
			print(("SistemaFuerza: total actual de %s = %.2f%% / %.2f%% (Bloqueada=%s)")
				:format(receptor:GetFullName(), estado.PorcentajeRegistrado, requisito, tostring(estado.Bloqueada)))
		end

		contactos[receptor] = nuevosContactos
	end
end)
