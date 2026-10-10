-- 소리·연출 (서버에서 부르면 모두에게 보인다)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "Effects"
effectsFolder.Parent = workspace

-- 소리 : where 는 소리가 날 파트 (없으면 판 가운데). pitchScale 은 음 높이 배율.
function Effects.sound(name: string, where: BasePart?, pitchScale: number?)
	local info = Config.Sounds[name]
	if not info then
		return
	end
	local holder = where or workspace:FindFirstChild("Board")
	if not holder then
		return
	end
	local low, high = info.Pitch[1], info.Pitch[2]
	local sound = Instance.new("Sound")
	sound.SoundId = info.Id
	sound.Volume = Config.SoundVolume * (info.Volume or 1)
	sound.PlaybackSpeed = (low + (high - low) * math.random()) * (pitchScale or 1)
	sound.RollOffMaxDistance = 400
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- 멜로디 : Config.Melodies 의 음들을 차례로
function Effects.melody(name: string, where: BasePart?)
	local melody = Config.Melodies[name]
	if not melody then
		return
	end
	local base = Config.Sounds[melody.Sound]
	if not base then
		return
	end
	task.spawn(function()
		local middle = (base.Pitch[1] + base.Pitch[2]) / 2
		for _, pitch in melody.Pitches do
			Effects.sound(melody.Sound, where, pitch / middle)
			task.wait(melody.Gap)
		end
	end)
end

-- 반짝이 터뜨리기
function Effects.sparkle(position: Vector3, color: Color3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = effectsFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(amount)
	Debris:AddItem(anchor, 2)
end

-- 폭발 모습 (알은 안 밀고 보이기만)
function Effects.explosion(position: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = Config.ExplosionRadius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = effectsFolder
	Remotes.Effect:FireAllClients("Shake", Config.ShakeStrength)
end

-- 화면 가운데 큰 글씨
function Effects.banner(text: string, color: Color3)
	Remotes.Effect:FireAllClients("Banner", text, color)
end

function Effects.folder(): Folder
	return effectsFolder
end

return Effects
