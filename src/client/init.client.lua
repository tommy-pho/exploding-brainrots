local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowLeaveFrame = ReplicatedStorage:WaitForChild("ShowLeaveFrame")


local Players = game:GetService("Players")
local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("Gui"):WaitForChild("ScreenGui") 
local leaveFrame = screenGui:WaitForChild("LeaveFrame")
local leaveButton = leaveFrame:WaitForChild("TextButton")
leaveFrame.Visible = false

leaveButton.Activated:Connect(function()
    leaveFrame.Visible = false
    ShowLeaveFrame:FireServer()
end)

ShowLeaveFrame.OnClientEvent:Connect(function()
    leaveFrame.Visible = true
end)