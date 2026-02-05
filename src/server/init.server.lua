local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Creating RemoteEvents --
local ShowLeaveFrame = Instance.new("RemoteEvent")
ShowLeaveFrame.Name = "ShowLeaveFrame"
ShowLeaveFrame.Parent = ReplicatedStorage

local ShowInitCamView = Instance.new("RemoteEvent")
ShowInitCamView.Name = "ShowInitCamView"
ShowInitCamView.Parent = ReplicatedStorage


-- CallBacks for RemoteEvents --
ShowLeaveFrame.OnServerEvent:Connect(function(player)
    local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid.Sit then
        humanoid.Sit = false
        humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight 
        humanoid.JumpPower = StarterPlayer.CharacterJumpPower
    end
end)

-- Setting up Game Tables --
local GameTable = require(game.ServerScriptService:WaitForChild("Modules"):WaitForChild("GameTable"))
NUM_ROWS = 3
NUM_COLS = 5
DX = 20
DZ = 15
Start = Vector3.new(23, 1.5, 18.2)

for row = 0, NUM_ROWS - 1 do
    for col = 0, NUM_COLS - 1 do
        local position = Vector2.new(Start.X + col * DX, Start.Z + row * DZ)
        GameTable.new(position)
    end
end