-- 거대화 : 내 알 크기·질량 2배 (그 판 내내)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ability = {}

function Ability.Execute(piece: BasePart, context)
	context.PieceFactory.resize(piece, Config.GiantScale)
	context.Effects.sparkle(piece.Position, Color3.fromRGB(120, 255, 120), 30)
end

function Ability.OnTurnEnd(_piece: BasePart) end

return Ability
