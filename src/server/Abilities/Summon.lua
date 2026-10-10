-- 소환 : 하늘에서 거창한 것이 나타나 상대 진영을 공격한다. (결제와 절대 연결 안 함)
-- 드래곤·운석·블리자드·고래·비둘기(꽝). 상대 알을 직접 움직이지 않고,
-- 진짜 물체(불덩이·얼음·운석·고래)를 떨어뜨려 부딪히게 한다.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Ability = {}

local SKY_HEIGHT = 45 -- 소환물이 나타나는 높이 (판 위)

-- 확률표에서 하나 뽑기 (rng:NextNumber 사용)
function Ability.roll(rng): { Name: string, Icon: string, Chance: number, Result: string }
	local total = 0
	for _, entry in Config.SummonTable do
		total += entry.Chance
	end
	local pick = rng:NextNumber(0, total)
	for _, entry in Config.SummonTable do
		pick -= entry.Chance
		if pick <= 0 then
			return entry
		end
	end
	return Config.SummonTable[#Config.SummonTable]
end

---------------------------------------------------------------- 도우미

local function enemyPieces(context): { BasePart }
	local list = {}
	for _, piece in context.piecesFolder:GetChildren() do
		if piece:IsA("BasePart") and piece:GetAttribute("Team") ~= context.team then
			table.insert(list, piece)
		end
	end
	return list
end

local function enemyKing(context): BasePart?
	for _, piece in enemyPieces(context) do
		if piece:GetAttribute("Kind") == "King" then
			return piece
		end
	end
	return nil
end

-- 상대 진영 가운데쯤
local function enemyCenter(context): Vector3
	local side = context.Placement.side(3 - context.team)
	return Vector3.new(0, Config.BoardHeight, side * Config.RowDistances[2])
end

-- 하늘에 떠서 움직이는 큰 그림 (이모지)
local function makeFlyer(icon: string, size: number, position: Vector3, context): Part
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size, size) -- 스터드 단위
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = icon
	label.Parent = gui
	gui.Parent = anchor
	anchor.Parent = context.Effects.folder()
	return anchor
end

local function flyTo(part: BasePart, target: Vector3, seconds: number)
	local tween = TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Position = target })
	tween:Play()
	return tween
end

-- 하늘에서 목표 지점으로 정확히 떨어지는 물체 (포물선 계산)
-- kind : Config.Summons 의 이름. look : 모양을 꾸미는 함수
local function launch(context, kind: string, start: Vector3, target: Vector3, seconds: number, look: (Part) -> ()): Part
	local info = Config.Summons[kind]
	local part = Instance.new("Part")
	part.Name = kind
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * info.Size
	part.Position = start
	part.Material = Enum.Material.SmoothPlastic
	part.CollisionGroup = context.PieceFactory.COLLISION_GROUP
	local volume = 4 / 3 * math.pi * (info.Size / 2) ^ 3
	local density = math.clamp(info.Mass * Config.MassUnit / volume, 0.01, 100)
	part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.3, 0.3, 1, 1)
	look(part)

	-- 중력을 생각해서 seconds 초 뒤에 target 에 닿는 속도
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	part.AssemblyLinearVelocity = (target - start - gravity * 0.5 * seconds * seconds) / seconds
	part.Parent = context.Effects.folder()
	part:SetNetworkOwner(nil)

	-- 상대 왕알에 맞으면 데미지 (한 번만). 처음 땅·알에 닿으면 쿵.
	local hitKing = false
	local landed = false
	part.Touched:Connect(function(other)
		if not landed then
			landed = true
			context.Effects.sound("Thud", part)
		end
		if
			not hitKing
			and other.Parent == context.piecesFolder
			and other:GetAttribute("Kind") == "King"
			and other:GetAttribute("Team") ~= context.team
		then
			hitKing = true
			context.Damage.apply(other, info.KingDamage)
			context.Effects.sound("KingHit", other)
			context.Speech.say(other, "Hit", true)
		end
	end)
	Debris:AddItem(part, Config.SummonLifetime)
	return part
