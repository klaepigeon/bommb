# HYSTERIA: the Android-first rebuild (Godot 4.7)

**Scene A**, **the maze** behind the wardrobe, then **Flat 48** across the landing. New code throughout for everything that
broke in the first Godot build (lighting, sound, the scene's logic, doors, controls, the test),
carrying that build's **art**: the textured flat, Socko's skinned
sock with his expression library, Kurt's anatomical arm and body, Marta, the infected. The old
project is kept, untouched, in `legacy/hysteria/`.

## Install

`dist/Hysteria.apk` (arm64, Android 7+), signed with the repo's key in `android/` (the same key
as the earlier builds, so it installs over them). The icon is Socko, rendered from the game's
own model (`tools/make_icon.sh` remakes `icon/`: the adaptive foreground and background, the
one-colour version for themed icons, and the legacy icon).

## Scene A, as written

Black, no intro text. Kurt on the landing outside 47. Knocks. *"Ms. Sokolov? Your sister asked me
to come check on you."* Knocks again. *"Marta? It's Kurt. I'm coming in."* He pushes the door.

| Trigger | What happens |
|---|---|
| Stepping into the hall | *"Christ..."* |
| Marta in view | *"Oh... oh no."* Then she can be examined. |
| **Examine** Marta (at her place at the dinner table) | He goes round to her side and leans in: *"What the hell is this?"* She lifts her head to him: the boxes. *"Marta?"* *"Look at the boxes, my little bird. Do you see them?"* She takes hold of him; a gasp; black. |
| Waking (on the floor beside her chair; muffled, ringing) | *"Oh, jeez, that smarts"* (rubbing his head). His left hand comes up with a sock on it, through *"Shouldn't have stood up so fast."* Her chair is empty, still grown through with coral. |
| **Open** the living room door (shut while he was out: he can't leave the room he found her in) | It rattles. *"It won't open."* through *"You're welcome!"* and, to himself, *"I like helping."* |
| **Push** the wardrobe (three shoves along the wall) | A ragged hole knocked through behind it, dark, with a glimmer of gaslight a long way off. *"What the hell is that?"* *"I don't know."* *"Do you know anything?"* *"I know that I can do this!"* (cross-eyed) *"Ooh! Ooh! And I can smell important stuff! Go this way!"* (pointing) |
| **Crawl through** | The maze. Socko points the way to the gun. |

Before the scene ends the flat is there to explore: doors and drawers open, and the notes,
papers and things the first build wrote text for can be read.

## The maze (where the town was)

Through the hole is Flat 47 gone wrong: its rooms over and over (the faded mustard damask, the
parquet, the plaster ceiling, fluorescent panels that hum), 13 × 14 of them, with doorways where
there shouldn't be, walls missing, a big room where the walls have gone, and the wardrobe, the
armchair and the radiator again and again. You come out into **a corridor of thirteen lights that
comes round on itself**. The way out is **the flat's own front door, 47, at the far south**,
bolted: the bolt on the wall beside it is loud. (The Romanov town it replaces kept closing itself
on phones; see **Why it's a maze now** below.)

**Marta hunts it.** She walks a round of the southern rooms from the start, listening, and sees
Kurt if he gets close; once the revolver is taken (on a table in a room deep in the east) she's
properly awake and comes for him. Caught, he comes to in the corridor where he came in.

The people the maze took, and what Kurt needs to talk them down:

| Who | Where | What it keeps saying | What Kurt needs |
|---|---|---|---|
| The porter | Room 4 (a "4" over the doorway), his back to the room | *"Room four. Room four."* | **Her Handwriting** + having looked at the photo strip in that room |
| The lamplighter | walking the corridor of thirteen lights | *"Thirteen... thirteen..."* | **These Walls** + having walked round the loop |
| Marta | everywhere | *"...Have you seen..."* | **Old Name** + having looked at the TRICKSHOT poster near the door |

Known, they stop, say one human thing, and stay down (and give back a nugget). Unknown (the
prompt says **Talk (?)**), Kurt gets as far as *"Hey. Hey, easy..."* and they come for him.

**Three ways out:** the gun (four hits drive Marta off for 25 s, or Headshot ends her); sneaking
(a loose brick thrown where she'll go to look, then the bolt); talking. Sonya's door is in the
south-west corner room, low down, СОНЯ scratched on it; it doesn't open. Through the front door:
white, and he's on the landing outside 47. Nuggets (12, plus one per person talked down) buy
skills from two trees in any order (`content/skills.json`).

## Flat 48

Flat 47 as reality only sketched it (master document Part VI; story bible §2d): the same rooms and
doors in pale draft plaster, the room names pencilled on the walls, every piece of furniture a
white block where 47's is, each with a paper tag that says what it was like, not what it is. Three
white figures (MAMA at the stove, PAPA at the bedroom window, CHILD by the small bed) stand with
their backs to the room and turn toward you only while you aren't looking.

**The rule: what something is, is what's written on it.**

- In the hall, under *what it is*, a wall of 25 loose sticky notes. **Take** one and it's in
  Kurt's hand, held up so you can read it. Taking another puts the first one back.
- **Stick** it on a block. The right word and the block becomes the thing: Flat 47's own
  furniture, copied in, solid, with the note stuck on it. The wrong word is on for a moment, lets
  go, and is back in his hand. Some words fit nothing (PIANO, DOG, WINDOW, HOME, LATER).
- **Peel** a stuck note off and the thing is a white block again, the note back in his hand.
  **Put it back** on the wall where it came from.
- **GUN SAFE** on the tall cold block in the box room (*PAPA'S. Locked. Nobody touches it.*) makes
  it a steel hunting-gun cabinet. It isn't locked. Inside, hanging on two pegs where you can see
  it: a sawn-off **IZh-43** shotgun, and a box of shells on the shelf. Take them. It's a second
  working gun (two barrels, nine pellets each, breaks open to reload; SWAP changes guns).
- **MARTA** on MAMA and **KURT** on PAPA dress them as faceless shop mannequins: her cardigan and
  red painted mouth; his jacket, a domino mask on a face that isn't there, a bow on its back.
  Their notes peel off too. **SONYA** won't stay on CHILD: *she isn't here.*
- Each of the three can be **shot**, separately, and stays down. Nothing requires it, and nothing
  is gained by it: the right thing to do with them is **leave them alone and keep the shells**.

## The building, and The Super

**The goal of the game is to find Sonya** (it says so when Kurt comes out onto the landing, and in
the pause menu).

Building 14 has a stairwell now: floors 2 to 6, switchback flights, two padded doors a landing
(47 and 48 on the fourth), one bare bulb each, dark between. Above 6 and below 2 the stair has
come down.

**The Super** walks it: an old man the height of a doorway, starved to the bone, the skin of a
much heavier man hanging off him in flaps, naked (all of him, always in plain sight), the top of
his head gone. He has his own rig (`scripts/actors/super_rig.gd`: his own skeleton, skin, sprung
bones for everything that hangs, and his own walk, hunt, stagger and grab). He does
rounds from the bottom of the building to the top and back. He hears steps a floor away and shots
anywhere; he comes at a walk Kurt can outpace and never outlast. **Nothing kills him**: a shot
staggers him for a second, one in what's left of his head for two or three. If he gets hold of
Kurt, Kurt comes round on his own landing and the Super has gone off to one end of the building.
He doesn't come through 48's door. You hear which floor he's on before you see him.
(`scripts/actors/super.gd`, `scripts/world/building.gd`; `tools/test.sh super`.)

**Socko wants them shot and never says so.** *"Well. That's a family."* *"I wouldn't get too
close."* *"You don't know what they are."* He sneers at the notes, likes the safe very much,
counts the barrels, approves quietly the moment a gun points at one of them (*"There we are."*),
and when Kurt has the shotgun and won't use it he escalates: impatience, *"we have our own
problems"*, *"you can't save everybody, bud"*, and finally *"What? I didn't say shoot them."*
What Kurt did is remembered (`socko_advice_followed` / `socko_advice_rejected`, and a flag per
block, note and figure) for later chapters.

Looking at things gives a quiet line of text above the subtitles. All of Flat 48's data (blocks,
tags, the words on the wall, the figures, every text, Socko's lines) is `content/flat48.json`.
The door you came in by takes you back to the landing.

## Socko's face

Socko holds an expression and plays clips from the first build's library (`scripts/socko/
socko_clips.gd`: 16 expressions, ~70 clips: head tilts, nods, laughing, peeking, surprise, the
talking styles). Each line can set them in content:

```json
"im_socko": { "speaker": "socko", "text": "I'm Socko! ...",
              "socko_face": "excitement", "socko_clip": "Head_Bob", "socko_talk": "Talking_Excited" }
```

`socko_face` is held until a couple of seconds after the line (then he relaxes);
`socko_clip` plays once on top; `socko_talk` is how he moves while he says it. On Kurt's lines
they're Socko's reaction. Every line of Scene A and the maze has them.

## Content

`content/scene_a.json`, `content/town.json` and `content/flat48.json`: every line (text, speaker, Socko's cues), the
monsters (what they say, what Kurt needs, his words, their answer), and what Socko says the first
time Kurt looks at each thing. `content/characters.json`: speakers' colours and voices.
`content/skills.json`: the trees. New writing is marked NEW / PROPOSED for you to rewrite.

## Controls

| | Touch | Gamepad | Keyboard / mouse |
|---|---|---|---|
| Move | left half: a stick under your thumb | left stick | WASD |
| Look | drag on the right half | right stick | mouse |
| Use / Talk / Read / Take | the round button (when there's something) | A | E / Space |
| Fire / throw | FIRE (THROW with a cobble) | RT | left mouse / F |
| Aim | AIM (toggle) | LT | right mouse / Q |
| Reload | LOAD | X | R |
| Swap guns | SWAP (with both) | RB | V |
| Skills | SKILLS | Y / Back | Tab / K |
| Pause | ‖ or Back | Start | Esc |

## The issues raised about the first build

| Issue | Now |
|---|---|
| Lighting flicker | Every light is steady (the flat's flicker models are gone; the failing bulbs are just dimmer). No shadow maps. A room's lights fade in and out slowly as you come and go, so no mesh is ever over the phone renderer's light limit (which is what made walls pop). |
| No sound | All sound is synthesised in the game at start-up; voices use the phone's text-to-speech. |
| Broken animations | One controller per character, posing the first build's rigs by name, eased; tested through every beat. |
| Door out of the waking room not locked | The living room door is shut and locked after the blackout; tested at the end of Scene A. |
| Hands going into walls | Kurt's hand, what's in it, and Socko draw back from anything solid that's nearer than they reach. |
| The town closing itself on Android, always at the same spot (a few steps in, at the first nugget, as Socko spoke) | The town is gone: behind the wardrobe is now a maze of Flat 47's own rooms, built from the flat's simplest materials (see **Why it's a maze now**). Not yet tried on a phone: if it ever closes, the next launch shows the trail. |

## Why it's a maze now

The Romanov town closed itself on phones, always at the same moment: the first nugget a few steps
from the hole, with Socko's first line there. It never did on a desktop and it couldn't be
reproduced off a phone, so instead of a third fix the place is replaced with one that asks a
phone for much less, and everything around it is built so no one frame does anything heavy:

- **One simple shader** for every surface (the flat's `ps1.gdshader`: a texture and lambert light;
  none of the town's normal maps, roughness maps or specular), six materials in all.
- **145 meshes** (the town had 798): the maze in 16 m chunks, one mesh per material per chunk;
  no shadows anywhere; fog, and nothing drawn past 40 m on a phone.
- **A light budget**: every room has a glowing panel (emission, free), but only the nearest 4
  carry a real light on a phone (9 on a desktop), chosen four times a second; steady, no flicker.
- **Built a step a frame behind the black, then drawn once from 12 views** (`TownChapter.prewarm`)
  so every shader and light combination is compiled before the black lifts.
- **Inert pickups**: taking a nugget hides it, counts it, plays one sound. Nothing is created,
  tweened or freed while he walks about.
- **One phase at a time** in `TownChapter` (BLACK, ARRIVING, FREE, SCENE, LEAVING, DONE), and
  **one queue for what's said**: a line starts only when nobody is speaking, only while he's free,
  never in a pickup's frame.
- **Socko comes up to say his lines** while Kurt walks about (before, he talked from just out of
  view). `--sockocheck` plays every line, clip, face and pointing he has in the maze and checks
  every bone and eye is a finite number every frame.
- **The voice**: on a phone it's never paused and resumed (a line in progress just finishes). If a
  run ever dies while a spoken line is being started, the next launch turns voices off by itself
  (subtitles stay) and says so on the report screen.
- **Way-finding** is a table worked out once; the autotest checks it gives the shortest way
  through the doorways for all 32,942 pairs of rooms.
- The trail (`user://trail.txt`) marks every build step, prewarm view, phase, pickup and line.

## Build and test

```
tools/test.sh                 # three full playthroughs from the first knock (talk, gun, sneak),
                              # each on through the landing and all of Flat 48
tools/test.sh kill            # one
tools/test.sh shots DIR talk  # rendered, a frame per line
godot --path . -- --autotest --start=town --mazeviews --shots=DIR   # the maze from 8 spots
godot --path . -- --autotest --start=town --sockocheck               # Socko: every line, clip, face
tools/build_apk.sh            # → ../dist/Hysteria.apk, signed, or it fails
tools/make_icon.sh            # re-render Socko and rebuild the launcher icons in icon/
godot --path . -- --start=wake|door|wardrobe|town|landing|flat48
godot --path . -- --start=door --poses --shots=DIR    # Kurt himself: looking down, the gun
```

## Not done yet

Where Sonya is. Suite 51 and the POINTLESS DOOR are cut for now. Sonya's shoes; saving; the
dialogue graph and cutscene tools. The other floors' flats are shut doors.
