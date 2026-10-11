-- Studio 없이 NPC 대 NPC 로 판을 돌려 보는 시뮬레이션.
-- 실행 : luau tests/simulate.luau
-- 물리는 단순화 (원판 미끄러짐 + 공 굴러감 + 탄성 충돌). 숫자는 진짜 Config.lua 를 쓴다.
-- 능력은 빼고 튕기기만 한다.

-- Config.lua 는 Color3 (로블록스 타입)을 써서 그대로는 못 불러온다.
-- tests/simulate.sh 가 가짜 Color3 를 붙인 사본을 tests/_build/Config.lua 로 만들어 준다.
local Config = require("./_build/Config")
local Npc = require("../src/server/Npc")
local TeamLayout = require("../src/shared/TeamLayout")
local BoardShape = require("../src/shared/BoardShape")

-- 지금 판 모양 (playGame 이 팀 수에 맞게 바꾼다)
-- 지금 판 설정 (playGame 이 판 크기·바닥·팀 수에 맞게 바꾼다)
local setup = BoardShape.makeSetup(Config, "Normal", "Wood", 2)
-- 울퉁불퉁 바닥의 혹 (움직이지 않는 동그라미 장애물) { x, z, r }
local bumps: { { x: number, z: number, r: number } } = {}
-- 구덩이 (가운데로 끌어당기고 느리게) { x, z, r }
local dips: { { x: number, z: number, r: number } } = {}
TERRAIN = { boards = 0, bumps = 0, mounds = 0, dips = 0, settled = 0, turns = 0 }
local GRAVITY = 196.2
local DT = 1 / 240
local MAX_TURNS = 300

-- Roblox Random 대신 쓰는 간단한 난수
local function makeRandom(seed: number)
	local state = seed
	local rng = {}
	function rng.NextNumber(_, low: number?, high: number?): number
		state = (state * 1103515245 + 12345) % 2147483648
		local unit = state / 2147483648
		if low and high then
			return low + (high - low) * unit
		end
		return unit
	end
	function rng.NextInteger(self, low: number, high: number): number
		return math.min(high, low + math.floor(self:NextNumber() * (high - low + 1)))
	end
	return rng
end

local function makePiece(kind: string, team: number, x: number, z: number)
	local info = Config.Pieces[kind]
	return {
		kind = kind,
		team = team,
		x = x,
		z = z,
		vx = 0,
		vz = 0,
		alive = true,
		mass = info.mass * Config.MassUnit,
		massFactor = info.mass,
		radius = Config.PieceDiameter * info.size / 2,
		slow = BoardShape.slowdown(setup, info.friction, GRAVITY), -- GameManager.slowOf 와 같은 식
		bounce = info.bounce,
		flickScale = info.flickScale or 1,
		hp = info.hp,
	}
end

-- Placement.layoutTeam 과 같은 배치 (같은 TeamLayout 모듈을 쓴다)
local function layoutTeam(team: number, teamCount: number, entries, pieces)
	local layout = setup.layout
	for _, slot in TeamLayout.slots(team, teamCount, entries, layout) do
		table.insert(pieces, makePiece(slot.kind, team, slot.x, slot.z))
	end
end

-- Damage.formula 와 같은 식
local function damageFormula(relativeSpeed: number, massFactor: number): number
	if relativeSpeed < Config.DamageMinSpeed then
		return 0
	end
	return relativeSpeed * massFactor * Config.DamageScale
end

