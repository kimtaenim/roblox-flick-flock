-- 모든 숫자는 여기에만! 숫자를 바꾸고 Play 해 보세요.
local Config = {}

-- 판
Config.BoardSize = 40 -- 판 한 변 길이 (스터드)
Config.BoardThickness = 2
Config.BoardHeight = 6 -- 판 윗면 높이
Config.BoardColor = Color3.fromRGB(196, 154, 108)
Config.BoardFriction = 0.3 -- 판이 미끄러운 정도 (작을수록 미끄러움)
Config.FallDepth = 3 -- 판 윗면보다 이만큼 아래로 떨어지면 탈락

-- 알 공통
Config.PieceDiameter = 4 -- 크기 1 알의 지름
Config.FlatHeight = 1 -- 크기 1 납작 알의 두께
Config.MassUnit = 10 -- 질량 1 = 실제 무게 몇
Config.PieceFriction = 0.3
Config.PieceElasticity = 0.4 -- 튕김 정도 (0~1)

-- 알 종류 : 다섯 값 (shape, size, mass, hp, ability)
Config.Pieces = {
	Flat = { shape = "Flat", size = 1, mass = 1, hp = 0, ability = nil }, -- 납작 알
}

-- 팀
Config.Teams = {
	{ Name = "빨강", Color = Color3.fromRGB(226, 70, 70) },
	{ Name = "파랑", Color = Color3.fromRGB(64, 120, 230) },
}
Config.StartingPieces = { "Flat", "Flat", "Flat", "Flat", "Flat" } -- 1단계 팀 구성
Config.StartRowDistance = 12 -- 판 가운데에서 각 팀 줄까지 거리
Config.PieceSpacing = 6 -- 알 사이 간격

-- 튕기기
Config.FlickPower = 700 -- 최대 세기일 때 임펄스
Config.MinFlickPower = 0.05 -- 이보다 약하면 발사 안 함 (0~1)
Config.MaxDragDistance = 15 -- 이만큼 끌면 최대 세기
Config.PullBackToShoot = true -- true: 새총처럼 뒤로 끌어 쏘기, false: 끈 방향으로 쏘기

-- 턴
Config.StopSpeed = 0.5 -- 이보다 느리면 멈춘 것
Config.StopHoldTime = 1 -- 모두 멈춘 채 이 시간이 지나면 턴 넘김 (초)
Config.MaxMoveTime = 12 -- 아무리 오래 움직여도 이 시간 뒤엔 턴 넘김 (초)
Config.RestartDelay = 6 -- 승패가 난 뒤 새 판까지 (초)

-- 혼자 할 때
Config.SoloMode = "Npc" -- "Npc": 파랑은 컴퓨터 / "BothTeams": 혼자 빨강·파랑 둘 다 조종
Config.SoloWaitTime = 3 -- 친구를 이만큼 기다린 뒤 혼자 시작 (초)

-- NPC (컴퓨터)
Config.NpcName = "NPC"
Config.NpcThinkTime = 1.5 -- 쏘기 전에 생각하는 척 (초)
Config.NpcAimErrorDegrees = 10 -- 조준이 빗나가는 정도 (클수록 쉬움)
Config.NpcPowerBoost = 1.25 -- 계산한 세기보다 이만큼 세게 (클수록 과감)

-- 카메라
Config.CameraHeight = 45
Config.CameraBack = 38

return Config
