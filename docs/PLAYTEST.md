# Playtest notes: 100 in-game days on the Brass Coast

Two playtests, both run with `tools/playtest.mjs`, a bot that plays through the real
controls (virtual stick + buttons, A* navigation). Every in-game day it:

- **9 AM:** takes and works a family job (collect, lean on, rob, boost, hit), or hands it to a hired friend.
- **1 PM:** shops, visits the tailor and barber, grabs loose junk, greets people, asks for tips, hires people, wanders, and picks fights.
- **4 PM:** robs a store, goes hunting, or buys property. If the cops come, it runs.
- **6 PM:** steals a car and drives it (and bails when it catches fire).
- **10 PM:** goes to a bar, club or casino (dealers, drugs, darts, blackjack), burgles a house, or hunts a legend (Fear Man, ghost, UFO, sasquatch, crossroads).
- **Overnight:** sleeps in a hotel or skips ahead.

It logs a snapshot every day plus every toast, story card, crime, and hit the player takes. It also screenshots every ten days. One day is one year of life for the population (the default life speed), so 100 days is a full century for the NPCs.

Final run: **100 days in 56 seconds of wall time, 0 page errors.** Render check at 390×844 @3x: steady **60 fps** downtown by day, at night, in a thunderstorm, while driving, and inside a packed disco.

---

## Playtest 1: what was missing or broken

### Run 1, first pass (before fixes)

| What | Seen | Why |
|---|---|---|
| **Player died 10 times in 3 days** without committing a crime | One car bump did 6×18 damage in the same instant | `runOver` hurt the player every frame of contact and knocked you *along* the car's path, into the next hit |
| Bot couldn't reach anything | Every goal "not reached" | Tooling bug (the pathfinder returns `{x,y}` nodes); fixed in the bot, not the game |

### Run 1, 100 days

| Day | People | Kids | Avg age | Households |
|---|---|---|---|---|
| 2 | 955 | 189 | 40 | 283 |
| 30 | 849 | 100 | 46 | 228 |
| 59 | 592 | 49 | 50 | 147 |
| 98 | **292** | **29** | 53 | 79 |

**The population collapsed.** The causes, from `dailyTick`:

- Births were blocked as soon as a home reached capacity +2.
- Grown kids only moved out 60% of the time, and only if a free home existed.
- Nobody ever moved to town.

Over a simulated century the coast emptied out and the towns aged.

The other findings from this run:

- **Cars were the #1 damage source** (1,234 HP of damage to the player over 100 days). Drivers only braked for someone standing dead-centre in their lane, so anyone half a step off the lane line got clipped.
- **"Police pursuit in progress nearby" fired 95 times.** Ambient chases toasted every time, from anywhere on the map. This fed the "too much chaos" feeling.
- **Weather toasts fired about 100 times,** including "Weather: Clear." and "Weather: Overcast."
- **"New on your map" came in bursts** of 4 or 5 separate toasts when you walked into a new downtown.
- **Ring rockets hurt and burned their wearer.** They set fires and logged "Explosives" crimes on nobody (84 "Nobody saw the explosives" toasts).
- **Crashing a car killed you outright.** At 0 HP the car blew up with you inside, with no warning.
- **Port Hollow's prosperity sank to 1/100.** Every crime drains prosperity and adds heat. That's intended, but a pure-crime run makes the home city grim. Worth watching.

### Fixes made from playtest 1

1. **Migration keeps towns alive** (`P.migrate`):
   - When a town drops below 94% of its founding size, 1–4 new families (couples aged 22–38, often with kids) move into empty homes, and the paper reports it.
   - When a town tops 118%, young singles leave for the big city.
   - Births are allowed up to capacity +4, and grown kids move out 80% of the time.
2. **Getting hit by a car:**
   - One hit per bump (1.2 s cooldown), capped at 40 damage.
   - You're thrown clear of the car, not along its path.
   - The driver slams the brakes and honks.
   - Drivers now brake for anyone who'd be clipped by the bumper, not just someone dead-centre in the lane.
