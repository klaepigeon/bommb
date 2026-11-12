# Status

What actually works, checked by the tools in `tools/` (run with
`xvfb-run godot --rendering-driver opengl3 --path . -s tools/<name>.gd`):

| Tool | Checks | Last result |
|---|---|---|
| `parse_all.gd` | every script compiles | 0 bad |
| `playthrough.gd` | the whole chapter beat by beat, with screenshots: knock, door, "Christ", seeing Marta, her lines, the throw, waking, Socko, the locked door, the wardrobe, cross-eyes, the pistol and firing it, the balcony, a random conversation, crawling in, the loading card, level 2's arrival, the encounter, the hunt, being caught and the restart, the exit and the card | 0 fails |
| `hunt_test.gd` | Marta: hears and investigates, gives up, sees standing / not crouched at range, stunned by a bullet, hunts again more suspicious, searches and returns to patrol | 0 fails |
| `touch_test.gd` | stick walks, right-half drag looks, both at once, USE presses interact | 0 fails |
| `socko_view.gd`, `marta_view.gd` | render the characters for looking at | |

## Implemented

- Two levels with loading cards between them; the crawl cutscene runs into the load.
- The whole authored script for Flat 47, the maze encounter, and random conversations A, B, C
  (C's memory branch reads `Game.memories`).
- Kurt: walk, limited-stamina run, trained crouch, head bob, footsteps that make noise, carrying,
  turning over and throwing physics objects, interaction prompts.
- Socko on Kurt's left hand: holds (out, facing Kurt, at his forehead, low), arm lag when turning,
  emotions, gestures (recoil, tilt, nod, bounce, point, shake), mouth driven by his syllables,
  cross-eyed, idle eye wandering, the divided-attention glance at something he wants noticed.
- Marta seated (Flat 47) and hunting (level 2): patrol, investigate noise, chase on sight, search,
  stun when shot, catch -> restart from checkpoint.
- Pistol: 8-round magazine, 4 to start, 6 more in level 2; recoil, flash, hit marks, reload,
  inspection, every shot is a noise she hears.
- Doors (open, locked, blocked from outside), drawers, a pushable wardrobe, pickups, physics props
  whose landings are noises (distractions).
- Touch controls (multi-touch, resizable, fade-able, movable, saved), gamepad, keyboard and mouse
  through one input map. Pause menu with settings. Title with Continue / New game.
- Saving: a checkpoint at the start of each level (flags, inventory, pistol, memories).

## Partially implemented / placeholder

- **Voices** are synthesised babble under subtitles, not recordings. Every sound is synthesised.
- **Kurt's body**: no visible body or left/right hand animation beyond Socko's arm and the hand on
  the pistol. No contextual hand animations for doors and drawers.
- **Infection** system: not started (flags only).
- **Memory tree**: only `Game.memories` exists (for random conversation C); nothing spends it.
- **Socko's antagonism**: his personality is in the lines and performance, but there's no
  obey/defy tracking yet.
- **Hiding places**: none dedicated; crouching and breaking line of sight are the stealth.
- Marta can't be killed (by design for now: the pistol buys time).

## Not built

- Android APK (needs export templates and the Android SDK in this environment; see the commit
  notes). The project is set up for it (Compatibility renderer, touch, landscape).
- Flat 48 (the chapter ends on its card).

## Known issues

- Test runs report a few leaked ObjectDB instances at exit (quit mid-level); harmless.
