-- 팀 고르기 : 추천 팀 중 하나 고르기. "고급" 을 누르면 예산 안에서 직접 조합.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PieceTypes = require(Shared:WaitForChild("PieceTypes"))
local AbilityList = require(Shared:WaitForChild("AbilityList"))
local TeamLayout = require(Shared:WaitForChild("TeamLayout"))
local BoardShape = require(Shared:WaitForChild("BoardShape"))


local player = Players.LocalPlayer
local state = Remotes.State

-- 이번 판에 한 팀이 놓을 수 있는 알 개수 (판 크기·팀 수에 따라)
local function currentCapacity(): number
	local setup = BoardShape.makeSetup(
		Config,
		state:GetAttribute("BoardSizeKey") or Config.DefaultBoardSize,
		state:GetAttribute("FloorKey") or Config.DefaultFloor,
		state:GetAttribute("TeamCount") or 2
	)
	return TeamLayout.capacity(setup.layout)
end

local CARD_COLOR = Color3.fromRGB(255, 248, 230)
local TEXT_COLOR = Color3.fromRGB(60, 40, 20)

local gui = Instance.new("ScreenGui")
gui.Name = "TeamSelectUI"
gui.ResetOnSpawn = false
gui.Enabled = false

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.55)
panel.Size = UDim2.new(0.92, 0, 0.7, 0)
panel.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
panel.BackgroundTransparency = 0.15
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(900, 520)
sizeLimit.Parent = panel

local function makeText(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = CARD_COLOR
	button.Font = Enum.Font.GothamBold
	button.TextSize = 20
	button.TextWrapped = true
	button.TextColor3 = TEXT_COLOR
	button.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	button.Parent = parent
	return button
end

local title = makeText(panel, "팀을 골라요!", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 8), 30)
local timerLabel = makeText(panel, "", UDim2.new(0, 120, 0, 30), UDim2.new(1, -130, 0, 12), 22)

-- 추천 팀 카드
local presetPage = Instance.new("Frame")
presetPage.Size = UDim2.new(1, -24, 1, -110)
presetPage.Position = UDim2.fromOffset(12, 56)
presetPage.BackgroundTransparency = 1
presetPage.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -8, 0.5, -8)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.Parent = presetPage

local function describePieces(pieces: { { string } }): string
	local counts = {}
	local order = {}
	for _, entry in pieces do
		local ability = AbilityList.get(entry[2])
		local name = if ability then ability.Icon .. ability.Name else PieceTypes.DisplayName[entry[1]]
		if not counts[name] then
			counts[name] = 0
			table.insert(order, name)
		end
		counts[name] += 1
	end
	local parts = {}
	for _, name in order do
		table.insert(parts, name .. "×" .. counts[name])
	end
	return table.concat(parts, "  ")
end

local presetCards: { [number]: TextButton } = {}
for index, preset in Config.PresetTeams do
	local card = makeButton(presetPage, "", UDim2.new(), UDim2.new())
	card.LayoutOrder = index
	card.Text = preset.Name .. "\n" .. preset.Description .. "\n" .. describePieces(preset.Pieces)
	card.Activated:Connect(function()
		Remotes.SelectTeam:FireServer(index)
	end)
	presetCards[index] = card
end

-- 고급 : 직접 조합
local customPage = Instance.new("Frame")
customPage.Size = UDim2.new(1, -24, 1, -110)
customPage.Position = UDim2.fromOffset(12, 56)
customPage.BackgroundTransparency = 1
customPage.Visible = false
customPage.Parent = panel