3. **Your own car always burns first.** Your car can't explode from under you without a warning: it catches fire ("Your car is on fire. Get out (A)!") and gives you about 6 seconds.
4. **Ambient police chases** only mention themselves if they're within 25 tiles, and at most once a day.
5. **Ring hard light never hurts the wearer.** Ring rockets don't start fires, and don't log crimes unless they actually hurt someone.
6. **Weather toasts** only for rain, storms, fog and heatwaves.
7. **Map discoveries** are batched into one line ("New on your map: A, B, C and 2 more").
8. **Caps** on loose props (200) and ground decals (480) so century-long sessions stay lean.

### Run 3, 100 days (after the fixes)

| Day | People | Kids | Avg age | Households | Buildings | Cash | Rank | Jobs | Crimes | Deaths | Shops known |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 1011 | 234 | 38 | 331 | 598 | $67 | Associate | 1 | 0 | 0 | 20 |
| 17 | 1044 | 241 | 42 | 289 | 599 | $20 | Soldier | 5 | 28 | 0 | 74 |
| 33 | 990 | 166 | 43 | 240 | 607 | $181 | Capo | 10 | 60 | 1 | 105 |
| 49 | 950 | 164 | 44 | 212 | 617 | $146 | Capo | 12 | 89 | 3 | 156 |
| 65 | 947 | 155 | 44 | 190 | 620 | $247 | Capo | 17 | 112 | 5 | 158 |
| 80 | 954 | 156 | 45 | 197 | 619 | $1,113 | Underboss | 20 | 139 | 6 | 178 |
| 94 | 957 | 194 | 42 | 205 | 618 | $3,029 | Underboss | 30 | 171 | 8 | 182 |
| 100 | **952** | **181** | **43** | 204 | 622 | $1,892 | Underboss | 30 | 180 | 9 | 196 |

The coast now holds about 950 people for the full century: births, weddings, funerals, new families and new construction every day.

Car damage fell from about 12 to about 8 HP per day. What's left is mostly the bot sprinting across four-lane roads without looking. Deaths fell to 9 in 100 days, mostly from bailing out of burning cars at speed (fall damage), plus gunfights and animal attacks.

### Notes by system

**Early game and pacing**
- **Day 1 is calm.** The first street events show up around day 2–3, and violent ones (brawls, robberies, foot chases, ambushes) ramp in with the square of the calm factor.
- **No false blame.** None of the 180 crimes logged was something the bot didn't do. Every one traced to its own action: burglary, robbing a till, assault after antagonizing, possession in front of a cop.
- **Self-defence is free.** Anyone who hits you first can be put down without a crime, and shooting back at a shooter doesn't count as discharging a firearm.

**Progression**
- **Associate → Underboss in about 70 days,** Consigliere reached in an earlier run, from 30 finished jobs.
- **About 9% of jobs were abandoned** by the bot (missing target). That's a fair failure rate.
- **Money stays tight until mid-game** (hospital bills, bounties, fees), then climbs fast once you're Underboss. It feels right, but the late game could use more to spend on.
  - *Future:* businesses and car upgrades.

**Law**
- 2 arrests, 2 bounties paid and 5 "You lost them" escapes over 100 days. A lot of "Nobody saw the …" results: RDR2-style witnessing works.
- **Stop Witness:** a fleeing witness in shouting range grabs focus. Intimidate works best with a gun out or high infamy; bribes are only charged when accepted.
- **Possession** (taking drugs where a cop can see) is a minor crime: a warning first, then a small bounty.

**Life sim**
- The paper runs every day for the whole century: weddings, births, deaths of old age, new families, ground-breakings and ribbon-cuttings, and the odd arrest after a hired hand's botched robbery.
- Towns rebuild what burns down and grow new houses under housing pressure.

**Legends**
- The Fear Man was found on the first try at 2 AM from the rumour's direction ("east of Dustwater") and gave up the ring.
- The ghost, UFO (abduction worked: missing time and +10 max health), sasquatch sightings (the paper paid $150) and the crossroads dealer all triggered.
- Old Scratch didn't appear in these runs: the bot's marsh visits all landed inside Bayou Clair's city limits. It's reachable through the debug menu, and its spawn logic is covered by the legends test.

**Drugs**
- Coke, angel dust, heroin, reefer and LSD were all bought and taken. Every one showed its name, street name, effect and comedown before purchase.
- Comedowns hit, and heroin's double-dose overdose sends you to hospital for a day.