local function step(pieces)
	for _, p in pieces do
		if p.alive then
			local speed = math.sqrt(p.vx ^ 2 + p.vz ^ 2)
			local slow = p.slow * DT
			if speed <= slow then
				p.vx, p.vz = 0, 0
			else
				p.vx -= p.vx / speed * slow
				p.vz -= p.vz / speed * slow
			end
			-- 모래처럼 Drag 가 있는 바닥 (GameManager 와 같은 계산)
			local drag = Config.Floors[setup.floorKey].Drag or 0
			if drag > 0 then
				local keep = math.max(1 - drag * DT, 0)
				p.vx *= keep
				p.vz *= keep
			end
			p.x += p.vx * DT
			p.z += p.vz * DT
		end
	end
	for i = 1, #pieces do
		local a = pieces[i]
		for j = i + 1, #pieces do
			local b = pieces[j]
			if a.alive and b.alive then
				local dx, dz = b.x - a.x, b.z - a.z
				local dist = math.sqrt(dx * dx + dz * dz)
				local minDist = a.radius + b.radius
				if dist < minDist and dist > 1e-6 then
					local nx, nz = dx / dist, dz / dist
					local closing = (a.vx - b.vx) * nx + (a.vz - b.vz) * nz
					if closing > 0 then
						-- 왕알 데미지 (상대속도 × 때린 알 질량 계수)
						local relative = math.sqrt((a.vx - b.vx) ^ 2 + (a.vz - b.vz) ^ 2)
						-- 같은 편끼리는 데미지 없음 (Damage.lua 와 같은 규칙)
						if a.kind == "King" and a.team ~= b.team then
							a.hp -= damageFormula(relative, b.massFactor)
						end
						if b.kind == "King" and a.team ~= b.team then
							b.hp -= damageFormula(relative, a.massFactor)
						end
						local impulse = (1 + (a.bounce + b.bounce) / 2) * closing / (1 / a.mass + 1 / b.mass)
						a.vx -= impulse / a.mass * nx
						a.vz -= impulse / a.mass * nz
						b.vx += impulse / b.mass * nx
						b.vz += impulse / b.mass * nz
					end
					local push = (minDist - dist) / 2
					a.x -= nx * push
					a.z -= nz * push
					b.x += nx * push
					b.z += nz * push
				end
			end
		end
	end
	-- 구덩이 : GameManager 처럼 가운데로 끌어당기고 느리게
	local dipInfo = Config.Floors.Bumpy.Dips
	for _, dip in dips do
		for _, p in pieces do
			if p.alive then
				local ox, oz = dip.x - p.x, dip.z - p.z
				local distance = math.sqrt(ox * ox + oz * oz)
				if distance < dip.r then
					local slow = math.max(1 - dipInfo.Damping * DT, 0)
					p.vx *= slow
					p.vz *= slow
					if distance > 0.2 then
						local pull = dipInfo.Pull * DT * (distance / dip.r)
						p.vx += ox / distance * pull
						p.vz += oz / distance * pull
					end
				end
			end
		end
	end
	-- 혹에 부딪히면 튕겨 나온다 (혹은 안 움직임)
	for _, bump in bumps do
		for _, p in pieces do
			if p.alive then
				local dx, dz = p.x - bump.x, p.z - bump.z
				local dist = math.sqrt(dx * dx + dz * dz)
				local minDist = p.radius + bump.r
				if dist < minDist and dist > 1e-6 then
					local nx, nz = dx / dist, dz / dist
					local into = p.vx * nx + p.vz * nz
					if into < 0 then
						local bounce = (p.bounce + 0.3) / 2
						p.vx -= (1 + bounce) * into * nx
						p.vz -= (1 + bounce) * into * nz
					end
					p.x = bump.x + nx * minDist
					p.z = bump.z + nz * minDist
				end
			end
		end
	end
	-- 판 밖 탈락 (Elimination.lua 와 같은 규칙)
	for _, p in pieces do
		if p.alive and not BoardShape.inside(setup.shape, p.x, p.z) then
			p.alive = false
		end
	end
end

local function anyMoving(pieces): boolean
	for _, p in pieces do
		if p.alive and (math.abs(p.vx) > Config.StopSpeed or math.abs(p.vz) > Config.StopSpeed) then
			return true
		end
	end
	return false
end

-- GameManager.loseReason 과 같은 규칙 (왕알만 남아도 계속 싸운다)
local function loseReason(pieces, team: number): string?
	for _, p in pieces do
		if p.alive and p.team == team and p.kind == "King" then
			return if p.hp <= 0 then "왕알 격파" else nil
		end
	end
	return "왕알 탈락"
end

local function infoOf(p)
	return {
		x = p.x,
		z = p.z,
		mass = p.mass,
		radius = p.radius,
		slow = p.slow,
		bounce = p.bounce,
		isKing = p.kind == "King",
		hp = p.hp,
		massFactor = p.massFactor,
		flickScale = p.flickScale,
	}
end

