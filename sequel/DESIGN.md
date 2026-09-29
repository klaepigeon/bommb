# RHAPSODY II: BRASS STARS (working title)

The sequel to *Rhapsody: The Brass Coast*. Same year-XX7X seventies soul, now a space opera: a
whole solar system of planets you can land on, fly between, rob, rule or burn down. Mobile first,
played in portrait like a DS.

## Pillars

1. **Deep before wide.** Three living planets at launch, each as dense as the Brass Coast.
   More planets are added later, and each new one must meet the same bar.
2. **The ship is your horse, your house and your gang hideout.** You build it, crew it, live
   on it, get chased in it and lose it.
3. **Every faction is a system, not a questline.** Factions have turf, money, heat, grudges
   and memory, like the families and cops of game 1. Quests grow out of those systems.
4. **Seventies space.** Chunky hulls, analog dials, shag-carpet cabins, synth radio. The look
   is the space opera the seventies imagined, not modern sci-fi.

## Look: Gen 4 DS (HeartGold / SoulSilver / Platinum)

Game 1 is drawn like a Gen 3 GBA game. The sequel moves up a generation:

| | Game 1 (Gen 3) | Sequel (Gen 4) |
|---|---|---|
| Screen | one 3:2 screen | **two screens**: the world on top, a touch screen below (the portrait phone *is* a DS) |
| Resolution | 240×160 look | 256×192 per screen |
| Buildings | flat fronts | **2.5D**: roofs and side walls in perspective, taller silhouettes |
| Tiles | 3–4 tones | 5–6 tones per material, softer ramps, dithered transitions, animated water and grass |
| People | 16×32, chibi | 32×32 cells, bigger heads, walk cycles with head bob, run and surf/float frames |
| Light | day and night tint | per-area palettes (morning, noon, dusk, night), lit windows, reflective floors indoors |
| UI | paper boxes | the DS menu style: rounded panels, the bottom screen as a touch device (Pokétch style) |

**The bottom screen is the Ship Watch.** It's a seventies wrist-computer app deck: map, ship
status, cargo, crew, radio, contacts and the ring. On foot it's your phone; in the cockpit it's
your dashboard.

## The system

A star with five bodies at first. Three are landable at launch; two are in view and unlock later.

| Body | What it is | Who runs it | Play |
|---|---|---|---|
| **Veridia** | green trade world, casino ring-city | the Solari crime families (space mafia) | rackets, casinos, loan sharking, turf wars |
| **Castra Prime** | Empire capital, marble and chrome | the Galactic Empire | infiltration, heists, bribery, the court |
| **Hollow Moon** | frontier mining moon, dust and domes | nobody, so the cult and the rebels | smuggling, bounties, the cult's strange lights |
| Oa-adjacent station | the Green Lantern outpost | the Corps | later: ring trials |
| Ysmault drift | a dead, haunted wreck field | Red Lanterns | later: rage and ruin |

Each landable planet is a full tile map the size of the Brass Coast, with its own biomes,
cities, population, economy and law.

## Space

- **System map:** planets on real orbits that move over time. Trade prices and patrol routes
  shift with them.
- **Flight:** top-down Newtonian-lite flight with a thrust stick, a boost and a brake. Asteroid
  fields, stations, patrols, traders, pirates and derelicts.
- **Landing and launch:** a spaceport per city. Land anywhere else and you risk a crash landing,
  hidden from the law.
- **Hyperlanes:** fast travel between planets, taking in-game hours. Things can happen on the way:
  interdictions, distress calls, cult hymns on the radio.

## Ship building

The ship is a grid of modules on the bottom screen:

- **Hull tiers:** skiff, cutter, freighter, corvette, then capital (end game).
- **Modules:** cockpit, engine, fuel, reactor, cargo, **smuggler's hold** (hidden from scans),
  gun, torpedo, shield, tractor beam, **boarding tube**, med bay, crew quarters, lounge (morale),
  lantern battery (ring recharge).
- **What placement changes:** mass, thrust, heat, power and crew needs. Adjacency matters:
  a reactor next to cargo raises the explosion risk, and quarters next to engines hurt morale.
- **Walkable interior:** the grid is the ship's interior. You walk it on foot with your crew,
  and boarders fight through it.
- **Parts:** buy them at shipyards, strip them from wrecks, or steal whole ships (hotwiring from
  game 1 returns as ship slicing).

## Piracy

