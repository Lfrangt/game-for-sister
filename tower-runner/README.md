# Tower Runner — Phase 1 (solo skeleton)

Single-file Roblox server script. Vertical tower with three alternating
segments (tower → runner → tower). Falling into the lava floor teleports
you back to your last checkpoint. Reach the goal at the top to "win" the
run; you reset to the start after a short banner.

## Files
- `TowerRunner.server.lua` — paste into `ServerScriptService` as a single
  Script named `TowerRunner`.

## How it differs from Animals CTF
- Solo experience; no teams, no flag, no bots.
- Uses `RespawnLocation` + checkpoint teleport (server) instead of CTF state.
- Conveyor push is implemented by adding world-+Z velocity to the
  player's HumanoidRootPart while they stand on a tagged `Conveyor` part.

## Phase 1 scope (this script)
- 3 segments: tower → runner → tower
- 6 platforms inside each tower segment (zig-zag left/right)
- One conveyor segment with side walls + jump-over obstacles
- Checkpoint at the top of each segment + start pad
- Lava floor instakills (bounces you to your last checkpoint via respawn)
- Goal pad at the very top with a "🏆 You finished!" billboard
- Leaderstats: `Stage` (number of checkpoints reached)

## Phase 2 (NOT in this skeleton)
- Multi-player race — multiple climbers on the same tower at once
- Mode picker GUI: Solo / Race / Practice
- Procedural variation between runs (different platform layouts)
- Polish: lighting, BGM, particle effects on checkpoint hit

## Studio install (1 minute)
1. Open Studio (any baseplate place, or new place).
2. Right-click `ServerScriptService` → Insert Object → Script.
3. Rename to `TowerRunner` (no `.server` suffix in Studio).
4. Paste contents of `TowerRunner.server.lua`.
5. F5 to test. Try jumping the tower stage, walking onto the conveyor
   stage, and falling into the lava to verify the checkpoint reset.

## Tunables (top of script)
- `SEGMENT_HEIGHT` — vertical studs per segment (default 40)
- `TOWER_PLATFORMS` — how many platforms in each tower stage
- `RUNNER_SPEED` — conveyor push velocity (studs/sec)
- `SEGMENTS` — list of `"tower"` / `"runner"` strings; reorder or add more