-- presets : 팀마다 추천 팀 번호 (또는 알 목록 그대로). 돌려주는 것 : 턴 수, 이긴 팀 (0 무승부, -1 안 끝남), 끝난 이유
local function playGame(seed: number, presets: { any }, sizeKey: string?, floorKey: string?)
	local rng = makeRandom(seed)
	local teamCount = #presets
	setup = BoardShape.makeSetup(Config, sizeKey or "Normal", floorKey or "Wood", teamCount)
	local pieces = {}
	for team, preset in presets do
		-- GameManager.copyPreset 처럼 판 크기에 맞게 늘이거나 줄인 추천 팀
		local entries = if type(preset) == "table" then preset else BoardShape.adaptPreset(Config, setup, Config.PresetTeams[preset].Pieces)
		layoutTeam(team, teamCount, entries, pieces)
	end

	-- 울퉁불퉁이면 Board.addTerrain 처럼 알 사이 빈 자리에 언덕·구덩이·혹
	table.clear(bumps)
	table.clear(dips)
	local floor = Config.Floors[setup.floorKey]
	if floor.Bumps then
		local occupied = {}
		for _, p in pieces do
			table.insert(occupied, { p.x, p.z, p.radius })
		end
		local terrainRng = makeRandom(seed + 99)
		local terrain = BoardShape.terrain(setup.shape, floor, occupied, function(low, high)
			return terrainRng:NextNumber(low, high)
		end)
		local footprint = BoardShape.bumpFootprint(floor.Bumps.Radius, floor.Bumps.Height)
		for _, spot in terrain.bumps do
			table.insert(bumps, { x = spot.x, z = spot.z, r = footprint })
		end
		for _, spot in terrain.dips do
			table.insert(dips, { x = spot.x, z = spot.z, r = floor.Dips.Radius })
		end
		-- 언덕은 넘어갈 수 있어서 2D 시뮬레이션에서는 개수만 센다
		TERRAIN.boards += 1
		TERRAIN.bumps += #terrain.bumps
		TERRAIN.mounds += #terrain.mounds
		TERRAIN.dips += #terrain.dips
	end

	-- 시작 배치가 겹치거나 판 밖이면 안 된다
	for i, a in pieces do
		assert(BoardShape.inside(setup.shape, a.x, a.z, a.radius), "시작 알이 판 밖(또는 구멍): " .. a.kind .. " " .. setup.sizeKey .. "/" .. setup.floorKey .. "/" .. teamCount .. "팀")
		for j = i + 1, #pieces do
			local b = pieces[j]
			local dist = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			assert(dist >= a.radius + b.radius, "시작 알이 겹침: " .. a.kind .. " / " .. b.kind)
		end
	end

	local out: { [number]: boolean } = {}
	-- GameManager 처럼 먼저 치는 팀은 무작위
	local team = rng:NextInteger(1, teamCount)
	local lastReason = ""
	for turn = 1, MAX_TURNS do
		local shooters, shooterInfos, targets = {}, {}, {}
		for _, p in pieces do
			if p.alive then
				if p.team == team and (Config.CanFlickKing or p.kind ~= "King") then
					table.insert(shooters, p)
					table.insert(shooterInfos, infoOf(p))
				elseif p.team ~= team and not out[p.team] then
					table.insert(targets, infoOf(p))
				end
			end
		end
		local shot = Npc.chooseShot(shooterInfos, targets, {
			distanceToEdge = function(x, z, dx, dz)
				return BoardShape.distanceToEdge(setup.shape, x, z, dx, dz)
			end,
			gravity = GRAVITY,
			friction = setup.friction,
			elasticity = Config.Pieces.Flat.bounce,
			flickPower = Config.FlickPower,
			powerBoost = Config.NpcPowerBoost,
			aimErrorDegrees = Config.NpcAimErrorDegrees,
			damageScale = Config.DamageScale,
			damageMinSpeed = Config.DamageMinSpeed,
			mistakeChance = Config.NpcMistakeChance,
			kingFocus = Config.NpcKingFocus,
			powerError = Config.NpcPowerError,
		}, rng :: any)
		if shot then
			assert(shot.power >= 0 and shot.power <= 1, "세기가 0~1 밖")
			local shooter = shooters[shot.shooter]
			local speed = math.max(shot.power, Config.MinFlickPower) * Config.FlickPower * shooter.flickScale / shooter.mass
			shooter.vx, shooter.vz = shot.dirX * speed, shot.dirZ * speed
		end
		local t = 0
		repeat
			step(pieces)
			t += DT
		until not anyMoving(pieces) or t > Config.MaxMoveTime
		-- GameManager 처럼 시간이 다 되면 그 자리에 멈춘다
		for _, p in pieces do
			p.vx, p.vz = 0, 0
		end

		if #dips > 0 then
			TERRAIN.turns += 1
			for _, p in pieces do
				if p.alive then
					for _, dip in dips do
						if math.sqrt((p.x - dip.x) ^ 2 + (p.z - dip.z) ^ 2) < dip.r * 0.6 then
							TERRAIN.settled += 1
						end
					end
				end
			end
		end
		-- 진 팀 탈락 (GameManager.knockOut 과 같은 규칙 : 남은 알도 치운다)
		for checkTeam = 1, teamCount do
			if not out[checkTeam] then
				local reason = loseReason(pieces, checkTeam)
				if reason then
					out[checkTeam] = true
					lastReason = reason
					for _, p in pieces do
						if p.team == checkTeam then
							p.alive = false
						end
					end
				end
			end
		end
		local alive = {}
		for checkTeam = 1, teamCount do
			if not out[checkTeam] then
				table.insert(alive, checkTeam)
			end
		end
		if #alive <= 1 then
			return turn, alive[1] or 0, lastReason
		end
		team = TeamLayout.nextTeam(team, teamCount, out) or alive[1]
	end
	return MAX_TURNS, -1, "끝나지 않음"
