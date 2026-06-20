-- Procedurally builds the Chameleon arena on the server at startup.
-- Pure construction: identical MapConfig in => identical geometry out.
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")
)

local MAP_FOLDER_NAME = "ChameleonMap"
local FLOOR_TOP_Y     = 0  -- floor top surface sits at y = 0

local MapBuilder = {}

-- Deterministic [0,1) from two integers. Pure arithmetic LCG, no global state,
-- so prop layout is identical on every server boot.
local function rand01(seed, i)
    local n = (seed + i * 2654435761) % 2147483647
    n = (n * 1103515245 + 12345) % 2147483648
    return n / 2147483648
end

local function newPart(name, size, position, color, parent, material, shape)
    local p = Instance.new("Part")
    p.Name          = name
    p.Anchored      = true
    p.Size          = size
    p.Position      = position
    p.Color         = color
    p.Material      = material or Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if shape then p.Shape = shape end
    p.Parent        = parent
    return p
end

-- Prop builders: each places one anchored assembly centered on (x, z) with its
-- base at FLOOR_TOP_Y. `color` is the zone color chosen for this prop.
local PROP_BUILDERS = {
    tree = function(x, z, color, parent)
        newPart("Trunk", Vector3.new(2, 10, 2), Vector3.new(x, FLOOR_TOP_Y + 5, z),
            Color3.fromRGB(139, 90, 43), parent, Enum.Material.Wood)
        newPart("Canopy", Vector3.new(10, 10, 10), Vector3.new(x, FLOOR_TOP_Y + 13, z),
            color, parent, Enum.Material.Grass, Enum.PartType.Ball)
    end,
    bush = function(x, z, color, parent)
        newPart("Bush", Vector3.new(8, 4, 8), Vector3.new(x, FLOOR_TOP_Y + 2, z),
            color, parent, Enum.Material.Grass, Enum.PartType.Ball)
    end,
    boulder = function(x, z, color, parent)
        newPart("Boulder", Vector3.new(7, 6, 7), Vector3.new(x, FLOOR_TOP_Y + 3, z),
            color, parent, Enum.Material.Slate, Enum.PartType.Ball)
    end,
    pillar = function(x, z, color, parent)
        newPart("Pillar", Vector3.new(4, 16, 4), Vector3.new(x, FLOOR_TOP_Y + 8, z),
            color, parent, Enum.Material.Concrete)
    end,
    dune = function(x, z, color, parent)
        newPart("Dune", Vector3.new(14, 4, 14), Vector3.new(x, FLOOR_TOP_Y + 2, z),
            color, parent, Enum.Material.Sand, Enum.PartType.Ball)
    end,
    mound = function(x, z, color, parent)
        newPart("Mound", Vector3.new(12, 5, 12), Vector3.new(x, FLOOR_TOP_Y + 2.5, z),
            color, parent, Enum.Material.Snow, Enum.PartType.Ball)
    end,
    iceblock = function(x, z, color, parent)
        local p = newPart("IceBlock", Vector3.new(6, 6, 6),
            Vector3.new(x, FLOOR_TOP_Y + 3, z), color, parent, Enum.Material.Glass)
        p.Transparency = 0.3
    end,
}

local function clearOldGeometry()
    local existing = Workspace:FindFirstChild(MAP_FOLDER_NAME)
    if existing then existing:Destroy() end
    local baseplate = Workspace:FindFirstChild("Baseplate")
    if baseplate then baseplate:Destroy() end
end

local function buildFloorAndWalls(folder)
    local size = MapConfig.ARENA_SIZE
    local ft   = MapConfig.FLOOR_THICK
    -- Base floor (its top at FLOOR_TOP_Y)
    newPart("ArenaFloor", Vector3.new(size, ft, size),
        Vector3.new(0, FLOOR_TOP_Y - ft / 2, 0),
        Color3.fromRGB(60, 60, 60), folder, Enum.Material.SmoothPlastic)

    -- Zone floors laid on top of the base floor
    for _, zone in ipairs(MapConfig.ZONES) do
        local zs = MapConfig.ZONE_SIZE
        newPart(zone.name .. "Floor", Vector3.new(zs, ft, zs),
            Vector3.new(zone.offset[1], FLOOR_TOP_Y + ft / 2, zone.offset[2]),
            zone.floorColor, folder, Enum.Material.SmoothPlastic)
    end

    -- Perimeter walls
    local h, wt = MapConfig.WALL_HEIGHT, MapConfig.WALL_THICK
    local half  = size / 2
    local wy    = FLOOR_TOP_Y + h / 2
    local walls = {
        { Vector3.new(size, h, wt), Vector3.new(0,  wy,  half) },
        { Vector3.new(size, h, wt), Vector3.new(0,  wy, -half) },
        { Vector3.new(wt, h, size), Vector3.new( half, wy, 0) },
        { Vector3.new(wt, h, size), Vector3.new(-half, wy, 0) },
    }
    for i, w in ipairs(walls) do
        newPart("Wall" .. i, w[1], w[2], Color3.fromRGB(90, 90, 90),
            folder, Enum.Material.SmoothPlastic)
    end
