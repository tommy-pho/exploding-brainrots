-- Module For Managing GameTables
local ProximityPromptService = game:GetService("ProximityPromptService")
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
	local chairPrompts = {}

	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.ActionText = "Play Game"
	ProximityPrompt.ObjectText = "Join"
	ProximityPrompt.HoldDuration = 1.0
	ProximityPrompt.MaxActivationDistance = 10
	ProximityPrompt.Triggered:Connect(function(player)
		self:ChairPromptCallback(player, 1)
	end)
	chairPrompts[#chairPrompts+1] = ProximityPrompt
	ProximityPrompt.Parent = playerOneChair:WaitForChild("Seat")

	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.ActionText = "Play Game"
	ProximityPrompt.ObjectText = "Join"
	ProximityPrompt.HoldDuration = 1.0
	ProximityPrompt.MaxActivationDistance = 10
	ProximityPrompt.Triggered:Connect(function(player)
		self:ChairPromptCallback(player, 2)
	end)
	chairPrompts[#chairPrompts+1] = ProximityPrompt
	ProximityPrompt.Parent = playerTwoChair:WaitForChild("Seat")

	local tableChairs = {playerOneChair, playerTwoChair}

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
	self.playerSign = textLabel

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

	self.numPlayers = 0
	self.tableChairs = tableChairs
	self.chairPrompts = chairPrompts
	return self
end

function GameTable:ChairPromptCallback(player:Player, chairNumber:number)
	-- TODOL : Add checks to prevent joining if already seated or game in progress

	print(player.Name .. " wants to join the game on chair " .. chairNumber)
	self.numPlayers = self.numPlayers + 1
	self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
	self.chairPrompts[chairNumber].Enabled = false

	local Seat = self.tableChairs[chairNumber]:WaitForChild("Seat")
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.JumpHeight = 0  -- Disable jumping
	humanoid.JumpPower = 0  -- Disable jumping
	Seat:Sit(humanoid)

	-- Make the ui visible
	player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui"):WaitForChild("LeaveFrame").Visible = true

	if self.numPlayers >= 2 then
		-- Reset player count after both players have joined
		-- self.numPlayers = 0
		-- TODO: Make Gui Appear for both players
		-- TODO: Start Counting Down to Start Game
		for i = 5, 0, -1 do
			self.playerSign.Text = "Game starting in "..i.." seconds"
			task.wait(1)
		self.playerSign.Text = ""
end
	end
end 

return GameTable