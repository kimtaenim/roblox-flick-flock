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

---------------------------------------------------------------- 무늬

local PATTERN_Y = Config.BoardHeight + 0.02

-- (x1,z1)→(x2,z2) 선을 판 위에 있는 부분만 그린다 (판 모양 밖·구멍은 건너뜀)
local function drawClippedLine(x1: number, z1: number, x2: number, z2: number, width: number, color: Color3, parent: Instance)
	local length = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	if length < 0.01 then
		return
	end
	local dx, dz = (x2 - x1) / length, (z2 - z1) / length
	local step = 0.5
	local spanStart: number? = nil
	local t = 0
	local function finish(spanEnd: number)
		local from = spanStart :: number
		if spanEnd - from > 0.3 then
			local middle = (from + spanEnd) / 2
			local center = Vector3.new(x1 + dx * middle, PATTERN_Y, z1 + dz * middle)
			local direction = Vector3.new(dx, 0, dz)
			makeDecal("PatternLine", Vector3.new(width, 0.04, spanEnd - from), CFrame.lookAt(center, center + direction), color, parent)
		end
		spanStart = nil
	end
	while t <= length do
		local inside = BoardShape.inside(Board.shape, x1 + dx * t, z1 + dz * t, 0.3)
		if inside and not spanStart then
			spanStart = t
		elseif not inside and spanStart then
			finish(t - step)
		end
		t += step
	end
	if spanStart then
		finish(length)
	end
end

local function drawPattern(parent: Instance)
	local floor = floorInfo()
	if not floor.Pattern then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pattern"
	folder.Parent = parent
	local color = floor.PatternColor
	-- 무늬를 그리는 네모 : 사각형 판은 판 전체, 다른 모양은 판을 감싸는 크기
	local half = if Board.shape.kind == "Square" then Board.shape.size / 2 else Board.shape.reach
	if floor.Pattern == "Chess" then
		local cells = floor.Cells
		local cell = half * 2 / cells
		for column = 0, cells - 1 do
			for row = 0, cells - 1 do
				if (column + row) % 2 == 1 then
					local x = -half + (column + 0.5) * cell
					local z = -half + (row + 0.5) * cell
					-- 칸 네 모서리가 다 판 위일 때만
					local h = cell / 2
					local ok = BoardShape.inside(Board.shape, x - h, z - h)
						and BoardShape.inside(Board.shape, x + h, z - h)
						and BoardShape.inside(Board.shape, x - h, z + h)
						and BoardShape.inside(Board.shape, x + h, z + h)
					if ok then
						makeDecal("Square", Vector3.new(cell, 0.04, cell), CFrame.new(x, PATTERN_Y, z), color, folder)
					end
				end
			end
		end
		return
	end

	-- 장기판·바둑판 : 줄 긋기 (가장자리에서 조금 안쪽부터)
	local inner = half * 0.92
	local columns, rows = floor.Lines[1], floor.Lines[2]
	local gapX = inner * 2 / (columns - 1)
	local gapZ = inner * 2 / (rows - 1)
	for column = 0, columns - 1 do
		local x = -inner + column * gapX
		drawClippedLine(x, -inner, x, inner, 0.2, color, folder)
	end
	for row = 0, rows - 1 do
		local z = -inner + row * gapZ
		drawClippedLine(-inner, z, inner, z, 0.2, color, folder)
	end

	if floor.Pattern == "Janggi" then
		-- 궁 : 양쪽 끝 가운데 3×3 칸에 X 자
		for _, sign in { -1, 1 } do
			local zEdge = sign * inner
			local zInner = sign * (inner - 2 * gapZ)
			drawClippedLine(-gapX, zEdge, gapX, zInner, 0.2, color, folder)
			drawClippedLine(gapX, zEdge, -gapX, zInner, 0.2, color, folder)
		end
	elseif floor.Pattern == "Baduk" then
		-- 화점 : 4·10·16 번째 줄이 만나는 9 곳
		for _, column in { 3, 9, 15 } do
			for _, row in { 3, 9, 15 } do
				local x = -inner + column * gapX
				local z = -inner + row * gapZ
				if BoardShape.inside(Board.shape, x, z, 0.6) then
					makeDecal(
						"Star",
						Vector3.new(0.05, 1.1, 1.1),
						CFrame.new(x, PATTERN_Y + 0.01, z) * CFrame.Angles(0, 0, math.rad(90)),
						color,
						folder,
						Enum.PartType.Cylinder
					)
				end
			end
		end
	end
