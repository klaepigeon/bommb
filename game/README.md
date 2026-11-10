# HYSTERIA: the Android-first rebuild (Godot 4.7)

**Scene A**, then **the town** behind the wardrobe. New code throughout for everything that
broke in the first Godot build (lighting, sound, the scene's logic, doors, controls, the test),
carrying that build's **art**: the textured flat, the old town's modelled streets, Socko's skinned
sock with his expression library, Kurt's anatomical arm and body, Marta, the infected. The old
project is kept, untouched, in `legacy/hysteria/`.

## Install

`dist/Hysteria.apk` (arm64, Android 7+), signed with the repo's key in `android/` (the same key
as the earlier builds, so it installs over them).

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
| **Crawl through** | The town. Socko points the way to the gun. |

Before the scene ends the flat is there to explore: doors and drawers open, and the notes,
papers and things the first build wrote text for can be read.

## The town

The first build's labyrinth: Kerzhansk under the Romanovs, at night. The main street goes on for
ever (walk off one end and you're at the other; the cathedral dome stays the same distance away);
the square where a fight stopped in mid-air, with the revolver lying in it; the photographer's
séance salon; the hotel room; the nursery izba with Sonya's door; the chapel plaza. Added for this
chapter: **a gate south out of the plaza, the only way out**, with a lever beside it, and Marta
sitting in front of it, floating, head down, still seated in a chair that isn't there.

**No NPCs to talk to.** The monsters were people (the infected generator: every one different),
and Kurt can talk to them as himself once he knows who they were:

| Monster | Where | What it keeps saying | What Kurt needs |
|---|---|---|---|
| The porter | the hotel room, his back to the door | *"Room four. Room four."* | **Her Handwriting** + having looked at the photo strip in that room |
| The lamplighter | walking the main street | *"Thirteen... thirteen..."* | **These Streets** + having walked round the seam |
| Marta | the gate | *"...Have you seen..."* | **Old Name** + having looked at the TRICKSHOT poster in the square |

Known, they stop, say one human thing, and stay down (and give back a nugget). Unknown (the
prompt says **Talk (?)**), Kurt gets as far as *"Hey. Hey, easy..."* and they come for him.

**Three ways out:** the gun (the Nagant: seven rounds, loaded one at a time; taking it wakes
Marta and she comes for him; four hits drive her off the gate for 25 s, or Headshot ends her);
sneaking (everything hears: steps, shots, a thrown cobble where it lands, the lever, which is
loud); talking. Caught, he comes to where he came in. Through the gate: white, and the title.

Nuggets (14, plus one per monster talked down) buy skills from two trees in any order
(`content/skills.json`); the talk route alone costs 8.

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
they're Socko's reaction. Every line of Scene A and the town has them.

## Content

`content/scene_a.json` and `content/town.json`: every line (text, speaker, Socko's cues), the
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
| Skills | SKILLS | Y / Back | Tab / K |
| Pause | ‖ or Back | Start | Esc |

## The issues raised about the first build

| Issue | Now |
|---|---|
| Lighting flicker | Every light is steady (the flat's flicker models are gone; the failing bulbs are just dimmer). No shadow maps. A room's lights fade in and out slowly as you come and go, so no mesh is ever over the phone renderer's light limit (which is what made walls pop). |
| No sound | All sound is synthesised in the game at start-up; voices use the phone's text-to-speech. |
| Broken animations | One controller per character, posing the first build's rigs by name, eased; tested through every beat. |
| Door out of the waking room not locked | The living room door is shut and locked after the blackout; tested at the end of Scene A. |
| Crash through the gap on Android | The town is built behind the black once, the flat switched off while you're in it; lamps beyond 22 m are off on phones; no moon light on phones. Not yet tried on a phone. |

## Build and test

```
tools/test.sh                 # three full playthroughs from the first knock (talk, gun, sneak)
tools/test.sh kill            # one
tools/test.sh shots DIR talk  # rendered, a frame per line
tools/build_apk.sh            # → ../dist/Hysteria.apk, signed, or it fails
godot --path . -- --start=wake|door|wardrobe|town
godot --path . -- --start=door --poses --shots=DIR    # Kurt himself: looking down, the gun
```

## Not done yet

What's past the gate; Flat 48; Sonya's shoes; saving; the dialogue graph and cutscene tools.
