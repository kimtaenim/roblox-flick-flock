-- 분신 : 내 알 옆에 0.5 알 2개 (원래 알은 그대로)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ability = {}

function Ability.Execute(piece: BasePart, context)
	context.Effects.melody("Clone", piece)
	local radius = Config.PieceDiameter * Config.Pieces.Half.size / 2
	local offset = context.PieceFactory.radius(piece) + radius + 0.5
	for _, sign in { -1, 1 } do
		local wantX = piece.Position.X + sign * offset
		local wantZ = piece.Position.Z
		local spot = context.Placement.findFreeSpot(wantX, wantZ, radius, context.piecesFolder)
		if spot then
			local clone = context.PieceFactory.create("Half", context.team, spot, context.piecesFolder, nil, context.Placement.randomCharacter("Half"))
			context.watchPiece(clone)
			context.Effects.sparkle(clone.Position, Config.Teams[context.team].Color, 15)
		end
	end
end

function Ability.OnTurnEnd(_piece: BasePart) end

return Ability
