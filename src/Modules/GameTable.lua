-- Module For Managing GameTables
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage:WaitForChild("Models")
local tables = models:WaitForChild("Tables")
local chairs = models:WaitForChild("Chairs")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowLeaveFrame = ReplicatedStorage:WaitForChild("ShowLeaveFrame")
local ShowInitCamView = ReplicatedStorage:WaitForChild("ShowInitCamView")
local CreateClickDetectors = ReplicatedStorage:WaitForChild("CreateClickDetectors")
local Configs = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Configs"))
local GameTableConfig = Configs.GameTable

local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

local GameTable = {}
GameTable.__index = GameTable

function GameTable.new(position:Vector2)
	local self = setmetatable({}, GameTable)
	self.numPlayers = 0
	self.isCountingDown = false
	self.playerOneFoods = {}
	self.playerTwoFoods = {}
	self.requiredPlayers = 1

	-- Setting up Table and Chairs --
	local table = tables:FindFirstChild("Default"):Clone()
	local playerOneChair = chairs:FindFirstChild('Default'):Clone()
	local playerTwoChair = chairs:FindFirstChild('Default'):Clone()
	local seatOne = Instance.new("Seat")
	local seatTwo = Instance.new("Seat")
	seatOne.Disabled = true
	seatTwo.Disabled = true
	seatOne.Size = Vector3.new(1, 0.2, 1)
	seatTwo.Size = Vector3.new(1, 0.2, 1)
	seatOne.CanCollide = false
	seatTwo.CanCollide = false
	seatOne.CastShadow = false
	seatTwo.CastShadow = false
	seatOne.Transparency = 0
	seatTwo.Transparency = 0

	local tablePosition = Vector3.new(position.X, GameTableConfig.TableHeight, position.Y)
	local rotationCFrame = CFrame.Angles(0, math.rad(GameTableConfig.TableRotY), 0)  -- e.g., angleDeg = 45 for 45°
	local fullCFrame = CFrame.new(tablePosition) * rotationCFrame  -- Position * Rotation
	table:PivotTo(fullCFrame)
	local tablePosition = table:GetPivot().Position
	playerOneChair:PivotTo(CFrame.new(Vector3.new(tablePosition.X + GameTableConfig.ChairOffsetX, GameTableConfig.ChairHeight, tablePosition.Z + GameTableConfig.ChairOffsetZ)))
	playerTwoChair:PivotTo(CFrame.new(Vector3.new(tablePosition.X - GameTableConfig.ChairOffsetX, GameTableConfig.ChairHeight, tablePosition.Z + GameTableConfig.ChairOffsetZ)))
	seatOne:PivotTo(CFrame.new(Vector3.new(tablePosition.X + GameTableConfig.ChairOffsetX, GameTableConfig.SeatOffsetY, tablePosition.Z + GameTableConfig.ChairOffsetZ)))
	seatTwo:PivotTo(CFrame.new(Vector3.new(tablePosition.X - GameTableConfig.ChairOffsetX, GameTableConfig.SeatOffsetY, tablePosition.Z + GameTableConfig.ChairOffsetZ)))
	seatOne.Anchored = true
	seatTwo.Anchored = true


	local rotationCFrame = CFrame.Angles(0, math.rad(GameTableConfig.ChairRotY), 0)  -- e.g., angleDeg = 45 for 45°
	local fullCFrame = CFrame.new(playerOneChair:GetPivot().Position) * rotationCFrame  -- Position * Rotation
	playerOneChair:PivotTo(fullCFrame)

	local rotationCFrame = CFrame.Angles(0, math.rad(GameTableConfig.ChairRotY), 0)  -- e.g., angleDeg = 45 for 45°
	local fullCFrame = CFrame.new(playerTwoChair:GetPivot().Position) * rotationCFrame  -- Position * Rotation
	playerTwoChair:PivotTo(fullCFrame)

	-- Disabling Seats initially --
	playerOneChair:WaitForChild("Seat").Disabled = true
	playerTwoChair:WaitForChild("Seat").Disabled = true
	local chairPrompts = {}

	-- Setting up Proximity Prompts For Chairs --
	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.ActionText = "Play Game"
	ProximityPrompt.ObjectText = "Join"
	ProximityPrompt.HoldDuration = 1.5
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
	ProximityPrompt.HoldDuration = 1.5
	ProximityPrompt.MaxActivationDistance = 10
	ProximityPrompt.Triggered:Connect(function(player)
		self:ChairPromptCallback(player, 2)
	end)
	chairPrompts[#chairPrompts+1] = ProximityPrompt
	ProximityPrompt.Parent = playerTwoChair:WaitForChild("Seat")

	local tableChairs = {playerOneChair, playerTwoChair}
	local seats = {seatOne, seatTwo}
	self.tableChairs = tableChairs
	self.seats = seats
	self.chairPrompts = chairPrompts

	-- Setting up Seat Occupant Changed Callbacks --
	for chairNumber, seat in pairs(self.seats) do
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not seat.Occupant then
				-- A player has left the seat
				self.numPlayers = self.numPlayers - 1
				self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
				self.winMoneySign.Text = GameTableConfig.DefaultMoneyText
				self.chairPrompts[chairNumber].Enabled = true
			else
				self.numPlayers = self.numPlayers + 1
				self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
				self.chairPrompts[chairNumber].Enabled = false
				local occupantHumanoid = seat.Occupant
				local player = game.Players:GetPlayerFromCharacter(occupantHumanoid.Parent)
				ShowLeaveFrame:FireClient(player, true) -- Make the leave button visible for the player
				self:CheckAndStartCountdown()
			end
		end)
	end

	-- Setting up Billboard Gui for Table --
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
	self.winMoneySign = textLabel

	-- Adding Squares on Top of Table --
	print("TableTop Size: " .. tostring(tableTop.Size))
	local squareSpacing = 0.5
	local squaresizeX = 0.85 * (table.tableTop.Size.X - squareSpacing * (GameTableConfig.NumSquaresX - 1)) / GameTableConfig.NumSquaresX
	local squaresizeZ = 0.95 * (table.tableTop.Size.Z - squareSpacing * (GameTableConfig.NumSquaresZ - 1)) / GameTableConfig.NumSquaresZ
	local squareSize = math.min(squaresizeX, squaresizeZ)
	local playerOneSquares = {}
	local playerTwoSquares = {}
	-- TODO: make sure the y position 0.1 is correct
	for i = 0, GameTableConfig.NumSquaresX - 1 do
		for j = 0, GameTableConfig.NumSquaresZ - 1 do
			local squarePart = Instance.new("Part")
			squarePart.Size = Vector3.new(squareSize, 0.1, squareSize)
			squarePart.Anchored = true
			squarePart.CanCollide = false
			squarePart.Transparency = 0
			squarePart.CastShadow = false
			squarePart.Material = Enum.Material.SmoothPlastic
			squarePart.Position = table.tableTop.Position + Vector3.new(
				(-GameTableConfig.NumSquaresX / 2 + 0.5 + i) * squareSize + (i - (GameTableConfig.NumSquaresX - 1) / 2) * squareSpacing,
				table.tableTop.Size.Y/2 + squarePart.Size.Y/2,
				(-GameTableConfig.NumSquaresZ / 2 + 0.5 + j) * squareSize + (j - (GameTableConfig.NumSquaresZ - 1) / 2) * squareSpacing
			)
			if i < GameTableConfig.NumSquaresX / 2 then
				squarePart.Color = Color3.fromRGB(4, 175, 236)-- color for player 2 side
				playerTwoSquares[#playerTwoSquares+1] = squarePart
			else
				squarePart.Color = Color3.fromRGB(196, 40, 28)  -- color for player 1 side
				playerOneSquares[#playerOneSquares+1] = squarePart
			end
			squarePart.Parent = table
		end
	end
	self.playerOneSquares = playerOneSquares
	self.playerTwoSquares = playerTwoSquares

	-- Parenting Table and Chairs to Workspace --
	self.table = table
	table.Parent = workspace
	for _, chair in pairs(tableChairs) do
		chair.Parent = workspace
	end

	for _, seat in pairs(seats) do
		seat.Parent = workspace
	end

	return self
end

function GameTable:ChairPromptCallback(player:Player, chairNumber:number)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid.Sit then
		print(player.Name .. " is already seated.")
		return
	end

	local seat = self.seats[chairNumber]
	humanoid.JumpHeight = 0  -- Disable jumping
	humanoid.JumpPower = 0  -- Disable jumping
	seat:Sit(humanoid) -- Make the player sit in the seat
end


function GameTable:GetPlayerTableCFrame(chairNum)
	-- chair number is either 1 or 2, depending on which chair the player is sitting in --
	-- 1 is positive x direction, 2 is negative x direction --
    local table = self.table
	local tablePos = table.tableTop.Position
	local xOffsetSign = -1
	if chairNum == 1 then
		xOffsetSign = 1
	end
	local rotationAngle = math.rad(-90)
	return CFrame.lookAt(
		tablePos + Vector3.new(xOffsetSign * 2, 4, 0),
		tablePos + Vector3.new(xOffsetSign * 2, 0, 0)                  
	) * CFrame.Angles(0, 0, rotationAngle) 
end

function GameTable:GetTableCameraCFrame()
    local table = self.table
	local tablePos = table.tableTop.Position
	return CFrame.lookAt(
		tablePos + Vector3.new(0, 5, -5),  -- Cam pos (above)
		tablePos                          -- Look at table center
	)
end

function GameTable:CheckAndStartCountdown()
	print("Current Players: " .. self.numPlayers .. "/" .. self.requiredPlayers)
    if self.numPlayers >= self.requiredPlayers and not self.isCountingDown then
        self.isCountingDown = true

        for i = 5, 0, -1 do
            if self.numPlayers < self.requiredPlayers then
                print("Countdown aborted - player left!")
                self.isCountingDown = false
                self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
                return 
            end

            self.playerSign.Text = "Game starting in " .. i .. " seconds"
            task.wait(1)
        end

        -- Countdown finished → start the actual game!
        self.playerSign.Text = ""
		self.winMoneySign.Text = ""
		self.isCountingDown = false
 
		-- Get the players sitting in the chairs --
		local players = {}
		for chairNumber, seat in pairs(self.seats) do
			if seat.Occupant ~= nil then
				local occupantHumanoid = seat.Occupant
				local player = game.Players:GetPlayerFromCharacter(occupantHumanoid.Parent)
				table.insert(players, player)
			end
		end

		-- Verify player count --
		if #players < self.requiredPlayers then
			print("Not enough players to start the game.")
			self.isCountingDown = false
			-- TODO: remove remaining player from seat and award him money --
			return
		end

		-- Set camera for each player to show them the table --
		for i = 1, self.requiredPlayers do
			ShowLeaveFrame:FireClient(players[i], false) -- Make the leave button visible for the player
			local camCFrame = self:GetTableCameraCFrame()
			ShowInitCamView:FireClient(players[i], camCFrame)  -- set cam for ith player
		end
		
		-- drop the food on server
		-- TODO: add code to spawn the player's own selected food
		-- TODO: probably need to add a remote function to retrieve the player's selected food from the client
		local tweens = {}
		local playerOneFoods = {}
		for _, part in self.playerOneSquares do
			local food = Instance.new("Part")
			food.Size = Vector3.new(0.5, 0.5, 0.5)
			local spawnLocation = part.Position + Vector3.new(0, part.Size.Y/2 + food.Size.Y/2, 0) + Vector3.new(0, 3, 0)
			food.Anchored = true
			food.Position = spawnLocation
			food.Parent = workspace
			local tween = TweenService:Create(food, tweenInfo, {Position = part.Position + Vector3.new(0, part.Size.Y/2 + food.Size.Y/2, 0)})
			table.insert(tweens, tween)
			table.insert(playerOneFoods, food)
		end
		self.playerOneFoods = playerOneFoods

		local playerTwoFoods = {}
		for _, part in self.playerTwoSquares do
			local food = Instance.new("Part")
			food.Size = Vector3.new(0.5, 0.5, 0.5)
			local spawnLocation = part.Position + Vector3.new(0, part.Size.Y/2 + food.Size.Y/2, 0) + Vector3.new(0, 3, 0)
			food.Anchored = true
			food.Position = spawnLocation
			food.Parent = workspace
			local tween = TweenService:Create(food, tweenInfo, {Position = part.Position + Vector3.new(0, part.Size.Y/2 + food.Size.Y/2, 0)})
			table.insert(tweens, tween)
			table.insert(playerTwoFoods, food)
		end
		self.playerTwoFoods = playerTwoFoods

		local completedCount = 0
		local totalTweens = #tweens

		for _, tween in ipairs(tweens) do
			tween.Completed:Connect(function()
				completedCount += 1
				if completedCount >= totalTweens then
					print("ALL tweens finished! Proceeding...")
					self:StartGame()
				end
			end)
			tween:Play()  -- Still all at once
		end		
    end
end

function GameTable:StartGame()
	-- Change the camera for each player to show them their own side of the table --
	local players = {}
	for chairNumber, seat in pairs(self.seats) do
		if seat.Occupant ~= nil then
			local occupantHumanoid = seat.Occupant
			local player = game.Players:GetPlayerFromCharacter(occupantHumanoid.Parent)
			local desiredChairNumber = 1
			if chairNumber == 1 then
				desiredChairNumber = 2
			end
			local camCFrame = self:GetPlayerTableCFrame(desiredChairNumber)
			ShowInitCamView:FireClient(player, camCFrame)  -- set cam for ith player
			players[chairNumber] = player
			print("Player " .. player.Name .. " is sitting in chair " .. chairNumber)
		end
	end

	local playerCount = 0
    for _ in pairs(players) do
        playerCount += 1 -- Roblox Lua supports +=
    end

	-- Verify player count --
		if playerCount < self.requiredPlayers then
			print("Not enough players to start the game.")
			self.isCountingDown = false
			-- TODO: remove remaining player from seat and award him money --
			return
		end

	for playerNumber, player in pairs(players) do	
		if playerNumber == 1 then
			CreateClickDetectors:InvokeClient(player, self.playerTwoFoods)
		else
			CreateClickDetectors:InvokeClient(player, self.playerOneFoods) 
		end
	end
end

return GameTable