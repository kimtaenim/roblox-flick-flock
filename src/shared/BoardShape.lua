-- 판 모양 계산 (숫자만 써서 Studio 없이도 테스트할 수 있다)
-- 모양 : "Square" 사각형 / "Hexagon" 육각형 / "Circles" 원 여러 개를 합친 모양 (호리병, 곰돌이 얼굴)
-- 가운데 구멍(화산)도 있을 수 있다 : 구멍 안은 판 밖과 같다.
local BoardShape = {}

export type Edge = { nx: number, nz: number, half: number, length: number }
export type Circle = { x: number, z: number, r: number }
export type Shape = {
	kind: string,
	size: number,
	edges: { Edge }?, -- 사각형·육각형 : 마주 보는 평평한 변 묶음
	circles: { Circle }?, -- 원들을 합친 모양 (호리병·곰돌이)
	holeRadius: number, -- 가운데 구멍 반지름 (0 = 구멍 없음)
	reach: number, -- 판 가운데에서 가장 먼 곳까지 거리
}

-- 팀 수에 맞는 기본 모양 (3팀은 육각형, 2·4팀은 사각형)
function BoardShape.pick(setting: string, teamCount: number): string
	if setting == "Square" or setting == "Hexagon" or setting == "Circles" then
		return setting
	end
	return if teamCount == 3 then "Hexagon" else "Square"
end

-- size : 사각형·육각형은 마주 보는 변 사이 거리. circles : "Circles" 일 때 { { x, z, 반지름 }, ... }
function BoardShape.create(kind: string, size: number, holeRadius: number?, circles: { { number } }?): Shape
	local half = size / 2
	local shape: Shape = { kind = kind, size = size, holeRadius = holeRadius or 0, reach = half }
	if kind == "Hexagon" then
		-- 변 길이 = size / √3. 0도(+Z)·60도·120도 방향에 평평한 변
		local side = size / math.sqrt(3)
		local edges = {}
		for index = 0, 2 do
			local angle = math.rad(index * 60)
			table.insert(edges, { nx = math.sin(angle), nz = math.cos(angle), half = half, length = side })
		end
		shape.edges = edges
		shape.reach = side
	elseif kind == "Circles" then
		-- 원 여러 개를 겹쳐 놓은 모양. 호리병 = 같은 원 두 개, 곰돌이 = 얼굴 + 귀 두 개
		local list = {}
		local reach = 0
		local source: { { number } } = circles or { { 0, 0, half } }
		for _, entry in source do
			table.insert(list, { x = entry[1], z = entry[2], r = entry[3] })
			reach = math.max(reach, math.sqrt(entry[1] ^ 2 + entry[2] ^ 2) + entry[3])
		end
		shape.circles = list
		shape.reach = reach
	else
		shape.edges = {
			{ nx = 1, nz = 0, half = half, length = size },
			{ nx = 0, nz = 1, half = half, length = size },
		}
		shape.reach = half * math.sqrt(2)
	end
	return shape
end

-- (x, z) 가 판 위인지. margin 만큼 안쪽(구멍에서도 margin 만큼 떨어져야)까지만 인정
function BoardShape.inside(shape: Shape, x: number, z: number, margin: number?): boolean
	local gap = margin or 0
	if shape.holeRadius > 0 and math.sqrt(x * x + z * z) < shape.holeRadius + gap then
		return false
	end
	if shape.circles then
		for _, circle in shape.circles do
			local dx, dz = x - circle.x, z - circle.z
			if math.sqrt(dx * dx + dz * dz) <= circle.r - gap then
				return true
			end
		end
		return false
	end
	for _, edge in shape.edges :: { Edge } do
		if math.abs(x * edge.nx + z * edge.nz) > edge.half - gap then
			return false
		end
	end
	return true
end

-- 점 (x, z) 에서 방향 (dx, dz) 로 갔을 때 판 밖(또는 구멍)까지 거리. 조금씩 가 보고 경계를 좁혀 찾는다.
function BoardShape.distanceToEdge(shape: Shape, x: number, z: number, dx: number, dz: number): number
	if not BoardShape.inside(shape, x, z) then
		return 0
	end
	local step = 0.5
	local limit = shape.reach * 2 + 1
	local inner = 0
	local t = step
	while t <= limit do
		if not BoardShape.inside(shape, x + dx * t, z + dz * t) then
			-- inner 는 판 위, t 는 판 밖 : 반씩 좁혀서 정확하게
			local outer = t
			for _ = 1, 10 do
				local middle = (inner + outer) / 2
				if BoardShape.inside(shape, x + dx * middle, z + dz * middle) then
					inner = middle
				else
					outer = middle
				end
			end
			return (inner + outer) / 2
		end
		inner = t
		t += step
	end
	return limit
end

