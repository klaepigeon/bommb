# Rhapsody: The Brass Coast

A mobile-first, top-down crime sandbox. The year is XX7X on the Brass Coast, and the seventies never ended. You choose your first name, last name and the name the street calls you. Two men walk you into the Dustwater desert and shoot you, and you crawl back to the highway, where one of five dons decides you're worth saving. From his back room you work your way up (or through) the families, in a region of five cities and about a thousand named people who live their own lives.

This is a ground-up rebuild of the original single-file *Rhapsody* (Port Hollow) artifact.

## Look & feel (matches the original)

- **GBA screen:** the world renders into a 480-wide buffer, a 240-wide view at 2x like the original, scaled with nearest-neighbour inside a wooden handheld bezel. In landscape it's 480×320 (3:2) with the controls either side. In portrait the screen sits on top and grows taller (up to 5:4) into the space the joystick and buttons don't need, so phones held upright see more of the world.
- **The original's characters:** people are painted by the original build's own character routine (`src/03_oldsprites.js`, ported verbatim: 16×32 pixel grids, 4-shade ramps, hair styles, flares, moustaches, poses). The protagonist is a young mafioso: slicked hair, charcoal suit, maroon shirt. Hats are drawn over the top.
- **The original's buildings and ground:** `src/03_oldtown.js` ports the original's building painter (siding, brick, stucco, concrete and board walls, awnings, shop glass with goods, doors, rooftop vents, lit windows after dark) and its grass, sidewalk, plaza, sand, dirt, boardwalk and parking textures, curbs included.
- **Scale:** one tile is a person's width. Buildings are 7–16 tiles wide with character-height facades, roads are four lanes, and the map is 880×880 tiles.
- **Pixel text:** all in-screen text, from the HUD hearts and money to signs, tags, bubbles and the STORY bar, is rasterised from the Silkscreen pixel font at its native size, hard-thresholded and scaled by whole pixels. Silkscreen and Pixelify Sans (SIL Open Font License) are embedded in the build.
- **Walk-in interiors:** every building has a furnished room, stamped on demand into a hidden strip below the map. Bars have counters, stools, jukeboxes and pool tables, homes have beds and dressers, and there are vaults, cells, pews, slot machines and more. The people the population sim says are inside are really there, including the family asleep in bed when you break in at night. Searching furniture, robbing registers and fighting inside all go through the same witness and law rules.

## Play

- **Local:** open `dist/index.html` in a browser (phone or desktop). No server or install needed.
- **Build from source:** `node tools/build.mjs` bundles `src/` into `dist/index.html` (standalone page) and `dist/rhapsody.html` (body-only, for publishing as a claude.ai artifact).
- **Smoke test:** `node tools/smoke.mjs` boots the build headless at phone size and fails on any page error. It needs Playwright.
- **Long playtest:** `node tools/playtest.mjs 100 out/` plays 100 in-game days through the real controls and writes `out/report.json` plus screenshots.

### Controls

| | Touch (default) | Keyboard |
|---|---|---|
| Move | Drag anywhere on the left half. Push far to run | WASD / arrows, Shift runs |
| Use (doors, cars, bodies, phones) | **A** (its label shows what it will do) | E |
| Hit / shoot | **B** | Space / F |
| Switch weapon / holster | **WPN** (hold to holster) | Q |
| Greet / Antagonize / Talk / Rob | Chips that appear near a person | G / V / T, X defuses |
| Cool (slow-mo), Mask, Sneak (crouch), Pockets | Small buttons | Z, M, C, I |
| Yellow Ring: conjure / beam / library | **RING** (tap / hold), **LIB** | Y, L |
| Improvised weapon: swing / throw / drop | **B** / tap **SWAP** / hold **SWAP** | Space / Q |
| Driving | Point the stick where you want to go. **Brake** drifts at speed | Space brakes, H horn, R radio |
| Menu / map | Tap the HUD / minimap | Esc / Tab |

## What changed from the old build

