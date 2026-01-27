-- Module For Managing GameTables
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage:WaitForChild("Models")
local tables = models:WaitForChild("Tables")
local chairs = models:WaitForChild("Chairs")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
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

	
	playerOneChair:WaitForChild("Seat").Disabled = true
	playerTwoChair:WaitForChild("Seat").Disabled = true

	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.ActionText = "Play Game"
	ProximityPrompt.ObjectText = "Join"
	ProximityPrompt.HoldDuration = 1.0
	ProximityPrompt.Parent = playerOneChair:WaitForChild("Seat")

	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.ActionText = "Play Game"
	ProximityPrompt.ObjectText = "Join"
	ProximityPrompt.HoldDuration = 1.0
	ProximityPrompt.Parent = playerTwoChair:WaitForChild("Seat")

	local tableChairs = {playerOneChair, playerTwoChair}

	-- TODO: Set Up Ui Signs on the Tables
	-- TODO: create parts for signs
	local tableTop = table:FindFirstChild("tableTop")
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "TableSign"
	billboardGui.Size = UDim2.new(7, 0, 5, 0)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.MaxDistance = 100
	billboardGui.Parent = tableTop

	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 0.2, 0)
	textLabel.Position = UDim2.new(0, 0, 0.15, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = GameTableConfig.DefaultSignText
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.TextStrokeTransparency = 0
	textLabel.FontFace = Font.fromName("FredokaOne",  Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	textLabel.Name = "PlayerSign"
	textLabel.Parent = billboardGui

	textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 0.3, 0)
	textLabel.Position = UDim2.new(0, 0, 0.6, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = GameTableConfig.DefaultMoneyText
	textLabel.TextColor3 = Color3.new(0.329411, 0.972549, 0.270588)
	textLabel.TextScaled = true
	textLabel.TextStrokeTransparency = 0
	textLabel.FontFace = Font.fromName("FredokaOne",  Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	textLabel.Name = "MoneySign"
	textLabel.Parent = billboardGui

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