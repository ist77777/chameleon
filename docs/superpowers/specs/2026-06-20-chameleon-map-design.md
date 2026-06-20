# Chameleon Map — Design Spec

**Date:** 2026-06-20
**Status:** Approved
**Scope:** Add a playable arena map to the Chameleon hide-and-seek game.

## Problem

The game has no geometry. All scripts (`src/server`, `src/shared`, `src/client`) run
against Roblox's default baseplate; there are zero `Workspace`/`SpawnLocation`/`Terrain`
references anywhere in `src/`. The core mechanic — hiders paint their character one of 12
`PAINT_COLORS` to blend in — has nothing to blend *into*. We need a map whose surfaces and
props come in the paint palette so blending is meaningful, plus proper spawning that closes
the current "seekers watch hiders during the hide phase" exploit.

## Concept

A single enclosed **themed color-zone arena**: ~200×200 studs, a 2×2 grid of four 100×100
zones, each themed to a slice of the paint palette. Hiders blend by painting to match the
zone they hide in; paints with no matching zone make them stand out — so color choice is a
real risk/reward decision. Daytime neutral lighting so paint colors read true (the Night
palette is intentionally *not* used as a zone, since darkness would stop hiders from
seeing to paint).

```
        +-----------------+-----------------+
        |   FOREST        |   STONE         |
        |   greens/browns |   greys         |
        |   trees,bushes  |   boulders,     |
        |   logs          |   pillars       |
        +--------+--------[ HIDER SPAWN ]----+   <- center pad
        |   SAND          |   SNOW          |
        |   tans          |   whites/ice    |
        |   dunes,rocks   |   snow mounds,  |
        |                 |   ice blocks    |
        +-----------------+-----------------+
                   [ SEEKER PEN ] (glass box, overlooks center)
```

### Zone → palette mapping

Colors are drawn from `src/shared/GameConfig.lua` `PAINT_COLORS`.

| Zone   | Floor color | Prop colors          | Best blend-in paints |
|--------|-------------|----------------------|----------------------|
| Forest | Grass green | Forest, Brown, Grass | Forest / Grass / Brown |
| Stone  | Stone grey  | Stone, Dark Slate    | Stone / Dark Slate |
| Sand   | Sand tan    | Sand, Brown, Rust    | Sand / Brown |
| Snow   | Snow white  | Snow, Ice, Sky       | Snow / Ice |

Paints with no home (Night, Brick, Sky-in-Forest, etc.) deliberately stand out. This is the
game's balance — it lives in the map, not in extra code.

## Build approach

A **procedural Lua builder** the server runs once on startup. Chosen over hand-authored
`.rbxmx` models (verbose, error-prone XML) and manual Studio building (not version-controlled).
The builder is pure code: version-controlled, diff-able, regenerates identically every boot.

Prop layout uses a **fixed seed / grid-jitter**, NOT live `math.random` at build time — every
server produces the identical map (fair for competitive play, reproducible for debugging).

## Architecture

```
src/server/
  MapBuilder.lua      NEW   builds geometry, returns spawn references
  Main.server.lua     EDIT  require + build before loop; per-phase teleports
  RoundManager.lua    unchanged
src/shared/
  MapConfig.lua       NEW   data-only zone definitions
  GameConfig.lua      unchanged
src/client/           all unchanged
```

### `MapConfig.lua` (new, data-only)
A plain table describing the arena: total size, wall height, per-zone `{ name, floorColor,
propColors, propCounts }`, central spawn offset, seeker-pen size/position, and prop
dimensions. Separates tuning (the *what*) from geometry code (the *how*) so the map can be
re-themed without touching builder logic.

### `MapBuilder.lua` (new)
One public function:

