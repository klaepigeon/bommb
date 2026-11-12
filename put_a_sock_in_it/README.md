# Put A Sock In It

First-person survival horror. Kerzhansk, 1996. Godot 4.7, GL Compatibility renderer (runs on
Android phones and PC from the same project).

Kurt is asked by Marta Sokolov's sister to look in on her in Flat 47. He finds her fused to her
armchair by coral, alive, asking about boxes. She throws him across the room. He wakes without
his name, and his left hand is a sock puppet called Socko, who is very helpful.

This folder is a fresh start. The only thing carried over from the old HYSTERIA project is Socko
himself: his model and rig (`scripts/socko/sock_rig.gd`), his cloth shader, and the mesh helpers
the rig uses (`scripts/core/meshkit.gd`). Everything else is new.

## Run it

Open the folder in Godot 4.7 and press Play, or: `godot --path put_a_sock_in_it`

Android: install `dist/PutASockInIt.apk` (rebuild with `tools/build_apk.sh`).

## Controls

| | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD | left stick | thumb anywhere on the left half |
| Look | mouse | right stick | drag on the right half |
| Use / open / pick up / drop | E | A | USE |
| Run (he's old: not for long) | Shift | L3 | RUN |
| Crouch | C / Ctrl | B | DUCK |
| Fire / throw what you hold | left mouse | RT | FIRE |
| Turn over what you hold, inspect the pistol | right mouse / Q | LT | TURN |
| Reload | R | X | RLD |
| Hurry the dialogue | Space | Y | » |
| Pause (settings, move/resize touch buttons) | Esc | Start | II |

## The chapter

1. **Flat 47.** The knock, the flat, Marta, the grab, the blackout. Socko. The door that won't
   open, the wardrobe, the hole, the pistol in the kitchen drawer, the balcony. Into the hole.
2. **Flat 47, again.** The flat grown out of meat, in the wrong order. Marta hunts you through it.
   Find the real front door.

Levels are separate scenes with a loading card between them; the cutscene at the end of a level
(crawling into the hole) runs into the black the next level loads behind.

## Layout

```
scripts/core       Game (state, saves, level changes, loading card, input map), Sfx (synthesised
                   sounds), Tex (procedural textures), Build (geometry), MeshKit
scripts/player     Kurt: movement, look, interaction, carrying and throwing, noise
scripts/socko      SockRig (the carried-over puppet) and Socko (his performance in play)
scripts/characters Marta's body, and her hunting AI
scripts/world      doors, drawers, the wardrobe, hotspots, pickups, physics props
scripts/weapons    the pistol
scripts/dialogue   the conversation runner and subtitles
scripts/levels     Level (shared), flat47, flesh47
scripts/ui         HUD, touch controls, pause menu, title
data/dialogue      every line in the game, as data
tools/             automated checks (see docs/STATUS.md)
```