- **Interdict:** pull a ship out of hyperlane or chase it down in open space.
- **Disable:** shoot engines and shields without destroying the cargo.
- **Board:** dock the tube, then fight room to room on the top screen as a small tactical brawl
  with cover (game 1's cover shooting).
- **Loot:** cargo, credits, crew who switch sides, and the ship itself (tow it to a fence).
- **Heat:** every faction tracks piracy against its own ships. Rob the Empire and the rebels love
  you. Rob the families and a contract goes out.
- **Fences and black markets** on each planet, like game 1's swag fencing.

## Factions

Each faction has a standing meter, a heat meter, territory on each planet, leaders who can die,
and memory: they remember what you did and when.

- **Galactic Empire:** the law of the system. Patrols, customs scans, an Imperial bounty that
  follows you between planets, officers you can bribe, and a court on Castra Prime.
- **The Rebellion:** cells on every planet. They hire you for sabotage, pay badly, and remember
  loyalty. Joining them fully turns the Empire's whole system against you.
- **Solari families (space mafia):** five families. Game 1's family systems carry over: dons,
  capos, rackets, hits, vendettas, weddings, the made-man ceremony.
- **The Choir (space cult):** worships a signal from beyond the star. Recruits the desperate,
  and has real, unsettling powers that slowly show as the story goes on.
- **The Lantern Corps:** all nine colours, each a power faction with its own emotion, ring,
  rules and enemies. A colour leads to another, as in game 1. Your Sinestro Corps uniform from
  game 1 is your way in.

## Carrying over from game 1

- Your name, nickname and legend title.
- Your rings, whatever the wardrobe held at the end.
- The Sinestro Corps uniform, which starts the sequel's opening.
- Honour and infamy: they set the opening's tone and how the first faction greets you.
- The crew member with the highest loyalty comes with you.

This is read from game 1's save if it's on the device; otherwise the player picks a background.

## Engine plan: game 1's systems, carried over

Direction: the sequel keeps **as much of game 1's physics and systems as possible**. The
Brass Coast already has a deep, tested simulation, and rewriting it would throw that away.

**Shared engine.** Game 1's simulation modules become a library that both games build from,
so there's one source of truth and fixes flow both ways. Each planet's ground layer runs that
engine with new data and new art:

| Game 1 system | Sequel use |
|---|---|
| Population and life sim (families, ageing, jobs, relationships, kids) | every planet's citizens; offscreen planets run it coarsely |
| Pedestrian AI, routes, the sim worker | planet crowds |
| Vehicle physics, traffic, damage, dust, tyre marks | hover cars and speeders on planets |
| Combat: melee, guns, props, cover, suppression, gore, bruising | on foot everywhere, including boarding fights |
| Carry, rope and duct tape, bodies, trunks | the same, plus airlocks |
| Law, heat, bounties, witnesses, investigations, profiling | the Empire (patrols, customs, detectives), per planet and system-wide |
| Families, turf, rackets, hit squads, vendettas, made men | the Solari families |
| Loan sharking, bookmaking, laundering, drugs, fencing | Veridia's underworld and every black market |
| Truck hijacking | freighter piracy on planets (hover-trucks) |
| Heists and the plan board | Imperial vaults, casino jobs, ship heists |
| Cops on the payroll, IA, rats | bribed officers, Imperial Security, informants |
| Dialogue, honour, morality, flirting, marriage | unchanged, with new writing |
| World memory, newspaper, gossip | per-planet holo-news |
| Crew camp (moods, loyalty, side stories) | your ship's crew |
| Weather, seasons, dust storms, fire, water | per planet: moon dust storms, Veridia rain, low-g |
| Lantern rings and corps | all nine, as factions |

**What is new in the sequel:** the Gen 4 renderer and art, the dual-screen UI, space
(flight, the system map, hyperlanes), ship building, space combat and boarding, the
multi-planet world registry, and versioned saves.

**How:**
1. Pull game 1's `src/` into a shared engine package, with its tests (smoke, scenarios,
   nightly bots) coming along, so a port can never silently break behaviour.
2. Make the engine multi-world: `R.game.world` becomes the current planet, and the others
   run in a coarse offscreen tick.
3. Put the Gen 4 art behind game 1's art interface (it already swaps Emerald and Classic),
   so the same systems draw in the new look.
4. Swap the data: tiles, buildings, outfits, factions, goods, names.
5. Keep game 1's tuning numbers unless a playtest says otherwise.

Still part of the plan:
- **Scenes:** planet, space, boarding and the system map, each owning its own update and draw.
- **Dual-screen UI:** the world on the top screen, the Ship Watch on the bottom touch screen.
- **Versioned saves** with migrations from day one.
- **Deterministic generation:** each planet comes from a seed plus its definition.
- **A worker** for pathfinding and the offscreen planet simulation.

## Milestones

1. **Prototype (v0.1), this build:** the dual-screen shell; one spaceport district on Veridia in
   the Gen 4 look; walk to your ship; the ship editor; lift off; fly in space; the system map;
   land on a second planet; one freighter to rob (disable, board, loot, tow).
2. **Shared engine:** game 1's systems running on Veridia with the Gen 4 art: crowds, hover
   cars, combat, law and the families. The v0.1 planet scene is replaced by the engine.
3. **Castra Prime and the Empire:** customs, bounties, heists, the court.
4. **Hollow Moon, the Choir and the rebels.**
5. **The Corps:** the lantern questlines across all planets.
6. **Polish and the ending(s).**
