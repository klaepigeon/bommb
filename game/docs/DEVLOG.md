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
