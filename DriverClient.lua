local driverSystem = script.Parent
local vehicle = driverSystem.Parent

local car = driverSystem:WaitForChild("Car")
local driverSeat = driverSystem:WaitForChild("Seat")

local myPlayer = game.Players.LocalPlayer
local playerCamera = workspace.CurrentCamera

local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

local tireAttachments = {}
local velocities = {}

local lastSoundUpdate = tick()

local gears = {
	[-2] = {
		["TopSpeed"] = 4,
		["Power"] = -120000,
		["Name"] = "R2",
	},
	[-1] = {
		["TopSpeed"] = 6,
		["Power"] = -50000,
		["Name"] = "R1",
	},
	[0] = {
		["TopSpeed"] = 4,
		["Power"] = 100000,
		["Name"] = "F1",
	},
	[1] = {
		["TopSpeed"] = 6,
		["Power"] = 60000,
		["Name"] = "F2",
	},
	[2] = {
		["TopSpeed"] = 10,
		["Power"] = 40000,
		["Name"] = "F3",
	}
}

local gearIndex = 0

for _, v in car:GetChildren() do
	if v:IsA("Attachment") and v.Name:match("Wheel") then
		table.insert(tireAttachments, v:GetAttribute("Index"), v)
		velocities[v] = car:GetVelocityAtPosition(v.Position)
	end
end

local ui = script.DriverView
local isInDriverView = false
local previousLookVector = Vector3.new()

local enginePoweringOn = false

local coefficientOfFriction = 1
local tireGripFactor = 0.25
local throttling = false

local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {vehicle}
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function isMyPlayerSeated()
	local occupant: Humanoid = driverSeat.Occupant
	
	return occupant and game.Players:GetPlayerFromCharacter(occupant.Parent) == myPlayer
end

local function occupantChanged()
	if isMyPlayerSeated() then
		-- add effects
		
		previousLookVector = playerCamera.CFrame.LookVector
	else
		-- remove effects
		if isInDriverView then
			print('out')
			exitDriverView()
		end
	end
end

