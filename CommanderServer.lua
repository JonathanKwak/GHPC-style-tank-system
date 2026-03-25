local commanderSystem = script.Parent
local vehicle = commanderSystem.Parent

local commanderSeat = commanderSystem:WaitForChild("Seat")

local function getOccupantPlayer()
	local humanoid = commanderSeat.Occupant
	local player = humanoid and game.Players:GetPlayerFromCharacter(humanoid.Parent)

	return player
end

local function occupantChanged()
	local player = getOccupantPlayer()
	if player then
		for _, v in pairs(commanderSeat:GetChildren()) do
			if v:IsA("BasePart") then
				v.Massless = true
				v:SetNetworkOwner(player)
			end
		end
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

	commanderSeat:Sit(humanoid)
end

occupantChanged()
commanderSeat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged)
commanderSeat.ProximityPrompt.Triggered:Connect(promptTriggered)
