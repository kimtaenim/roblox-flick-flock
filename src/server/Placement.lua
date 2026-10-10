-- 알을 놓을 빈 자리 찾기, 팀 배치
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TeamLayout = require(Shared:WaitForChild("TeamLayout"))
local BoardShape = require(Shared:WaitForChild("BoardShape"))

local Board = require(script.Parent:WaitForChild("Board"))

local PieceFactory = require(script.Parent:WaitForChild("PieceFactory"))

local Placement = {}

local EDGE_GAP = 1 -- 가장자리에서 띄우는 거리

-- 판 가운데에서 팀 자리 쪽 방향 (단위 벡터)
function Placement.direction(team: number, teamCount: number): Vector3
	local x, z = TeamLayout.direction(team, teamCount)
	return Vector3.new(x, 0, z)
end

-- (x, z) 에 반지름 radius 알을 놓으면 다른 알과 안 겹치는지
function Placement.isFree(x: number, z: number, radius: number, folder: Instance, ignore: BasePart?): boolean
	if not BoardShape.inside(Board.edges, x, z, radius + EDGE_GAP) then
		return false
	end
	for _, piece in folder:GetChildren() do
		if piece:IsA("BasePart") and piece ~= ignore then
			local dx, dz = piece.Position.X - x, piece.Position.Z - z
			local minGap = radius + PieceFactory.radius(piece) + 0.3
			if dx * dx + dz * dz < minGap * minGap then
				return false
			end
		end
	end
	return true
end

-- 원하는 자리에서 가장 가까운 빈 자리
function Placement.findFreeSpot(wantX: number, wantZ: number, radius: number, folder: Instance, ignore: BasePart?): Vector3?
	local half = math.ceil(BoardShape.reach(Board.shape, Config.BoardSize))
	local best: Vector3? = nil
	local bestDistance = math.huge
	for x = -half, half do
		for z = -half, half do
			local distance = (x - wantX) ^ 2 + (z - wantZ) ^ 2
			if distance < bestDistance and Placement.isFree(x, z, radius, folder, ignore) then
				bestDistance = distance
				best = Vector3.new(x, Config.BoardHeight, z)
			end
		end
	end
	return best
end

-- 팀 알 배치 : 왕알은 뒤쪽 가운데, 나머지는 앞줄부터 채운다
-- pieces : { { kind, ability? }, ... }
function Placement.layoutTeam(team: number, teamCount: number, pieces: { { string } }, folder: Instance): { BasePart }
	local layout = TeamLayout.pick(Config.Layouts, teamCount)
	local created: { BasePart } = {}
	for _, slot in TeamLayout.slots(team, teamCount, pieces, layout) do
		local piece = PieceFactory.create(slot.kind, team, Vector3.new(slot.x, Config.BoardHeight, slot.z), folder, slot.ability)
		table.insert(created, piece)
	end
	return created
end

return Placement
