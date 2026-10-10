-- 모든 숫자는 여기에만! 숫자를 바꾸고 Play 해 보세요.
local Config = {}

-- 판
Config.BoardSize = 64 -- 판 한 변 길이 (스터드)
Config.BoardThickness = 2
Config.BoardHeight = 6 -- 판 윗면 높이
Config.BoardColor = Color3.fromRGB(196, 154, 108)
Config.BoardFriction = 0.3 -- 판이 미끄러운 정도 (작을수록 미끄러움)
Config.FallDepth = 3 -- 판 윗면보다 이만큼 아래로 떨어지면 탈락

-- 알 공통
Config.PieceDiameter = 4 -- 크기 1 알의 지름
Config.FlatHeight = 1 -- 크기 1 납작 알의 두께
Config.RoundHeight = 1.8 -- 크기 1 둥근 알의 높이 (볼록한 정도)
Config.MassUnit = 10 -- 질량 1 = 실제 무게 몇

-- 알 종류 : 다섯 값 (shape, size, mass, hp, ability) + 미끄러움(friction)·튕김(bounce)
-- shape : "Flat" 납작 원기둥 / "Round" 볼록한 타원체 (바둑알처럼)
-- friction 이 작을수록 멀리 가고, bounce 가 클수록 세게 튄다 (0~1)
Config.Pieces = {
	King = { shape = "Flat", size = 2, mass = 4, hp = 150, ability = nil, friction = 0.3, bounce = 0.4 }, -- 왕알
	Flat = { shape = "Flat", size = 1, mass = 1, hp = 0, ability = nil, friction = 0.3, bounce = 0.4 }, -- 납작 알
	Round = { shape = "Round", size = 1, mass = 1, hp = 0, ability = nil, friction = 0.1, bounce = 0.7 }, -- 둥근 알
	Half = { shape = "Round", size = 0.5, mass = 0.5, hp = 0, ability = nil, friction = 0.12, bounce = 0.7 }, -- 0.5 알
}
Config.CanFlickKing = true -- 왕알도 튕길 수 있음 (무거워서 멀리 안 감)

-- 데미지 (왕알)
Config.DamageScale = 0.6 -- damage = 충돌 속도 × 때린 알 질량 × DamageScale
Config.DamageMinSpeed = 4 -- 이보다 느리게 부딪히면 데미지 없음
Config.DamageCooldown = 0.3 -- 같은 알이 연달아 때릴 때 간격 (초)

-- 팀 진영 : 빨강은 +Z, 파랑은 -Z
Config.Teams = {
	{ Name = "빨강", Color = Color3.fromRGB(226, 70, 70) },
	{ Name = "파랑", Color = Color3.fromRGB(64, 120, 230) },
}
Config.KingRowDistance = 22 -- 판 가운데에서 왕알까지
Config.RowDistances = { 9, 14 } -- 판 가운데에서 알 줄까지 (앞줄, 뒷줄)
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
-- 효과가 유지되는 턴 수 (능력을 쓴 내 턴도 1로 센다)
-- 유령·똥 2 = 상대 턴 한 번 동안 / 자석 3 = 상대 턴 + 내 다음 턴 동안 (그동안 나도 상대도 못 움직임)
Config.PoopSlowFactor = 0.35 -- 똥을 밟으면 속도가 이만큼으로 줄어듦
Config.FootprintTime = 4 -- 똥 발자국이 남는 시간 (초)
Config.EffectTurns = { Ghost = 2, Poop = 2, Magnet = 3 }
-- 소환 확률 (합이 100)
-- 소환 : 하늘에서 거창한 것이 나타나 상대 진영을 공격한다 (진짜 물체가 떨어져서 부딪힘).
-- Chance 합은 100. Result 는 Summon.lua 안의 소환 이름.
Config.SummonTable = {
	{ Name = "드래곤", Icon = "🐉", Chance = 20, Result = "Dragon" }, -- 불덩이를 퍼붓는다 (대박)
	{ Name = "운석", Icon = "☄️", Chance = 25, Result = "Meteor" }, -- 거대한 운석이 왕알에 쾅
	{ Name = "블리자드", Icon = "❄️", Chance = 25, Result = "Blizzard" }, -- 얼음덩이가 우수수
	{ Name = "고래", Icon = "🐋", Chance = 20, Result = "Whale" }, -- 고래가 철퍼덕
	{ Name = "꽝", Icon = "🐦", Chance = 10, Result = "Pigeon" }, -- 비둘기가 똥만 싸고 감
}
-- 소환물 : 떨어지는 물체 하나의 크기·무게·왕알 데미지
Config.Summons = {
	Fireball = { Size = 3, Mass = 1.5, KingDamage = 15, Count = 5 }, -- 드래곤 불덩이
	Meteor = { Size = 8, Mass = 4, KingDamage = 40 },
	Ice = { Size = 2.5, Mass = 1, KingDamage = 8, Count = 10 }, -- 블리자드 얼음
	Whale = { Size = 16, Mass = 6, KingDamage = 30 },
	PigeonPoop = { Size = 1, Mass = 0.1, KingDamage = 1 },
}
Config.SummonLifetime = 4 -- 떨어진 물체가 사라지기까지 (초)

