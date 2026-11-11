# Development log

## Rebuild 3, session 1

- Studied the browser build (`src/`), both Godot builds (`legacy/hysteria/`, now `legacy/game_v2/`),
  the docs (story bible, Socko, Kurt, audit, implementation report) and the three phone
  recordings (darkness and black frames; the hole's blocky edge; subtitles clipped; the town
  crashing to the home screen). See `DESIGN.md` §2.
- New project. Light engine first, checked on Mesa's OpenGL ES 3.2 before anything was built on
  it: a lamp lights its own room and the lamp in the wrong room lights nothing.
- GLES lesson: a shader varying can't be assigned inside a helper function (desktop GL allowed
  it). The engine's shaders are written to the stricter rule.
- Winding lesson: Godot's front faces are clockwise. Procedural geometry (`Kit`) is now built
  two-sided, so no driver can drop a face.
- `Noise` is a Godot class: the noise autoload is `Noises`.
- Socko: the owner asked to keep him (then: rewrite him if it works better). His rig and clip
  library are kept; his controller is new (threats, pointing, the torch, looking at the player)
  and his mind is new (seven stages, the HUD's duties, commands).
- The test harness drives Kurt the way a player does: the real raycast picks the target, the
  real verbs are used; walking follows the Nav graph and opens only what a player could.
- Bugs the routes found (all fixed, all now covered):
  - the floor ended inside the wall's thickness at the crawl hole and the bathroom hole (Kurt
    fell through): every hole has a floor now;
  - the bathroom's plug was inside the tub's collider (it couldn't be reached);
  - Nav points sat on doors' hinge lines (an open leaf blocked the way): every waypoint is
    centred in its doorway; each hole has a waypoint in its middle; the landing is on the graph;
  - a deadlock in every monster's walking: a waypoint counted as reached under 0.35 m but the
    walker stopped under 0.4 m, so at 0.39 m it did neither (Marta froze 2 m from Kurt);
  - things asleep in zero gravity stayed hanging when gravity came back;
  - the porter heard nothing while sitting (every sitter was deaf), and calmed down the moment
    Kurt was 8 m off;
  - look input was overwritten each rendered frame: on a 120 Hz phone half of every drag was
    lost. It's accumulated until the physics step uses it;
  - Socko's googly eyes were plain materials and went black without Godot lights;
  - the touch buttons drew over the pause menu.
- Game feel added because of what testing showed: Kurt ducks into a low opening by himself; with
  something in his hand he can still open a door or flip a switch (Put down moves to ALT); a
  monster wedged against a half-open door shoves it.
- Tests: `tools/test.sh` (15 routes, headless) and `tools/phone.sh` (GLES 3 at 2340x1080 with
  real multi-touch). The touch harness must inject window pixels: the engine maps them to the
  canvas (as it does a phone's touches).

### Known gaps
See DESIGN.md §7. Not yet on a physical phone.

## Session 1, continued: the monsters' old models; the building

- Ported the previous build's models onto the new lighting: MartaModel (at her table; hunting,
  with coral roots trailing), SuperRig, InfectedBody/InfectedGenome (the porter, the lamplighter).
  One `CreatureBody` interface between the models and the AI. The new `Body` is kept for the
  white figures. Bodies built facing +Z were walking backwards: they face -Z now.
- Building 14: the stairwell (floors 1-5), the lobby, the street door's four bolts; Flats 48
  (the draft, the notes, the red-note plan, the pointless door, the gun safe, MAMA/PAPA/CHILD),
  51 (the echo, the grey, the prints), 44 (the corridor of cells, the child's cell). The game now
  ends only at the street door.
- Bugs found and fixed on the way: Scene A's exit trigger fired before the scene; the white
  void's catch zone overlapped the stairwell's lower floors (Kurt fell through to the balcony);
  the half-landing walls' colliders sat inside the stairwell; the basement door stood across the
  first flight; the rubble above floor 5 took the headroom of the flight below; waypoints cut
  across the flights instead of running along them; the flats were offset twice; the pointless
  door was behind 48's hall cupboard; a multi-line lambda can't end inside a `match` (Godot).
- Tests: 16 headless routes + the touch route on GLES 3 at 2340x1080; all pass. APK 1.1.

## Session 1, continued: atmosphere, and room to grow

- Places are data: content/places.json names each place's script, landing door, world position,
  bounds, arrival points, fog, ambience and street-door bolt. Flats 48/51/44 extend `Place`;
  reaching a place's heart (`reached_heart()`) slides its bolt. Travel, the landings, chained doors
  and the bolt count read from the data; story no longer knows any flat by number but 47.
- Ambience director: beds, fog, positioned one-shots, the tension layer, dust in the light. The
  hall telephone (engaged tone; rings later if hung up). Balcony wind. New synth sounds: drip,
  engaged, ring, wind, steps above, a far door, floor creaks, whispering, low hum, fluorescent
  buzz, a child counting.
- docs/EXPANDING.md. New route `atmosphere`. 17 headless routes pass.

## Session 1, continued: the gaps, polish, the basement

- The ledge route (WindowLedge) and Kurt's free arm (FPArm over the ArmRig). Kurt.climb() for
  scripted climbs; `rail_axis` holds him to a ledge.
- **The lighting engine chose lamps for the wrong eye.** `Lights` asked the root viewport for its
  camera, but the game renders in a SubViewport, so lamps were always chosen as if you stood at
  the world origin (47's living room). Every place far from 47 (48, 51, 44) was getting only the
  torch and the fog. `Lights.camera` is now Kurt's camera. The same mistake meant `Audio` never
  muffled sounds through walls; fixed too.
- Seams: the background followed nothing (pure white), so every hairline gap shone. It now takes
  the place's air (white only where the outside's in view), and every Place has a shell in its own
  colour round it (`"shell": false` for places that open onto a void, like 51).
- The basement (the Super's): a padlocked entrance (`entrance`, `locked: padlock`, `exit` in
  places.json, handled by Place), the furnace and four ways to the drawing, the Super coming down
  for loud noises. A floor under the flights at the bottom of the stairwell (there was none).
- Noise loudness is metres: the phone's ring had been set as if it were 0-1.
- New routes: ledge, basement (and arm, for screenshots). 20 headless routes pass.
