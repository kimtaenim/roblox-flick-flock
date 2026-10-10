-- 왕알 HP 계산
-- damage = 충돌 상대속도 × 때린 알의 질량 계수 × Config.DamageScale
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PieceFactory = require(script.Parent:WaitForChild("PieceFactory"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Damage = {}

local piecesFolder: Folder? = nil
-- 바로 전 프레임 속도 (부딪히기 직전 속도로 쓴다)
local lastVelocity: { [BasePart]: Vector3 } = {}
local lastHitTime: { [BasePart]: { [BasePart]: number } } = {}
-- 폭발 턴에는 부딪혀도 HP 1 아래로 안 내려간다 (폭발은 죽이지 않음)
local protectedMinHp = 0

function Damage.setProtected(protected: boolean)
	protectedMinHp = if protected then 1 else 0
end

function Damage.formula(relativeSpeed: number, massFactor: number): number
	if relativeSpeed < Config.DamageMinSpeed then
		return 0
	end
	return relativeSpeed * massFactor * Config.DamageScale
end

-- 왕알 HP 깎기. minHp 아래로는 안 내려간다 (폭발은 1)
function Damage.apply(king: BasePart, amount: number, minHp: number?)
	if amount <= 0 then
		return
	end
	local hp = king:GetAttribute("Hp") or 0
	local newHp = math.max(hp - amount, math.max(minHp or 0, protectedMinHp))
	if newHp < hp then
		king:SetAttribute("Hp", newHp)
		Effects.sparkle(king.Position, Color3.fromRGB(255, 80, 80), math.clamp(math.floor(amount), 5, 30))
	end
end

local lastSoundTime: { [BasePart]: number } = {}

local function onPieceTouched(piece: BasePart, other: BasePart)
	if not piecesFolder or other.Parent ~= piecesFolder or other == piece then
		return
	end
	local pieceVelocity = lastVelocity[piece] or piece.AssemblyLinearVelocity
	local otherVelocity = lastVelocity[other] or other.AssemblyLinearVelocity
	local relativeSpeed = (otherVelocity - pieceVelocity).Magnitude
	local now = os.clock()

	-- 부딪히는 소리 : 더 빨랐던 알 쪽에서 한 번만. 작은 알일수록 높은 소리.
	if
		relativeSpeed >= Config.HitSoundMinSpeed
		and pieceVelocity.Magnitude >= otherVelocity.Magnitude
		and now - (lastSoundTime[piece] or 0) > Config.HitSoundCooldown
	then
		lastSoundTime[piece] = now
		Effects.sound("Hit", piece, 1 / math.max(PieceFactory.radius(piece) / 2, 0.25))
	end

	-- 왕알이면 데미지
	if piece:GetAttribute("Kind") ~= "King" then
		return
	end
	local hits = lastHitTime[piece]
	if not hits then
		hits = {}
		lastHitTime[piece] = hits
	end
	if hits[other] and now - hits[other] < Config.DamageCooldown then
		return
	end
	local amount = Damage.formula(relativeSpeed, PieceFactory.massFactor(other))
	if amount > 0 then
		hits[other] = now
		Damage.apply(piece, amount)
		Effects.sound("KingHit", piece)
	end
end

-- 알이 생길 때 불러 준다 (부딪히는 소리 + 왕알 데미지)
function Damage.watchPiece(piece: BasePart)
	piece.Touched:Connect(function(other)
		onPieceTouched(piece, other)
	end)
end

function Damage.start(folder: Folder)
	piecesFolder = folder
	RunService.Heartbeat:Connect(function()
		table.clear(lastVelocity)
		for _, piece in folder:GetChildren() do
			if piece:IsA("BasePart") then
				lastVelocity[piece] = piece.AssemblyLinearVelocity
			end
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			lastHitTime[child] = nil
			lastSoundTime[child] = nil
		end
	end)
end

return Damage
