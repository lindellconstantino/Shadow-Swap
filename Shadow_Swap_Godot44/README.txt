SHADOW SWAP — GODOT 4.4
=======================
Genre: 2D top-down exploration / realm-switching puzzle
Engine: Godot 4.4 (GDScript)

ABOUT
-----
You are a small traveler trapped between the Material Realm and the Shadow Realm.
Collect all three memory shards, use SPACE to switch realms, and reach the glowing
Eclipse Gate. Obstacles differ between realms, so switching at the right moment is
part of the puzzle.

CONTROLS
--------
WASD or Arrow Keys : Move
SPACE              : Swap between Material and Shadow realms
E                  : Interact with the Eclipse Gate / nearby world
R                  : Restart the level

HOW TO IMPORT
-------------
1. Extract the entire Shadow_Swap_Godot44.zip to a folder.
2. Open Godot 4.4.
3. In the Project Manager, click Import.
4. Select the extracted project's project.godot file.
5. Click Import & Edit.
6. Press F6 only if you want to run the current scene; use F5 to run the project.

PROJECT STRUCTURE
-----------------
project.godot          Project settings and main scene configuration
scenes/Main.tscn       Main game scene
scenes/Player.tscn     Player CharacterBody2D and collision shape
scripts/main.gd        Level, procedural art, realm swapping, shards, portal, UI
scripts/player.gd     Top-down player movement
OS_CONCEPTS_GUIDE.md   Not applicable; this game is unrelated to Operating Systems

GAMEPLAY TIPS
-------------
- Collect all 3 glowing memory shards.
- Material-only barriers are blue. Shadow-only barriers are purple.
- Faint barriers are inactive in the current realm.
- If a realm swap would place you inside a newly solid barrier, the swap is rejected.
- Stand near the Eclipse Gate and press E after collecting every shard.

NOTES
-----
The visuals are generated in GDScript at runtime, so no external image assets are
required. The game was authored for Godot 4.4. It has not been launched in the Godot
editor in this build environment, so please test it once after importing. If an error
appears, inspect the Output and Debugger panels.
