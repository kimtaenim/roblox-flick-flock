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
local boardEdges = BoardShape.edges("Square", Config.BoardSize)
local GRAVITY = 196.2
local DT = 1 / 240
local MAX_TURNS = 120

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
		slow = (info.friction + Config.BoardFriction) / 2 * GRAVITY, -- GameManager.slowOf 와 같은 식
		bounce = info.bounce,
		flickScale = info.flickScale or 1,
		hp = info.hp,
	}
end

-- Placement.layoutTeam 과 같은 배치 (같은 TeamLayout 모듈을 쓴다)
local function layoutTeam(team: number, teamCount: number, entries, pieces)
	local layout = TeamLayout.pick(Config.Layouts, teamCount)
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
						if a.kind == "King" then
							a.hp -= damageFormula(relative, b.massFactor)
						end
						if b.kind == "King" then
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
	-- 판 밖 탈락 (Elimination.lua 와 같은 규칙)
	for _, p in pieces do
		if p.alive and not BoardShape.inside(boardEdges, p.x, p.z) then
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

-- presets : 팀마다 추천 팀 번호. 돌려주는 것 : 턴 수, 이긴 팀 (0 무승부, -1 안 끝남), 끝난 이유
local function playGame(seed: number, presets: { number })
	local rng = makeRandom(seed)
	local teamCount = #presets
	boardEdges = BoardShape.edges(BoardShape.pick(Config.BoardShape, teamCount), Config.BoardSize)
	local pieces = {}
	for team, preset in presets do
		layoutTeam(team, teamCount, Config.PresetTeams[preset].Pieces, pieces)
	end

	-- 시작 배치가 겹치거나 판 밖이면 안 된다
	for i, a in pieces do
		assert(BoardShape.inside(boardEdges, a.x, a.z, a.radius), "시작 알이 판 밖: " .. a.kind)
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
				return BoardShape.distanceToEdge(boardEdges, x, z, dx, dz)
			end,
			gravity = GRAVITY,
			friction = Config.BoardFriction,
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
	print(string.format("%d팀 (%s) : %d판, 평균 %.1f턴, 무승부 %d | %s", teamCount, BoardShape.pick(Config.BoardShape, teamCount), games, turnsSum / games, draws, table.concat(line, " · ")))
end

print(if unfinished == 0 then "모든 판이 승패로 끝남" else ("끝나지 않은 판: " .. unfinished))
