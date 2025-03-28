local CarClassModule = script.Parent
local Signal = require(CarClassModule.Signal)

local DefaultConfigurations = {
	MaxHealth = 100,
	MaxFuel = 100,
	FuelDiscount = 2,
	CanUseProximityPrompt = true,
	
	CollisionHealthDiscount = 0.05,
	CollisionUpdateInterval = 0.1, -- Time interval to calculate average change over
	CollisionThreshold = 250, -- Amount of average change that must be passed to play a collision sound
}

local CarClassServer = {}
CarClassServer.__index = CarClassServer

function CarClassServer.new(Car: Model)
	if Car:GetAttribute("Exploded") then
		return
	end
	
	local self = setmetatable({}, CarClassServer)
	self.Player = nil
	self.Car = Car
	self.Structure = Car:WaitForChild("Main"):WaitForChild("Structure") :: BasePart
	self.DriveSeat = Car.Main:WaitForChild("DriveSeat") :: VehicleSeat
	self.SteeringWheelJoint = Car.Main:WaitForChild("SteeringWheelJoint")
	self.Constraints = self.Structure:WaitForChild("Constraints") :: Folder
	
	self.CanUseProximityPrompt = DefaultConfigurations.CanUseProximityPrompt
	self.ProximityPrompt = (function()
		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Enabled = self.CanUseProximityPrompt
		Prompt.ActionText = "Enter"
		Prompt.ObjectText = ""
		Prompt.MaxActivationDistance = 12
		Prompt.RequiresLineOfSight = false
		Prompt.Parent = self.Structure
		
		return Prompt
	end)()
	self.TriggeredConnection = self.ProximityPrompt.Triggered:Connect(function(Player: Player)
		self.DriveSeat:Sit(Player.Character.Humanoid)
	end)
	
	self.IsIKEnabled = true
	self.ArmConstraints = (function()
		local Constraints = CarClassModule.ArmConstraints:Clone()
		Constraints.Parent = CarClassModule
		
		return Constraints
	end)()
	self.LeftIK, self.RightIK = (function()
		local LeftIK = Instance.new("IKControl")
		LeftIK.Name = "LeftIKHand"
		LeftIK.Target = Car.Main.SteeringWheel.LeftHand
		LeftIK.Parent = CarClassModule
		LeftIK.Enabled = false

		local RightIK = Instance.new("IKControl")
		RightIK.Name = "RightIKHand"
		RightIK.Target = Car.Main.SteeringWheel.RightHand
		RightIK.Parent = CarClassModule
		RightIK.Enabled = false
		
		return LeftIK, RightIK
	end)()
	
	self.IsExploded = false
	self.MaxFuel = DefaultConfigurations.MaxFuel
	self.Fuel = self.MaxFuel
	self.MaxHealth = DefaultConfigurations.MaxHealth
	self.Health = self.MaxHealth
	
	self.LastCollisionUpdate = os.clock()
	self.LastSpeed = 0
	self.TotalSpeedChange = 0

	self.OccupantChanged = Signal.new()
	self.OccupantConnection = self.DriveSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if self.DriveSeat.Occupant == nil then
			if self.Player then
				CarClassModule.OnLeft:FireClient(self.Player, Car)
				self.Player = nil
				self.OccupantChanged:Fire(nil)
			end
			
			return
		end
		
		local Character = self.DriveSeat.Occupant:FindFirstAncestorWhichIsA("Model")
		local Player = game:GetService("Players"):GetPlayerFromCharacter(Character)
		
		if not Player then
			return
		end
		
		self.Player = Player
		CarClassModule.OnSit:FireClient(Player, Car)
		self.OccupantChanged:Fire(Player)
	end)
	
	self.UpdateConnection = game:GetService("RunService").Stepped:Connect(function(_, Delta)
		self:Update(Delta)
	end)
	
	self.OccupantChanged:Connect(function()
		self:SetupIK()
		
		if self.Player and self.CanUseProximityPrompt then
			self.ProximityPrompt.Enabled = false
		elseif self.CanUseProximityPrompt then
			self.ProximityPrompt.Enabled = true
		end
	end)
	
	return self
end

function CarClassServer:GetConfigurations()
	return self.Configurations
end