-- 혼자 할 때
Config.SoloMode = "Npc" -- "Npc": 파랑은 컴퓨터 / "BothTeams": 혼자 빨강·파랑 둘 다 조종
Config.SoloWaitTime = 3 -- 친구를 이만큼 기다린 뒤 혼자 시작 (초)

-- NPC (컴퓨터)
Config.NpcName = "NPC"
Config.NpcThinkTime = 1.5 -- 쏘기 전에 생각하는 척 (초)
Config.NpcAimErrorDegrees = 10 -- 조준이 빗나가는 정도 (클수록 쉬움)
Config.NpcMistakeChance = 0.25 -- 엉뚱한 데로 치는 확률 (0~1, 클수록 쉬움)
Config.NpcPowerError = 0.25 -- 세기가 틀리는 정도 (0.25 = ±25%, 클수록 쉬움)
Config.NpcPowerBoost = 1.25 -- 계산한 세기보다 이만큼 세게 (클수록 과감)
Config.NpcAbilityChance = 0.35 -- 능력 알이 있을 때 능력을 쓸 확률

-- 카메라
Config.CameraDistance = 50 -- 처음 카메라가 판 가운데에서 떨어진 거리
Config.CameraPitch = 55 -- 처음 내려다보는 각도 (도). 90 = 바로 위
Config.CameraLookSpeed = 0.3 -- 끌어서 둘러보는 속도
Config.CameraMoveSpeed = 40 -- 키보드로 움직이는 속도 (스터드/초)
Config.CameraFastMultiplier = 2.5 -- Shift 누르면 몇 배 빠르게
Config.CameraWheelStep = 6 -- 휠 한 칸에 앞뒤로 움직이는 거리
Config.CameraLimit = 250 -- 카메라가 갈 수 있는 끝 (판 가운데에서)
Config.ShakeStrength = 1.2 -- 폭발 때 화면 흔들림

-- 소리 : 로블록스에 기본으로 들어 있는 소리를 음 높이(Pitch)를 바꿔 여러 가지로 쓴다.
-- Pitch 1 = 원래 소리, 0.5 = 굵고 느리게, 2 = 다람쥐처럼 빠르게. { 최소, 최대 } 사이에서 무작위.
-- 다른 소리를 쓰고 싶으면 Id 를 "rbxassetid://숫자" 로 바꾸면 된다.
local OOF = "rbxasset://sounds/uuhhh.mp3" -- "웁!"
local JUMP = "rbxasset://sounds/action_jump.mp3" -- 뿅
local LAND = "rbxasset://sounds/action_jump_land.mp3" -- 쿵
local FALL = "rbxasset://sounds/action_falling.ogg" -- 휘이잉
local SWIM = "rbxasset://sounds/action_swim.mp3" -- 슈욱
local SPLASH = "rbxasset://sounds/impact_water.mp3" -- 첨벙
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3" -- 톡톡
local GETUP = "rbxasset://sounds/action_get_up.mp3" -- 으쌰

