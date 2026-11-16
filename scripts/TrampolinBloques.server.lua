--[=[
	Script: ServerScriptService > TrampolinBloques.server.lua

	Pon el Tag "Trampolin" en cada Part/MeshPart de trampolín.
	Pon el Tag "ObjetoPesado" en el bloque (Part o Model).
	Los bloques usan la misma curva de rebote que el jugador.
]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG_TRAMPOLIN = "Trampolin"
local TAG_OBJETO = "ObjetoPesado"
local VELOCIDAD_MINIMA_CAIDA = 10
local MULTIPLICADOR_INICIAL = 1.35
local PERDIDA_POR_REBOTE = 0.15
local MULTIPLICADOR_MINIMO = 0.5
local IMPULSO_MINIMO_PRIMER_REBOTE = 60
local COOLDOWN_REBOTE = 0.25

local trampolinesConectados = {}
local objetosConectados = {}
local estados = {} -- [objeto] = { rebotes = number, ultimoRebote = number }
local parametrosSuelo = RaycastParams.new()
parametrosSuelo.FilterType = Enum.RaycastFilterType.Exclude

local function buscarObjetoPesado(instancia)
	local actual = instancia
	while actual and actual ~= workspace do
		if CollectionService:HasTag(actual, TAG_OBJETO) then
			return actual
		end
		actual = actual.Parent
	end
	return nil
end

local function buscarRaiz(objeto)
	if objeto:IsA("BasePart") then
		return objeto.AssemblyRootPart or objeto
	end
	if objeto:IsA("Model") then
		if objeto.PrimaryPart then
			return objeto.PrimaryPart.AssemblyRootPart or objeto.PrimaryPart
		end
		for _, parte in objeto:GetDescendants() do
			if parte:IsA("BasePart") then
				return parte.AssemblyRootPart or parte
			end
		end
	end
	return nil
end

local function esTrampolin(instancia)
	local actual = instancia
	while actual and actual ~= workspace do
		if CollectionService:HasTag(actual, TAG_TRAMPOLIN) then
			return true
		end
		actual = actual.Parent
	end
	return false
end

local function conectarTrampolin(trampolin)
	if trampolinesConectados[trampolin] or not trampolin:IsA("BasePart") then
		return
	end
	trampolinesConectados[trampolin] = true
	trampolin.CanTouch = true
	trampolin.Touched:Connect(function(parteTocada)
		local objeto = buscarObjetoPesado(parteTocada)
		if not objeto then
			return
		end
		local raiz = buscarRaiz(objeto)
		if not raiz or raiz.Anchored then
			return
		end

		local ahora = os.clock()
		local estado = estados[objeto]
		if not estado then
			estado = { rebotes = 0, ultimoRebote = 0 }
			estados[objeto] = estado
		end
		if ahora - estado.ultimoRebote < COOLDOWN_REBOTE then
			return
		end

		local velocidad = raiz.AssemblyLinearVelocity
		local velocidadCaida = -velocidad.Y
		if velocidadCaida <= VELOCIDAD_MINIMA_CAIDA then
			return
		end

		local multiplicador = math.max(
			MULTIPLICADOR_MINIMO,
			MULTIPLICADOR_INICIAL - PERDIDA_POR_REBOTE * estado.rebotes
		)
		local velocidadRebote = velocidadCaida * multiplicador
		if estado.rebotes == 0 then
			velocidadRebote = math.max(IMPULSO_MINIMO_PRIMER_REBOTE, velocidadRebote)
		end

		estado.rebotes += 1
		estado.ultimoRebote = ahora
		raiz.AssemblyLinearVelocity = Vector3.new(velocidad.X, velocidadRebote, velocidad.Z)
	end)
end

local function conectarObjeto(objeto)
	if objetosConectados[objeto] then
		return
	end
	objetosConectados[objeto] = true
	estados[objeto] = { rebotes = 0, ultimoRebote = 0 }
end

for _, trampolin in CollectionService:GetTagged(TAG_TRAMPOLIN) do
	conectarTrampolin(trampolin)
end
for _, objeto in CollectionService:GetTagged(TAG_OBJETO) do
	conectarObjeto(objeto)
end
CollectionService:GetInstanceAddedSignal(TAG_TRAMPOLIN):Connect(conectarTrampolin)
CollectionService:GetInstanceAddedSignal(TAG_OBJETO):Connect(conectarObjeto)
CollectionService:GetInstanceRemovedSignal(TAG_OBJETO):Connect(function(objeto)
	objetosConectados[objeto] = nil
	estados[objeto] = nil
end)

-- Reinicia el contador de cada bloque al aterrizar sobre cualquier superficie normal.
RunService.Heartbeat:Connect(function()
	for objeto, estado in estados do
		local raiz = buscarRaiz(objeto)
		if not raiz or raiz.Anchored or raiz.AssemblyLinearVelocity.Y > 1 then
			continue
		end

		local origen = raiz.Position
		local distancia = raiz.Size.Y * 0.5 + 1
		if objeto:IsA("Model") then
			local _, tamano = objeto:GetBoundingBox()
			distancia = tamano.Y * 0.5 + 1
		end
		parametrosSuelo.FilterDescendantsInstances = { objeto }
		local resultado = workspace:Raycast(origen, Vector3.new(0, -distancia, 0), parametrosSuelo)
		if resultado and resultado.Normal.Y > 0.5 and not esTrampolin(resultado.Instance) then
			estado.rebotes = 0
		end
	end
end)
