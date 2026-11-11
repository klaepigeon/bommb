# Expanding HYSTERIA

The game is built so the next flat, creature, line or sound is mostly data plus one small script.
This is the map. Every route in `tools/test.sh` should still pass after a change; add a route for
what you add (see the end).

## The shape of things

```
Main ── Level ── Flat47 (the glb flat; Scene A)
   │        ├── Maze (behind the wardrobe)
   │        ├── Building (stairwell, landings, lobby, street door + its bolts)   ← content/places.json "landings"
   │        └── places{id: Place}  (48, 51, 44, ...)                              ← content/places.json "places"
   ├── Kurt, Socko (+ SockoMind)
   └── Story ── Ambience (beds, fog, one-shots, tension, dust)                    ← content/ambience.json
```

Autoloads: `Log World Settings Lights Noises Audio Controls Power Speech Progress`.
World state goes through `World` (flags, events, save/load); nothing else writes save data.

## Add a place (a flat, a cellar, the roof)

1. **Script.** `scripts/world/flat52.gd`:
   ```gdscript
   class_name Flat52
   extends Place

   func build_content() -> void:
       # build at `at` (each place has its own patch of world; doors are the only way between)
       var k := Kit.new()
       k.box(Mats.tex(Tex.get_tex("plaster"), 52), at + Vector3(5, -0.05, 4), Vector3(10, 0.1, 8))
       k.commit(self)
       Lamp.make(self, at + Vector3(5, 2.4, 4), Color(1, 0.85, 0.6), 1.2, 6.0, [52])
       # ... colliders, Usables, Props, nav waypoints (level.nav) ...

   # when Kurt gets to what this place is for:
   #     reached_heart()
   ```
   Override `zone_of(p)` if it has rooms with their own light zones.
2. **Data.** An entry in `content/places.json` → `places`:
   ```json
   "52": {"script": "res://scripts/world/flat52.gd", "title": "Flat 52", "floor": 5, "side": 1,
          "at": [120, 0, 0], "bounds": [[-1, -1, -1], [11, 3, 9]], "zone": 52,
          "arrive": [[9.5, 0, 4.5], 1.5708], "fog": ["#101012", 18], "ambience": "47",
          "bolt_order": 5}
   ```
   and put `"52"` on its landing in `landings` (`[west, east]`). Pick an `at` nobody else uses
   (places sit 40 m apart).
   - `locked: "chain"` + `chain_look` gives it a chained door (kick it, or come out the inside).
   - `arrive_via: {"name": [[x,y,z], yaw]}` adds another way in (51 is reachable through 48's
     pointless door this way: `travel.call("51", false, "48door")`).
   - `bolt_order` adds a bolt to the street door, slid back when its heart is reached. Leave it
     out and the place is optional. The street door's text counts the bolts itself.
   - A place whose door isn't on a landing: `"entrance": "basement"` (the lobby's basement door;
     add another kind in `Building` the same way), `"exit": [[x,y,z], yaw]` for where you come out,
     and `"locked": "padlock"` + `"key": "<item id>"` for a padlock (key, axe, gun, Coral Grip:
     `Place.entrance_verbs`). `scripts/world/basement.gd` is the worked example.
   - `"shell": false` if the place opens onto a void (otherwise a dark box round it hides seams).
   - `"bolt_mark"`: what's scratched beside its bolt on the street door (default: its id).
3. **Story.** Nothing to do unless it needs monsters or beats: the `heart` event
   (`World.event`, `{"place": id}`) already slides its bolt. Beats go in `Story._on_event`.

## Add a creature

- AI: `extends Monster` (`scripts/ai/monster.gd`). Override `make_body()` to return a
  `CreatureBody` (see `scripts/creatures/creature_body.gd`: `SuperBody`, `InfectedFlesh`,
  `MartaBody`, or the procedural `Body`). Set `hearing`, `sight`, `fov`, `walk_speed`/`hunt_speed`, `can_break_doors`, `head_hp`/`body_hp`.
  Perception (`Noises`, light level), doors, nav and the state machine come free; override
  `think(delta)` for what's different. Look at `porter.gd` first.
- New look: an `InfectedGenome` with overrides (porter/lamplighter do this), or a new
  `CreatureBody` subclass with `pose(ctx)`.
- Spawn: in `Story.setup` (see Super, the figures), with `_dormant(m, true)` until it's wanted.
- Anything in group `monsters` that's hunting feeds the ambience's tension automatically.

## Add a line, a character, a document

- Lines: `content/dialogue.json` under any section; `Speech.say_id("id")` (or `Speech.say(speaker,
  text)` for one-offs). Scene A's are verbatim from the brief: don't edit them.
- Characters (voice, colour): `content/characters.json`.
- Readable documents: `content/docs.json`; a pickable Prop with `doc = "<key>"` can be read (Flat47 sets this from its level data).
- Socko's barks/suggestions: `content/dialogue.json` → `socko`; `SockoMind` picks by stage/mood.

## Add a skill

`content/skills.json` (`memory` tree costs memories, `gameplay` costs shards). Check it in code
with `Progress.has("id")`. Memories: `Progress.remember(key, n)` once per key.

## Add atmosphere

`content/ambience.json`:

- `profiles.<name>`: `bed` (looping sounds, dB), `fog` (for non-Place areas; Places use their own),
  `events` (one-shots: `every [min,max]`, `db`, `pitch`, `where` = wall / above / below / far / here,
  or `at` [x,y,z] relative to the place, `repeat`/`gap`, `needs` a World flag).
- A place picks a profile with its `ambience` field. Beds shared between profiles carry over
  without a seam.
- `tension`: heartbeat and pressure volumes, and how near (m) a hunter has to be to count.
- `Ambience.fire(event, near)` plays one now, for scripted moments.

Sounds are synthesised in `Audio._make` (no files): add a `match` case returning `_wav(data,
looped)`; build from `_noise`, `_tone`, `_mix`. Positioned sounds are muffled through walls.

Small reusable set-dressing: `Telephone.place(parent, id, at, facing, zone)` (off the hook,
rings after you hang it up). Lights: `Lamp.make(...)` with `flicker`, and `circuit` to put it on
the fuse box.

## Lighting rules (or it breaks on phones)

- Lamps are chosen for `Lights.camera` (Kurt's). Anything else that needs "the camera" should use
  that too: the game renders inside a SubViewport, so the root viewport has none.
- Put Usables in front of colliders, not inside them: the look ray stops at the first solid.

- No `Light3D`. Light is `Lamp` nodes; `Lights` feeds the nearest eight to every material.
- Every material is `world.gdshader` (`Mats.flat`, `Mats.tex`, `Mats.convert` for imported ones).
- Give each room a zone; a lamp lights only the zones it lists; doors join zones while open.
- GLES 3: assign varyings in the vertex function body, not helper functions (see
  `world.gdshaderinc`'s macro).

## Testing what you add

Add `func r_<name>()` in `tools/autotest.gd` (drive Kurt with `walk_to`, `look`, `use(point,
verb)`; assert with `check`), and the name to `ROUTES` in `tools/test.sh`. Run
`tools/test.sh <name>`, then all of them, then `tools/phone.sh` (GLES 3 at phone resolution with
real touches) before building the APK (`tools/build_apk.sh`).