end

---------------------------------------------------------------- 소환들

-- 🐉 드래곤 : 상대 진영 위를 가로질러 날며 불덩이를 퍼붓는다
local function dragon(context)
	local side = context.Placement.side(3 - context.team)
	local half = Config.BoardSize / 2
	local y = Config.BoardHeight + SKY_HEIGHT
	local from = Vector3.new(-half - 20, y, side * 12)
	local to = Vector3.new(half + 20, y, side * 12)
	local flyer = makeFlyer("🐉", 22, from, context)
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 15
	fire.Parent = flyer
	context.Effects.sound("Roar", flyer)
	local flightTime = 3.5
	flyTo(flyer, to, flightTime)

	local count = Config.Summons.Fireball.Count
	for index = 1, count do
		task.wait(flightTime / (count + 1))
		-- 앞의 절반은 왕알, 나머지는 아무 상대 알
		local targets = enemyPieces(context)
		local king = enemyKing(context)
		local target: Vector3
		if king and index <= math.ceil(count / 2) then
			target = king.Position
		elseif #targets > 0 then
			target = targets[context.random:NextInteger(1, #targets)].Position
		else
			target = enemyCenter(context)
		end
		launch(context, "Fireball", flyer.Position, target, 0.9, function(part)
			part.Color = Color3.fromRGB(255, 120, 20)
			part.Material = Enum.Material.Neon
			local flame = Instance.new("Fire")
			flame.Size = 6
			flame.Parent = part
		end)
		context.Effects.sound("Roar", flyer)
	end
	task.wait(1.2)
	flyer:Destroy()
end

-- ☄️ 운석 : 멀리 하늘에서 거대한 운석이 상대 왕알로
local function meteor(context)
	local king = enemyKing(context)
	local target = if king then king.Position else enemyCenter(context)
	local side = context.Placement.side(3 - context.team)
	local start = target + Vector3.new(40, SKY_HEIGHT + 60, side * 40)
	local rock = launch(context, "Meteor", start, target, 1.6, function(part)
		part.Color = Color3.fromRGB(90, 60, 50)
		part.Material = Enum.Material.Slate
		local flame = Instance.new("Fire")
		flame.Size = 20
		flame.Heat = 20
		flame.Parent = part
		local smoke = Instance.new("Smoke")
		smoke.Size = 10
		smoke.Parent = part
	end)
	context.Effects.sound("Wind", rock)
	task.wait(1.6)
	if rock.Parent then
		context.Effects.explosion(rock.Position)
	end
	context.Effects.sound("Boom")
	task.wait(1)
end

-- ❄️ 블리자드 : 상대 진영에 먹구름, 얼음덩이가 우수수
local function blizzard(context)
	local center = enemyCenter(context)
	local cloud = Instance.new("Part")
	cloud.Name = "BlizzardCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Size = Vector3.new(Config.BoardSize, 8, Config.BoardSize / 2)
	cloud.Position = center + Vector3.new(0, SKY_HEIGHT, 0)
	cloud.Color = Color3.fromRGB(120, 130, 150)
	cloud.Transparency = 0.25
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = cloud
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.6)
	snow.Lifetime = NumberRange.new(2, 3)
	snow.Speed = NumberRange.new(15, 25)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(30, 30)
	snow.Rate = 200
	snow.Parent = cloud
	cloud.Parent = context.Effects.folder()
	local icon = makeFlyer("❄️", 14, cloud.Position + Vector3.new(0, 8, 0), context)
	context.Effects.sound("Wind", cloud)

	local half = Config.BoardSize / 2 - 2
	local side = context.Placement.side(3 - context.team)
	local count = Config.Summons.Ice.Count
	for index = 1, count do
		task.wait(0.25)
		local king = enemyKing(context)
		local target: Vector3
		if king and index % 3 == 0 then
			target = king.Position
		else
			-- 상대 진영 아무 데나
			target = Vector3.new(context.random:NextNumber(-half, half), Config.BoardHeight, side * context.random:NextNumber(2, half))
		end
		local start = Vector3.new(target.X, cloud.Position.Y - 4, target.Z)
		launch(context, "Ice", start, target, 0.8, function(part)
			part.Shape = Enum.PartType.Block
			part.Color = Color3.fromRGB(170, 220, 255)
			part.Material = Enum.Material.Glass
			part.Transparency = 0.2
			part.CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		end)
	end
	task.wait(1.2)
	snow.Enabled = false
	Debris:AddItem(cloud, 2)
	Debris:AddItem(icon, 0.5)
end

-- 🐋 고래 : 상대 진영에 고래가 철퍼덕
local function whale(context)
	local king = enemyKing(context)
	local center = enemyCenter(context)
	-- 왕알과 진영 가운데 사이
	local target = if king then center:Lerp(king.Position, 0.6) else center
	local start = target + Vector3.new(0, SKY_HEIGHT + 20, 0)
	local body = launch(context, "Whale", start, target + Vector3.new(0, 4, 0), 1.3, function(part)
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(Config.Summons.Whale.Size, Config.Summons.Whale.Size * 0.45, Config.Summons.Whale.Size * 0.55)
		part.Color = Color3.fromRGB(70, 110, 200)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end)
	local icon = makeFlyer("🐋", 12, start + Vector3.new(0, 10, 0), context)
	flyTo(icon, target + Vector3.new(0, 14, 0), 1.3)
	task.wait(1.3)
	context.Effects.sound("Splash", body)
	context.Effects.sparkle(target + Vector3.new(0, 2, 0), Color3.fromRGB(120, 190, 255), 60)
	context.Remotes.Effect:FireAllClients("Shake", Config.ShakeStrength)
	task.wait(1)
	Debris:AddItem(icon, 0.5)
end

-- 🐦 꽝 : 비둘기가 날아와서 똥만 싸고 간다
local function pigeon(context)
	local side = context.Placement.side(3 - context.team)
	local half = Config.BoardSize / 2
	local y = Config.BoardHeight + 25
	local flyer = makeFlyer("🐦", 6, Vector3.new(-half - 10, y, side * 10), context)
	context.Effects.sound("Cute", flyer)
	flyTo(flyer, Vector3.new(half + 10, y, side * 10), 3)
	task.wait(1.4)
	local targets = enemyPieces(context)
	local target = if #targets > 0 then targets[context.random:NextInteger(1, #targets)].Position else enemyCenter(context)
	launch(context, "PigeonPoop", flyer.Position, target, 0.7, function(part)
		part.Color = Color3.fromRGB(120, 72, 30)
	end)
	context.Effects.sound("Poop", flyer)
	task.wait(1.8)
	flyer:Destroy()
end

local SUMMONS = {
	Dragon = dragon,
	Meteor = meteor,
	Blizzard = blizzard,
	Whale = whale,
	Pigeon = pigeon,
}

function Ability.Execute(_piece: BasePart, context)
	local entry = Ability.roll(context.random)
	local run = SUMMONS[entry.Result]
	if not run then
		return
	end

	if entry.Result == "Pigeon" then
		context.Effects.banner("꽝! 🐦 비둘기가 똥만 싸고 갔어요 💩", Color3.fromRGB(200, 200, 200))
	else
		context.Effects.banner(entry.Icon .. " " .. entry.Name .. " 소환!!", Color3.fromRGB(255, 215, 0))
		if entry.Result == "Dragon" then
			context.Effects.melody("Jackpot")
		end
	end

	-- 연출이 끝날 때까지 턴을 잡아 둔다
	local release = context.hold()
	task.spawn(function()
		local ok, problem = pcall(run, context)
		if not ok then
			warn("소환 오류: " .. tostring(problem))
		end
		release()
	end)
end

function Ability.OnTurnEnd(_piece: BasePart) end

return Ability