function enterDriverView()
	print('entering driver view')
	isInDriverView = true
	
	playerCamera.CameraType = Enum.CameraType.Scriptable
	playerCamera.FieldOfView = 50
	
	userInputService.MouseIconEnabled = false
	userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	
	previousLookVector = playerCamera.CFrame.LookVector
	
	ui.Parent = myPlayer.PlayerGui
	
	ui.Cover.BackgroundTransparency = 0
	tweenService:Create(ui.Cover, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
end

function exitDriverView()
	isInDriverView = false
	
	playerCamera.CameraType = Enum.CameraType.Custom
	playerCamera.FieldOfView = 70
	
	userInputService.MouseIconEnabled = true

	ui.Parent = script
end

function setEngineState(bool)
	if bool == nil then
		bool = not vehicle:GetAttribute("EngineState")
	end
	
	if enginePoweringOn then
		return -- effectively a debounce
	end
	
	if bool == true then
		-- power on please
		
		car.Startup:Play()
		enginePoweringOn = true
		
		ui.MainFrame.Engine:SetAttribute("Text", "--")
		
		task.wait(4.3)
		enginePoweringOn = false
		
		car.InteriorEngine:Play()
		car.InteriorFolley:Play()
	else
		-- power off please
		
		car.InteriorEngine:Stop()
		car.InteriorFolley:Stop()
		car.Shutoff:Play()
	end
	
	ui.MainFrame.Engine:SetAttribute("Text", "")
	ui.MainFrame.Engine:SetAttribute("Text", bool and "ON" or "OF")
	
	vehicle:SetAttribute("EngineState", bool)
	vehicle.ReplicateAttribute:FireServer(vehicle:GetAttributes())
end

local function updateWheel(attachment: Attachment, dt)
	local restLength = attachment:GetAttribute("SpringRestLength")
	local wheel = car:WaitForChild("WheelVisual"..attachment:GetAttribute("Index"))
	local weld = wheel:WaitForChild("WheelWeld")

	local relativeUp = attachment.WorldCFrame.UpVector
	local radius = wheel.Size.Y / 2

	local ray = workspace:Spherecast(attachment.WorldPosition, radius, -relativeUp * restLength, rayParams)

	local targetOffset = restLength
	if ray then
		targetOffset = ray.Distance 
	end
	
	local defaultCF = weld:GetAttribute("DefaultCF")
	weld.C1 = defaultCF * CFrame.new(0, targetOffset, 0)
end

local function getDrag()
	local DRAG_COEFFICIENT = math.abs(vehicle:GetAttribute("EnginePower") / (vehicle:GetAttribute("TopSpeed")^2))
	
	local velocity = car.AssemblyLinearVelocity
	local speed = velocity.Magnitude

	if speed < 0.1 then return Vector3.zero end

	-- F = d * v^2
	local dragMagnitude = DRAG_COEFFICIENT * (speed^2)

	-- Apply in the opposite direction of movement
	return -velocity.Unit * dragMagnitude
end

local function getUpForces(attachment: Attachment, dt): Vector3
	local stiffness = attachment:GetAttribute("SpringStiffness")
	local restLength = attachment:GetAttribute("SpringRestLength")
	local damping = attachment:GetAttribute("SpringDampening") -- Use a high value here!
	
	local relativeUp = attachment.WorldCFrame.UpVector
	local ray = workspace:Raycast(attachment.WorldPosition, -relativeUp * restLength * 1.5, rayParams)

	if ray then
		local displacement = ray.Distance - restLength 
		
		local springForce = -stiffness * displacement
		
		local worldVel = car:GetVelocityAtPosition(attachment.WorldPosition)
		local localVelocity = relativeUp:Dot(worldVel)
		
		local dampingForce = -localVelocity * damping
		
		local weightSupport = (car:GetMass() * workspace.Gravity) / #tireAttachments
		
		local totalForce = springForce + dampingForce + weightSupport
		
		return relativeUp * math.max(0, totalForce)
	end

	return Vector3.zero
end

local function getForwardForces(attachment: Attachment)
	if vehicle:GetAttribute("EngineState") == false then
		return Vector3.new()
	end
	
	local direction = attachment.WorldCFrame.LookVector
	local magnitude = 0
	
	local isWPressed = isMyPlayerSeated() and userInputService:IsKeyDown(Enum.KeyCode.W)
	
	local isAPressed = isMyPlayerSeated() and userInputService:IsKeyDown(Enum.KeyCode.A)
	local isDPressed = isMyPlayerSeated() and userInputService:IsKeyDown(Enum.KeyCode.D)
	
	local isLeft = attachment:GetAttribute("Index") <= (#tireAttachments / 2)
	
	if isWPressed then
		magnitude = vehicle:GetAttribute("EnginePower")
	end
	
	if isLeft then

		if isAPressed then
			-- slow down
			
			magnitude = 0
		elseif isDPressed then
			-- speed up
			
			magnitude = vehicle:GetAttribute("EnginePower") * 2
		end

	else

		if isAPressed then
			-- speed up
			
			magnitude = vehicle:GetAttribute("EnginePower") * 2
		elseif isDPressed then
			-- slow down
			
			magnitude = 0
		end

	end
	--]]
	
	return direction * magnitude
end

