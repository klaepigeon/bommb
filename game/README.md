# HYSTERIA — Flat 47 (rebuild 3, Godot 4.7, Android first)

A ground-up rebuild: Scene A as written, then the walls behind the wardrobe, an enclosed maze
where Marta hunts, then Building 14: the stairwell, Flats 48, 51 and 44, the Super's basement, and the street door
that won't let you go until you've been everywhere it wants you to see. Design, reference inventory and what's different from the last build:
[`docs/DESIGN.md`](docs/DESIGN.md). Development log: [`docs/DEVLOG.md`](docs/DEVLOG.md). Adding to it (a place, a creature, a line,
a sound): [`docs/EXPANDING.md`](docs/EXPANDING.md).

Install `../dist/Hysteria.apk` (arm64, Android 7+, signed with the repo's key, so it installs over
earlier builds).

## Controls

| | Touch | Gamepad | Keyboard / mouse |
|---|---|---|---|
| Move | a stick wherever the left thumb lands (push past the ring to run) | left stick (L3 run) | WASD (Shift run) |
| Look | drag on the right | right stick | mouse |
| Use (the button says what: Open, Take, Push...) | the big round button | A | E |
| The other thing you can do to it | the smaller button beside it | X | Q |
| Jump / climb up onto things | JUMP | B | Space |
| Crouch | CROUCH | R3 | C / Ctrl |
| Ask Socko (what now? or, at the right thing, ask him to do it) | SOCKO | D-pad up | T |
| Socko's light | LIGHT | D-pad down | F |
| Pockets | POCKETS | Back | Tab / I |
| What you are (the two trees) | GROW | D-pad left | K |
| Fire / throw what you're holding | FIRE | RT | left mouse |
| Aim | AIM | LT | right mouse |
| Load a round | LOAD | Y | R |
| Pause and settings | ‖ | Start | Esc |

Settings (pause menu): look sensitivity, brightness, subtitle size, subtitles, voices, which side
Socko and the stick are on (left-handed play), text prompts, button opacity, invert look, picture,
volume. Save is in the pause menu too; it also saves when the app is put away.

## Build and test

```
tools/test.sh                  # every route, headless: Scene A, each way out of the living room,
                               # the maze, the shoes, each way through the front door, the service
                               # door, the systems, save/load, the monsters, talking, Socko & Marta,
                               # the random conversations and the balcony, the whole building to
                               # the street door, 51 the hard way, the atmosphere, the ledge
                               # outside the bedroom, the basement
godot --path . -- --gallery --shots=DIR   # every creature, rendered
tools/test.sh poke kick        # some routes
tools/phone.sh DIR             # the phone: GLES 3, 2340x1080, real multi-touch; screenshots in DIR
tools/build_apk.sh             # ../dist/Hysteria.apk, signed, or it fails
godot --path . -- --start=knock|wake|wardrobe|maze|gun    # start somewhere
godot --path . -- --autotest --route=arm --shots=DIR      # Kurt's free arm (needs a display)
godot --path . -- --views="x,y,z,yaw,pitch;..." --shots=DIR # render views
```