end

local presetCount = #Config.PresetTeams
local unfinished = 0
local reasons: { [string]: number } = {}
local totalGames, totalTurns = 0, 0
print("2팀 : 추천 팀끼리 NPC 대전 (각 조합 10판, 먼저 치는 팀 무작위)")
for red = 1, presetCount do
	local line = {}
	for blue = 1, presetCount do
		local redWins = 0
		for seed = 1, 10 do
			local turns, winner, reason = playGame(seed * 7919 + red * 31 + blue, { red, blue })
			totalGames += 1
			totalTurns += turns
			reasons[reason :: string] = (reasons[reason :: string] or 0) + 1
			if winner == -1 then
				unfinished += 1
			elseif winner == 1 then
				redWins += 1
			end
		end
		table.insert(line, string.format("%s %d승", Config.PresetTeams[blue].Name, redWins))
	end
	print(string.format("  빨강 %s vs  %s", Config.PresetTeams[red].Name, table.concat(line, " | ")))
end
print(string.format("  총 %d판, 평균 %.1f턴", totalGames, totalTurns / totalGames))
for reason, count in reasons do
	print(string.format("  끝난 이유 %s : %d판", reason, count))
end

-- 3팀·4팀 : 추천 팀 무작위, 자리(순서)별 승리 수
for teamCount = 3, 4 do
	local games, turnsSum = 100, 0
	local wins: { [number]: number } = {}
	local draws = 0
	for seed = 1, games do
		local rng = makeRandom(seed * 104729 + teamCount)
		local presets = {}
		for team = 1, teamCount do
			presets[team] = rng:NextInteger(1, presetCount)
		end
		local turns, winner = playGame(seed * 7 + teamCount * 1000, presets)
		turnsSum += turns
		if winner == -1 then
			unfinished += 1
		elseif winner == 0 then
			draws += 1
		else
			wins[winner] = (wins[winner] or 0) + 1
		end
	end
	local line = {}
	for team = 1, teamCount do
		table.insert(line, string.format("%s %d승", Config.Teams[team].Name, wins[team] or 0))
	end
	print(string.format("%d팀 (보통 판) : %d판, 평균 %.1f턴, 무승부 %d | %s", teamCount, games, turnsSum / games, draws, table.concat(line, " · ")))
end

