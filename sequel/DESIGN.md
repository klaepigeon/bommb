# RHAPSODY XX8X

The sequel to *Rhapsody: The Brass Coast*, ten years on. The Brass Coast was a county; XX8X is our
own solar system, and the end goal is a galaxy: the deepest space sim and crime sim we can build,
with worlds you can land on, fly between, rob, rule or burn down, and aliens to meet on them.
Mobile first.

## Pillars

1. **Deep before wide, but wide in the end.** Every inhabited world runs game 1's full simulation.
   New worlds are added only when they meet that bar, and the goal is very many of them.
2. **Real physics, magnificent scale.** Real orbits and periods, Newtonian flight in every body's
   gravity, and a cruise drive and camera that make the distances felt.
3. **The ship is your horse, your house and your gang hideout.** You build it, crew it, live
   on it, get chased in it and lose it.
4. **Every faction is a system, not a questline.** Factions have turf, money, heat, grudges
   and memory, like the families and cops of game 1. Quests grow out of those systems.
5. **Every corner of sci-fi.** Diverse worlds and populations: space opera empires, cyberpunk
   cities, pulp aliens, cosmic horror, hard-SF miners, wizards with rings.

## Scale: from a county to a galaxy

| Level | What it is | Status |
|---|---|---|
| District | a city and its streets (game 1's cities) | done |
| County | game 1's whole map, 880×880 tiles | done: every inhabited world is one |
| Region | several counties stitched and streamed around you | done on Earth: walk or drive across sector borders |
| Planet | many regions across biomes and climate bands, with ecosystems (food chains, migrations, seasons) | done on Earth: 72 x 36 sectors (2,592 counties) over the real continents |
| Star system | our solar system at true relative distances | done: 8 planets, Ceres, 6 moons, the belt, the Sun |
| Galaxy | procedurally generated star systems reached by jump drive | started: the six nearest real stars, each with generated worlds |

## Earth: a planet-sized tech demo (built)

Earth is a grid of 72 x 36 sectors, five degrees each. Every sector is a full game 1 map (880 x
880 tiles: cities, roads, countryside, people, traffic, law), generated in under a second the
first time you enter it. That's 2,592 counties and about two billion tiles. The Brass Coast,
game 1's whole map, is one sector on the California coast.

- **Real continents:** a hand-made land mask of the real Earth, smoothed and roughened so
  coastlines run continuously across sector borders. Climate follows latitude and the real
  deserts, jungles and ice caps.
- **Real cities, after the collapse:** Neo-Tokyo, the London Arcology, the Cairo Sprawl and
  about sixty more sit in their real sectors; the rest are habs, blocks and zones.
- **Moving around:** walk or drive off the edge of a sector into the next (open ocean turns
  you back). Your ship stays where you parked it; call it to any pad. From orbit, the planet map
  picks your landing zone.
- **Saves:** the last few sectors you visited keep full saves; older ones regrow from their seed.
  The Brass Coast always keeps its save.
- **From orbit:** Earth is drawn from the same mask (the Americas facing you), with the sprawls
  lit on the night side.

## Earth's look: Streets of Fire and The Protomen (built)

The main visual reference for Earth and its tech is *Streets of Fire* (a rock-and-roll fable
city in a permanent wet night) and *The Protomen* (a city under a tyrant's lights). On Earth:

- a crimson smog sky, even at noon, with searchlights sweeping it;
- neon on every storefront, and marquees with chasing bulbs on the clubs, cantinas and hotels;
- the El: an elevated train on iron girders over every city's main drag, lit windows and sparks;
- the Fear Man's face and slogans (OBEY, FEAR IS ORDER) on screens over the towers;
- robot Peacekeepers on the corners, acid rain that stings, a VHS grade over the picture.

## Look: the future the 80s imagined, drawn with Gen 4 pixel craft

The subject is 80s retro-futurism: neon and chrome, synth-sunset skies, grid horizons, VHS
glow, big-shouldered starships, holographic signage, Blade Runner streets and Tron interiors. The
technique is Gen 4 pixel art (HeartGold/SoulSilver/Platinum).

## Pixel technique: Gen 4 DS (HeartGold / SoulSilver / Platinum)

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

## The solar system (built)

Our real solar system in year XX8X: the Sun, all eight planets, the Moon, Io, Europa, Ganymede,
Callisto and Titan. Orbits use real distances (1 AU = 60,000 units) and real periods, so the
worlds drift apart and together over the in-game months. Planet radii are exaggerated about 200×
so they read at ship scale.

| World | What it is | Who runs it | Status |
|---|---|---|---|
| **Earth** | a dystopian planet-sized Earth; the Brass Coast is one sector of it | the Fear Man's Syndicate, and the street crews under him | landable anywhere on land |
| **Mars** | terraformed: green where the money went, red dust where it didn't; the casino world | the Solari families | landable (the start) |
| **Venus** | the Imperial capital: marble cloud-cities over an acid sea | the Galactic Empire | landable |
| **Luna** | mining domes, the black market, hymns on the radio | the Choir and the rebels | landable |
| **Ceres** | the biggest rock in the belt: ice mines, claim-jumpers, nobody's law | the claim-jumpers | landable |
| Europa | ice over an ocean, and something under it that answers the radio | the Europans | first contact (scan it) |
| Titan | orange haze; the Choir's signal comes from here | the signal | scan it |
| Mercury, the gas giants, the other moons | prisons, gas rigs, rebel yards | various | visible, planned |

## Flight (built)

- **Newtonian:** every body pulls with its surface gravity × radius². With flight assist on,
  the ship damps drift and leans against gravity. With it off it's pure physics: real orbits,
  and a predicted trajectory line shows where you're falling.
- **Cruise drive (RUN):** speed grows with altitude over the nearest world (about 20% per
  second), so crossing an AU takes under a minute but planets pull you back to local speeds.
  It drops you out when you dive toward a world or reach your course.
- **Flight computer:** set a course on the System tab and it steers in cruise, climbing out of
  any gravity well you're low in before heading off.
- **Scale:** the camera zooms out with speed and altitude. Worlds shrink to discs, the orbits
  appear, and your ship becomes a marker.
- **Landing:** get low over an inhabited world and slow down; hitting a surface fast hurts.

## Stations and the belt (built)

- **The Red Velvet Orbital** circles Mars: dock and you're in a full game 1 casino, in orbit.
- **The Haulyard Assay Station** circles Ceres: it buys ore, ice and platinum, sells jump fuel
  and patches hulls.
- **The asteroid belt** (2.2 to 3.3 AU) is really there: rocks in every stretch of it, thicker
  toward the middle and around Ceres. Shoot one to crack it, fly through the pieces to scoop
  them up (a Tractor Beam pulls them in from further). Hitting one at speed hurts.

## Aliens and peoples (built)

Species live inside each world's population (homes, jobs, families, grudges, like anyone),
with their own bodies, names and voices:

| Species | Where | What they want |
|---|---|---|
| Greys | Luna, Ceres | brokers: they buy Song-Pearls and platinum, sell Xeno-Tech (contraband) |
| The Choir | Luna | hybrids who hum the signal; listen to them three times and it leads to Titan |
| Martians | Mars | little green tourists with big bankrolls |
| Saurians | Venus | the Empire's crested old allies, all over the court |
| Belters | Ceres | people the belt changed: visors, long bones, their own slang |
| Europans | under Europa's ice | never seen; first contact is a call-and-response of tones, then they trade pearls for records |

Other stars generate their own species (a body plan, colours, eyes, names and a voice).

## Ecosystems (built)

Every world has its own wildlife on game 1's animal AI (grazing, fleeing, packs, ambushes,
night hunts): Mars has dust hares, striders on the terraformed green, rust wolves and sand
worms; Venus has garden bucks, marble cats and acid lurkers; Luna has dome rats and crater
crabs; Ceres has ice bugs and tunnel worms. A daily predator-prey model runs per world (and
keeps running on worlds you've left). What you meet follows the numbers; hungry predators
hunt grazers in front of you; herds drift with the seasons. Shoot out the predators and the
grazers boom, strip the land, and crash below where they started.

## The Imperial bounty (built)

One number for the whole system, on top of game 1's per-city bounties. Crimes on Imperial
worlds, piracy against Imperial ships and downed patrols raise it. Bounty hunters come for it
on the ground (armed crews) and in space (gunships that disable you, dock, and board: fight
them in your own hold). The court on Venus settles it: pay, plead (a good name halves it once),
or stand trial and serve the time in game 1's jail, with game 1's jailbreaks.

## The jump drive (built)

A Jump Drive module reaches the six nearest real stars (Alpha Centauri, Barnard's Star,
Wolf 359, Sirius, Epsilon Eridani, Tau Ceti) by their real distances. It needs jump fuel
(refilled when you land, or bought at the Haulyard) and clear space: 4 AU from the Sun and
well away from any world. Each star's system is generated from its name: planets, moons,
sometimes a belt, and one or two inhabited worlds, each a full game 1 world with its own
cities, families, law, alien species and wildlife.

## Space (planned next)

- More stations (an Imperial customs platform, a rebel yard at Ganymede), derelicts, distress
  calls and interdictions.
- Charts: a galaxy map beyond the six neighbours.

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

## The opening (built)

The families are finished. The Fear Man (game 1's magenta alien from the dead tree) came down
and took the whole underworld of Earth, and your old outfit came with it. He is very old now,
and his mind wanders, but his yellow ring still glows. You start in Tom Cody's road duster with
600 credits and the Brass Buzzard, with a Syndicate clamp on its landing gear. Pay the Fear Man
1,200 or do him one job (jobs pay triple now), and you're flying; a blue marker leads you back to
the pad. On Earth every city's crew is a street gang under him.

Kill him (he's frail, but guarded) and his ring and the Sinestro Corps uniform are yours. That
is the only way into the lantern rings in XX8X: every other light waits until the yellow is on
your finger. A ring lets you take off into space with no ship, from the construct menu: masked,
in uniform, at the starter skiff's speed. The ship stays parked where you left it, and any pad
can call it down.

## The people of the future (built)

Populations are procedural: besides the alien species, every world has its share of cyborgs
(chrome plates, red eyes), robots (serial numbers, boxy heads, their own opinions), mutants
(lumps, extra eyes, strange skins) and androids (pale, glowing eyes, borrowed memories), each
person varied by their seed. On Earth the police are robot Peacekeeper units. The gear is sci-fi
everywhere: blasters, vibro-knives, thermal detonators, hover cars, cantinas, chrome clinics.

## Roadmap (next builds)

From the playtest wishlist, in rough order:

1. **Ship variety:** many more hull types and modules, designed in this system.
2. **Capital ships and bases:** space stations and star destroyers in the world, and eventually
   building your own.
3. **Empty planets and colonies:** land on uninhabited worlds and settle them; procedural
   worlds for every planet without hand-made content, using the Earth sector system.
4. **A galaxy chart** beyond the six neighbours.
5. **More stations:** an Imperial customs platform, a rebel shipyard at Ganymede.
6. **Alien crew** who join your ship.
7. **The Choir's story** paying off the Titan signal.
8. **More procedural people:** a wider generator for cyborgs, robots, aliens and mutants.

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
