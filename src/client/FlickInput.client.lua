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

-- 카메라 : 판 가운데를 중심으로 빙 돌아가는 카메라.
-- 빈 곳 끌기 / 오른쪽 버튼 끌기 / Q·E = 돌리기, 휠·두 손가락 = 확대, WASD·화살표 = 이동, R = 처음 자리
local shakeAmount = 0
Remotes.Effect.OnClientEvent:Connect(function(kind, value)
	if kind == "Shake" and typeof(value) == "number" then
		shakeAmount = math.max(shakeAmount, value)
	end
end)

local cameraYaw = 0 -- 옆으로 돈 각도 (라디안)
local cameraPitch = math.rad(Config.CameraPitch)
local cameraDistance = Config.CameraDistance
local cameraFocus = Vector3.new(0, Config.BoardHeight, 0)
local smoothCFrame: CFrame? = nil
local lastSideTeam: number? = nil

-- 내 진영 뒤에서 보는 처음 자리
local function resetCamera()
	local team = myTeam() or 1
	cameraYaw = if team == 1 then 0 else math.pi
	cameraPitch = math.rad(Config.CameraPitch)
	cameraDistance = Config.CameraDistance
	local side = if team == 1 then 1 else -1
	cameraFocus = Vector3.new(0, Config.BoardHeight, side * 4)
end

local function clampCamera()
	cameraPitch = math.clamp(cameraPitch, math.rad(Config.CameraMinPitch), math.rad(Config.CameraMaxPitch))
	cameraDistance = math.clamp(cameraDistance, Config.CameraMinDistance, Config.CameraMaxDistance)
	local half = Config.BoardSize / 2
	cameraFocus = Vector3.new(math.clamp(cameraFocus.X, -half, half), Config.BoardHeight, math.clamp(cameraFocus.Z, -half, half))
end

local function rotateCamera(deltaX: number, deltaY: number)
	cameraYaw -= math.rad(deltaX * Config.CameraRotateSpeed)
	cameraPitch += math.rad(deltaY * Config.CameraRotateSpeed)
	clampCamera()
end

local function zoomCamera(factor: number)
	cameraDistance *= factor
	clampCamera()
end

local MOVE_KEYS = {
	[Enum.KeyCode.W] = Vector2.new(0, -1),
	[Enum.KeyCode.Up] = Vector2.new(0, -1),
	[Enum.KeyCode.S] = Vector2.new(0, 1),
	[Enum.KeyCode.Down] = Vector2.new(0, 1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}

RunService:BindToRenderStep("FlickCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	-- 내 팀이 바뀌면 (혼자 두 팀일 때 차례가 바뀌면) 그 팀 뒤로
	local team = myTeam() or 1
	if team ~= lastSideTeam then
		lastSideTeam = team
		resetCamera()
	end

	-- 키보드 : 이동·돌리기
	if not UserInputService:GetFocusedTextBox() then
		local move = Vector2.zero
		for key, direction in MOVE_KEYS do
			if UserInputService:IsKeyDown(key) then
				move += direction
			end
		end
		if move.Magnitude > 0 then
			-- 화면 기준 앞·옆
			local forward = Vector3.new(-math.sin(cameraYaw), 0, -math.cos(cameraYaw))
			local right = Vector3.new(math.cos(cameraYaw), 0, -math.sin(cameraYaw))
			cameraFocus += (right * move.X - forward * move.Y) * Config.CameraMoveSpeed * dt
			clampCamera()
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			rotateCamera(-120 * dt, 0)
		elseif UserInputService:IsKeyDown(Enum.KeyCode.E) then
			rotateCamera(120 * dt, 0)
		end
	end

	local flat = cameraDistance * math.cos(cameraPitch)
	local eye = cameraFocus + Vector3.new(math.sin(cameraYaw) * flat, cameraDistance * math.sin(cameraPitch), math.cos(cameraYaw) * flat)
	local target = CFrame.lookAt(eye, cameraFocus)
	smoothCFrame = if smoothCFrame then smoothCFrame:Lerp(target, math.clamp(dt * 10, 0, 1)) else target

	local shake = Vector3.zero
	if shakeAmount > 0.01 then
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shakeAmount * 2
		shakeAmount = math.max(shakeAmount - dt * 2, 0)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = (smoothCFrame :: CFrame) + shake
end)

-- 휠 확대
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		zoomCamera(if input.Position.Z > 0 then Config.CameraZoomStep else 1 / Config.CameraZoomStep)
	end
end)

-- 두 손가락 벌리기·오므리기 확대
local lastPinchScale = 1
UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, inputState, gameProcessed)
	if gameProcessed then
		return
	end
	if inputState == Enum.UserInputState.Begin then
		lastPinchScale = 1
	end
	if scale > 0 then
		zoomCamera(lastPinchScale / scale)
		lastPinchScale = scale
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.R then
		resetCamera()
	end
end)

-- 화면 돌리기 끌기 (빈 곳을 왼쪽 버튼·손가락으로, 또는 아무 데나 오른쪽 버튼으로)
local cameraDragInput: InputObject? = nil
local lastDragPosition = Vector3.zero

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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or cameraDragInput then
		return
	end
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2
	-- 왼쪽·터치는 알을 안 잡았을 때만 (위 InputBegan 이 먼저 dragging 을 정한다)
	if isRight or (isPress(input) and not dragging) then
		task.defer(function()
			if isRight or not dragging then
				cameraDragInput = input
				lastDragPosition = input.Position
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	local dragInput = cameraDragInput
	if not dragInput then
		return
	end
	local isMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
		or dragInput.UserInputType == Enum.UserInputType.MouseButton2
	if (isMouse and input.UserInputType == Enum.UserInputType.MouseMovement) or input == dragInput then
		local delta = input.Position - lastDragPosition
		lastDragPosition = input.Position
		rotateCamera(delta.X, delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local dragInput = cameraDragInput
	if dragInput and (input == dragInput or input.UserInputType == dragInput.UserInputType) then
		cameraDragInput = nil
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
