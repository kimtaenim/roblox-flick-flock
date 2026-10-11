-- 드래그 → 힘 환산, 조준선, 카메라
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TeamLayout = require(Shared:WaitForChild("TeamLayout"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local state = Remotes.State

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
	for team = 1, (state:GetAttribute("TeamCount") or 2) do
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

-- 카메라 : Studio 처럼 자유롭게 날아다니는 카메라.
-- 오른쪽 버튼 끌기 / 빈 곳 끌기 = 둘러보기, WASD·화살표 = 앞뒤옆, E·스페이스 = 위, Q·Ctrl = 아래,
-- Shift = 빠르게, 휠·두 손가락 = 앞뒤로, R = 처음 자리
local shakeAmount = 0
Remotes.Effect.OnClientEvent:Connect(function(kind, value)
	if kind == "Shake" and typeof(value) == "number" then
		shakeAmount = math.max(shakeAmount, value)
	end
end)

local cameraPosition = Vector3.new(0, 40, 40)
local cameraYaw = 0 -- 좌우로 돈 각도 (라디안). 0 = -Z 쪽을 봄
local cameraPitch = 0 -- 위아래 각도 (라디안). 음수 = 내려다봄
local smoothCFrame: CFrame? = nil
local lastSideTeam: number? = nil
local lastBoardKey = ""
local MAX_PITCH = math.rad(89)

local function lookCFrame(): CFrame
	return CFrame.new(cameraPosition) * CFrame.Angles(0, cameraYaw, 0) * CFrame.Angles(cameraPitch, 0, 0)
end

-- 내 진영 뒤에서 판을 내려다보는 처음 자리
local function resetCamera()
	local team = myTeam() or 1
	local x, z = TeamLayout.direction(team, state:GetAttribute("TeamCount") or 2)
	local back = Vector3.new(x, 0, z) -- 내 진영 쪽
	local focus = Vector3.new(0, Config.BoardHeight, 0) + back * 4
	local pitch = math.rad(Config.CameraPitch)
	-- 큰 판이면 더 멀리서, 작은 판이면 더 가까이서
	local boardSize = Config.BoardSizes[state:GetAttribute("BoardSizeKey") or "Normal"]
	local distance = Config.CameraDistance * (if boardSize then boardSize.Size / 64 else 1)
	local flat = distance * math.cos(pitch)
	cameraPosition = focus + Vector3.new(0, distance * math.sin(pitch), 0) + back * flat
	local look = (focus - cameraPosition).Unit
	cameraYaw = math.atan2(-look.X, -look.Z)
	cameraPitch = math.asin(look.Y)
end

local function clampCamera()
	cameraPitch = math.clamp(cameraPitch, -MAX_PITCH, MAX_PITCH)
	local limit = Config.CameraLimit
	cameraPosition = Vector3.new(
		math.clamp(cameraPosition.X, -limit, limit),
		math.clamp(cameraPosition.Y, Config.BoardHeight + 1, limit),
		math.clamp(cameraPosition.Z, -limit, limit)
	)
end

-- 둘러보기 (화면에서 끈 만큼)
local function rotateCamera(deltaX: number, deltaY: number)
	cameraYaw -= math.rad(deltaX * Config.CameraLookSpeed)
	cameraPitch -= math.rad(deltaY * Config.CameraLookSpeed)
	clampCamera()
end

-- 보는 방향으로 앞뒤 이동
local function moveForward(distance: number)
	cameraPosition += lookCFrame().LookVector * distance
	clampCamera()
end

local MOVE_KEYS = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.Up] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.Down] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.Left] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.Right] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.E] = Vector3.new(0, 1, 0),
	[Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
	[Enum.KeyCode.Q] = Vector3.new(0, -1, 0),
	[Enum.KeyCode.LeftControl] = Vector3.new(0, -1, 0),
}

RunService:BindToRenderStep("FlickCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	-- 처음, 그리고 내 팀이 바뀌면 (혼자 두 팀일 때 차례가 바뀌면) 그 팀 뒤로
	local team = myTeam() or 1
	local boardKey = tostring(state:GetAttribute("BoardSizeKey")) .. tostring(state:GetAttribute("TeamCount"))
	if team ~= lastSideTeam or boardKey ~= lastBoardKey then
		lastSideTeam = team
		lastBoardKey = boardKey
		resetCamera()
	end

	-- 키보드 이동 : 앞뒤옆은 보는 방향 기준, 위아래는 하늘 기준
	if not UserInputService:GetFocusedTextBox() then
		local move = Vector3.zero
		for key, direction in MOVE_KEYS do
			if UserInputService:IsKeyDown(key) then
				move += direction
			end
		end
		if move.Magnitude > 0 then
			local view = lookCFrame()
			local speed = Config.CameraMoveSpeed
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
				speed *= Config.CameraFastMultiplier
			end
			local worldMove = view.RightVector * move.X + Vector3.yAxis * move.Y - view.LookVector * move.Z
			cameraPosition += worldMove.Unit * speed * dt
			clampCamera()
		end
	end

	local target = lookCFrame()
	smoothCFrame = if smoothCFrame then smoothCFrame:Lerp(target, math.clamp(dt * 15, 0, 1)) else target

	local shake = Vector3.zero
	if shakeAmount > 0.01 then
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shakeAmount * 2
		shakeAmount = math.max(shakeAmount - dt * 2, 0)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = (smoothCFrame :: CFrame) + shake
end)

