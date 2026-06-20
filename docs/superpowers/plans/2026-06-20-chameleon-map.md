# Chameleon Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a procedurally-built, palette-themed arena map (Forest/Stone/Sand/Snow) with a central hider spawn and a glass seeker pen to the Chameleon game.

**Architecture:** A data-only `MapConfig` ModuleScript describes the arena; a `MapBuilder` ModuleScript constructs all geometry on server boot and returns spawn references; `Main.server.lua` builds the map before the round loop and teleports players per phase. Geometry is deterministic (fixed seed, no `math.random`), so every server produces an identical map.

**Tech Stack:** Roblox Luau, Rojo 7.6.1 (already installed and serving on `localhost:34872`).

## Testing note (read first)

This project has **no Lua/Luau runtime and no test framework**, and the map code depends on Roblox-only globals (`Instance`, `Color3`, `Vector3`, `CFrame`, `Workspace`) that only exist in the Studio runtime. Standing up a headless mock harness would be larger and less trustworthy than the feature itself (YAGNI). Therefore the verification medium for every task is **Roblox Studio observation** against the spec's success criteria, with Command Bar (`View → Command Bar`) print/assert snippets where an exact value can be checked. This is the real test cycle for this domain, not a substitute for one.

**Standing setup for every verification step:**
1. Rojo is already serving (`rojo serve default.project.json`, port 34872). If not: `export PATH="$HOME/.rokit/bin:$PATH"; rojo serve default.project.json`.
2. In Studio: open a **Baseplate** place → Plugins → **Rojo** → **Connect**.
3. Press **Run** (F8) — not Play — for map-only checks (Run starts the server without a player so you can inspect geometry). Use **Play** (F5) when a character/teleport behavior must be observed.

## Global Constraints

- Roblox Luau only; no external dependencies beyond what `default.project.json` already maps.
- `src/server/RoundManager.lua` and all of `src/client/` MUST remain unmodified (spec: out of scope).
- All zone/prop colors MUST come from the `PAINT_COLORS` RGB values in `src/shared/GameConfig.lua` (verbatim RGB triples below).
- Geometry MUST be deterministic — no `math.random`, `tick`, `os.time`, or other nondeterministic input at build time.
- Arena: 200×200 studs, 2×2 grid of 100×100 zones, enclosed by perimeter walls.

Palette RGB values (from `GameConfig.lua`, copied verbatim):
Forest `(34,139,34)`, Brown `(139,90,43)`, Stone `(169,169,169)`, Sky `(70,130,180)`, Sand `(210,180,140)`, Dark Slate `(47,79,79)`, Brick `(178,88,50)`, Snow `(240,240,240)`, Night `(25,25,50)`, Grass `(85,170,50)`, Rust `(183,65,14)`, Ice `(176,224,230)`.

---

### Task 1: MapConfig (data-only zone definitions)

**Files:**
- Create: `src/shared/MapConfig.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: a table required by `MapBuilder` (Task 2) and read indirectly via references. Exact shape:
  - `ARENA_SIZE: number`, `ZONE_SIZE: number`, `FLOOR_THICK: number`, `WALL_HEIGHT: number`, `WALL_THICK: number`, `SCATTER_SEED: number`, `PROPS_PER_ZONE: number`, `PROP_INSET: number`, `HIDER_RING_RADIUS: number`, `PEN_SIZE: number`, `PEN_OFFSET_Z: number`, `PEN_SLOTS: number`
  - `ZONES: { { name: string, offset: {number, number}, floorColor: Color3, propColors: {Color3}, propKinds: {string} } }` where `propKinds` entries are one of: `"tree"`, `"bush"`, `"boulder"`, `"pillar"`, `"dune"`, `"mound"`, `"iceblock"`.

- [ ] **Step 1: Create the config file**

Create `src/shared/MapConfig.lua` with exactly:

```lua
-- Data-only description of the Chameleon arena. No geometry logic here.
-- Colors are taken verbatim from GameConfig.PAINT_COLORS so hiders can blend.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

