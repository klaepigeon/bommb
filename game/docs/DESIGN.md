# HYSTERIA — Flat 47 rebuild: reference and design

The third Godot build, written from scratch (`game/`). The previous one is kept, untouched, in
`legacy/game_v2/`; the first Godot build in `legacy/hysteria/`; the browser build in `src/`.

## 1. Reference inventory (what was studied, what was kept)

| From | Kept as | Why |
|---|---|---|
| Browser build (`src/`): the flat's plan, painted surfaces, furniture, ~145 described things, the papers, the fuse box with a tripped circuit, the bath of black water, the chained front door, the box room den, the "outside" sticky note | **The flat itself**: `assets/flat47/flat47.glb` + `level.json` (its export), and every text (`content/docs.json`) | It is the atmosphere: the damask going off the wet wall, dinner for three, the jars of hoarded water. Nothing redrawn. |
| The owner's Scene A, balcony, random conversations | `content/dialogue.json`, verbatim | Canon |
| Socko's rig and clip library (Godot build 2) | `scripts/art/sock_rig.gd`, `scripts/socko/socko_clips.gd` (unchanged apart from his material) | The owner: "keep Socko as is or improve". His controller (`socko.gd`) and mind (`socko_mind.gd`) are new. |
| Kurt's arm rig (build 2) | `scripts/art/arm_rig.gd` (material only) | Shared hand anatomy |
| Monsters: Marta (hunter), The Super, the porter, the lamplighter, Flat 48's MAMA/PAPA/CHILD | New designs (`scripts/art/body.gd`) and new AI (`scripts/ai/`) with the same behaviour and lines | The owner: "keep all monsters … how they're supposed to behave … a new iteration and redo their code and AI" |
| The town behind the wardrobe | **Replaced** by the walls (the maze) | The owner: "instead of a massive town … an enclosed maze with Marta as a hunting npc". The town is also what crashed on the phone. |

## 2. What went wrong on the phone, and what's different

| Seen in the recordings | Cause in build 2 | Now |
|---|---|---|
| The scene goes murky and black; walls pop | Godot's own lights under GL Compatibility's per-object light limit, faded in and out by room | **No Light3D at all.** The game's light engine (`scripts/render/lights.gd`) writes the eight lamps that matter most to shader globals each frame, fading lamps in and out of the eight over 0.4 s. Every surface is lit by the same shader (`shaders/world.gdshaderinc`), so there is no per-object limit to exceed and no shadow atlas. Lamps light only the rooms they're in (and rooms joined by open doors): no light through walls. |
| Blocky, crawling edge on the hole behind the wardrobe | A shader that discarded pixels by a hash at 1/3 resolution | The hole is cut cleanly (`hole_a/hole_b` in `world.gdshader`) and its broken edge is real geometry: brick in the wall's thickness, plaster chips, rubble |
| The game closes a few seconds into the town | The town: ~960 meshes, many textures, many lights | The maze is one merged mesh per material, ~30 lamps (eight lit at a time), small procedural textures. A crash trail (`user://trail.txt`) is written every few seconds; if the last run didn't end cleanly, the pause menu shows where it was. |
| Subtitles cut off at the edge | Fixed width | Subtitles wrap inside the display's safe area, scaled to the screen and the subtitle-size setting |

Tested on Mesa's OpenGL ES 3.2 (the phone's API) at phone resolution (2340×1080) with real
multi-touch events (`tools/test.sh touch`, `tools/phone.sh`). There is no KVM on the build machine,
so an Android emulator can't run there; the APK itself has not been on a phone yet.

## 3. Architecture

Autoloads (all small): `Log` (crash trail), `Settings`, `World` (flags + the save: every system
registers a saver/loader), `Lights` (the light engine), `Noises` (sound that things can hear),
`Audio` (all sound synthesised at runtime), `Power` (circuits), `Controls` (keyboard, pad, touch →
intents), `Speech` (lines, subtitles, TTS, gibberish), `Progress` (the two trees).

