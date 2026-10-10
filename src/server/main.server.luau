-- 서버 시작 스크립트
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

print(("[%s] 서버 시작"):format(Config.GameName))
