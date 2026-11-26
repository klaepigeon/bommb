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
| Second action (Pick lock, Knock, Ask about...) | the smaller button | Q / right mouse | LT |
| Next second action (when there are several) | >> | R | RB |
| Bag and notes (the journal) | BAG | Tab / I | Y |
| Fast-forward time (watch routines) | WAIT | T | Back |
| Hit (fists, or a weapon you've picked up) | HIT | X / left mouse (when captured) | RT |
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

A night lasts about 18 real minutes (the clock runs at 30×; WAIT runs it at 1800×).

## The Missing Merchant

Abe Kessler owes Marv $400 (the Nite Owl's ledger) and keeps a heavy tin box in his office that
somebody wants. A letter on his desk at home tells him to bring it to the Vesper **tonight, after he
closes**, and to come inside. His appointment book says the same.

**If nobody interferes**, at 00:35 Abe fetches the box from his office and carries it across the
street into the Vesper's back room, lifts a hatch in the floor and goes down. The bolt slides shut.
Nothing after that is scripted:

- whoever could see the Vesper's door remembers him going in (not the Vesper's own people, who
  lie: Claudette says he left before two);
- people who expect him notice he isn't there (Rita and the diner's regulars when he doesn't come
  in for his late meal; anyone passing his dark shop in opening hours), and say so out loud;
- the news travels by gossip; the shop can't open with its owner gone;
- Officer Doyle hears, goes to look at the dark shop, and if you show him evidence, he spends his
  nights watching the Vesper's door;
- Abe's spectacles lie by the hatch.

**Ways through it**, all tested (`tools/test.sh`):

| Route | How | Result |
|---|---|---|
| Steal the box | Abe's office, behind him while he's at the counter (he faces the street) | No box, no meeting. He finds it gone (and doesn't know who), goes home and locks the door. Abe lives. |
| Warn him | Read his letter (apartment 2B, locked: pick it while he's at work), then *Warn him about the Vesper*. He only listens if he doesn't have reason to distrust you. | He stays home. Abe lives. |
| Investigate | Ask people about Abe (the topic opens once you know something), read the ledger and the book, see him go in yourself, break into the Vesper's back room (it's locked, and staffed until 04:30) | The spectacles and the hatch. The trail goes down. |
| Report | Show Doyle the spectacles | The police watch the Vesper from then on. |

**Rescue** (Location B, below): go under the street, get past what lives there, open the cage.
Abe walks himself home, up the ladder and out through the laundromat.

Your **notes** (BAG) are written only from what you've actually learned: read, been told,
overheard, seen, or picked up. They note contradictions (Claudette's story against the people who
saw him go in).

## Location B: under the street

The old **Ellery Street station**, closed in 1948, 8 m under the south side of the street, in the
same world as the block (no loading screen; the simulation keeps running overhead). Built from
`data/underground.json` by the same builder as the street.

- **Ways in:** the Vesper's hatch (bolted from below until someone down there slides the bolt), and
  the Suds-O-Mat, whose boiler room hides an iron ladder (the laundromat is locked: pick it). Frank,
  if you ask him about Abe, and a flyer on the laundromat floor point the way.
- **The station:** the platform, a dead subway car on the tracks, the token hall turned into the
  Court's chapel (an altar, the tin box if Abe brought it, a coffin, the Court's ledger of "guests"),
  the old entrance hall, and across the tracks the larder and its cage, the nest, the service room
  (the power lever, the larder key on a hook), the pump room (a chest: money and a lead pipe).
- **Routes:** along the platform past the pale walker; through the nest past the sleeper; down onto
  the tracks and along them; across the tracks at the boarded crossings, or anywhere if the power is
  off.
- **Power:** the lever lights the platform, tracks, hall and pump room, and makes the **third rail**
  live. Feeders see 13 m in the light and 4 m in the dark, so light helps them as much as you. The
  rail burns anything that steps on it, Feeders included.
- **Feeders** (`simulation/feeder.gd`): patrol, sleep, go to noises (the lever, smashed bottles, a
  fight), hunt what they see, grab. They stagger when hit and die. Not people: no schedule, no memory.
- **Combat** (`player/player.gd`): health, a swing (10 with fists, 25 with the pipe), getting hurt.
  At zero you're knocked out and wake in the yard behind the Nite Owl 90 minutes later.
- **Traps:** the third rail; bottles strung across the nest's doorway (walk into them and the sleeper
  wakes; cut the wire if you see it).
- **Secrets and storytelling:** loose tiles in the chapel hide a 1948 maintenance diary (a Kessler
  hid the box down here once before); the ledger names the East Side disappearances from the
  newspaper; a child's shoe in the nest; scratches on the larder door ("THEY DONT LIKE THE LIGHTS").
