--[=[
	PuertasPorPeso.server.lua
	Coloca este Script en ServerScriptService y reemplaza el controlador anterior.

	Las puertas deben ser Models etiquetados con PuertaNivel, PuertaTutorial o PuertaElevador.
	PuertaNivel usa el Attribute Number IDPuerta.
	PuertaElevador se abre una vez, 5 segundos después de iniciar este Script.
	La báscula usa BasculaReceptor, el mismo IDPuerta, Valor y PorcentajeRegistrado.
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TAG_PUERTA_NIVEL = "PuertaNivel"
local TAG_PUERTA_TUTORIAL = "PuertaTutorial"
local TAG_PUERTA_ELEVADOR = "PuertaElevador"
local TAG_BASCULA = "BasculaReceptor"

local DISTANCIA_APERTURA_TUTORIAL = 12
local DISTANCIA_CIERRE_TRAS_CRUCE = 5

local puertas = {} -- [Model] = estado
local puertasPorID = {} -- [IDPuerta] = {Model, ...}
local conexionesBasculas = {} -- [Model o BasePart] = {conexiones}
local esperaElevadorTerminada = false

local function obtenerPartes(modelo)
	local partes = {}
	for _, instancia in ipairs(modelo:GetDescendants()) do
		if instancia:IsA("BasePart") then
			table.insert(partes, instancia)
		end
	end
	return partes
end

local function abrirPuerta(modelo, jugadorQueAbre)
	local estado = puertas[modelo]
	if not estado or estado.abierta or estado.bloqueadaParaSiempre then
		return
	end

	local pivot = modelo:GetPivot()
	estado.pivotAlAbrir = pivot
	estado.ladosIniciales = {}
	estado.abierta = true
	modelo:SetAttribute("PuertaAbierta", true)

	-- La puerta desaparece y deja de bloquear el paso al instante.
	for _, parte in ipairs(obtenerPartes(modelo)) do
		parte.Transparency = 1
		parte.CanCollide = false
	end

	-- La báscula no identifica al jugador que puso el objeto, así que registra a todos.
	-- La puerta tutorial registra solamente al jugador que la activó por proximidad.
	for _, jugador in ipairs(Players:GetPlayers()) do
		if not jugadorQueAbre or jugador == jugadorQueAbre then
			local character = jugador.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local lado = math.sign((hrp.Position - pivot.Position):Dot(pivot.LookVector))
				if lado ~= 0 then
					estado.ladosIniciales[jugador] = lado
				end
			end
		end
	end
end

local function cerrarPuerta(modelo)
	for _, parte in ipairs(obtenerPartes(modelo)) do
		parte.Transparency = 0
		parte.CanCollide = true
	end
end

local function bloquearDespuesDeCruzar(modelo)
	local estado = puertas[modelo]
	if not estado or not estado.abierta or estado.bloqueadaParaSiempre then
		return
	end

	estado.abierta = false
	estado.bloqueadaParaSiempre = true
	modelo:SetAttribute("PuertaAbierta", false)
	modelo:SetAttribute("PuertaBloqueadaParaSiempre", true)
	cerrarPuerta(modelo)
	print("PuertasPorPeso: cerrada y bloqueada:", modelo:GetFullName())
end

local function requisitoDeBascula(bascula)
	local valor = bascula:GetAttribute("Valor")
	if typeof(valor) == "number" then
		return math.clamp(valor, 0, 100)
	end
	return 100
end

local function comprobarBascula(bascula)
	local id = bascula:GetAttribute("IDPuerta")
	local porcentaje = bascula:GetAttribute("PorcentajeRegistrado")
	local alcanzado = bascula:GetAttribute("Bloqueada") == true
		or (typeof(porcentaje) == "number" and porcentaje >= requisitoDeBascula(bascula))
	if not alcanzado then
		return
	end
	if typeof(id) ~= "number" then
		warn(("PuertasPorPeso: %s necesita el Attribute Number IDPuerta.")
			:format(bascula:GetFullName()))
		return
	end

	for _, modelo in ipairs(puertasPorID[id] or {}) do
		abrirPuerta(modelo)
	end
end

local function registrarPuerta(modelo)
	if not modelo:IsA("Model") then
		warn(("PuertasPorPeso: %s tiene un tag de puerta, pero no es un Model.")
			:format(modelo:GetFullName()))
		return
	end
	if puertas[modelo] then
		return
	end
	if #obtenerPartes(modelo) == 0 then
		warn(("PuertasPorPeso: %s no contiene BaseParts."):format(modelo:GetFullName()))
		return
	end

	local esNivel = CollectionService:HasTag(modelo, TAG_PUERTA_NIVEL)
	local esTutorial = CollectionService:HasTag(modelo, TAG_PUERTA_TUTORIAL)
	local esElevador = CollectionService:HasTag(modelo, TAG_PUERTA_ELEVADOR)
	local id = modelo:GetAttribute("IDPuerta")
	if esNivel and typeof(id) ~= "number" then
		warn(("PuertasPorPeso: %s necesita el Attribute Number IDPuerta.")
			:format(modelo:GetFullName()))
		return
	end

	local estado = {
		abierta = false,
		bloqueadaParaSiempre = false,
		seCierraAlCruzar = esNivel or esTutorial,
		esTutorial = esTutorial,
		esElevador = esElevador,
		ladosIniciales = {},
		pivotAlAbrir = nil,
	}
	puertas[modelo] = estado
	modelo:SetAttribute("PuertaAbierta", false)
	modelo:SetAttribute("PuertaBloqueadaParaSiempre", false)
	cerrarPuerta(modelo)

	if esNivel then
		puertasPorID[id] = puertasPorID[id] or {}
		table.insert(puertasPorID[id], modelo)
		for bascula in pairs(conexionesBasculas) do
			comprobarBascula(bascula)
		end
	end
	if esElevador and esperaElevadorTerminada then
		abrirPuerta(modelo)
	end
	print("PuertasPorPeso: preparada:", modelo:GetFullName())
end

local function quitarPuerta(modelo)
	local estado = puertas[modelo]
	if not estado then
		return
	end
	local id = modelo:GetAttribute("IDPuerta")
	local lista = puertasPorID[id]
	if lista then
		for indice, actual in ipairs(lista) do
			if actual == modelo then
				table.remove(lista, indice)
				break
			end
		end
	end
	puertas[modelo] = nil
end

local function registrarBascula(bascula)
	if conexionesBasculas[bascula] then
		return
	end
	local conexiones = {
		bascula:GetAttributeChangedSignal("PorcentajeRegistrado"):Connect(function()
			comprobarBascula(bascula)
		end),
		bascula:GetAttributeChangedSignal("Bloqueada"):Connect(function()
			comprobarBascula(bascula)
		end),
		bascula:GetAttributeChangedSignal("IDPuerta"):Connect(function()
			comprobarBascula(bascula)
		end),
		bascula:GetAttributeChangedSignal("Valor"):Connect(function()
			comprobarBascula(bascula)
		end),
	}
	conexionesBasculas[bascula] = conexiones
	comprobarBascula(bascula)
end

local function quitarBascula(bascula)
	local conexiones = conexionesBasculas[bascula]
	if not conexiones then
		return
	end
	for _, conexion in ipairs(conexiones) do
		conexion:Disconnect()
	end
	conexionesBasculas[bascula] = nil
end

local function actualizarTagPuerta(modelo)
	if CollectionService:HasTag(modelo, TAG_PUERTA_NIVEL)
		or CollectionService:HasTag(modelo, TAG_PUERTA_TUTORIAL)
		or CollectionService:HasTag(modelo, TAG_PUERTA_ELEVADOR) then
		registrarPuerta(modelo)
	else
		quitarPuerta(modelo)
	end
end

for _, modelo in ipairs(CollectionService:GetTagged(TAG_PUERTA_NIVEL)) do
	registrarPuerta(modelo)
end
for _, modelo in ipairs(CollectionService:GetTagged(TAG_PUERTA_TUTORIAL)) do
	registrarPuerta(modelo)
end
for _, modelo in ipairs(CollectionService:GetTagged(TAG_PUERTA_ELEVADOR)) do
	registrarPuerta(modelo)
end
for _, bascula in ipairs(CollectionService:GetTagged(TAG_BASCULA)) do
	registrarBascula(bascula)
end

CollectionService:GetInstanceAddedSignal(TAG_PUERTA_NIVEL):Connect(registrarPuerta)
CollectionService:GetInstanceRemovedSignal(TAG_PUERTA_NIVEL):Connect(actualizarTagPuerta)
CollectionService:GetInstanceAddedSignal(TAG_PUERTA_TUTORIAL):Connect(registrarPuerta)
CollectionService:GetInstanceRemovedSignal(TAG_PUERTA_TUTORIAL):Connect(actualizarTagPuerta)
CollectionService:GetInstanceAddedSignal(TAG_PUERTA_ELEVADOR):Connect(registrarPuerta)
CollectionService:GetInstanceRemovedSignal(TAG_PUERTA_ELEVADOR):Connect(actualizarTagPuerta)
CollectionService:GetInstanceAddedSignal(TAG_BASCULA):Connect(registrarBascula)
CollectionService:GetInstanceRemovedSignal(TAG_BASCULA):Connect(quitarBascula)

task.delay(5, function()
	esperaElevadorTerminada = true
	for modelo, estado in pairs(puertas) do
		if estado.esElevador then
			abrirPuerta(modelo)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	for modelo, estado in pairs(puertas) do
		if not estado.abierta or estado.bloqueadaParaSiempre then
			if estado.esTutorial
				and not estado.abierta and not estado.bloqueadaParaSiempre then
				local centro = modelo:GetPivot().Position
				for _, jugador in ipairs(Players:GetPlayers()) do
					local character = jugador.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - centro).Magnitude < DISTANCIA_APERTURA_TUTORIAL then
						abrirPuerta(modelo, jugador)
						break
					end
				end
			end
			continue
		end
		if not estado.seCierraAlCruzar then
			continue
		end

		local pivot = estado.pivotAlAbrir or modelo:GetPivot()
		for _, jugador in ipairs(Players:GetPlayers()) do
			local character = jugador.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local ladoActual = math.sign((hrp.Position - pivot.Position):Dot(pivot.LookVector))
				local ladoInicial = estado.ladosIniciales[jugador]
				if ladoInicial == nil then
					if ladoActual ~= 0 then
						estado.ladosIniciales[jugador] = ladoActual
					end
				elseif ladoActual ~= 0 and ladoActual ~= ladoInicial
					and (hrp.Position - pivot.Position).Magnitude > DISTANCIA_CIERRE_TRAS_CRUCE then
					bloquearDespuesDeCruzar(modelo)
					break
				end
			end
		end
	end
end)
