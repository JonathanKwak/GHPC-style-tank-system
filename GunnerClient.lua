local myPlayer = game.Players.LocalPlayer
local mouse = myPlayer:GetMouse()

local playerCamera = workspace.CurrentCamera

local gunnerSystem = script.Parent
local vehicle = gunnerSystem.Parent

local turretSeat = gunnerSystem:WaitForChild("Seat")
local turret, gun, camera = gunnerSystem:WaitForChild("Turret"), gunnerSystem:WaitForChild("Gun"), gunnerSystem:WaitForChild("Camera")

local turretHinge = require(vehicle.TurretController).new(gunnerSystem.TurretHinge, {
	["YawLeft"] = 180;
	["YawRight"] = 180;
	["ElevationAngle"] = 0;
	["DepressionAngle"] = 0;
})

local gunHinge = require(vehicle.TurretController).new(gunnerSystem.GunHinge, {
	["YawLeft"] = 0;
	["YawRight"] = 0;
	["ElevationAngle"] = 40;
	["DepressionAngle"] = 15;
})

local cameraHinge = require(vehicle.TurretController).new(gunnerSystem.CameraHinge, {
	["YawLeft"] = 0;
	["YawRight"] = 0;
	["ElevationAngle"] = 40;
	["DepressionAngle"] = 12.4;
})

local gunModes = {
	"Main",
	"Coax"
}
local gunModeIndex = 1

local keyCodeToNumber = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 0,
}

local ammoTypes = require(vehicle:WaitForChild("AmmoTypes"))

local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

local lastReplicateUpdate = tick()

local dragging = false
local zoomed = false
local firing = false
local isNightVision = false
local isInGunnerView = false

local lastCoaxFire = 0

local stabilizedLookVector = gun.TurretAttachment.WorldCFrame.LookVector

local rangefinderParams = RaycastParams.new()
rangefinderParams.FilterDescendantsInstances = {vehicle}

local interpolationTween = TweenInfo.new(0.10, Enum.EasingStyle.Linear)

local ui = script.GunnerView

local function isMyPlayerSeated()
	local occupant: Humanoid = turretSeat.Occupant

	return occupant and game.Players:GetPlayerFromCharacter(occupant.Parent) == myPlayer
end

local function getGunMode()
	return gunModes[gunModeIndex]
end

local function occupantChanged()
	setZoom(false)

	if isMyPlayerSeated() then
		-- add effects
		
		
	else
		-- remove effects
		exitGunnerView()
	end
end

function lerp(a, b, t)
	return a + (b - a) * t
end

function setZoom(newState)
	zoomed = (newState ~= nil and newState) or (newState == nil and not zoomed)
	
	if isInGunnerView then
		if zoomed then
			playerCamera.FieldOfView = 10
		else
			playerCamera.FieldOfView = 30
		end
	end
	
	ui.Sight.Reticle1.Visible = not zoomed
	ui.Sight.Reticle2.Visible = zoomed
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
	
	camera.Lens.IRSpotlight.Enabled = isNightVision
	
	gun.NightVisionToggle:Play()
end

function checkForRound()
	local alreadyUI = myPlayer.PlayerGui:FindFirstChild("NewRound")
	if alreadyUI then
		alreadyUI:Destroy()
	end
	
	if isInGunnerView and (gunnerSystem.AwaitingRound.Value == true) then
		local ui = script.NewRound:Clone()
		ui.Parent = myPlayer:WaitForChild("PlayerGui")
	end
end

function onRoundChange()
	local toDisplay = gunnerSystem.LoadedRound.Value
	
	if toDisplay == "" then
		toDisplay = "---"
	end
	
	ui.Info.Round.Text = "RND  : "..toDisplay
end