- **The objective:** Abe is alive in the cage. The key is on the big one's watch, or on a hook in the
  service room (or pick it). Open the cage and he goes home on his own (NPCs climb ladders through
  navigation links), and his life on the street resumes.

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
| Sound | Pooled 3D one-shots; loops that belong to a room and are muffled (low-pass, quieter) from anywhere else, so the Vesper's disco thumps through the wall and the street goes dull indoors; music only while its business is open; crowd murmur as loud as the room is full; footsteps per surface (concrete, tile, wood, metal, gravel) for the player and nearby people. | `core/sfx.gd` |
| Story events (fates) | Things that happen whether or not the player watches, started from `data/story.json` and then left to the ordinary simulation (walking, doors, witnesses, noticing absences, gossip, police). `NPC.command()` sends someone on an errand; `vanish_forever()` takes them out of the world. | `simulation/fates.gd` |
| Knowledge and the journal | The player's knowledge (flags) comes only from reading, taking, hearing, being told, seeing. Dialogue topics and the quest log are derived from it. | `core/journal.gd`, `simulation/npc.gd` (`ask`) |
| Location B | Underground areas in the same builder (height offset, floor levels, open passages, walkable stairs, powered lights); ladders with navigation links and bolts; the power lever, third rail, tripwires, secrets. | `world/neighbourhood.gd`, `world/ladder.gd`, `world/third_rail.gd`, `world/tripwire.gd`, `world/secret.gd`, `world/power_lever.gd` |
| Enemies and combat | Feeders (patrol, sleep, investigate, hunt, attack, stagger, die; sight depends on light); player health, attacks, weapons, knock-out. | `simulation/feeder.gd`, `player/player.gd` |
| Asset pipeline | Every external asset is in `data/asset_registry.json` (licence, source, creator, date, path, scale, collision); the game loads props only through it (`core/assets.gd`), which scales, recentres and converts every material to the PS1 shader. | `core/assets.gd`, `data/asset_registry.json` |

## Build and test

```
tools/test.sh                 # headless, three routes through the night (exit 0 = all pass):
                              #  night: the world, 15 people, touch, doors and keys, sound, reading,
                              #    taking, a witnessed theft, an unwitnessed one discovered later,
                              #    routines 21:00-06:15, gossip, the ledger, and the Missing Merchant
                              #    left alone (he goes, people notice, you investigate, Doyle)
                              #  prevent: steal the box;  warn: read the letter, warn him
                              #  rescue: under the street (ladder, power and rail, tripwire,
                              #    a Feeder hunts and hurts, the pipe, the key, the cage, Abe
                              #    walks home, knock-out)
tools/test.sh warn            # one route
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

Everything in the Systems table runs and is exercised by `tools/test.sh` (three routes, all passing).

### 3. Asset inventory (all CC0, see `ASSET_CREDITS.md`)

| Pack | Used for |
|---|---|
| ambientCG, 24 materials → 128 px | brick (3), asphalt, tar roof, sidewalk, concrete (2), plaster (2), wallpaper (2), wood floors (2), planks, tiles (2), carpet, shutter, rust, metal, diamond plate, fabric |
| Kenney Retro Urban Kit (23 models) | streetlights, traffic light, windows, doors, fire escapes, awnings, dumpsters, barriers, fences, pallets, planks, scaffolding, cables, bench, truck |
| Kenney Furniture Pack (33 models) | beds, sofas, chairs, stools, tables, bar/kitchen counters, stoves, fridges, sinks, bookcases, TVs, radios, boxes, desk, rug, toilet |
| Kenney Car Kit (6 models) | sedans, taxi, police car, van, delivery and garbage trucks |
| Audio (CC0): traffic (ignasd), crowd (starninjas), doors/keys/knocks/dishes/glass/hum/kitchen (rubberduck), coin/cloth/UI (artisticdude), static (bretbernhoft), music: blues (pro-sensory), disco (fupi), funk (Spring Spring) | ambience, radios, the Vesper, interaction sounds |
| Footsteps on different surfaces, **CC-BY 3.0** (congusbongus, from Freesound recordings by swuing, ceberation, Eelke; gravel CC0 by Ali_6868) | footsteps; **attribution required and given** |
| Kenney Survival, Graveyard, Train and Factory kits (CC0, 19 models) | the station: chests, barrels, bedrolls, bottles, the altar, candles, coffin, urns, chalice, cage bars, rails, the subway car, the power lever, the generator, pipes |
| Quaternius Ultimate Animated Character Pack (16 characters) | everyone, including the player; one shared rig with Idle, Walk, SitDown, StandUp, PickUp, Punch, RecieveHit, Defeat, Shoot_OneHanded, Walk_Carry, Victory |

Custom content: the architecture (generated boxes, textured with the sourced materials), the
signs (Label3D), all writing and data. No models were made by hand.

### 4. Missing foundations (honest list)

- **Not yet run on a phone.** The APK builds and is signed; performance and the touch layout
  need a real device. Watch: 15 skinned characters (~6.5k triangles each), ~30 omni lights.
- **No save/load**, no settings screen beyond the pause panel (settings are in `Settings` and saved).
- **Not built yet:** RPG layer (attributes, skills, origins, conditions), factions as
  systems, ranged combat, blocking and dodging, and multiplayer (the code is written to be host-authoritative, with world state in
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

Done since the first build: **sound**, **The Missing Merchant as a world event**, and
**Location B** with a first combat layer (above).

1. **On a phone:** install, measure frame time, tune render height / light count / NPC tiers.
2. **Consequences of the rescue:** the Court notices its guest gone and its thrall dead; Claudette
   comes looking for the box and whoever took Abe; Doyle and the street react to Abe's return.
3. **Save/load** (the world is in `World`, `Journal`, NPC memories and purses: all plain data).
4. **RPG foundation:** attributes, skills that improve through use (lock-picking first: picking
   becomes a skill check with time and noise), inventory weight, equipment.
5. **Origins as stacked traits** (Vampire, Human, Witch) with conditions; Claudette and the Court
   become the first supernatural faction.
6. **Combat**, then **host/client multiplayer** (ENet; the authoritative state is already in one place).
