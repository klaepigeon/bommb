# HYSTERIA

**The game is `game/`: rebuild 3, Godot 4.7, Android first.** Scene A as written, then the walls
behind the wardrobe: an enclosed maze where Marta hunts, with the Super, the porter, the
lamplighter and the white figures, and every way out of the flat there is. See
[`game/README.md`](game/README.md) and [`game/docs/DESIGN.md`](game/docs/DESIGN.md). Install
`dist/Hysteria.apk`.

Older code kept for reference: `legacy/game_v2/` (rebuild 2: the town), `legacy/hysteria/` (the
first Godot project) and, below, the original browser build (`src/`, `dist/index.html`,
`dist/Flat47.apk`), whose painted flat the new game is built in.

---

# FLAT 47

A first-person survival-horror environment: a flat on the fourth floor of Building 14,
a 1950s brick block on Ulitsa Gagarina in Kerzhansk, a city that was told to leave.
Phase 1 is the flat itself: seven rooms and a balcony to explore, with the courtyard
and the city beyond the windows. It runs in a browser and builds to one HTML file.

You are Lebedev, a private investigator. Marta Sokolova's sister in Kursk hasn't heard
from her in eight days and has paid you to knock on a door. The opening cutscene takes
you across the courtyard, through the lobby and up the stairs to 47, where the door is
standing open. You go in, and it shuts behind you: the chain is on, from the inside.

You find Marta in the box room. She is alive. Coral has grown up out of her, through her
skin and her clothes and on into the wall and the floor, so that she is rooted where she
sits, breathing. Touch her face and she wakes, takes hold of you, and asks if you've seen
the boxes. Then dark; then the box room floor, and Socko on your left hand, and she
isn't there any more.

Socko is a dirty sock with big googly eyes and the only thing in the game that looks like
it came from somewhere else. From then on he gives you your objectives (top left) and
tells you how things work the first time you need to know, out loud, in a cheap
text-to-speech voice, flapping his mouth.

## Play

Open `dist/index.html` in a desktop browser (Chrome, Edge, Firefox, Safari). Wear
headphones. Click **Enter** to lock the mouse.

| | |
|---|---|
| **WASD** / arrows | move |
| **Mouse** | look |
| **Shift** | hurry |
| **Ctrl / C** | crouch (toggle) |
| **E** | use · open · take · read |
| **F** | torch |
| **Right mouse** (holding something) | turn it over in your hands; **E** reads it if it's written on |
| **Left mouse** (holding something) | throw it |
| **Esc** | pause: sensitivity, volume, quality, invert |

### Controller

Any standard gamepad (Xbox, PlayStation, 8BitDo, Android controllers…), in a desktop
browser or the Android app. The prompts switch to controller glyphs as soon as you
touch it.

| | |
|---|---|
| **Left stick** | move (**RB** or **L3** to hurry) |
| **Right stick** | look; turns the held object while inspecting |
| **A** | use · open · take · read |
| **B** | back: close what you're reading, put the object down, leave the peephole |
| **X** | torch |
| **Y** | crouch |
| **LT** / **RT** | inspect / throw what you're holding |
| **Start** | pause (D-pad / stick to move through the menu, **A** to choose, **B** to resume) |

Pipe knocks near you rumble the controller.

### Android

`dist/Flat47.apk` installs directly (allow installs from unknown sources). It's the same
game in a full-screen landscape WebView, with touch controls (stick + buttons), or
plug in / pair a controller. The app reads the controller through Android's input
system itself and passes it to the game, so it doesn't depend on WebView's own gamepad
support; it also routes rumble to the controller (never the phone), pauses when you
leave the app, and maps the back gesture to pause. It starts on low quality.

Build it with `android/build.sh` (Android SDK with build-tools 35 and platform 35, JDK
17+; no Gradle). It's signed with the project's own debug key in `android/`, so each
build installs over the last.

URL options: `?skip` skips the opening cutscene (in game: E, Space or A skips it); `?q=high|medium|low` sets quality (shadow detail, render scale; point-light
shadows only on high). Touch screens get a stick and buttons and start on low.

## The flat

