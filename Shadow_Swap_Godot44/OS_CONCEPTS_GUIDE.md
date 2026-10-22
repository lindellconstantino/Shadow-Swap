SHADOW SWAP — GAME DESIGN NOTES
===============================
This project is a standalone 2D adventure/puzzle game and is not related to Operating Systems.

CORE LOOP
1. Explore the dungeon.
2. Swap between Material and Shadow realms with SPACE.
3. Use the realm-specific barriers to find safe routes.
4. Collect three memory shards.
5. Reach the Eclipse Gate and press E to win.

FEATURES
- Top-down movement with CharacterBody2D and move_and_slide().
- Two realms with different obstacle layouts and collision activation.
- Procedural 2D graphics drawn with Node2D._draw().
- Animated shard glow, portal pulse, and player aura.
- UI objective counter, realm indicator, contextual messages, and victory state.
- Automatic restart with R.

CODE LOCATIONS
- scripts/player.gd: player movement.
- scripts/main.gd: level setup, collisions, realm swapping, collectibles, portal, HUD, drawing.

TEST CHECKLIST
[ ] Player moves using WASD and arrow keys.
[ ] SPACE switches realm when the target location is safe.
[ ] A blocked realm swap is rejected.
[ ] Shards disappear when collected and counter updates.
[ ] Gate refuses entry until all shards are collected.
[ ] Gate triggers victory after all shards are collected.
[ ] R restarts the game.

All puzzle behavior is local game logic; no external services or imported art assets are required.
