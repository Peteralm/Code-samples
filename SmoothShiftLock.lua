local SmoothShiftLock = {}
SmoothShiftLock.__index = SmoothShiftLock

local UIS = game:GetService("UserInputService")
local Player = game:GetService("Players").LocalPlayer
local Spring = require(script:WaitForChild("Spring"))

local Config = {
	ActivationKeyCode = Enum.KeyCode.LeftControl,
	LockedMouseIcon = "rbxassetid://132635963319066",
	
	RotationSpeed = 3,
	TransitionDamper = 0.7,
	CameraTransitionInSpeed  = 10,
	CameraTransitionOutSpeed = 14,
	LockedCameraOffset = Vector3.new(1.5, 1, 0)
}

function SmoothShiftLock.new()
	local self = setmetatable({}, SmoothShiftLock)
	self.Character = Player.Character or Player.CharacterAdded:Wait() :: Model
	self.Camera = workspace.CurrentCamera :: Camera
	self.Head = self.Character:WaitForChild("Head") :: BasePart
	self.Humanoid = self.Character:WaitForChild("Humanoid") :: Humanoid
	self.RootPart = self.Character:WaitForChild("HumanoidRootPart") :: BasePart
	
	self.Enabled = false	
	self.CamSpring = Spring.new(Vector3.zero)
	self.CamSpring.Damper = Config.TransitionDamper
	
	self.Connections = {}
	
	table.insert(self.Connections, Player.CharacterAdded:Connect(function(Character: Model)
		self:Reset()
	end))
	
	table.insert(self.Connections, game:GetService("RunService").RenderStepped:Connect(function(Delta)
		if not (self.Head.LocalTransparencyModifier > 0.6) then
			local camCF = self.Camera.CFrame;
			local distance = (self.Head.Position - camCF.p).magnitude;

			--// Camera offset
			if (distance > 1) then
				self.Camera.CFrame = (self.Camera.CFrame * CFrame.new(self.CamSpring.Position)); 
			end;
		end
		
		if self.Enabled then
			self:Update(Delta)
		end
	end))
	
	table.insert(self.Connections, UIS.InputBegan:Connect(function(Input, gpe)
		if gpe then
			return
		end
		
		if Input.KeyCode == Config.ActivationKeyCode then
			self:ToggleShiftLock()
		end
	end))
	
	table.insert(self.Connections, self.Humanoid.Died:Connect(function()
		self:Destroy()
	end))
	
	table.insert(self.Connections, Player.CharacterRemoving:Connect(function()
		self:Destroy()
	end))
	
	return self
end

function SmoothShiftLock:TransitionLockOffset(enable : boolean)
	if (enable) then
		self.CamSpring.Speed = Config.CameraTransitionInSpeed;
		self.CamSpring.Target = Config.LockedCameraOffset;
	else
		self.CamSpring.Speed = Config.CameraTransitionOutSpeed;
		self.CamSpring.Target = Vector3.zero;
	end;
end;

function SmoothShiftLock:ToggleShiftLock(Enabled: boolean)
	local LastEnabled = self.Enabled
	
	if Enabled == nil then
		self.Enabled = not self.Enabled
	else
		self.Enabled = Enabled
	end
	
	script.EnableChanged:Fire(Enabled)
	script.IsEnabled.Value = Enabled
	self:TransitionLockOffset(self.Enabled)
	UIS.MouseIcon = self.Enabled and Config.LockedMouseIcon or ""
	UIS.MouseBehavior = self.Enabled and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	self.Humanoid.AutoRotate = not self.Enabled;
end

function SmoothShiftLock:Destroy()
	self:ToggleShiftLock(false)
	
	for _, Connection: RBXScriptConnection in self.Connections do
		Connection:Disconnect()
	end
	
	table.clear(self)
end

function SmoothShiftLock:Update(Delta: number)
	if not (self.Humanoid.Sit) then
		local x, y, z = self.Camera.CFrame:ToOrientation();
		self.RootPart.CFrame = self.RootPart.CFrame:Lerp(CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0), Delta * 5 * Config.RotationSpeed);
	end
end

Player.CharacterAdded:Connect(function()
	SmoothShiftLock.new()
end)

script.GetConfigurations.OnInvoke = function()
	return Config
end

return {}
