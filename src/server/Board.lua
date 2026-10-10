-- 알까기 판 만들기 : 모양(사각형·육각형·호리병) × 크기 × 바닥(나무·얼음·화산·울퉁불퉁)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BoardShape = require(Shared:WaitForChild("BoardShape"))

local Board = {}

-- 지금 판 설정 (다른 모듈이 판 밖 판정·배치·마찰 계산에 쓴다)
Board.setup = BoardShape.makeSetup(Config, Config.DefaultBoardSize, Config.DefaultFloor, Config.DefaultTeamCount)
Board.shape = Board.setup.shape

local function floorInfo()
	return Config.Floors[Board.setup.floorKey]
end

local function makeSlab(name: string, size: Vector3, cframe: CFrame, parent: Instance, shapeType: Enum.PartType?)
	local floor = floorInfo()
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shapeType or Enum.PartType.Block
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = floor.Color
	part.Material = (Enum.Material :: any)[floor.Material] or Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties =
		PhysicalProperties.new(0.7, Board.setup.friction, 0.2, Board.setup.frictionWeight, 1)
	part.Parent = parent
	return part
end

-- 판 위에 그리는 것 (부딪히지 않음)
local function makeDecal(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, shapeType: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shapeType or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- 가운데 용암 구멍 (화산). 판 밖 판정은 BoardShape 가 하고, 여기는 보이는 것만.
local function makeLava(radius: number, parent: Instance)
	local y = Config.BoardHeight + 0.03
	local lava = makeDecal(
		"Lava",
		Vector3.new(0.1, radius * 2, radius * 2),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 90, 20),
		parent,
		Enum.PartType.Cylinder
	)
	lava.Material = Enum.Material.Neon
	local rim = makeDecal(
		"LavaRim",
		Vector3.new(0.08, radius * 2 + 1.2, radius * 2 + 1.2),
		CFrame.new(0, y - 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 25, 20),
		parent,
		Enum.PartType.Cylinder
	)
	rim.Material = Enum.Material.Slate
	local fire = Instance.new("Fire")
	fire.Size = radius * 1.5
	fire.Heat = 8
	fire.Parent = lava
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = radius * 4
	light.Brightness = 2
	light.Parent = lava
end

function Board.build(teamCount: number, sizeKey: string?, floorKey: string?): Model
	local old = workspace:FindFirstChild("Board")
	if old then
		old:Destroy()
	end
	Board.setup = BoardShape.makeSetup(Config, sizeKey or Config.DefaultBoardSize, floorKey or Config.DefaultFloor, teamCount)
	Board.shape = Board.setup.shape
	local shape = Board.shape

	local board = Instance.new("Model")
	board.Name = "Board"
	local y = Config.BoardHeight - Config.BoardThickness / 2
	local size = shape.size
	if shape.kind == "Hexagon" then
		-- 직사각형 3개를 60도씩 돌려 겹치면 정육각형
		local side = size / math.sqrt(3)
		for index = 0, 2 do
			local cframe = CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(index * 60), 0)
			makeSlab("Slab" .. index, Vector3.new(side, Config.BoardThickness, size), cframe, board)
		end
	elseif shape.kind == "Gourd" then
		-- 둥근 판 두 개를 겹쳐 놓으면 가운데가 잘록한 호리병
		for index, circle in shape.circles :: { BoardShape.Circle } do
			local cframe = CFrame.new(circle.x, y, circle.z) * CFrame.Angles(0, 0, math.rad(90))
			makeSlab("Lobe" .. index, Vector3.new(Config.BoardThickness, circle.r * 2, circle.r * 2), cframe, board, Enum.PartType.Cylinder)
		end
	else
		makeSlab("Slab", Vector3.new(size, Config.BoardThickness, size), CFrame.new(0, y, 0), board)
	end

	if shape.holeRadius > 0 then
		makeLava(shape.holeRadius, board)
	end

	-- 팀 사이 경계선 : 가운데(구멍 밖)에서 판 끝 조금 앞까지
	local lineY = Config.BoardHeight + 0.025
	for team = 1, teamCount do
		local angle = (team - 0.5) * 2 * math.pi / teamCount
		local dx, dz = math.sin(angle), math.cos(angle)
		local start = shape.holeRadius + 1
		local reach = BoardShape.distanceToEdge(shape, dx * start, dz * start, dx, dz)
		local length = math.max(reach * 0.9, 1)
		local direction = Vector3.new(dx, 0, dz)
		local middle = Vector3.new(0, lineY, 0) + direction * (start + length / 2)
		makeDecal("Line", Vector3.new(0.3, 0.05, length), CFrame.lookAt(middle, middle + direction), Color3.new(1, 1, 1), board)
	end

	board.Parent = workspace
	return board
end

-- 울퉁불퉁 바닥 : 알을 놓은 뒤에 빈 자리에 혹을 심는다 (판 밑에 공을 묻어서 위만 솟게)
function Board.addBumps(piecesFolder: Instance)
	local floor = floorInfo()
	local board = workspace:FindFirstChild("Board")
	if not floor.BumpCount or not board then
		return
	end
	local shape = Board.shape
	local random = Random.new()
	local placed = 0
	local tries = 0
	local spots: { Vector3 } = {}
	while placed < floor.BumpCount and tries < floor.BumpCount * 40 do
		tries += 1
		local x = random:NextNumber(-shape.reach, shape.reach)
		local z = random:NextNumber(-shape.reach, shape.reach)
		local ok = BoardShape.inside(shape, x, z, floor.BumpRadius + 1)
		if ok then
			-- 알과 다른 혹에서 떨어뜨린다
			for _, piece in piecesFolder:GetChildren() do
				if piece:IsA("BasePart") then
					local gap = Vector3.new(piece.Position.X - x, 0, piece.Position.Z - z).Magnitude
					if gap < piece.Size.Y / 2 + floor.BumpRadius + 1.5 then
						ok = false
						break
					end
				end
			end
			for _, spot in spots do
				if (spot - Vector3.new(x, 0, z)).Magnitude < floor.BumpRadius * 2.5 then
					ok = false
					break
				end
			end
		end
		if ok then
			placed += 1
			table.insert(spots, Vector3.new(x, 0, z))
			local bump = Instance.new("Part")
			bump.Name = "Bump"
			bump.Shape = Enum.PartType.Ball
			bump.Anchored = true
			bump.CanQuery = false
			bump.Size = Vector3.one * floor.BumpRadius * 2
			bump.Position = Vector3.new(x, Config.BoardHeight - floor.BumpRadius + floor.BumpHeight, z)
			bump.Color = floor.Color:Lerp(Color3.new(0, 0, 0), 0.25)
			bump.Material = Enum.Material.Rock
			bump.CustomPhysicalProperties = PhysicalProperties.new(0.7, Board.setup.friction, 0.3, 1, 1)
			bump.Parent = board
		end
	end
end

return Board
