-- 라운드와 턴 진행
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Board = require(script.Parent:WaitForChild("Board"))
local PieceFactory = require(script.Parent:WaitForChild("PieceFactory"))
local Elimination = require(script.Parent:WaitForChild("Elimination"))

local state = Remotes.State

-- 캐릭터는 알과 부딪히지 않는다 (판 위를 걸어도 알이 안 밀림)
local CHARACTER_GROUP = "Characters"
PhysicsService:RegisterCollisionGroup(PieceFactory.COLLISION_GROUP)
PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
PhysicsService:CollisionGroupSetCollidable(PieceFactory.COLLISION_GROUP, CHARACTER_GROUP, false)

local function setCharacterGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = CHARACTER_GROUP
	end
end

local function onCharacterAdded(character: Model)
	for _, part in character:GetDescendants() do
		setCharacterGroup(part)
	end
	character.DescendantAdded:Connect(setCharacterGroup)
end

local piecesFolder = Instance.new("Folder")
piecesFolder.Name = "Pieces"
piecesFolder.Parent = workspace

Board.build()

-- 팀 주인 : teamOwners[1] = 빨강 플레이어, teamOwners[2] = 파랑 플레이어
local teamOwners: { [number]: Player? } = {}
local restartRequested = false

local function assignTeams()
	local list = Players:GetPlayers()
	teamOwners[1] = list[1]
	teamOwners[2] = list[2] or (if Config.AllowSoloPlay then list[1] else nil)
	for team = 1, 2 do
		local owner = teamOwners[team]
		state:SetAttribute("Team" .. team .. "Owner", if owner then owner.UserId else 0)
	end
end

local function isSoloGame(): boolean
	return teamOwners[1] ~= nil and teamOwners[1] == teamOwners[2]
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	-- 혼자 하던 중에 친구가 들어오면 2인으로 새로 시작
	if isSoloGame() then
		restartRequested = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if teamOwners[1] == player or teamOwners[2] == player then
		restartRequested = true
	end
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

local function countPieces(team: number): number
	local count = 0
	for _, piece in piecesFolder:GetChildren() do
		if piece:GetAttribute("Team") == team then
			count += 1
		end
	end
	return count
end

local function setupPieces()
	piecesFolder:ClearAllChildren()
	local kinds = Config.StartingPieces
	for team = 1, 2 do
		-- 빨강은 +Z 쪽, 파랑은 -Z 쪽
		local side = if team == 1 then 1 else -1
		for index, kind in kinds do
			local x = (index - (#kinds + 1) / 2) * Config.PieceSpacing
			local z = side * Config.StartRowDistance
			PieceFactory.create(kind, team, Vector3.new(x, Config.BoardHeight, z), piecesFolder)
		end
	end
end

-- 판 밖으로 나간 알은 바로 탈락
RunService.Heartbeat:Connect(function()
	Elimination.removeOutPieces(piecesFolder)
end)

-- 튕기기 요청 (클라이언트는 "이 알을 이 방향으로 이만큼"만 보낸다)
Remotes.Flick.OnServerEvent:Connect(function(player, piece, direction, power)
	if state:GetAttribute("Phase") ~= "Aiming" then
		return
	end
	local team = state:GetAttribute("CurrentTeam")
	if teamOwners[team] ~= player then
		return
	end
	if typeof(piece) ~= "Instance" or piece.Parent ~= piecesFolder or piece:GetAttribute("Team") ~= team then
		return
	end
	if typeof(direction) ~= "Vector3" or typeof(power) ~= "number" or power ~= power then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.01 then
		return
	end
	power = math.clamp(power, 0, 1)
	if power < Config.MinFlickPower then
		return
	end

	state:SetAttribute("Phase", "Moving")
	piece:SetNetworkOwner(nil)
	piece:ApplyImpulse(flatDirection.Unit * power * Config.FlickPower)
end)

-- 모든 알이 멈출 때까지 기다린다
local function waitUntilStopped()
	local stillTime = 0
	local elapsed = 0
	while elapsed < Config.MaxMoveTime and not restartRequested do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local moving = false
		for _, piece in piecesFolder:GetChildren() do
			if
				piece.AssemblyLinearVelocity.Magnitude > Config.StopSpeed
				or piece.AssemblyAngularVelocity.Magnitude > Config.StopSpeed
			then
				moving = true
				break
			end
		end
		stillTime = if moving then 0 else stillTime + dt
		if stillTime >= Config.StopHoldTime then
			return
		end
	end
end

local function playRound()
	setupPieces()
	state:SetAttribute("Winner", 0)
	state:SetAttribute("CurrentTeam", 1)

	while true do
		state:SetAttribute("Phase", "Aiming")
		while state:GetAttribute("Phase") == "Aiming" do
			if restartRequested then
				return
			end
			task.wait(0.1)
		end

		waitUntilStopped()
		if restartRequested then
			return
		end

		local red, blue = countPieces(1), countPieces(2)
		if red == 0 or blue == 0 then
			local winner = if red == 0 and blue == 0 then -1 elseif red == 0 then 2 else 1
			state:SetAttribute("Winner", winner)
			state:SetAttribute("Phase", "GameOver")
			task.wait(Config.RestartDelay)
			return
		end

		state:SetAttribute("CurrentTeam", 3 - state:GetAttribute("CurrentTeam"))
	end
end

-- 플레이어를 기다렸다가 판을 계속 돌린다
while true do
	state:SetAttribute("Phase", "Waiting")
	local waited = 0
	while true do
		local count = #Players:GetPlayers()
		if count >= 2 then
			break
		end
		if count == 1 and Config.AllowSoloPlay and waited >= Config.SoloWaitTime then
			break
		end
		if count == 0 then
			waited = 0
		end
		waited += task.wait(0.25)
	end

	restartRequested = false
	assignTeams()
	playRound()
end
