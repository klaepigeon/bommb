# Rhapsody: The Brass Coast

A mobile-first, top-down crime sandbox. It's 2026 on the Brass Coast, but the seventies never ended. You're Nicky "The Mook" Marchetti: fedora, pinstripe suit, shades, gold chain. You work your way up the Vane family in a region of five cities and about a thousand named people who live their own lives.

This is a ground-up rebuild of the original single-file *Rhapsody* (Port Hollow) artifact.

## Play

- **Local:** open `dist/index.html` in a browser (phone or desktop). No server or install needed.
- **Build from source:** `node tools/build.mjs` bundles `src/` into `dist/index.html` (standalone page) and `dist/rhapsody.html` (body-only, for publishing as a claude.ai artifact).
- **Smoke test:** `node tools/smoke.mjs` boots the build headless at phone size and fails on any page error. It needs Playwright.

### Controls

| | Touch (default) | Keyboard |
|---|---|---|
| Move | Drag anywhere on the left half. Push far to run | WASD / arrows, Shift runs |
| Use (doors, cars, bodies, phones) | **A** (its label shows what it will do) | E |
| Hit / shoot | **B** | Space / F |
| Switch weapon / holster | **WPN** (hold to holster) | Q |
| Greet / Antagonize / Talk / Rob | Chips that appear near a person | G / V / T, X defuses |
| Cool (slow-mo), Mask, Sneak, Item | Small buttons | Z, M, C, I |
| Driving | Point the stick where you want to go. **Brake** drifts at speed | Space brakes, H horn, R radio |
| Menu / map | Tap the HUD / minimap | Esc / Tab |

## What changed from the old build

| Your note | What the rebuild does |
|---|---|
| Mobile-first interface | Floating joystick, thumb-sized A/B buttons, contextual action label, bottom-sheet menus, safe-area aware, portrait and landscape layouts |
| Much bigger map, multiple cities | 640×640-tile procedural region: **Port Hollow** (harbor), **New Avalon** (metropolis), **Dustwater** (desert), **Pinecrest** (snowy forest), **Bayou Clair** (marsh), four hamlets, farms and cabins, a river, a lake, and highways between them. About 780 buildings |
| ~1,000 named NPCs + procgen citizens + animals | About 1,010 named people with homes, jobs, spouses, kids, schedules, memories and opinions of you. Anonymous pedestrians and drivers fill the streets. Wildlife is biome-specific: deer, wolves, bears, boar, coyotes, gators, rattlesnakes, birds, cattle |
| Replace Claude dialogue with RDR2-style greet/antagonize + scripted choices | No text input anywhere. **Greet** builds familiarity (twice and you learn their name), **Antagonize** gets personality-driven reactions (cower, retort, laugh, square up, call a cop), **Defuse** calms a fight, **Talk** opens scripted trees per role (bartender, fence, cop, doctor, priest, mechanic, Don, shopkeepers, kids, sweethearts) |
| Text input and systems broken | The Claude/text-input path is gone. Every system was rewritten and is exercised by a headless test run |
| Player should look like a tough mafia mook | Heavy build, pinstripe suit with lapels, fedora, sunglasses, mustache, gold chain. Tailors sell other 70s looks |
| Smarter, more reactive NPCs | They react to your gun, mask, blood and drunkenness. They flee, cower, fight back or beg. They chat with each other about real town news and their own families. Grudges come from killing kin. Drivers get road rage |
| Stop punishing the player (random property-damage wanted) | **RDR2-style law:** a crime only counts if someone *sees* it. Witnesses must physically run to a payphone or a cop, and you can stop them by scaring, paying off, or worse. Police search your last known position, and you escape by breaking line of sight and leaving the circle. Masks keep your name off the bounty. Bounties are per city and payable at any police station. **Accidents are never crimes**: bumping lamps, hydrants or cars is free, and cops warn you before minor stuff escalates. Fistfights someone else agreed to aren't assault, and self-defence is legal |
| More dynamic traffic | Lane-following cars with traffic lights, yielding at intersections, following distance, honking, buses and trucks, parked cars, patrol cars, ambient police chases, reckless drivers, and drivers who get out and fight you after a crash |
| NPCs build their cities and have children | One in-game day = one year of aging (adjustable). People marry, have babies, grow up, move out, take jobs, grow old and die. Prosperous cities break ground on new houses and shops (construction crews included) and rebuild what burns down. It's all reported in the in-game newspaper |
| More fun and more environmental systems | Weather (rain, storms, fog, heatwaves, snow up north). Wind-driven wildfire that rain puts out. Lightning. Gasoline trails you can light. Molotovs and dynamite. Hydrant geysers. Shootable street lamps (darker streets mean fewer witnesses). Hunting, skinning and fishing. Three procedural radio stations (funk, disco, outlaw country). Bar fights, block parties, weddings, hitchhikers, roadside ambushes, pickpockets, muggers. Bank heists, store robberies, burglary, protection rackets, buying businesses and safehouses, a crew, a sweetheart, and a Cool slow-mo meter |

## Architecture

Plain ES2020, no dependencies and no bundler. Every module hangs off a global `R` namespace, and `tools/build.mjs` concatenates the modules in filename order into one HTML file.

| File | Responsibility |
|---|---|
| `00_core.js` | RNG, value noise, math, event bus, spatial hash, safe storage |
| `01_data.js` | Cities, building types, jobs, archetypes, weapons, items, outfits, vehicles, animals, names, radio |
| `02_world.js` | World generation: coast, biomes, river, city grids, docks, parks, highways (grid-aligned routing), lane-flow data, intersections and lights, countryside, street furniture. Also the world mutations (build on lot, destroy) |
| `03_art.js` | Procedural pixel art: chunk-cached terrain and buildings, people, cars, animals, minimap |
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
| `14_audio.js` | Synthesized SFX and procedural radio |
| `15_input.js` | Touch joystick, buttons, keyboard |
| `16_ui.js` | HUD, context chips, sheets, interiors, shops, phone, fishing, burglary, heist, menu, map |
| `17_render.js` | Rendering, lighting, weather, speech bubbles |
| `18_main.js` | Game object, loop, daily tick, save/load (seed + world-mutation log + population snapshot) |

Saves go to `localStorage`. The world regenerates from its seed, and construction or destruction events are replayed on top of it.