return {
    ARENA_SIZE     = 200,   -- total width/depth (studs)
    ZONE_SIZE      = 100,   -- each of the four zones is ZONE_SIZE x ZONE_SIZE
    FLOOR_THICK    = 2,     -- floor sits with its TOP at y = 0
    WALL_HEIGHT    = 30,
    WALL_THICK     = 2,
    SCATTER_SEED   = 1337,  -- fixed seed => identical layout every boot
    PROPS_PER_ZONE = 12,
    PROP_INSET     = 10,    -- keep props this far inside each zone's edges

    HIDER_RING_RADIUS = 12, -- hiders scatter in a ring of this radius around center
    PEN_SIZE     = 30,      -- glass pen footprint (studs, square)
    PEN_OFFSET_Z = 130,     -- pen center sits this far -Z of arena center (outside arena)
    PEN_SLOTS    = 12,      -- max seekers held; slots laid out in a grid

    -- Zones at grid-cell centers; offset = {x, z} from arena center (0,0).
    ZONES = {
        { name = "Forest", offset = { -50,  50 }, floorColor = rgb(85, 170, 50),
          propColors = { rgb(34, 139, 34), rgb(139, 90, 43), rgb(85, 170, 50) },
          propKinds  = { "tree", "bush" } },

        { name = "Stone",  offset = {  50,  50 }, floorColor = rgb(169, 169, 169),
          propColors = { rgb(169, 169, 169), rgb(47, 79, 79) },
          propKinds  = { "boulder", "pillar" } },

        { name = "Sand",   offset = { -50, -50 }, floorColor = rgb(210, 180, 140),
          propColors = { rgb(210, 180, 140), rgb(139, 90, 43), rgb(183, 65, 14) },
          propKinds  = { "dune", "boulder" } },

        { name = "Snow",   offset = {  50, -50 }, floorColor = rgb(240, 240, 240),
          propColors = { rgb(240, 240, 240), rgb(176, 224, 230), rgb(70, 130, 180) },
          propKinds  = { "mound", "iceblock" } },
    },
}
```

- [ ] **Step 2: Verify it loads (Command Bar)**

With Rojo connected, paste into the Command Bar:

```lua
local c = require(game.ReplicatedStorage.Shared.MapConfig)
print(c.ARENA_SIZE, #c.ZONES, c.ZONES[1].name, c.ZONES[1].floorColor)
```

Expected output: `200 4 Forest 0.333333, 0.666667, 0.196078` (the Color3 components for RGB 85,170,50). If it errors, the module didn't sync — check Rojo connection.

- [ ] **Step 3: Commit**

```bash
git add src/shared/MapConfig.lua
git commit -m "Add MapConfig: data-only Chameleon arena/zone definitions"
```

---

### Task 2: MapBuilder (geometry + spawn references)

**Files:**
- Create: `src/server/MapBuilder.lua`

**Interfaces:**
- Consumes: `MapConfig` (Task 1) — all keys listed in Task 1's Produces block.
- Produces: `MapBuilder.build() -> references`, called once by `Main` (Task 3). Return shape:
  ```
  {
    hiderSpawnCFrame    : CFrame,        -- center pad, character height
    seekerPenCFrames    : { CFrame },    -- length == MapConfig.PEN_SLOTS
    seekerReleaseCFrame : CFrame,        -- release pad just inside the arena
  }
  ```
  `build()` also has the side effect of populating `Workspace` with a folder named `"ChameleonMap"` and a center `SpawnLocation`, and removing any pre-existing `Baseplate` or prior `ChameleonMap` folder.

- [ ] **Step 1: Create the builder file**

Create `src/server/MapBuilder.lua` with exactly:

```lua
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
        seekerReleaseCFrame = CFrame.new(0, FLOOR_TOP_Y + 3, -20),
    }
end

