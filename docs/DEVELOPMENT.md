# HYSTERIA — living development document

Updated with every milestone. Covers: what's complete, what isn't, known bugs, performance
issues, design decisions, and outstanding tasks.

## State (end of the first build of Chapter One)

All seven automated suites pass: **148 checks, 0 failures, 0 engine or script errors.**
They run with real rendering through the Compatibility renderer, which is what Android uses.
The touch and stealth suites also pass when run against the **exported APK's own data**.

| Suite | What it proves |
|---|---|
| systems (23) | Doors, bolts, keys, lock-picking, chains, drawers, holding, throwing noise, pulling heavy furniture, the fuse box, hiding, smashing, save/load round trip |
| touch (24) | Injected multi-touch exactly as Android delivers it: the stick, two-finger look while walking, Use, tap-to-use, chips, Crouch, pause/inventory menus by touch, a **menu worked by a second finger while the thumb rests on the stick**, layout editing and reset, 20:9 and 4:3 screens |
| scene_a (14) | The owner's opening, from the knocks to the crawl through the wall |
| routes (≈40) | Every way out of the Backrooms played to the ground floor: padlock key, bolt cutters, gunshot, the vent, the plank bridge |
| ai (21) | Marta: encounter, no hearing through closed doors, a gunshot heard, sight in light vs dark, catching, pounding a bolted door (she also finds the way round when there is one), silencing the radio, the music box calming her, being shot, dying |
| stealth (21) | Walking in through the front door, Socko knowing 13, The Super patrolling, half-blind in the dark, hearing a footstep, catching Kurt, mailbox key, key board key, picking 13, arriving, the end card |
| soak | Random touches and buttons for 25 s in each level while the hunters are active: must produce zero errors |

`tools/test.sh` runs them all. A suite that stops early, or that logs any engine or script error,
fails.

## Complete

- **Engine and project:** Godot 4.7 with Jolt physics and the Compatibility renderer. A
  low-resolution SubViewport with a PS1 post-process (15-bit dither, grain, infection effects).
  A performance governor that steps quality down on long frames (thermal throttling) and back
  up after headroom. An optional on-screen overlay showing frame time, draw calls and memory.
  Errors are logged on the device (`user://errors.log`), along with the last story beat.
- **Preserved assets, carried over untouched:**
  - Kurt's arm rig and pose library, and his body
  - Socko's rig and his 73-clip performance
  - Marta's model
  - The Super's rig
  - The infected generator

  The one change: Kurt's shoes are built with a local box helper instead of the old town's kit.
- **Asset library:** generated PS1 textures and sounds (`tools/gen_*`), and a kit of about 45
  furniture and fixture pieces. Static geometry merges into one mesh per room. Room light is
  baked into vertex colours and scaled by the room's circuit. Real-time lights are used only
  for the torch, muzzle flash and characters.
- **Levels:** one data-driven builder makes Flat 47, the Backrooms and the ground floor.
  Doorways are checked automatically for passability.
- **Interaction framework:**
  - Verbs, including hold-to-complete actions that make noise.
  - Forgiving touch aim along the line of sight.
  - Props with mass, noise, durability, fragility and contents.
  - Hold, throw, inspect, push and pull. Long objects are carried end-first.
  - Doors with keys, bolts, chains, padlocks and jams; barricades; pounding.
  - Drawers, cupboards, hiding spots, breakables.
  - Electricity: circuits, switches, fuses, and live-water hazards.
- **Inventory:** items are defined by tags, so problems ask for "pry" or "cut", not a
  specific item.
- **Narrative:** the owner's script verbatim. Lines written for the rebuild are flagged
  `"proposed": true` in `content/script.json`.
- **Socko:** random conversations A–C, with C branching on memories. He suggests the loud,
  violent option, records whether Kurt obeyed or ignored him, gets increasingly frustrated,
  and can betray Kurt with a giggle while he's hiding. He remembers 13.
- **Hunters:** one brain, two bodies.
  - **Marta** relies on sight and hearing equally; the lullaby calms her and she can be killed.
  - **The Super** is half-blind, hears everything, ignores the lullaby and is very hard to put
    down.
- **The revolver:** found on the bed in the tall bedroom. Rounds are loaded one at a time,
  there are about 7 in total, and each gunshot is heard about 30 m away. It works on padlocks,
  locks and breakables. Aiming at Marta makes her hesitate.
- **Consequences:** the story ledger and the infection (it shows in the post-process, whispers,
  Marta's clicking becoming almost-words, document text, the "Finish it" verb). There's a
  convergence summary at Apartment 13.
- **Mobile UI:** settings (camera, controls, subtitles, audio, graphics), save and load,
  checkpoints, and a failure state with retry.

## Not done yet / known gaps

- **Not tested on a real Android device.** This environment has no device and no KVM for an
  emulator. The exported APK's data was run through the test suites on the desktop engine
  instead. **Next step: install on a mid-range phone, turn on Pause → Graphics → Performance
  overlay, and play the chapter.**
- **Performance targets are unmeasured on hardware.** Desktop numbers:
  - Flat 47 builds in ~130 ms, ~11k triangles.
  - The Backrooms build in ~150 ms, ~15k triangles.
  - The ground floor builds in ~75 ms, ~7k triangles.
  - Rooms cost about one draw call per material.
- **Voice** is the device's text-to-speech under the subtitles. There's no recorded dialogue.
- **Kurt's memory points** come only from reading documents (the photograph, the clipping, the
  returned letter). How memories are "invested" is undesigned.
- **Infection** affects perception, sound, text, the finish verb and the ending lines. It does
  not yet drive Kurt's transformation (later chapters).
- **Smaller gaps:**
  - The Backrooms' room-by-room culling relies on occluders and fog. There's no portal system.
  - Marta's patrol is a fixed loop of points.
- **What lies beyond Apartment 13 is deliberately not built** (brief §12). The chapter ends on
  arrival.

## Known bugs

- None open that the suites catch.
- The intro's subtitles keep going if a test teleports Kurt during them; that only matters in tests.

## Design decisions

- **Engine:** Godot 4.7. It's the only engine where the preserved assets survive unchanged and
  everything can be built and tested here (`ENGINE_EVALUATION.md`).
- **Renderer:** Compatibility (GLES3) rather than Vulkan. It has the widest Android support, it
  avoids Vulkan driver crashes, and it's what the test renders exercise.
- **Navigation:** a door-aware A* grid instead of a navmesh. It's cheap to build on a phone,
  deterministic to test, and doors gate routes directly.
- **Lighting:** baked vertex light plus a few real lights. That's PS1-authentic, and the lights
  really go off when a circuit dies.
- **Touch routing:** touches are routed by finger index in the HUD. Godot only turns the first
  finger into mouse input for menus, so the other fingers are forwarded by hand. Without this,
  menus are dead while a thumb rests on the stick.
- **Hidden overlays** are sized when they open, because a hidden Control doesn't follow its
  parent's size, which left 0×0, unclickable menus.
- **The owner's direction (this session):** every way out of the Backrooms leads down to the
  ground floor, through the building's front door. The Super makes the ground floor a stealth
  sequence. Apartment 13 replaces Flat 48 as the destination. "13" is scrawled in the
  Backrooms, and Socko reads it aloud and remembers it, so it can't be missed.

## Outstanding

1. On-device testing on a range of phones: frame pacing, thermals, memory, touch feel.
2. The owner to review the lines marked `proposed` and the open questions in
   `SCRIPT_OPENING.md`.
3. Recorded voice, music, a bigger sound library.
4. Design memory-point investment, and the infection's later stages.
