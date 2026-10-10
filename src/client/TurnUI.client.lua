-- 화면 위 차례·알 개수 표시, 가운데 큰 글씨(배너)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

local cameraHint = Instance.new("TextLabel")
cameraHint.Name = "CameraHint"
cameraHint.AnchorPoint = Vector2.new(0, 1)
cameraHint.Position = UDim2.new(0, 12, 1, -100)
cameraHint.Size = UDim2.new(0.6, 0, 0, 22)
cameraHint.BackgroundTransparency = 1
cameraHint.Font = Enum.Font.Gotham
cameraHint.TextSize = 16
cameraHint.TextXAlignment = Enum.TextXAlignment.Left
cameraHint.TextColor3 = Color3.new(1, 1, 1)
cameraHint.TextStrokeTransparency = 0.5
cameraHint.Text = "🎥 빈 곳 끌기: 돌리기 · 휠: 확대 · WASD: 이동 · R: 처음 자리"
cameraHint.Parent = gui

local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.4)
banner.Size = UDim2.new(0.9, 0, 0, 70)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextStrokeTransparency = 0
banner.TextTransparency = 1
banner.TextStrokeTransparency = 1
banner.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local bannerTween: Tween? = nil
local function showBanner(text: string, color: Color3)
	if bannerTween then
		bannerTween:Cancel()
	end
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	local tween = TweenService:Create(
		banner,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.2),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	bannerTween = tween
	tween:Play()
end

Remotes.Effect.OnClientEvent:Connect(function(kind, text, color)
	if kind == "Banner" and typeof(text) == "string" then
		showBanner(text, if typeof(color) == "Color3" then color else Color3.new(1, 1, 1))
	end
end)

local function countPieces(team: number): (number, number)
	local soldiers, kingHp = 0, 0
	for _, piece in piecesFolder:GetChildren() do
		if piece:GetAttribute("Team") == team then
			if piece:GetAttribute("Kind") == "King" then
				kingHp = piece:GetAttribute("Hp") or 0
			else
				soldiers += 1
			end
		end
	end
	return soldiers, kingHp
end

local function ownerText(team: number): string
	local owner = state:GetAttribute("Team" .. team .. "Owner")
	if owner == -1 then
		return Config.NpcName
	elseif owner == player.UserId then
		return "나"
	end
	return "친구"
end

local function refresh()
	local phase = state:GetAttribute("Phase")
	local team = state:GetAttribute("CurrentTeam")
	local teamInfo = Config.Teams[team]
	local owner = state:GetAttribute("Team" .. team .. "Owner")

	turnLabel.TextColor3 = Color3.new(1, 1, 1)
	helpLabel.Text = ""
	if phase == "Waiting" then
		turnLabel.Text = "친구를 기다리는 중..."
	elseif phase == "TeamSelect" then
		turnLabel.Text = "팀 고르기"
	elseif phase == "Aiming" then
		turnLabel.Text = teamInfo.Name .. " 차례 (" .. ownerText(team) .. ")"
		turnLabel.TextColor3 = teamInfo.Color
		if owner == player.UserId then
			helpLabel.Text = if Config.PullBackToShoot
				then "내 알을 뒤로 끌었다 놓으면 날아가요! 아래 버튼은 능력"
				else "내 알을 날릴 방향으로 끌었다 놓아요! 아래 버튼은 능력"
		elseif owner == -1 then
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
		helpLabel.Text = (state:GetAttribute("WinReason") or "") .. "  곧 새 판이 시작돼요"
	end

	local red, redHp = countPieces(1)
	local blue, blueHp = countPieces(2)
	scoreLabel.Text = string.format(
		"%s 알 %d · 👑%d   vs   %s 알 %d · 👑%d",
		Config.Teams[1].Name,
		red,
		math.ceil(redHp),
		Config.Teams[2].Name,
		blue,
		math.ceil(blueHp)
	)
end

for _, name in { "Phase", "CurrentTeam", "Winner", "Team1Owner", "Team2Owner" } do
	state:GetAttributeChangedSignal(name):Connect(refresh)
end

local function watch(piece: Instance)
	piece:GetAttributeChangedSignal("Hp"):Connect(refresh)
end
for _, piece in piecesFolder:GetChildren() do
	watch(piece)
end
piecesFolder.ChildAdded:Connect(function(piece)
	watch(piece)
	refresh()
end)
piecesFolder.ChildRemoved:Connect(refresh)
refresh()

-- 이긴 팀 발표
state:GetAttributeChangedSignal("Phase"):Connect(function()
	if state:GetAttribute("Phase") == "GameOver" then
		local winner = state:GetAttribute("Winner")
		if winner == -1 then
			showBanner("무승부!", Color3.new(1, 1, 1))
		elseif Config.Teams[winner] then
			local mine = state:GetAttribute("Team" .. winner .. "Owner") == player.UserId
			showBanner(if mine then "이겼다!! 🎉" else Config.Teams[winner].Name .. " 승리!", Config.Teams[winner].Color)
		end
	end
end)
