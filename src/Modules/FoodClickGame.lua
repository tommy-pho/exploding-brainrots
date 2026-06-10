-- Food-clicking game implementation built on TurnBasedGame.
--
-- Phase 1 (setup): each player sees the opponent's food and clicks to plant bombs.
-- Phase 2 (turns): each player clicks one of their own food; bomb = lose a heart.
-- The player who runs out of hearts loses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local TurnBasedGame = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("TurnBasedGame"))
local ShowInitCamView = ReplicatedStorage:WaitForChild("ShowInitCamView")
local CreateClickDetectors = ReplicatedStorage:WaitForChild("CreateClickDetectors")
local StartTimer = ReplicatedStorage:WaitForChild("StartTimer")
local StopTimer = ReplicatedStorage:WaitForChild("StopTimer")
local ClearClickDetectors = ReplicatedStorage:WaitForChild("ClearClickDetectors")
local MarkBombs = ReplicatedStorage:WaitForChild("MarkBombs")

local FOOD_DROP_TWEEN = TweenInfo.new(2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local NUM_BOMBS = 3
local MAX_HEARTS = 3
local BOMB_PLACEMENT_TIMEOUT = 60

local FoodClickGame = {}

function FoodClickGame.new(gameTable)
	local playerOneFoods = {}
	local playerTwoFoods = {}
	local bombedParts = {}       -- Set<Part>: which parts have bombs (server-side only)
	local hearts = {}            -- [player] = heart count
	local revealedP1 = {}        -- [Part] = true for P1 foods already picked
	local revealedP2 = {}        -- [Part] = true for P2 foods already picked
	local currentFoodLists = {}  -- [player] = ordered list sent to that player this phase/turn

	local function spawnFoods(squares)
		local foods, tweens = {}, {}
		for _, part in ipairs(squares) do
			local food = Instance.new("Part")
			food.Size = Vector3.new(0.5, 0.5, 0.5)
			food.Anchored = true
			food.Position = part.Position + Vector3.new(0, part.Size.Y / 2 + food.Size.Y / 2 + 3, 0)
			food.Parent = workspace
			local targetPos = part.Position + Vector3.new(0, part.Size.Y / 2 + food.Size.Y / 2, 0)
			table.insert(tweens, TweenService:Create(food, FOOD_DROP_TWEEN, {Position = targetPos}))
			table.insert(foods, food)
		end
		return foods, tweens
	end

	local function waitForTweens(tweens)
		if #tweens == 0 then return end
		local done = 0
		for _, tween in ipairs(tweens) do
			tween.Completed:Connect(function() done += 1 end)
			tween:Play()
		end
		while done < #tweens do task.wait(0.1) end
	end

	local function getRemainingFoods(foods, revealed)
		local remaining = {}
		for _, food in ipairs(foods) do
			if not revealed[food] then
				table.insert(remaining, food)
			end
		end
		return remaining
	end

	local config = {
		maxTurns = math.huge,  -- game ends by hearts, not a fixed turn count
		turnTimeLimit = 30, --time limit per turn (in seconds)

		-- Sets up the game by spawning food pieces above each square and dropping them in with tweens
		-- Then each player gets a chance to place bombs on the opponent's food pieces. Bomb placement is tracked server-side in bombedParts.
		onSetup = function(game)
			-- Spawn and drop food on both sides
			local tweens = {}
			local p1Foods, p1Tweens = spawnFoods(gameTable.playerOneSquares)
			playerOneFoods = p1Foods
			for _, t in ipairs(p1Tweens) do table.insert(tweens, t) end

			local p2Foods, p2Tweens = spawnFoods(gameTable.playerTwoSquares)
			playerTwoFoods = p2Foods
			for _, t in ipairs(p2Tweens) do table.insert(tweens, t) end

			waitForTweens(tweens)

			-- Initialize hearts
			for _, player in pairs(game.players) do
				hearts[player] = MAX_HEARTS
			end

			-- Transition each player's camera to their oppent's side of table for bomb placement
			for chairNumber, player in pairs(game.players) do
				local opponentChairNum = (chairNumber == 1) and 2 or 1
				ShowInitCamView:FireClient(player, gameTable:GetPlayerTableCFrame(opponentChairNum))
			end

			-- Bomb placement phase: each player sees opponent's food and places bombs
			local bombsLeft = {}
			for chairNumber, player in pairs(game.players) do
				bombsLeft[player] = NUM_BOMBS
				local opponentFoods = (chairNumber == 1) and playerTwoFoods or playerOneFoods --tenary operator to pick the correct food list for this player
				currentFoodLists[player] = opponentFoods
				player:SetAttribute("CurrentTableId", gameTable.id)
				CreateClickDetectors:FireClient(player, opponentFoods, gameTable.id, "bomb", NUM_BOMBS)
			end

			-- Expose a handler so the server can route PlaceBomb events here
			game.recordBombPlacement = function(player, foodIndex)
				local list = currentFoodLists[player]
				if not list then return end
				local food = list[foodIndex]
				if not food or bombedParts[food] then return end  -- ignore out-of-range or duplicates
				bombedParts[food] = true
				bombsLeft[player] = bombsLeft[player] - 1
			end

			-- Start the bomb placement countdown for both players
			for _, p in pairs(game.players) do
				StartTimer:FireClient(p, BOMB_PLACEMENT_TIMEOUT, "Place your bombs!")
			end

			-- Wait for all players to finish (or timeout)
			local startTime = tick()
			while tick() - startTime < BOMB_PLACEMENT_TIMEOUT do
				local allDone = true
				for _, player in pairs(game.players) do
					if bombsLeft[player] > 0 then
						allDone = false
						break
					end
				end
				if allDone then break end
				task.wait(0.1)
			end

			game.recordBombPlacement = nil  -- close off bomb phase

			-- Randomly assign any remaining bombs for players who didn't finish in time
			for _, player in pairs(game.players) do
				if bombsLeft[player] > 0 then
					local list = currentFoodLists[player]
					local available = {}
					for _, food in ipairs(list) do
						if not bombedParts[food] then
							table.insert(available, food)
						end
					end
					-- Fisher-Yates shuffle then take the first bombsLeft[player] items
					for i = #available, 2, -1 do
						local j = math.random(i)
						available[i], available[j] = available[j], available[i]
					end
					local randomlyChosen = {}
					for i = 1, bombsLeft[player] do
						if available[i] then
							bombedParts[available[i]] = true
							table.insert(randomlyChosen, available[i])
						end
					end
					if #randomlyChosen > 0 then
						MarkBombs:FireClient(player, randomlyChosen)
					end
				end
				-- Clear any remaining click detectors on the client for this player
				ClearClickDetectors:FireClient(player, currentFoodLists[player])
			end

			for _, p in pairs(game.players) do
				StopTimer:FireClient(p)
			end

			-- Transition each player's camera to the overview position for the main game phase
			for _, player in pairs(game.players) do
				ShowInitCamView:FireClient(player, gameTable:GetTableCameraCFrame())
			end
		end,

		-- The active player clicks one of their own remaining food pieces
		onTurnStart = function(game, _turnNumber)
			local chairNumber = game.currentPlayerIndex
			local player = game.players[chairNumber]
			ShowInitCamView:FireClient(player, gameTable:GetPlayerTableCFrame(chairNumber))

			for _, p in pairs(game.players) do
				StartTimer:FireClient(p, game.turnTimeLimit, player.Name .. "'s turn")
			end

			local ownFoods = (chairNumber == 1) and playerOneFoods or playerTwoFoods
			local ownRevealed = (chairNumber == 1) and revealedP1 or revealedP2
			local remaining = getRemainingFoods(ownFoods, ownRevealed)

			if #remaining == 0 then
				-- No food left; auto-submit so the turn doesn't block
				task.spawn(function() game:SubmitChoice(player, nil) end)
			else
				currentFoodLists[player] = remaining
				CreateClickDetectors:FireClient(player, remaining, gameTable.id, "select", 1)
			end
		end,

		onTurnEnd = function(game, choices)
			local chairNumber = game.currentPlayerIndex
			local player = game.players[chairNumber]
			local foodIndex = choices[player]

			for _, p in pairs(game.players) do
				StopTimer:FireClient(p)
			end

			if foodIndex and foodIndex ~= "forfeit" then
				local food = currentFoodLists[player] and currentFoodLists[player][foodIndex]
				if food then
					local ownRevealed = (chairNumber == 1) and revealedP1 or revealedP2
					ownRevealed[food] = true

					if bombedParts[food] then
						hearts[player] -= 1
						print(player.Name .. " hit a bomb! Hearts: " .. hearts[player] .. "/" .. MAX_HEARTS)
						food:Destroy()
						if hearts[player] <= 0 then
							ShowInitCamView:FireClient(player, gameTable:GetTableCameraCFrame())
							local opponentChair = (chairNumber == 1) and 2 or 1
							game:EndGame(game.players[opponentChair])
							return
						end
					else
						print(player.Name .. " is safe!")
						food:Destroy()
					end
				end
			end

			ShowInitCamView:FireClient(player, gameTable:GetTableCameraCFrame())

			-- Check if all foods on both sides have been picked; compare hearts for final result
			local p1 = game.players[1]
			local p2 = game.players[2]
			local p1Remaining = getRemainingFoods(playerOneFoods, revealedP1)
			local p2Remaining = getRemainingFoods(playerTwoFoods, revealedP2)
			if #p1Remaining == 0 and #p2Remaining == 0 then
				if hearts[p1] > hearts[p2] then
					game:EndGame(p1)
				elseif hearts[p2] > hearts[p1] then
					game:EndGame(p2)
				else
					game:EndGame(nil)  -- draw
				end
				return
			end

			game:NextTurn()
		end,

		onGameEnd = function(game, winner)
			if winner then
				print(winner.Name .. " wins!")
			else
				print("Draw!")
			end

			for _, food in ipairs(playerOneFoods) do
				if food.Parent then food:Destroy() end
			end
			for _, food in ipairs(playerTwoFoods) do
				if food.Parent then food:Destroy() end
			end

			for _, player in pairs(game.players) do
				player:SetAttribute("CurrentTableId", nil)
			end

			gameTable.activeGame = nil
		end,
	}

	local game = TurnBasedGame.new(gameTable, config)
	gameTable.activeGame = game
	return game
end

return FoodClickGame
