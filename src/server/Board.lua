-- 알까기 판 만들기
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Board = {}

function Board.build(): Part
	local old = workspace:FindFirstChild("Board")
	if old then
		old:Destroy()
	end

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Size = Vector3.new(Config.BoardSize, Config.BoardThickness, Config.BoardSize)
	board.Position = Vector3.new(0, Config.BoardHeight - Config.BoardThickness / 2, 0)
	board.Color = Config.BoardColor
	board.Material = Enum.Material.Wood
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth
	board.CustomPhysicalProperties = PhysicalProperties.new(0.7, Config.BoardFriction, 0.2, 1, 1)

	-- 가운데 선 (빨강 진영 +Z / 파랑 진영 -Z)
	local line = Instance.new("Part")
	line.Name = "CenterLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.Size = Vector3.new(Config.BoardSize, 0.05, 0.3)
	line.Position = Vector3.new(0, Config.BoardHeight + 0.025, 0)
	line.Color = Color3.fromRGB(255, 255, 255)
	line.Material = Enum.Material.SmoothPlastic
	line.Parent = board

	board.Parent = workspace
	return board
end

return Board
