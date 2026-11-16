--[=[
	ModuleScript: ServerStorage > DatosJuego
	Mantiene el estado actual de cada receptor durante esta sesión del servidor.
]=]

local DatosJuego = {}
local estados = {}

local function obtenerInterno(bascula)
	assert(typeof(bascula) == "Instance", "La báscula debe ser una Instance")
	local estado = estados[bascula]
	if not estado then
		estado = {
			PorcentajeRegistrado = 0,
			Bloqueada = false,
		}
		estados[bascula] = estado
		bascula:SetAttribute("PorcentajeRegistrado", estado.PorcentajeRegistrado)
		bascula:SetAttribute("Bloqueada", estado.Bloqueada)
		bascula:SetAttribute("PorcentajeBase", 0)
	end
	return estado
end

function DatosJuego.ObtenerEstado(bascula)
	local estado = obtenerInterno(bascula)
	return {
		PorcentajeRegistrado = estado.PorcentajeRegistrado,
		Bloqueada = estado.Bloqueada,
	}
end

-- Establece el total actualmente apoyado en la báscula y el estado de su umbral.
function DatosJuego.EstablecerEstado(bascula, porcentaje, requisito)
	local estado = obtenerInterno(bascula)
	if estado.Bloqueada then
		return DatosJuego.ObtenerEstado(bascula)
	end

	estado.PorcentajeRegistrado = math.clamp(porcentaje, 0, 100)
	if estado.PorcentajeRegistrado >= requisito then
		estado.Bloqueada = true -- Latch: no vuelve a false durante esta sesión.
	end
	bascula:SetAttribute("PorcentajeRegistrado", estado.PorcentajeRegistrado)
	bascula:SetAttribute("Bloqueada", estado.Bloqueada)
	return DatosJuego.ObtenerEstado(bascula)
end

return DatosJuego
