local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local Shared    = ReplicatedStorage:WaitForChild("Shared", 10)
local Remotes   = require(Shared:WaitForChild("RemoteEvents"))
local playerGui = player:WaitForChild("PlayerGui")

local currentState = "Lobby"
local hudScreen, timerLabel, countLabel

local function buildHUD()
    local old = playerGui:FindFirstChild("SeekerUI")
    if old then old:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name         = "SeekerUI"
    screen.ResetOnSpawn = false
    screen.Enabled      = false
    screen.Parent       = playerGui

    -- Timer chip
    local timerFrame = Instance.new("Frame")
    timerFrame.Size                   = UDim2.new(0, 180, 0, 48)
    timerFrame.Position               = UDim2.new(0.5, -90, 0, 14)
    timerFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    timerFrame.BackgroundTransparency = 0.25
    timerFrame.BorderSizePixel        = 0
    timerFrame.Parent                 = screen

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 10)
    tc.Parent       = timerFrame

    timerLabel = Instance.new("TextLabel")
    timerLabel.Size                   = UDim2.new(1, 0, 1, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text                   = "2:00"
    timerLabel.TextColor3             = Color3.new(1, 1, 1)
    timerLabel.TextScaled             = true
    timerLabel.Font                   = Enum.Font.GothamBold
    timerLabel.Parent                 = timerFrame

    -- Hiders-remaining chip
    local countFrame = Instance.new("Frame")
    countFrame.Name                   = "CountFrame"
    countFrame.Size                   = UDim2.new(0, 180, 0, 38)
    countFrame.Position               = UDim2.new(0.5, -90, 0, 70)
    countFrame.BackgroundColor3       = Color3.fromRGB(200, 50, 50)
    countFrame.BackgroundTransparency = 0.2
    countFrame.BorderSizePixel        = 0
    countFrame.Parent                 = screen

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 10)
    cc.Parent       = countFrame

    countLabel = Instance.new("TextLabel")
    countLabel.Size                   = UDim2.new(1, 0, 1, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text                   = "Hiders: ?"
    countLabel.TextColor3             = Color3.new(1, 1, 1)
    countLabel.TextScaled             = true
    countLabel.Font                   = Enum.Font.Gotham
    countLabel.Parent                 = countFrame

    return screen
end

hudScreen = buildHUD()

local function updateHUDVisibility()
    hudScreen.Enabled = currentState == "Seeking"
        and player:GetAttribute("Role") == "Seeker"
end

Remotes.RoundStateChanged.OnClientEvent:Connect(function(state)
    currentState = state
    updateHUDVisibility()
end)

player:GetAttributeChangedSignal("Role"):Connect(function()
    updateHUDVisibility()
end)

Remotes.UpdateSeekerHUD.OnClientEvent:Connect(function(data)
    if not data then return end

    local t    = data.timeLeft or 0
    local mins = math.floor(t / 60)
    local secs = t % 60
    timerLabel.Text = string.format("%d:%02d", mins, secs)

    local left = data.hidersLeft or 0
    countLabel.Text = left == 1 and "1 Hider Left" or (left .. " Hiders Left")

    -- Colour shifts to orange when only 1 hider remains
    local countFrame = countLabel.Parent
    countFrame.BackgroundColor3 = left <= 1
        and Color3.fromRGB(220, 140, 20)
        or  Color3.fromRGB(200, 50,  50)
end)

-- Toast notification when a hider is caught
Remotes.HiderFound.OnClientEvent:Connect(function(hiderName)
    local toast = Instance.new("Frame")
    toast.Size                   = UDim2.new(0, 280, 0, 44)
    toast.Position               = UDim2.new(0.5, -140, 0.85, 0)
    toast.BackgroundColor3       = Color3.fromRGB(30, 160, 40)
    toast.BackgroundTransparency = 0.15
    toast.BorderSizePixel        = 0
    toast.Parent                 = hudScreen

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 8)
    tc.Parent       = toast

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = hiderName .. " was found!"
    lbl.TextColor3             = Color3.new(1, 1, 1)
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = toast

    task.delay(3, function()
        if toast and toast.Parent then toast:Destroy() end
    end)
end)