```
            courtyard (north)
   ┌─────────────┬──────────┬────────┐
   │             │          │        │
   │ LIVING ROOM │ BEDROOM  │KITCHEN │      balcony outside the living room
   │             │          │        │
   │        ┌────┴──d────┬──┴──d─────┤
   │        d    HALLWAY  ·  ·  ·  ·  d ── stair landing (front door, on its chain)
   ├──d──┬──┴───d────┬───────d──────┤
   │ BOX │  SONYA'S  │   BATHROOM   │
   │ ROOM│   ROOM    │              │
   └─────┴───────────┴──────────────┘
            street (south)
```

Every room has its own surfaces, light and story:

- **Hallway**: a dying bare bulb, the battery emergency lamp over the padded front
  door, his work jacket still on its hook, his boots still wet, a telephone off the hook
  with the engaged tone going, the fuse box with one circuit tripped.
- **Living room**: damask paper coming away from the wet outer wall, a herringbone
  floor gone grey by the balcony door, the wall unit with the good china and a
  television that still works, dinner for three on the table, a ceiling come down on the
  armchair, a bookcase on its face, a wardrobe dragged across the box-room door, and
  on the wall beside it someone has sprayed `14 IS EMPTY`. Someone else disagreed.
- **Bedroom**: the unmade bed, a wardrobe of bare hangers, a half-packed suitcase, her
  pills (all empty), a cracked mirror, their savings rolled in a pair of socks.
- **Kitchen**: the one fluorescent tube still lit, more or less; the calendar with every
  day crossed through to the 14th of October; Marta's note on the fridge; jars of water
  hoarded along the wall; a radio that only gets hiss, and pips under the hiss.
- **Sonya's room**: almost dark, the window boarded from inside and orange streetlight
  coming through the slats. The only bed in the flat that has been made.
- **Bathroom**: no window and no light, the ceiling down in the middle, the bath full
  of black water. You can reach into it.
- **Box room**: no window, bolted from the outside. Someone lived in here.
- **Balcony**: the courtyard four floors down, the blocks around it with a few lit
  windows, an army lorry, the playground swing moving in the wind, and on the skyline
  Plant No. 3's three chimneys, one of them still smoking.

Nothing is explained. The flat is meant to take a while: read things, open things,
take things down off shelves, knock on the pipes.

## The building (and reality, dying)

