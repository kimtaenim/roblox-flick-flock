-- 서버 오류를 화면에 보여 주기 위해 적어 둔다 (ErrorScreen 이 빨간 글씨로 띄움)
-- 다른 모듈을 하나도 안 불러서, 게임 코드가 고장 나도 이건 돈다
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

ScriptContext.Error:Connect(function(message, trace)
	local text = tostring(message) .. "\n" .. tostring(trace)
	ReplicatedStorage:SetAttribute("ServerError", string.sub(text, 1, 600))
end)
-- 서버가 살아 있다는 표시 (안 보이면 서버 코드가 아예 안 돈 것)
ReplicatedStorage:SetAttribute("ServerAlive", true)
