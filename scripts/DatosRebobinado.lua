--[=[ ModuleScript: ServerStorage > DatosRebobinado ]=]
local DatosRebobinado = {}
local sesiones = {}

local function publicarDatos(jugador, sesion)
	local total = 0
	for numeroSala, tiempo in sesion.tiemposPorSala do
		total += tiempo
		jugador:SetAttribute("TiempoSala_" .. tostring(numeroSala), math.floor(tiempo))
	end
	local limite = math.clamp(math.floor((180 * total) / (total + 60)), 60, 179)
	jugador:SetAttribute("TiempoTotalSegundos", math.floor(total))
	jugador:SetAttribute("TiempoLimiteRebobinado", limite)
	sesion.tiempoTotal = total
	sesion.tiempoLimite = limite
end

function DatosRebobinado.IniciarJugador(jugador)
	sesiones[jugador] = {
		tiemposPorSala = {}, salaActual = nil, tiempoTotal = 0,
		tiempoLimite = 60, tiempoDesdePublicacion = 0,
	}
	jugador:SetAttribute("NumeroSalaActual", nil)
	jugador:SetAttribute("EstaEnZona", false)
	jugador:SetAttribute("TiempoTotalSegundos", 0)
	jugador:SetAttribute("TiempoLimiteRebobinado", 60)
end

function DatosRebobinado.EstablecerSalaActual(jugador, numeroSala)
	local sesion = sesiones[jugador]
	if not sesion then return end
	local cambio = sesion.salaActual ~= numeroSala
	sesion.salaActual = numeroSala
	jugador:SetAttribute("NumeroSalaActual", numeroSala)
	jugador:SetAttribute("EstaEnZona", numeroSala ~= nil)
	if numeroSala ~= nil and sesion.tiemposPorSala[numeroSala] == nil then
		sesion.tiemposPorSala[numeroSala] = 0
	end
	if cambio then publicarDatos(jugador, sesion) end
end

function DatosRebobinado.Actualizar(jugador, dt)
	local sesion = sesiones[jugador]
	if not sesion or sesion.salaActual == nil then return end
	local numeroSala = sesion.salaActual
	sesion.tiemposPorSala[numeroSala] = (sesion.tiemposPorSala[numeroSala] or 0) + dt
	sesion.tiempoDesdePublicacion += dt
	if sesion.tiempoDesdePublicacion >= 1 then
		sesion.tiempoDesdePublicacion %= 1
		publicarDatos(jugador, sesion)
	end
end

function DatosRebobinado.ObtenerDatos(jugador)
	local sesion = sesiones[jugador]
	if not sesion then return nil end
	return {
		TiemposPorSala = table.clone(sesion.tiemposPorSala),
		TiempoTotalSegundos = sesion.tiempoTotal,
		TiempoLimiteRebobinado = sesion.tiempoLimite,
	}
end

function DatosRebobinado.QuitarJugador(jugador)
	sesiones[jugador] = nil
end

return DatosRebobinado
