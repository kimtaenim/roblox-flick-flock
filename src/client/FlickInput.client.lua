-- 드래그 → 힘 환산, 조준선, 카메라
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local state = Remotes.State
local piecesFolder = workspace:WaitForChild("Pieces")

local AIM_MIN_LENGTH = 2
local AIM_MAX_LENGTH = 14
local WEAK_COLOR = Color3.fromRGB(90, 220, 90)
local STRONG_COLOR = Color3.fromRGB(240, 60, 60)

-- 지금 내가 조종하는 팀 (혼자 두 팀이면 차례인 팀)
local function myTeam(): number?
	local current = state:GetAttribute("CurrentTeam")
	if state:GetAttribute("Team" .. current .. "Owner") == player.UserId then
		return current
	end
	for team = 1, 2 do
		if state:GetAttribute("Team" .. team .. "Owner") == player.UserId then
			return team
		end
	end
	return nil
end

local function isMyTurn(): boolean
	return state:GetAttribute("Phase") == "Aiming" and myTeam() == state:GetAttribute("CurrentTeam")
end

local function canFlick(piece: Instance): boolean
	if not piece:IsA("BasePart") or piece.Anchored then
		return false
	end
	if piece:GetAttribute("Team") ~= state:GetAttribute("CurrentTeam") then
		return false
	end
	return Config.CanFlickKing or piece:GetAttribute("Kind") ~= "King"
end

-- 카메라 : 내 진영 뒤에서 판을 내려다본다. 폭발하면 흔들린다.
local shakeAmount = 0
Remotes.Effect.OnClientEvent:Connect(function(kind, value)
	if kind == "Shake" and typeof(value) == "number" then
		shakeAmount = math.max(shakeAmount, value)
	end
end)

local smoothCFrame: CFrame? = nil
RunService:BindToRenderStep("FlickCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local side = if (myTeam() or 1) == 1 then 1 else -1
	local eye = Vector3.new(0, Config.BoardHeight + Config.CameraHeight, side * Config.CameraBack)
	local focus = Vector3.new(0, Config.BoardHeight, side * 2)
	local target = CFrame.lookAt(eye, focus)
	smoothCFrame = if smoothCFrame then smoothCFrame:Lerp(target, math.clamp(dt * 5, 0, 1)) else target

	local shake = Vector3.zero
	if shakeAmount > 0.01 then
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shakeAmount * 2
		shakeAmount = math.max(shakeAmount - dt * 2, 0)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = (smoothCFrame :: CFrame) + shake
end)

-- 조준선 (내 화면에만 보임)
local aimArrow = Instance.new("Part")
aimArrow.Name = "AimArrow"
aimArrow.Anchored = true
aimArrow.CanCollide = false
aimArrow.CanQuery = false
aimArrow.CanTouch = false
aimArrow.Material = Enum.Material.Neon

type Drag = { piece: BasePart, input: InputObject }
local dragging: Drag? = nil
local shotDirection = Vector3.zero
local shotPower = 0

-- 화면 위치 → 알 높이의 수평면 위 한 점
local function screenToWorld(screenPosition: Vector3, planeY: number): Vector3?
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function hideAim()
	aimArrow.Parent = nil
end

local function updateAim(screenPosition: Vector3)
	local drag = dragging
	if not drag then
		return
	end
	local piece = drag.piece
	local center = piece.Position
	local point = screenToWorld(screenPosition, center.Y)
	if not point then
		return
	end

	local pull = Vector3.new(point.X - center.X, 0, point.Z - center.Z)
	local shot = if Config.PullBackToShoot then -pull else pull
	if shot.Magnitude < 0.01 then
		shotPower = 0
		hideAim()
		return
	end
	shotDirection = shot.Unit
	shotPower = math.clamp(shot.Magnitude / Config.MaxDragDistance, 0, 1)

	local length = AIM_MIN_LENGTH + (AIM_MAX_LENGTH - AIM_MIN_LENGTH) * shotPower
	local start = Vector3.new(center.X, Config.BoardHeight + 0.3, center.Z)
	aimArrow.Size = Vector3.new(0.6, 0.2, length)
	aimArrow.CFrame = CFrame.lookAt(start + shotDirection * (length / 2), start + shotDirection * length)
	aimArrow.Color = WEAK_COLOR:Lerp(STRONG_COLOR, shotPower)
	aimArrow.Parent = workspace
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or dragging or not isPress(input) or not isMyTurn() then
		return
	end
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { piecesFolder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result and canFlick(result.Instance) then
		dragging = { piece = result.Instance :: BasePart, input = input }
		shotPower = 0
	end
end)

UserInputService.InputChanged:Connect(function(input)
	local drag = dragging
	if not drag then
		return
	end
	local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
		and drag.input.UserInputType == Enum.UserInputType.MouseButton1
	if isMouseMove or input == drag.input then
		updateAim(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local drag = dragging
	if not drag then
		return
	end
	local isSameMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		and drag.input.UserInputType == Enum.UserInputType.MouseButton1
	if not (isSameMouse or input == drag.input) then
		return
	end

	dragging = nil
	hideAim()
	if isMyTurn() and drag.piece.Parent and shotPower >= Config.MinFlickPower then
		Remotes.Flick:FireServer(drag.piece, shotDirection, shotPower)
	end
end)

-- 차례가 끝나면 끌던 것 취소
state:GetAttributeChangedSignal("Phase"):Connect(function()
	if state:GetAttribute("Phase") ~= "Aiming" then
		dragging = nil
		hideAim()
	end
end)