-- 판 종류마다 : 크기·모양 × 바닥 × 팀 수 (시작 배치가 판 위에 있고 겹치지 않는지, 판이 끝나는지)
print("판 종류별 (각 20판, 추천 팀 무작위)")
local sizeKeys = { "Normal", "Small", "Large", "Gourd", "Bear" }
local floorKeys = { "Wood", "Ice", "Volcano", "Bumpy", "Sand", "Chess", "Janggi", "Baduk" }
for _, sizeKey in sizeKeys do
	for teamCount = 2, 4 do
		if BoardShape.allowed(Config, sizeKey, teamCount) then
			local line = {}
			for _, floorKey in floorKeys do
				if not BoardShape.floorAllowed(Config, sizeKey, floorKey) then
					table.insert(line, Config.Floors[floorKey].Name .. " (안 됨)")
					continue
				end
				local turnsSum, draws = 0, 0
				local boardSetup = BoardShape.makeSetup(Config, sizeKey, floorKey, teamCount)
				local capacity = TeamLayout.capacity(boardSetup.layout)
				for seed = 1, 20 do
					local rng = makeRandom(seed * 7177 + teamCount)
					local presets = {}
					for team = 1, teamCount do
						-- 자리에 들어가는 추천 팀만
						local pick
						repeat
							pick = rng:NextInteger(1, presetCount)
						until #BoardShape.adaptPreset(Config, boardSetup, Config.PresetTeams[pick].Pieces) <= capacity
						presets[team] = pick
					end
					local turns, winner = playGame(seed * 13 + teamCount, presets, sizeKey, floorKey)
					turnsSum += turns
					if winner == -1 then
						unfinished += 1
					elseif winner == 0 then
						draws += 1
					end
				end
				table.insert(line, string.format("%s %.0f턴(무%d)", Config.Floors[floorKey].Name, turnsSum / 20, draws))
			end
			-- 이 판에서 추천 팀 알 개수 (수비팀·돌격팀·꼬마군단·마법팀)
			local counts = {}
			local countSetup = BoardShape.makeSetup(Config, sizeKey, "Wood", teamCount)
			for _, preset in Config.PresetTeams do
				table.insert(counts, tostring(#BoardShape.adaptPreset(Config, countSetup, preset.Pieces)))
			end
			print(string.format("  %s %d팀 [알 %s] : %s", Config.BoardSizes[sizeKey].Name, teamCount, table.concat(counts, "/"), table.concat(line, " · ")))
			if TERRAIN.boards > 0 then
				local info = Config.Floors.Bumpy
				print(string.format(
					"      울퉁불퉁 : 혹 %.1f · 언덕 %.1f · 구덩이 %.1f 놓임 (보통 판 기준 %d·%d·%d), 턴이 끝날 때 구덩이 가운데에 고인 알 판마다 평균 %.1f개",
					TERRAIN.bumps / TERRAIN.boards,
					TERRAIN.mounds / TERRAIN.boards,
					TERRAIN.dips / TERRAIN.boards,
					info.Bumps.Count, info.Mounds.Count, info.Dips.Count,
					TERRAIN.settled / math.max(TERRAIN.turns, 1)
				))
				TERRAIN = { boards = 0, bumps = 0, mounds = 0, dips = 0, settled = 0, turns = 0 }
			end
		end
	end
end

-- 랜덤 모드 : 판·바닥 무작위 + 모든 팀이 같은 무작위 알 조합 (GameManager.runRandomTeams 처럼)
for teamCount = 2, 4 do
	local games, turnsSum, draws = 40, 0, 0
	local wins: { [number]: number } = {}
	local boards: { [string]: number } = {}
	local pieceSum = 0
	for seed = 1, games do
		local rng = makeRandom(seed * 92821 + teamCount)
		local nextNumber = function()
			return rng:NextNumber()
		end
		local sizeKey, floorKey = BoardShape.randomBoard(Config, teamCount, nextNumber)
		local boardSetup = BoardShape.makeSetup(Config, sizeKey, floorKey, teamCount)
		local counts = BoardShape.randomCounts(Config, boardSetup, nextNumber)
		local cost, list = 0, {}
		for kind, count in counts do
			cost += count * Config.Prices[kind]
			for _ = 1, count do
				table.insert(list, { if kind == "Ability" then "Flat" else kind })
			end
		end
		assert(cost <= boardSetup.budget and #list <= TeamLayout.capacity(boardSetup.layout) and #list > 0, "랜덤 팀이 예산·자리를 넘음")
		pieceSum += #list
		local key = Config.BoardSizes[sizeKey].Name .. "/" .. Config.Floors[floorKey].Name
		boards[key] = (boards[key] or 0) + 1
		local presets = {}
		for team = 1, teamCount do
			presets[team] = list
		end
		local turns, winner = playGame(seed * 31 + teamCount, presets, sizeKey, floorKey)
		turnsSum += turns
		if winner == -1 then
			unfinished += 1
		elseif winner == 0 then
			draws += 1
		else
			wins[winner] = (wins[winner] or 0) + 1
		end
	end
	local line = {}
	for team = 1, teamCount do
		table.insert(line, string.format("%s %d승", Config.Teams[team].Name, wins[team] or 0))
	end
	local kinds = 0
	for _ in boards do
		kinds += 1
	end
	print(string.format(
		"랜덤 %d팀 : %d판, 판·바닥 %d가지, 팀당 알 평균 %.1f개, 평균 %.1f턴, 무승부 %d | %s",
		teamCount, games, kinds, pieceSum / games, turnsSum / games, draws, table.concat(line, " · ")
	))
end

print(if unfinished == 0 then "모든 판이 승패로 끝남" else ("끝나지 않은 판: " .. unfinished))
