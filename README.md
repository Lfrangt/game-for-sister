# Animals Capture The Flag

A 2D local-multiplayer Capture The Flag game inspired by the Roblox game *Animals Capture The Flag*. Pure HTML + Canvas + vanilla JavaScript — no build step, no dependencies. Just open `index.html` in a browser.

## Play

Double-click `index.html`, or:

```bash
open index.html
```

## Controls

| Player | Move | Attack |
|--------|------|--------|
| **P1 (Blue team)** | WASD | Space |
| **P2 (Red team)**  | Arrow keys | Enter |

## Rules

- Each player picks one of 9 animals — Lion, Elephant, Fox, Gorilla, Kangaroo, Rhino, Cheetah, Bear, Cat — each with unique stats (speed / HP / attack).
- 4v4 matches: you + 3 AI teammates vs the enemy player + 3 AI.
- Grab the enemy flag and bring it back to your own base.
- Classic CTF rule: your own flag must be at home to score.
- First team to **3 captures**, or the higher score at the **3:00** timer, wins.

## Animals

| Animal | Speed | HP | Attack | Style |
|--------|-------|----|----|---|
| 🦁 Lion | 2.6 | 100 | 22 | Balanced |
| 🐘 Elephant | 1.6 | 180 | 28 | Tank |
| 🦊 Fox | 3.6 | 70 | 14 | Scout |
| 🦍 Gorilla | 2.0 | 150 | 26 | Brawler |
| 🦘 Kangaroo | 3.0 | 90 | 18 | Hit-and-run |
| 🦏 Rhino | 2.2 | 160 | 24 | Bruiser |
| 🐆 Cheetah | 4.0 | 65 | 15 | Flag runner |
| 🐻 Bear | 2.2 | 140 | 24 | Bruiser |
| 🐱 Cat | 3.4 | 75 | 16 | Agile skirmisher |

## Tech

- Single HTML file, ~850 lines
- `<canvas>` 2D rendering
- Top-down view with pseudo-depth y-sorting
- Simple AI: chases enemy flag, attacks nearby enemies, returns captured flag, chases enemy carrier

## License

MIT
