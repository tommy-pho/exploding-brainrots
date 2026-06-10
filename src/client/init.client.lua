-- Remote Events --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowLeaveFrame = ReplicatedStorage:WaitForChild("ShowLeaveFrame")
local ShowInitCamView = ReplicatedStorage:WaitForChild("ShowInitCamView")
local CreateClickDetectors = ReplicatedStorage:WaitForChild("CreateClickDetectors")
local SelectFoods = ReplicatedStorage:WaitForChild("SelectFoods")
local PlaceBomb = ReplicatedStorage:WaitForChild("PlaceBomb")
local StartTimer = ReplicatedStorage:WaitForChild("StartTimer")
local StopTimer = ReplicatedStorage:WaitForChild("StopTimer")
local ClearClickDetectors = ReplicatedStorage:WaitForChild("ClearClickDetectors")
local MarkBombs = ReplicatedStorage:WaitForChild("MarkBombs")
local ResetCamera = ReplicatedStorage:WaitForChild("ResetCamera")

-- Services --
local TweenService = game:GetService("TweenService")

-- Player and Camera --
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera

-- UI Elements --
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("Gui"):WaitForChild("ScreenGui")
local leaveFrame = screenGui:WaitForChild("LeaveFrame")
local leaveButton = leaveFrame:WaitForChild("TextButton")
leaveFrame.Visible = false

-- Timer UI (created dynamically so no Studio setup needed) --
local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.new(0, 220, 0, 70)
timerFrame.Position = UDim2.new(0.5, -110, 0, 16)
timerFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
timerFrame.BackgroundTransparency = 0.45
timerFrame.BorderSizePixel = 0
timerFrame.Visible = false
timerFrame.Parent = screenGui

local timerPhaseLabel = Instance.new("TextLabel")
timerPhaseLabel.Size = UDim2.new(1, 0, 0.5, 0)
timerPhaseLabel.Position = UDim2.new(0, 0, 0, 0)
timerPhaseLabel.BackgroundTransparency = 1
timerPhaseLabel.TextColor3 = Color3.new(1, 1, 1)
timerPhaseLabel.TextScaled = true
timerPhaseLabel.TextStrokeTransparency = 0
timerPhaseLabel.FontFace = Font.fromName("FredokaOne", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
timerPhaseLabel.Parent = timerFrame

local timerCountLabel = Instance.new("TextLabel")
timerCountLabel.Size = UDim2.new(1, 0, 0.5, 0)
timerCountLabel.Position = UDim2.new(0, 0, 0.5, 0)
timerCountLabel.BackgroundTransparency = 1
timerCountLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
timerCountLabel.TextScaled = true
timerCountLabel.TextStrokeTransparency = 0
timerCountLabel.FontFace = Font.fromName("FredokaOne", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
timerCountLabel.Parent = timerFrame

-- On respawn, reset camera --
player.CharacterAdded:Connect(function(character)
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
end)

leaveButton.Activated:Connect(function()
	leaveFrame.Visible = false
	ShowLeaveFrame:FireServer()
    camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
end)

ShowLeaveFrame.OnClientEvent:Connect(function(bool)
	leaveFrame.Visible = bool
end)

ResetCamera.OnClientEvent:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom
	end
end)

ShowInitCamView.OnClientEvent:Connect(function(camCFrame)
	camera.CameraType = Enum.CameraType.Scriptable
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {CFrame = camCFrame})
	tween:Play()
end)

-- Timer: server fires StartTimer(duration, label) at the start of each phase,
-- and StopTimer() when it ends early (e.g. all players submitted before timeout).
local timerTask = nil

StartTimer.OnClientEvent:Connect(function(duration, label)
	if timerTask then task.cancel(timerTask) end
	timerFrame.Visible = true
	timerPhaseLabel.Text = label
	local endTime = tick() + duration
	timerTask = task.spawn(function()
		while tick() < endTime do
			timerCountLabel.Text = tostring(math.max(0, math.ceil(endTime - tick())))
			task.wait(0.1)
		end
		timerCountLabel.Text = "0"
		timerTask = nil
	end)
end)

StopTimer.OnClientEvent:Connect(function()
	if timerTask then task.cancel(timerTask) end
	timerTask = nil
	timerFrame.Visible = false
end)

ClearClickDetectors.OnClientEvent:Connect(function(foods)
	for _, food in ipairs(foods) do
		local cd = food:FindFirstChild("ClickDetector")
		if cd then cd:Destroy() end
	end
end)

MarkBombs.OnClientEvent:Connect(function(foods)
	for _, food in ipairs(foods) do
		food.Color = Color3.fromRGB(220, 50, 50)
	end
end)

-- foods: Part[], tableId: string, mode: "bomb"|"select", limit: number
-- "bomb"   → player clicks up to `limit` foods to plant bombs; each clicked food turns red
-- "select" → player clicks one of their own foods; fires once then removes all detectors
CreateClickDetectors.OnClientEvent:Connect(function(foods, tableId, mode, limit)
	-- Cleanup any leftover detectors from a previous phase
	for _, food in ipairs(foods) do
		local old = food:FindFirstChild("ClickDetector")
		if old then old:Destroy() end
	end

	local placed = 0

	for i, food in ipairs(foods) do
		local cd = Instance.new("ClickDetector")
		cd.Parent = food

		cd.MouseClick:Connect(function()
			if mode == "bomb" then
				if placed >= limit then return end
				placed += 1
				food.Color = Color3.fromRGB(220, 50, 50)  -- tint red to show bomb placed
				cd:Destroy()
				PlaceBomb:FireServer(tableId, i)
				-- Once all bombs are placed, clear any remaining detectors
				if placed >= limit then
					for _, f in ipairs(foods) do
						local leftover = f:FindFirstChild("ClickDetector")
						if leftover then leftover:Destroy() end
					end
				end

			elseif mode == "select" then
				SelectFoods:FireServer(tableId, i)
				-- Remove all detectors so the player can't click again
				for _, f in ipairs(foods) do
					local leftover = f:FindFirstChild("ClickDetector")
					if leftover then leftover:Destroy() end
				end
			end
		end)
	end
end)