return MapBuilder
```

- [ ] **Step 2: Verify the map builds (Studio, Run mode)**

With Rojo connected, paste into the Command Bar to invoke the builder directly (it normally runs from `Main`, but this isolates Task 2):

```lua
local refs = require(game.ServerScriptService.MapBuilder).build()
print("pen slots:", #refs.seekerPenCFrames, "hider:", refs.hiderSpawnCFrame.Position)
print("ChameleonMap children:", #workspace.ChameleonMap:GetChildren())
```

Expected: `pen slots: 12 hider: 0, 3, 0` and a child count of roughly 60 (1 base floor + 4 zone floors + 4 walls + 48 props + spawn + pen floor + 4 pen walls + roof ≈ 64). Visually confirm against spec success criteria #1–#2 and #5:
- A 200×200 enclosed arena with four differently-colored zone floors (green / grey / tan / white).
- ~12 props per zone in that zone's palette colors; no default `Baseplate` remains.
- Perimeter walls on all four sides; a white neon center spawn pad; a see-through glass pen on the −Z side.

- [ ] **Step 3: Verify determinism (Command Bar)**

Run twice and compare a known prop position:

```lua
local MB = require(game.ServerScriptService.MapBuilder)
MB.build()
local function firstBoulderX()
    for _, p in ipairs(workspace.ChameleonMap:GetChildren()) do
        if p.Name == "Pillar" then return p.Position.X end
    end
end
local a = firstBoulderX()
MB.build()
local b = firstBoulderX()
print("deterministic:", a == b, a, b)
```

Expected: `deterministic: true <x> <x>` (same value both times).

- [ ] **Step 4: Commit**

```bash
git add src/server/MapBuilder.lua
git commit -m "Add MapBuilder: procedural deterministic arena + seeker pen"
```

---

### Task 3: Wire the map into the round loop

**Files:**
- Modify: `src/server/Main.server.lua`

**Interfaces:**
- Consumes: `MapBuilder.build()` (Task 2) returning `{ hiderSpawnCFrame, seekerPenCFrames, seekerReleaseCFrame }`; existing `RoundManager` accessors `getSeekers()`, `isHider(p)`.
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Require MapBuilder and build the map before the loop**

In `src/server/Main.server.lua`, after the existing require block (the lines requiring `GameConfig`, `Remotes`, `RoundManager`, currently lines 4–7), add:

```lua
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local MapRefs    = MapBuilder.build()
```

- [ ] **Step 2: Add teleport + freeze helpers**

Immediately below the `broadcast` function (currently ends at line 12), add:

```lua
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
```

- [ ] **Step 3: Place hiders and pen the seekers in the hide phase**

In `runHidePhase`, after the existing `RoundManager.assignRoles()` and `RoundManager.resetCharacters()` calls and before the `broadcast(... HIDING ...)` line, insert:

```lua
    -- Scatter hiders in a ring around the center spawn
    local hiders = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if RoundManager.isHider(p) then table.insert(hiders, p) end
    end
    for i, hider in ipairs(hiders) do
        local angle = (i / math.max(#hiders, 1)) * math.pi * 2
        local r = 12
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
```

- [ ] **Step 4: Release seekers at the start of the seek phase**

In `runSeekPhase`, immediately after the opening `broadcast(RoundManager.State.SEEKING, ...)` line, insert:

```lua
    -- Release seekers from the pen into the arena
    for seeker in pairs(RoundManager.getSeekers()) do
        setFrozen(seeker, false)
        teleportTo(seeker, MapRefs.seekerReleaseCFrame)
    end
```

- [ ] **Step 5: Verify the full round flow (Studio, Play Solo)**

With Rojo connected, press **Play** (F5). Because `MIN_PLAYERS = 2`, the lobby will wait — to test the hide/seek flow solo, temporarily set `MIN_PLAYERS = 1` in `src/shared/GameConfig.lua` (revert after). Observe against spec success criteria #3–#4:
- During **Hiding**: your character spawns at the center pad and can move/paint; if you were assigned Seeker, you are inside the glass pen and cannot move (WalkSpeed 0).
- At **Seeking** start: a penned seeker is teleported to the center release pad and can move again.
- You cannot walk out of the arena (criteria #5).

Command Bar check that the map exists during play:

```lua
print(workspace:FindFirstChild("ChameleonMap") ~= nil, workspace:FindFirstChild("Baseplate"))
```

Expected: `true nil`.

- [ ] **Step 6: Revert the temporary test change (if made)**

If you changed `MIN_PLAYERS` to 1 for solo testing, set it back to `2` in `src/shared/GameConfig.lua`. Confirm with:

```bash
git diff src/shared/GameConfig.lua
```

Expected: no output (file unchanged from committed state).

- [ ] **Step 7: Commit**

```bash
git add src/server/Main.server.lua
git commit -m "Wire map into round loop: build on boot, pen seekers, scatter hiders"
```

---

## Known limitations (acceptable for v1, per spec)

- A seeker who dies/respawns *during* the hide phase respawns at the center pad rather than back in the pen (Roblox `SpawnLocation` default). Rare; not handled in v1.
- Prop scatter can place a prop near a zone's inner corner (within ~`PROP_INSET` of center); the center spawn pad (12×12) and props rarely overlap and it is cosmetic if they do.

## Self-Review

- **Spec coverage:** Arena/zones → Tasks 1–2. Palette mapping → Task 1 `ZONES`. Procedural deterministic build → Task 2 (`rand01`, Step 3 check). Center spawn + glass pen + confinement → Tasks 2–3. Spawn flow per phase → Task 3 Steps 3–4. `RoundManager`/clients untouched → enforced by Global Constraints, no task edits them. Success criteria #1–#7 each map to a verification step. No gaps.
- **Placeholder scan:** No TBD/TODO; all code shown in full; verification steps give exact commands and expected output.
- **Type consistency:** `build()` returns `{hiderSpawnCFrame, seekerPenCFrames, seekerReleaseCFrame}` in Task 2 and is consumed with those exact names in Task 3. `MapConfig` keys used in Task 2 all exist in Task 1. `PROP_BUILDERS` keys match `propKinds` values in Task 1 (`tree, bush, boulder, pillar, dune, mound, iceblock`).
