-- Studio 없이 NPC 대 NPC 로 판을 돌려 보는 시뮬레이션.
-- 실행 : luau tests/simulate.luau
-- 물리는 단순화 (원판 미끄러짐 + 공 굴러감 + 탄성 충돌). 숫자는 진짜 Config.lua 를 쓴다.
-- 능력은 빼고 튕기기만 한다.

-- Config.lua 는 Color3 (로블록스 타입)을 써서 그대로는 못 불러온다.
-- tests/simulate.sh 가 가짜 Color3 를 붙인 사본을 tests/_build/Config.lua 로 만들어 준다.
local Config = require("./_build/Config")
local Npc = require("../src/server/Npc")

local BOARD_HALF = Config.BoardSize / 2
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
		hp = info.hp,
	}
end

-- Placement.layoutTeam 과 같은 배치
local function layoutTeam(team: number, entries, pieces)
	local side = if team == 1 then 1 else -1
	table.insert(pieces, makePiece("King", team, 0, side * Config.KingRowDistance))
	local perRow = Config.PiecesPerRow
	for index, entry in entries do
		local row = math.floor((index - 1) / perRow) + 1
		local rowDistance = Config.RowDistances[math.min(row, #Config.RowDistances)]
		local inRow = math.min(#entries - (row - 1) * perRow, perRow)
		local column = (index - 1) % perRow + 1
		local x = (column - (inRow + 1) / 2) * Config.PieceSpacing
		table.insert(pieces, makePiece(entry[1], team, x, side * rowDistance))
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
		if p.alive and (math.abs(p.x) > BOARD_HALF or math.abs(p.z) > BOARD_HALF) then
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

-- GameManager.loseReason 과 같은 규칙
local function loseReason(pieces, team: number): string?
	local king, soldiers = nil, 0
	for _, p in pieces do
		if p.alive and p.team == team then
			if p.kind == "King" then
				king = p
			else
				soldiers += 1
			end
		end
	end
	if not king then
		return "왕알 탈락"
	end
	if king.hp <= 0 then
		return "왕알 격파"
	end
	if soldiers == 0 then
		return "알 전멸"
	end
	return nil
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
	}
end

local function playGame(seed: number, presetRed: number, presetBlue: number)
	local rng = makeRandom(seed)
	local pieces = {}
	layoutTeam(1, Config.PresetTeams[presetRed].Pieces, pieces)
	layoutTeam(2, Config.PresetTeams[presetBlue].Pieces, pieces)

	-- 시작 배치가 겹치거나 판 밖이면 안 된다
	for i, a in pieces do
		assert(math.abs(a.x) + a.radius <= BOARD_HALF and math.abs(a.z) + a.radius <= BOARD_HALF, "시작 알이 판 밖")
		for j = i + 1, #pieces do
			local b = pieces[j]
			local dist = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			assert(dist >= a.radius + b.radius, "시작 알이 겹침: " .. a.kind .. " / " .. b.kind)
		end
	end

	local team = 1
	for turn = 1, MAX_TURNS do
		local shooters, shooterInfos, targets = {}, {}, {}
		for _, p in pieces do
			if p.alive then
				if p.team == team and (Config.CanFlickKing or p.kind ~= "King") then
					table.insert(shooters, p)
					table.insert(shooterInfos, infoOf(p))
				elseif p.team ~= team then
					table.insert(targets, infoOf(p))
				end
			end
		end
		local shot = Npc.chooseShot(shooterInfos, targets, {
			boardHalf = BOARD_HALF,
			gravity = GRAVITY,
			friction = Config.BoardFriction,
			elasticity = Config.Pieces.Flat.bounce,
			flickPower = Config.FlickPower,
			powerBoost = Config.NpcPowerBoost,
			aimErrorDegrees = Config.NpcAimErrorDegrees,
			damageScale = Config.DamageScale,
			damageMinSpeed = Config.DamageMinSpeed,
			mistakeChance = Config.NpcMistakeChance,
			powerError = Config.NpcPowerError,
		}, rng :: any)
		if shot then
			assert(shot.power >= 0 and shot.power <= 1, "세기가 0~1 밖")
			local shooter = shooters[shot.shooter]
			local speed = math.max(shot.power, Config.MinFlickPower) * Config.FlickPower / shooter.mass
			shooter.vx, shooter.vz = shot.dirX * speed, shot.dirZ * speed
		end
		local t = 0
		repeat
			step(pieces)
			t += DT
		until not anyMoving(pieces) or t > Config.MaxMoveTime

		local redLose, blueLose = loseReason(pieces, 1), loseReason(pieces, 2)
		if redLose or blueLose then
			local winner = if redLose and blueLose then 0 elseif redLose then 2 else 1
			return turn, winner, redLose or blueLose
		end
		team = 3 - team
	end
	return MAX_TURNS, -1, "끝나지 않음"
end

local presetCount = #Config.PresetTeams
local unfinished = 0
local reasons: { [string]: number } = {}
local totalGames, totalTurns = 0, 0
print("추천 팀끼리 NPC 대전 (각 조합 10판)")
for red = 1, presetCount do
	local line = {}
	for blue = 1, presetCount do
		local redWins = 0
		for seed = 1, 10 do
			local turns, winner, reason = playGame(seed * 7919 + red * 31 + blue, red, blue)
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
print(string.format("총 %d판, 평균 %.1f턴", totalGames, totalTurns / totalGames))
for reason, count in reasons do
	print(string.format("  끝난 이유 %s : %d판", reason, count))
end
print(if unfinished == 0 then "모든 판이 승패로 끝남" else ("끝나지 않은 판: " .. unfinished))
