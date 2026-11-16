--[=[
	Script: StarterPlayer > StarterPlayerScripts > TrampolinJugador.client.lua

	Pon el Tag "Trampolin" en cada Part/MeshPart que sea trampolín.
	El cliente aplica el rebote al personaje local para que responda al instante.
]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local jugador = Players.LocalPlayer
local TAG_TRAMPOLIN = "Trampolin"
local VELOCIDAD_MINIMA_CAIDA = 10
local MULTIPLICADOR_INICIAL = 1.35
local PERDIDA_POR_REBOTE = 0.15
local MULTIPLICADOR_MINIMO = 0.5
local IMPULSO_MINIMO_PRIMER_REBOTE = 60
local COOLDOWN_REBOTE = 0.25

local rebotesConsecutivos = 0
local ultimoRebote = 0
local conectado = {}
local personajeActual
local humanoidActual
local rootActual

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

local function prepararTrampolin(instancia)
	if conectado[instancia] or not instancia:IsA("BasePart") then
		return
	end
	conectado[instancia] = true
	instancia.Touched:Connect(function(parteTocada)
		if not personajeActual or not parteTocada:IsDescendantOf(personajeActual) then
			return
		end
		if not humanoidActual or humanoidActual.Health <= 0 or not rootActual then
			return
		end

		local ahora = os.clock()
		if ahora - ultimoRebote < COOLDOWN_REBOTE then
			return
		end

		local velocidad = rootActual.AssemblyLinearVelocity
		local velocidadCaida = -velocidad.Y
		if velocidadCaida <= VELOCIDAD_MINIMA_CAIDA then
			return
		end

		local multiplicador = math.max(
			MULTIPLICADOR_MINIMO,
			MULTIPLICADOR_INICIAL - PERDIDA_POR_REBOTE * rebotesConsecutivos
		)
		local velocidadRebote = velocidadCaida * multiplicador
		if rebotesConsecutivos == 0 then
			velocidadRebote = math.max(IMPULSO_MINIMO_PRIMER_REBOTE, velocidadRebote)
		end

		rebotesConsecutivos += 1
		ultimoRebote = ahora
		rootActual.AssemblyLinearVelocity = Vector3.new(velocidad.X, velocidadRebote, velocidad.Z)
		humanoidActual:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
end

local function asignarPersonaje(personaje)
	personajeActual = personaje
	humanoidActual = personaje:WaitForChild("Humanoid")
	rootActual = personaje:WaitForChild("HumanoidRootPart")
	rebotesConsecutivos = 0
	ultimoRebote = 0
end

for _, trampolin in CollectionService:GetTagged(TAG_TRAMPOLIN) do
	prepararTrampolin(trampolin)
end
CollectionService:GetInstanceAddedSignal(TAG_TRAMPOLIN):Connect(prepararTrampolin)

jugador.CharacterAdded:Connect(asignarPersonaje)
if jugador.Character then
	asignarPersonaje(jugador.Character)
end

-- Reinicia la pérdida de energía al pisar suelo normal.
local parametros = RaycastParams.new()
parametros.FilterType = Enum.RaycastFilterType.Exclude
RunService.Heartbeat:Connect(function()
	if not personajeActual or not humanoidActual or not rootActual then
		return
	end
	if humanoidActual.FloorMaterial == Enum.Material.Air then
		return
	end

	parametros.FilterDescendantsInstances = { personajeActual }
	local resultado = workspace:Raycast(rootActual.Position, Vector3.new(0, -5, 0), parametros)
	if resultado and not esTrampolin(resultado.Instance) then
		rebotesConsecutivos = 0
	end
end)