-- cancels out whatever turning forces we had (so we don't slip on the ground)
-- also note this may be influenced by world vector things and not relative
-- meaning direction changes based on where on the map u are
local function getSteeringForces(attachment: Attachment, dt)
	-- world-space direction of the spring force
	local steeringDir = attachment.WorldCFrame.RightVector
	
	-- world-space velocity of the suspension
	local worldVel = car:GetVelocityAtPosition(attachment.WorldPosition)
	
	-- what it's the tire's velocity in the steering direction?
	-- note that steeringDir is a unit vector, so this returns the magnitude of tireWorldVel
	-- as projected onto steeringDir
	local steeringVel = steeringDir:Dot(worldVel)
	
	-- the change in velocity we're looking for is -steeringVel * gripFactor
	-- gripFactor is in range 0-1, 0 means no grip and 1 means full grip
	local desiredVelChange = -steeringVel * tireGripFactor
	
	-- turn the change in velocity into an acceleration (acceleration = change in vel / time)
	-- this will produce the acceleration necessary to change the velocity by desiredVelChange in 1 physics step
	local desiredAccel = desiredVelChange / dt
	
	-- Force = mass * acceleration, so multiply the mass of the tire and apply it as a force
	local force = steeringDir * (car:GetMass() / #tireAttachments) * desiredAccel
	
	--print(force.Magnitude)
	return force
	
end

-- to fix later
local function getFrictionForce(attachment: Attachment, dt)
	local localVel = attachment.WorldCFrame.Rotation:Inverse() * car:GetVelocityAtPosition(attachment.WorldPosition)
	local worldVel = car:GetVelocityAtPosition(attachment.WorldPosition)

	-- flatten relative to the vehicle
	local planarVelocity = Vector3.new(localVel.X, 0, localVel.Z)

	if planarVelocity.Magnitude < 0.1 then 
		return Vector3.zero 
	end

	-- F = (m * v) * dt
	local mass = car:GetMass()
	
	local brakeForce = Vector3.new()
	if not throttling then
		local brakePower = math.abs(vehicle:GetAttribute("EnginePower")) * 5
		local cappedWorldVel = worldVel
		
		brakeForce = -(worldVel * mass) / dt
		
		if brakeForce.Magnitude > brakePower then
			brakeForce = brakeForce.Unit * brakePower
		end
	end
	
	return (brakeForce / #tireAttachments)
end

local function heartbeat(dt)
	if car.AssemblyLinearVelocity.Magnitude < 0.1 then
		-- for some reason roblox physics will sleep unless you give it a nudge
		car.AssemblyLinearVelocity = Vector3.new(0, 0.001, 0)
	end
	
	for _, attachment: Attachment in tireAttachments do
		local forceX: VectorForce = car:WaitForChild(attachment.Name.."ForceX")
		local forceY: VectorForce = car:WaitForChild(attachment.Name.."ForceY")
		local forceZ: VectorForce = car:WaitForChild(attachment.Name.."ForceZ")
		local dragForce: VectorForce = car:WaitForChild(attachment.Name.."ForceDrag")
		
		local origin = attachment.WorldPosition
		local relativeUp = attachment.WorldCFrame.UpVector
		
		dragForce.Force = getDrag() / #tireAttachments
		
		forceX.Force = getSteeringForces(attachment, dt) + getFrictionForce(attachment, dt)
		forceY.Force = getUpForces(attachment, dt) + getFrictionForce(attachment, dt)
		forceZ.Force = getForwardForces(attachment) + getFrictionForce(attachment, dt)
		
		velocities[attachment] = car:GetVelocityAtPosition(attachment.Position)
		
		updateWheel(attachment, dt)
	end
	
	throttling = (isMyPlayerSeated() and vehicle:GetAttribute("EngineState") and userInputService:IsKeyDown(Enum.KeyCode.W))
	
	local velocity = car.AssemblyLinearVelocity
	
	ui.MainFrame.Speed:SetAttribute("Text", math.floor(velocity.Magnitude))--string.format("%04d", math.floor(velocity.Magnitude)))
	
	car.InteriorEngine.PlaybackSpeed = 0.5 + (math.clamp(velocity.Magnitude / car:GetAttribute("TopSpeed"), 0, 1) / 2)
	car.InteriorFolley.Volume = 0 + (math.clamp(velocity.Magnitude / car:GetAttribute("TopSpeed"), 0, 1) / 2)
	
	if tick() - lastSoundUpdate >= 0.1 then
		lastSoundUpdate = tick()
		
		vehicle.ReplicateSound:FireServer("change", {Object = car.InteriorEngine, PlaybackSpeed = car.InteriorEngine.PlaybackSpeed})
		vehicle.ReplicateSound:FireServer("change", {Object = car.InteriorFolley, Volume = car.InteriorFolley.Volume})
	end
end

local function renderStep(dt)
	if isInDriverView then
		--[[
		playerCamera.CFrame = CFrame.lookAt(
			playerCamera.CFrame.Position, playerCamera.CFrame.Position + previousLookVector
		):Lerp(car.DriverViewport.WorldCFrame, 0.15)
		--]]
		
		local currentPos = car.DriverViewport.WorldPosition
		local targetDirection = car.DriverViewport.WorldCFrame.LookVector
		
		local newLookVector = previousLookVector:Lerp(targetDirection, 0.15)
		
		playerCamera.CFrame = CFrame.lookAt(currentPos, currentPos + newLookVector)
		
		local delta = playerCamera.CFrame.LookVector - previousLookVector
		
		local relativeRotation = car.DriverViewport.WorldCFrame:ToObjectSpace(playerCamera.CFrame)
		local x, y, z = relativeRotation:ToEulerAnglesXYZ()
		
		local xOffset = delta:Dot(playerCamera.CFrame.RightVector)
		local yOffset = delta:Dot(playerCamera.CFrame.UpVector)
		
		-- translate that difference in look vectors into UI pixels
		ui.MainFrame.Position = UDim2.new(
			0,
			xOffset * 750,
			0,
			yOffset * 750
		)
		
		ui.MainFrame.Rotation = math.deg(z) * 0.5
		
		previousLookVector = newLookVector
	end
end

local function onChassisImpulse(impulse: Vector3, position: Vector3)
	car:ApplyImpulseAtPosition(impulse, position)
end

local function inputBegan(input: InputObject, gameProcessedEvent)
	
	if gameProcessedEvent then
		return
	end
	
	if not isMyPlayerSeated() then
		return
	end
	
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.E then
		local oldGear = gearIndex
		
		if input.KeyCode == Enum.KeyCode.Q then
			gearIndex -= 1
		end
		
		if input.KeyCode == Enum.KeyCode.E then
			gearIndex += 1
		end
		
		gearIndex = math.clamp(gearIndex, -2, 2)
		
		ui.MainFrame.Gear:SetAttribute("Text", gears[gearIndex].Name)
		
		if gearIndex > oldGear then
			-- shifted up
			
			local clone = driverSeat.GearShiftUp:Clone()
			clone.Parent = driverSeat
			clone:Play()

			game.Debris:AddItem(clone, 1)

			vehicle.ReplicateSound:FireServer("playCloned", {Object = driverSeat.GearShiftUp})
		elseif gearIndex < oldGear then
			-- shifted down
			
			local clone = driverSeat.GearShiftDown:Clone()
			clone.Parent = driverSeat
			clone:Play()

			game.Debris:AddItem(clone, 1)

			vehicle.ReplicateSound:FireServer("playCloned", {Object = driverSeat.GearShiftDown})
		end
		
		local newData = gears[gearIndex]
		
		vehicle:SetAttribute("CurrentGear", newData.Name)
		vehicle:SetAttribute("TopSpeed", newData.TopSpeed)
		vehicle:SetAttribute("EnginePower", newData.Power)
		
		vehicle.ReplicateAttribute:FireServer(vehicle:GetAttributes())
	end
	
	-- NOTE: this is temporary... in the actual game you'd click on a physical monitor in the tank
	if input.KeyCode == Enum.KeyCode.X then
		if not isInDriverView then
			enterDriverView()
		else
			exitDriverView()
		end
	end
	
	if input.KeyCode == Enum.KeyCode.P then
		-- toggle engine
		
		setEngineState()
	end
	
end

local function applyAttributeChanges(data)
	for aName, aValue in pairs(data) do
		vehicle:SetAttribute(aName, aValue)
	end
end

local function playerAdded(player: Player)
	rayParams:AddToFilter(player.Character or player.CharacterAdded:Wait())
end

playerAdded(myPlayer)
game.Players.PlayerAdded:Connect(playerAdded)
userInputService.InputBegan:Connect(inputBegan)
runService.Heartbeat:Connect(heartbeat)
runService.RenderStepped:Connect(renderStep)

driverSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged)
vehicle:WaitForChild("ApplyChassisImpulse").OnClientEvent:Connect(onChassisImpulse)

vehicle:WaitForChild("ReplicateAttribute").OnClientEvent:Connect(applyAttributeChanges)

driverSystem:WaitForChild("EnterView").Event:Connect(enterDriverView)
driverSystem:WaitForChild("ExitView").Event:Connect(exitDriverView)
