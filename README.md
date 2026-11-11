# HYSTERIA — Chapter One

An Android-first immersive sim in Godot 4.7. The chapter runs Flat 47 → the Backrooms (Flat 47,
wrong) → the ground floor of Building 14 → Apartment 13.

**Install:** `dist/Hysteria.apk` (arm64, Android 7+). It is signed with the repository's own key
(`android/`), so it installs over earlier builds.

**Status, open problems and design decisions:** [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
**Engine choice:** [`docs/ENGINE_EVALUATION.md`](docs/ENGINE_EVALUATION.md).
**The owner's script, verbatim:** [`docs/SCRIPT_OPENING.md`](docs/SCRIPT_OPENING.md).

## The chapter

1. **Flat 47.** Kurt knocks, goes in, finds Marta, and wakes up with Socko on his hand. The flat
   is a whole apartment to explore: drawers, cupboards, papers, a fuse box, doors that lock, bolt
   and chain. The living room seals itself. The wardrobe moves, and there's a hole behind it.
2. **The Backrooms.** It's the same flat, built from the same pieces, rearranged and wrong.
   - The corridor loops.
   - There are two kitchens, and one is flooded on a live circuit.
   - The bedroom is six metres tall, and the revolver is on its bed.
   - "13" is scrawled on the wall. Socko reads it and remembers it.
   - **Marta hunts Kurt** by sight and sound.
   - There are three ways out: the padlocked door across the landing (key, bolt cutters,
     crowbar, hammer or a bullet), the vent behind the bathroom panel (screwdriver, smash it
     or shoot it), or a plank laid across to the other balcony.
3. **The ground floor.** Every way out ends with Kurt walking in through the building's front
   door. **The Super** walks this floor. He's nearly blind and he hears everything. Getting
   past him is a stealth sequence: you can listen, crouch, use the dark, hide, throw things,
   use the gun, or run.
4. **Apartment 13.** Its key is in mailbox 13 or on the key board in The Super's lodge. You can
   also pick the lock quietly or force it loudly. Arriving ends the chapter. What Kurt brings
   with him (Marta's fate, rounds, injuries, infection, memories, how he treated Socko) is
   played back through the dialogue and saved to `user://chapter1_end.json`.

## Controls

| | Touch (Android) | Keyboard / mouse | Gamepad |
|---|---|---|---|
| Move | stick: thumb down anywhere on the left half | WASD | left stick |
| Look | drag on the right half | mouse | right stick |
| Use / take / open | **Use** button (its label says what it'll do), or tap the view | E | A |
| Other actions | the chips beside Use | 2–5 | D-pad |
| Run | **Run**, or push the stick to its edge | Shift | RB |
| Crouch | **Crouch** | C / Ctrl | Y |
| Light | **Light** (once you have a torch or lighter) | F | X |
| Bag | **Bag** | Tab / I | Back |
| Gun | **Gun**, then **Aim**, **Fire**, **Load** | G, right mouse, left mouse, R | LT, RT, LB |
| Pause | **II** | Esc | Start |

Every on-screen button can be moved and resized under **Pause → Arrange the on-screen controls**.
Sensitivity, inversion, subtitles, audio, graphics preset, frame rate and the thermal
governor are all under Pause.

## Build and test

```sh
cd game
tools/test.sh                 # compile check, build every level, then every automated suite
tools/test.sh stealth         # one suite: systems | touch | scene_a | routes | ai | stealth | soak
tools/test.sh shots DIR       # rendered screenshots (needs xvfb)
tools/build_apk.sh            # dist/Hysteria.apk, signed (Godot 4.7 + export templates, Android SDK, JDK 17+)
tools/gen_audio.gd / tools/gen_textures.gd   # regenerate the sound and texture libraries
```

The previous builds are archived, untouched, in `legacy/`.