-- 휠 : 보는 방향으로 앞뒤
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		moveForward(if input.Position.Z > 0 then Config.CameraWheelStep else -Config.CameraWheelStep)
	end
end)

-- 두 손가락 벌리기 = 앞으로, 오므리기 = 뒤로
local lastPinchScale = 1
UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, inputState, gameProcessed)
	if gameProcessed then
		return
	end
	if inputState == Enum.UserInputState.Begin then
		lastPinchScale = 1
	end
	if scale > 0 then
		moveForward((scale - lastPinchScale) * Config.CameraWheelStep * 6)
		lastPinchScale = scale
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.R then
		resetCamera()
	end
end)

-- 둘러보기 끌기 (빈 곳을 왼쪽 버튼·손가락으로, 또는 아무 데나 오른쪽 버튼으로)
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

-- 조준 중 안내 : 취소하는 방법
local aimGui = Instance.new("ScreenGui")
aimGui.Name = "AimHint"
aimGui.ResetOnSpawn = false
local aimHint = Instance.new("TextLabel")
aimHint.AnchorPoint = Vector2.new(0.5, 1)
aimHint.Position = UDim2.new(0.5, 0, 1, -130)
aimHint.Size = UDim2.new(0.9, 0, 0, 30)
aimHint.BackgroundTransparency = 1
aimHint.Font = Enum.Font.GothamBold
aimHint.TextSize = 22
aimHint.TextColor3 = Color3.new(1, 1, 1)
aimHint.TextStrokeTransparency = 0.3
aimHint.Visible = false
aimHint.Parent = aimGui
aimGui.Parent = player:WaitForChild("PlayerGui")

local CANCEL_TEXT = "✖ 알 위로 돌아와서 놓거나, 오른쪽 클릭·Esc 를 누르면 취소"
local WILL_CANCEL_TEXT = "지금 놓으면 취소돼요 (다른 알을 골라도 돼요)"

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
	aimHint.Visible = false
end

-- 조준 그만두기 (차례는 그대로, 다시 골라서 칠 수 있다)
local function cancelAim()
	dragging = nil
	shotPower = 0
	hideAim()
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
	aimHint.Visible = true
	-- 알 가까이로 돌아오면 놓아도 안 쏜다
	if shot.Magnitude < Config.CancelDragDistance then
		shotPower = 0
		aimArrow.Parent = nil
		aimHint.Text = WILL_CANCEL_TEXT
		return
	end
	aimHint.Text = CANCEL_TEXT
	shotDirection = shot.Unit
	shotPower = math.clamp(shot.Magnitude / Config.MaxDragDistance, 0, 1)

	local length = AIM_MIN_LENGTH + (AIM_MAX_LENGTH - AIM_MIN_LENGTH) * shotPower
	-- 울퉁불퉁 판은 요철에 묻히지 않게 요철 꼭대기보다 위에 그린다
	local floor = Config.Floors[state:GetAttribute("FloorKey") or Config.DefaultFloor]
	local ripples = floor and floor.Ripples
	local arrowY = Config.BoardHeight + 0.3 + (if ripples then ripples.MaxHeight + 0.15 else 0)
	local start = Vector3.new(center.X, arrowY, center.Z)
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
	local piecesFolder = workspace:FindFirstChild("Pieces")
	if not piecesFolder then
		return
	end
	params.FilterDescendantsInstances = { piecesFolder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result and canFlick(result.Instance) then
		dragging = { piece = result.Instance :: BasePart, input = input }
		shotPower = 0
		aimHint.Text = CANCEL_TEXT
		aimHint.Visible = true
	end
end)

-- 조준 중에 오른쪽 클릭·Esc = 취소
UserInputService.InputBegan:Connect(function(input)
	if not dragging then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
		cancelAim()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or cameraDragInput then
		return
	end
	local isRight = input.UserInputType == Enum.UserInputType.MouseButton2
	-- 왼쪽·터치는 알을 안 잡았을 때만 (위 InputBegan 이 먼저 dragging 을 정한다)
	-- (조준 중 오른쪽 클릭은 취소라서 화면을 안 돌린다)
	if (isRight and not dragging) or (isPress(input) and not dragging) then
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

	local power = shotPower
	cancelAim()
	if isMyTurn() and drag.piece.Parent and power >= Config.MinFlickPower then
		Remotes.Flick:FireServer(drag.piece, shotDirection, power)
	end
end)

-- 차례가 끝나면 끌던 것 취소
state:GetAttributeChangedSignal("Phase"):Connect(function()
	if state:GetAttribute("Phase") ~= "Aiming" then
		cancelAim()
	end
end)
