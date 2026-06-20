local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared       = ReplicatedStorage:WaitForChild("Shared", 10)
local GameConfig   = require(Shared:WaitForChild("GameConfig"))
local Remotes      = require(Shared:WaitForChild("RemoteEvents"))
local RoundManager = require(script.Parent:WaitForChild("RoundManager"))

local function broadcast(state, data)
    RoundManager.setState(state)
    Remotes.RoundStateChanged:FireAllClients(state, data or {})
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
