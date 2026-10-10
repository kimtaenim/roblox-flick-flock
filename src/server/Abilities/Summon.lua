-- 소환 : 무작위 알 1개가 내 진영 빈 자리에 나온다. (결제와 절대 연결 안 함)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AbilityList = require(Shared:WaitForChild("AbilityList"))

local Ability = {}

-- 확률표에서 하나 뽑기 (rng:NextNumber 사용)
function Ability.roll(rng): { Name: string, Chance: number, Result: string }
	local total = 0
	for _, entry in Config.SummonTable do
		total += entry.Chance
	end
	local pick = rng:NextNumber(0, total)
	for _, entry in Config.SummonTable do
		pick -= entry.Chance
		if pick <= 0 then
			return entry
		end
	end
	return Config.SummonTable[#Config.SummonTable]
end

function Ability.Execute(_piece: BasePart, context)
	local entry = Ability.roll(context.random)
	local kind, ability = "Half", nil
	if entry.Result == "Normal" then
		kind = if context.random:NextNumber() < 0.5 then "Flat" else "Round"
	elseif entry.Result == "Ability" then
		kind = if context.random:NextNumber() < 0.5 then "Flat" else "Round"
		local list = AbilityList.List
		ability = list[context.random:NextInteger(1, #list)].Id
	end

	local radius = Config.PieceDiameter * Config.Pieces[kind].size / 2
	local side = context.Placement.side(context.team)
	local spot = context.Placement.findFreeSpot(0, side * Config.RowDistances[1], radius, context.piecesFolder, context.team)
	if not spot then
		context.Effects.banner("자리가 없어요!", Color3.new(1, 1, 1))
		return
	end
	local newPiece = context.PieceFactory.create(kind, context.team, spot, context.piecesFolder, ability)
	context.watchPiece(newPiece)

	local color = Config.Teams[context.team].Color
	if entry.Result == "Ability" then
		context.Effects.banner("대박!! " .. AbilityList.get(ability).Icon .. " " .. AbilityList.get(ability).Name .. " 알!", Color3.fromRGB(255, 215, 0))
		context.Effects.sparkle(newPiece.Position, Color3.fromRGB(255, 215, 0), 80)
		context.Remotes.Effect:FireAllClients("Shake", Config.ShakeStrength * 0.6)
	else
		context.Effects.banner(entry.Name .. "! " .. (if kind == "Half" then "0.5 알" elseif kind == "Flat" then "납작 알" else "둥근 알"), color)
		context.Effects.sparkle(newPiece.Position, color, 25)
	end
end

function Ability.OnTurnEnd(_piece: BasePart) end

return Ability
