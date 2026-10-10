-- 판 밖 탈락 판정
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Elimination = {}

function Elimination.isOut(piece: BasePart): boolean
	local position = piece.Position
	local half = Config.BoardSize / 2
	-- 판 아래로 떨어졌거나, 알 가운데가 판 가장자리를 넘었으면 탈락
	if position.Y < Config.BoardHeight - Config.FallDepth then
		return true
	end
	return math.abs(position.X) > half or math.abs(position.Z) > half
end

-- 탈락한 알을 지우고 개수를 돌려준다
function Elimination.removeOutPieces(folder: Instance): number
	local removed = 0
	for _, piece in folder:GetChildren() do
		if piece:IsA("BasePart") and Elimination.isOut(piece) then
			piece:Destroy()
			removed += 1
		end
	end
	return removed
end

return Elimination
