-- 알을 놓을 빈 자리 찾기, 팀 배치
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PieceFactory = require(script.Parent:WaitForChild("PieceFactory"))

local Placement = {}

local EDGE_GAP = 1 -- 가장자리에서 띄우는 거리

-- 진영 방향 : 빨강 +1, 파랑 -1
function Placement.side(team: number): number
	return if team == 1 then 1 else -1
end

-- (x, z) 에 반지름 radius 알을 놓으면 다른 알과 안 겹치는지
function Placement.isFree(x: number, z: number, radius: number, folder: Instance, ignore: BasePart?): boolean
	local half = Config.BoardSize / 2 - EDGE_GAP
	if math.abs(x) + radius > half or math.abs(z) + radius > half then
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

-- 원하는 자리에서 가장 가까운 빈 자리. team 을 주면 그 팀 진영 안에서만.
function Placement.findFreeSpot(wantX: number, wantZ: number, radius: number, folder: Instance, team: number?, ignore: BasePart?): Vector3?
	local half = Config.BoardSize / 2
	local step = 1
	local best: Vector3? = nil
	local bestDistance = math.huge
	for x = -half, half, step do
		for z = -half, half, step do
			local inSide = team == nil or (z * Placement.side(team) >= radius)
			if inSide then
				local distance = (x - wantX) ^ 2 + (z - wantZ) ^ 2
				if distance < bestDistance and Placement.isFree(x, z, radius, folder, ignore) then
					bestDistance = distance
					best = Vector3.new(x, Config.BoardHeight, z)
				end
			end
		end
	end
	return best
end

-- 팀 알 배치 : 왕알은 뒤쪽 가운데, 나머지는 앞줄부터 채운다
-- pieces : { { kind, ability? }, ... }
function Placement.layoutTeam(team: number, pieces: { { string } }, folder: Instance): { BasePart }
	local side = Placement.side(team)
	local created: { BasePart } = {}
	table.insert(created, PieceFactory.create("King", team, Vector3.new(0, Config.BoardHeight, side * Config.KingRowDistance), folder))

	local perRow = Config.PiecesPerRow
	for index, entry in pieces do
		local row = math.floor((index - 1) / perRow) + 1
		local rowDistance = Config.RowDistances[math.min(row, #Config.RowDistances)]
		local inRow = math.min(#pieces - (row - 1) * perRow, perRow)
		local column = (index - 1) % perRow + 1
		local x = (column - (inRow + 1) / 2) * Config.PieceSpacing
		local piece = PieceFactory.create(entry[1], team, Vector3.new(x, Config.BoardHeight, side * rowDistance), folder, entry[2])
		table.insert(created, piece)
	end
	return created
end

return Placement
