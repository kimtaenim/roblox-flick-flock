-- 클라이언트 시작 스크립트
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

print(("[%s] %s 접속"):format(Config.GameName, Players.LocalPlayer.Name))
