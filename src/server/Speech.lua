-- 알 대사 (말풍선 + 목소리). 대사는 Config.Lines 에서 고친다.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Effects = require(script.Parent:WaitForChild("Effects"))

local Speech = {}

local lastSpoke: { [BasePart]: number } = {}
-- 알마다 지금 떠 있는 말풍선 (새로 말하면 이전 것은 지운다)
local currentBubble: { [BasePart]: BillboardGui } = {}

-- 알 종류 → 대사 목록 묶음 이름
local function voiceGroup(kind: string?): string
	if kind == "King" then
		return "King"
	elseif kind == "Half" then
		return "Small"
	end
	return "Normal"
end

local VOICE_SOUND = { King = "KingTalk", Normal = "Talk", Small = "Cute" }

local function pick(list: { string }?): string?
	if not list or #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

-- 이 알 캐릭터의 대사 목록 (없으면 nil)
local function characterLines(piece: BasePart, group: string, event: string): { string }?
	local name = piece:GetAttribute("Character")
	local list = Config.Characters[group]
	if not name or not list then
		return nil
	end
	for _, character in list do
		if typeof(character) == "table" and character.Name == name and character.Lines then
			return character.Lines[event]
		end
	end
	return nil
end

-- "용감이: 돌격!!" 처럼 이름 붙이기
local function withName(piece: BasePart, text: string): string
	local name = piece:GetAttribute("Character")
	if typeof(name) == "string" then
		return name .. ": " .. text
	end
	return text
end

-- 말풍선 만들기. 알이 사라지면 그 자리에 남아서 마저 보인다.
local function showBubble(piece: BasePart, text: string, color: Color3)
	local old = currentBubble[piece]
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	currentBubble[piece] = gui
	gui.Destroying:Connect(function()
		if currentBubble[piece] == gui then
			currentBubble[piece] = nil
		end
	end)
	gui.Name = "Speech"
	gui.Size = UDim2.fromOffset(230, 46)
	-- 왕알은 HP 막대 위로
	local extra = if piece:FindFirstChild("HpBar") then 3 else 0
	gui.StudsOffsetWorldSpace = Vector3.new(0, piece.Size.Y / 2 + 3.5 + extra, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = piece

	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.Font = Enum.Font.GothamBold
	bubble.TextScaled = true
	bubble.TextColor3 = color
	bubble.Text = text
	bubble.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = bubble

	gui.Parent = Effects.folder()
	Debris:AddItem(gui, Config.SpeechTime)

	-- 알이 사라지면 (판 밖, 폭발) 마지막 자리에 투명한 받침을 두고 그 위에 띄운다
	local lastPosition = piece.Position
	local connection
	connection = piece.AncestryChanged:Connect(function(_, parent)
		if parent == nil and gui.Parent then
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.one
			anchor.Position = lastPosition
			anchor.Parent = Effects.folder()
			gui.Adornee = anchor
			Debris:AddItem(anchor, Config.SpeechTime)
		end
		connection:Disconnect()
	end)
	task.delay(Config.SpeechTime, function()
		if connection.Connected then
			connection:Disconnect()
		end
	end)
	task.spawn(function()
		while gui.Parent and piece.Parent do
			lastPosition = piece.Position
			task.wait(0.1)
		end
	end)
end

-- event : "Start" "Flick" "Hit" "LowHp" "Out" "Win"
-- force 면 확률·쉬는 시간 무시
function Speech.say(piece: BasePart, event: string, force: boolean?)
	if not Config.ShowSpeech then
		return
	end
	local now = os.clock()
	if not force then
		if math.random() > (Config.SpeechChance[event] or 0) then
			return
		end
		if lastSpoke[piece] and now - lastSpoke[piece] < Config.SpeechCooldown then
			return
		end
	end
	local group = voiceGroup(piece:GetAttribute("Kind") :: string?)
	-- 캐릭터만의 대사가 있으면 그것, 없으면 보통 대사
	local text = pick(characterLines(piece, group, event)) or pick(Config.Lines[group][event])
	if not text then
		return
	end
	text = withName(piece, text)
	lastSpoke[piece] = now

	local team = piece:GetAttribute("Team") :: number?
	local color = if team and Config.Teams[team] then Config.Teams[team].Color else Color3.new(0, 0, 0)
	showBubble(piece, text, color)
	Effects.sound(VOICE_SOUND[group], piece)
end

-- 능력 쓸 때 외치기
function Speech.sayAbility(piece: BasePart, abilityId: string)
	if not Config.ShowSpeech then
		return
	end
	local text = pick(Config.Lines.Ability[abilityId])
	if not text then
		return
	end
	text = withName(piece, text)
	local team = piece:GetAttribute("Team") :: number?
	local color = if team and Config.Teams[team] then Config.Teams[team].Color else Color3.new(0, 0, 0)
	lastSpoke[piece] = os.clock()
	showBubble(piece, text, color)
end

return Speech
