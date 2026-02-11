-- Remote Events --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowLeaveFrame = ReplicatedStorage:WaitForChild("ShowLeaveFrame")
local ShowInitCamView = ReplicatedStorage:WaitForChild("ShowInitCamView")

-- Services --
local TweenService = game:GetService("TweenService")

-- Player and Camera --
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera

-- Ui Elements --
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("Gui"):WaitForChild("ScreenGui") 
local leaveFrame = screenGui:WaitForChild("LeaveFrame")
local leaveButton = leaveFrame:WaitForChild("TextButton")
leaveFrame.Visible = false

leaveButton.Activated:Connect(function()
    leaveFrame.Visible = false
    ShowLeaveFrame:FireServer()
    camera.CameraType = Enum.CameraType.Custom
end)

ShowLeaveFrame.OnClientEvent:Connect(function(bool)
    leaveFrame.Visible = bool
end)

ShowInitCamView.OnClientEvent:Connect(function(camCFrame)
    camera.CameraType = Enum.CameraType.Scriptable
    
    local tweenInfo = TweenInfo.new(
        1.5,  -- Duration
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(camera, tweenInfo, {CFrame = camCFrame})
    tween:Play()
    
    tween.Completed:Connect(function()
        ShowInitCamView:FireServer("CameraReady")
    end)
end)