| Your note | What the rebuild does |
|---|---|
| Health | No free healing in a fight. Out of trouble for 15 seconds (not hit, not bleeding, no cops), you patch yourself back up to 60%; food, sleep, doctors and the hospital do the rest |
| Mobile-first interface | Floating joystick, thumb-sized A/B buttons, contextual action label, bottom-sheet menus, safe-area aware, portrait and landscape layouts |
| Much bigger map, multiple cities | 880×880-tile procedural region: **Port Hollow** (harbor), **New Avalon** (metropolis), **Dustwater** (desert), **Pinecrest** (snowy forest), **Bayou Clair** (marsh), four hamlets, farms and cabins, a river, a lake, and four-lane highways between them. About 600 buildings |
| ~1,000 named NPCs + procgen citizens + animals | About 1,010 named people with homes, jobs, spouses, kids, schedules, memories and opinions of you. Anonymous pedestrians and drivers fill the streets. Wildlife is biome-specific: deer, wolves, bears, boar, coyotes, gators, rattlesnakes, birds, cattle |
| Replace Claude dialogue with RDR2-style greet/antagonize + scripted choices | No text input anywhere. **Greet** builds familiarity (twice and you learn their name), **Antagonize** gets personality-driven reactions (cower, retort, laugh, square up, call a cop), **Defuse** calms a fight, **Talk** opens scripted trees per role (bartender, fence, cop, doctor, priest, mechanic, Don, shopkeepers, kids, sweethearts) |
| Text input and systems broken | The Claude/text-input path is gone. Every system was rewritten and is exercised by a headless test run |
| Player should look like a tough mafia mook | Heavy build, pinstripe suit with lapels, fedora, sunglasses, mustache, gold chain. Tailors sell other 70s looks |
| Smarter, more reactive NPCs | They react to your gun, mask, blood and drunkenness. They flee, cower, fight back or beg. They chat with each other about real town news and their own families. Grudges come from killing kin. Drivers get road rage |
| Stop punishing the player (random property-damage wanted) | **RDR2-style law:** a crime only counts if someone *sees* it. Witnesses must physically run to a payphone or a cop, and you can stop them by scaring, paying off, or worse. Police search your last known position, and you escape by breaking line of sight and leaving the circle. Masks keep your name off the bounty. Bounties are per city and payable at any police station. **Accidents are never crimes**: bumping lamps, hydrants or cars is free, and cops warn you before minor stuff escalates. Fistfights someone else agreed to aren't assault, and self-defence is legal |
| More dynamic traffic | Lane-following cars with traffic lights, yielding at intersections, following distance, honking, buses and trucks, parked cars, patrol cars, ambient police chases, reckless drivers, and drivers who get out and fight you after a crash |
| NPCs build their cities and have children | One in-game day = one year of aging (adjustable). People marry, have babies, grow up, move out, take jobs, grow old and die. Prosperous cities break ground on new houses and shops (construction crews included) and rebuild what burns down. It's all reported in the in-game newspaper |
| More fun and more environmental systems | Weather (rain, storms, fog, heatwaves, snow up north). Wind-driven wildfire that rain puts out. Lightning. Gasoline trails you can light. Molotovs and dynamite. Hydrant geysers. Shootable street lamps (darker streets mean fewer witnesses). Hunting, skinning and fishing. Three procedural radio stations (funk, disco, outlaw country). Bar fights, block parties, weddings, hitchhikers, roadside ambushes, pickpockets, muggers. Bank heists, store robberies, burglary, protection rackets, buying businesses and safehouses, a crew, a sweetheart, and a Cool slow-mo meter |

## This round

- **The Phone Man:** once you have a name (infamy 10+), payphones near you start ringing. A
  voice offers a contract (a name, a price, three days) and sometimes a way he wants it done:
  a blade, no guns, an accident, broad daylight, quietly. Do it his way for double; the money
  is taped under the phone you answered.
- **A dog:** feed a stray a sandwich and it's yours, with a name. It follows you, waits when you
  drive or go inside, goes for anyone who comes at you, digs up coins, and makes people like
  you a little more. Pet it. If it dies, it hurts.
- **The uniform:** strip a downed cop and wear the blues. Street cops stop knowing your face.
  In a police station you can lose the case file on you or clear out the property room (20%
  chance someone notices). Anything serious in front of people blows it.
- **Roadblocks:** run from a level-2 warrant by car and they set up ahead: two cruisers across
  the road, shotguns, a spike strip. Shredded tyres crawl; a garage or gas station sells new ones.