After you wake, the front door is still chained and padlocked from the inside. The key is somewhere in the
flat (where somebody hid it, under something you'd rather not put your arm into); or
there's an axe in the box room.

Past the door, Building 14:

- **The stairwell**: a Soviet switchback stair from the basement to the ninth floor,
  green gloss paint to shoulder height, a narrow well down the middle you can look
  down. Thirty-odd flat doors, nearly all locked; knock and once in a while something
  knocks back. Climb past the ninth floor and the stairs carry on, to a landing exactly
  like the ninth, and the numbers on the wall keep going up.
- **The lobby**: mailboxes (47's is stuffed with post dated after the evacuation), the
  street door. Outside it there is no street, only white; walk into it and it hands you
  back in through the door.
- **The basement door**: chained, warm water seeping under it, and on the other side,
  right up against the door, three knocks, then three.
- **Flat 48**, across the landing: the Sokolovs' flat as a draft. Bare grey plaster,
  pencil setting-out lines, grey blocks where the furniture should be with paper tags
  ("SOFA — the green one with the burn"), white windows with nothing behind them, and
  three tall grey shapes tagged MAMA, PAPA, SONYA standing with their faces to the
  walls. They only move when you aren't looking.
- **Flat 51**, upstairs, the one from the note in the box room: the same flat, the same
  paper on the walls, never lived in, the dust unbroken except for one set of footprints
  going in. Past the living room the building stops: no wall, just a floor going on into
  grey, his footprints going on with it, things standing a long way off. Follow them far
  enough and you're standing in 47's hallway again, and something in 47 has moved.
- **Flat 44**, downstairs: a hallway, then a corridor of identical cells, each with a
  chair facing the wall. It's longer than the building. It's longer than that.

Underneath all of it, a single number rises as you go further in (the first time you
reach each of these places, and each time a loop gives you back). As it rises, colour
drains from surfaces in drifting patches and then the surfaces themselves go, in
holes, from the edges in; the city dissolves from the horizon toward you; the sky stops
being a sky; the picture starts to slip and fringe; lights sag; the building hums; and
sometimes you hear the flat downstairs doing things nobody is there to do. It never
goes back down.

## How it's built

Everything is procedural: no image, model or sound files. Walls, floors and ceilings
are painted face by face at load time onto canvases (wallpaper patterns, water tide
lines, mould blooms, peeling paper over plaster and brick, ghost squares where frames
hung, graffiti, tally marks), each with its own bump map, so no two patches of damp
repeat. The furniture is built from parts; cloth is a heightfield draped over what's
under it. The soundscape is synthesised with Web Audio: HRTF-positioned sources with a
crude occlusion filter by room (a sound behind two walls is muffled), and a director
that schedules the building's noises.

```
src/
  main.js        boot, render loop, post, input, menus, static-geometry baking, test hooks
  plan.js        the floor plan: rooms, walls, openings (all dimensions in metres)
  shell.js       room skins with real door/window holes, reveals, wall cores, collapses, facade
  surfaces.js    what each room's walls, floor and ceiling look like (the painting)
  textures.js    canvas toolkit: noise, stains, mould, cracks, peel, wallpaper, wood, metal
  openings.js    hinged doors (they push you and the props), windows, the boarded window, front door
  furniture.js   materials and parts: carcasses with doors and drawers, drape, books, jars, frames
  dress.js       living room, hallway, balcony, light switches, fuse box, TV, telephone, torch
  dress2.js      bedroom, kitchen, Sonya's room, bathroom, box room
  docs.js        everything you can read (drawn onto canvases, shown in the reading view)
  exterior.js    sky, courtyard, buildings, streetlights, wires, the city, the stair landing, peephole
  lighting.js    controllable lights, flicker models, brownouts, window light
  props.js       physics props (cannon-es): carry, throw, push; lazily created bodies
  player.js      movement, collision (circle vs oriented boxes), pushing, footsteps per surface
  interact.js    crosshair targeting, use/take/hold/inspect/read, the HUD
  audio.js       synthesised sounds, positional chains, occlusion, the ambience director
  particles.js   dust that only shows where light catches it
  post.js        film grain and vignette
  gamepad.js     controllers: Gamepad API or the Android bridge, menus by pad, rumble
  zone.js        builds any set of rooms on any floor (skins, cores, collision, floors), mirror/offset plans
  building.js    the stairwell, landings and their doors, lobby, street, basement, the stair loop, pooled lights
  flats.js       48 (the draft), 51 (the echo, and the void past it), 44 (the corridor)
  decay.js       reality dying: the surface shader patch, decay volumes, fog/sky/post/audio, progression
  cutscene.js    the opening: shots along camera paths, subtitles, events, skip
  marta.js       Marta: PS1-style (vertex-snapped, flat-shaded, pixel textures), coral, breathing, the grab, waking
  hands.js       first-person hands (drawn over the world), torch hand, reaching, holding; Socko on the left
  voice.js       text-to-speech (Android TTS / browser speech / square-wave babble), Socko's lines, objectives, tips
android/         the Android app: manifest, MainActivity (WebView + controller bridge), build.sh
```

Performance notes: the building outside 47 is split into per-floor and per-flat groups and
only what's within two floors of you is drawn; its light fittings share a pool of four
real lights handed to the nearest fittings each frame; static meshes are merged by
material after load (per group) (and each prop's
parts are merged into one mesh per material); repeated exterior pieces are instanced;
distant buildings are textured boxes; outdoor surfaces carry their skylight as emission
so no hemisphere light floods the interior; shadow maps for slow-changing lights
refresh on alternate frames and dark lights skip theirs; the city isn't drawn from the
windowless rooms; tiny objects don't cast shadows.

## Build and test

```
npm install
node build.mjs            # → dist/index.html (minified, one file)
node build.mjs --dev      # unminified, readable stack traces
node build.mjs --watch
node tools/smoke.mjs      # boot headless, save screenshots of ~20 viewpoints to shots/
node tools/play.mjs       # scripted playthrough: walks the flat (A*), uses ~30 things, fails on any error
node tools/pad.mjs        # drives the game with a fake controller through the Android bridge
node tools/building.mjs   # key, front door, 48, up to 51 and out into the void, down to 44's corridor, the street
node tools/cine.mjs       # plays the opening cutscene, then finds Marta, touches her face, wakes with Socko
android/build.sh          # → dist/Flat47.apk
```

The tools need Playwright with a Chromium (`NODE_PATH=$(npm root -g)` if it's installed
globally). Screenshots render through SwiftShader, so they are slow and a little darker
and noisier than a real GPU.
