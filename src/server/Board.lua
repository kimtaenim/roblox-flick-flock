-- 알까기 판 만들기 (사각형 또는 육각형)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BoardShape = require(Shared:WaitForChild("BoardShape"))

local Board = {}

-- 지금 판 모양 (다른 모듈이 판 밖 판정 등에 쓴다)
Board.shape = "Square"
Board.edges = BoardShape.edges("Square", Config.BoardSize)

local function makeSlab(name: string, size: Vector3, cframe: CFrame, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = Config.BoardColor
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(0.7, Config.BoardFriction, 0.2, 1, 1)
	part.Parent = parent
	return part
end

-- 판 위에 그리는 선 (부딪히지 않음)
local function makeLine(length: number, cframe: CFrame, parent: Instance)
	local line = Instance.new("Part")
	line.Name = "Line"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.Size = Vector3.new(0.3, 0.05, length)
	line.CFrame = cframe
	line.Color = Color3.fromRGB(255, 255, 255)
	line.Material = Enum.Material.SmoothPlastic
	line.Parent = parent
end

function Board.build(teamCount: number): Model
	local old = workspace:FindFirstChild("Board")
	if old then
		old:Destroy()
	end
	Board.shape = BoardShape.pick(Config.BoardShape, teamCount)
	Board.edges = BoardShape.edges(Board.shape, Config.BoardSize)

	local board = Instance.new("Model")
	board.Name = "Board"
	local y = Config.BoardHeight - Config.BoardThickness / 2
	local size = Config.BoardSize
	if Board.shape == "Hexagon" then
		-- 직사각형 3개를 60도씩 돌려 겹치면 정육각형
		local side = size / math.sqrt(3)
		for index = 0, 2 do
			local cframe = CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(index * 60), 0)
			makeSlab("Slab" .. index, Vector3.new(side, Config.BoardThickness, size), cframe, board)
		end
	else
		makeSlab("Slab", Vector3.new(size, Config.BoardThickness, size), CFrame.new(0, y, 0), board)
	end

	-- 팀 사이 경계선 : 가운데에서 팀과 팀 사이 방향으로
	local lineY = Config.BoardHeight + 0.025
	for team = 1, teamCount do
		local angle = (team - 0.5) * 2 * math.pi / teamCount
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local length = Config.BoardSize / 2 * 0.9
		local middle = Vector3.new(0, lineY, 0) + direction * (length / 2)
		makeLine(length, CFrame.lookAt(middle, middle + direction), board)
	end

	board.Parent = workspace
	return board
end

return Board
