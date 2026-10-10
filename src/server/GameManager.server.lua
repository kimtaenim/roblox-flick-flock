-- 라운드·턴 진행
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AbilityList = require(Shared:WaitForChild("AbilityList"))
local Board = require(script.Parent:WaitForChild("Board"))
local PieceFactory = require(script.Parent:WaitForChild("PieceFactory"))
local Placement = require(script.Parent:WaitForChild("Placement"))
local Elimination = require(script.Parent:WaitForChild("Elimination"))
local Damage = require(script.Parent:WaitForChild("Damage"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Npc = require(script.Parent:WaitForChild("Npc"))
local Speech = require(script.Parent:WaitForChild("Speech"))

local state = Remotes.State
local random = Random.new()

-- 능력 모듈 불러오기 (Abilities 폴더 안 파일 하나 = 능력 하나)
local Abilities = {}
for _, ability in AbilityList.List do
	Abilities[ability.Id] = require(script.Parent:WaitForChild("Abilities"):WaitForChild(ability.Id))
end

-- 충돌 그룹
-- Pieces : 보통 알 / Ghost : 유령·똥 (판에만 닿고 알은 통과) / Characters : 캐릭터 (알과 안 부딪힘)
local CHARACTER_GROUP = "Characters"
local GHOST_GROUP = "Ghost"
PhysicsService:RegisterCollisionGroup(PieceFactory.COLLISION_GROUP)
PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
PhysicsService:RegisterCollisionGroup(GHOST_GROUP)
PhysicsService:CollisionGroupSetCollidable(PieceFactory.COLLISION_GROUP, CHARACTER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP, PieceFactory.COLLISION_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP, CHARACTER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP, GHOST_GROUP, false)

local function setCharacterGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = CHARACTER_GROUP
	end
end

local function onCharacterAdded(character: Model)
	for _, part in character:GetDescendants() do
		setCharacterGroup(part)
	end
	character.DescendantAdded:Connect(setCharacterGroup)
end

local piecesFolder = Instance.new("Folder")
piecesFolder.Name = "Pieces"
piecesFolder.Parent = workspace

Board.build()
Damage.start(piecesFolder)

---------------------------------------------------------------- 팀 주인

-- teamOwners[1] = 빨강 플레이어, teamOwners[2] = 파랑 플레이어 (NPC 면 "Npc")
local NPC_OWNER_ID = -1
local teamOwners: { [number]: Player | string | nil } = {}
local restartRequested = false

local function assignTeams()
	local list = Players:GetPlayers()
	teamOwners[1] = list[1]
	if list[2] then
		teamOwners[2] = list[2]
	elseif Config.SoloMode == "BothTeams" then
		teamOwners[2] = list[1]
	else
		teamOwners[2] = "Npc"
	end
	for team = 1, 2 do
		local owner = teamOwners[team]
		local ownerId = 0
		if owner == "Npc" then
			ownerId = NPC_OWNER_ID
		elseif typeof(owner) == "Instance" and owner:IsA("Player") then
			ownerId = owner.UserId
		end
		state:SetAttribute("Team" .. team .. "Owner", ownerId)
	end
end

local function isSoloGame(): boolean
	return teamOwners[1] ~= nil and (teamOwners[2] == "Npc" or teamOwners[1] == teamOwners[2])
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	-- 혼자 하던 중에 친구가 들어오면 2인으로 새로 시작
	if isSoloGame() then
		restartRequested = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if teamOwners[1] == player or teamOwners[2] == player then
		restartRequested = true
	end
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

---------------------------------------------------------------- 알 목록

local function piecesOf(team: number): { BasePart }
	local list = {}
	for _, piece in piecesFolder:GetChildren() do
		if piece:IsA("BasePart") and piece:GetAttribute("Team") == team then
			table.insert(list, piece)
		end
	end
	return list
end

local function kingOf(team: number): BasePart?
	for _, piece in piecesOf(team) do
		if piece:GetAttribute("Kind") == "King" then
			return piece
		end
	end
	return nil
end

local function countSoldiers(team: number): number
	local count = 0
	for _, piece in piecesOf(team) do
		if piece:GetAttribute("Kind") ~= "King" then
			count += 1
		end
	end
	return count
end

local function watchPiece(piece: BasePart)
	Damage.watchPiece(piece)
end

---------------------------------------------------------------- 매 프레임 물리

-- 똥을 이미 밟은 알 (같은 똥을 지나는 동안 한 번만 느려짐)
local steppedInPoop: { [BasePart]: { [BasePart]: boolean } } = {}
local lastFootprint: { [BasePart]: number } = {}

RunService.Heartbeat:Connect(function()
	-- 판 밖으로 나간 알은 바로 탈락
	local function sayGoodbye(piece: BasePart)
		Speech.say(piece, "Out", true)
	end
	for _, removed in Elimination.removeOutPieces(piecesFolder, sayGoodbye) do
		Effects.sound("Out")
		Effects.sound("OutCry", nil, if removed.kind == "King" then 0.5 elseif removed.kind == "Half" then 1.3 else 1)
		Effects.sparkle(removed.position, Config.Teams[removed.team].Color, 20)
	end

	local poops = {}
	for _, piece in piecesFolder:GetChildren() do
		if piece:IsA("BasePart") then
			if piece:GetAttribute("Effect") == "Poop" then
				table.insert(poops, piece)
			end
		end
	end

	-- 똥 밟기 : 똥과 겹친 알은 확 느려지고 발자국
	for _, poop in poops do
		local stepped = steppedInPoop[poop]
		if not stepped then
			stepped = {}
			steppedInPoop[poop] = stepped
		end
		for _, other in piecesFolder:GetChildren() do
			if other:IsA("BasePart") and other ~= poop and not other.Anchored then
				local gap = (other.Position - poop.Position) * Vector3.new(1, 0, 1)
				local touching = gap.Magnitude < PieceFactory.radius(poop) + PieceFactory.radius(other)
				if touching then
					if not stepped[other] then
						stepped[other] = true
						other.AssemblyLinearVelocity *= Config.PoopSlowFactor
						Effects.sound("PoopStep", poop)
					end
					local now = os.clock()
					if other.AssemblyLinearVelocity.Magnitude > 1 and now - (lastFootprint[other] or 0) > 0.15 then
						lastFootprint[other] = now
						Effects.footprint(other.Position)
					end
				else
					stepped[other] = nil
				end
			end
		end
	end
end)

---------------------------------------------------------------- 능력 효과 (몇 턴 유지)

local activeEffects: { [BasePart]: { id: string, turnsLeft: number } } = {}
-- 소환처럼 시간이 걸리는 능력이 끝날 때까지 턴을 안 넘긴다
local busyCount = 0
local turnEndCallbacks: { () -> () } = {}

local function startEffect(piece: BasePart, id: string)
	activeEffects[piece] = { id = id, turnsLeft = Config.EffectTurns[id] or 2 }
	piece:SetAttribute("Effect", id)
end

local function endEffect(piece: BasePart, effect: { id: string, turnsLeft: number })
	activeEffects[piece] = nil
	steppedInPoop[piece] = nil
	if piece.Parent then
		piece:SetAttribute("Effect", nil)
		Abilities[effect.id].OnTurnEnd(piece)
	end
end

local function onTurnEnd()
	for _, callback in turnEndCallbacks do
		callback()
	end
	table.clear(turnEndCallbacks)

	for piece, effect in activeEffects do
		effect.turnsLeft -= 1
		if effect.turnsLeft <= 0 or not piece.Parent then
			endEffect(piece, effect)
		end
	end
end

local function clearAllEffects()
	for piece, effect in activeEffects do
		endEffect(piece, effect)
	end
	for _, callback in turnEndCallbacks do
		callback()
	end
	table.clear(turnEndCallbacks)
end

local function makeContext(team: number)
	return {
		team = team,
		piecesFolder = piecesFolder,
		random = random,
		Config = Config,
		Remotes = Remotes,
		PieceFactory = PieceFactory,
		Placement = Placement,
		Effects = Effects,
		Damage = Damage,
		Speech = Speech,
		GHOST_GROUP = GHOST_GROUP,
		startEffect = startEffect,
		watchPiece = watchPiece,
		onTurnEnd = function(callback: () -> ())
			table.insert(turnEndCallbacks, callback)
		end,
		-- 오래 걸리는 연출 시작 : 끝나면 돌려받은 함수를 부른다
		hold = function(): () -> ()
			busyCount += 1
			local released = false
			return function()
				if not released then
					released = true
					busyCount -= 1
				end
			end
		end,
	}
end

---------------------------------------------------------------- 튕기기·능력 (사람·NPC 공통)

local function applyFlick(piece: BasePart, direction: Vector3, power: number)
	state:SetAttribute("Phase", "Moving")
	piece:SetNetworkOwner(nil)
	local info = Config.Pieces[piece:GetAttribute("Kind") :: string]
	local flickScale = if info and info.flickScale then info.flickScale else 1
	piece:ApplyImpulse(direction.Unit * power * Config.FlickPower * flickScale)
	Effects.sound("Flick", piece)
	-- 상대 왕알을 노리고 치면 허세, 아니면 보통 대사
	local enemyKing = kingOf(3 - (piece:GetAttribute("Team") :: number))
	local aimingAtKing = false
	if enemyKing then
		local toKing = (enemyKing.Position - piece.Position) * Vector3.new(1, 0, 1)
		if toKing.Magnitude > 0.1 then
			local cosine = toKing.Unit:Dot(direction.Unit)
			aimingAtKing = cosine >= math.cos(math.rad(Config.TauntAngle))
		end
	end
	if aimingAtKing then
		Speech.say(piece, "Taunt", true)
	else
		Speech.say(piece, "Flick")
	end
end

local function useAbility(piece: BasePart, team: number)
	local id = piece:GetAttribute("Ability")
	local ability = AbilityList.get(id)
	if not ability then
		return
	end
	state:SetAttribute("Phase", "Moving")
	-- 능력 알은 1회 사용 (Config.ReusableAbilities 는 계속 쓸 수 있음)
	if not Config.ReusableAbilities[ability.Id] then
		piece:SetAttribute("Ability", nil)
		PieceFactory.refreshAbilityTag(piece)
	end
	Effects.sound(if Config.Sounds[ability.Id] then ability.Id else "Ability", piece)
	Effects.banner(Config.Teams[team].Name .. " : " .. ability.Icon .. " " .. ability.Name .. "!", Config.Teams[team].Color)
	Speech.sayAbility(piece, ability.Id)
	Abilities[ability.Id].Execute(piece, makeContext(team))
end

local function canFlick(piece: BasePart): boolean
	return not piece.Anchored and (Config.CanFlickKing or piece:GetAttribute("Kind") ~= "King")
end

local function isMyPieceNow(player: Player, piece: any): (boolean, number)
	if state:GetAttribute("Phase") ~= "Aiming" then
		return false, 0
	end
	local team = state:GetAttribute("CurrentTeam")
	if teamOwners[team] ~= player then
		return false, team
	end
	if typeof(piece) ~= "Instance" or not piece:IsA("BasePart") or piece.Parent ~= piecesFolder then
		return false, team
	end
	return piece:GetAttribute("Team") == team, team
end

-- 튕기기 요청 (클라이언트는 "이 알을 이 방향으로 이만큼"만 보낸다)
Remotes.Flick.OnServerEvent:Connect(function(player, piece, direction, power)
	local ok = isMyPieceNow(player, piece)
	if not ok or not canFlick(piece) then
		return
	end
	if typeof(direction) ~= "Vector3" or typeof(power) ~= "number" or power ~= power then
		return
	end
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.01 then
		return
	end
	power = math.clamp(power, 0, 1)
	if power < Config.MinFlickPower then
		return
	end
	applyFlick(piece, flatDirection, power)
end)

Remotes.UseAbility.OnServerEvent:Connect(function(player, piece)
	local ok, team = isMyPieceNow(player, piece)
	if ok and piece:GetAttribute("Ability") then
		useAbility(piece, team)
	end
end)

---------------------------------------------------------------- NPC

-- 미끄러지며 초당 줄어드는 속도 = (알 마찰 + 판 마찰) / 2 × 중력
local function slowOf(piece: BasePart): number
	local info = Config.Pieces[piece:GetAttribute("Kind") :: string]
	local friction = if info then info.friction else Config.BoardFriction
	return (friction + Config.BoardFriction) / 2 * workspace.Gravity
end

local function toInfo(piece: BasePart): Npc.PieceInfo
	local info = Config.Pieces[piece:GetAttribute("Kind") :: string]
	return {
		x = piece.Position.X,
		z = piece.Position.Z,
		mass = piece.AssemblyMass,
		radius = PieceFactory.radius(piece),
		slow = slowOf(piece),
		bounce = if info then info.bounce else nil,
		isKing = piece:GetAttribute("Kind") == "King",
		hp = piece:GetAttribute("Hp") :: number?,
		massFactor = PieceFactory.massFactor(piece),
		flickScale = if info then info.flickScale else nil,
	}
end

-- NPC 가 쓸 만한 능력 알 고르기
local function chooseNpcAbility(team: number): BasePart?
	-- 상대 왕알 가까이 있는 폭발 알은 무조건 터뜨린다
	local enemyKing = kingOf(3 - team)
	if enemyKing then
		for _, piece in piecesOf(team) do
			if
				piece:GetAttribute("Ability") == "Explosion"
				and (enemyKing.Position - piece.Position).Magnitude < Config.ExplosionRadius * 0.8
			then
				return piece
			end
		end
	end
	if random:NextNumber() >= Config.NpcAbilityChance then
		return nil
	end
	local candidates = {}
	for _, piece in piecesOf(team) do
		local id = piece:GetAttribute("Ability")
		if id == "Explosion" then
			-- 주변에 상대 알이 있을 때만 터뜨린다
			for _, enemy in piecesOf(3 - team) do
				if (enemy.Position - piece.Position).Magnitude < Config.ExplosionRadius * 0.7 then
					table.insert(candidates, piece)
					break
				end
			end
		elseif id then
			table.insert(candidates, piece)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[random:NextInteger(1, #candidates)]
end

local function playNpcTurn(team: number)
	task.wait(Config.NpcThinkTime)
	if restartRequested or state:GetAttribute("Phase") ~= "Aiming" then
		return
	end

	local abilityPiece = chooseNpcAbility(team)
	if abilityPiece then
		useAbility(abilityPiece, team)
		return
	end

	local shooters, shooterInfos = {}, {}
	for _, piece in piecesOf(team) do
		if canFlick(piece) then
			table.insert(shooters, piece)
			table.insert(shooterInfos, toInfo(piece))
		end
	end
	-- 맞힐 수 있는 상대 알 / 길만 막는 알 (자석·유령·똥은 못 밀어냄)
	local targets, blockers = {}, {}
	for _, piece in piecesOf(3 - team) do
		if piece.CollisionGroup == GHOST_GROUP then
			continue
		end
		table.insert(if piece.Anchored then blockers else targets, toInfo(piece))
	end

	local shot = Npc.chooseShot(shooterInfos, targets, {
		boardHalf = Config.BoardSize / 2,
		gravity = workspace.Gravity,
		friction = Config.BoardFriction,
		elasticity = Config.Pieces.Flat.bounce,
		flickPower = Config.FlickPower,
		powerBoost = Config.NpcPowerBoost,
		aimErrorDegrees = Config.NpcAimErrorDegrees,
		damageScale = Config.DamageScale,
		damageMinSpeed = Config.DamageMinSpeed,
		mistakeChance = Config.NpcMistakeChance,
		powerError = Config.NpcPowerError,
	}, random, blockers)
	if not shot then
		-- 튕길 알이 없으면 차례만 넘긴다
		state:SetAttribute("Phase", "Moving")
		return
	end
	applyFlick(shooters[shot.shooter], Vector3.new(shot.dirX, 0, shot.dirZ), math.max(shot.power, Config.MinFlickPower))
end

---------------------------------------------------------------- 팀 고르기

local teamChoices: { [number]: { { string } }? } = {}

local function randomAbilityId(): string
	local list = AbilityList.List
	return list[random:NextInteger(1, #list)].Id
end

local function copyPreset(index: number): { { string } }
	local list = {}
	for _, entry in Config.PresetTeams[index].Pieces do
		table.insert(list, { entry[1], entry[2] })
	end
	return list
end

-- 직접 고른 팀 { Flat = n, Round = n, Half = n, Ability = n } → 알 목록 (예산 넘으면 nil)
local function buildCustomTeam(choice: any): { { string } }?
	if typeof(choice) ~= "table" then
		return nil
	end
	local total, cost = 0, 0
	local counts = {}
	for name, price in Config.Prices do
		local count = choice[name]
		if count == nil then
			count = 0
		end
		if typeof(count) ~= "number" or count < 0 or count ~= math.floor(count) then
			return nil
		end
		counts[name] = count
		total += count
		cost += count * price
	end
	if total < 1 or cost > Config.Budget or total > Config.PiecesPerRow * #Config.RowDistances then
		return nil
	end
	local list = {}
	for _ = 1, counts.Flat do
		table.insert(list, { "Flat" })
	end
	for _ = 1, counts.Round do
		table.insert(list, { "Round" })
	end
	for _ = 1, counts.Half do
		table.insert(list, { "Half" })
	end
	for _ = 1, counts.Ability do
		table.insert(list, { if random:NextNumber() < 0.5 then "Flat" else "Round", randomAbilityId() })
	end
	return list
end

local function setChoice(team: number, pieces: { { string } })
	teamChoices[team] = pieces
	state:SetAttribute("Team" .. team .. "Ready", true)
end

Remotes.SelectTeam.OnServerEvent:Connect(function(player, choice)
	if state:GetAttribute("Phase") ~= "TeamSelect" then
		return
	end
	-- 이 플레이어가 맡은 팀 중 아직 안 고른 팀 (혼자 두 팀이면 빨강 먼저)
	for team = 1, 2 do
		if teamOwners[team] == player and not state:GetAttribute("Team" .. team .. "Ready") then
			local pieces
			if typeof(choice) == "number" and Config.PresetTeams[choice] then
				pieces = copyPreset(choice)
			else
				pieces = buildCustomTeam(choice)
			end
			if pieces then
				setChoice(team, pieces)
			end
			return
		end
	end
end)

local function runTeamSelect()
	table.clear(teamChoices)
	state:SetAttribute("Team1Ready", false)
	state:SetAttribute("Team2Ready", false)
	state:SetAttribute("SelectEndsAt", workspace:GetServerTimeNow() + Config.TeamSelectTime)
	state:SetAttribute("Phase", "TeamSelect")

	for team = 1, 2 do
		if teamOwners[team] == "Npc" then
			task.delay(1, function()
				if state:GetAttribute("Phase") == "TeamSelect" and not teamChoices[team] then
					setChoice(team, copyPreset(random:NextInteger(1, #Config.PresetTeams)))
				end
			end)
		end
	end

	local deadline = os.clock() + Config.TeamSelectTime
	while not (teamChoices[1] and teamChoices[2]) and os.clock() < deadline and not restartRequested do
		task.wait(0.1)
	end
	for team = 1, 2 do
		if not teamChoices[team] then
			setChoice(team, copyPreset(1))
		end
	end
end

---------------------------------------------------------------- 판 진행

local function setupPieces()
	clearAllEffects()
	piecesFolder:ClearAllChildren()
	for team = 1, 2 do
		for _, piece in Placement.layoutTeam(team, teamChoices[team] or copyPreset(1), piecesFolder) do
			watchPiece(piece)
		end
	end
end

-- 모든 알이 멈출 때까지 기다린다
local function waitUntilStopped()
	-- 소환 연출이 끝날 때까지 (최대 20초)
	local busyTime = 0
	while busyCount > 0 and busyTime < 20 and not restartRequested do
		busyTime += RunService.Heartbeat:Wait()
	end
	busyCount = 0
	local stillTime = 0
	local elapsed = 0
	while elapsed < Config.MaxMoveTime and not restartRequested do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local moving = false
		for _, piece in piecesFolder:GetChildren() do
			if
				piece:IsA("BasePart")
				and (
					piece.AssemblyLinearVelocity.Magnitude > Config.StopSpeed
					or piece.AssemblyAngularVelocity.Magnitude > Config.StopSpeed
				)
			then
				moving = true
				break
			end
		end
		stillTime = if moving then 0 else stillTime + dt
		if stillTime >= Config.StopHoldTime then
			return
		end
	end
end

-- 진 팀 확인 : 왕알이 없거나 HP 0, 또는 왕알 말고 남은 알이 없으면 진다
local function loseReason(team: number): string?
	local king = kingOf(team)
	if not king then
		return "왕알이 판 밖으로!"
	end
	if (king:GetAttribute("Hp") or 0) <= 0 then
		return "왕알 격파!"
	end
	if countSoldiers(team) == 0 then
		return "알이 모두 떨어졌어요!"
	end
	return nil
end

local function playRound()
	runTeamSelect()
	if restartRequested then
		return
	end
	setupPieces()
	-- 왕알들이 한마디씩
	for team = 1, 2 do
		local king = kingOf(team)
		if king then
			task.delay(team * 0.8, function()
				if king.Parent then
					Speech.say(king, "Start", true)
				end
			end)
		end
	end
	state:SetAttribute("Winner", 0)
	state:SetAttribute("WinReason", "")
	state:SetAttribute("CurrentTeam", 1)

	while true do
		state:SetAttribute("Phase", "Aiming")
		local team = state:GetAttribute("CurrentTeam")
		Effects.sound("TurnStart")
		if teamOwners[team] == "Npc" then
			task.spawn(playNpcTurn, team)
		end
		while state:GetAttribute("Phase") == "Aiming" do
			if restartRequested then
				return
			end
			task.wait(0.1)
		end

		waitUntilStopped()
		if restartRequested then
			return
		end
		onTurnEnd()

		-- 쓰러진 왕알 정리
		for checkTeam = 1, 2 do
			local king = kingOf(checkTeam)
			if king and (king:GetAttribute("Hp") or 0) <= 0 then
				Effects.explosion(king.Position)
				Effects.sound("KingDown")
				king:Destroy()
			end
		end

		local redLose, blueLose = loseReason(1), loseReason(2)
		if redLose or blueLose then
			local winner = if redLose and blueLose then -1 elseif redLose then 2 else 1
			state:SetAttribute("Winner", winner)
			state:SetAttribute("WinReason", if winner == -1 then "둘 다 쓰러졌어요" elseif winner == 1 then blueLose else redLose)
			state:SetAttribute("Phase", "GameOver")
			Effects.melody(if winner == -1 then "Draw" else "Win")
			-- 이긴 팀 왕알과 알 하나가 환호
			if winner ~= -1 then
				local winners = piecesOf(winner)
				local king = kingOf(winner)
				if king then
					Speech.say(king, "Win", true)
				end
				for _, piece in winners do
					if piece ~= king then
						task.delay(0.6, function()
							if piece.Parent then
								Speech.say(piece, "Win", true)
							end
						end)
						break
					end
				end
			end
			task.wait(Config.RestartDelay)
			return
		end

		state:SetAttribute("CurrentTeam", 3 - team)
	end
end

-- 플레이어를 기다렸다가 판을 계속 돌린다
while true do
	state:SetAttribute("Phase", "Waiting")
	local waited = 0
	while true do
		local count = #Players:GetPlayers()
		if count >= 2 then
			break
		end
		if count == 1 and waited >= Config.SoloWaitTime then
			break
		end
		if count == 0 then
			waited = 0
		end
		waited += task.wait(0.25)
	end

	restartRequested = false
	assignTeams()
	while not restartRequested do
		playRound()
	end
end
