local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared       = ReplicatedStorage:WaitForChild("Shared", 10)
local GameConfig   = require(Shared:WaitForChild("GameConfig"))
local Remotes      = require(Shared:WaitForChild("RemoteEvents"))
local RoundManager = require(script.Parent:WaitForChild("RoundManager"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local MapRefs    = MapBuilder.build()

local function broadcast(state, data)
    RoundManager.setState(state)
    Remotes.RoundStateChanged:FireAllClients(state, data or {})
end

local function teleportTo(player, cframe)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = cframe end
end

local function setFrozen(player, frozen)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed  = frozen and 0 or 16
        hum.JumpHeight = frozen and 0 or 7.2
    end
end

-- Wire up touch-tag detection for a seeker's character
local function connectSeekerTouch(seeker)
    local char = seeker.Character
    if not char then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    hrp.Touched:Connect(function(hit)
        if not RoundManager.isSeeking() then return end
        local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        if not hitPlayer then return end
        if not RoundManager.isActiveHider(hitPlayer) then return end

        if RoundManager.markFound(hitPlayer) then
            Remotes.HiderFound:FireAllClients(hitPlayer.Name)
        end
    end)
end

-- Re-wire seekers when they respawn mid-round
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if RoundManager.isSeeker(player) then
            connectSeekerTouch(player)
        end
    end)
end)

-- Server validates and applies paint from hiders
Remotes.PaintCharacter.OnServerEvent:Connect(function(player, color)
    if not RoundManager.isActiveHider(player) then return end
    if typeof(color) ~= "Color3" then return end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Color = color
        end
    end
end)

-- LOBBY — hold until enough players, then count down
local function runLobby()
    broadcast(RoundManager.State.LOBBY, { waiting = true })
    while true do
        local count  = #Players:GetPlayers()
        local needed = GameConfig.MIN_PLAYERS - count
        if needed > 0 then
            broadcast(RoundManager.State.LOBBY, { waiting = true, needed = needed })
            task.wait(1)
            continue
        end
        break
    end

    for t = GameConfig.LOBBY_COUNTDOWN, 1, -1 do
        broadcast(RoundManager.State.LOBBY, { countdown = t })
        task.wait(1)
    end
end

-- HIDE PHASE — roles assigned; hiders have time to paint and hide
local function runHidePhase()
    RoundManager.assignRoles()
    RoundManager.resetCharacters()

    -- Scatter hiders in a ring around the center spawn
    local hiders = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if RoundManager.isHider(p) then table.insert(hiders, p) end
    end
    for i, hider in ipairs(hiders) do
        local angle = (i / math.max(#hiders, 1)) * math.pi * 2
        local r = MapRefs.hiderRingRadius
        teleportTo(hider, MapRefs.hiderSpawnCFrame
            * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r))
        setFrozen(hider, false)
    end

    -- Confine seekers to the glass pen, frozen
    local slots = MapRefs.seekerPenCFrames
    local si = 0
    for seeker in pairs(RoundManager.getSeekers()) do
        si += 1
        teleportTo(seeker, slots[((si - 1) % #slots) + 1])
        setFrozen(seeker, true)
    end

    broadcast(RoundManager.State.HIDING, { duration = GameConfig.HIDE_DURATION })

    for seeker in pairs(RoundManager.getSeekers()) do
        connectSeekerTouch(seeker)
    end

    for t = GameConfig.HIDE_DURATION, 1, -1 do
        broadcast(RoundManager.State.HIDING, { timeLeft = t, duration = GameConfig.HIDE_DURATION })
        task.wait(1)
    end
end

-- SEEK PHASE — seekers hunt; ends on all-found or timeout
local function runSeekPhase()
    broadcast(RoundManager.State.SEEKING, { duration = GameConfig.SEEK_DURATION })

    -- Release seekers from the pen, spread in a ring so they don't pile up
    local releasing = {}
    for seeker in pairs(RoundManager.getSeekers()) do
        table.insert(releasing, seeker)
    end
    for i, seeker in ipairs(releasing) do
        local angle = (i / math.max(#releasing, 1)) * math.pi * 2
        local r = 6
        teleportTo(seeker, MapRefs.seekerReleaseCFrame
            * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r))
        setFrozen(seeker, false)
    end

    local winner
    for t = GameConfig.SEEK_DURATION, 1, -1 do
        local hidersLeft = RoundManager.activeHiderCount()
        if hidersLeft == 0 then
            winner = "Seekers"
            break
        end

        for seeker in pairs(RoundManager.getSeekers()) do
            if seeker and seeker.Parent then
                Remotes.UpdateSeekerHUD:FireClient(seeker, {
                    timeLeft   = t,
                    hidersLeft = hidersLeft,
                })
            end
        end
        task.wait(1)
    end

    broadcast(RoundManager.State.RESULTS, { winner = winner or "Hiders" })
    task.wait(GameConfig.RESULTS_DURATION)
end

-- Game loop
task.spawn(function()
    while true do
        runLobby()
        runHidePhase()
        runSeekPhase()
    end
end)
