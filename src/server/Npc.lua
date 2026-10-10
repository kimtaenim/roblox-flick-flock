-- NPC(컴퓨터) 조준 : 상대 알을 판 밖으로 밀어낼 수 있는 샷을 고른다.
-- 계산은 숫자(x, z)만 써서 Studio 없이도 테스트할 수 있다.
--
-- 알 정보 : { x = number, z = number, mass = number, radius = number }
-- 설정 : { distanceToEdge(x, z, dx, dz), gravity, friction, elasticity, flickPower, powerBoost, aimErrorDegrees }

local Npc = {}

-- slow : 미끄러지거나 굴러가며 초당 줄어드는 속도 (없으면 판 마찰로 계산)
-- bounce : 튕김 (없으면 settings.elasticity)
-- isKing·hp : 왕알이면 표시. massFactor : 데미지 계산용 질량 계수 (없으면 1)
export type PieceInfo = {
	x: number,
	z: number,
	mass: number,
	radius: number,
	slow: number?,
	bounce: number?,
	isKing: boolean?,
	hp: number?,
	massFactor: number?,
	flickScale: number?, -- 튕기는 힘 배율 (없으면 1)
}
export type Shot = { shooter: number, target: number?, dirX: number, dirZ: number, power: number }

-- 점 (x, z) 에서 방향 (dx, dz) 로 갔을 때 판 가장자리까지 거리.
-- 판 모양(사각형·육각형)은 부르는 쪽이 settings.distanceToEdge 로 알려 준다 (BoardShape.distanceToEdge).
local function distanceToEdge(x: number, z: number, dx: number, dz: number, settings): number
	return settings.distanceToEdge(x, z, dx, dz)
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
-- 두 알이 부딪힐 때 튕김 (로블록스는 두 값의 평균)
local function pairBounce(a: PieceInfo, b: PieceInfo, settings): number
	return ((a.bounce or settings.elasticity) + (b.bounce or settings.elasticity)) / 2
end

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
	local targetTravel = distanceToEdge(target.x, target.z, dx, dz, settings) + 1
	local targetSpeed = math.sqrt(2 * targetSlow * targetTravel)
	-- 부딪힐 때 상대에게 전달되는 비율 (정면 충돌)
	local transfer = (1 + pairBounce(mine, target, settings)) * mine.mass / (mine.mass + target.mass)
	local hitSpeed = targetSpeed / transfer
	-- 부딪히기 전까지 내 알이 가는 거리
	local gap = math.max(distance - mine.radius - target.radius, 0)
	local startSpeed = math.sqrt(hitSpeed * hitSpeed + 2 * mineSlow * gap) * settings.powerBoost

	local power = startSpeed * mine.mass / (settings.flickPower * (mine.flickScale or 1))
	return power, dx, dz
end

-- 부딪힌 뒤 내 알이 계속 미끄러져서 판 밖으로 떨어질지 (무거운 알에 맞고 뒤로 튕기는 것도)
local function shooterFallsOff(mine: PieceInfo, target: PieceInfo, power: number, dx: number, dz: number, settings): boolean
	local defaultSlow = settings.friction * settings.gravity
	local mineSlow = mine.slow or defaultSlow
	local distance = math.sqrt((target.x - mine.x) ^ 2 + (target.z - mine.z) ^ 2)
	local gap = math.max(distance - mine.radius - target.radius, 0)
	local startSpeed = math.min(power, 1) * settings.flickPower * (mine.flickScale or 1) / mine.mass
	local hitSpeedSq = startSpeed * startSpeed - 2 * mineSlow * gap
	if hitSpeedSq <= 0 then
		return false
	end
	-- 정면 충돌 뒤 내 알 속도 (음수면 뒤로 튕김)
	local leftSpeed = math.sqrt(hitSpeedSq) * (mine.mass - pairBounce(mine, target, settings) * target.mass) / (mine.mass + target.mass)
	local travel = leftSpeed * leftSpeed / (2 * mineSlow)
	local hitX = target.x - dx * (mine.radius + target.radius)
	local hitZ = target.z - dz * (mine.radius + target.radius)
	if leftSpeed >= 0 then
		return travel > distanceToEdge(hitX, hitZ, dx, dz, settings)
	end
	return travel > distanceToEdge(hitX, hitZ, -dx, -dz, settings)
end

