-- 자석 : 바닥에 딱 붙는다. 상대 턴과 내 다음 턴 동안 나도 상대도 못 움직임 (Config.EffectTurns.Magnet).
-- 때린 알은 딱딱하게 되튕김.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ability = {}

function Ability.Execute(piece: BasePart, context)
	piece.AssemblyLinearVelocity = Vector3.zero
	piece.AssemblyAngularVelocity = Vector3.zero
	piece.Anchored = true
	context.PieceFactory.setElasticity(piece, Config.MagnetElasticity)
	for _, part in context.PieceFactory.bodyParts(piece) do
		part.Material = Enum.Material.DiamondPlate
	end
	context.startEffect(piece, "Magnet")
end

function Ability.OnTurnEnd(piece: BasePart)
	-- 효과가 끝날 때 (GameManager 가 남은 턴이 0 이 되면 부른다)
	piece.Anchored = false
	local PieceFactory = require(script.Parent.Parent:WaitForChild("PieceFactory"))
	for _, part in PieceFactory.bodyParts(piece) do
		part.Material = Enum.Material.SmoothPlastic
	end
	PieceFactory.setElasticity(piece, nil)
	piece:SetNetworkOwner(nil)
end

return Ability
