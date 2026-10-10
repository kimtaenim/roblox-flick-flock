-- 알 만들기. 모든 알은 Config.Pieces 의 다섯 값으로 만든다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AbilityList = require(Shared:WaitForChild("AbilityList"))
local TeamLayout = require(Shared:WaitForChild("TeamLayout"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PieceFactory = {}

PieceFactory.COLLISION_GROUP = "Pieces"

-- 모든 알은 몸통(물리)이 납작한 원기둥이다. 둥근 알은 그 위에 볼록한 겉모양을 씌운다.
-- 알 크기 (스터드) : (높이, 지름)
local function dimensions(kind: string, scale: number): (number, number)
	local info = Config.Pieces[kind]
	local diameter = Config.PieceDiameter * info.size * scale
	local height = if info.shape == "Flat" then Config.FlatHeight else Config.RoundHeight
	return height * info.size * scale, diameter
end

-- 알 반지름
function PieceFactory.radius(piece: BasePart): number
	return piece.Size.Y / 2
end

local function isRound(piece: BasePart): boolean
	local info = Config.Pieces[piece:GetAttribute("Kind") :: string]
	return info ~= nil and info.shape == "Round"
end

-- 알 높이의 절반 (바닥에서 가운데까지). 원기둥은 X축이 높이.
function PieceFactory.halfHeight(piece: BasePart): number
	return piece.Size.X / 2
end

-- 때린 알의 질량 계수 (데미지 계산용)
function PieceFactory.massFactor(piece: BasePart): number
	local info = Config.Pieces[piece:GetAttribute("Kind") :: string]
	local scale = (piece:GetAttribute("MassScale") :: number?) or 1
	return (if info then info.mass else 1) * scale
end

local function setPhysics(piece: BasePart, kind: string, massScale: number, elasticity: number?)
	local info = Config.Pieces[kind]
	local volume = math.pi * (piece.Size.Y / 2) ^ 2 * piece.Size.X
	-- 질량이 Config 값과 같도록 밀도를 맞춘다
	local density = math.clamp(info.mass * Config.MassUnit * massScale / volume, 0.01, 100)
	local bounce = elasticity or info.bounce
	-- 튕김이 크게 바뀐 알(자석)은 상대 알보다 튕김 비중을 크게
	local bounceWeight = if elasticity then 100 else 1
	piece.CustomPhysicalProperties = PhysicalProperties.new(density, info.friction, bounce, 1, bounceWeight)
end

function PieceFactory.setElasticity(piece: BasePart, elasticity: number?)
	setPhysics(piece, piece:GetAttribute("Kind") :: string, (piece:GetAttribute("MassScale") :: number?) or 1, elasticity)
end

-- 눈에 보이는 몸통 파트들 (둥근 알은 겉모양, 납작 알은 자기 자신)
function PieceFactory.bodyParts(piece: BasePart): { BasePart }
	local look = piece:FindFirstChild("Look")
	local body = look and look:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		return { body }
	end
	return { piece }
end

-- 알 전체 투명도 (유령·똥알에서 씀). 0 = 보통, 1 = 안 보임
function PieceFactory.setTransparency(piece: BasePart, transparency: number)
	piece.Transparency = if isRound(piece) then 1 else transparency
	local look = piece:FindFirstChild("Look")
	if look then
		for _, part in look:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = transparency
			end
		end
	end
end

local function makeDecoration(name: string, size: Vector3, color: Color3, cframe: CFrame, piece: BasePart, folder: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = cframe
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

-- 알이 보는 방향 (판 가운데 쪽)
function PieceFactory.forward(piece: BasePart): Vector3
	local team = (piece:GetAttribute("Team") :: number?) or 1
	local teamCount = (Remotes.State:GetAttribute("TeamCount") :: number?) or 2
	local x, z = TeamLayout.direction(team, teamCount)
	return Vector3.new(-x, 0, -z)
end

-- 눈·왕관 붙이기 (새알 콘셉트). 크기가 바뀌면 다시 붙인다.
function PieceFactory.decorate(piece: BasePart)
	local old = piece:FindFirstChild("Look")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Look"

	-- 판 가운데 쪽을 본다
	local forward = PieceFactory.forward(piece)
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local up = Vector3.yAxis
	local radius = PieceFactory.radius(piece)
	local center = piece.Position

	local height = PieceFactory.halfHeight(piece) * 2
	local eyeBase
	if isRound(piece) then
		-- 볼록한 겉모양 (공 모양 메시를 납작하게 눌러서)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(radius * 2, height, radius * 2)
		body.CFrame = CFrame.new(center)
		body.Color = piece.Color
		body.Material = Enum.Material.SmoothPlastic
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.Massless = true
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		body.Parent = folder
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = piece
		weld.Part1 = body
		weld.Parent = body
		eyeBase = center + up * height * 0.28 + forward * radius * 0.62
	else
		eyeBase = center + up * height / 2 + forward * radius * 0.45
	end
	local eyeSize = radius * 0.45
	for _, sign in { -1, 1 } do
		local eyeCenter = eyeBase + side * sign * radius * 0.32
		makeDecoration("Eye", Vector3.one * eyeSize, Color3.new(1, 1, 1), CFrame.new(eyeCenter), piece, folder)
		makeDecoration(
			"Pupil",
			Vector3.one * eyeSize * 0.5,
			Color3.new(0.05, 0.05, 0.05),
			CFrame.new(eyeCenter + forward * eyeSize * 0.3 + up * eyeSize * 0.15),
			piece,
			folder
		)
	end

	if piece:GetAttribute("Kind") == "King" then
		local crownSize = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5)
		makeDecoration(
			"Crown",
			crownSize,
			Color3.fromRGB(255, 205, 40),
			CFrame.new(center + up * (PieceFactory.halfHeight(piece) + crownSize.Y * 0.3)),
			piece,
			folder
		)
	end

	folder.Parent = piece
end

-- 왕알 HP 막대
local function addHpBar(piece: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = back

	local function refresh()
		local hp = piece:GetAttribute("Hp") or 0
		local maxHp = piece:GetAttribute("MaxHp") or 1
		local ratio = math.clamp(hp / maxHp, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60):Lerp(Color3.fromRGB(80, 220, 90), ratio)
		label.Text = "HP " .. math.ceil(hp)
	end
	piece:GetAttributeChangedSignal("Hp"):Connect(refresh)
	refresh()

	gui.Parent = piece
end

-- 능력 알 표시 (아이콘 + 이름)
function PieceFactory.refreshAbilityTag(piece: BasePart)
	local old = piece:FindFirstChild("AbilityTag")
	if old then
		old:Destroy()
	end
	local ability = AbilityList.get(piece:GetAttribute("Ability") :: string?)
	if not ability then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AbilityTag"
	gui.Size = UDim2.fromOffset(90, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ability.Icon .. " " .. ability.Name
	label.Parent = gui
	gui.Parent = piece
end

-- groundPosition : 알 바닥이 놓일 자리
function PieceFactory.create(kind: string, team: number, groundPosition: Vector3, parent: Instance, ability: string?): Part
	local info = Config.Pieces[kind]
	assert(info, "모르는 알 종류: " .. tostring(kind))

	local piece = Instance.new("Part")
	piece.Name = Config.Teams[team].Name .. "_" .. kind
	local height, diameter = dimensions(kind, 1)
	-- 원기둥은 X축이 길이 방향이라 Z축으로 90도 돌려 눕힌다
	piece.Shape = Enum.PartType.Cylinder
	piece.Size = Vector3.new(height, diameter, diameter)
	piece.CFrame = CFrame.new(groundPosition + Vector3.new(0, height / 2 + 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	if info.shape == "Round" then
		piece.Transparency = 1 -- 겉모양(Body)만 보인다
	end

	piece:SetAttribute("Team", team)
	piece:SetAttribute("Kind", kind)
	piece:SetAttribute("MassScale", 1)
	piece:SetAttribute("Hp", info.hp)
	piece:SetAttribute("MaxHp", info.hp)
	piece:SetAttribute("Ability", ability)

	setPhysics(piece, kind, 1, nil)
	piece.Color = Config.Teams[team].Color
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.CollisionGroup = PieceFactory.COLLISION_GROUP

	PieceFactory.decorate(piece)
	if kind == "King" then
		addHpBar(piece)
	end
	PieceFactory.refreshAbilityTag(piece)

	piece.Parent = parent
	-- 물리는 서버가 담당 (클라이언트 소유면 서버에서 속도를 못 바꾼다)
	piece:SetNetworkOwner(nil)
	return piece
end

-- 크기·질량을 scale 배로 (거대화)
function PieceFactory.resize(piece: BasePart, scale: number)
	local kind = piece:GetAttribute("Kind") :: string
	local massScale = ((piece:GetAttribute("MassScale") :: number?) or 1) * scale
	local oldHalf = PieceFactory.halfHeight(piece)
	local bottom = piece.Position - Vector3.new(0, oldHalf, 0)

	piece.Size = piece.Size * scale
	piece:SetAttribute("MassScale", massScale)
	setPhysics(piece, kind, massScale, nil)
	-- 바닥에 파묻히지 않게 위로 올린다 (회전은 그대로)
	local rotation = piece.CFrame - piece.Position
	piece.CFrame = CFrame.new(bottom + Vector3.new(0, PieceFactory.halfHeight(piece) + 0.05, 0)) * rotation
	PieceFactory.decorate(piece)
end

return PieceFactory
