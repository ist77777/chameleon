local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local Shared     = ReplicatedStorage:WaitForChild("Shared", 10)
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes    = require(Shared:WaitForChild("RemoteEvents"))
local playerGui  = player:WaitForChild("PlayerGui")

local currentState = "Lobby"
local isHiding     = false

local function updateVisibility()
    local ui = playerGui:FindFirstChild("HiderUI")
    if not ui then return end
    isHiding   = currentState == "Hiding" and player:GetAttribute("Role") == "Hider"
    ui.Enabled = isHiding
end

local function buildPaletteUI()
    local old = playerGui:FindFirstChild("HiderUI")
    if old then old:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name         = "HiderUI"
    screen.ResetOnSpawn = false
    screen.Enabled      = false
    screen.Parent       = playerGui

    local COLS    = 6
    local BTN     = 44
    local PAD     = 6
    local rows    = math.ceil(#GameConfig.PAINT_COLORS / COLS)
    local w       = COLS * (BTN + PAD) + PAD
    local h       = rows * (BTN + PAD) + PAD

    local frame = Instance.new("Frame")
    frame.Name                   = "Palette"
    frame.Size                   = UDim2.new(0, w, 0, h)
    frame.Position               = UDim2.new(0.5, -w / 2, 1, -h - 20)
    frame.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel        = 0
    frame.Parent                 = screen

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent       = frame

    local grid = Instance.new("UIGridLayout")
    grid.CellSize            = UDim2.new(0, BTN, 0, BTN)
    grid.CellPadding         = UDim2.new(0, PAD, 0, PAD)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.VerticalAlignment   = Enum.VerticalAlignment.Top
    grid.Parent              = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, PAD)
    padding.PaddingTop  = UDim.new(0, PAD)
    padding.Parent      = frame

    for _, entry in ipairs(GameConfig.PAINT_COLORS) do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, BTN, 0, BTN)
        btn.BackgroundColor3 = entry.color
        btn.Text             = ""
        btn.AutoButtonColor  = false
        btn.Parent           = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent       = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color     = Color3.new(0.8, 0.8, 0.8)
        stroke.Thickness = 2
        stroke.Parent    = btn

        btn.MouseEnter:Connect(function()
            stroke.Color     = Color3.fromRGB(255, 220, 50)
            stroke.Thickness = 3
        end)
        btn.MouseLeave:Connect(function()
            stroke.Color     = Color3.new(0.8, 0.8, 0.8)
            stroke.Thickness = 2
        end)

        btn.MouseButton1Click:Connect(function()
            if isHiding then
                Remotes.PaintCharacter:FireServer(entry.color)
            end
        end)
    end
end

buildPaletteUI()

Remotes.RoundStateChanged.OnClientEvent:Connect(function(state)
    currentState = state
    updateVisibility()
end)

player:GetAttributeChangedSignal("Role"):Connect(function()
    updateVisibility()
end)