Config.SoundVolume = 0.7
Config.Sounds = {
	Flick = { Id = JUMP, Pitch = { 0.9, 1.3 } }, -- 튕길 때
	Hit = { Id = LAND, Pitch = { 0.9, 1.2 } }, -- 알끼리 부딪힐 때 (작은 알일수록 높은 소리)
	KingHit = { Id = OOF, Pitch = { 0.85, 1.15 } }, -- 왕알이 맞을 때
	KingDown = { Id = OOF, Pitch = { 0.45, 0.5 }, Volume = 1 }, -- 왕알이 쓰러질 때
	Out = { Id = FALL, Pitch = { 1, 1.3 } }, -- 판 밖으로 떨어질 때
	OutCry = { Id = OOF, Pitch = { 1.7, 2.1 } }, -- 떨어지면서 지르는 소리
	TurnStart = { Id = STEP, Pitch = { 1.6, 1.6 }, Volume = 0.5 }, -- 내 차례
	Ability = { Id = SWIM, Pitch = { 1.5, 1.7 } }, -- 능력 공통
	Explosion = { Id = LAND, Pitch = { 0.3, 0.35 }, Volume = 1 },
	Giant = { Id = GETUP, Pitch = { 0.4, 0.45 }, Volume = 1 },
	Teleport = { Id = SWIM, Pitch = { 2.2, 2.4 } },
	Ghost = { Id = SWIM, Pitch = { 0.5, 0.55 } },
	Magnet = { Id = STEP, Pitch = { 0.4, 0.5 }, Volume = 1 },
	Summon = { Id = JUMP, Pitch = { 1.6, 1.7 } },
	Clone = { Id = JUMP, Pitch = { 1.9, 2.1 } },
	Roar = { Id = OOF, Pitch = { 0.25, 0.3 }, Volume = 1 }, -- 드래곤 울음
	Wind = { Id = SWIM, Pitch = { 0.35, 0.4 }, Volume = 1 }, -- 눈보라
	Boom = { Id = LAND, Pitch = { 0.2, 0.25 }, Volume = 1 }, -- 운석 쾅
	Splash = { Id = SPLASH, Pitch = { 0.6, 0.7 }, Volume = 1 }, -- 고래 철퍼덕
	Thud = { Id = LAND, Pitch = { 0.8, 1.2 }, Volume = 0.6 }, -- 불덩이·얼음 떨어짐
	Poop = { Id = SPLASH, Pitch = { 0.5, 0.55 }, Volume = 1 }, -- 뿌직
	PoopStep = { Id = SPLASH, Pitch = { 0.75, 0.9 } }, -- 똥 밟음
	-- 대사할 때 목소리
	KingTalk = { Id = GETUP, Pitch = { 0.6, 0.7 }, Volume = 0.8 }, -- 왕알 : 굵게
	Talk = { Id = STEP, Pitch = { 1.3, 1.6 }, Volume = 0.5 }, -- 일반 알 : 톡
	Cute = { Id = JUMP, Pitch = { 2.2, 2.8 } }, -- 쪼꼬미 : 삐약
}
-- 여러 음을 이어서 (멜로디). Pitches 순서대로 Gap 초 간격.
Config.Melodies = {
	Win = { Sound = "Flick", Pitches = { 1, 1.26, 1.5, 2 }, Gap = 0.15 },
	Jackpot = { Sound = "Flick", Pitches = { 1.5, 1.9, 2.25, 3 }, Gap = 0.08 },
	Draw = { Sound = "KingHit", Pitches = { 1, 0.8 }, Gap = 0.35 },
	Clone = { Sound = "Clone", Pitches = { 1.8, 2.2 }, Gap = 0.12 },
}
Config.HitSoundMinSpeed = 6 -- 이보다 느리게 부딪히면 소리 안 남
Config.HitSoundCooldown = 0.12 -- 같은 알 소리 간격 (초)

-- 대사 (말풍선). 마음대로 고치고 늘려도 된다! 목록에서 하나를 무작위로 고른다.
-- King = 왕알, Normal = 납작·둥근 알, Small = 쪼꼬미(0.5 알) — 쪼꼬미는 귀여운 소리만 낸다.
Config.Lines = {
	King = {
		Start = { "나를 지켜라!", "왕이 나가신다!", "덤벼라~!" },
		Flick = { "왕도 움직인다!", "영차!", "비켜라~!" },
		Hit = { "아야!", "감히 왕을!", "으윽, 내 왕관!", "그만 때려~" },
		LowHp = { "살려줘~!", "나 이제 힘없어…", "도와줘 얘들아!" },
		Out = { "왕이 떨어진다아아~", "안 돼애애~!" },
		Win = { "내가 진짜 왕이다!", "이겼다! 만세!" },
	},
	Normal = {
		Flick = { "간다~!", "날아라!", "받아랏!", "슝~!", "돌격!" },
		Hit = { "으악!", "아얏!", "깜짝이야!", "왜 때려~" },
		Out = { "안녀어엉~", "으아아아~", "나 떨어져어~" },
		Win = { "우리가 이겼다!", "야호!" },
	},
	Small = {
		Flick = { "삐약!", "뿅!", "쪼꼬미 출동!", "삐삐!" },
		Hit = { "히잉!", "삐잉~", "앙!" },
		Out = { "삐야아아~", "히이잉~" },
		Win = { "꺄르륵~", "뿌잉뿌잉!" },
	},
	-- 능력 쓸 때 (능력 알이 외친다)
	Ability = {
		Explosion = { "펑 간다!", "다 비켜!" },
		Summon = { "나와라 드래곤!", "하늘이시여~!", "소환!!" },
		Clone = { "분신술!", "나 둘! 셋!" },
		Giant = { "커져라!", "나 엄청 크다!" },
		Teleport = { "순간이동!", "슝!" },
		Magnet = { "꼼짝 마!", "착 붙었다!" },
		Ghost = { "부우~ 유령이다~", "날 못 만지지~" },
		Poop = { "뿌지직!", "밟지 마~ 밟으면 큰일나~" },
	},
}
Config.SpeechChance = { Start = 1, Flick = 0.6, Hit = 0.5, LowHp = 1, Out = 1, Win = 1, Ability = 1 } -- 대사할 확률
Config.SpeechTime = 2.2 -- 말풍선이 떠 있는 시간 (초)
Config.SpeechCooldown = 1.5 -- 같은 알이 다시 말하기까지 (초)
Config.KingLowHpRatio = 0.3 -- 왕알 HP 가 이 비율 아래로 내려가면 "살려줘~"

return Config