- **Hurricanes:** every few weeks one comes off the Gulf, warned a day ahead. Sideways wind,
  debris, and a blackout: street lights and windows go dark, and shop registers are there for
  the taking until the power comes back.
- **Moonshine:** buy a copper still and mash at a general store, set it up out in the country,
  and it cooks a jug every five hours. Bars and liquor stores buy it out the back. The ATF
  smashes untended stills, and visits the ones you're standing next to.
- **The armored car:** buy the day's route in a bar, or catch one by chance. It won't blow up,
  but shoot or ram it enough and it dies on the road; drop the crew, then blow or pry the back
  doors for the bank's bags. Every cop in the county comes.
- **Mob funerals:** when a don or capo dies, the family buries him at his city's church the
  next morning, 9 to 1. Pay your respects ($100, standing with the family, unless the widow
  recognises the man who put him there), or hit the rival boss standing on the steps.
- Seven new achievements for the above. `node tools/game1x.mjs` tests every one of them (part of
  `npm run check`).

## Earlier: interrogation round

- **Interrogation:** anyone tied up, or with their hands up at gunpoint, can be interrogated.
  Wear down their resolve (ask, bribe, threaten, rough them up, or make it hurt: the knife, a
  shot to the leg, broken fingers). Pain breaks people fastest, but people in agony lie, and
  screams carry. Broken, they give up their money and where the rest is hidden, who they work
  for (evidence, and the boss's club on the map), the safe combination at work, secrets to
  blackmail others with, what the police have, and who the rat is. Then let them go, knock
  them out, or finish it.
- **Knockouts last:** anyone knocked out stays out for a whole day, unless someone wakes them:
  you can (the "Out cold" menu: pick them up, wake them, tie them), and passers-by who find them
  will (and may report an assault). Anyone with their hands up can be knocked out too.
- **Kill the detective:** every case they were working loses most of its progress, stalls for
  two days while a new detective starts over, and loses a witness.
- **Achievements:** milestones for every way to play, at the bottom of Menu > Status.
- **HUD weapon names:** every weapon shows its own name (the newer ones read FISTS before).

| Your note | What changed |
|---|---|
| Buildings bigger, not NPCs smaller; scale everything to the player | Characters keep their size. Blocks, buildings, facades, doors, roads (four lanes) and the map (880×880) grew around them, and cars are scaled to fit the lanes |
| Copy the old artifact's look | Buildings and ground are painted by the original's own routines |
| Start chilled; stop blaming me for things I didn't do | Street trouble ramps up with days played, infamy and jobs. Anyone who attacks you is fair game, and shooting back isn't a crime |
| Shops better indicated; NPCs mark points of interest | Icon boards and OPEN / CLOSED lamps by every shop door. Shops you pass go on the map. Ask anyone "Know any good spots?" and they pin a place. Rumours drop fuzzy pins |
| Gore; broken animations; menu closing instantly; debug menu | Blood that stains, sprays, pools and gibs (toggle in Settings). Natural walk cadence and working NPC punch poses. Sheets ignore the tap that opened them. Menu > Debug has cheats, time, weather, teleports and spawners |
| Stop Witness | Fleeing witnesses in shouting range get Intimidate / Bribe chips |
| Real minigames | Lockpicking, hotwiring, safecracking (a Mastermind-style PIN pad: green and amber lights, 10 tries), blackjack, slots, pool, darts and craps |
| Inventory; know what drugs we're buying | A Pockets tab with pixel icons and actions. Seven named 70s street drugs, each with a street name, effect, duration and comedown, sold by dealers |
| Hire NPCs to do jobs | People who like you will do your family job for a cut, boost a car, rob a store, run numbers or scout a mark |
| Hostile animals must be killable | Blows stagger animals and wounded animals limp |
| Supernatural references, and Sinestro as "Fear Man" | The Fear Man waits under a dead tree deep in the Dustwater flats from 1 to 4 AM and gives you the **Yellow Ring**: a 46-construct library, a beam, and giant construct swings with bare fists, all powered by Will, which fear refills. There's also a drowned captain, a sasquatch, a UFO, the gentleman at the crossroads, and Old Scratch |
| Improvised weapons | The original's 32 props are back, with its sprites, durability, throwing and per-material effects |
| Lockpicking / hotwiring; sneaking sprite | Doors and cars can be picked, parked cars must be hotwired, and sneaking crouches |
| Clothes, hats, hair, facial hair | Tailor (12 jackets, 10 shirts, 8 trousers, 4 collars, 7 hats in 7 colours, shades) and barber (8 cuts, 6 colours, moustache or beard) |
| Playtest 100 days with notes | See [docs/PLAYTEST.md](docs/PLAYTEST.md). `tools/playtest.mjs` plays N in-game days through the real controls and writes a report |

## Later rounds

| Area | What's in the game |
|---|---|
| The opening | Entirely in-engine and letterboxed: the gunmen's car on the desert highway (they ask your name), the walk into the sand, a last-words choice, two shots, the crawl back with a gut wound (its own prone sprite sheet, built from your colours), the don's car, and a back-room conversation that sets your standing. `?quick` in the URL skips it |
| Unfinished business | The two gunmen are real people. Leads arrive over the first weeks, they know you on sight (flee or draw), and one of them can be made to name the family that paid |
| Law & heat | Detectives build cases from witnesses, your face, clothes, the body, the weapon and the car (Heat tab, with police sketches). Unsolved killings in a similar style get linked to a serial-killer profile with task forces, curfews, decoys, frisks and stakeouts. Serious bounties mean jail (and jailbreaks) |
| Street business | Loan sharking with weekly juice, deadbeats, collateral and favours. The bookie in every bar (and fixed races). Cops and captains on a weekly envelope, with Internal Affairs sweeps. Rats who flip to the FBI, found through clues and dealt with three ways. Truck hijacking and fences |
| Money & families | Dirty cash, suspicion and Treasury audits, laundering through businesses you own or casino chips. Living rival families with wars, rackets, hit squads and city loyalty. Vendettas: the kin of the people you kill find out and come for you, hire guns, blackmail you or go to the police |
| Reputation | Honor and infamy shape what you say (you cuss when you're a thug), how people react, who's attracted to you (flirt and seduce) and, at the top end, prices and whether witnesses talk. Feared names get steeper bounties |
| Bodies & gore | Wounds show where they landed (and only on the side you can see), close when healed, and bruises age. Knife work: heads, limbs, skinning, bagging remains. Shotgun headshots. Carrying bodies, unconscious people and game (the red wagon), rope and tape, trunks, cinder-block shoes |
| Weapons | Derringer to tommy gun, a crossbow, blades, a sap for knockouts, silencers, and the original's 32 improvised props |
| Cars | Car-length following distance, lanes held without weaving, intersections kept clear, box collisions, and GTA-style durability (dents where hit, cracked glass, smoking engine, then fire, then the bang). Tyre marks and dust plumes |
| Night & style | Strip clubs, costume shops and masks, street workers, busier bars, lit windows and colour neon at night. Dozens of jackets, shirts, trousers, hats, haircuts and facial hair |
| The emotional spectrum | Nine rings, each leading to the next. The Fear Man's five lessons (the midpoint is killing Hal Jordan; the finale gives the Sinestro Corps uniform and sets up a space sequel). Or side with Hal: find his wife Carol (his battery, and the violet path), take a spare ring to Guy Gardner, then fight the Fear Man for the green ring and uniform. Red comes from rage, orange from killing Larfleeze and searching his hoard, black from a churchyard at midnight, white from the dead tree at dawn, violet from being loved, indigo and blue from the people the crystal shows you. Each has its own bolt, RING power and way of refilling Will (orange keeps ghosts of the people it kills and fills on crimes that pay). Swap rings and uniforms at any wardrobe |
| World memory | One event log of what you did, where, whether you were seen and what you wore. It feeds the morning Herald (newsboys shout the headline; a copy waits when you sleep), street gossip (with a double take if you walk past in the described shirt) and a detective's brown sedan outside your place once a case warms up |
| The crew | Everyone who rides with you joins a roster that hangs out in your club's back room. Loyalty, mood, needs, weekly wages, personal troubles to help with, and morale that changes how they fight (and whether they walk, or talk) |
| Plan board | In the back room: pick a bank or casino, case it for the 2 to 4 AM shift change, choose quiet, loud or an inside man, pick the vault tool, and put the crew on wireman, lookout, muscle and driver. The take is split |
| Gunfights | Take cover by standing still armed beside anything solid (walls, trees, furniture, cars); shots from that side mostly hit the cover. Near misses suppress: pinned gunmen crouch, hold and fire slower |
| Light & seasons | Rim light: people catch the colour of the nearest lamp, sign, headlight, fire or muzzle flash on the side facing it. The calendar turns: winter snow comes south, autumn leaves, holidays (fireworks, jack-o'-lanterns, Christmas lights). Footprints in snow, sand and mud; idle people smoke and fidget; conversations push the camera in |
| Graphics | A WebGL renderer finishes every frame on the GPU. Coloured light comes from lamps, neon, windows, headlights, sirens, fire and muzzle flashes. Per-pixel normals are derived from the art itself, so sprites and walls catch light directionally. Also bloom, blue night fill, desert heat shimmer, a colour split when you're hit, film grain and optional CRT scanlines. It falls back to the classic Canvas2D renderer automatically (or via Settings > Graphics) |
| Art style | The default look follows the Pokémon Emerald overworld: flat, saturated colours with cool shadows and warm highlights, dark outlines on everything that stands up, grass with tufts and flowers, shore foam, desert ripples, cliff lips, round-canopy trees and tiered pines. Buildings get pitched shingle roofs or parapet roofs with rooftop kit, framed glass with glints (lit warm at night) and striped shop awnings. People, cars and interiors get GBA palettes, and every weapon anchor and pose is unchanged. Settings > Art style switches back to Classic |
| Your legend | A running epilogue written from your honor, infamy, kills, crew, rings, heists and endings, in the Stats tab and after each road to the top |
| Tracking | TRACK beside the minimap (T on a keyboard) cycles your waypoint through the current job, quest errands, leads and map tips, following moving targets. The Jobs tab lists them with a Track button each |
| Places & people | Five story characters with chaptered quests, landmarks and hidden tins, destructible street furniture, dust storms in the desert |

## TypeScript

Modules are `.js` or `.ts`. The build transpiles TypeScript per file, and `npm run typecheck` runs the strict type check over every `.ts` module against `types/rhapsody.d.ts`, which types the global `R` namespace and the main game objects. Typed so far: the core utilities, the simulation worker, the route planner, the chunk scheduler, the WebGL renderer, the tracker and the new art. `npm run check` runs typecheck, build and smoke in one go. New modules are written in TypeScript; older ones are converted as they're touched.

## Tools

- `node tools/smoke.mjs`: boot and tick check.
- `node tools/scenarios.mjs`: real-input scenario suite.
- `node tools/interro.mjs [sequel]` and `node tools/game1x.mjs`: interrogation, and this round's game 1 features.
- `node tools/playtest.mjs DAYS OUT STYLE`: the long-haul bot (styles: all, shark, fixer, hijacker).
- `node tools/nightly.mjs [days] [--update-baseline]`: runs the bot per style and flags any metric that drifted more than 40% from `tools/baseline.json` (writes `nightly-out/summary.md`).

## Architecture

Plain ES2020, no dependencies and no bundler. Every module hangs off a global `R` namespace, and `tools/build.mjs` concatenates the modules in filename order into one HTML file.

| File | Responsibility |
|---|---|
| `00_core.js` | RNG, value noise, math, event bus, spatial hash, safe storage |
| `01_data.js` | Cities, building types, jobs, archetypes, weapons, items, outfits, vehicles, animals, names, radio |
| `02_world.js` | World generation: coast, biomes, river, city grids, docks, parks, highways (grid-aligned routing), lane-flow data, intersections and lights, countryside, street furniture. Also the world mutations (build on lot, destroy) |
| `03_art.js` | Procedural pixel art: chunk-cached terrain and buildings, cars, animals, minimap |
| `03_oldsprites.js` | The original build's character painter and palette, ported verbatim |
| `03_oldtown.js` | The original build's building painter and ground textures, ported verbatim |
| `03_sprites_emerald.ts` | The Emerald art style: ground tiles and edges, nature and street objects, buildings, GBA palettes for people, cars and interiors, and the Art style setting |
| `03_sprites.js` | Adapter from people to the original's looks, pixel text, hats, interior floors, walls and furniture, buildings and signs |
| `04_population.js` | The named population: households, jobs, schedules, memories, life facts, the daily life tick (aging, marriage, births, deaths, jobs) and city growth |
| `05_actors.js` | On-screen people and animals: A* pathfinding, steering, sidewalk walking, perception, reactions, witnesses reporting, spawning |
| `06_traffic.js` | Lane driving, lights, yielding, arcade physics with drift, chase steering, collisions, road rage, spawning |
| `07_combat.js` | Melee, hitscan guns, thrown weapons, explosions, knockouts vs kills, self-defence rules, NPC fight AI |
| `08_law.js` | Crimes, witnesses, reports, incidents (responding, pursuit, search), arrests, bounties, bounty hunters |
| `09_env.js` | Clock, weather, fire, gasoline, hydrants, lighting queries, camera, particles |
| `10_life.js` | Bridges named people to on-screen actors, construction crews, street events |
| `11_dialog.js` | Greet / antagonize / defuse, chatter, talk trees |
| `12_jobs.js` | Families, ranks, contracts, rackets, leads |
| `13_player.js` | The player |
| `13_goods.js` | Inventory icons and actions, street drugs, dealers, hired help |
| `13_poi.js` | Shop signs, discovered shops and pins on the map |
| `13_props.js` | Improvised weapons (the original's 32 props) |
| `13_ring.js` | The Fear Man and the Yellow Ring: construct library, beam, swings |
| `13_spooky.js` | Legends: the ghost, sasquatch, UFO, crossroads dealer, Old Scratch |
| `13_style.js` | Wardrobe and grooming: clothes, hats, hair, facial hair |
| `14_audio.js` | Synthesized SFX and procedural radio |
| `15_input.js` | Touch joystick, buttons, keyboard |
| `16_debug.js` | The debug menu |
| `16_minigames.js` | Lockpicking, hotwiring, safecracking, blackjack, slots, pool, darts, craps |
| `16_ui.js` | HUD, context chips, sheets, interiors, shops, phone, fishing, burglary, heist, menu, map |
| `17_render_gl.js` | The WebGL back end: light pass with art-derived normals, half-size bloom, final composite with the overlay layer, heat, hurt split, grain and CRT; fallback on context loss |
| `17_render.js` | Rendering, lighting, weather, speech bubbles |
| `19_interiors.js` | Walk-in rooms: layouts per building type, occupants, furniture actions, searching, register robberies |
| `12_campaign.js`, `12_stories.js` | Family campaigns and endgame routes; the five story characters |
| `13_*` (salvage, vice, relics, remains, water, route…) | Destructible furniture and exploration, relationships and affairs, supernatural rewards, bodies, swimming and sinking, waypoints |
| `14_opening.js`, `14_desert.js` | The in-engine opening and crawl sprite; hunting the men who shot you |
| `14_case.js`, `14_profile.js`, `14_vendetta.js` | Detective cases, the serial-killer task force, vendettas |
| `14_money.js`, `14_turf.js` | Dirty money and laundering; living rival families |
| `14_shark.js`, `14_payroll.js`, `14_rat.js`, `14_hijack.js` | Loan sharking and the ponies, cops on the payroll, rats, hijacking |
| `14_butcher.js`, `14_carry.js`, `14_arms.js` | Wounds and knife work, carrying and the red wagon, new weapons |
| `14_charm.js`, `14_honor.js`, `14_night.js`, `14_fashion.js` | Reputation-driven dialogue and attraction, reputation perks, nightlife and masks, clothes and hair |
| `14_cars.js`, `14_dust.js` | Car damage, tyre marks and dust; dust storms |
| `16_debugx.js`, `19_slammer.js`, `19_realty.js`, `19_vault.js` | Debug shortcuts for every system; jail; property; bank vaults |
| `18_main.js` | Game object, loop, daily tick, save/load (seed + world-mutation log + population snapshot) |

Saves go to `localStorage`. The world regenerates from its seed, and construction or destruction events are replayed on top of it.
