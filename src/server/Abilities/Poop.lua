-- 똥알 : 내 알이 똥이 된다. 상대 알이 뚫고 지나가며 똥을 밟아 확 느려지고 발자국이 남는다.
-- 똥알은 밀리지 않는다 (다른 알과 안 부딪힘).
local Ability = {}

local POOP_COLOR = Color3.fromRGB(120, 72, 30)

function Ability.Execute(piece: BasePart, context)
	piece:SetAttribute("OriginalColor", piece.Color)
	piece.Color = POOP_COLOR
	piece.Material = Enum.Material.Slate
	piece.CollisionGroup = context.GHOST_GROUP
	context.Effects.sound("Poop", piece)
	context.startEffect(piece, "Poop")
end

function Ability.OnTurnEnd(piece: BasePart)
	local PieceFactory = require(script.Parent.Parent:WaitForChild("PieceFactory"))
	local original = piece:GetAttribute("OriginalColor")
	if typeof(original) == "Color3" then
		piece.Color = original
	end
	piece.Material = Enum.Material.SmoothPlastic
	piece.CollisionGroup = PieceFactory.COLLISION_GROUP
end

return Ability
