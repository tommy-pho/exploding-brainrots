-- Module For Managing GameTables
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local models = ReplicatedStorage:WaitForChild("Models")
local tables = models:WaitForChild("Tables")
local chairs = models:WaitForChild("Chairs")
local defaultSignText = "0/2 Players"
local defaultMoneyTest = "Win $300"

local GameTable = {}
GameTable.__index = GameTable

function GameTable.new(position:Vector3)
	local self = setmetatable({}, GameTable)

	self.table = tables:FindFirstChild("Default"):Clone()
	self.table.Position = position

	self.chairs = {}
	local player_one_chair = chairs:FindFirstChild('Default'):Clone()
	local player_two_chair = chairs:FindFirstChild('Default'):Clone()
	-- self.chairs.Position = position + Vector3.new(0,0,5)
	self.chairs.insert(player_one_chair)
	self.chairs.insert(player_two_chair)

	-- Set Up Ui Signs on the Tables
	-- create parts for signs


	self.table.Parent = workspace
	for _, chair in pairs(self.chairs) do
		chair.Parent = workspace
	end
	
	return self
end


function GameTable:Is_Ready()
	-- Check if the table is ready for a game
	return false
end 

return GameTable