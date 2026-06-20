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
    RELEASE_OFFSET_Z  = 20,   -- seekers released this far -Z of arena center
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
