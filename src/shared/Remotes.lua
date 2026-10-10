-- 서버와 클라이언트가 주고받는 이벤트와 게임 상태
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Flick : 클라 → 서버 (알, 방향, 세기)
-- UseAbility : 클라 → 서버 (능력 알)
-- SelectMode : 클라 → 서버 { teams = 2~4, size = Config.BoardSizes 이름, floor = Config.Floors 이름 } (방장만)
-- SelectTeam : 클라 → 서버 (추천 팀 번호 또는 { Flat = n, Round = n, Half = n, Ability = n })
-- Effect : 서버 → 클라 (종류, 값...) 화면 흔들기·큰 글씨
local EVENT_NAMES = { "Flick", "UseAbility", "SelectMode", "SelectTeam", "Effect" }

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		Remotes[name] = event
	end
	folder.Parent = ReplicatedStorage

	-- 게임 상태는 이 폴더의 Attribute 로 모두에게 보인다
	-- Phase : Waiting / ModeSelect / TeamSelect / Aiming / Moving / GameOver
	-- TeamCount : 이번 판 팀 수 (2~4)
	-- HostUserId : 모드를 고르는 방장
	-- CurrentTeam : 지금 차례 팀 번호
	-- Winner : 0 없음, 팀 번호 = 이긴 팀, -1 무승부
	-- WinReason : 이긴 이유 글
	-- Team{n}Owner : 조종하는 플레이어 UserId (-1 = NPC, 0 = 없음)
	-- Team{n}Ready : 팀 고르기 끝났는지
	-- Team{n}Out : 탈락했는지
	-- SelectEndsAt : 고르기 마감 시각 (workspace:GetServerTimeNow 기준)
	local state = Instance.new("Folder")
	state.Name = "GameState"
	state:SetAttribute("Phase", "Waiting")
	state:SetAttribute("TeamCount", 2)
	state:SetAttribute("BoardSizeKey", "Normal") -- Config.BoardSizes 이름
	state:SetAttribute("FloorKey", "Wood") -- Config.Floors 이름
	state:SetAttribute("HostUserId", 0)
	state:SetAttribute("CurrentTeam", 1)
	state:SetAttribute("Winner", 0)
	state:SetAttribute("WinReason", "")
	for team = 1, 4 do
		state:SetAttribute("Team" .. team .. "Owner", 0)
		state:SetAttribute("Team" .. team .. "Ready", false)
		state:SetAttribute("Team" .. team .. "Out", false)
	end
	state:SetAttribute("SelectEndsAt", 0)
	state.Parent = ReplicatedStorage
	Remotes.State = state
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENT_NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
	Remotes.State = ReplicatedStorage:WaitForChild("GameState")
end

return Remotes
