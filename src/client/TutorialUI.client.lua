-- 튜토리얼 : 처음 들어오면 한 장씩 보여 준다. 오른쪽 위 "?" 로 다시 보기.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer

local PAGES = {
	{ "🥚 Flick Flock", "알을 튕겨서 상대 알을 판 밖으로 보내는 게임이에요!" },
	{ "👆 튕기기", if Config.PullBackToShoot
		then "내 알을 꾹 누르고 뒤로 끌었다가 놓으면 반대쪽으로 날아가요.\n많이 끌수록 세게!"
		else "내 알을 꾹 누르고 날릴 쪽으로 끌었다가 놓아요.\n많이 끌수록 세게!" },
	{ "👑 왕알", "왕관 쓴 큰 알이 왕알이에요.\n세게 부딪히면 HP가 줄고, 0이 되거나 판 밖으로 나가면 져요." },
	{ "✨ 능력", "능력 알이 있으면 화면 아래 버튼이 생겨요.\n튕기는 대신 능력을 한 번 쓸 수 있어요." },
	{ "🏆 이기려면", "상대 왕알을 쓰러뜨리거나,\n상대 알(왕알 빼고)을 모두 판 밖으로 보내요!" },
}

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.85, 0, 0, 280)
card.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = card
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(600, 280)
sizeLimit.Parent = card

local function makeLabel(textSize: number, y: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(20, y)
	label.Size = UDim2.new(1, -40, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(60, 40, 20)
	label.Parent = card
	return label
end

local titleLabel = makeLabel(32, 18, 44)
local bodyLabel = makeLabel(22, 70, 120)
local pageLabel = makeLabel(16, 196, 20)

local function makeButton(text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(130, 44)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.TextColor3 = Color3.fromRGB(60, 40, 20)
	button.Text = text
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = button
	button.Parent = card
	return button
end

local nextButton = makeButton("다음 ▶", UDim2.new(1, -150, 1, -60))
local skipButton = makeButton("건너뛰기", UDim2.new(0, 20, 1, -60))

local helpButton = Instance.new("TextButton")
helpButton.AnchorPoint = Vector2.new(1, 0)
helpButton.Position = UDim2.new(1, -12, 0, 60)
helpButton.Size = UDim2.fromOffset(44, 44)
helpButton.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
helpButton.Font = Enum.Font.GothamBlack
helpButton.TextSize = 26
helpButton.Text = "?"
helpButton.Parent = gui
local helpCorner = Instance.new("UICorner")
helpCorner.CornerRadius = UDim.new(1, 0)
helpCorner.Parent = helpButton

local page = 1
local function show(index: number)
	page = index
	card.Visible = true
	titleLabel.Text = PAGES[page][1]
	bodyLabel.Text = PAGES[page][2]
	pageLabel.Text = page .. " / " .. #PAGES
	nextButton.Text = if page == #PAGES then "시작! 🎮" else "다음 ▶"
end

nextButton.Activated:Connect(function()
	if page >= #PAGES then
		card.Visible = false
	else
		show(page + 1)
	end
end)
skipButton.Activated:Connect(function()
	card.Visible = false
end)
helpButton.Activated:Connect(function()
	show(1)
end)

gui.Parent = player:WaitForChild("PlayerGui")
show(1)