-- 폭발 턴에 세우는 벽 자리 : { x, z, nx, nz, length } (n 은 판 밖 쪽 방향)
function BoardShape.wallSpots(shape: Shape): { { x: number, z: number, nx: number, nz: number, length: number } }
	local spots = {}
	if shape.circles then
		local count = 32
		for index, circle in shape.circles do
			for step = 0, count - 1 do
				local angle = step * 2 * math.pi / count
				local nx, nz = math.sin(angle), math.cos(angle)
				local px, pz = circle.x + nx * circle.r, circle.z + nz * circle.r
				-- 다른 원 안쪽이면 (잘록한 허리 안) 벽이 필요 없다
				local covered = false
				for otherIndex, other in shape.circles do
					if otherIndex ~= index and math.sqrt((px - other.x) ^ 2 + (pz - other.z) ^ 2) < other.r - 0.5 then
						covered = true
					end
				end
				if not covered then
					table.insert(spots, { x = px, z = pz, nx = nx, nz = nz, length = 2 * math.pi * circle.r / count + 1 })
				end
			end
		end
	else
		for _, edge in shape.edges :: { Edge } do
			for _, sign in { 1, -1 } do
				table.insert(spots, {
					x = edge.nx * edge.half * sign,
					z = edge.nz * edge.half * sign,
					nx = edge.nx * sign,
					nz = edge.nz * sign,
					length = edge.length + 6,
				})
			end
		end
	end
	-- 구멍 둘레 (판 밖 쪽 = 구멍 가운데 쪽)
	if shape.holeRadius > 0 then
		local count = 16
		for step = 0, count - 1 do
			local angle = step * 2 * math.pi / count
			local nx, nz = math.sin(angle), math.cos(angle)
			table.insert(spots, {
				x = nx * shape.holeRadius,
				z = nz * shape.holeRadius,
				nx = -nx,
				nz = -nz,
				length = 2 * math.pi * shape.holeRadius / count + 1,
			})
		end
	end
	return spots
end

-- 울퉁불퉁 바닥의 혹 자리 : 알(occupied)과 다른 혹에서 떨어진 빈 곳에 count 개까지
-- occupied : { { x, z, r }, ... }, nextNumber(low, high) : 무작위 숫자 함수
function BoardShape.bumpSpots(
	shape: Shape,
	count: number,
	bumpRadius: number,
	occupied: { { number } },
	nextNumber: (number, number) -> number
): { { x: number, z: number } }
	local spots = {}
	local tries = 0
	while #spots < count and tries < count * 60 do
		tries += 1
		local x = nextNumber(-shape.reach, shape.reach)
		local z = nextNumber(-shape.reach, shape.reach)
		local ok = BoardShape.inside(shape, x, z, bumpRadius + 1)
		if ok then
			for _, other in occupied do
				if math.sqrt((other[1] - x) ^ 2 + (other[2] - z) ^ 2) < other[3] + bumpRadius + 1.5 then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, spot in spots do
				if math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2) < bumpRadius * 2.5 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(spots, { x = x, z = z })
		end
	end
	return spots
end

-- 혹이 판 윗면에서 차지하는 동그라미 반지름 (공을 묻어서 위만 솟게 했을 때)
function BoardShape.bumpFootprint(bumpRadius: number, bumpHeight: number): number
	local below = bumpRadius - bumpHeight
	return math.sqrt(math.max(bumpRadius * bumpRadius - below * below, 0))
end

-- 울퉁불퉁 바닥 지형 자리 : 언덕 → 구덩이 → 혹 순서로, 알과 서로에게서 떨어진 곳에
-- floor = Config.Floors.Bumpy, occupied = 알 { { x, z, r } }
-- 돌려주는 것 : { mounds = { {x,z} }, dips = { {x,z} }, bumps = { {x,z} } }
function BoardShape.terrain(
	shape: Shape,
	floor,
	occupied: { { number } },
	nextNumber: (number, number) -> number
): { mounds: { { x: number, z: number } }, dips: { { x: number, z: number } }, bumps: { { x: number, z: number } } }
	local taken = table.clone(occupied)
	local result = { mounds = {}, dips = {}, bumps = {} }
	-- 개수는 보통 판(64) 넓이 기준 : 작은 판은 적게, 큰 판은 많게
	local areaScale = (shape.size / 64) ^ 2
	local kinds = {
		{ key = "mounds", info = floor.Mounds, round = true },
		{ key = "dips", info = floor.Dips, round = false },
		{ key = "bumps", info = floor.Bumps, round = true },
	}
	for _, kind in kinds do
		local info = kind.info
		local count = if info then math.max(1, math.floor(info.Count * areaScale + 0.5)) else 0
		if info and count > 0 then
			-- 판 윗면에서 차지하는 동그라미 크기로 자리를 잡는다
			local radius = if kind.round then BoardShape.bumpFootprint(info.Radius, info.Height) else info.Radius
			local spots = BoardShape.bumpSpots(shape, count, radius, taken, nextNumber)
			for _, spot in spots do
				table.insert(taken, { spot.x, spot.z, radius })
			end
			result[kind.key] = spots
		end
	end
	return result
