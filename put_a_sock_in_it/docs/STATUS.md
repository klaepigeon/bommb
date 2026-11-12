# Status

What actually works, checked by the tools in `tools/` (run with
`xvfb-run godot --rendering-driver opengl3 --path . -s tools/<name>.gd`):

| Tool | Checks | Last result |
|---|---|---|
| `parse_all.gd` | every script compiles | 0 bad |
| `walkthrough.gd` | **plays the chapter like a person**: walks with the move key along routes planned on the flat's grid, turns to face things, presses interact only when the prompt is right, opens doors it walks into; reports where it gets stuck and what it's touching. Front door → Marta → waking → the jammed door → the wardrobe → the drawer and pistol → the balcony and back → the hole → copies A, B, C → 48 | 0 fails |
| `playthrough.gd` | the whole chapter beat by beat, with screenshots: knock, door, "Christ", seeing Marta, her lines, the throw, waking, Socko, the locked door, the wardrobe, cross-eyes, the pistol and firing it, the balcony, a random conversation, crawling in, the loading card, level 2's arrival, the encounter, the hunt, being caught and the restart, the exit and the card | 0 fails |
| `hunt_test.gd` | Marta (in copy B): hears and investigates, gives up, sees standing / not crouched at range, stunned by a bullet, hunts again more suspicious, searches and returns to patrol | 0 fails |
| `build_apk.sh` | exports and verifies the signed APK | signed |
| `touch_test.gd` | stick walks, right-half drag looks, both at once, USE presses interact | 0 fails |
| `flash_test.gd` | photosensitivity: renders the flickering scenes and counts brightness flashes per screen quadrant (WCAG general-flash rule, simplified) | 0 fails (≤ 1 flash/s) |
| `socko_view.gd`, `marta_view.gd`, `hunter_pose.gd`, `landing_view.gd`, `note_view.gd`, `beauty.gd`, `title_shot.gd` | render characters, Marta's poses, the stairwell and doors, Sonya's note and fixed views for judging the look | |
| `bake_audio.gd` | synthesises every sound into `assets/audio/` | 78 sounds |

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
- The stairwell (`Stairwell`): tiled floor, green dado and whitewash with grime and peeling,
  graffiti, the meter cabinet and its wires to a caged dying bulb, an iron rail over the well, the
  stair down jammed with furniture, a night window on the half-landing below; shared by both levels.
- Doors built as geometry (`DoorLeaf`): quilted leatherette front doors (47, 48) with studs,
  piping, peephole, locks and number plates; panelled painted interior doors (glazed where
  the export had glass); through the flat's material converter, so they flesh over in level 2.
- Sonya's note, half under her bed in Flat 47 (`NoteReader` shows readable paper; sets
  `flags.read_pembis`).
- Marta's voice (creaking fry, scream, cracks, sniffing, rattling breath) and animation: seated
  life and lunge; on her feet a dragging walk, scuttling chase, sniff and over-rotated head,
  listening crouch, slow tilt on meeting Kurt, reeling when shot.
- Pistol: 8-round magazine, 4 to start, 6 more in level 2; recoil, flash, hit marks, reload,
  inspection, every shot is a noise she hears.
- Doors (open, locked, blocked from outside), drawers, a pushable wardrobe, pickups, physics props
  whose landings are noises (distractions).
- Touch controls (multi-touch, resizable, fade-able, movable, saved), gamepad, keyboard and mouse
  through one input map. Pause menu with settings. Title with Continue / New game.
- Saving: a checkpoint at the start of each level (flags, inventory, pistol, memories).

## Fixed by the walkthrough (things teleporting tests never saw)

- The exported doors and drawers swung on screen but their collision never moved (their physics
  update was never switched on): the front door blocked the doorway open or shut.