end

-- 곰돌이 얼굴 : 귀 안쪽, 눈, 코, 입 (밟고 지나갈 수 있는 그림)
local function drawBearFace(parent: Instance)
	local circles = Board.shape.circles
	if not circles then
		return
	end
	local face = circles[1]
	local folder = Instance.new("Folder")
	folder.Name = "BearFace"
	folder.Parent = parent
	local y = PATTERN_Y + 0.01
	local function disc(name: string, x: number, z: number, radius: number, color: Color3)
		makeDecal(
			name,
			Vector3.new(0.05, radius * 2, radius * 2),
			CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			folder,
			Enum.PartType.Cylinder
		)
	end
	-- 귀 안쪽 (분홍)
	for index = 2, #circles do
		local ear = circles[index]
		disc("EarInside", ear.x, ear.z, ear.r * 0.55, Color3.fromRGB(240, 170, 170))
	end
	-- 얼굴은 귀 쪽(+X)이 위. 눈·코·입은 얼굴 가운데 둘레에 크게 (알이 다닐 자리를 덜 가리게 얇게)
	local r = face.r
	disc("EyeLeft", face.x + r * 0.35, face.z + r * 0.35, r * 0.09, Color3.fromRGB(50, 35, 25))
	disc("EyeRight", face.x + r * 0.35, face.z - r * 0.35, r * 0.09, Color3.fromRGB(50, 35, 25))
	disc("Muzzle", face.x - r * 0.25, face.z, r * 0.3, Color3.fromRGB(235, 205, 160))
	disc("Nose", face.x - r * 0.12, face.z, r * 0.1, Color3.fromRGB(50, 35, 25))
	disc("Cheek1", face.x - r * 0.1, face.z + r * 0.6, r * 0.12, Color3.fromRGB(245, 160, 150))
	disc("Cheek2", face.x - r * 0.1, face.z - r * 0.6, r * 0.12, Color3.fromRGB(245, 160, 150))
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
	elseif shape.kind == "Circles" then
		-- 둥근 판 여러 개를 겹쳐 놓는다 (호리병, 곰돌이 얼굴 + 귀)
		for index, circle in shape.circles :: { BoardShape.Circle } do
			local cframe = CFrame.new(circle.x, y, circle.z) * CFrame.Angles(0, 0, math.rad(90))
			makeSlab("Lobe" .. index, Vector3.new(Config.BoardThickness, circle.r * 2, circle.r * 2), cframe, board, Enum.PartType.Cylinder)
		end
	else
		makeSlab("Slab", Vector3.new(size, Config.BoardThickness, size), CFrame.new(0, y, 0), board)
	end

	drawPattern(board)
	if Config.BoardSizes[Board.setup.sizeKey].Face then
		drawBearFace(board)
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
	local random = Random.new()
	local occupied = {}
	for _, piece in piecesFolder:GetChildren() do
		if piece:IsA("BasePart") then
			table.insert(occupied, { piece.Position.X, piece.Position.Z, piece.Size.Y / 2 })
		end
	end
	local spots = BoardShape.bumpSpots(Board.shape, floor.BumpCount, floor.BumpRadius, occupied, function(low, high)
		return random:NextNumber(low, high)
	end)
	for _, spot in spots do
		local bump = Instance.new("Part")
		bump.Name = "Bump"
		bump.Shape = Enum.PartType.Ball
		bump.Anchored = true
		bump.CanQuery = false
		bump.Size = Vector3.one * floor.BumpRadius * 2
		bump.Position = Vector3.new(spot.x, Config.BoardHeight - floor.BumpRadius + floor.BumpHeight, spot.z)
		bump.Color = floor.Color:Lerp(Color3.new(0, 0, 0), 0.25)
		bump.Material = Enum.Material.Rock
		bump.CustomPhysicalProperties = PhysicalProperties.new(0.7, Board.setup.friction, 0.3, 1, 1)
		bump.Parent = board
	end
end

return Board
