-- 판 모양 계산 (숫자만 써서 Studio 없이도 테스트할 수 있다)
-- 사각형과 육각형 모두 "마주 보는 평평한 변" 묶음으로 나타낸다.
-- 변 하나 = 판 가운데에서 그 변까지 방향(nx, nz)과 거리(half). 반대쪽 변은 자동으로 같이.
local BoardShape = {}

export type Edge = { nx: number, nz: number, half: number, length: number }

-- 팀 수에 맞는 판 모양. setting = Config.BoardShape ("Auto" 면 3팀은 육각형, 나머지는 사각형)
function BoardShape.pick(setting: string, teamCount: number): string
	if setting == "Square" or setting == "Hexagon" then
		return setting
	end
	return if teamCount == 3 then "Hexagon" else "Square"
end

-- size = 마주 보는 변 사이 거리
function BoardShape.edges(shape: string, size: number): { Edge }
	local half = size / 2
	if shape == "Hexagon" then
		-- 육각형 : 변 길이 = size / √3. 0도(+Z)·60도·120도 방향에 평평한 변
		local side = size / math.sqrt(3)
		local list = {}
		for index = 0, 2 do
			local angle = math.rad(index * 60)
			table.insert(list, { nx = math.sin(angle), nz = math.cos(angle), half = half, length = side })
		end
		return list
	end
	return {
		{ nx = 1, nz = 0, half = half, length = size },
		{ nx = 0, nz = 1, half = half, length = size },
	}
end

-- 판 가운데에서 가장 먼 꼭짓점까지 거리 (빈 자리 찾을 때 범위)
function BoardShape.reach(shape: string, size: number): number
	if shape == "Hexagon" then
		return size / math.sqrt(3)
	end
	return size / 2 * math.sqrt(2)
end

-- (x, z) 가 판 안인지. margin 만큼 안쪽까지만 인정
function BoardShape.inside(edges: { Edge }, x: number, z: number, margin: number?): boolean
	local gap = margin or 0
	for _, edge in edges do
		if math.abs(x * edge.nx + z * edge.nz) > edge.half - gap then
			return false
		end
	end
	return true
end

-- 점 (x, z) 에서 방향 (dx, dz) 로 갔을 때 판 가장자리까지 거리
function BoardShape.distanceToEdge(edges: { Edge }, x: number, z: number, dx: number, dz: number): number
	local best = math.huge
	for _, edge in edges do
		local along = dx * edge.nx + dz * edge.nz
		local position = x * edge.nx + z * edge.nz
		if along > 1e-6 then
			best = math.min(best, (edge.half - position) / along)
		elseif along < -1e-6 then
			best = math.min(best, (-edge.half - position) / along)
		end
	end
	return math.max(best, 0)
end

return BoardShape