function enterGunnerView()
	if gunnerSystem.AwaitingRound.Value then
		checkForRound()
	end
	
	isInGunnerView = true
	
	playerCamera.CameraType = Enum.CameraType.Scriptable
	playerCamera.FieldOfView = 30

	userInputService.MouseIconEnabled = false

	ui.Parent = myPlayer.PlayerGui
	
	ui.Cover.BackgroundTransparency = 0
	tweenService:Create(ui.Cover, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
end

function exitGunnerView()
	setZoom(false)
	setNightVision(false)
	
	dragging = false
	isInGunnerView = false
	
	playerCamera.CameraType = Enum.CameraType.Custom
	playerCamera.FieldOfView = 70

	userInputService.MouseIconEnabled = true

	ui.Parent = script
end

local function playSound(parent, sound)
	local clone = sound:Clone()
	clone.Parent = parent
	clone.Name = "CoaxClone"
	clone:Play()
	
	clone.PlaybackSpeed = Random.new():NextNumber(0.9, 1.1)

	game.Debris:AddItem(clone, 1)
	
	return clone
end

local function ejectRound()
	if gunnerSystem.LoadedRound.Value == "" then
		print('stop')
		return
	end
	
	print('ejecting round')
	
	gunnerSystem.AwaitingRound.Value = true
	gunnerSystem.LoadedRound.Value = ""
end

local function fire()
	local mode = getGunMode()
	local direction = gun.TurretAttachment.WorldCFrame.LookVector
	
	if mode == "Main" then
		local blur = Instance.new("BlurEffect")
		blur.Parent = playerCamera
		blur.Size = 40
		
		tweenService:Create(blur, TweenInfo.new(3), {Size = 0}):Play()
		
		game.Debris:AddItem(blur, 3)
		
		local position = gun.TurretAttachment.WorldPosition

		gun.FireInside1:Play()
		gun.FireInside2:Play()

		vehicle.ReplicateSound:FireServer("play", {Object = gun.FireInside1})
		vehicle.ReplicateSound:FireServer("play", {Object = gun.FireInside2})
		
		vehicle.ClientProjectileFire:Fire(position, direction, gunnerSystem.LoadedRound.Value)
		vehicle.ReplicateProjectile:FireServer(position, direction, gunnerSystem.LoadedRound.Value)
		
		ejectRound()
	elseif mode == "Coax" then
		lastCoaxFire = tick()
		
		local position = gun.CoaxialEnd.WorldPosition
		
		playSound(gun, gun.CoaxCasing)
		playSound(gun, gun.Coax)
		
		vehicle.ReplicateSound:FireServer("playCloned", {Object = gun.CoaxCasing})
		vehicle.ReplicateSound:FireServer("playCloned", {Object = gun.Coax})
		
		vehicle.ClientProjectileFire:Fire(position, direction, "Coax")
		vehicle.ReplicateProjectile:FireServer(position, direction, "Coax")
	end
	
	vehicle.Fired:FireServer(direction, mode)
end

local function renderStep(dt)
	if not isMyPlayerSeated() then
		return
	end
	
	local oldCondition = turret.Traverse.IsPlaying
	
	local viewportSize = playerCamera.ViewportSize
	local mouseDifference = userInputService:GetMouseLocation() - (viewportSize / 2) -- adds the offset

	-- left/right = mouseDifference.X
	-- up/down = mouseDifference.Y

	if mouseDifference.Magnitude <= 1 then
		mouseDifference = Vector2.new()
	end

	mouseDifference = Vector2.new(
		math.clamp(mouseDifference.X, -vehicle:GetAttribute("MaxHorizontalTraverseSpeed"), vehicle:GetAttribute("MaxHorizontalTraverseSpeed")),
		math.clamp(mouseDifference.Y, -vehicle:GetAttribute("MaxVerticalTraverseSpeed"), vehicle:GetAttribute("MaxVerticalTraverseSpeed"))
	)
	
	if dragging then
		if turret.TraverseStop.IsPlaying then
			turret.TraverseStop:Stop()
		end
		
		if zoomed then
			mouseDifference /= 2
		end
		
		local traverseSFXGoal = math.clamp(0.5 + (mouseDifference.Magnitude / 500) * 0.5, 0.5, 1)
		turret.Traverse.PlaybackSpeed = lerp( turret.Traverse.PlaybackSpeed, traverseSFXGoal, 0.25 )
		
		stabilizedLookVector = playerCamera.CFrame.LookVector
		
		local rightVector = playerCamera.CFrame.RightVector
		local upVector = playerCamera.CFrame.UpVector
		local lookVector = stabilizedLookVector * 400
		
		local turretBasePos = turret.TurretAttachment.WorldPosition + lookVector
		local gunBasePos = gun.BaseAttachment.WorldPosition + lookVector
		local cameraBasePos = camera.CameraAttachment.WorldPosition + lookVector
		
		turretHinge:LookAt(turretBasePos + (rightVector * mouseDifference.X * dt), 1)
		gunHinge:LookAt(gunBasePos + (upVector * -mouseDifference.Y * dt), 1)
		cameraHinge:LookAt(cameraBasePos + (upVector * -mouseDifference.Y * dt), 1)
		
		local p1 = viewportSize / 2
		local p2 = userInputService:GetMouseLocation()
		
		local distance = (p1 - p2).Magnitude
		local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))
		local midpoint = (p1 + p2) / 2
		
		ui.DirectionIndicator.Size = UDim2.new(0, distance, 0, 2)
		ui.DirectionIndicator.Position = UDim2.new(0, midpoint.X, 0, midpoint.Y)
		ui.DirectionIndicator.Rotation = angle
	else
		turretHinge:LookAt(turret.TurretAttachment.WorldPosition + stabilizedLookVector * 400, 1)
		gunHinge:LookAt(gun.BaseAttachment.WorldPosition + stabilizedLookVector * 400, 1)
		cameraHinge:LookAt(camera.CameraAttachment.WorldPosition + stabilizedLookVector * 400, 1)
	end
	
	if tick() - lastReplicateUpdate >= 1 / 10 then
		lastReplicateUpdate = tick()
		
		vehicle.ReplicateTurret:FireServer({
			["Turret"] = {turretHinge.JointMotor6D.C0, turretHinge.JointMotor6D.C1},
			["Gun"] = {gunHinge.JointMotor6D.C0, gunHinge.JointMotor6D.C1},
			["Camera"] = {cameraHinge.JointMotor6D.C0, cameraHinge.JointMotor6D.C1}
		})
		
		if turret.Traverse.IsPlaying then
			vehicle.ReplicateSound:FireServer("change", {Object = turret.Traverse, PlaybackSpeed = turret.Traverse.PlaybackSpeed})
		end
	end
	
	if isInGunnerView then
		playerCamera.CFrame = camera.Lens.WorldCFrame
		
		local finalDistance = "----"
		local ray = workspace:Raycast(camera.Lens.WorldPosition, camera.Lens.WorldCFrame.LookVector * 9999, rangefinderParams)
		if ray then
			finalDistance = ray.Distance
		end

		ui.Distance:SetAttribute("Text", finalDistance)
	end
	
	turret.Traverse.Playing = dragging and mouseDifference.Magnitude >= 2
	stabilizedLookVector = camera.Lens.WorldCFrame.LookVector
	
	ui.DirectionIndicator.Visible = dragging
	
	if oldCondition ~= turret.Traverse.IsPlaying then
		if turret.Traverse.IsPlaying then
			-- play it for other clients
			vehicle.ReplicateSound:FireServer("play", {Object = turret.Traverse})
		else
			-- stop it for other clients
			vehicle.ReplicateSound:FireServer("stop", {Object = turret.Traverse})
		end
		
		if oldCondition == false and turret.Traverse.IsPlaying == true then
			turret.Traverse.PlaybackSpeed = 0.5
		end
		
		if oldCondition == true and turret.Traverse.IsPlaying == false then
			turret.TraverseStop.PlaybackSpeed = turret.Traverse.PlaybackSpeed
			turret.TraverseStop:Play()
			
			vehicle.ReplicateSound:FireServer("change", {Object = turret.TraverseStop, PlaybackSpeed = turret.TraverseStop.PlaybackSpeed})
			vehicle.ReplicateSound:FireServer("play", {Object = turret.TraverseStop})
		end
	end
