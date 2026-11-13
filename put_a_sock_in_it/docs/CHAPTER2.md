# Chapter 2: The Lobby

Kurt comes out of "outside" into the ground floor of the building. Flat 27 is two floors up. The chapter is built as a small, interconnected dungeon: some routes are closed at first, there's more than one way past each obstacle, and coming back to earlier rooms opens new ones.

**Where it lives:**

| What | File |
|---|---|
| Level | `scripts/levels/lobby.gd` |
| Building | `scripts/levels/chapter2/lobby_build.gd` |
| AI | `scripts/ai/` |
| Building's working parts | `scripts/world/ch2/` |
| Dialogue | `data/dialogue/lobby.json` |
| Test | `tools/chapter2_test.gd` |

## The building

The building is 24 × 14 m on plan, with three floors 3.2 m apart. Each floor has a corridor down the middle and flats on either side.

**Fixed features, on every floor:**
- A switchback stairwell at the east end. The steps are scenery; underneath them are ramps that people actually walk on.
- The lift shaft beside the stairwell.
- A ladder closet at the west end of each corridor.

**Ground floor**
- The lobby, with its entrance chained shut.
- The mailboxes, and the directory with 27's name scratched out.
- The super's office, with a reception window onto the lobby, and his flat (1) behind it.
- Maintenance: the breaker, the boiler, and a chest freezer.
- The laundry.
- Flat 2 (locked; its key is in mailbox 2).
- Flat 3, where the hunter sleeps.