end

local function buildProps(folder)
    local seed  = MapConfig.SCATTER_SEED
    local inset = MapConfig.PROP_INSET
    local half  = MapConfig.ZONE_SIZE / 2 - inset
    local idx   = 0
    for _, zone in ipairs(MapConfig.ZONES) do
        local cx, cz = zone.offset[1], zone.offset[2]
        for i = 1, MapConfig.PROPS_PER_ZONE do
            idx += 1
            local kind  = zone.propKinds[((i - 1) % #zone.propKinds) + 1]
            local color = zone.propColors[((i - 1) % #zone.propColors) + 1]
            local x = cx + (rand01(seed, idx * 2) * 2 - 1) * half
            local z = cz + (rand01(seed, idx * 2 + 1) * 2 - 1) * half
            PROP_BUILDERS[kind](x, z, color, folder)
        end
    end
end

local function buildCenterSpawn(folder)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name        = "CenterSpawn"
    spawn.Anchored    = true
    spawn.Size        = Vector3.new(12, 1, 12)
    spawn.Position    = Vector3.new(0, FLOOR_TOP_Y + 0.5, 0)
    spawn.Color       = Color3.fromRGB(255, 255, 255)
    spawn.Material    = Enum.Material.Neon
    spawn.Neutral     = true
    spawn.Enabled     = true
    spawn.Duration    = 0
    spawn.Parent      = folder
end

-- Returns { CFrame } of length PEN_SLOTS, plus builds the glass pen.
local function buildSeekerPen(folder)
    local s   = MapConfig.PEN_SIZE
    local cz  = -MapConfig.PEN_OFFSET_Z
    -- Pen walls are half the arena wall height (visually distinct holding box)
    local h   = MapConfig.WALL_HEIGHT / 2
    local wt  = MapConfig.WALL_THICK
    local half = s / 2

    -- Pen floor
    newPart("PenFloor", Vector3.new(s, MapConfig.FLOOR_THICK, s),
        Vector3.new(0, FLOOR_TOP_Y - MapConfig.FLOOR_THICK / 2, cz),
        Color3.fromRGB(120, 120, 120), folder, Enum.Material.SmoothPlastic)

    -- Glass walls (solid but see-through) + invisible roof
    local wy = FLOOR_TOP_Y + h / 2
    local penWalls = {
        { Vector3.new(s, h, wt), Vector3.new(0, wy, cz + half) },
        { Vector3.new(s, h, wt), Vector3.new(0, wy, cz - half) },
        { Vector3.new(wt, h, s), Vector3.new( half, wy, cz) },
        { Vector3.new(wt, h, s), Vector3.new(-half, wy, cz) },
    }
    for i, w in ipairs(penWalls) do
        local p = newPart("PenWall" .. i, w[1], w[2],
            Color3.fromRGB(200, 230, 255), folder, Enum.Material.Glass)
        p.Transparency = 0.5
    end
    local roof = newPart("PenRoof", Vector3.new(s, wt, s),
        Vector3.new(0, FLOOR_TOP_Y + h, cz), Color3.fromRGB(200, 230, 255),
        folder, Enum.Material.Glass)
    roof.Transparency = 1
    roof.CanCollide   = true

    -- Slot CFrames in a grid inside the pen
    local slots = {}
    local n     = MapConfig.PEN_SLOTS
    local perRow = math.ceil(math.sqrt(n))
    local gap    = (s - 8) / math.max(perRow - 1, 1)
    local startX = -((perRow - 1) * gap) / 2
    for k = 0, n - 1 do
        local row = math.floor(k / perRow)
        local col = k % perRow
        local x = startX + col * gap
        local z = cz + startX + row * gap
        table.insert(slots, CFrame.new(x, FLOOR_TOP_Y + 3, z))
    end
    return slots
end

function MapBuilder.build()
    clearOldGeometry()

    -- Neutral daytime light so paint colors read true.
    Lighting.ClockTime  = 14
    Lighting.Brightness = 2

    local folder = Instance.new("Folder")
    folder.Name   = MAP_FOLDER_NAME
    folder.Parent = Workspace

    buildFloorAndWalls(folder)
    buildProps(folder)
    buildCenterSpawn(folder)
    local penSlots = buildSeekerPen(folder)

    return {
        hiderSpawnCFrame    = CFrame.new(0, FLOOR_TOP_Y + 3, 0),
        seekerPenCFrames    = penSlots,
        seekerReleaseCFrame = CFrame.new(0, FLOOR_TOP_Y + 3, -MapConfig.RELEASE_OFFSET_Z),
        hiderRingRadius     = MapConfig.HIDER_RING_RADIUS,
        seekerReleaseRadius = MapConfig.SEEKER_RELEASE_RING_RADIUS,
    }
end

return MapBuilder