local counts = { Flat = 0, Round = 0, Half = 0, Ability = 0 }
local rows = { "Flat", "Round", "Half", "Ability" }
local rowNames = {
	Flat = PieceTypes.DisplayName.Flat,
	Round = PieceTypes.DisplayName.Round,
	Half = PieceTypes.DisplayName.Half,
	Ability = "능력 알 (능력은 무작위)",
}
local countLabels: { [string]: TextLabel } = {}
local budgetLabel = makeText(customPage, "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 1, -80), 22)
local confirmButton = makeButton(customPage, "이 팀으로!", UDim2.new(0, 200, 0, 44), UDim2.new(0.5, -100, 1, -46))

local function spent(): number
	local total = 0
	for name, count in counts do
		total += count * Config.Prices[name]
	end
	return total
end

local function totalPieces(): number
	local total = 0
	for _, count in counts do
		total += count
	end
	return total
end

local function refreshCustom()
	for name, label in countLabels do
		label.Text = tostring(counts[name])
	end
	budgetLabel.Text = string.format("남은 예산 %d / %d  (왕알은 공짜)", Config.Budget - spent(), Config.Budget)
	confirmButton.AutoButtonColor = totalPieces() > 0
	confirmButton.BackgroundTransparency = if totalPieces() > 0 then 0 else 0.5
end

for index, name in rows do
	local y = (index - 1) * 52
	makeText(customPage, rowNames[name] .. "  (" .. Config.Prices[name] .. "점)", UDim2.new(0.55, 0, 0, 44), UDim2.fromOffset(0, y), 20).TextXAlignment =
		Enum.TextXAlignment.Left
	local minus = makeButton(customPage, "-", UDim2.fromOffset(44, 44), UDim2.new(0.6, 0, 0, y))
	countLabels[name] = makeText(customPage, "0", UDim2.fromOffset(60, 44), UDim2.new(0.6, 50, 0, y), 24)
	local plus = makeButton(customPage, "+", UDim2.fromOffset(44, 44), UDim2.new(0.6, 116, 0, y))
	minus.Activated:Connect(function()
		counts[name] = math.max(counts[name] - 1, 0)
		refreshCustom()
	end)
	plus.Activated:Connect(function()
		local maxPieces = currentCapacity()
		if spent() + Config.Prices[name] <= Config.Budget and totalPieces() < maxPieces then
			counts[name] += 1
			refreshCustom()
		end
	end)
end

confirmButton.Activated:Connect(function()
	if totalPieces() > 0 then
		Remotes.SelectTeam:FireServer({ Flat = counts.Flat, Round = counts.Round, Half = counts.Half, Ability = counts.Ability })
	end
end)

local toggleButton = makeButton(panel, "고급 ▶", UDim2.fromOffset(130, 40), UDim2.new(0, 12, 1, -50))
toggleButton.Activated:Connect(function()
	customPage.Visible = not customPage.Visible
	presetPage.Visible = not customPage.Visible
	toggleButton.Text = if customPage.Visible then "◀ 추천 팀" else "고급 ▶"
	refreshCustom()
end)

local waitingLabel = makeText(gui, "상대가 팀을 고르는 중...", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.45, 0), 30)
waitingLabel.TextStrokeTransparency = 0.3
waitingLabel.Visible = false

gui.Parent = player:WaitForChild("PlayerGui")

-- 모드 고르기 (방장만) : 팀 수, 판 크기·모양, 바닥을 고르고 "시작!"
local modePanel = Instance.new("Frame")
modePanel.AnchorPoint = Vector2.new(0.5, 0.5)
modePanel.Position = UDim2.fromScale(0.5, 0.55)
modePanel.Size = UDim2.new(0.92, 0, 0, 400)
modePanel.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
modePanel.BackgroundTransparency = 0.15
modePanel.Visible = false
modePanel.Parent = gui
local modeCorner = Instance.new("UICorner")
modeCorner.CornerRadius = UDim.new(0, 16)
modeCorner.Parent = modePanel
local modeLimit = Instance.new("UISizeConstraint")
modeLimit.MaxSize = Vector2.new(820, 400)
modeLimit.Parent = modePanel
makeText(modePanel, "어떤 판에서 할까요?", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 10), 28)
local modeTimer = makeText(modePanel, "", UDim2.new(0, 120, 0, 30), UDim2.new(1, -130, 0, 14), 22)

local SELECTED_COLOR = Color3.fromRGB(255, 200, 80)
local mode = { teams = Config.DefaultTeamCount, size = Config.DefaultBoardSize, floor = Config.DefaultFloor }

-- 이름순이 아니라 Config 의 Order 순서로
local function sortedKeys(list): { string }
	local keys = {}
	for key in list do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (list[a].Order or 99) < (list[b].Order or 99)
	end)
	return keys
end

type Choice = { button: TextButton, value: any }
local modeRows: { [string]: { Choice } } = { teams = {}, size = {}, floor = {} }

local function refreshModeButtons()
	-- 호리병은 2팀만 : 팀 수를 바꾸면 보통 판으로
	if not BoardShape.allowed(Config, mode.size, mode.teams) then
		mode.size = Config.DefaultBoardSize
	end
	for rowName, choices in modeRows do
		for _, choice in choices do
			local selected = (mode :: any)[rowName] == choice.value
			local usable = rowName ~= "size" or BoardShape.allowed(Config, choice.value, mode.teams)
			choice.button.BackgroundColor3 = if selected then SELECTED_COLOR else CARD_COLOR
			choice.button.BackgroundTransparency = if usable then 0 else 0.6
			choice.button.Active = usable
			choice.button.AutoButtonColor = usable
		end
	end
