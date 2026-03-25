local driverSystem = script.Parent
local vehicle = driverSystem.Parent

local car = driverSystem:WaitForChild("Car")
local driverSeat = driverSystem:WaitForChild("Seat")

local WHEELS_PER_SIDE = 6

local function getOccupantPlayer()
	local humanoid = driverSeat.Occupant
	local player = humanoid and game.Players:GetPlayerFromCharacter(humanoid.Parent)

	return player
end

local function occupantChanged()
	local player = getOccupantPlayer()
	if player then
		car:SetNetworkOwner(player)
		
		for _, v in pairs(driverSystem:GetChildren()) do
			if v:IsA("BasePart") then
				v.Massless = true
				v:SetNetworkOwner(player)
			end
		end
	end
end

local function setupWheels()
	for i = 1, WHEELS_PER_SIDE * 2, 1 do
		-- 6 wheels per side, distributed evenly along the part
		local attachment: Attachment = Instance.new("Attachment")
		attachment.Parent = car
		attachment.Name = "Wheel"..i
		attachment:SetAttribute("Index", i)
		attachment.Visible = true
		
		local massRatio = (car:GetMass() / 11200)
		attachment:SetAttribute("SpringStiffness", 55000 * massRatio)
		attachment:SetAttribute("SpringRestLength", 4)
		
		local criticalDampening = 2 * math.sqrt(attachment:GetAttribute("SpringStiffness") * (car:GetMass() / (WHEELS_PER_SIDE * 2)))
		attachment:SetAttribute("SpringDampening", criticalDampening)
		
		for j = 1, 4, 1 do
			local label = (j == 1 and "X") or (j == 2 and "Y") or (j == 3 and "Z") or (j == 4 and "Drag")
			local vectorForce: VectorForce = Instance.new("VectorForce")
			vectorForce.Parent = car
			vectorForce.Name = "Wheel"..i.."Force"..label
			vectorForce.Attachment0 = attachment
			vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
			vectorForce.Force = Vector3.new()
			vectorForce.Visible = true
			vectorForce.Color = (j == 1 and BrickColor.new("Really red")) 
				or (j == 2 and BrickColor.new("Neon green")) 
				or (j == 3 and BrickColor.new("Dark blue"))
				or (j == 4 and BrickColor.new("Bright yellow"))
		end

		local relativeX = car.Size.X / 2
		local relativeZ = 0
		
		local isLeftSide = (i <= WHEELS_PER_SIDE)
		local clampedIndex = isLeftSide and i or (i - WHEELS_PER_SIDE)

		if isLeftSide then
			relativeX = -relativeX
		end
		
		local padding = 1 
		local trackLength = car.Size.Z - (padding * 2)
		
		local alpha = (clampedIndex - 1) / (WHEELS_PER_SIDE - 1)

		-- Interpolate from Front (Length/2) to Back (-Length/2)
		local startZ = (trackLength / 2)
		local endZ = -(trackLength / 2)
		local relativeZ = startZ + (alpha * (endZ - startZ))
		
		attachment.Position = Vector3.new(relativeX, 0, relativeZ)
		
		local wheel: MeshPart = workspace.Wheel:Clone()
		wheel.Parent = car
		wheel.Name = "WheelVisual"..i
		wheel:SetNetworkOwner(nil)
		wheel:PivotTo(attachment.WorldCFrame)
		wheel.Massless = true

		local wheelWeld: Weld = Instance.new("Weld")
		wheelWeld.Name = "WheelWeld"
		wheelWeld.Part0 = car
		wheelWeld.Part1 = wheel
		
		wheelWeld.C0 = attachment.CFrame
		wheelWeld.C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90 * (isLeftSide and -1 or 1)), 0)
		
		wheelWeld.Parent = wheel
		
		wheelWeld:SetAttribute("DefaultCF", wheelWeld.C1)
	end
end

local function onReplicateSound(player: Player, ...)
	if player ~= getOccupantPlayer() then
		return
	end

	for _, v in game.Players:GetPlayers() do
		if v == player then
			continue
		end

		vehicle.ReplicateSound:FireClient(v, ...)
	end
end

local function onReplicateAttribute(player: Player, ...)
	if player ~= getOccupantPlayer() then
		return
	end
	
	for _, v in game.Players:GetPlayers() do
		if v == player then
			continue
		end

		vehicle.ReplicateAttribute:FireClient(v, ...)
	end
end

local function promptTriggered(player: Player)
	local character = player.Character
	if not character then
		return
	end
	
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	
	if humanoid.Sit then
		humanoid.Sit = false
	end
	
	driverSeat:Sit(humanoid)
end

occupantChanged()
driverSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged)
vehicle.ReplicateSound.OnServerEvent:Connect(onReplicateSound)
driverSeat.ProximityPrompt.Triggered:Connect(promptTriggered)

setupWheels()
