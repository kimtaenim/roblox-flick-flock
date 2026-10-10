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

-- 탈락한 알을 지우고, 지운 알 정보 목록을 돌려준다. beforeRemove 는 지우기 직전에 불린다 (대사 등).
function Elimination.removeOutPieces(
	folder: Instance,
	beforeRemove: ((BasePart) -> ())?
): { { team: number, kind: string, position: Vector3 } }
	local removed = {}
	for _, piece in folder:GetChildren() do
		if piece:IsA("BasePart") and Elimination.isOut(piece) then
			table.insert(removed, {
				team = piece:GetAttribute("Team"),
				kind = piece:GetAttribute("Kind"),
				position = piece.Position,
			})
			if beforeRemove then
				beforeRemove(piece)
			end
			piece:Destroy()
		end
	end
	return removed
end

return Elimination
