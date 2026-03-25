local vehicle = script.Parent
local bindable = vehicle:WaitForChild("ClientProjectileFire")
local remote = vehicle:WaitForChild("ReplicateProjectile")

local fastCast = require(vehicle:WaitForChild("FastCastRedux"))

local caster = fastCast.new()

local ammoTypes = require(vehicle:WaitForChild("AmmoTypes"))

local function castTerminating(casterThatFired)
	local bullet = casterThatFired.RayInfo.CosmeticBulletObject
	
	if bullet then
		bullet:Destroy()
	end
end

local function lengthChanged(casterThatFired, lastPoint: Vector3, rayDir: Vector3, displacement: number, segmentVelocity: Vector3, bullet: Instance)
	local currentPoint = lastPoint + (rayDir * displacement)
	local distanceBetweenPoints = (currentPoint - lastPoint).Magnitude
	local center = (currentPoint + lastPoint) / 2
	
	if bullet then
		bullet.CFrame = CFrame.lookAt(center, currentPoint)
		bullet.Size = Vector3.new(bullet.Size.X, bullet.Size.Y, distanceBetweenPoints)
	end
end

local function onHit(casterThatFired, result: RaycastResult, segmentVelocity: Vector3, bullet: Instance)
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldCFrame = CFrame.lookAt(result.Position, result.Position + result.Normal)
	
	local impactFolder = script.Impacts:FindFirstChild(casterThatFired.UserData.Type)
	if impactFolder then
		for _, impact in pairs(impactFolder:GetChildren()) do
			local clone = impact:Clone()
			clone.Parent = attachment
			clone:Emit(clone:GetAttribute("EmissionCount") or 1)
		end
	end
	
	game.Debris:AddItem(attachment, 10)
end

local function onFire(origin: Vector3, direction: Vector3, gunType: string)
	local data = nil
	local activeCast
	
	local masterTable = nil
	
	if gunType ~= "Coax" then
		-- must be some variant of maingun
		masterTable = ammoTypes.MainGunTypes
	else
		masterTable = ammoTypes.CoaxGunTypes
	end
	
	for _, v in masterTable do
		if v.Name == gunType then
			data = v
			break
		end
	end
	
	activeCast = caster:Fire(origin, direction, data.Velocity, data.Behavior)
	activeCast.UserData.Type = gunType
end

bindable.Event:Connect(onFire)
remote.OnClientEvent:Connect(onFire)

caster.CastTerminating:Connect(castTerminating)
caster.LengthChanged:Connect(lengthChanged)
caster.RayHit:Connect(onHit)