end

---------------------------------------------------------------- 판 설정 한 묶음
-- 이번 판의 모양·크기·바닥·팀 배치. 서버(Board), 화면(팀 고르기), 시뮬레이션이 모두 이걸 써서 같은 판을 본다.
-- config = Config 모듈

export type Setup = {
	sizeKey: string,
	floorKey: string,
	teamCount: number,
	shape: Shape,
	layout: { KingDistance: number, Rows: { number }, PerRow: number, Spacing: number },
	friction: number,
	frictionWeight: number,
	budget: number, -- 이 판의 팀 예산
}

-- 이 판 크기를 이 팀 수로 쓸 수 있는지 (호리병은 2팀만)
function BoardShape.allowed(config, sizeKey: string, teamCount: number): boolean
	local size = config.BoardSizes[sizeKey]
	return size ~= nil and (not size.TwoTeamsOnly or teamCount == 2)
end

function BoardShape.makeSetup(config, sizeKey: string, floorKey: string, teamCount: number): Setup
	if not BoardShape.allowed(config, sizeKey, teamCount) then
		sizeKey = "Normal"
	end
	if not config.Floors[floorKey] then
		floorKey = "Wood"
	end
	local size = config.BoardSizes[sizeKey]
	local floor = config.Floors[floorKey]
	local layout = if teamCount <= 2 or not size.Many then size.Two else size.Many

	-- 화산 구멍은 앞줄 알과 안 겹치게
	local holeRadius = 0
	if floor.HoleRadius then
		holeRadius = math.min(floor.HoleRadius, layout.Rows[1] - 3)
	end
	local kind = BoardShape.pick(size.Shape or "Auto", teamCount)
	local circles = size.Circles
	if size.Shape == "Lobes" then
		-- 팀마다 그 팀 쪽에 둥근 부분 하나 (팀 방향은 TeamLayout 과 같다 : i번째 팀 = (i-1) × 360/팀수 도)
		local lobe = size.Lobes[teamCount] or size.Lobes[2]
		circles = {}
		for team = 1, teamCount do
			local angle = (team - 1) * 2 * math.pi / teamCount
			table.insert(circles, { math.sin(angle) * lobe.Distance, math.cos(angle) * lobe.Distance, lobe.Radius })
		end
		if lobe.Center > 0 then
			table.insert(circles, { 0, 0, lobe.Center })
		end
		kind = "Circles"
	end
	return {
		sizeKey = sizeKey,
		floorKey = floorKey,
		teamCount = teamCount,
		shape = BoardShape.create(kind, size.Size, holeRadius, circles),
		layout = layout,
		friction = floor.Friction,
		frictionWeight = floor.FrictionWeight or 1,
		budget = size.Budget or config.Budget,
	}
end

-- 추천 팀을 이 판 크기에 맞게 : 작은 판은 알을 빼고, 큰 판은 보통 알을 더 넣는다 (예산 비율만큼)
-- pieces : { { kind, ability? }, ... } → 새 목록
function BoardShape.adaptPreset(config, setup: Setup, pieces: { { string } }): { { string } }
	local capacity = setup.layout.PerRow * #setup.layout.Rows
	local target = math.floor(#pieces * setup.budget / config.Budget + 0.5)
	target = math.clamp(target, 1, capacity)
	local list = {}
	for _, entry in pieces do
		table.insert(list, { entry[1], entry[2] })
	end
	-- 줄일 때 : 뒤에서부터 보통 알을 먼저 뺀다 (능력 알은 되도록 남긴다)
	local index = #list
	while #list > target and index >= 1 do
		if list[index][2] == nil then
			table.remove(list, index)
		end
		index -= 1
	end
	while #list > target do
		table.remove(list)
	end
	-- 늘릴 때 : 이 팀의 보통 알 종류를 돌아가며 더 넣는다
	if #list < target then
		local basics = {}
		for _, entry in pieces do
			if entry[2] == nil then
				table.insert(basics, entry[1])
			end
		end
		if #basics == 0 then
			basics = { "Flat" }
		end
		local next = 1
		while #list < target do
			table.insert(list, { basics[next] })
			next = next % #basics + 1
		end
	end
	return list
end

-- 알이 이 바닥에서 미끄러질 때 초당 줄어드는 속도 (로블록스는 무게를 단 평균 마찰을 쓴다)
function BoardShape.slowdown(setup: Setup, pieceFriction: number, gravity: number): number
	local friction = (pieceFriction + setup.friction * setup.frictionWeight) / (1 + setup.frictionWeight)
	return friction * gravity
end

return BoardShape
