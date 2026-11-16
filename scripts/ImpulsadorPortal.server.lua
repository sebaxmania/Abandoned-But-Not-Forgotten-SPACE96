--[=[
	Script: ServerScriptService > ImpulsadorPortal.server.lua

	Lanza objetos con el Tag "ObjetoPesado" al tocar una placa con el Tag
	"ImpulsadorPortal". Las placas deben ser Part/MeshPart.
	Attributes numéricos por placa: FuerzaAdelante y FuerzaArriba.
]=]

local CollectionService = game:GetService("CollectionService")

local TAG_IMPULSADOR = "ImpulsadorPortal"
local TAG_OBJETO = "ObjetoPesado"
local FUERZA_ADELANTE_DEFAULT = 90
local FUERZA_ARRIBA_DEFAULT = 75
local COOLDOWN = 0.35

local conexiones = {}
local ultimaActivacion = {}

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

local function conectarPlaca(placa)
	if conexiones[placa] or not placa:IsA("BasePart") then
		return
	end
	conexiones[placa] = true
	placa.CanTouch = true

	placa.Touched:Connect(function(parteTocada)
		local objeto = buscarObjetoPesado(parteTocada)
		if not objeto then
			return
		end
		local raiz = buscarRaiz(objeto)
		if not raiz or raiz.Anchored then
			return
		end

		local ahora = os.clock()
		local porPlaca = ultimaActivacion[placa]
		if not porPlaca then
			porPlaca = {}
			ultimaActivacion[placa] = porPlaca
		end
		if ahora - (porPlaca[objeto] or 0) < COOLDOWN then
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

		porPlaca[objeto] = ahora
		local direccion = placa.CFrame.LookVector
		-- Deja el lanzamiento del bloque bajo autoridad del servidor,
		-- incluso si otro sistema le había asignado un network owner.
		pcall(function()
			raiz:SetNetworkOwner(nil)
		end)
		raiz.AssemblyLinearVelocity = direccion * adelante + Vector3.new(0, arriba, 0)
	end)
end

for _, placa in CollectionService:GetTagged(TAG_IMPULSADOR) do
	conectarPlaca(placa)
end
CollectionService:GetInstanceAddedSignal(TAG_IMPULSADOR):Connect(conectarPlaca)
