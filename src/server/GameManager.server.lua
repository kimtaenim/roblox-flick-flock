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
local TeamLayout = require(Shared:WaitForChild("TeamLayout"))
local BoardShape = require(Shared:WaitForChild("BoardShape"))

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

Board.build(Config.DefaultTeamCount)
Damage.start(piecesFolder)

---------------------------------------------------------------- 팀 주인

-- teamOwners[팀 번호] = 그 팀을 조종하는 플레이어 (NPC 면 "Npc"). 팀 수는 teamCount.
local NPC_OWNER_ID = -1
local MAX_TEAMS = #Config.Teams
local teamCount = Config.DefaultTeamCount
local teamOwners: { [number]: Player | string | nil } = {}
local outTeams: { [number]: boolean } = {} -- 탈락한 팀
local restartRequested = false

-- 들어온 순서대로 팀을 맡고, 모자란 자리는 NPC (BothTeams 면 첫 사람이 다 맡음). 남는 사람은 구경.
local function assignTeams()
	local list = Players:GetPlayers()
	table.clear(teamOwners)
	for team = 1, MAX_TEAMS do
		local owner: Player | string | nil = nil
		if team <= teamCount then
			if list[team] then
				owner = list[team]
			elseif Config.SoloMode == "BothTeams" then
				owner = list[1]
			else
				owner = "Npc"
			end
		end
		teamOwners[team] = owner
		local ownerId = 0
		if owner == "Npc" then
			ownerId = NPC_OWNER_ID
		elseif typeof(owner) == "Instance" and owner:IsA("Player") then
			ownerId = owner.UserId
		end
		state:SetAttribute("Team" .. team .. "Owner", ownerId)
	end
end

-- 사람이 들어오면 맡을 자리 (NPC 나 한 사람이 여러 팀) 가 있는지
local function hasOpenSeat(): boolean
	local seen = {}
	for team = 1, teamCount do
		local owner = teamOwners[team]
		if owner == "Npc" or (owner and seen[owner]) then
			return true
		end
		if owner then
			seen[owner] = true
		end
	end
	return false
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	-- NPC 와 하던 중에 친구가 들어오면 새로 시작 (친구가 NPC 자리를 맡음)
	if hasOpenSeat() then
		restartRequested = true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for team = 1, teamCount do
		if teamOwners[team] == player then
			restartRequested = true
		end
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

-- 아직 안 진 상대 팀들의 알
local function enemyPiecesOf(team: number): { BasePart }
	local list = {}
	for _, piece in piecesFolder:GetChildren() do
		local pieceTeam = piece:GetAttribute("Team")
		if piece:IsA("BasePart") and pieceTeam ~= team and not outTeams[pieceTeam :: number] then
			table.insert(list, piece)
		end
	end
	return list
end

local function enemyKingsOf(team: number): { BasePart }
	local list = {}
	for _, piece in enemyPiecesOf(team) do
		if piece:GetAttribute("Kind") == "King" then
			table.insert(list, piece)
		end
	end
	return list
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
		Board = Board,
		BoardShape = BoardShape,
		GHOST_GROUP = GHOST_GROUP,
		teamCount = teamCount,
		-- 아직 안 진 상대 팀 번호들
		enemyTeams = function(): { number }
			local list = {}
			for other = 1, teamCount do
				if other ~= team and not outTeams[other] then
					table.insert(list, other)
				end
			end
			return list
		end,
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
	-- 왕알·거대화 알은 무거운 만큼 세게 (PieceFactory.flickScale)
	piece:ApplyImpulse(direction.Unit * power * Config.FlickPower * PieceFactory.flickScale(piece))
	Effects.sound("Flick", piece)
	-- 상대 왕알을 노리고 치면 허세, 아니면 보통 대사
	local aimingAtKing = false
	for _, enemyKing in enemyKingsOf(piece:GetAttribute("Team") :: number) do
		local toKing = (enemyKing.Position - piece.Position) * Vector3.new(1, 0, 1)
		if toKing.Magnitude > 0.1 and toKing.Unit:Dot(direction.Unit) >= math.cos(math.rad(Config.TauntAngle)) then
			aimingAtKing = true
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
	-- 능력 알은 1회 사용. Config.AbilityUses 는 정한 횟수만큼, Config.ReusableAbilities 는 계속.
	if not Config.ReusableAbilities[ability.Id] then
		local usesLeft = ((piece:GetAttribute("AbilityUsesLeft") :: number?) or Config.AbilityUses[ability.Id] or 1) - 1
		if usesLeft <= 0 then
			piece:SetAttribute("Ability", nil)
			piece:SetAttribute("AbilityUsesLeft", nil)
		else
			piece:SetAttribute("AbilityUsesLeft", usesLeft)
		end
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
		flickScale = PieceFactory.flickScale(piece),
	}
