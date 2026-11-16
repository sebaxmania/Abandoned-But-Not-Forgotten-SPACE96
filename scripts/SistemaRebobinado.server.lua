--[=[
	Script: ServerScriptService > SistemaRebobinado.server.lua
	Tag: ZonaSala en cada BasePart de zona; Attribute Number NumeroSala.
	Usa solapamiento para saber si el jugador sigue dentro, sin depender de TouchEnded.
]=]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DatosRebobinado = require(ServerStorage:WaitForChild("DatosRebobinado"))
local TAG_ZONA = "ZonaSala"
local INTERVALO_DETECCION = 0.1
local parametros = OverlapParams.new()
parametros.FilterType = Enum.RaycastFilterType.Include
parametros.RespectCanCollide = false

local zonaActualPorJugador = {}
local tiempoDeteccion = 0

local function iniciarJugador(jugador)
	DatosRebobinado.IniciarJugador(jugador)
	jugador.CharacterRemoving:Connect(function()
		zonaActualPorJugador[jugador] = nil
		DatosRebobinado.EstablecerSalaActual(jugador, nil)
	end)
end

Players.PlayerAdded:Connect(iniciarJugador)
Players.PlayerRemoving:Connect(function(jugador)
	zonaActualPorJugador[jugador] = nil
	DatosRebobinado.QuitarJugador(jugador)
end)
for _, jugador in Players:GetPlayers() do iniciarJugador(jugador) end

local function detectarZona(jugador)
	local personaje = jugador.Character
	if not personaje then
		zonaActualPorJugador[jugador] = nil
		DatosRebobinado.EstablecerSalaActual(jugador, nil)
		return
	end

	parametros.FilterDescendantsInstances = { personaje }
	local zonaElegida = nil
	local numeroElegido = nil
	local zonaAnterior = zonaActualPorJugador[jugador]

	for _, zona in CollectionService:GetTagged(TAG_ZONA) do
		if zona:IsA("BasePart") and zona:IsDescendantOf(workspace) then
			local numeroSala = zona:GetAttribute("NumeroSala")
			if typeof(numeroSala) == "number" then
				zona.CanQuery = true
				local partes = workspace:GetPartsInPart(zona, parametros)
				if #partes > 0 then
					if zona == zonaAnterior then
						zonaElegida, numeroElegido = zona, numeroSala
						break
					elseif not zonaElegida then
						zonaElegida, numeroElegido = zona, numeroSala
					end
				end
			end
		end
	end

	zonaActualPorJugador[jugador] = zonaElegida
	DatosRebobinado.EstablecerSalaActual(jugador, numeroElegido)
end

RunService.Heartbeat:Connect(function(dt)
	for _, jugador in Players:GetPlayers() do
		DatosRebobinado.Actualizar(jugador, dt)
	end
	tiempoDeteccion += dt
	if tiempoDeteccion >= INTERVALO_DETECCION then
		tiempoDeteccion %= INTERVALO_DETECCION
		for _, jugador in Players:GetPlayers() do
			detectarZona(jugador)
		end
	end
end)