**First floor**
- 11.
- 12, where the cook lives. The crowbar is on his wall.
- 13, where the rearranger lives.
- The fuse closet beside the lift.
- Storage.
- 14 (a fuse in a drawer, and 16's key).
- 15: flooded, with a live cable in the water.
- 16 (locked; shells inside).

**Second floor**
Infested: flesh in the walls, dark except for a sick light from the growth.
- 21, 22 (the fridge of meat), 23.
- The valve closet.
- 24 (the thing in the bath), 25, 26.
- 27.

## The way up, and the ways round each obstacle

| Obstacle | Ways past it |
|---|---|
| **Stairs, first floor to second** | Meat grows across the half-landing. Hack or shoot through it (220 hp). It's slow and loud, and each blow is a noise. Once it's cleared, the paths are rebaked. |
| **The lift** | Needs the mains on (the breaker in maintenance) and a good fuse in the **LIFT** slot of the first-floor fuse box. |
| **Fuses** | One is already in **LIGHT**. Taking it puts the first floor in the dark, and the crawlers come out. There's a spare in the super's desk drawer (taking it is trespassing if he sees) and one in a drawer in 14. **BOILER** holds a burnt-out one. |
| **Maintenance (locked)** | The super's key, if the conversation gets it. Or the crowbar from the cook's kitchen, which is loud. Or the vent from the laundry, where something lives in the ducts. |
| **The ladder** | The ground-floor closet is locked like maintenance. The first-floor closet is open. The hatch to the second floor is bolted and needs the crowbar. Once open, the ladder is a shortcut. |
| **27's door** | Meat grows over it, rooted in the thing in the bath in 24. Either kill the thing (its caretaker defends it), or light the boiler (mains on, a good fuse in BOILER, then the boiler itself). The heat on the second floor makes the meat let go, about 25 s after the boiler is lit. |
| **Into 27** | Ends the chapter. |

**Backtracking pays off:**
- The crowbar (first floor) opens maintenance and the ladder (ground floor).
- The fuses (ground and first floors) run the lift (first floor) and the boiler (ground floor).
- The boiler (ground floor) clears 27's door (second floor).

## The super

He is Gennady Vorobyov (Kurt never hears the first name). He's naked, starved-thin and wet, the skin hanging loose on him, with a mouth too wide and too-long fingers, and his keys hang on a cord round his neck. His wife Lyudmila ("Lyuda") is "at her sister's, in Tula".

**The conversation** (`super_hello`) has three choice points, each answered by approach: cooperative, neutral, suspicious, hostile or deceptive. Every choice changes `Game.rel.super`:

- **suspicion**, **hostility** and **trust**
- **threatened**: Kurt threatened him
- **offended**
- **lied**: Kurt claimed to be from the housing committee, or signed a false name
- **known**: what Kurt learned, such as `wife_tula`, `book_empty` or `fuses_upstairs`
- **approach**: a count of each approach used

**Disposition** is worked out from those numbers by thresholds:

| Disposition | When |
|---|---|
| hostile | threatened, or hostility 4+ |
| suspicious | suspicion 4+ |
| cooperative | trust 3+ |
| deceived | trust 3+, but on a lie |
| neutral | anything else |

Nothing shows the numbers to the player.

**What each disposition gets you:**

| Disposition | Key | What he does |
|---|---|---|
| Cooperative | Yes, plus "the fuses are upstairs" | His rounds: desk, mailboxes, watching the laundry from the door, maintenance. Not trustworthy; just not interested in Kurt. |
| Deceived | Yes | Rounds. Catching Kurt in his flat or office exposes the lie, and he turns hostile. |
| Neutral | No | Rounds. Minds the breaker being thrown. |
| Suspicious | No | Follows Kurt at a distance and relocks maintenance, the ground closet and his flat. Kurt learns the Tula story. |
| Hostile | No | Hunts Kurt (keys: every door opens for him). Goes back to maintenance to cut the mains whenever they're on. The listener's hearing sharpens. |

**What can change it later:**
- Being caught in his flat or office.
- Throwing the breaker when it wasn't his idea.
- Prying his door.
- Hitting him.

## The inhabitants (`Inhabitant`, `FleshBody`, `Station`)

Each inhabitant is built from a profile. Every 0.35 to 0.6 s it scores its objectives and the reactive drives (attack something it hates that it can see; flee light; defend its territory; investigate a noise) and does the highest. Each has its own senses:

- **Sight:** a cone, a range and a clear line. Some need light to see by.
- **Hearing:** every `Game.noise` in the building, quieter through walls. Inhabitants' own work makes noise too.
- **Grudges:** whoever hurts one becomes a target.

They open doors (the super opens locked ones), take damage from hazards, telegraph their attacks, stagger when their poise breaks, and die.

| Who | Where | Does | Danger | Counterplay |
|---|---|---|---|---|
| The laundress | Laundry | Washing machines, folding, the lines. Loops forever. | Only if her territory is invaded by another faction. | Leave her be, or use her: the hunter comes for her. |
| The hunter | Ground floor, and up the stairs | Hunts the residents. Patrols both floors. | Heavy hits, high poise. Sight-based. | Out of sight, crouched; let him find someone else; hazards; the shotgun. |
| The listener | First floor | Blind. Hears everything. Patrols. | Fast once it hears. Attacks whatever it hears near: Kurt, the rearranger, the hunter. | Crouch, stay quiet; throw something; its fights with the rest. |
| The rearranger | 13 | Shoves furniture between its flat and the corridor, loudly. | Only if hurt. | Its noise draws the listener. Its furniture changes the routes. |
| The cook | 12 | Stove, chopping, the chute (when he leaves). | Defends his kitchen. Notices the crowbar going. | Take it while he's at the chute. |
| The crawlers | First floor in the dark, the vents, the second floor | Live in darkness. Flee light. | Fast and fragile. | The torch. The lights (the LIGHT fuse). The live water in 15 kills them. |
| The caretaker | 24 and 22 | Carries meat from 22's fridge to the bath in 24. | Defends 24. | Go round it: the boiler. |
| The thing in the bath | 24 | Breathes. It's the root of 27's meat. | — | Kill it, or don't. |
| The super | Ground floor, everywhere | See above. | | |

**Things that happen without Kurt** (all in the test):
- The hunter climbs the stairs after a resident.
- The hunter goes for the laundress.
- The listener goes after a noise it didn't make.
- The thing that lives in the dark in 15 dies when the mains go live in the water.

Nothing on screen explains what they're doing. The developer overlay shows it (see below).

## Socko

- **His job:** he guides with hints in your style (the listener, the dark, the fuses).
- **His suggestions:** three heinous ones.
  - Shut the laundress in with the hunter.
  - Kill the thing in the bath ("It's just a big baby").
  - "Bonk" the super.
- **Obeying or defying:** what Kurt does about each is recorded as `ch2_obey_*` or `ch2_defy_*`.
- **His anger:** each defiance raises `Game.rel.socko.anger`, and it shows. His resting emotion moves from friendly to artificial (too much smile), then irritated, then angry, with snaps, jabs and trembling. His lines sour to match.
- **His secret:** Kurt still doesn't know who Socko is, and no line implies it.
- **Health:** Socko also carries Kurt's health. Fresh blood soaks through the knit and he sags. The edges of the picture darken and redden, steadily, never flashing. Health comes back slowly after 9 s unhurt.

## The wife

Optional, found through the environment, and never explained:

- **The directory:** "1 VOROBYOV G. & L."
- **Mailbox 1:** stuffed with her sister Vera's letters from Tula, three years of "why don't you write".
- **In his flat:** her coat with the gloves still in the pockets; her handbag with her passport and an unpunched train ticket to Tula; the wedding photograph with her face scratched out.
- **In maintenance:** a padlocked chest freezer, humming, with her slippers beside it.
- **What he says:** "At her sister's. In Tula." Only if Kurt asks.

## Sound

Every Chapter 2 effect is new and dark: no bubbles, no pitch-drops. The list is in `docs/SOUND.md`. The voice blips stay. The super has his own: low, breathy and close.

## Saving

Game state saved at checkpoints:
- the relationships
- the mains, the fuses, the boiler, the hatch
- the doors that were unlocked or pried
- the meat that was cleared
- what was taken
- who's dead
- obey/defy
- the conversation's outcome

Checkpoints happen after the conversation, when the mains go on, when the boiler is lit, on first reaching the second floor, and when 27's door clears. A restart brings the building back as Kurt left it. Everyone else starts their routines again.

## Developer tools

`DevOverlay`, toggled with F3. It only exists in a debug build run from the editor or with `--dev`. It shows:
- the super's numbers and disposition
- Socko's anger
- every `ch2_` flag
- the mains, fuses, boiler, heat, hatch and lift
- the inventory
- every inhabitant's state, objective, target, awareness and health

## What's reused

- Kurt and his systems (movement, health, the nerve, hiding, melee, the pistol and the shotgun).
- Socko's rig.
- The dialogue system (extended).
- `Door`, `Prop`, `NoteReader`, `Fx`, the sound library.
- Flat 47's furniture.

## What's new

- `LobbyBuild` (the building)
- `Inhabitant`, `FleshBody`, `Station`
- `Use`, `Growth`, `Hazard`, `BathThing`, `Lift`
- `Game.rel` and dispositions
- Dialogue branching and consequences
- Kurt's health
- Socko's new emotions and gestures
- `DevOverlay`
- The Chapter 2 sounds

## Still incomplete

- **Flat 27.** Decided: in this chapter it's only where Socko sends Kurt, for the chase. What's inside (a puppet show) belongs to what comes next and isn't built; the chapter ends on the threshold.
- **Facial and lip performance** for the inhabitants. Mouths and jaws move with posture, not with speech.
- **Wall hiding** (wardrobes) isn't placed in this building yet. The hiding system exists.
- **Electrocution as a trap.** The live water works on anything that walks into it, but there's no dedicated "lure it in" tool beyond noise.
- **Inhabitants' routines restart at a checkpoint** rather than being saved mid-task (by design: "sensible persistence").
- **Not played by hand or on a phone yet.** Tuning (enemy speeds and damage, how long things take) is first-pass.
