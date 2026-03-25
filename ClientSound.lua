local vehicle = script.Parent
local replicateSoundRemote = vehicle:WaitForChild("ReplicateSound")

local function onReplicateSound(applyType, data)
	if applyType == "play" then
		data.Object:Play()
	elseif applyType == "playCloned" then
		local clone = data.Object:Clone()
		clone.Parent = data.Object.Parent
		clone.Name = "ClonedSound"
		clone:Play()
		
		game.Debris:AddItem(clone, clone.TimeLength / clone.PlaybackSpeed)
	elseif applyType == "stop" then
		data.Object:Stop()
	elseif applyType == "change" then
		data.Object.Volume = data.Volume or data.Object.Volume
		data.Object.PlaybackSpeed = data.PlaybackSpeed or data.Object.PlaybackSpeed
	end
end

replicateSoundRemote.OnClientEvent:Connect(onReplicateSound)
