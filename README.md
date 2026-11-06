# FLAT 47

A first-person survival-horror environment: a flat on the fourth floor of Building 14,
a 1950s brick block on Ulitsa Gagarina in Kerzhansk, a city that was told to leave.
Phase 1 is the flat itself: seven rooms and a balcony to explore, with the courtyard
and the city beyond the windows. It runs in a browser and builds to one HTML file.

There is no monster and no objective yet. There is the flat, what the Sokolov family
left in it, the evidence that somebody came back afterwards, and the building, which
is never quite quiet.

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

URL options: `?q=high|medium|low` sets quality (shadow detail, render scale; point-light
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
android/         the Android app: manifest, MainActivity (WebView + controller bridge), build.sh
```

Performance notes: static meshes are merged by material after load (and each prop's
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
android/build.sh          # → dist/Flat47.apk
```

The tools need Playwright with a Chromium (`NODE_PATH=$(npm root -g)` if it's installed
globally). Screenshots render through SwiftShader, so they are slow and a little darker
and noisier than a real GPU.