**Minigames**
- Darts, blackjack, lockpicking, hotwiring (the bot rarely needed it: it mostly hotwired through the debug path) and safes all opened, played and paid out without errors.

**Improvised weapons**
- Junk turns up on sidewalks and in rooms.
- Bottles shatter, pans stun, heavy props slow you down, thrown props bounce off people and cars.

**Performance**
- Sim tick p95 is **0.3–0.6 ms** headless with 40–60 actors and 15–25 cars.
- Rendering holds 60 fps in every test scene.

---

## Playtest 2: polish and game feel

Hands-on passes through the screenshots at every tenth day, plus targeted captures (street at noon, night downtown, storefronts, interiors, minigames, tailor, inventory, map).

| Felt wrong | Change |
|---|---|
| Melee hits felt weightless | **Hitstop:** a 35–85 ms slow-down on every landed blow, scaled by weapon damage, and a shorter one when you get hit. Bigger shake for heavier weapons |
| Camera dragged behind you on foot | The camera **leads your movement** (about 22 px ahead horizontally, 14 px vertically) like it already did in cars |
| Toasts sat under the Greet / Antagonize chips in landscape | Toasts rise to just under the HUD while the chips are showing |
| The talk tag showed a keyboard "T" on phones | Key hints only appear if you last used a keyboard |
| Shop signs were hard to read | Shops hang a 2× pixel icon board beside the door (a gun for the gun store, a mug for bars, scissors for the barber…) and an OPEN / CLOSED lamp that glows at night |
| Building signs cut off long names | Signs wrap to two lines at a word boundary, drop filler words, and only abbreviate as a last resort |
| Ring constructs and UFOs looked muddy at night | Hard light and alien light draw after the lighting pass, so they glow |
| The menu tab strip collapsed in landscape | Fixed |
| The phone sheet closed as soon as you opened it | The tap that opens a sheet can no longer press a button underneath |

## Still on the list

- **Pedestrian vs car:** drivers now brake properly, but crossing a four-lane road at a run is still dangerous. A "walk signal" at lit intersections would teach safer crossings.
- **Late-game money sink:** cash piles up after Underboss. Candidates: buying and upgrading businesses, better safehouses, and car tuning at the garage.
- **Home-city prosperity:** a crime-heavy player can drag their home town's prosperity very low. Consider a family "clean-up" job that restores it.
- **Old Scratch discoverability:** give the marsh rumour a pin further from Bayou Clair's limits.
- **Hunting:** animals often flee before you're in range with a rifle. A crouch-stalk bonus or a hunting call would help.

---

## Playtest 3: systems, mechanics and visual fidelity (XX7X build)

Three passes over the newer systems:

- `tools/playtest.mjs` for **20 and then 40 in-game days**, now logging the state of every new system each day: detective cases, dirty money, family wars, grudges and the serial-killer profile.
- `tools/scenarios.mjs`, a new scripted run through the **real controls** (WASD, SPACE, E, M, the interaction chips and the menus). It screenshots 20 moments at 2× and times frames in a busy scene.
- Close-up render sheets of masks, wardrobe, corpses, weapons and overhead props.

**Result:** 0 page errors across all runs. The 40-day bot run took 28 s of wall time (tick p95 0.3–0.6 ms). Downtown New Avalon at 10 PM holds 16.7 ms frames (vsync-bound) with 46 actors and 12 cars.

### Bugs found and fixed

