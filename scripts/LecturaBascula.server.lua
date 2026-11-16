--[=[
	Script: dentro de la Part "Pantalla".
	Necesita un SurfaceGui con un TextLabel llamado "Lectura".
	Si existe un ObjectValue "Receptor" con Value asignado, usa ese objetivo.
	Si no, puede encontrarlo automáticamente cuando solo hay un BasculaReceptor.
]=]

local CollectionService = game:GetService("CollectionService")

local pantalla = script.Parent
local lectura = pantalla:FindFirstChild("Lectura", true)
if not lectura or not lectura:IsA("TextLabel") then
	warn("LecturaBascula: no encontré un TextLabel llamado 'Lectura' dentro de Pantalla")
	return
end

lectura.Text = "--%"

local referencia = pantalla:FindFirstChild("Receptor")
local receptor = referencia and referencia:IsA("ObjectValue") and referencia.Value

if not receptor then
	local receptores = CollectionService:GetTagged("BasculaReceptor")
	if #receptores == 1 then
		receptor = receptores[1]
		print("LecturaBascula: encontré automáticamente", receptor:GetFullName())
	elseif #receptores == 0 then
		warn("LecturaBascula: no hay ningún objeto con el tag BasculaReceptor")
		lectura.Text = "NO RECEPTOR"
		return
	else
		warn("LecturaBascula: hay varias básculas; asigna Pantalla > Receptor (ObjectValue) > Value")
		lectura.Text = "ELIGE RECEPTOR"
		return
	end
end

if not CollectionService:HasTag(receptor, "BasculaReceptor") then
	warn("LecturaBascula: Receptor.Value no tiene el tag BasculaReceptor")
	lectura.Text = "RECEPTOR INVALIDO"
	return
end

print("LecturaBascula: leyendo", receptor:GetFullName())

local DURACION_CURVA = 0.65 -- segundos; cambia esto para alargar/acortar la subida
local porcentajeMostrado = receptor:GetAttribute("PorcentajeRegistrado") or 0
local animacionActual = 0

local function dibujarLectura(porcentaje)
	local bloqueada = receptor:GetAttribute("Bloqueada") == true
	lectura.Text = string.format("%.2f%%", porcentaje)
	if bloqueada then
		lectura.Text = lectura.Text .. "  LOCK"
	end
end

local function actualizarLectura()
	local objetivo = receptor:GetAttribute("PorcentajeRegistrado") or 0
	animacionActual += 1
	local estaAnimacion = animacionActual
	-- Anima tanto la subida al colocar objetos como la bajada al retirarlos.
	local inicio = receptor:GetAttribute("PorcentajeBase")
	if typeof(inicio) ~= "number" then
		inicio = porcentajeMostrado
	end
	inicio = math.clamp(inicio, 0, 100)
	porcentajeMostrado = inicio
	dibujarLectura(porcentajeMostrado)

	task.spawn(function()
		local tiempoInicio = os.clock()
		while animacionActual == estaAnimacion do
			local alpha = math.clamp((os.clock() - tiempoInicio) / DURACION_CURVA, 0, 1)
			local curva = alpha * alpha * (3 - 2 * alpha) -- Smoothstep
			porcentajeMostrado = inicio + (objetivo - inicio) * curva
			dibujarLectura(porcentajeMostrado)
			if alpha >= 1 then
				break
			end
			task.wait()
		end
	end)
end

receptor:GetAttributeChangedSignal("PorcentajeRegistrado"):Connect(actualizarLectura)
receptor:GetAttributeChangedSignal("Bloqueada"):Connect(function()
	dibujarLectura(porcentajeMostrado)
end)
actualizarLectura()
