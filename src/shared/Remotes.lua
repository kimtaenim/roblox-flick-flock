-- 서버와 클라이언트가 주고받는 이벤트와 게임 상태
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = { "Flick" }

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
	-- Phase : Waiting / Aiming / Moving / GameOver
	-- CurrentTeam : 1 또는 2
	-- Winner : 0 없음, 1·2 이긴 팀, -1 무승부
	-- Team1Owner / Team2Owner : 조종하는 플레이어 UserId
	local state = Instance.new("Folder")
	state.Name = "GameState"
	state:SetAttribute("Phase", "Waiting")
	state:SetAttribute("CurrentTeam", 1)
	state:SetAttribute("Winner", 0)
	state:SetAttribute("Team1Owner", 0)
	state:SetAttribute("Team2Owner", 0)
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
