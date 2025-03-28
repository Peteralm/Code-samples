local NoobClass = {}
NoobClass.__index = NoobClass

local RS = game:GetService("ReplicatedStorage")
local Knit = require(RS:WaitForChild("Packages"):WaitForChild("Knit"))
local Assets = RS:WaitForChild("Assets")
local Noobs = RS:WaitForChild("Noobs")
local ConditionHandler = require(Assets:WaitForChild("Modules"):WaitForChild("ConditionHandler"))
local NewObject = require(Assets.Modules:WaitForChild("NewObject.lua"))
local Signal = require(Assets.Modules:WaitForChild("Signal"))

function NoobClass.new()
	local self = setmetatable({}, NoobClass)
	local Character = game:GetService("Players").LocalPlayer.Character
	
	self.AnimateData = {}
	self.AnimateFunctionsCallback = {
		PlayAnimation = function(self, AnimationName, TransitionTime)
			local AnimationSelected = self.AnimationsStates[AnimationName]

			if not AnimationSelected then
				return
			end

			for Name, AnimationClassRunning: AnimationTrack in self.AnimationsStates do
				if AnimationClassRunning.IsPlaying and Name ~= AnimationName and not AnimationClassRunning:GetAttribute("CantStop") then
					AnimationClassRunning:Stop(TransitionTime)
				end
			end

			if AnimationSelected.IsPlaying then
				return
			end

			AnimationSelected:Play(TransitionTime)
		end,

		Running = function(self, AnimClass: AnimationTrack, Speed)
			local Character = game:GetService("Players").LocalPlayer.Character
			local Animate = Knit.GetController("Animate")

			Speed /= Character:GetScale()
			AnimClass:AdjustSpeed(Speed / 16)

			if Speed >= 0.01 then
				self.AnimateFunctionsCallback.PlayAnimation(self, "Running", 0.1)
			else
				self.AnimateFunctionsCallback.PlayAnimation(self, "Standing", 0.1)
			end
		end,

		Jumping = function(self, AnimClass)
			self.AnimateFunctionsCallback.PlayAnimation(self, "Jumping", 0.1)
			self.LastJumpingTimeAnimation = tick()
		end,

		FreeFalling = function(self, AnimClass, Enabled)
			local Character = game:GetService("Players").LocalPlayer.Character

			if Enabled then
				local Connection
				Connection = Character:FindFirstChildWhichIsA("Humanoid").StateChanged:Connect(function(_, New)
					if New == Enum.HumanoidStateType.Landed then
						self.AnimationsStates.Landed:SetAttribute("CantStop", true)
						self.AnimationsStates.Landed:Play()
						Connection:Disconnect()
					end
				end)

				if self.LastJumpingTimeAnimation then
					task.wait(0.3 - tick() - self.LastJumpingTimeAnimation)

					if Character:FindFirstChildWhichIsA("Humanoid"):GetState() ~= Enum.HumanoidStateType.Freefall then
						return
					end

					self.AnimateFunctionsCallback.PlayAnimation(self, "FreeFalling", 0.3)
				end
			end
		end,

		Update = function(self, DeltaTime)
			--[[if ConditionHandler.GetCondition("CanChangeAnimationState").Value and Character.Humanoid:GetState() == Enum.HumanoidStateType.Running then
				self.AnimateFunctionsCallback.Running(self.AnimationsStates.Running, 1)
				return
			end]]
		end,
	}
	self.DefaultAnimateFunctionsCallback = table.clone(self.AnimateFunctionsCallback)
	
	script.Parent:WaitForChild("LoadCharacterRequest").OnClientEvent:Connect(function()
		self:LoadCharacter()
	end)

	return self
end

function NoobClass:OnLoadCharacter()
	local Animate = Knit.GetController("Animate")
	local Character = game:GetService("Players").LocalPlayer.Character or game:GetService("Players").LocalPlayer.CharacterAppearanceLoaded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	local Animations = (function()
		local Animations = {}
		
		if typeof(self.AnimationsStates) == "table" then
			Animations = self.AnimationsStates
		end
		
		for _, AnimationInstance in script:WaitForChild("Animations"):GetDescendants() do
			if Animations[AnimationInstance.Name] then
				continue
			end
			
			Animations[AnimationInstance.Name] = AnimationInstance
		end
		
		return Animations
	end)()
	
	for HumanoidState: Enum.HumanoidStateType, Animation: Animation in Animations do
		Animations[HumanoidState] = Animate:AddAnimation(HumanoidState.Name, Animation)
	end
	self.DefaultAnimations = table.clone(Animations)
	self.AnimationsStates = Animations
	
	for _, Event in require(script:WaitForChild("AnimationStates")) do
		Humanoid[Event]:Connect(function(...)
			if self.AnimateFunctionsCallback[Event] then
				self.AnimateFunctionsCallback[Event](self, Animations[Event], ...)
			end
		end)
	end
	
	task.spawn(function()
		local Connection
		Connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
			if Character.Parent == nil then
				Connection:Disconnect()
				return
			end
			
			local Update = self.AnimateFunctionsCallback.Update

			if Update then
				Update(self, dt)
			end
		end)
	end)
end

function NoobClass:SetAnimationToDefault(Name: string)
	local AnimationSelected = self.DefaultAnimations[Name]
	
	if AnimationSelected then
		self.AnimationsStates[Name] = AnimationSelected
	end
end

function NoobClass:SetAnimationFunctionToDefault(Name: string)
	if self.DefaultAnimateFunctionsCallback[Name] then
		self.AnimateFunctionsCallback[Name] = self.DefaultAnimateFunctionsCallback[Name]
	end
end

return NoobClass
