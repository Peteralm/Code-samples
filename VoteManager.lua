local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Modules"):WaitForChild("Signal"))

local VoteManager = {}
VoteManager.__index = VoteManager

function VoteManager.new (time: number, options: { string })
	local self = setmetatable({}, VoteManager)
	
	self.Votes = (function ()
		local votes = {}
		
		for _, name: string in options do
			votes[name] = {}
		end

		return votes
	end)()
	
	self.VoteAdded = Signal.new()
	self.VoteRemoved = Signal.new()
	self.Ended = Signal.new()

	task.delay(time, function ()
		self.Ended:Fire((function ()
			local voteCount = 0
			local winners = {}
			for name, votes in self.Votes do
				if #votes > voteCount then
					table.clear(winners)
					voteCount = #votes
					table.insert(winners, name)
				elseif #votes == voteCount then
					table.insert(winners, name)				
				end
			end

			return winners
		end)(), self.Votes)

		self:Cancel()
	end)

	return self
end

function VoteManager:GetPlayerVote (player: Player)
	for name, votes in self.Votes do
		if not table.find(votes, player) then continue end
		return name
	end
end

function VoteManager:OnVote (player: Player, targetVote: string)
	local playerVote = self:GetPlayerVote(player)
	if playerVote then
		self.VoteRemoved:Fire(player, playerVote)
		table.remove(self.Votes[playerVote], table.find(self.Votes[playerVote], player))
	end

	if typeof(self.Votes[targetVote]) ~= "table" then
		return
	end

	table.insert(self.Votes[targetVote], player)
	self.VoteAdded:Fire(player, targetVote)
end

function VoteManager:Cancel ()
	table.clear(self)
end

return VoteManager