| Responsibility (master prompt Part 17) | Where |
|---|---|
| PlayerController, InteractionSystem, ObjectManipulation | `scripts/player/kurt.gd` (move, mantle, look, verbs, carry/throw/place, The Pull, revolver) |
| InventorySystem | Kurt's pockets; the POCKETS screen (`ui/hud.gd`) |
| EnvironmentalSimulation | `scripts/sim/`: `door.gd`, `prop.gd`, `power.gd`, `fusebox.gd`, `water.gd`, `puddle.gd`, `gravity_zone.gd`, `drawer.gd`, `usable.gd` |
| ElectricitySystem | `Power` + `FuseBox` + `Lamp.circuit` + appliances (TV, radio, the service door's lock, the hanging room) |
| WaterSystem | `WaterBody`: levels, inflow/outflow, overflow into the next body, wading, splashes as noise, electrified water that trips its breaker |
| GravitySystem | `GravityZone` (Godot area gravity for things; Kurt reads it each step), tied to a circuit |
| DialogueSystem | `Speech` + `content/dialogue.json` (lines with Socko's face cues) |
| NPCBehaviourSystem, EnemyAI, PersistentThreatSystem | `scripts/ai/monster.gd` (perception, Nav, doors, damage) + one mind per creature |
| SockoController, SockoHUD | `scripts/socko/socko.gd` (performance), `socko_mind.gd` (wants, stages, HUD duties, commands) |
| ProgressionSystem, MemorySystem, InfectionSystem | `Progress` + `content/skills.json` |
| QuestAndStoryState | `World` flags + `scripts/story/story.gd` |
| SaveLoadSystem | `World.save_game()` / `restore()` |
| AudioSystem | `Audio` (synth), `Noises` |
| AccessibilitySystem | `Settings` + pause menu: subtitle size, subtitles on/off, Socko/stick side, text prompts, button opacity, brightness, look sensitivity, invert, volume, voices, picture |

Navigation is a waypoint graph (`scripts/sim/nav.gd`): every open cell of the maze and a handful of
points per room of the flat, joined where you can get through (doors on the joins). A* over it.
Nothing is baked at runtime.

## 4. The slice

**Scene A** exactly as written (no intro text; knocks; *"Christ..."* in the hall; *"Oh... oh no."*
at the sight of her; examine her → her lines → she takes hold of him → black). He wakes on the
floor; Socko; the owner's lines in order. The living room door is now shut and locked from the
hall side, the key still in it. The front door is chained and padlocked from inside.

**Getting out of the living room** (any of):
- push the wardrobe off the box room door (three shoves) — the owner's lines play; or pull it over
  (fast, and the whole building hears);
- slide the magazine under the door, have **Socko** poke the key out of the lock, pull the magazine
  back with the key on it (the cooperative puzzle). Poke it out without the magazine and it's gone,
  out of reach on the hall floor;
- kick the door in (four kicks; loud; things come).

**The walls.** Behind the wardrobe the box room has gone through into a maze that can't fit behind
a flat. It breaks back into the flat through Sonya's room (a crawl) and the bathroom.

| Place | What's there | Ways |
|---|---|---|
| The hanging room | Nothing weighs anything while its circuit's dead: chairs, cobbles and **the revolver** turning against the ceiling. The TRICKSHOT poster. | low-gravity jump; throw things at it; power the room (everything falls, loudly); The Pull |
| The breaker room | The walls' fuse board: west passages (M1), the service side (M2, **no fuse**), the hanging room (M3) | fuses come from the flat's box (killing a circuit there), the walls' own M1 (killing the west lights), or the porter's box |
| The porter's lodge | The porter, "Room four. Room four.", the spare fuse in his key box, the room-four photo strip | sneak (he startles if you're in front of him); a noise elsewhere and he gets up to see; **Socko fetches it**; talk him down (Faces + the photo); kill him |
| The west passages | The lamplighter, counting bulbs, "Thirteen..." | stay out of his light; pull M1 and he stands under the first dead bulb; talk him down (These Walls, lights on: he gives you rounds); kill him |
| The flooded passage | Knee-deep, every step loud. A drain wheel (stiff). A cable over the water. | wade; drain it (three turns, or one with Coral Grip); drop the live cable in: anything in the water gets it (Marta is driven off; so is Kurt's health), until the breaker trips |
| The white room | MAMA, PAPA, CHILD: they move only unseen | keep them in view; go round; shoot them (Socko approves; nothing gained) |
| The service ring | **The Super**: unkillable, hears what the infection lets him hear, too big for the holes into the flat | evade; stagger him with shots; hide in the flat |
| The nursery | Sonya's door, СОНЯ; Marta's resting place | — |

**Marta** hunts the walls (and follows into the flat). Evade her; lure her (a thrown thing, the TV,
the radio, the bath draining); shoot her (she breaks off for a while); shock her; give her a red
shoe (calm for two minutes; both shoes, calm for good); know her (Old Name + having understood who
she was: the drawing, the fridge note, the poster); or, with the infection's Headshot, kill her.
The first time she sees Kurt with Socko on his hand she stops, and she and Socko have a whole
conversation, snarls and cartoon gibberish, that Kurt is not part of.

**Out**: the front door (the small key from the bath; the axe, three blows; two bullets in the
padlock; a heavy thing, seven blows; Coral Grip) or the service door (fuse into M2 and press the
release; or tear it open). The ending card says how.

## 5. Progression

Two currencies, two trees (`content/skills.json`). **Memories** come from understanding (reading
the right things with the right skill, talking people down). **Shards** come from the Gutterspace
(pink, missing-texture shards in the walls), from the black water, and from every kill (the god
pays). Memory skills: Faces, Her Handwriting, Old Name, How She Moves, These Walls, The Bow.
Infection skills: Quiet Feet, Deep Lungs, The Pull, Coral Grip, Dark Eyes, Headshot. Every hunter
reads `Progress.aggression()`: up with the infection and with kills, down with memory.

## 6. Socko

Seven stages (friendly → confused → insistent → passive-aggressive → irritated → manipulative →
hostile), driven by what the player does, never shown as a number. Everything he suggests (SOCKO
button) is the loud, cruel option; he never mentions the shoes, talking, or the memory tree. He
watches what Kurt looks at, turns to threats before they can be seen (and from stage 5, sometimes
keeps Marta to himself), shows Kurt's breathing and injuries, teaches, carries the torch in his
mouth, can be asked to do things (poke the key, fetch the fuse, feel around in the black bath:
from stage 6 he may refuse), and now and then, once he's far enough gone, looks straight out of
the screen.

## 7. Not done yet (Phase 7, expansion)

The bedroom-window ledge route (the balcony ledge exists, and falling into the white hands you
back); Dark Eyes and How She Moves are partial (the latter is the directional pressure sound);
Kurt's visible right hand (the rig is in the project, not yet posed in play); Flat 48 and the
stairwell beyond the service door; recorded voices (text-to-speech for now); the APK on a real phone.
