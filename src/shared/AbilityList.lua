-- 능력 목록. 이름 바꾸고 싶으면 Name 만 고치세요.
-- Id 는 src/server/Abilities 폴더 안 파일 이름과 같아야 한다.
local AbilityList = {
	{ Id = "Explosion", Name = "폭발", Icon = "💥", Help = "내 알이 터지며 주변 알을 날려요" },
	{ Id = "Summon", Name = "소환", Icon = "🎁", Help = "무작위 알이 하나 나와요" },
	{ Id = "Clone", Name = "분신", Icon = "👯", Help = "옆에 0.5 알 2개가 생겨요" },
	{ Id = "Giant", Name = "거대화", Icon = "🦖", Help = "내 알이 2배로 커져요" },
	{ Id = "Teleport", Name = "텔레포트", Icon = "✨", Help = "내 알이 판 가운데로 순간이동" },
	{ Id = "Magnet", Name = "자석", Icon = "🧲", Help = "바닥에 딱 붙어요. 나도 상대도 못 움직여요" },
	{ Id = "Poop", Name = "똥알", Icon = "💩", Help = "상대가 밟으면 물컹! 확 느려져요" },
	{ Id = "Ghost", Name = "유령", Icon = "👻", Help = "다른 알을 스르륵 통과해요" },
}

local byId = {}
for _, ability in AbilityList do
	byId[ability.Id] = ability
end

local Module = {
	List = AbilityList,
}

function Module.get(id: string?)
	if id == nil then
		return nil
	end
	return byId[id]
end

return Module
