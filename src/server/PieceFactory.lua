-- 알 만들기. 모든 알은 Config.Pieces 의 다섯 값으로 만든다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PieceFactory = {}

PieceFactory.COLLISION_GROUP = "Pieces"

-- groundPosition : 알 바닥이 놓일 자리
function PieceFactory.create(kind: string, team: number, groundPosition: Vector3, parent: Instance): Part
	local info = Config.Pieces[kind]
	assert(info, "모르는 알 종류: " .. tostring(kind))

	local diameter = Config.PieceDiameter * info.size
	local height = Config.FlatHeight * info.size

	local piece = Instance.new("Part")
	piece.Name = Config.Teams[team].Name .. "_" .. kind
	-- 원기둥은 X축이 길이 방향이라 Z축으로 90도 돌려 눕힌다
	piece.Shape = Enum.PartType.Cylinder
	piece.Size = Vector3.new(height, diameter, diameter)
	piece.CFrame = CFrame.new(groundPosition + Vector3.new(0, height / 2 + 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))

	-- 질량이 Config 값과 같도록 밀도를 맞춘다
	local volume = math.pi * (diameter / 2) ^ 2 * height
	local density = math.clamp(info.mass * Config.MassUnit / volume, 0.01, 100)
	piece.CustomPhysicalProperties = PhysicalProperties.new(density, Config.PieceFriction, Config.PieceElasticity, 1, 1)

	piece.Color = Config.Teams[team].Color
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.CollisionGroup = PieceFactory.COLLISION_GROUP

	piece:SetAttribute("Team", team)
	piece:SetAttribute("Kind", kind)
	piece:SetAttribute("Hp", info.hp)

	piece.Parent = parent
	-- 물리는 서버가 담당 (클라이언트 소유면 서버에서 속도를 못 바꾼다)
	piece:SetNetworkOwner(nil)
	return piece
end

return PieceFactory
