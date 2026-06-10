local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

print("Initializing server...")

-- Helper Function to create Remote events (created here so clients can WaitForChild on them) --
local function makeRemote(name)
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = ReplicatedStorage
	return remoteEvent
end

local ShowLeaveFrame = makeRemote("ShowLeaveFrame")
makeRemote("ShowInitCamView")
makeRemote("CreateClickDetectors")
local SelectFoods = makeRemote("SelectFoods")
local PlaceBomb = makeRemote("PlaceBomb")
makeRemote("StartTimer")
makeRemote("StopTimer")
makeRemote("ClearClickDetectors")
makeRemote("MarkBombs")
makeRemote("ResetCamera")

-- Modules --
local Modules = ServerScriptService:WaitForChild("Modules")
local GameTable = require(Modules:WaitForChild("GameTable"))
local FoodClickGame = require(Modules:WaitForChild("FoodClickGame"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local CrateSystem = require(Modules:WaitForChild("CrateSystem"))

-- Load player data as soon as they join --
Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)

-- Catch players who joined before this script finished loading --
for _, player in ipairs(Players:GetPlayers()) do
	if not PlayerData.get(player) then
		PlayerData.load(player)
	end
end

-- Save and unload when a player leaves (forfeit active game first) --
Players.PlayerRemoving:Connect(function(player)
	local tableId = player:GetAttribute("CurrentTableId")
	if tableId then
		local tbl = GameTable.TablesById[tableId]
		if tbl and tbl.activeGame then
			tbl.activeGame:ForfeitPlayer(player)
		end
		player:SetAttribute("CurrentTableId", nil)
	end
	PlayerData.save(player)
	PlayerData.unload(player)
end)

-- Autosave every 120 seconds in case the server shuts down before PlayerRemoving fires --
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.save(player)
		end
	end
end)

-- Robux crate purchases via Developer Products --
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player is not in the server; tell Roblox to retry when they rejoin
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local crateType = CrateSystem.PRODUCT_TO_CRATE[receiptInfo.ProductId]
	if not crateType then
		-- Unknown product — grant immediately so Roblox stops retrying
		warn("ProcessReceipt: unrecognized product ID " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local success, err = pcall(function()
		CrateSystem.openWithRobux(player, crateType)
	end)

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("ProcessReceipt: failed to open crate — " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

-- Leave button: unseat the player --
ShowLeaveFrame.OnServerEvent:Connect(function(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid.Sit then
		humanoid.Sit = false
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
	end
end)

-- Player selects one of their own food during a turn --
SelectFoods.OnServerEvent:Connect(function(player, tableId, choiceIndex)
	local tbl = GameTable.TablesById[tableId]
	if tbl and tbl.activeGame then
		tbl.activeGame:SubmitChoice(player, choiceIndex)
	end
end)

-- Player places a bomb on the opponent's food during setup --
PlaceBomb.OnServerEvent:Connect(function(player, tableId, foodIndex)
	local tbl = GameTable.TablesById[tableId]
	if tbl and tbl.activeGame and tbl.activeGame.recordBombPlacement then
		tbl.activeGame.recordBombPlacement(player, foodIndex)
	end
end)

-- Spawn game tables --
-- To use a different game, swap FoodClickGame.new for another implementation.
print("Initializing game tables...")
local NUM_ROWS = 3
local NUM_COLS = 5
local DX = 20
local DZ = 15
local START = Vector3.new(23, 1.5, 18.2)

for row = 0, NUM_ROWS - 1 do
	for col = 0, NUM_COLS - 1 do
		local position = Vector2.new(START.X + col * DX, START.Z + row * DZ)
		local tbl  -- forward-declared so the callback closes over it

		tbl = GameTable.new(position, function(players)
			local game = FoodClickGame.new(tbl)
			game:Start(players)
		end)
	end
end
