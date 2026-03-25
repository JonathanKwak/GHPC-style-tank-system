local commanderSystem = script.Parent
local vehicle = commanderSystem.Parent

local commanderSeat = commanderSystem:WaitForChild("Seat")

local myPlayer = game.Players.LocalPlayer
local playerCamera = workspace.CurrentCamera

local base, turret = commanderSystem:WaitForChild("Base"), commanderSystem:WaitForChild("Turret")

local baseHinge = require(vehicle.TurretController).new(commanderSystem.BaseHinge, {
	["YawLeft"] = 180;
	["YawRight"] = 180;
	["ElevationAngle"] = 0;
	["DepressionAngle"] = 0;
})

local turretHinge = require(vehicle.TurretController).new(commanderSystem.TurretHinge, {
	["YawLeft"] = 0;
	["YawRight"] = 0;
	["ElevationAngle"] = 89;
	["DepressionAngle"] = 45;
})

local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

local rangefinderParams = RaycastParams.new()
rangefinderParams.FilterDescendantsInstances = {vehicle}

local interpolationTween = TweenInfo.new(0.10, Enum.EasingStyle.Linear)

local zoomed = false
local isNightVision = false
local isInCommanderView = false

local ui = script.CommanderView

local function isMyPlayerSeated()
	local occupant: Humanoid = commanderSeat.Occupant

	return occupant and game.Players:GetPlayerFromCharacter(occupant.Parent) == myPlayer
end

local function occupantChanged()
	setZoom(false)

	if isMyPlayerSeated() then
		-- add effects


	else
		-- remove effects
		exitCommanderView()
	end
end

function setZoom(newState)
	zoomed = (newState ~= nil and newState) or (newState == nil and not zoomed)

	if isInCommanderView then
		if zoomed then
			playerCamera.FieldOfView = 10
		else
			playerCamera.FieldOfView = 30
		end
	end
	
	ui.Viewer.Crosshair1.Visible = not zoomed
	ui.Viewer.Crosshair2.Visible = zoomed
end

function setNightVision(newState)
	isNightVision = (newState ~= nil and newState) or (newState == nil and not isNightVision)

	if isNightVision then
		local grainEffect = script.Grain:Clone()
		grainEffect.Parent = myPlayer:WaitForChild("PlayerGui")

		local colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Parent = playerCamera
		colorCorrection.TintColor = Color3.fromRGB(0, 255, 0)
		colorCorrection.Saturation = -1
		colorCorrection.Brightness = 0.25
		colorCorrection.Contrast = -0.1

		local blurEffect = Instance.new("BlurEffect")
		blurEffect.Parent = playerCamera
		blurEffect.Size = 8
	else
		local grainEffect = myPlayer:WaitForChild("PlayerGui"):FindFirstChild("Grain")
		local colorCorrection = playerCamera:FindFirstChild("ColorCorrection")
		local blurEffect = playerCamera:FindFirstChild("Blur")

		if colorCorrection then
			colorCorrection:Destroy()
		end

		if blurEffect then
			blurEffect:Destroy()
		end

		if grainEffect then
			grainEffect:Destroy()
		end
	end

	commanderSystem.Turret.TurretAttachment.IRSpotlight.Enabled = isNightVision

	commanderSeat.NightVisionToggle:Play()
end

function enterCommanderView()
	isInCommanderView = true

	playerCamera.CameraType = Enum.CameraType.Scriptable
	playerCamera.FieldOfView = 30

	userInputService.MouseIconEnabled = false
	userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	ui.Parent = myPlayer.PlayerGui

	ui.Cover.BackgroundTransparency = 0
	tweenService:Create(ui.Cover, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
end

function exitCommanderView()
	setZoom(false)
	setNightVision(false)
	
	isInCommanderView = false

	playerCamera.CameraType = Enum.CameraType.Custom
	playerCamera.FieldOfView = 70

	userInputService.MouseIconEnabled = true

	ui.Parent = script
end

local function renderStep(dt)
	if not isMyPlayerSeated() then
		return
	end
	
	if isInCommanderView then
		local rightVector = playerCamera.CFrame.RightVector
		local upVector = playerCamera.CFrame.UpVector
		local lookVector = playerCamera.CFrame.LookVector * 400
		
		local basePos = base.TurretAttachment.WorldPosition + lookVector
		local turretBasePos = turret.TurretAttachment.WorldPosition + lookVector
		
		userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local mouseDifference = userInputService:GetMouseDelta() * 60

		baseHinge:LookAt(basePos + (rightVector * mouseDifference.X * dt), 1)
		turretHinge:LookAt(turretBasePos + (upVector * -mouseDifference.Y * dt), 1)
	end

	if isInCommanderView then
		playerCamera.CFrame = turret.TurretAttachment.WorldCFrame
		
		local finalDistance = "----"
		local ray = workspace:Raycast(turret.TurretAttachment.WorldPosition, turret.TurretAttachment.WorldCFrame.LookVector * 9999, rangefinderParams)
		if ray then
			finalDistance = ray.Distance
		end

		ui.Distance:SetAttribute("Text", finalDistance)
	end
end

local function inputBegan(input: InputObject, gameProcessed)
	if gameProcessed then
		return
	end

	if not isMyPlayerSeated() then
		return
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton2 and isInCommanderView then
		-- toggle zoom

		commanderSeat.ZoomToggle:Play()

		setZoom()
	end

	if input.KeyCode == Enum.KeyCode.V then
		setNightVision()
	end

	if input.KeyCode == Enum.KeyCode.X then
		if not isInCommanderView then
			enterCommanderView()
		else
			exitCommanderView()
		end
	end
end

local function inputEnded(input: InputObject, gameProcessed)
	if gameProcessed then
		return
	end

	if not isMyPlayerSeated() then
		return
	end
	
end

local function applyTween(object, ti, properties)
	local tween = tweenService:Create(object, ti, properties)
	tween:Play()

	return tween
end

commanderSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged)

runService.RenderStepped:Connect(renderStep)

userInputService.InputBegan:Connect(inputBegan)
userInputService.InputEnded:Connect(inputEnded)

commanderSystem:WaitForChild("EnterView").Event:Connect(enterCommanderView)
commanderSystem:WaitForChild("ExitView").Event:Connect(exitCommanderView)
