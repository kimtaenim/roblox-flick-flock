-- 능력 목록. 이름 바꾸고 싶으면 Name 만 고치세요.
-- Id 는 src/server/Abilities 폴더 안 파일 이름과 같아야 한다.
local AbilityList = {
	{ Id = "Explosion", Name = "폭발", Icon = "💥", Help = "내 알이 터지며 주변 알을 날려요" },
	{ Id = "Summon", Name = "소환", Icon = "🐉", Help = "드래곤? 운석? 고래? 뭐가 나올까!" },
	{ Id = "Clone", Name = "분신", Icon = "👯", Help = "옆에 0.5 알 2개가 생겨요" },
	{ Id = "Giant", Name = "거대화", Icon = "🦖", Help = "내 알이 2배로 커져요" },
	{ Id = "Teleport", Name = "텔레포트", Icon = "✨", Help = "내 알이 판 가운데로 순간이동" },
	{ Id = "Magnet", Name = "자석", Icon = "🧲", Help = "아주 무거워져서 잘 안 밀려요. 때리면 되튕겨요" },
	{ Id = "Ghost", Name = "유령", Icon = "👻", Help = "다른 알을 스르륵 통과해요 (계속 쓸 수 있어요)" },
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
