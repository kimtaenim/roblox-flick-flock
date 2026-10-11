-- 오류가 나면 화면 왼쪽 위에 빨간 글씨로 보여 준다 (Studio 출력 창을 안 열어도 보이게)
-- 다른 모듈을 하나도 안 불러서, 게임 코드가 고장 나도 이건 돈다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local gui = Instance.new("ScreenGui")
gui.Name = "ErrorScreen"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
local label = Instance.new("TextLabel")
label.Position = UDim2.fromOffset(10, 130)
label.Size = UDim2.new(0.6, 0, 0, 200)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.fromRGB(255, 90, 90)
label.Font = Enum.Font.Code
label.TextSize = 14
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Visible = false
label.Parent = gui
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local lines = {}
local function show(text: string)
	table.insert(lines, text)
	if #lines > 3 then
		table.remove(lines, 1)
	end
	label.Text = "⚠ 오류 (이 화면을 찍어서 보내 주세요)\n" .. table.concat(lines, "\n")
	label.Visible = true
end

-- 화면 쪽 오류
ScriptContext.Error:Connect(function(message, trace)
	show("[화면] " .. string.sub(tostring(message) .. " " .. tostring(trace), 1, 400))
end)

-- 서버 쪽 오류
local function onServerError()
	local text = ReplicatedStorage:GetAttribute("ServerError")
	if typeof(text) == "string" then
		show("[서버] " .. text)
	end
end
ReplicatedStorage:GetAttributeChangedSignal("ServerError"):Connect(onServerError)
onServerError()

-- 15초가 지나도 서버가 판을 안 만들면 알린다
task.delay(15, function()
	if not ReplicatedStorage:GetAttribute("ServerAlive") then
		show("[서버] 서버 코드가 안 켜졌어요")
	elseif not workspace:FindFirstChild("Board") then
		show("[서버] 판이 안 만들어졌어요 (Board 없음)")
	end
end)
