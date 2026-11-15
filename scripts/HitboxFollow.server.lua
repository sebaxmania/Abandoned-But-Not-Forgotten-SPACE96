--[=[
	HitboxFollow.server.lua
	Pon este Script dentro del bloque padre o dentro de la pieza "hitbox".
	La hitbox copia la posición y rotación del bloque cada frame de física.
]=]

local RunService = game:GetService("RunService")

local scriptParent = script.Parent
local container
local hitbox

if scriptParent:IsA("BasePart") and scriptParent.Name == "hitbox" then
	hitbox = scriptParent
	container = hitbox.Parent
else
	container = scriptParent
	hitbox = container:WaitForChild("hitbox")
end

assert(hitbox:IsA("BasePart"), '"hitbox" debe ser una Part, MeshPart u otra BasePart')

local blockPart
if container:IsA("BasePart") then
	blockPart = container
elseif container:IsA("Model") then
	blockPart = container.PrimaryPart
	if not blockPart then
		for _, descendant in container:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= hitbox then
				blockPart = descendant
				break
			end
		end
	end
end

assert(blockPart and blockPart ~= hitbox,
	"HitboxFollow: el objeto debe tener una pieza BasePart aparte de hitbox")

-- Borra la soldadura que creaba la versión anterior de este script.
for _, descendant in container:GetDescendants() do
	if descendant:IsA("WeldConstraint") and descendant.Name == "HitboxWeld" then
		local connectsTheseParts =
			(descendant.Part0 == blockPart and descendant.Part1 == hitbox)
			or (descendant.Part1 == blockPart and descendant.Part0 == hitbox)
		if connectsTheseParts then
			descendant:Destroy()
		end
	end
end

hitbox.Anchored = true
hitbox.CanCollide = false
hitbox.CanTouch = true
hitbox.CanQuery = true
hitbox.Massless = true

local function followBlock()
	if hitbox.Parent and blockPart.Parent then
		hitbox.CFrame = blockPart.CFrame
	end
end

followBlock()
RunService.Heartbeat:Connect(followBlock)
