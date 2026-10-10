-- 텔레포트 : 내 알을 판 가운데로. 막혀 있으면 가장 가까운 빈 자리.
local Ability = {}

function Ability.Execute(piece: BasePart, context)
	local radius = context.PieceFactory.radius(piece)
	local spot = context.Placement.findFreeSpot(0, 0, radius, context.piecesFolder, piece)
	if not spot then
		return
	end
	context.Effects.sparkle(piece.Position, Color3.fromRGB(200, 150, 255), 25)
	local rotation = piece.CFrame - piece.Position
	piece.AssemblyLinearVelocity = Vector3.zero
	piece.AssemblyAngularVelocity = Vector3.zero
	piece.CFrame = CFrame.new(spot + Vector3.new(0, context.PieceFactory.halfHeight(piece) + 0.05, 0)) * rotation
	context.Effects.sparkle(piece.Position, Color3.fromRGB(200, 150, 255), 25)
end

function Ability.OnTurnEnd(_piece: BasePart) end

return Ability
