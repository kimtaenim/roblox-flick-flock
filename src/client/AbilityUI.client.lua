-- 능력 버튼 : 내 차례에 내 능력 알마다 버튼 하나. 누르면 그 알의 능력을 쓴다 (튕기기 대신).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local AbilityList = require(Shared:WaitForChild("AbilityList"))

local player = Players.LocalPlayer
local state = Remotes.State
local piecesFolder = workspace:WaitForChild("Pieces")

local gui = Instance.new("ScreenGui")
gui.Name = "AbilityUI"
gui.ResetOnSpawn = false

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.new(0.95, 0, 0, 70)
bar.BackgroundTransparency = 1
bar.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.Parent = bar

local helpLabel = Instance.new("TextLabel")
helpLabel.AnchorPoint = Vector2.new(0.5, 1)
helpLabel.Position = UDim2.new(0.5, 0, 1, -92)
helpLabel.Size = UDim2.new(0.9, 0, 0, 24)
helpLabel.BackgroundTransparency = 1
helpLabel.Font = Enum.Font.GothamBold
helpLabel.TextSize = 20
helpLabel.TextColor3 = Color3.new(1, 1, 1)
helpLabel.TextStrokeTransparency = 0.3
helpLabel.Text = ""
helpLabel.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local highlight = Instance.new("Highlight")
highlight.FillColor = Color3.fromRGB(255, 230, 80)
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.FillTransparency = 0.4

local function isMyTurn(): boolean
	local team = state:GetAttribute("CurrentTeam")
	return state:GetAttribute("Phase") == "Aiming" and state:GetAttribute("Team" .. team .. "Owner") == player.UserId
end

local function clearButtons()
	for _, child in bar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	highlight.Parent = nil
	helpLabel.Text = ""
end

local function refresh()
	clearButtons()
	if not isMyTurn() then
		return
	end
	local team = state:GetAttribute("CurrentTeam")
	for _, piece in piecesFolder:GetChildren() do
		local ability = AbilityList.get(piece:GetAttribute("Ability") :: string?)
		if piece:IsA("BasePart") and ability and piece:GetAttribute("Team") == team then
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(130, 64)
			button.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
			button.Font = Enum.Font.GothamBold
			button.TextScaled = true
			button.TextColor3 = Color3.fromRGB(60, 40, 20)
			button.Text = ability.Icon .. " " .. ability.Name
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = button
			button.MouseEnter:Connect(function()
				highlight.Adornee = piece
				highlight.Parent = piece
				helpLabel.Text = ability.Help
			end)
			button.MouseLeave:Connect(function()
				highlight.Parent = nil
				helpLabel.Text = ""
			end)
			button.Activated:Connect(function()
				if isMyTurn() and piece.Parent then
					Remotes.UseAbility:FireServer(piece)
					clearButtons()
				end
			end)
			button.Parent = bar
		end
	end
end

for _, name in { "Phase", "CurrentTeam" } do
	state:GetAttributeChangedSignal(name):Connect(refresh)
end
piecesFolder.ChildAdded:Connect(refresh)
piecesFolder.ChildRemoved:Connect(refresh)
refresh()
