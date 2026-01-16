-- Module For Managing GameTables
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage:WaitForChild("Models")
local tables = models:WaitForChild("Tables")
local chairs = models:WaitForChild("Chairs")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configs = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Configs"))
local GameTableConfig = Configs.GameTable

local GameTable = {}
GameTable.__index = GameTable

function GameTable.new(position:Vector2)
	local self = setmetatable({}, GameTable)

	local table = tables:FindFirstChild("Default"):Clone()
	local playerOneChair = chairs:FindFirstChild('Default'):Clone()
	local playerTwoChair = chairs:FindFirstChild('Default'):Clone()

	table:PivotTo(CFrame.new(Vector3.new(position.X, GameTableConfig.TableHeight, position.Y)))
	local tablePosition = table:GetPivot().Position
	playerOneChair:PivotTo(CFrame.new(Vector3.new(tablePosition.X + GameTableConfig.ChairOffsetX, GameTableConfig.ChairHeight, tablePosition.Z + GameTableConfig.ChairOffsetZ)))
	playerTwoChair:PivotTo(CFrame.new(Vector3.new(tablePosition.X - GameTableConfig.ChairOffsetX, GameTableConfig.ChairHeight, tablePosition.Z + GameTableConfig.ChairOffsetZ)))
	
	local rotationCFrame = CFrame.Angles(0, math.rad(GameTableConfig.ChairRotY), 0)  -- e.g., angleDeg = 45 for 45°
	local fullCFrame = CFrame.new(playerOneChair:GetPivot().Position) * rotationCFrame  -- Position * Rotation
	playerOneChair:PivotTo(fullCFrame)

	local rotationCFrame = CFrame.Angles(0, math.rad(GameTableConfig.ChairRotY), 0)  -- e.g., angleDeg = 45 for 45°
	local fullCFrame = CFrame.new(playerTwoChair:GetPivot().Position) * rotationCFrame  -- Position * Rotation
	playerTwoChair:PivotTo(fullCFrame)

	local tableChairs = {playerOneChair, playerTwoChair}

	-- TODO: Set Up Ui Signs on the Tables
	-- TODO: create parts for signs

	table.Parent = workspace
	for _, chair in pairs(tableChairs) do
		chair.Parent = workspace
	end
	return self
end

function GameTable:Is_Ready()
	-- Check if the table is ready for a game
	return false
end 

return GameTable