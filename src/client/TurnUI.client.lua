-- 화면 위 차례·알 개수 표시
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local state = Remotes.State
local piecesFolder = workspace:WaitForChild("Pieces")

local gui = Instance.new("ScreenGui")
gui.Name = "TurnUI"
gui.ResetOnSpawn = false

local function makeLabel(name: string, y: number, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.new(0.9, 0, 0, textSize + 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return label
end

local turnLabel = makeLabel("Turn", 10, 32)
local helpLabel = makeLabel("Help", 54, 20)
local scoreLabel = makeLabel("Score", 84, 24)
gui.Parent = player:WaitForChild("PlayerGui")

local function countPieces(team: number): number
	local count = 0
	for _, piece in piecesFolder:GetChildren() do
		if piece:GetAttribute("Team") == team then
			count += 1
		end
	end
	return count
end

local function refresh()
	local phase = state:GetAttribute("Phase")
	local team = state:GetAttribute("CurrentTeam")
	local teamInfo = Config.Teams[team]
	local mine = state:GetAttribute("Team" .. team .. "Owner") == player.UserId

	turnLabel.TextColor3 = Color3.new(1, 1, 1)
	helpLabel.Text = ""
	if phase == "Waiting" then
		turnLabel.Text = "친구를 기다리는 중..."
	elseif phase == "Aiming" then
		turnLabel.Text = teamInfo.Name .. " 차례"
		turnLabel.TextColor3 = teamInfo.Color
		if mine then
			helpLabel.Text = if Config.PullBackToShoot
				then "내 알을 뒤로 끌었다 놓으면 날아가요!"
				else "내 알을 날릴 방향으로 끌었다 놓아요!"
		elseif state:GetAttribute("Team" .. team .. "Owner") == -1 then
			helpLabel.Text = Config.NpcName .. "가 생각하는 중..."
		else
			helpLabel.Text = "상대가 조준하는 중..."
		end
	elseif phase == "Moving" then
		turnLabel.Text = "알이 멈추길 기다리는 중..."
	elseif phase == "GameOver" then
		local winner = state:GetAttribute("Winner")
		if winner == -1 then
			turnLabel.Text = "무승부!"
		else
			turnLabel.Text = Config.Teams[winner].Name .. " 승리!"
			turnLabel.TextColor3 = Config.Teams[winner].Color
		end
		helpLabel.Text = "곧 새 판이 시작돼요"
	end

	scoreLabel.Text = string.format(
		"%s %d  :  %d %s",
		Config.Teams[1].Name,
		countPieces(1),
		countPieces(2),
		Config.Teams[2].Name
	)
end

for _, name in { "Phase", "CurrentTeam", "Winner", "Team1Owner", "Team2Owner" } do
	state:GetAttributeChangedSignal(name):Connect(refresh)
end
piecesFolder.ChildAdded:Connect(refresh)
piecesFolder.ChildRemoved:Connect(refresh)
refresh()
