# Animals CTF — Roblox (Luau) version

Ported from the HTML/Canvas version. Playable multiplayer Capture-The-Flag:
9 animals with unique stats, two teams, auto-built arena, auto match timer,
scoring and respawn.

## Files

```
src/
├── ReplicatedStorage/
│   ├── Animals.lua          (ModuleScript) animal stats table
│   ├── GameConfig.lua       (ModuleScript) round length, score limit, etc.
│   └── Remotes.lua          (ModuleScript) RemoteEvent registry
├── ServerScriptService/
│   ├── InitMap.server.lua   (Script) auto-builds arena + teams on start
│   └── GameManager.server.lua (Script) all gameplay logic
└── StarterPlayerScripts/
    ├── AnimalPickerUI.client.lua  (LocalScript) pick animal UI
    ├── HUD.client.lua             (LocalScript) scoreboard / banners
    └── AttackInput.client.lua     (LocalScript) Space / F / tap to attack
```

## Setup in Roblox Studio (5 minutes)

1. **Open Roblox Studio** → **New** → **Baseplate** template.
2. In the Explorer panel (View → Explorer if hidden), delete the default
   `SpawnLocation` under `Workspace`. The InitMap script will create team spawns.
3. For each file above, in Studio:
   - Right-click the matching service (e.g. `ReplicatedStorage`)
   - `Insert Object` → pick the type in parentheses (`ModuleScript`,
     `Script`, or `LocalScript`)
   - Rename it exactly as the filename (drop the `.server` / `.client` suffix,
     those only matter to tools like Rojo)
     - `InitMap.server.lua` → Script named `InitMap`
     - `GameManager.server.lua` → Script named `GameManager`
     - `AnimalPickerUI.client.lua` → LocalScript named `AnimalPickerUI`
     - `HUD.client.lua` → LocalScript named `HUD`
     - `AttackInput.client.lua` → LocalScript named `AttackInput`
   - Paste the file contents into the script editor.
4. Press **Play** (F5). You spawn at the Blue (or Red, auto-balanced) base,
   the picker opens — choose an animal.

## Controls

| Action          | Key / input                  |
|-----------------|------------------------------|
| Move            | WASD / left stick / joystick |
| Jump            | Space (Roblox default)       |
| Attack          | F key / right-trigger / on-screen "Attack" button |
| Open picker     | P                            |

> Space is already reserved by Roblox for **Jump**, so attack is bound to
> **F** (and a mobile button). If you prefer Space for attack, remove the
> default jump binding or change the KeyCode in `AttackInput`.

## How to win

- Touch the enemy flag to pick it up.
- Bring it to **your own base plate** to score — *your own flag must be at
  home,* or the point doesn't count (classic CTF rule).
- First team to **3 captures** wins, or if time runs out (**3:00**) the
  higher score wins (ties = draw).
- Getting killed drops the flag where you died. Friendly teammates touch the
  dropped flag to return it home.
- 10-second intermission, then a fresh round starts automatically.

## Testing with multiple players in Studio

- `Test` tab → `Clients and Servers` → pick `2 players` → `Start`.
- Two client windows + one server window open. You can drive both players
  and watch team assignment balance them.

## Publishing

1. `File` → `Publish to Roblox As…` → give it a name (e.g. "Animals CTF")
2. After publish, on the Roblox website open the place → **Configure** →
   set the **Experience** to Public.
3. Share the link. Done.

## Swapping in real animal models (optional, later)

The scripts don't require fancy models — they just set `Humanoid.WalkSpeed`
and `Humanoid.MaxHealth`, and stick an emoji BillboardGui above the head.

To replace the character with an actual 3D animal:

1. Open **Toolbox** (View → Toolbox) → search e.g. `low poly lion`,
   `low poly elephant`, `animal rig`.
2. Insert the model. If it's a `Model` with a `Humanoid`, you can set it as
   the player's starting character by parenting it under `StarterPlayer` and
   naming it `StarterCharacter`. Or use `Humanoid:ApplyDescription()` with
   a custom rig per animal (advanced).
3. Easier approach: keep the default R15 rig, weld the animal model onto it,
   or use the animal model's meshes as accessories.

The script logic doesn't care about visuals — stats come from
`ReplicatedStorage/Animals` only.

## Tuning

Edit `ReplicatedStorage/Animals.lua` to change any animal's stats.
Edit `ReplicatedStorage/GameConfig.lua` to change round length, score limit,
arena size, or attack cooldown.

## Troubleshooting

- **"Infinite yield possible on ReplicatedStorage:WaitForChild('Remotes')"**
  This is a benign warning on the very first Play if the server is slow.
  Everything still loads. If it persists, make sure `InitMap` is placed in
  `ServerScriptService` (not `StarterPlayerScripts`).
- **Players don't spawn at team bases** — check that the default
  `SpawnLocation` in `Workspace` is deleted.
- **Flag doesn't pick up** — confirm the `Flag` tag exists on the flag Part
  (the Tag Editor plugin can verify). `InitMap` adds it via CollectionService.
- **Emoji shows as a box** — some platforms don't render emoji in
  `Font.SourceSansBold`. Replace with animal name text in `Animals.lua` or
  use an image label.
