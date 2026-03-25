local module = {}

-- this module contains information about different projectile types

local vehicle = script.Parent
local fastCast = require(vehicle:WaitForChild("FastCastRedux"))

local params = RaycastParams.new()
params.FilterDescendantsInstances = {vehicle}

local APFSDS = fastCast.newBehavior()
APFSDS.RaycastParams = params
APFSDS.CosmeticBulletTemplate = game.ReplicatedStorage.Tracers["120mm"]
APFSDS.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
APFSDS.CosmeticBulletContainer = workspace.Tracers
APFSDS.MaxDistance = 9999

local HEAT = fastCast.newBehavior()
HEAT.RaycastParams = params
HEAT.CosmeticBulletTemplate = game.ReplicatedStorage.Tracers["120mm"]
HEAT.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
HEAT.CosmeticBulletContainer = workspace.Tracers
HEAT.MaxDistance = 9999

local machineGunBehavior = fastCast.newBehavior()
machineGunBehavior.RaycastParams = params
machineGunBehavior.CosmeticBulletTemplate = game.ReplicatedStorage.Tracers["13mm"]
machineGunBehavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
machineGunBehavior.CosmeticBulletContainer = workspace.Tracers
machineGunBehavior.MaxDistance = 9999

module.MainGunTypes = {
	[1] = {
		Behavior = APFSDS,
		Name = "APFSDS",
		Velocity = 4430,
	},
	
	[2] = {
		Behavior = HEAT,
		Name = "HEAT",
		Velocity = 2500,
	}
}

-- may add more in the future...
module.CoaxGunTypes = {
	[1] = {
		Behavior = machineGunBehavior,
		Name = "Coax",
		Velocity = 6000,
	}
}

return module