end

-- 한 줄 : 제목 + 버튼들
local function makeRow(rowName: string, label: string, y: number, entries: { { text: string, value: any } })
	makeText(modePanel, label, UDim2.new(0, 90, 0, 60), UDim2.fromOffset(10, y), 22).TextXAlignment = Enum.TextXAlignment.Left
	local count = #entries
	for index, entry in entries do
		local button = makeButton(
			modePanel,
			entry.text,
			UDim2.new(1 / count, -10 - 100 / count, 0, 60),
			UDim2.new((index - 1) / count, 100 - (index - 1) * 100 / count + 5, 0, y)
		)
		button.TextSize = 22
		table.insert(modeRows[rowName], { button = button, value = entry.value })
		button.Activated:Connect(function()
			if rowName == "size" and not BoardShape.allowed(Config, entry.value, mode.teams) then
				return
			end
			(mode :: any)[rowName] = entry.value
			refreshModeButtons()
		end)
	end
end

local teamEntries = {}
for count = 2, #Config.Teams do
	table.insert(teamEntries, { text = count .. "팀", value = count })
end
makeRow("teams", "팀 수", 60, teamEntries)

local sizeEntries = {}
for _, key in sortedKeys(Config.BoardSizes) do
	local info = Config.BoardSizes[key]
	table.insert(sizeEntries, { text = info.Name .. (if info.TwoTeamsOnly then "\n(2팀만)" else ""), value = key })
end
makeRow("size", "판", 135, sizeEntries)

local floorEntries = {}
for _, key in sortedKeys(Config.Floors) do
	local info = Config.Floors[key]
	table.insert(floorEntries, { text = (if info.Icon then info.Icon .. " " else "") .. info.Name, value = key })
end
makeRow("floor", "바닥", 210, floorEntries)

local startButton = makeButton(modePanel, "시작! (모자란 자리는 NPC)", UDim2.new(0, 320, 0, 64), UDim2.new(0.5, -160, 0, 300))
startButton.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
startButton.TextSize = 24
startButton.Activated:Connect(function()
	Remotes.SelectMode:FireServer({ teams = mode.teams, size = mode.size, floor = mode.floor })
end)
refreshModeButtons()

-- 내가 지금 골라야 하는 팀 (없으면 nil)
local function teamToPick(): number?
	for team = 1, (state:GetAttribute("TeamCount") or 2) do
		if state:GetAttribute("Team" .. team .. "Owner") == player.UserId and not state:GetAttribute("Team" .. team .. "Ready") then
			return team
		end
	end
	return nil
end

local function refresh()
	local phase = state:GetAttribute("Phase")
	local choosingMode = phase == "ModeSelect"
	local selecting = phase == "TeamSelect"
	local isHost = state:GetAttribute("HostUserId") == player.UserId
	local team = if selecting then teamToPick() else nil
	gui.Enabled = selecting or choosingMode
	modePanel.Visible = choosingMode and isHost
	panel.Visible = team ~= nil
	waitingLabel.Visible = (selecting and team == nil) or (choosingMode and not isHost)
	waitingLabel.Text = if choosingMode then "방장이 몇 팀으로 할지 고르는 중..." else "상대가 팀을 고르는 중..."
	if team then
		title.Text = Config.Teams[team].Name .. " 팀을 골라요!"
		title.TextColor3 = Config.Teams[team].Color
		-- 3·4팀은 자리가 좁아서 알이 너무 많은 추천 팀은 못 고른다
		local capacity = currentCapacity()
		for index, card in presetCards do
			local fits = #Config.PresetTeams[index].Pieces <= capacity
			card.Active = fits
			card.AutoButtonColor = fits
			card.BackgroundTransparency = if fits then 0 else 0.6
		end
	end
end

local watched = { "Phase", "TeamCount", "HostUserId", "BoardSizeKey" }
for watchTeam = 1, #Config.Teams do
	table.insert(watched, "Team" .. watchTeam .. "Ready")
	table.insert(watched, "Team" .. watchTeam .. "Owner")
end
for _, name in watched do
	state:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

RunService.Heartbeat:Connect(function()
	if gui.Enabled then
		local left = math.max(0, (state:GetAttribute("SelectEndsAt") or 0) - workspace:GetServerTimeNow())
		timerLabel.Text = string.format("%d초", math.ceil(left))
		modeTimer.Text = timerLabel.Text
	end
end)