end

local function heartbeat(dt)
	if not isMyPlayerSeated() then
		return
	end
	
	if firing then
		
		local mode = getGunMode()
		
		if (mode == "Main" and gunnerSystem.LoadedRound.Value ~= "") or (mode == "Coax" and tick() - lastCoaxFire >= 60 / 600) then			
			fire()
		end
		
	end
end

local function inputBegan(input: InputObject, gameProcessed)
	if gameProcessed then
		return
	end
	
	if not isMyPlayerSeated() then
		return
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isInGunnerView then
		dragging = true
		
		userInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton2 and isInGunnerView then
		-- toggle zoom
		
		gun.ZoomToggle:Play()
		
		setZoom()
	end
	
	if input.KeyCode == Enum.KeyCode.V then
		setNightVision()
	end
	
	if input.KeyCode == Enum.KeyCode.R then
		gun.GunToggle:Play()
		
		gunModeIndex += 1
		
		if gunModeIndex > #gunModes then
			gunModeIndex = 1
		end
		
		ui.Info.Mode.Text = "MODE : "..string.upper(getGunMode())
	end
	
	if input.KeyCode == Enum.KeyCode.X then
		if not isInGunnerView then
			enterGunnerView()
		else
			exitGunnerView()
		end
		
	end
	
	if input.KeyCode == Enum.KeyCode.F then
		firing = true
	end
	
	if input.KeyCode == Enum.KeyCode.Z then
		-- eject round, load new round
		ejectRound()
		
		gun.Eject:Play()
		vehicle.ReplicateSound:FireServer("play", {Object = gun.Eject})
	end
	
	-- handle loading new rounds
	if keyCodeToNumber[input.KeyCode] and gunnerSystem.AwaitingRound.Value then
		local number = keyCodeToNumber[input.KeyCode]
		local ammoValue = ammoTypes.MainGunTypes[number]
		
		if ammoValue then
			print('loading '..ammoValue.Name)
			gunnerSystem.AwaitingRound.Value = false
			
			-- load a new round
			vehicle.LoadNewRound:FireServer(ammoValue.Name)
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
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
		userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	
	if input.KeyCode == Enum.KeyCode.F then
		firing = false
	end