function CarClassServer:SetupIK()
	local LeftIK = self.LeftIK
	local RightIK = self.RightIK
	local ArmConstraints = self.ArmConstraints
	
	if self.Player then
		local Character = self.Player.Character		
		ArmConstraints.Parent = Character
		ArmConstraints.LeftShoulderRig.Attachment0 = Character.UpperTorso.LeftShoulderRigAttachment
		ArmConstraints.LeftShoulderRig.Attachment1 = Character.LeftUpperArm.LeftShoulderRigAttachment
		ArmConstraints.RightShoulderRig.Attachment0 = Character.UpperTorso.RightShoulderRigAttachment
		ArmConstraints.RightShoulderRig.Attachment1 = Character.RightUpperArm.RightShoulderRigAttachment
		
		ArmConstraints.LeftElbowRig.Attachment0 = Character.LeftUpperArm.LeftElbowRigAttachment
		ArmConstraints.LeftElbowRig.Attachment1 = Character.LeftLowerArm.LeftElbowRigAttachment
		ArmConstraints.RightElbowRig.Attachment0 = Character.RightUpperArm.RightElbowRigAttachment
		ArmConstraints.RightElbowRig.Attachment1 = Character.RightLowerArm.RightElbowRigAttachment
		
		ArmConstraints.LeftWristRig.Attachment0 = Character.LeftLowerArm.LeftWristRigAttachment
		ArmConstraints.LeftWristRig.Attachment1 = Character.LeftHand.LeftWristRigAttachment
		ArmConstraints.RightWristRig.Attachment0 = Character.RightLowerArm.RightWristRigAttachment
		ArmConstraints.RightWristRig.Attachment1 = Character.RightHand.RightWristRigAttachment

		for _, Constraint: Constraint in ArmConstraints:GetChildren() do
			Constraint.Enabled = true
		end

		LeftIK.ChainRoot = Character.LeftUpperArm
		RightIK.ChainRoot = Character.RightUpperArm

		LeftIK.EndEffector = Character.LeftHand
		RightIK.EndEffector = Character.RightHand

		RightIK.Parent, LeftIK.Parent = Character.Humanoid, Character.Humanoid
		RightIK.Enabled, LeftIK.Enabled = true, true
	else
		RightIK.Parent, LeftIK.Parent = CarClassModule, CarClassModule
		RightIK.Enabled, LeftIK.Enabled = false, false
		ArmConstraints.Parent = CarClassModule
		
		for _, Constraint: Constraint in ArmConstraints:GetChildren() do
			Constraint.Enabled = false
		end
	end
end

function CarClassServer:GiveFuel(Fuel: number)
	self.Fuel = math.clamp(self.Fuel + Fuel, 0, self.MaxFuel)
end

function CarClassServer:TakeDamage(Damage: number)
	self.Health = math.clamp(self.Health - Damage, 0, self.MaxHealth)
	print("Health: " .. self.Health)
	
	if self.Health == 0 then
		self:Explode()
	end
end

function CarClassServer:Explode()
	self.IsExploded = true
	local MainPart: BasePart = self.Structure
	MainPart:ApplyImpulse(MainPart.CFrame.UpVector * 35000)
	
	for _, Constraint: Constraint in self.Constraints:GetChildren() do
		Constraint.Enabled = false
	end
	
	for _, Wheel: BasePart in self.Car.Wheels:GetChildren() do
		if Wheel.Name:find("L") then
			Wheel:ApplyImpulse(Wheel.CFrame.RightVector * -500 + Wheel.CFrame.UpVector * 500)
		else
			Wheel:ApplyImpulse(Wheel.CFrame.RightVector * 500 + Wheel.CFrame.UpVector * 500)
		end
	end
	
	self.DriveSeat:Sit(nil)
	local Car = self.Car
	Car:SetAttribute("Exploded", true)
	task.delay(20, function()
		Car:Destroy()
	end)
	self:Destroy()
end

function CarClassServer:DetectCollisions(Delta: number)
	if self.IsExploded then
		return
	end
	
	-- Calculate the change in the car's speed and add it to totalSpeedChange
	local speed = self.Structure.AssemblyLinearVelocity.Magnitude
	local change = math.abs(speed - self.LastSpeed)
	self.LastSpeed = speed
	self.TotalSpeedChange += change

	local Elapsed = os.clock() - self.LastCollisionUpdate
	if Elapsed < DefaultConfigurations.CollisionUpdateInterval then
		return
	end
	self.LastCollisionUpdate = os.clock()

	-- Calculate the average change in speed over the update interval
	local averageChangeOverInterval = self.TotalSpeedChange / Elapsed
	if averageChangeOverInterval > DefaultConfigurations.CollisionThreshold then
		-- If the change is higher than the threshold, play a random collision sound
		local Damage = averageChangeOverInterval * DefaultConfigurations.CollisionHealthDiscount
		self:TakeDamage(Damage)
	end

	self.TotalSpeedChange = 0
end

function CarClassServer:UpdateSteeringWheel()
	if not self.SteeringWheelJoint then
		return
	end
	
	local Joint: Motor6D = self.SteeringWheelJoint
	local CurrentPosition = self.Constraints.SteeringPrismatic.CurrentPosition
	
	Joint.C1 = CFrame.Angles(0, 0, math.rad(45 * CurrentPosition))
end

function CarClassServer:Update(Delta)
	if self.Structure.Parent == nil then
		self:Destroy()
		return
	end
	
	self:DetectCollisions(Delta)
	self:UpdateSteeringWheel()
	
	if self.Structure.AssemblyLinearVelocity.Magnitude > 10 then
		self.Fuel = math.clamp(self.Fuel - DefaultConfigurations.FuelDiscount * Delta, 0, self.MaxFuel)
	end
	
	if self.Player then
		CarClassModule.OnFuelUpdated:FireClient(self.Player, self.Fuel)
		CarClassModule.OnHealthUpdated:FireClient(self.Player, self.Health)
	end
	
	print("\nHealth: " .. self.Health .. "\n" .. "Fuel: " .. self.Fuel)
end

function CarClassServer:Destroy()
	self.UpdateConnection:Disconnect()
	self.OccupantConnection:Disconnect()
	self.TriggeredConnection:Disconnect()
	self.RightIK:Destroy()
	self.LeftIK:Destroy()
	self.ArmConstraints:Destroy()
	CarClassModule.OnLeft:FireClient(self.Player, self.Car)
	
	table.clear(self)
end

return CarClassServer
