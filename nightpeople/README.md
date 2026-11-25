# NIGHT PEOPLE

A cooperative supernatural immersive-sim RPG. New York, 1977, at night. Godot 4.7 (GDScript),
GL Compatibility renderer, Android first, PC second.

**Milestone 1 (this build):** a character walks a small, atmospheric, PS1-style 1977 street,
goes into buildings, uses things, and watches 15 people live their night.

Install `../dist/NightPeople.apk` (arm64, signed with the repo's debug key). Or run on PC:
`godot --path nightpeople`.

## Controls

| | Touch | Keyboard / mouse | Gamepad |
|---|---|---|---|
| Move | left half: a stick under your thumb | WASD (Shift runs) | left stick |
| Look | drag on the right half | mouse (click to capture) | right stick |
| Main action (Open, Talk, Take, Read...) | the big round button | E | A |
| Second action (Pick lock, Knock...) | the smaller button | Q / right mouse | LT |
| Bag | BAG | Tab / I | Y |
| Fast-forward time (watch routines) | WAIT | T | Back |
| Pause, settings, credits | II | Esc | Start |

## What's in the first night

**Ellery Street**, one block, 21:00 Thursday 7 July 1977. Twelve buildings, eight with
enterable ground floors (20 rooms): two tenements on each side (apartments 1A–1D, 2A, 2B; yours
is 218/1D), **The Nite Owl** (bar, back room, toilet, back door to the yard), **Abe's Loans**
(pawn shop + office), **Lucky's Diner** (open 24 hrs) and its kitchen, **Rivera's Bodega** and
storeroom, **Club Vesper** (opens 22:00). An alley to a walled back yard behind the bar and the
pawn shop. A condemned building, a dead laundromat, warehouses closing the street.

**The people (`data/npcs.json`).** 15 inhabitants with homes, jobs, schedules, money,
relationships, personality and lines: Abe the pawnbroker, Rita the waitress, Gus the cook, Marv
the bartender, Luz and Hector Rivera, Vinnie the loan shark, Claudette and Ray of the Vesper,
Mrs. Feld in 1C, Dot, Eddie the cab driver, Nina who sleeps in the yard, Officer Doyle on his
beat, and Frank, a retired detective. People who live elsewhere arrive from and leave by the
ends of the street.

**Seeded for "The Missing Merchant":** Abe owes Marv $400 (the bar's ledger); Abe holds a tin box
someone wants (his office); a letter on his desk at home tells him to bring it to the Vesper after
midnight on Friday and "come inside"; his appointment book, Ida's pawn ticket, Rita's note from
Gus, the newspaper, Eddie's fare with no reflection. The disappearance itself is the next step
(see roadmap): it has to happen *in the simulation*, not as a script.

## Systems (and where they live)

| System | What it actually does | Files |
|---|---|---|
| PS1 rendering | One world shader for everything (vertex snapping, partial affine texture warp, nearest filtering, per-vertex lighting, no specular) with an alpha-cutout variant; the 3D view renders at 360 lines (setting: 240/360/480) and is scaled up nearest-neighbour with a 15-bit, 4×4 ordered-dither post pass. Fog, sodium streetlights, coloured interior light, lit and dark windows. | `render/`, `core/main.gd` |
| Neighbourhood builder | Builds the whole block from `data/neighbourhood.json`: buildings in local coordinates (either side of the street), walls with real door/window openings whose two sides take the covering of the room they face, floors, ceilings, facades, fire escapes, neon signs, props, lights; registers rooms (owners, public, opening hours) and places; bakes the navmesh. Geometry is merged per material per building (few draw calls) and the street is cut into 16 m chunks so no mesh is lit by more lights than a phone allows. | `world/neighbourhood.gd`, `world/mesh_kit.gd` |
| Interaction | `Interactable` base: verbs per actor, `perform(actor, verb)`. Doors (access from `World.may_enter`: owners, public rooms, opening hours, so shops lock at closing; keys; pick lock; knock; NPCs open them as they reach them), owned items, readables, people. The player's focus picks the nearest usable thing in front of the camera. | `world/interactable.gd`, `door.gd`, `item.gd`, `readable.gd` |
| Player | Third person, camera-relative movement, spring-arm camera, inventory and cash, starts with the key to 1D. | `player/player.gd` |
| Controls | Touch first (floating stick, drag look, context buttons that show the verb), keyboard/mouse and gamepad through the InputMap defined in code. | `ui/controls.gd`, `core/settings.gd` |
| Schedules + utility AI | Schedule blocks fix work/sleep/home/patrol/away; free time is chosen by utility: needs (hunger, drink, company, shopping, restlessness) grow by the hour, are weighted by personality, and only count where a free place is open to that person. Places are reserved (one person per stool). | `simulation/mind.gd`, `core/world.gd` |
| Tiered simulation | ACTIVE (< 35 m): physics, navigation, perception. NEARBY (< 55 m): visible, moved along the nav path kinematically. DISTANT: hidden, moved kinematically in game time. Fast-forwarded time makes everyone kinematic so routines keep pace with the clock. | `simulation/society.gd`, `simulation/npc.gd` |
| Perception + memory | Sight (range, field of view, line of sight through walls and doors), hearing (by loudness). Memories carry their source (witnessed, heard, found, told, rumour) and fade; disposition toward someone is derived from what's remembered. NPCs react to trespass and theft they witness, hear lock-picking, answer knocks, and *find out* about thefts by coming home to the missing thing (culprit unknown unless they saw it). | `simulation/memory.gd`, `simulation/npc.gd` |
| Gossip | People together share the most striking thing they know, if they don't distrust each other; the listener remembers it as told, by whom. | `simulation/society.gd` |
| Economy (basic) | Every NPC has a purse; meals, drinks and purchases pay the business's owner; every payment is in `World.ledger`. | `core/world.gd`, `simulation/mind.gd` |
| Dialogue (basic) | Talking to someone: what they say depends on what they know about you (witnessed crimes, rumours, first meeting), whether they're working, asleep (you woke them, in their home), and their own lines. | `simulation/npc.gd` |
| Asset pipeline | Every external asset is in `data/asset_registry.json` (licence, source, creator, date, path, scale, collision); the game loads props only through it (`core/assets.gd`), which scales, recentres and converts every material to the PS1 shader. | `core/assets.gd`, `data/asset_registry.json` |

## Build and test

```
tools/test.sh                 # headless: the world, 15 people, touch, doors and keys, reading,
                              # taking, a witnessed theft, an unwitnessed one discovered later,
                              # routines from 21:00 to 06:15, gossip, the ledger. Exit 0 = pass.
tools/test.sh shots DIR       # render fixed views and third-person views to DIR (xvfb)
tools/build_apk.sh            # → ../dist/NightPeople.apk, signed, or it fails
python3 -I tools/credits.py   # regenerate ASSET_CREDITS.md from the registry
python3 -I tools/process_textures.py SRC   # ambientCG 1K colour maps → 128px game textures
godot --path . -- --at=-20,7  # start somewhere else
```

---

# Project report (brief §24)

### 1. Current project state

The repository held one game, **HYSTERIA** (`game/`, Godot 4.7, its own story, art and APKs) and
its older browser build. NIGHT PEOPLE is a different game, so it was started as its own Godot
project in `nightpeople/`; HYSTERIA is untouched. It reuses HYSTERIA's proven patterns rather
than its code: the InputMap defined in code, the touch layout (and the lesson of its zero-size
touch layer bug), Compatibility renderer everywhere, no shadow maps, steady lights, a light
limit per mesh, headless autotests and the signed-APK script.

### 2. Existing functionality

Everything in the Systems table runs and is exercised by `tools/test.sh` (42 checks, passing).

### 3. Asset inventory (all CC0, see `ASSET_CREDITS.md`)

| Pack | Used for |
|---|---|
| ambientCG, 24 materials → 128 px | brick (3), asphalt, tar roof, sidewalk, concrete (2), plaster (2), wallpaper (2), wood floors (2), planks, tiles (2), carpet, shutter, rust, metal, diamond plate, fabric |
| Kenney Retro Urban Kit (23 models) | streetlights, traffic light, windows, doors, fire escapes, awnings, dumpsters, barriers, fences, pallets, planks, scaffolding, cables, bench, truck |
| Kenney Furniture Pack (33 models) | beds, sofas, chairs, stools, tables, bar/kitchen counters, stoves, fridges, sinks, bookcases, TVs, radios, boxes, desk, rug, toilet |
| Kenney Car Kit (6 models) | sedans, taxi, police car, van, delivery and garbage trucks |
| Quaternius Ultimate Animated Character Pack (14 characters) | everyone, including the player; one shared rig with Idle, Walk, SitDown, StandUp, PickUp, Punch, RecieveHit, Defeat, Shoot_OneHanded, Walk_Carry, Victory |

Custom content: the architecture (generated boxes, textured with the sourced materials), the
signs (Label3D), all writing and data. No models were made by hand.

### 4. Missing foundations (honest list)

- **Not yet run on a phone.** The APK builds and is signed; performance and the touch layout
  need a real device. Watch: 15 skinned characters (~6.5k triangles each), ~30 omni lights.
- **No audio** at all yet.
- **No save/load**, no settings screen beyond the pause panel (settings are in `Settings` and saved).
- **Not built yet:** RPG layer (attributes, skills, origins, conditions), combat, factions as
  systems, and multiplayer (the code is written to be host-authoritative, with world state in
  `World`, actions through `Interactable.perform`, input through `Controls`, but there is no networking).
- **Simplifications:** perception ignores darkness and disguise; no NPC-NPC avoidance; doors don't
  carve the navmesh (people with access open them, nobody is routed through doors they can't use);
  sitting and sleeping use the pack's SitDown and Defeat animations, which don't line up exactly
  with every seat or bed; upper floors are facades; Quaternius characters are chibi-proportioned
  (deliberately uncanny, but a taller rig may be wanted later); kit window glass is opaque, so lit
  windows are glow panes behind the frames.
- **Asset gaps:** no payphones, fire hydrants, subway entrance, 1970s cars (the Kenney cars are
  modern-ish), signage textures/posters/graffiti, or supernatural creatures yet.

### 5. Godot and platform configuration

Godot 4.7 stable. `gl_compatibility` on desktop and mobile. MSAA off, vertex shading forced
(PS1 Gouraud, and cheaper), 16 lights per object, nearest filtering, ETC2/ASTC import,
landscape, keep screen on. Physics 60 Hz. Physics layers: world, player, npc, doors,
interactable. Android preset: arm64-v8a only, package `com.klaepigeon.nightpeople`, immersive.
Render resolution is the main performance lever (`Settings.render_height`), followed by
`Settings.npc_active_distance`.

### 6. Asset sourcing plan

Order of preference per category: **Kenney** (CC0, consistent, low-poly, already chosen for the
city kits; downloaded from Kenney's own uploads on OpenGameArt), **Quaternius** (CC0, animated
characters and creatures: the "Ultimate Monsters" and "Animated Zombie/Animal" packs fit the
supernatural roster on the same pipeline), **ambientCG / Poly Haven** (CC0 textures through their
APIs, reduced to 128 px), **OpenGameArt** filtered to CC0/CC-BY per asset (the PSX-style uploads
there are the best source for 1970s props, signs and posters), **Freesound** (CC0 first, CC-BY
with attribution) for city ambience, subway, doors, footsteps. Next needs, in order: city
ambience and footsteps (audio is the biggest gap), payphone / hydrant / newsstand / mailbox,
1970s cars, posters and graffiti decals, subway station kit for Location B, creatures.

### 7. Licensing and attribution workflow

1. Check the licence on the asset's own page (not the site's general claim) and keep the
   pack's `License.txt` next to it when there is one.
2. Copy only what will be placed into `assets/...`; add a pack entry and each item to
   `data/asset_registry.json` (creator, source, licence, attribution, modification, commercial,
   date, notes).
3. `python3 -I tools/credits.py` regenerates `ASSET_CREDITS.md`; the pause screen lists the packs
   from the same registry.
4. Anything CC-BY: set `attribution_required: true`, and the credit line appears automatically.
   NC/ND/unclear licences, rips and fan ports are not used.
5. Unused assets are deleted (five were pruned in this pass).

### 8. Prioritized roadmap

1. **On a phone:** install, measure frame time, tune render height / light count / NPC tiers.
2. **Sound:** CC0 city ambience, footsteps per surface, doors, the bar's radio, the club's music
   through the wall.
3. **The Missing Merchant, as a world event:** on Friday after midnight Abe goes to the Vesper with
   the box and does not come out. His routine stops, his shop stays shut, Marv's debt goes unpaid,
   Ida worries, Doyle files a report, rumours spread through gossip. Solutions: talk (Ida, Dot,
   Eddie, Nina, Frank), evidence (the letter, the book, the ledger), theft (the office), the
   Vesper itself, and later supernatural powers.
4. **RPG foundation:** attributes, skills that improve through use (lock-picking first: picking
   becomes a skill check with time and noise), inventory weight, equipment.
5. **Origins as stacked traits** (Vampire, Human, Witch) with conditions; Claudette and the Court
   become the first supernatural faction.
6. **Location B:** the abandoned subway station under the street (Kenney/OGA modular kits).
7. **Combat**, then **host/client multiplayer** (ENet; the authoritative state is already in one place).