-- 왕알 들이받기 : 떨어지지 않는 가장 센 세기와 그때 데미지
local function kingAttack(mine: PieceInfo, king: PieceInfo, settings): (number, number, number, number)
	local dx, dz = king.x - mine.x, king.z - mine.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-3 then
		return 0, 0, 0, 0
	end
	dx, dz = dx / distance, dz / distance
	local slow = mine.slow or settings.friction * settings.gravity
	local gap = math.max(distance - mine.radius - king.radius, 0)
	local power = 1
	while power >= 0.4 do
		if not shooterFallsOff(mine, king, power, dx, dz, settings) then
			local startSpeed = power * settings.flickPower * (mine.flickScale or 1) / mine.mass
			local hitSpeedSq = startSpeed * startSpeed - 2 * slow * gap
			if hitSpeedSq <= 0 then
				return 0, power, dx, dz
			end
			local hitSpeed = math.sqrt(hitSpeedSq)
			local damage = 0
			if hitSpeed >= settings.damageMinSpeed then
				damage = hitSpeed * (mine.massFactor or 1) * settings.damageScale
			end
			return damage, power, dx, dz
		end
		power -= 0.1
	end
	return 0, 0, dx, dz
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

	-- 점수가 높은 샷을 고른다. 왕알을 가장 먼저 노린다.
	local best: Shot? = nil
	local bestValue = -math.huge
	local function consider(value: number, shot: Shot)
		if value > bestValue then
			bestValue = value
			best = shot
		end
	end

	for shooterIndex, shooter in mine do
		for targetIndex, target in enemies do
			local blocked = isBlocked(shooter, target, everyone)

			-- ① 판 밖으로 밀어내기
			local power, dx, dz = powerNeeded(shooter, target, settings)
			if power < math.huge then
				local value = if target.isKing then 100 else 15 - power * 5
				if power > 1 then
					value = if target.isKing then 5 else 2 -- 힘이 모자라면 웬만하면 안 고른다
				end
				if blocked then
					value -= 20
				end
				if shooterFallsOff(shooter, target, power, dx, dz, settings) then
					value -= 12 -- 내 알도 같이 떨어질 것 같으면 피한다
				end
				consider(value, { shooter = shooterIndex, target = targetIndex, dirX = dx, dirZ = dz, power = math.min(power, 1) })
			end

			-- ② 왕알 들이받기
			if target.isKing and not blocked then
				local damage, attackPower, kx, kz = kingAttack(shooter, target, settings)
				if damage > 0 then
					local hp = target.hp or 100
					local value = if damage >= hp then 90 else 25 + 20 * math.min(damage / hp, 1)
					consider(value, { shooter = shooterIndex, target = targetIndex, dirX = kx, dirZ = kz, power = attackPower })
				end
			end
		end
	end

	-- 좋은 샷이 없으면 그래도 왕알 쪽으로 (가는 길의 알을 밀어 준다)
	if bestValue < 0 then
		for targetIndex, target in enemies do
			if target.isKing then
				local shooter = mine[1]
				local dx, dz = target.x - shooter.x, target.z - shooter.z
				local length = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
				best = { shooter = 1, target = targetIndex, dirX = dx / length, dirZ = dz / length, power = 0.7 }
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

	-- 가끔 실수 : 아무 알로 아무 상대 알 쪽을 아무 세기로
	if settings.mistakeChance and rng:NextNumber(0, 1) < settings.mistakeChance and #enemies > 0 then
		local shooterIndex = math.clamp(math.floor(rng:NextNumber(1, #mine + 1)), 1, #mine)
		local targetIndex = math.clamp(math.floor(rng:NextNumber(1, #enemies + 1)), 1, #enemies)
		local shooter, target = mine[shooterIndex], enemies[targetIndex]
		local dx, dz = target.x - shooter.x, target.z - shooter.z
		local length = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
		result = {
			shooter = shooterIndex,
			target = targetIndex,
			dirX = dx / length,
			dirZ = dz / length,
			power = rng:NextNumber(0.3, 1),
		}
	end

	-- 세기도 사람처럼 들쭉날쭉
	if settings.powerError then
		result.power = math.clamp(result.power * rng:NextNumber(1 - settings.powerError, 1 + settings.powerError), 0, 1)
	end

	-- 사람처럼 조금 빗나가게
	local errorDegrees = rng:NextNumber(-settings.aimErrorDegrees, settings.aimErrorDegrees)
	result.dirX, result.dirZ = rotate(result.dirX, result.dirZ, errorDegrees)
	return result
end

return Npc
