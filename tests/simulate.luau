-- Studio 없이 NPC 대 NPC 로 판을 돌려 보는 시뮬레이션.
-- 실행 : luau tests/simulate.luau
-- 물리는 단순화 (원판 미끄러짐 + 마찰 + 탄성 충돌). 숫자는 Config.lua 와 맞춘다.
local Npc = require("../src/server/Npc")

local BOARD_HALF = 20
local GRAVITY = 196.2
local FRICTION = 0.3
local ELASTICITY = 0.4
local FLICK_POWER = 700
local MASS = 10
local RADIUS = 2
local DT = 1 / 240
local MAX_TURNS = 80

-- Roblox Random 대신 쓰는 간단한 난수
local function makeRandom(seed: number)
	local state = seed
	return {
		NextNumber = function(_, low: number, high: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return low + (high - low) * (state / 2147483648)
		end,
	}
end

local function newGame()
	local pieces = {}
	for team = 1, 2 do
		local side = if team == 1 then 1 else -1
		for i = 1, 5 do
			table.insert(pieces, { team = team, x = (i - 3) * 6, z = side * 12, vx = 0, vz = 0, alive = true })
		end
	end
	return pieces
end

local function step(pieces)
	local slow = FRICTION * GRAVITY * DT
	for _, p in pieces do
		if p.alive then
			local speed = math.sqrt(p.vx ^ 2 + p.vz ^ 2)
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
	-- 충돌
	for i = 1, #pieces do
		local a = pieces[i]
		for j = i + 1, #pieces do
			local b = pieces[j]
			if a.alive and b.alive then
				local dx, dz = b.x - a.x, b.z - a.z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < RADIUS * 2 and dist > 1e-6 then
					local nx, nz = dx / dist, dz / dist
					local closing = (a.vx - b.vx) * nx + (a.vz - b.vz) * nz
					if closing > 0 then
						local impulse = (1 + ELASTICITY) * closing / 2 -- 같은 질량
						a.vx -= impulse * nx
						a.vz -= impulse * nz
						b.vx += impulse * nx
						b.vz += impulse * nz
					end
					local push = (RADIUS * 2 - dist) / 2
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
		if p.alive and (math.abs(p.vx) > 0.5 or math.abs(p.vz) > 0.5) then
			return true
		end
	end
	return false
end

local function infos(pieces, team)
	local list, refs = {}, {}
	for _, p in pieces do
		if p.alive and p.team == team then
			table.insert(list, { x = p.x, z = p.z, mass = MASS, radius = RADIUS })
			table.insert(refs, p)
		end
	end
	return list, refs
end

local function count(pieces, team): number
	local n = 0
	for _, p in pieces do
		if p.alive and p.team == team then
			n += 1
		end
	end
	return n
end

local function playGame(seed: number, aimError: number)
	local rng = makeRandom(seed)
	local pieces = newGame()
	local team = 1
	local hits, ownLosses = 0, 0
	for turn = 1, MAX_TURNS do
		local mine, refs = infos(pieces, team)
		local enemies = infos(pieces, 3 - team)
		local shot = Npc.chooseShot(mine, enemies, {
			boardHalf = BOARD_HALF,
			gravity = GRAVITY,
			friction = FRICTION,
			elasticity = ELASTICITY,
			flickPower = FLICK_POWER,
			powerBoost = 1.25,
			aimErrorDegrees = aimError,
		}, rng :: any)
		assert(shot, "NPC 가 샷을 못 골랐다")
		assert(shot.power >= 0 and shot.power <= 1, "세기가 0~1 밖: " .. shot.power)
		local length = math.sqrt(shot.dirX ^ 2 + shot.dirZ ^ 2)
		assert(math.abs(length - 1) < 1e-6, "방향이 단위 벡터가 아님")

		local enemyBefore, mineBefore = count(pieces, 3 - team), count(pieces, team)
		local shooter = refs[shot.shooter]
		local speed = shot.power * FLICK_POWER / MASS
		shooter.vx, shooter.vz = shot.dirX * speed, shot.dirZ * speed
		local t = 0
		repeat
			step(pieces)
			t += DT
		until not anyMoving(pieces) or t > 12
		if count(pieces, 3 - team) < enemyBefore then
			hits += 1
		end
		ownLosses += mineBefore - count(pieces, team)

		local red, blue = count(pieces, 1), count(pieces, 2)
		if red == 0 or blue == 0 then
			local winner = if red == 0 and blue == 0 then "무승부" elseif red == 0 then "파랑" else "빨강"
			return turn, winner, hits, ownLosses
		end
		team = 3 - team
	end
	return MAX_TURNS, "끝나지 않음", hits, ownLosses
end

local unfinished = 0
for _, aimError in { 0, 10, 15 } do
	local totalTurns, totalHits, totalOwn = 0, 0, 0
	local games = 50
	for seed = 1, games do
		local turns, winner, hits, ownLosses = playGame(seed * 7919 + aimError, aimError)
		if winner == "끝나지 않음" then
			unfinished += 1
		end
		totalTurns += turns
		totalHits += hits
		totalOwn += ownLosses
	end
	print(string.format(
		"조준 오차 %2d도 : %d판 평균 %.1f턴, 명중률 %.0f%%, 판당 자책 %.2f개",
		aimError,
		games,
		totalTurns / games,
		100 * totalHits / totalTurns,
		totalOwn / games
	))
end
print(if unfinished == 0 then "모든 판이 승패로 끝남" else ("끝나지 않은 판: " .. unfinished))
