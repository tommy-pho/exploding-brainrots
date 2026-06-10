-- Venue layer: manages the physical table, chairs, seating, countdown, and cameras.
-- Game logic lives in a separate module; wire it up via the onGameReady callback.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterPlayer = game:GetService("StarterPlayer")

local models = ServerStorage:WaitForChild("Models")
local tables = models:WaitForChild("Tables")
local chairs = models:WaitForChild("Chairs")

local ShowLeaveFrame = ReplicatedStorage:WaitForChild("ShowLeaveFrame")
local ResetCamera = ReplicatedStorage:WaitForChild("ResetCamera")
local ShowInitCamView = ReplicatedStorage:WaitForChild("ShowInitCamView")

local Configs = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Configs"))
local GameTableConfig = Configs.GameTable

local GameTable = {}
GameTable.__index = GameTable
GameTable.TablesById = {}

-- onGameReady(players) is called (inside a task.spawn) once the countdown
-- finishes and the overview camera is set. players[chairNumber] = Player.
function GameTable.new(position: Vector2, onGameReady)
	local self = setmetatable({}, GameTable)
	self.id = HttpService:GenerateGUID(false)
	self.numPlayers = 0
	self.isCountingDown = false
	self.requiredPlayers = 2
	self.onGameReady = onGameReady or function() end
	self.activeGame = nil
	GameTable.TablesById[self.id] = self

	-- Physical table and chair setup --
	local tableModel = tables:FindFirstChild("Default"):Clone()
	local playerOneChair = chairs:FindFirstChild("Default"):Clone()
	local playerTwoChair = chairs:FindFirstChild("Default"):Clone()

	local function makeSeat()
		local seat = Instance.new("Seat")
		seat.Disabled = true
		seat.Size = Vector3.new(1, 0.2, 1)
		seat.CanCollide = false
		seat.CastShadow = false
		seat.Transparency = 0
		seat.Anchored = true
		return seat
	end
	local seatOne = makeSeat()
	local seatTwo = makeSeat()

	local tablePosition = Vector3.new(position.X, GameTableConfig.TableHeight, position.Y)
	tableModel:PivotTo(CFrame.new(tablePosition) * CFrame.Angles(0, math.rad(GameTableConfig.TableRotY), 0))
	local pivotPos = tableModel:GetPivot().Position

	local function chairCFrame(xSign)
		return CFrame.new(Vector3.new(
			pivotPos.X + xSign * GameTableConfig.ChairOffsetX,
			GameTableConfig.ChairHeight,
			pivotPos.Z + GameTableConfig.ChairOffsetZ
		)) * CFrame.Angles(0, math.rad(GameTableConfig.ChairRotY), 0)
	end
	local function seatCFrame(xSign)
		return CFrame.new(Vector3.new(
			pivotPos.X + xSign * GameTableConfig.ChairOffsetX,
			GameTableConfig.SeatOffsetY,
			pivotPos.Z + GameTableConfig.ChairOffsetZ
		))
	end

	playerOneChair:PivotTo(chairCFrame(1))
	playerTwoChair:PivotTo(chairCFrame(-1))
	seatOne:PivotTo(seatCFrame(1))
	seatTwo:PivotTo(seatCFrame(-1))

	playerOneChair:WaitForChild("Seat").Disabled = true
	playerTwoChair:WaitForChild("Seat").Disabled = true

	-- Proximity prompts --
	local chairPrompts = {}
	local function addPrompt(chairModel, chairNumber)
		local prompt = Instance.new("ProximityPrompt")
		prompt.RequiresLineOfSight = false
		prompt.ActionText = "Play Game"
		prompt.ObjectText = "Join"
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(player)
			self:_onChairPrompt(player, chairNumber)
		end)
		prompt.Parent = chairModel:WaitForChild("Seat")
		chairPrompts[chairNumber] = prompt
	end
	addPrompt(playerOneChair, 1)
	addPrompt(playerTwoChair, 2)

	self.tableChairs = {playerOneChair, playerTwoChair}
	self.seats = {seatOne, seatTwo}
	self.chairPrompts = chairPrompts

	-- Seat occupant callbacks --
	for chairNumber, seat in pairs(self.seats) do
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not seat.Occupant then
				self.numPlayers -= 1
				self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
				self.winMoneySign.Text = GameTableConfig.DefaultMoneyText
				self.chairPrompts[chairNumber].Enabled = true
			else
				self.numPlayers += 1
				self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
				self.chairPrompts[chairNumber].Enabled = false
				local player = game.Players:GetPlayerFromCharacter(seat.Occupant.Parent)
				ShowLeaveFrame:FireClient(player, true)
				self:_checkAndStartCountdown()
			end
		end)
	end

	-- Billboard GUI --
	local tableTop = tableModel:FindFirstChild("tableTop")
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TableSign"
	billboard.Size = UDim2.new(7, 0, 5, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 100
	billboard.Parent = tableTop

	local function makeLabel(size, pos, text, color)
		local lbl = Instance.new("TextLabel")
		lbl.Size = size
		lbl.Position = pos
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color
		lbl.TextScaled = true
		lbl.TextStrokeTransparency = 0
		lbl.FontFace = Font.fromName("FredokaOne", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
		lbl.Parent = billboard
		return lbl
	end
	self.playerSign = makeLabel(UDim2.new(1,0,0.2,0), UDim2.new(0,0,0.15,0), GameTableConfig.DefaultSignText, Color3.new(1,1,1))
	self.winMoneySign = makeLabel(UDim2.new(1,0,0.3,0), UDim2.new(0,0,0.6,0), GameTableConfig.DefaultMoneyText, Color3.fromRGB(84,248,69))

	-- Colored squares on the tabletop --
	local squareSpacing = 0.5
	local sqX = 0.85 * (tableTop.Size.X - squareSpacing * (GameTableConfig.NumSquaresX - 1)) / GameTableConfig.NumSquaresX
	local sqZ = 0.95 * (tableTop.Size.Z - squareSpacing * (GameTableConfig.NumSquaresZ - 1)) / GameTableConfig.NumSquaresZ
	local sqSize = math.min(sqX, sqZ)

	local playerOneSquares, playerTwoSquares = {}, {}
	for i = 0, GameTableConfig.NumSquaresX - 1 do
		for j = 0, GameTableConfig.NumSquaresZ - 1 do
			local sq = Instance.new("Part")
			sq.Size = Vector3.new(sqSize, 0.1, sqSize)
			sq.Anchored = true
			sq.CanCollide = false
			sq.CastShadow = false
			sq.Material = Enum.Material.SmoothPlastic
			sq.Position = tableTop.Position + Vector3.new(
				(-GameTableConfig.NumSquaresX / 2 + 0.5 + i) * sqSize + (i - (GameTableConfig.NumSquaresX - 1) / 2) * squareSpacing,
				tableTop.Size.Y / 2 + sq.Size.Y / 2,
				(-GameTableConfig.NumSquaresZ / 2 + 0.5 + j) * sqSize + (j - (GameTableConfig.NumSquaresZ - 1) / 2) * squareSpacing
			)
			if i < GameTableConfig.NumSquaresX / 2 then
				sq.Color = Color3.fromRGB(4, 175, 236)
				table.insert(playerTwoSquares, sq)
			else
				sq.Color = Color3.fromRGB(196, 40, 28)
				table.insert(playerOneSquares, sq)
			end
			sq.Parent = tableModel
		end
	end
	self.playerOneSquares = playerOneSquares
	self.playerTwoSquares = playerTwoSquares

	-- Parent everything to workspace --
	self.table = tableModel
	tableModel.Parent = workspace
	for _, chair in pairs(self.tableChairs) do chair.Parent = workspace end
	for _, seat in pairs(self.seats) do seat.Parent = workspace end

	return self
end

function GameTable:_onChairPrompt(player, chairNumber)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid.Sit then return end
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	self.seats[chairNumber]:Sit(humanoid)
end

function GameTable:GetPlayerTableCFrame(chairNum)
	local tablePos = self.table.tableTop.Position
	local xSign = (chairNum == 1) and 1 or -1
	return CFrame.lookAt(
		tablePos + Vector3.new(xSign * 2, 5, 0),
		tablePos + Vector3.new(xSign * 2, 0, 0)
	) * CFrame.Angles(0, 0, math.rad(-90))
end

function GameTable:GetTableCameraCFrame()
	local tablePos = self.table.tableTop.Position
	return CFrame.lookAt(tablePos + Vector3.new(0, 5, -5), tablePos)
end

function GameTable:_checkAndStartCountdown()
	if self.numPlayers < self.requiredPlayers or self.isCountingDown then return end
	self.isCountingDown = true

	for i = 5, 0, -1 do
		if self.numPlayers < self.requiredPlayers then
			self.isCountingDown = false
			self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
			return
		end
		self.playerSign.Text = "Game starting in " .. i .. " seconds"
		task.wait(1)
	end

	-- Collect seated players (keyed by chair number)
	local players = {}
	for chairNumber, seat in pairs(self.seats) do
		if seat.Occupant then
			players[chairNumber] = game.Players:GetPlayerFromCharacter(seat.Occupant.Parent)
		end
	end

	local playerCount = 0
	for _ in pairs(players) do playerCount += 1 end
	if playerCount < self.requiredPlayers then
		self.isCountingDown = false
		self.playerSign.Text = tostring(self.numPlayers) .. "/2 Players"
		return
	end

	self.playerSign.Text = ""
	self.winMoneySign.Text = ""
	self.isCountingDown = false

	-- Show overview camera, hide leave button, then hand off to game logic
	for _, player in pairs(players) do
		ShowLeaveFrame:FireClient(player, false)
		ShowInitCamView:FireClient(player, self:GetTableCameraCFrame())
	end

	task.spawn(function()
		self.onGameReady(players)
	end)
end

-- Unseat all players and reset the table after a game ends.
function GameTable:EndGame()
	for _, seat in pairs(self.seats) do
		if seat.Occupant then
			local humanoid = seat.Occupant
			local player = game.Players:GetPlayerFromCharacter(humanoid.Parent)
			humanoid.Sit = false
			humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
			humanoid.JumpPower = StarterPlayer.CharacterJumpPower
			if player then
				ShowLeaveFrame:FireClient(player, false)
				ResetCamera:FireClient(player)
			end
		end
	end
	self.playerSign.Text = GameTableConfig.DefaultSignText
	self.winMoneySign.Text = GameTableConfig.DefaultMoneyText
end

return GameTable