end

-- NPC 가 쓸 만한 능력 알 고르기
local function chooseNpcAbility(team: number): BasePart?
	-- 상대 왕알 가까이 있는 폭발 알은 무조건 터뜨린다
	for _, enemyKing in enemyKingsOf(team) do
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
			for _, enemy in enemyPiecesOf(team) do
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
	for _, piece in enemyPiecesOf(team) do
		if piece.CollisionGroup == GHOST_GROUP then
			continue
		end
		table.insert(if piece.Anchored then blockers else targets, toInfo(piece))
	end

	local shot = Npc.chooseShot(shooterInfos, targets, {
		distanceToEdge = function(x: number, z: number, dx: number, dz: number): number
			return BoardShape.distanceToEdge(Board.edges, x, z, dx, dz)
		end,
		gravity = workspace.Gravity,
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
	local capacity = TeamLayout.capacity(TeamLayout.pick(Config.Layouts, teamCount))
	if total < 1 or cost > Config.Budget or total > capacity then
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

-- 추천 팀이 자리에 다 들어가는지 (3·4팀은 한 팀 8개까지)
local function presetFits(index: number): boolean
	local capacity = TeamLayout.capacity(TeamLayout.pick(Config.Layouts, teamCount))
	return #Config.PresetTeams[index].Pieces <= capacity
end

Remotes.SelectTeam.OnServerEvent:Connect(function(player, choice)
	if state:GetAttribute("Phase") ~= "TeamSelect" then
		return
	end
	-- 이 플레이어가 맡은 팀 중 아직 안 고른 팀 (혼자 여러 팀이면 앞 번호 먼저)
	for team = 1, teamCount do
		if teamOwners[team] == player and not state:GetAttribute("Team" .. team .. "Ready") then
			local pieces
			if typeof(choice) == "number" and Config.PresetTeams[choice] then
				if not presetFits(choice) then
					return
				end
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

local function randomPreset(): number
	local fitting = {}
	for index in Config.PresetTeams do
		if presetFits(index) then
			table.insert(fitting, index)
		end
	end
	return fitting[random:NextInteger(1, #fitting)]
end

local function allChosen(): boolean
	for team = 1, teamCount do
		if not teamChoices[team] then
			return false
		end
	end
	return true
end

local function runTeamSelect()
	table.clear(teamChoices)
	for team = 1, MAX_TEAMS do
		state:SetAttribute("Team" .. team .. "Ready", false)
	end
	state:SetAttribute("SelectEndsAt", workspace:GetServerTimeNow() + Config.TeamSelectTime)
	state:SetAttribute("Phase", "TeamSelect")

	for team = 1, teamCount do
		if teamOwners[team] == "Npc" then
			task.delay(0.5 + team * 0.3, function()
				if state:GetAttribute("Phase") == "TeamSelect" and not teamChoices[team] then
					setChoice(team, copyPreset(randomPreset()))
				end
			end)
		end
	end

	local deadline = os.clock() + Config.TeamSelectTime
	while not allChosen() and os.clock() < deadline and not restartRequested do
		task.wait(0.1)
	end
	for team = 1, teamCount do
		if not teamChoices[team] then
			setChoice(team, copyPreset(1))
		end
	end
end

-- 모드 고르기 : 방장(먼저 들어온 사람)이 2·3·4팀 중 고른다
local chosenMode: number? = nil

Remotes.SelectMode.OnServerEvent:Connect(function(player, count)
	if state:GetAttribute("Phase") ~= "ModeSelect" or player.UserId ~= state:GetAttribute("HostUserId") then
		return
	end
	if typeof(count) == "number" and count == math.floor(count) and count >= 2 and count <= MAX_TEAMS then
		chosenMode = count
	end
end)

local function runModeSelect()
	local host = Players:GetPlayers()[1]
	chosenMode = nil
	state:SetAttribute("HostUserId", if host then host.UserId else 0)
	state:SetAttribute("SelectEndsAt", workspace:GetServerTimeNow() + Config.ModeSelectTime)
	state:SetAttribute("Phase", "ModeSelect")
	local deadline = os.clock() + Config.ModeSelectTime
	while not chosenMode and os.clock() < deadline and not restartRequested do
		task.wait(0.1)
	end
	teamCount = chosenMode or Config.DefaultTeamCount
	state:SetAttribute("TeamCount", teamCount)
end

---------------------------------------------------------------- 판 진행

local function setupPieces()
	clearAllEffects()
	piecesFolder:ClearAllChildren()
	for team = 1, teamCount do
		for _, piece in Placement.layoutTeam(team, teamCount, teamChoices[team] or copyPreset(1), piecesFolder) do
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
	-- 시간이 다 되면 모든 알을 그 자리에 멈춘다 (오래 기다리면 고장 난 것 같아서)
	for _, piece in piecesFolder:GetChildren() do
		if piece:IsA("BasePart") and not piece.Anchored then
			piece.AssemblyLinearVelocity = Vector3.zero
			piece.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- 진 팀 확인 : 왕알이 판 밖으로 나갔거나 HP 0 이면 진다 (왕알만 남아도 계속 싸운다)
local function loseReason(team: number): string?
	local king = kingOf(team)
	if not king then
		return "왕알이 판 밖으로!"
	end
	if (king:GetAttribute("Hp") or 0) <= 0 then
		return "왕알 격파!"
	end
	return nil
end

-- 팀 탈락 : 남은 알을 치우고 알린다
local function knockOut(team: number, reason: string)
	outTeams[team] = true
	state:SetAttribute("Team" .. team .. "Out", true)
	for _, piece in piecesOf(team) do
		Effects.sparkle(piece.Position, Config.Teams[team].Color, 15)
		piece:Destroy()
	end
	if teamCount > 2 then
		Effects.banner(Config.Teams[team].Name .. " 탈락! " .. reason, Config.Teams[team].Color)
	end
end

local function aliveTeams(): { number }
	local list = {}
	for team = 1, teamCount do
		if not outTeams[team] then
			table.insert(list, team)
		end
	end
	return list
end

local function cheer(winner: number)
	local king = kingOf(winner)
	if king then
		Speech.say(king, "Win", true)
	end
	for _, piece in piecesOf(winner) do
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

-- 먼저 칠 팀 : NPC 가 있으면 NPC 부터, 사람은 마지막 (Config.PlayerGoesLast). 사람끼리면 무작위.
-- 사람은 앞 번호 팀을 맡으므로, 사람 바로 다음 자리의 NPC 부터 시작하면 사람이 마지막이 된다.
local function pickFirstTeam(): number
	if Config.PlayerGoesLast then
		for team = 1, teamCount do
			local previous = (team - 2) % teamCount + 1
			if teamOwners[team] == "Npc" and teamOwners[previous] ~= "Npc" then
				return team
			end
		end
	end
	return random:NextInteger(1, teamCount)
end

local function playRound()
	runModeSelect()
	if restartRequested then
		return
	end
	assignTeams()
	-- 팀 수에 맞는 판 (3팀은 육각형)
	piecesFolder:ClearAllChildren()
	Board.build(teamCount)
	runTeamSelect()
	if restartRequested then
		return
	end
	table.clear(outTeams)
	for team = 1, MAX_TEAMS do
		-- 이번 판에 없는 팀은 처음부터 탈락 처리
		outTeams[team] = team > teamCount
		state:SetAttribute("Team" .. team .. "Out", team > teamCount)
	end
	setupPieces()
	-- 왕알들이 한마디씩
	for team = 1, teamCount do
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
	local firstTeam = pickFirstTeam()
	state:SetAttribute("CurrentTeam", firstTeam)
	Effects.banner(Config.Teams[firstTeam].Name .. " 먼저!", Config.Teams[firstTeam].Color)

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
		for _, checkTeam in aliveTeams() do
			local king = kingOf(checkTeam)
			if king and (king:GetAttribute("Hp") or 0) <= 0 then
				Effects.explosion(king.Position)
				Effects.sound("KingDown")
				king:Destroy()
			end
		end

		-- 진 팀 탈락
		local lastReason = ""
		for _, checkTeam in aliveTeams() do
			local reason = loseReason(checkTeam)
			if reason then
				lastReason = reason
				knockOut(checkTeam, reason)
			end
		end

		local alive = aliveTeams()
		if #alive <= 1 then
			local winner = alive[1] or -1
			state:SetAttribute("Winner", winner)
			state:SetAttribute("WinReason", if winner == -1 then "모두 쓰러졌어요" else lastReason)
			state:SetAttribute("Phase", "GameOver")
			Effects.melody(if winner == -1 then "Draw" else "Win")
			if winner ~= -1 then
				cheer(winner)
			end
			task.wait(Config.RestartDelay)
			return
		end

		state:SetAttribute("CurrentTeam", TeamLayout.nextTeam(team, teamCount, outTeams) or alive[1])
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
	while not restartRequested do
		playRound()
	end
end