- The landing wall's opening was centred on the door's hinge, not the doorway.
- Small loose things were put on the furniture layer (stopping Kurt) instead of underfoot.
- Doors left half open stood across the hall; they now open fully to the wall.
- Where Marta threw him was a pocket boxed in by furniture; he now lands on open floor.
- The pushed wardrobe slid into the only way out of the living room; it now goes into the corner.
- A disabled interaction box (the wardrobe's) still caught the crosshair, hiding "Crawl in".
- He couldn't step up anything (the balcony is 12 cm below the flat): he now steps up 30 cm.
- 25 cm rubble and overhead debris no longer block; he shoves loose chairs he walks into.

## Look (third pass)

- **The flat** is the JS version's apartment (`ExportedFlat`): its textures, painted relief and
  roughness through `shaders/world.gdshader` (unfiltered, vertex-snapped, specular calmed so it
  doesn't sparkle on a phone); collision and footstep surfaces from its room plan; its lights as
  Fittings, switched on only near Kurt (the phone renderer lights a mesh with at most 8); its
  doors, drawers and 145 loose things given behaviours (their descriptions kept).
- **Marta** is the old model: the grin, the teeth, the slid eye, the mould, the coral through her
  and the chair. The hunter is the same model standing (`MartaSeated.new(true)`).
- **Kurt's hand** (the old arm) reaches for her face across the table.
- **Level 2** is the same flat, blue like the hole, with `flesh` turned up in the shader: paint and paper with meat
  coming through, veins, wet, breathing; plus strands, lumps, coral, goo and pulsing glands.
- Every procedural box used to be inside out (wound the wrong way for Godot): fixed.

## Atmosphere (proof of concept / tech)

- **Screen** (`shaders/post.gdshader`, `Fx`): grain heavier in the shadows, vignette, 15-bit
  colour with ordered dither, colour fringing, colour drain, picture tearing, a concussed double
  image, a heartbeat at the edges, a colour wash. Driven by the story (the grab tears the picture
  and slows time; waking is doubled and drained, clearing over 16 s; the hole goes blue) and by
  Marta's distance in the flesh flat. Off in Pause > Film effects.
- **Light** (`Fitting`): each fitting has a character (old bulb, dying, fluorescent strike and
  stutter with its buzz, candle, TV, the flesh's shared heartbeat); the building's supply sags
  now and then and every mains light dims together; fixtures glow with their light; wall
  switches; shadows from her lamp (the coral up the wall), the landing bulb, the torch.
- **Torch** (F / RB / LIGHT): shadowed, its beam visible in the dust, swinging a little behind
  the view; it fails as Marta gets close, and she can see it from further away.
- **Air** (`Air`): dust that only shows where light falls; visible light cones.
- **Sound** (`Sfx`, baked by `tools/bake_audio.gd` into `assets/audio/`): a reverb bus sized per
  level, walls muffle what's behind them, footsteps per floor (wood with creaking boards, lino,
  tile, concrete, rug, flesh), Kurt panting after a run, and an ambience director: drips, the
  fridge, the fluorescent buzz, the receiver off the hook, the TV hiss, flies round Marta,
  someone walking about upstairs, the pipes (knock on the radiator: something answers), the
  building groaning, a siren far off, wind in her papers moving the curtains. In the flesh:
  a heartbeat that rises as she nears, whispers and groans behind the walls, knocking at her
  front doors (try one: something knocks back), goo dripping from the glands.
- **Dressing**: curtains, radiator, telephone, a clock stopped at 4:17, photographs (one frame
  empty), TV snow, the icon's red lamp; in the flesh, her wallpaper giving way to meat the
  deeper you go, ribs over the corridors, veins up the walls, strands from the ceiling, goo.
- **Title**: a live scene: Socko on a hand under a dying bulb, looking about, and at you.

## Partially implemented / placeholder

- **Voices** are synthesised babble under subtitles, not recordings. Every sound is synthesised (and baked).
- **Kurt's body**: no visible body or left/right hand animation beyond Socko's arm and the hand on
  the pistol. No contextual hand animations for doors and drawers.
- **Infection** system: not started (flags only).
- **Memory tree**: only `Game.memories` exists (for random conversation C); nothing spends it.
- **Socko's antagonism**: his personality is in the lines and performance, but there's no
  obey/defy tracking yet.
- **Hiding places**: none dedicated; crouching and breaking line of sight are the stealth.
- Marta can't be killed (by design for now: the pistol buys time).

## Android

`dist/PutASockInIt.apk` (arm64 + armv7, OpenGL ES 3, signed; `tools/build_apk.sh`). Built and
its signature verified here; **not yet run on a phone** (no device in this environment).

## Not built

- Flat 48 (the chapter ends on its card).

## Known issues

- Test runs report a few leaked ObjectDB instances at exit (quit mid-level); harmless.
