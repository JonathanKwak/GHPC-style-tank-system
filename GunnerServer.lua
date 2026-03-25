local gunnerSystem = script.Parent
local vehicle = gunnerSystem.Parent

local gunnerSeat = gunnerSystem:WaitForChild("Seat")
local turret, gun, camera = gunnerSystem:WaitForChild("Turret"), gunnerSystem:WaitForChild("Gun"), gunnerSystem:WaitForChild("Camera")

local driverSeat = vehicle:WaitForChild("DriverSystem"):WaitForChild("Seat")

local function getOccupantPlayer()
	local humanoid = gunnerSeat.Occupant
	local player = humanoid and game.Players:GetPlayerFromCharacter(humanoid.Parent)
	
	return player
end

local function occupuantChanged()
	local player = getOccupantPlayer()
	
	if player then
		for _, v in pairs(gunnerSystem:GetChildren()) do
			if v:IsA("BasePart") then
				--v:SetNetworkOwner(player)
			end
		end
	end
end

local function fired(player: Player, fireDirection: Vector3, gunType)
	if player ~= getOccupantPlayer() then
		return
	end
	
	if gunType ~= "Coax" then
		vehicle.GunnerSystem.Gun.TurretAttachment.Flash:Emit(1)
		vehicle.GunnerSystem.Gun.TurretAttachment.Smoke:Emit(120)
		
		gunnerSystem.AwaitingRound.Value = true
		gunnerSystem.LoadedRound.Value = ""
		
		local lightFlash = vehicle.GunnerSystem.Gun.TurretAttachment.Light:Clone()
		lightFlash.Parent = vehicle.GunnerSystem.Gun.TurretAttachment
		lightFlash.Enabled = true
		
		game.Debris:AddItem(lightFlash, 0.04)
		
		local chassisNetworkOwner: Player = vehicle.DriverSystem.Seat:GetNetworkOwner()
		
		local recoilMagnitude = 240000
		local recoilDirection = -fireDirection.Unit
		
		vehicle.ApplyChassisImpulse:FireClient(chassisNetworkOwner, recoilDirection * recoilMagnitude, gun.BaseAttachment.WorldPosition)
	else
		vehicle.GunnerSystem.Gun.CoaxialEnd.Flash:Emit(1)
		vehicle.GunnerSystem.Gun.CoaxialEnd.Smoke:Emit(25)
	end
end

local function onNewRound(player: Player, ammoType: string)
	if player ~= getOccupantPlayer() then
		return
	end
	
	gunnerSystem.Gun.Autoloader:Play()
	
	gunnerSystem.AwaitingRound.Value = false
	gunnerSystem.LoadedRound.Value = ""
	
	task.wait(7)
	
	gunnerSystem.LoadedRound.Value = ammoType
end

local function onReplicateTurret(player: Player, data)
	if player ~= getOccupantPlayer() then
		return
	end
	
	for _, v in game.Players:GetPlayers() do
		if v == player then
			continue
		end
		
		vehicle.ReplicateTurret:FireClient(v, data)
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

local function onReplicateProjectile(player: Player, ...)
	if player ~= getOccupantPlayer() then
		return
	end
	
	for _, v in game.Players:GetPlayers() do
		if v == player then
			continue
		end
		
		vehicle.ReplicateProjectile:FireClient(v, ...)
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

	gunnerSeat:Sit(humanoid)
end

occupuantChanged()
gunnerSeat:GetPropertyChangedSignal("Occupant"):Connect(occupuantChanged)
vehicle.Fired.OnServerEvent:Connect(fired)
vehicle.ReplicateTurret.OnServerEvent:Connect(onReplicateTurret)
vehicle.ReplicateSound.OnServerEvent:Connect(onReplicateSound)
vehicle.ReplicateProjectile.OnServerEvent:Connect(onReplicateProjectile)
gunnerSeat.ProximityPrompt.Triggered:Connect(promptTriggered)
vehicle.LoadNewRound.OnServerEvent:Connect(onNewRound)
