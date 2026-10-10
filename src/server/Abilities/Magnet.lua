-- 자석 : 아주 무거워지고 바닥에 착 붙는다 (상대 턴 한 번 동안, Config.EffectTurns.Magnet).
-- 세게 맞으면 조금은 밀린다. 때린 알은 딱딱하게 되튕김.
local Ability = {}

function Ability.Execute(piece: BasePart, context)
	piece.AssemblyLinearVelocity = Vector3.zero
	piece.AssemblyAngularVelocity = Vector3.zero
	piece:SetAttribute("Magnet", true)
	context.PieceFactory.refreshPhysics(piece)
	for _, part in context.PieceFactory.bodyParts(piece) do
		part.Material = Enum.Material.DiamondPlate
	end
	context.startEffect(piece, "Magnet")
end

function Ability.OnTurnEnd(piece: BasePart)
	-- 효과가 끝날 때 (GameManager 가 남은 턴이 0 이 되면 부른다)
	local PieceFactory = require(script.Parent.Parent:WaitForChild("PieceFactory"))
	piece:SetAttribute("Magnet", nil)
	PieceFactory.refreshPhysics(piece)
	for _, part in PieceFactory.bodyParts(piece) do
		part.Material = Enum.Material.SmoothPlastic
	end
end

return Ability
