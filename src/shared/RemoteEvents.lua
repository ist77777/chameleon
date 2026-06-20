local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local isServer = RunService:IsServer()

local function getFolder()
    if isServer then
        return ReplicatedStorage:FindFirstChild("Remotes") or (function()
            local f = Instance.new("Folder")
            f.Name   = "Remotes"
            f.Parent = ReplicatedStorage
            return f
        end)()
    else
        return ReplicatedStorage:WaitForChild("Remotes", 30)
    end
end

local function getRemote(parent, className, name)
    if isServer then
        return parent:FindFirstChild(name) or (function()
            local r = Instance.new(className)
            r.Name   = name
            r.Parent = parent
            return r
        end)()
    else
        return parent:WaitForChild(name, 30)
    end
end

local folder = getFolder()

return {
    PaintCharacter    = getRemote(folder, "RemoteEvent", "PaintCharacter"),    -- Hider  -> Server
    RoundStateChanged = getRemote(folder, "RemoteEvent", "RoundStateChanged"), -- Server -> All
    HiderFound        = getRemote(folder, "RemoteEvent", "HiderFound"),        -- Server -> All
    UpdateSeekerHUD   = getRemote(folder, "RemoteEvent", "UpdateSeekerHUD"),   -- Server -> Seeker only
}