| Found | Symptom | Fix |
|---|---|---|
| NPCs could close the name entry | A passer-by's greeting or talk sheet replaced "Who are you?", so the new opening never started | Name entry is modal: no other sheet can open over it, background taps are ignored, and the world is paused while it's up |
| The don's dialogue could be dismissed | Tapping the dimmed background mid-conversation left the opening hanging | The back-room scene is a cutscene: the world is paused and other sheets and background taps are blocked until the first job is given |
| Reloading during the desert crawl | Autosave during the crawl reloaded you in the sand with no car coming | The crawl state and the highway point are saved |
| Point-blank shotgun didn't kill | 7 pellets × 13 = 91 damage against 100 HP; the target shrugged it off and no head burst | Shotgun 16 per pellet, sawed-off 19. Point blank now kills, and the head bursts |
| "Out of ammo" spam | 34 toasts in 20 days | A dry-fire click, an automatic swap to your best melee weapon, and the warning at most every 20 s |
| Your family at war in week one | "Your family is at war" by day 5 made the calm opening hostile | Families at war with yours only start after day 7 and once you're a Soldier |
| Warrants for family work | 4 warrants in 40 days, mostly from contract hits the family ordered | Contract hits are marked, and the family leans on the file (×0.45 case progress). Rank shields you too (−12% per rank). The Heat tab says so |
| Hired guns every other day | Six hired-gun attacks in ten days from two grudges | Hiring now builds up slower (+12 a day, attacks at 60) than a relative hunting you in person (+20, attacks at 40) |
| Body menu listed "Cut up" twice | The knife action came from both the butcher and carry menus | De-duplicated |
| Strip club and costume shop looked unlit | They used the pale default shop palette | Strip club uses the club palette; costume shop uses the arcade's purple and pink |
| Name sheet cut off on phones | "That's me" fell below the fold at 390 px tall | Labels sit inline with their fields; the sheet fits with room to spare |
| Dancers busked | Strip club dancers said "Spare a dime for the music?" | Dancers have their own lines |
| The don wasn't in the back room | The conversation happened with an empty chair | The don is seated beside you for the talk |
| Serious arrests only fined you (previous report) | Cash in your pocket meant you always paid a fine, and jailbreaks never came up | A bounty of $150+ means a cell; smaller bounties let you choose between the fine and the cell |

### What the 40-day run says about balance

| System | Seen over 40 days | Read |
|---|---|---|
| Detective cases | 11 cases: most burglaries went **cold**, and 2 murders reached **warrant** | Burglary evidence decays well. With the contract shield, murders done for the family should now go cold more often, while freelance ones still get you a warrant |
| Dirty money | The bot never laundered: about 95% of its cash was dirty, but it never made a big purchase, so suspicion stayed at 0 | Correct: spending in small amounts is safe. The audit only comes after a big dirty purchase, as intended |
| Family wars | A war was running most days, ending in 3–8 day sit-downs; shootouts showed up in the war cities | Lively without flooding the streets |
| Grudges | 5 relatives were created by the first murder; 2 were children who wait; later the hired guns | After the tuning, about one attack every 5 days per rich relative |
| Serial killer | 1–2 unsolved bodies, no task force | Correct: the bot doesn't kill in a pattern. Tested separately with 4 matching killings: the task force forms and escalates, and frisking you with a bag of remains names you |

### Visual notes (screenshots in `playtest-out/scenarios` when run locally)

- **Opening:** the desert now spawns on real sand. Crawling reads as a man face-down dragging himself, at 0.7–0.9 tiles/s, leaving a blood trail. The highway is 19–27 tiles off, so about 25–35 s of crawling. That feels right: long enough to feel it, short enough not to drag.
- **Night downtown:** lamp pools and neon read well. The fringes of the cities are dark by design; the cores are lit.
- **Interiors:** the bar fills to 11–13 people at night, the strip club to 17–19, with dancers on the runway.
- **Gore:** a point-blank shotgun head burst sprays bone and brain flecks in the direction of the shot. Knife work leaves arms and legs scattered with blood trails, which can be bagged and sunk.
- **Masks:** all twelve read distinctly from the front, and horns, ears and snouts show from the side.
- **Wardrobe:** the new jackets, shirts and trousers render cleanly. Pompadour, mohawk, Jheri curl and locs read well; the mullet is subtle from the front and clearer from behind.
- **Wagon:** the red wagon with its black handle reads at 1×; the body lies in it with legs over the edge.

### Still on the list

- ~~Night lighting in the outer streets could use lit windows and more neon spill.~~ Done: homes keep lamps on in the evening (amber, or TV blue), with a few night owls after midnight. Window light spills onto the walk. Neon signs now come in five colours, pool on the sidewalk, and a few flicker on the fritz.
- ~~The desert crawl could use a vulture shadow for mood.~~ Done: three vulture shadows circle you while you crawl. Heat shimmer is still open.
- ~~A bot routine for laundering and flirting.~~ Done: `tools/playtest.mjs` now flirts at bars and washes chips on casino nights. In the 30-day run it flirted twice (0 errors). No casino night was rolled, so laundering is still unexercised by the bot.
