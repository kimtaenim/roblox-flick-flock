-- 팀 자리 계산 (숫자만 써서 Studio 없이도 테스트할 수 있다)
-- 팀 i 는 판 가운데에서 (i-1) × 360/팀수 도 방향에 앉는다. 1번 팀(빨강)은 +Z.
local TeamLayout = {}

export type Layout = { KingDistance: number, Rows: { number }, PerRow: number, Spacing: number }
export type Slot = { kind: string, ability: string?, x: number, z: number }

-- 팀 수에 맞는 배치 (layouts = Config.Layouts)
function TeamLayout.pick(layouts: { Two: Layout, Many: Layout }, teamCount: number): Layout
	return if teamCount <= 2 then layouts.Two else layouts.Many
end

-- 판 가운데에서 팀 자리 쪽 방향 (x, z)
function TeamLayout.direction(team: number, teamCount: number): (number, number)
	local angle = (team - 1) * 2 * math.pi / math.max(teamCount, 1)
	local x, z = math.sin(angle), math.cos(angle)
	-- 0 에 아주 가까운 값은 0 으로 (계산 찌꺼기 정리)
	if math.abs(x) < 1e-9 then
		x = 0
	end
	if math.abs(z) < 1e-9 then
		z = 0
	end
	return x, z
end

-- 한 팀이 놓을 수 있는 알 개수 (왕알 빼고)
function TeamLayout.capacity(layout: Layout): number
	return layout.PerRow * #layout.Rows
end

-- 왕알(맨 뒤 가운데) + 알들 (앞줄부터) 자리
-- entries : { { kind, ability? }, ... }
function TeamLayout.slots(team: number, teamCount: number, entries: { { string } }, layout: Layout): { Slot }
	local dx, dz = TeamLayout.direction(team, teamCount)
	-- 팀 방향에 수직인 방향 (줄이 늘어서는 방향)
	local px, pz = dz, -dx
	local slots: { Slot } = {}
	table.insert(slots, { kind = "King", ability = nil, x = dx * layout.KingDistance, z = dz * layout.KingDistance })

	local perRow = layout.PerRow
	for index, entry in entries do
		local row = math.floor((index - 1) / perRow) + 1
		local distance = layout.Rows[math.min(row, #layout.Rows)]
		local inRow = math.min(#entries - (row - 1) * perRow, perRow)
		local column = (index - 1) % perRow + 1
		local offset = (column - (inRow + 1) / 2) * layout.Spacing
		table.insert(slots, {
			kind = entry[1],
			ability = entry[2],
			x = dx * distance + px * offset,
			z = dz * distance + pz * offset,
		})
	end
	return slots
end

-- 다음 차례 팀 (탈락한 팀은 건너뛴다). out[team] = true 면 탈락.
function TeamLayout.nextTeam(current: number, teamCount: number, out: { [number]: boolean }): number?
	for step = 1, teamCount do
		local team = (current - 1 + step) % teamCount + 1
		if not out[team] then
			return team
		end
	end
	return nil
end

return TeamLayout
