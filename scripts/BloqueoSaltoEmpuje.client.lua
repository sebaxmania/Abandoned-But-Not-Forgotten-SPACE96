--[=[
	LocalScript: StarterPlayer > StarterPlayerScripts > BloqueoSaltoEmpuje
	Desactiva el estado Jumping solo mientras el servidor marca que se empuja
	un objeto con Tag ObjetoPesado.
]=]
local Players = game:GetService("Players")
local jugador = Players.LocalPlayer
local humanoid
local estadoSaltoOriginal
local saltoDesactivadoPorEsteScript = false
local atributoConexion
local saltoConexion

local function actualizarSalto()
	if not humanoid or not humanoid.Parent then return end
	local empujando = jugador:GetAttribute("EmpujandoBloquePesado") == true
	if empujando and not saltoDesactivadoPorEsteScript then
		estadoSaltoOriginal = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
		saltoDesactivadoPorEsteScript = true
		humanoid.Jump = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	elseif not empujando and saltoDesactivadoPorEsteScript then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, estadoSaltoOriginal)
		saltoDesactivadoPorEsteScript = false
	end
end

local function asignarPersonaje(personaje)
	if atributoConexion then atributoConexion:Disconnect() end
	if saltoConexion then saltoConexion:Disconnect() end
	if humanoid and saltoDesactivadoPorEsteScript and humanoid.Parent then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, estadoSaltoOriginal)
	end

	humanoid = personaje:WaitForChild("Humanoid")
	saltoDesactivadoPorEsteScript = false
	atributoConexion = jugador:GetAttributeChangedSignal("EmpujandoBloquePesado"):Connect(actualizarSalto)
	saltoConexion = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if jugador:GetAttribute("EmpujandoBloquePesado") == true and humanoid.Jump then
			humanoid.Jump = false
		end
	end)
	actualizarSalto()
end

jugador.CharacterAdded:Connect(asignarPersonaje)
if jugador.Character then
	asignarPersonaje(jugador.Character)
end
