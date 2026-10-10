-- NPC(컴퓨터) 조준 : 상대 알을 판 밖으로 밀어낼 수 있는 샷을 고른다.
-- 계산은 숫자(x, z)만 써서 Studio 없이도 테스트할 수 있다.
--
-- 알 정보 : { x = number, z = number, mass = number, radius = number }
-- 설정 : { boardHalf, gravity, friction, elasticity, flickPower, powerBoost, aimErrorDegrees }

local Npc = {}

-- slow : 미끄러지거나 굴러가며 초당 줄어드는 속도 (없으면 판 마찰로 계산)
export type PieceInfo = { x: number, z: number, mass: number, radius: number, slow: number? }
export type Shot = { shooter: number, target: number?, dirX: number, dirZ: number, power: number }

-- 점 (x, z) 에서 방향 (dx, dz) 로 갔을 때 판 가장자리까지 거리
local function distanceToEdge(x: number, z: number, dx: number, dz: number, half: number): number
	local best = math.huge
	if dx > 1e-6 then
		best = math.min(best, (half - x) / dx)
	elseif dx < -1e-6 then
		best = math.min(best, (-half - x) / dx)
	end
	if dz > 1e-6 then
		best = math.min(best, (half - z) / dz)
	elseif dz < -1e-6 then
		best = math.min(best, (-half - z) / dz)
	end
	return math.max(best, 0)
end

-- 선분 a→b 와 점 p 사이 거리
local function distanceToSegment(ax: number, az: number, bx: number, bz: number, px: number, pz: number): number
	local abx, abz = bx - ax, bz - az
	local lengthSq = abx * abx + abz * abz
	local t = if lengthSq > 0 then math.clamp(((px - ax) * abx + (pz - az) * abz) / lengthSq, 0, 1) else 0
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- 가는 길에 다른 알이 막고 있는지
local function isBlocked(mine: PieceInfo, target: PieceInfo, everyone: { PieceInfo }): boolean
	for _, other in everyone do
		if other ~= mine and other ~= target then
			local gap = distanceToSegment(mine.x, mine.z, target.x, target.z, other.x, other.z)
			if gap < mine.radius + other.radius then
				return true
			end
		end
	end
	return false
end

-- 내 알로 상대 알을 밖으로 보내려면 필요한 세기 (0~1 이 넘으면 불가능)
local function powerNeeded(mine: PieceInfo, target: PieceInfo, settings): (number, number, number)
	local dx, dz = target.x - mine.x, target.z - mine.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-3 then
		return math.huge, 0, 0
	end
	dx, dz = dx / distance, dz / distance

	local defaultSlow = settings.friction * settings.gravity -- 미끄러지며 줄어드는 속도 (초당)
	local mineSlow = mine.slow or defaultSlow
	local targetSlow = target.slow or defaultSlow
	-- 상대 알이 가장자리를 넘을 때까지 가야 하는 거리 (가운데가 넘으면 탈락, 여유 1)
	local targetTravel = distanceToEdge(target.x, target.z, dx, dz, settings.boardHalf) + 1
	local targetSpeed = math.sqrt(2 * targetSlow * targetTravel)
	-- 부딪힐 때 상대에게 전달되는 비율 (정면 충돌)
	local transfer = (1 + settings.elasticity) * mine.mass / (mine.mass + target.mass)
	local hitSpeed = targetSpeed / transfer
	-- 부딪히기 전까지 내 알이 가는 거리
	local gap = math.max(distance - mine.radius - target.radius, 0)
	local startSpeed = math.sqrt(hitSpeed * hitSpeed + 2 * mineSlow * gap) * settings.powerBoost

	local power = startSpeed * mine.mass / settings.flickPower
	return power, dx, dz
end

-- 부딪힌 뒤 내 알이 계속 굴러가서 판 밖으로 떨어질지
local function shooterFallsOff(mine: PieceInfo, target: PieceInfo, power: number, dx: number, dz: number, settings): boolean
	local defaultSlow = settings.friction * settings.gravity
	local mineSlow = mine.slow or defaultSlow
	local distance = math.sqrt((target.x - mine.x) ^ 2 + (target.z - mine.z) ^ 2)
	local gap = math.max(distance - mine.radius - target.radius, 0)
	local startSpeed = math.min(power, 1) * settings.flickPower / mine.mass
	local hitSpeedSq = startSpeed * startSpeed - 2 * mineSlow * gap
	if hitSpeedSq <= 0 then
		return false
	end
	-- 정면 충돌 뒤 내 알 속도
	local leftSpeed = math.sqrt(hitSpeedSq) * (mine.mass - settings.elasticity * target.mass) / (mine.mass + target.mass)
	if leftSpeed <= 0 then
		return false
	end
	local travel = leftSpeed * leftSpeed / (2 * mineSlow)
	local hitX = target.x - dx * (mine.radius + target.radius)
	local hitZ = target.z - dz * (mine.radius + target.radius)
	return travel > distanceToEdge(hitX, hitZ, dx, dz, settings.boardHalf)
end

local function rotate(dx: number, dz: number, degrees: number): (number, number)
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return dx * c - dz * s, dx * s + dz * c
end

-- others : 맞힐 수는 없지만 길을 막는 알 (자석 알 등)
function Npc.chooseShot(mine: { PieceInfo }, enemies: { PieceInfo }, settings, random: Random?, others: { PieceInfo }?): Shot?
	if #mine == 0 then
		return nil
	end
	local rng = random or Random.new()

	local everyone = {}
	for _, piece in mine do
		table.insert(everyone, piece)
	end
	for _, piece in enemies do
		table.insert(everyone, piece)
	end
	if others then
		for _, piece in others do
			table.insert(everyone, piece)
		end
	end

	local best: Shot? = nil
	local bestScore = math.huge
	for shooterIndex, shooter in mine do
		for targetIndex, target in enemies do
			local power, dx, dz = powerNeeded(shooter, target, settings)
			if power < math.huge then
				local score = power
				if isBlocked(shooter, target, everyone) then
					score += 10 -- 막혀 있으면 웬만하면 안 고른다
				end
				if power > 1 then
					score += 5 -- 힘이 모자라면 뒤로 미룬다
				end
				if shooterFallsOff(shooter, target, power, dx, dz, settings) then
					score += 3 -- 내 알도 같이 떨어질 것 같으면 웬만하면 피한다
				end
				if score < bestScore then
					bestScore = score
					best = { shooter = shooterIndex, target = targetIndex, dirX = dx, dirZ = dz, power = math.min(power, 1) }
				end
			end
		end
	end

	local result: Shot
	if best then
		result = best
	else
		-- 상대 알이 없으면 가운데 쪽으로 살짝
		local shooter = mine[1]
		local length = math.max(math.sqrt(shooter.x ^ 2 + shooter.z ^ 2), 1e-3)
		result = { shooter = 1, target = nil, dirX = -shooter.x / length, dirZ = -shooter.z / length, power = 0.3 }
	end

	-- 사람처럼 조금 빗나가게
	local errorDegrees = rng:NextNumber(-settings.aimErrorDegrees, settings.aimErrorDegrees)
	result.dirX, result.dirZ = rotate(result.dirX, result.dirZ, errorDegrees)
	return result
end

return Npc
