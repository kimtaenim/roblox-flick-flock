-- 똥알 : 내 알이 똥 모양이 된다 (상대 턴 한 번 동안).
-- 상대 알이 뚫고 지나가며 똥을 밟아 확 느려지고 발자국이 남는다.
-- 똥알은 밀리지 않는다 (다른 알과 안 부딪힘).
local Ability = {}

local POOP_COLOR = Color3.fromRGB(120, 72, 30)
local POOP_DARK = Color3.fromRGB(95, 55, 20)

local function makeBall(name: string, size: number, color: Color3, position: Vector3, piece: BasePart, folder: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Position = position
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = piece
	weld.Part1 = part
	weld.Parent = part
end

-- 아래가 넓고 위로 갈수록 좁아지는 똥 (공 4개 + 눈)
local function buildPoop(piece: BasePart, context)
	-- 이미 똥이면 (여러 번 쓸 때) 새로 만든다
	local old = piece:FindFirstChild("PoopLook")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "PoopLook"

	local radius = context.PieceFactory.radius(piece)
	local bottom = piece.Position.Y - context.PieceFactory.halfHeight(piece)
	local x, z = piece.Position.X, piece.Position.Z
	local layers = {
		{ size = radius * 2.3, height = radius * 0.55, shift = 0 },
		{ size = radius * 1.75, height = radius * 1.35, shift = 0.15 },
		{ size = radius * 1.2, height = radius * 2.0, shift = -0.1 },
		{ size = radius * 0.6, height = radius * 2.55, shift = 0.2 },
	}
	for index, layer in layers do
		local color = if index % 2 == 0 then POOP_DARK else POOP_COLOR
		makeBall("Poop" .. index, layer.size, color, Vector3.new(x + layer.shift * radius, bottom + layer.height, z), piece, folder)
	end

	-- 눈 (상대 쪽을 본다)
	local forward = context.PieceFactory.forward(piece)
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local eyeY = bottom + radius * 1.45
	local eyeSize = radius * 0.4
	for _, sign in { -1, 1 } do
		local eye = Vector3.new(x, eyeY, z) + side * sign * radius * 0.32 + forward * radius * 0.78
		makeBall("Eye", eyeSize, Color3.new(1, 1, 1), eye, piece, folder)
		makeBall("Pupil", eyeSize * 0.5, Color3.new(0.05, 0.05, 0.05), eye + forward * eyeSize * 0.3, piece, folder)
	end

	folder.Parent = piece
end

function Ability.Execute(piece: BasePart, context)
	piece.AssemblyLinearVelocity = Vector3.zero
	piece.AssemblyAngularVelocity = Vector3.zero
	piece.CollisionGroup = context.GHOST_GROUP
	context.PieceFactory.setTransparency(piece, 1)
	buildPoop(piece, context)
	context.startEffect(piece, "Poop")
end

function Ability.OnTurnEnd(piece: BasePart)
	local PieceFactory = require(script.Parent.Parent:WaitForChild("PieceFactory"))
	local poopLook = piece:FindFirstChild("PoopLook")
	if poopLook then
		poopLook:Destroy()
	end
	PieceFactory.setTransparency(piece, 0)
	piece.CollisionGroup = PieceFactory.COLLISION_GROUP
end

return Ability
