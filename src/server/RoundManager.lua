local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local RoundState = {
    LOBBY   = "Lobby",
    HIDING  = "Hiding",
    SEEKING = "Seeking",
    RESULTS = "Results",
}

local _state        = RoundState.LOBBY
local _seekers      = {}  -- [Player] = true
local _hiders       = {}  -- [Player] = true
local _activeHiders = {}  -- subset of hiders still hiding

local RoundManager = {}
RoundManager.State = RoundState

function RoundManager.getState()        return _state                     end
function RoundManager.getSeekers()      return _seekers                   end
function RoundManager.isSeeker(p)       return _seekers[p] == true        end
function RoundManager.isHider(p)        return _hiders[p]  == true        end
function RoundManager.isActiveHider(p)  return _activeHiders[p] == true   end
function RoundManager.isSeeking()       return _state == RoundState.SEEKING end
function RoundManager.setState(s)       _state = s                        end

function RoundManager.activeHiderCount()
    local n = 0
    for _ in pairs(_activeHiders) do n += 1 end
    return n
end

function RoundManager.assignRoles()
    _seekers, _hiders, _activeHiders = {}, {}, {}

    local all = Players:GetPlayers()
    -- Fisher-Yates shuffle so roles are random each round
    for i = #all, 2, -1 do
        local j = math.random(i)
        all[i], all[j] = all[j], all[i]
    end

    local numSeekers = math.max(1, math.floor(#all * GameConfig.SEEKER_RATIO))
    for i, p in ipairs(all) do
        if i <= numSeekers then
            _seekers[p] = true
            p:SetAttribute("Role", "Seeker")
        else
            _hiders[p]       = true
            _activeHiders[p] = true
            p:SetAttribute("Role", "Hider")
        end
    end
end

function RoundManager.resetCharacters()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if not char then continue end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Color        = Color3.new(1, 1, 1)
                part.Material     = Enum.Material.SmoothPlastic
                part.Transparency = 0
            end
        end
    end
end

-- Freezes and ghosts a hider when found. Returns false if already found.
function RoundManager.markFound(hider)
    if not _activeHiders[hider] then return false end
    _activeHiders[hider] = nil

    local char = hider.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed  = 0
            hum.JumpHeight = 0
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.6
            end
        end
    end
    return true
end

return RoundManager
