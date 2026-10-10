-- 유령 : 상대 턴 한 번 동안 다른 알을 통과 (판은 안 통과)
local Ability = {}

function Ability.Execute(piece: BasePart, context)
	piece.CollisionGroup = context.GHOST_GROUP
	context.PieceFactory.setTransparency(piece, 0.6)
	context.Effects.sparkle(piece.Position, Color3.fromRGB(230, 230, 255), 20)
	context.startEffect(piece, "Ghost")
end

function Ability.OnTurnEnd(piece: BasePart)
	local PieceFactory = require(script.Parent.Parent:WaitForChild("PieceFactory"))
	piece.CollisionGroup = PieceFactory.COLLISION_GROUP
	PieceFactory.setTransparency(piece, 0)
end

return Ability
