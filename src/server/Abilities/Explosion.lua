-- 폭발 : 내 알이 터지며 주변 알에 큰 충격 + 왕알 데미지.
-- 밖으로 내보내거나 죽이지 않는다 (이번 턴엔 판 가장자리에 안 보이는 벽, 왕알 HP 는 1 까지만).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ability = {}

local function buildWalls(): Folder
	local Board = require(script.Parent.Parent:WaitForChild("Board"))
	local walls = Instance.new("Folder")
	walls.Name = "ExplosionWalls"
	local height = Config.ExplosionWallHeight
	local thickness = 2
	local y = Config.BoardHeight + height / 2
	-- 판 가장자리(와 화산 구멍 둘레)를 따라 바깥에 벽
	local BoardShape = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BoardShape"))
	for _, spot in BoardShape.wallSpots(Board.shape) do
		local outward = Vector3.new(spot.nx, 0, spot.nz)
		local center = Vector3.new(spot.x, y, spot.z) + outward * (thickness / 2)
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanQuery = false
		wall.Size = Vector3.new(spot.length, height, thickness)
		wall.CFrame = CFrame.lookAt(center, center + outward)
		wall.CollisionGroup = "Pieces"
		wall.Parent = walls
	end
	walls.Parent = workspace
	return walls
end

function Ability.Execute(piece: BasePart, context)
	local center = piece.Position
	local walls = buildWalls()
	context.Damage.setProtected(true)
	context.onTurnEnd(function()
		walls:Destroy()
		context.Damage.setProtected(false)
	end)

	piece:Destroy()
	context.Effects.explosion(center)

	for _, other in context.piecesFolder:GetChildren() do
		if other:IsA("BasePart") then
			local offset = other.Position - center
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if distance < Config.ExplosionRadius then
				local strength = 1 - distance / Config.ExplosionRadius
				local direction = if distance > 0.01 then flat.Unit else Vector3.xAxis
				if other.Anchored then
					-- 자석 알은 안 밀린다
				else
					other:ApplyImpulse((direction + Vector3.new(0, 0.3, 0)) * Config.ExplosionPower * strength)
				end
				if other:GetAttribute("Kind") == "King" then
					context.Damage.apply(other, Config.ExplosionKingDamage * strength, 1)
				end
			end
		end
	end
end

function Ability.OnTurnEnd(_piece: BasePart) end

return Ability
