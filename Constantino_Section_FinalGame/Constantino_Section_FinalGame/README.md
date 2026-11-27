# Shadow Swap - Final Period Edition (Godot 4.4)

A top-down puzzle game: shift between the **Material** and **Shadow** realms, collect every memory shard, reach the Eclipse Gate. 3 stages.

## Open and run
1. Install **Godot 4.4** (or newer 4.x; "Standard" version, not .NET).
2. Unzip this folder. Open Godot > **Import** > select `project.godot` > Import & Edit.
3. Wait for the first import (fonts/audio) then press **F5**.
If you see errors in the Output panel on first open, close and reopen the project once (class-name cache).

## Controls
WASD / Arrows move - SPACE shift realm - E use gate - ESC pause - R restart - M sound.
Developer keys: F3 OS monitor, F4 cleanup on/off, F9 record memory log, F10 auto-walk.

## Export (OS as a Platform)
Editor > Manage Export Templates > Download. Project > Export > "Windows Desktop" (preset included) > Export Project to `build/windows/ShadowSwap.exe`. Run it outside Godot and check SYSTEM INFO says "Exported build".

## What is new / improved
- New: Stage 3 (sealed chambers), Stage select, how-to-play, system info panel, best times, loading screen, fade transitions, pause menu with sound toggle, ending screen, first-time tutorial hints, particle/ring effects, echo trail, screen shake, ambient music + UI sounds, Montserrat font, icon, F3 OS-concept overlay.
- Stage 1 now has a cage that teaches realm shifting (the original stage never required it).
- Layouts moved to `level_data.gd`; shared UI look in `ui_theme.gd`.
## Bugs fixed (found by reading the previous version)
- Pause/ending panels were positioned off-screen. Space re-triggered the focused Pause button. Rapid realm swaps could race. Wisps were freed by a screen notifier whenever you left the Shadow realm. Player used grounded physics in a top-down game. Player animation never redrew. Progress was only saved per shard and never for best times.

## IMPORTANT - testing status
This version was written and checked **without Godot available**. It was NOT run, so nothing is proven to work yet. Done: static checks of references (`tools/static_check.py`), and a search proving all 3 stages are solvable (`tools/check_levels.py`). Not done: running the game, memory measurements, export. Use `docs/QA_CHECKLIST.md`, fix anything Godot reports, and fill `docs/MEMORY_REPORT.md` with your real numbers.

Docs: `docs/OS_CONCEPT_MAP.md`, `docs/MEMORY_REPORT.md`, `docs/ORAL_DEFENSE_NOTES.md`, `docs/devlogs/`, `CREDITS.txt`.