end

local function applyTween(object, ti, properties)
	local tween = tweenService:Create(object, ti, properties)
	tween:Play()
	
	return tween
end

local function onTurretReplicate(data)
	applyTween(gunHinge.JointMotor6D, interpolationTween, {C0 = data.Gun[1], C1 = data.Gun[2]})
	applyTween(cameraHinge.JointMotor6D, interpolationTween, {C0 = data.Camera[1], C1 = data.Camera[2]})
	applyTween(turretHinge.JointMotor6D, interpolationTween, {C0 = data.Turret[1], C1 = data.Turret[2]})
end

turretSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged)
vehicle.ReplicateTurret.OnClientEvent:Connect(onTurretReplicate)

runService.RenderStepped:Connect(renderStep)
runService.Heartbeat:Connect(heartbeat)

userInputService.InputBegan:Connect(inputBegan)
userInputService.InputEnded:Connect(inputEnded)

gunnerSystem:WaitForChild("AwaitingRound").Changed:Connect(checkForRound)
gunnerSystem:WaitForChild("LoadedRound").Changed:Connect(onRoundChange)

gunnerSystem:WaitForChild("EnterView").Event:Connect(enterGunnerView)
gunnerSystem:WaitForChild("ExitView").Event:Connect(exitGunnerView)
