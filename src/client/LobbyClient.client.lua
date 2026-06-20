local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local Shared    = ReplicatedStorage:WaitForChild("Shared", 10)
local Remotes   = require(Shared:WaitForChild("RemoteEvents"))
local playerGui = player:WaitForChild("PlayerGui")

local lobbyScreen, statusLabel

local function buildLobbyUI()
    local old = playerGui:FindFirstChild("LobbyUI")
    if old then old:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name         = "LobbyUI"
    screen.ResetOnSpawn = false
    screen.Enabled      = true
    screen.Parent       = playerGui

    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.new(0, 340, 0, 110)
    frame.Position               = UDim2.new(0.5, -170, 0.5, -55)
    frame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel        = 0
    frame.Parent                 = screen

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent       = frame

    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, 0, 0.45, 0)
    title.Position               = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text                   = "CHAMELEON"
    title.TextColor3             = Color3.fromRGB(80, 220, 100)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Parent                 = frame

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size                   = UDim2.new(1, 0, 0.55, 0)
    statusLabel.Position               = UDim2.new(0, 0, 0.45, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text                   = "Waiting for players..."
    statusLabel.TextColor3             = Color3.new(1, 1, 1)
    statusLabel.TextScaled             = true
    statusLabel.Font                   = Enum.Font.Gotham
    statusLabel.Parent                 = frame

    return screen
end

lobbyScreen = buildLobbyUI()

-- Flash a full-screen banner when the round starts showing the player their role
local function showRoleFlash(role)
    local flash = Instance.new("ScreenGui")
    flash.Name         = "RoleFlash"
    flash.ResetOnSpawn = false
    flash.Parent       = playerGui

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3       = role == "Seeker"
        and Color3.fromRGB(200, 50, 50)
        or  Color3.fromRGB(50, 120, 200)
    bg.BackgroundTransparency = 0.4
    bg.BorderSizePixel        = 0
    bg.Parent                 = flash

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "You are a " .. role .. "!"
    lbl.TextColor3             = Color3.new(1, 1, 1)
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = bg

    task.delay(3, function()
        if flash and flash.Parent then flash:Destroy() end
    end)
end

Remotes.RoundStateChanged.OnClientEvent:Connect(function(state, data)
    if state == "Lobby" then
        lobbyScreen.Enabled = true
        if data and data.waiting then
            local n = data.needed or 1
            statusLabel.Text = "Waiting for " .. n .. " more player" .. (n == 1 and "" or "s") .. "..."
        elseif data and data.countdown then
            statusLabel.Text = "Starting in " .. data.countdown .. "s..."
        end

    elseif state == "Hiding" then
        lobbyScreen.Enabled = false
        showRoleFlash(player:GetAttribute("Role") or "Hider")

    elseif state == "Seeking" then
        lobbyScreen.Enabled = false

    elseif state == "Results" then
        lobbyScreen.Enabled = true
        if data and data.winner then
            local role   = player:GetAttribute("Role") or ""
            local youWon = (data.winner == "Seekers" and role == "Seeker")
                        or (data.winner == "Hiders"  and role == "Hider")
            statusLabel.Text = data.winner .. " win! "
                .. (youWon and "You won!" or "Better luck next time.")
        end
    end
end)
