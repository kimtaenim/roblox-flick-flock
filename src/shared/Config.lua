-- 모든 숫자는 여기에만! 숫자를 바꾸고 Play 해 보세요.
local Config = {}

-- 판
Config.BoardSize = 48 -- 판 한 변 길이 (스터드)
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

-- 알 종류 : 다섯 값 (shape, size, mass, hp, ability) + 굴러가다 멈추는 힘(rollSlow)
-- shape : "Flat" 납작 원기둥 / "Round" 공
Config.Pieces = {
	King = { shape = "Flat", size = 2, mass = 4, hp = 100, ability = nil, rollSlow = 0 }, -- 왕알
	Flat = { shape = "Flat", size = 1, mass = 1, hp = 0, ability = nil, rollSlow = 0 }, -- 납작 알
	Round = { shape = "Round", size = 1, mass = 1, hp = 0, ability = nil, rollSlow = 40 }, -- 둥근 알
	Half = { shape = "Round", size = 0.5, mass = 0.5, hp = 0, ability = nil, rollSlow = 45 }, -- 0.5 알
}
Config.CanFlickKing = false -- 왕알도 튕길 수 있게 하려면 true

-- 데미지 (왕알)
Config.DamageScale = 0.6 -- damage = 충돌 속도 × 때린 알 질량 × DamageScale
Config.DamageMinSpeed = 4 -- 이보다 느리게 부딪히면 데미지 없음
Config.DamageCooldown = 0.3 -- 같은 알이 연달아 때릴 때 간격 (초)

-- 팀 진영 : 빨강은 +Z, 파랑은 -Z
Config.Teams = {
	{ Name = "빨강", Color = Color3.fromRGB(226, 70, 70) },
	{ Name = "파랑", Color = Color3.fromRGB(64, 120, 230) },
}
Config.KingRowDistance = 18 -- 판 가운데에서 왕알까지
Config.RowDistances = { 6, 11 } -- 판 가운데에서 알 줄까지 (앞줄, 뒷줄)
Config.PieceSpacing = 6 -- 한 줄 안 알 사이 간격
Config.PiecesPerRow = 7

-- 팀 선택 (예산제)
Config.Budget = 12
Config.Prices = { Flat = 2, Round = 2, Ability = 3, Half = 1 }
Config.TeamSelectTime = 40 -- 이 시간 안에 안 고르면 첫 번째 추천 팀 (초)
-- 추천 팀 : 알 목록. { kind, ability } — ability 가 있으면 능력 알
Config.PresetTeams = {
	{
		Name = "수비팀",
		Description = "납작 알이 단단하게 막아요",
		Pieces = { { "Flat" }, { "Flat" }, { "Flat" }, { "Flat" }, { "Flat", "Magnet" } },
	},
	{
		Name = "돌격팀",
		Description = "둥근 알로 멀리 쾅!",
		Pieces = { { "Round" }, { "Round" }, { "Round" }, { "Round", "Explosion" }, { "Round", "Giant" } },
	},
	{
		Name = "꼬마군단",
		Description = "작은 알이 우르르",
		Pieces = { { "Half" }, { "Half" }, { "Half" }, { "Half" }, { "Half" }, { "Half" }, { "Round", "Clone" }, { "Flat", "Summon" } },
	},
	{
		Name = "마법팀",
		Description = "신기한 능력이 가득",
		Pieces = { { "Flat" }, { "Flat", "Teleport" }, { "Round", "Ghost" }, { "Flat", "Poop" } },
	},
}

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

-- 능력
Config.ExplosionRadius = 14
Config.ExplosionPower = 900 -- 가운데에서 받는 임펄스 (멀수록 약해짐)
Config.ExplosionKingDamage = 30 -- 가운데에서 왕알이 받는 데미지 (폭발로는 HP 1 아래로 안 내려감)
Config.ExplosionWallHeight = 6 -- 폭발 턴에 판 가장자리에 세우는 안 보이는 벽 높이
Config.GiantScale = 2 -- 거대화 배율 (크기·질량)
Config.MagnetElasticity = 1 -- 자석 알에 부딪히면 되튕기는 정도
Config.PoopSlowFactor = 0.35 -- 똥을 밟으면 속도가 이만큼으로 줄어듦
Config.FootprintTime = 4 -- 똥 발자국이 남는 시간 (초)
Config.EffectTurns = 2 -- 자석·똥·유령이 유지되는 턴 수 (내 턴 + 상대 턴)
-- 소환 확률 (합이 100)
Config.SummonTable = {
	{ Name = "꽝", Chance = 60, Result = "Half" },
	{ Name = "보통", Chance = 30, Result = "Normal" }, -- 납작 또는 둥근 알
	{ Name = "대박", Chance = 10, Result = "Ability" }, -- 능력 무작위
}

-- 혼자 할 때
Config.SoloMode = "Npc" -- "Npc": 파랑은 컴퓨터 / "BothTeams": 혼자 빨강·파랑 둘 다 조종
Config.SoloWaitTime = 3 -- 친구를 이만큼 기다린 뒤 혼자 시작 (초)

-- NPC (컴퓨터)
Config.NpcName = "NPC"
Config.NpcThinkTime = 1.5 -- 쏘기 전에 생각하는 척 (초)
Config.NpcAimErrorDegrees = 10 -- 조준이 빗나가는 정도 (클수록 쉬움)
Config.NpcPowerBoost = 1.25 -- 계산한 세기보다 이만큼 세게 (클수록 과감)
Config.NpcAbilityChance = 0.35 -- 능력 알이 있을 때 능력을 쓸 확률

-- 카메라
Config.CameraHeight = 54
Config.CameraBack = 44
Config.ShakeStrength = 1.2 -- 폭발 때 화면 흔들림

-- 소리 (rbxasset:// 또는 rbxassetid://숫자 로 바꿔도 됨)
Config.Sounds = {
	Flick = "rbxasset://sounds/swoosh.wav",
	Hit = "rbxasset://sounds/collide.wav",
	Out = "rbxasset://sounds/action_falling.mp3",
	Ability = "rbxasset://sounds/electronicpingshort.wav",
	Poop = "rbxasset://sounds/splat.wav",
}
Config.SoundVolume = 0.6

return Config
