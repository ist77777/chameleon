return {
    MIN_PLAYERS      = 2,
    SEEKER_RATIO     = 0.25,  -- fraction of players who become seekers (min 1)
    LOBBY_COUNTDOWN  = 15,
    HIDE_DURATION    = 30,
    SEEK_DURATION    = 120,
    RESULTS_DURATION = 8,

    -- Preset colours for the hider paint palette.
    -- Add or remove entries to match your map environments.
    PAINT_COLORS = {
        { name = "Forest",     color = Color3.fromRGB(34,  139, 34)  },
        { name = "Brown",      color = Color3.fromRGB(139, 90,  43)  },
        { name = "Stone",      color = Color3.fromRGB(169, 169, 169) },
        { name = "Sky",        color = Color3.fromRGB(70,  130, 180) },
        { name = "Sand",       color = Color3.fromRGB(210, 180, 140) },
        { name = "Dark Slate", color = Color3.fromRGB(47,  79,  79)  },
        { name = "Brick",      color = Color3.fromRGB(178, 88,  50)  },
        { name = "Snow",       color = Color3.fromRGB(240, 240, 240) },
        { name = "Night",      color = Color3.fromRGB(25,  25,  50)  },
        { name = "Grass",      color = Color3.fromRGB(85,  170, 50)  },
        { name = "Rust",       color = Color3.fromRGB(183, 65,  14)  },
        { name = "Ice",        color = Color3.fromRGB(176, 224, 230) },
    },
}
