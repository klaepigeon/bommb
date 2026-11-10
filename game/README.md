# HYSTERIA: the Android-first rebuild (Godot 4.7)

A clean rebuild of HYSTERIA: **Scene A**, then **the town** behind the wardrobe. It's built for phones first: touch
controls, a 3D view rendered at half resolution (the PS1 look, and cheap on phones), the GL
Compatibility renderer everywhere, few lights and no shadows. Every scene is played through by an
automated test before it ships. The old Godot project is kept, untouched, in `legacy/hysteria/`
to port from.

## Install

`dist/Hysteria.apk` (arm64, Android 7+). It's signed with the repo's key in `android/`, the same
key as the earlier builds, so it installs over them.

## Scene A, as written

Black, no intro text. Knocks. *"Ms. Sokolov? Your sister asked me to come check on you."* Knocks
again. *"Marta? It's Kurt. I'm coming in."* He pushes the door; it's open. You have control.

| Trigger | What happens |
|---|---|
| Stepping into the hallway | *"Christ..."* |
| Marta in view (on screen, nothing in the way) | *"Oh... oh no."* Only now can you use her. |
| **Examine** Marta | He goes round to her side and leans in: *"What the hell is this?"* She lifts her head: the boxes. *"Marta?"* *"Look at the boxes, my little bird. Do you see them?"* She grabs him; he gasps; black. |
| Waking (on the floor, sound muffled, ringing) | He sits up: *"Oh, jeez, that smarts"* (rubbing his head). His left hand comes up with a sock on it, and Socko and Kurt have the whole exchange, through *"Shouldn't have stood up so fast."* He stands, sways, and you have control again. Her chair is empty, still grown through with coral. |
| **Open** the living room door (open when he came in, shut while he was out: he can't leave the room he found her in) | It rattles. *"It won't open."* *"Maybe it's locked?"* *"Wow, thanks. I never would have guessed."* *"You're welcome!"* and, quieter, to himself, *"I like helping."* |
| **Push** the wardrobe (three shoves, it scrapes along the wall) | A hole low in the wall, and gaslight and cobbles through it. He crouches to it: *"What the hell is that?"* *"I don't know."* *"Do you know anything?"* *"I know that I can do this!"* Socko goes cross-eyed. *"Ooh! Ooh! And I can smell important stuff! Go this way!"*, pointing through the hole. |
| **Crawl through** | The town. Socko points down the street, at the square, at the gun. |

The lines live in `content/scene_a.json`. Edit the text there and the game uses it. Speakers'
colours and voice pitches are in `content/characters.json`.

## The town

Kerzhansk under the Romanovs, at night (story bible §2b): one main street, thirteen houses long, that
comes round on itself (walk off either end and you're back at the other, among the same houses;
the church dome stays the same distance away however far you go); a square off it with a fight
frozen in mid-air (stones, chairs, trick arrows hanging around one point, a domino mask, a
TRICKSHOT poster) and the revolver lying in the middle of it; the hotel (ГОСТИНИЦА), the
séance salon (ФОТОГРАФІЯ), and the nursery with Sonya's door. At the top of the square is
**the gate, the only way out**, and Marta sits in front of it, floating, head down, still seated
in a chair that isn't there.

**There are no NPCs to talk to.** There are monsters, and every one of them was someone:

| Monster | Where | What it keeps saying | How Kurt knows who it was |
|---|---|---|---|
| The porter | room four of the hotel, his back to the door | *"Room four. Room four."* | **Her Handwriting** + reading the hotel register |
| The lamplighter | walking the main street, end to end | *"Thirteen... thirteen..."* | **These Streets** + having walked round the seam once |
| Marta | the gate | *"...Have you seen..."* | **Old Name** + having looked at the TRICKSHOT poster |

Close enough, every monster can be talked to. If Kurt knows who it was, he talks to it **as
himself** (*"Room four. That was us…"*, *"It's thirteen. That's all of them…"*, *"Marta. It's me.
It's Trickshot."*): it answers with one human thing, sits down and stays down, and something
of his it was holding comes back (a nugget). If he doesn't know, he gets as far as *"Hey. Hey,
easy..."* and it comes for him. The prompt says **Talk (?)** until he knows.

**Three ways out, and any mix of them:**

- **The gun** (the gunplay tutorial). The Nagant M1895 holds seven, three in it when you find
  it, loaded a round at a time (boxes of seven in the hotel, the salon, the square). AIM brings
  it to his eye and steadies it; every shot is heard across the whole town. Taking it wakes
  Marta: *"There she is. Don't think. Aim for the head."* Townsfolk die to two head or four body
  hits. Marta doesn't die: four hits and she breaks off and drifts away from the gate for 25
  seconds (time to pull the lever), unless you have **Headshot**, and then a shot to the head
  ends her, for good.
- **Sneaking.** Everything hears: footsteps (less with Quiet Feet), shots, the wardrobe, the
  lever (loud), a thrown cobble where it lands. Pick up a loose cobble, throw it across the
  square, and Marta drifts off to see. Pull the lever while she's gone.
- **Talking**, as above. Talk Marta down and the gate is yours.

Getting caught (anything that reaches you takes hold of you): black, and you come to where you
came in; everything that's still alive goes back where it was.

**Nuggets and the skill trees** (`content/skills.json`): 14 gutterspace nuggets (2 in the
living room, 12 in the town; pink and black, like a missing texture), plus one for every
monster talked down. Anything can be bought in any order (SKILLS). There aren't enough for
everything: the talk route alone takes 8.

| Memory | | Survival | |
|---|---|---|---|
| Her Handwriting (3) | notes say more; knowing the porter | Headshot (4) | head shots kill outright, Marta too |
| These Streets (2) | the chalk circle at the seam; knowing the lamplighter | Steady Hand (2) | less kick, tighter shots |
| Old Name (3) *PROPOSED* | knowing who you were to Marta | Quick Reload (2) | rounds in twice as fast |
| How She Moves (2) | a pressure in the ears near Marta, louder as she nears | Quiet Feet (2) | footsteps carry half as far |
| The Bow (2) | throws go further | Deep Pockets (1) | seven more rounds |
| Counting (1) | a girl counting, from the nursery's way | | |

Socko wants the gun, the nuggets and the headshot (*"You've got enough. Headshot. Trust me."*),
waves away every clue, goes quiet in the nursery, sulks at Memory purchases, and has something
to say about however you got out. Through the gate: white, and the title. What's past it is
yours to write.

All of the town's text is in `content/town.json`: Socko's lines (most are the story bible's;
new ones are marked NEW), every document (with its Her Handwriting margin note), and each
monster (its phrase, what Kurt needs to know, his words and its answer). Who the porter and the
lamplighter were, and Kurt's lines to all three, are **this build's invention**, marked as such,
for you to rewrite.

## Controls

| | Touch | Gamepad | Keyboard / mouse |
|---|---|---|---|
| Move | left half of the screen: a stick appears under your thumb | left stick | WASD / arrows |
| Look | drag on the right half | right stick | mouse (click to capture) |
| Use / Talk / Read / Take | the round button (it appears when there's something to use) | A | E / Space |
| Fire / throw | FIRE (THROW with a cobble) | RT | left mouse / F |
| Aim | AIM (toggle) | LT (hold) | right mouse / Q (hold) |
| Reload | LOAD | X | R |
| Skills | SKILLS top left | Y / Back | Tab / K |
| Close a document or the skills | tap / Done | B | E / Esc |
| Pause | ‖ top right, or Back | Start | Esc |

Pause has: voices on/off (the device's text-to-speech; subtitles are always on), look speed,
subtitle size, and restart. Leaving the app pauses it.

## The issues raised about the old build

| Issue | In the rebuild |
|---|---|
| Lighting flicker | Every light is steady: no flicker models, no shadow maps, no specular sparkle. Textures have mipmaps, so distant floors don't shimmer. |
| No sound | All sound is synthesised in the game at start-up (knocks, the door creak, the rattle, footsteps, Marta's breathing, the grab, the thud, the ringing, Socko's pop, room tone). There are no audio files to fail to load. Voices use the phone's text-to-speech when it has one. |
| Broken animations | Kurt's right hand, Socko and Marta are simple rigs posed by name and eased between poses, with small procedural layers on top. The test plays every pose in the scene. |
| Door out of the waking room not locked | Every door you can't go through has collision and is shut. Trying one only rattles it. The front door after waking is tested to be shut at the end. |
| Crash passing through the gap on Android | The town is rebuilt from scratch on this base: its streets batched into one mesh per material per area, a moon and nine lamps (none with shadows), built behind the black in under 50 ms on the test machine, the flat switched off while you're in it. Every route through it is played start to finish by the test. Not yet tried on a phone. |

## What's in it

```
content/            the scene's lines, the speakers
shaders/ps1.gdshader    one material: nearest-filtered, mipmapped, vertex-snapped, no specular
scripts/core/       main (low-res view, HUD, boot), speech (subtitles + TTS + mouth shapes),
                    sfx (sound synthesis), settings, build (batched box geometry), look (textures)
scripts/world/      flat47 (the flat and the landing), door, hotspot
scripts/actors/     marta (seated, mould and coral, breathing, head, the grab, gone)
scripts/player/     player (movement, look, crosshair, body you see looking down), kurt_arm
scripts/socko/      socko (the hand is the puppet: fingers = upper jaw, thumb = lower; poses,
                    facing Kurt, emotions, gestures), googly_eye (each pupil its own spring)
scripts/core/       … game (nuggets, skills, what he knows), noise (what things hear)
scripts/town/       town (the streets, the seam, the square, the gate, the interiors), nugget
scripts/actors/     … monster (hears, sees, chases, grabs, gets shot, gets talked down),
                    marta_hunter (Marta in the town)
scripts/weapons/    weapon (the Nagant: aim, fire, one-round reloads; throwing), rock
scripts/story/      scene_a (the beats), town_chapter (the town), autopilot (plays it and checks)
scripts/ui/         controls (touch first; pad; keyboard/mouse), hud (prompt, fade, pause),
                    reader (documents), skill_menu
```

## Build and test

```
tools/test.sh                 # headless, three full playthroughs from the first knock: Scene A
                              # (all 29 lines in order, the door shut, the wardrobe, the hole), then
                              # out of the town by talking, by the gun, and by sneaking
tools/test.sh kill            # one route
tools/test.sh shots DIR talk --start=town   # rendered, a screenshot per line
tools/build_apk.sh            # → ../dist/Hysteria.apk, signed, or it fails
godot --path . -- --start=wake      # jump to waking up (or door, wardrobe, town)
```

Needs Godot 4.7 with its export templates, and for the APK the Android SDK (build-tools) and a
JDK set in Godot's editor settings.

## Not rebuilt yet (from the master documents, and in `legacy/hysteria/`)

What's past the gate; Flat 48; Sonya's shoes (the bible's other way to calm Marta, from the flat
the player can't get back to now); saving; the dialogue graph and cutscene tools. The
monsters here are built from primitives; the infected generator on the `ccr-51f7ea99-p2a8i9`
branch (skinned bodies, limbs that come off) is the next step up for them.