- `MapBuilder.build() -> references`
  Runs once at server boot. Steps:
  1. Remove any default baseplate present in `Workspace`.
  2. Lay the perimeter floor and four colored zone floors.
  3. Build perimeter walls (height from config) so players can't fall off.
  4. Scatter each zone's props (anchored part-assemblies) by seeded jitter.
  5. Place a `SpawnLocation` at center (the default respawn point).
  6. Build the glass seeker pen (transparent-but-solid walls, invisible roof) overlooking
     the center.
  Returns:
  ```
  {
    hiderSpawnCFrame   = CFrame,        -- center pad
    seekerPenCFrames   = { CFrame... }, -- one slot per potential seeker
    seekerReleaseCFrame = CFrame,       -- release pad near center
  }
  ```

Prop assemblies are simple anchored `BasePart` groups, sized so a painted character can tuck
against them:
- Tree = brown cylinder trunk + green block/sphere canopy
- Boulder/rock = scaled sphere/wedge
- Pillar = tall block
- Bush / dune / snow mound = squashed sphere
- Log / ice block = rotated block

~12 props per zone, ~50 total.

`MapBuilder` is self-contained: given `MapConfig`, it produces geometry and returns spawn
points. Consumers use only the returned references; they never reach into map internals.

## Spawn flow & round integration

Because the map adds geometry, default spawning is replaced.

```
SERVER BOOT
  MapBuilder.build()  ->  arena + center SpawnLocation (default respawn)

HIDE PHASE (after RoundManager.assignRoles)
  Hiders  -> teleported to center spawn, scattered in a ring -> free to run & paint
  Seekers -> teleported into pen slots, WalkSpeed=0 (frozen, can see out through glass)

SEEK PHASE start
  Seekers -> released: WalkSpeed restored + teleported to release pad near center

ROUND RESET (next lobby)
  Everyone -> center spawn; RoundManager.resetCharacters() already strips paint
```

### `Main.server.lua` edits
- Require `MapBuilder`; call `MapBuilder.build()` and capture references **before** the
  `task.spawn` game loop starts.
- Add two small helpers: `teleportTo(player, cframe)` and `freeze(player)/unfreeze(player)`
  (set `Humanoid.WalkSpeed`/`JumpHeight`).
- In `runHidePhase`: after `assignRoles()` + `resetCharacters()`, teleport hiders to a
  scattered ring around `hiderSpawnCFrame`, and teleport+freeze seekers into
  `seekerPenCFrames` slots.
- At the start of `runSeekPhase`: unfreeze seekers and teleport them to `seekerReleaseCFrame`.

`RoundManager.lua` is unchanged — it already freezes found hiders via `WalkSpeed=0` (the pen
reuses that same freeze technique) and already strips paint on reset. All client scripts are
unchanged.

## Design rationale

- **Glass pen = defense in depth.** Transparent-but-solid walls let seekers watch the arena
  (anticipation) while `WalkSpeed=0` + physical walls guarantee they can't act. If the freeze
  ever fails, the walls still hold them.
- **Teleport-out release, not wall-removal.** Deterministic and frame-perfect with the SEEK
  broadcast; avoids clipping or a lingering wall part.
- **Deterministic scatter.** Seeded layout = identical map on every server = fair play and
  reproducible debugging.

## Out of scope

- Multiple maps / map voting.
- Terrain (uses `BasePart` geometry only).
- Night/Brick/etc. dedicated zones (palette is intentionally only partially covered for
  risk/reward).
- Any client-side changes.

## Success criteria

1. Server boots and the arena appears (floor, walls, 4 colored zones with props, center
   spawn, glass pen) with no default baseplate remaining.
2. Each zone's floor and props use that zone's palette colors; a hider painting the matching
   color visibly blends.
3. During the hide phase, seekers are confined to the glass pen and cannot move; hiders
   spawn scattered at center.
4. At seek start, seekers are released to the center release pad and can move.
5. Players cannot fall out of the arena.
6. The map is identical across server restarts (deterministic).
7. `RoundManager` and all client scripts remain unmodified.
