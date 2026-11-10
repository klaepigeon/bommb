# HYSTERIA: the Android-first rebuild (Godot 4.7)

A clean rebuild of HYSTERIA, starting from **Scene A**. It's built for phones first: touch
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
| **Open** the front door (now shut) | It rattles. *"It won't open."* *"Maybe it's locked?"* *"Wow, thanks. I never would have guessed."* *"You're welcome!"* and, quieter, to himself, *"I like helping."* |

The lines live in `content/scene_a.json`. Edit the text there and the game uses it. Speakers'
colours and voice pitches are in `content/characters.json`.

## Controls

| | Touch | Gamepad | Keyboard / mouse |
|---|---|---|---|
| Move | left half of the screen: a stick appears under your thumb | left stick | WASD / arrows |
| Look | drag on the right half | right stick | mouse (click to capture) |
| Use | the round button (it appears when there's something to use) | A | E / Space / click |
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
| Crash passing through the gap on Android | The rebuild has no gap or town yet. They'll be rebuilt on this base and tested the same way before they ship. |

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
scripts/story/      scene_a (the beats), autopilot (plays it through and checks)
scripts/ui/         controls (touch first; pad; keyboard/mouse), hud (prompt, fade, pause)
```

## Build and test

```
tools/test.sh                 # headless: plays Scene A through the real controls, checks all 24
                              # lines in order and the front door shut (exit code 0 = pass)
tools/test.sh shots DIR       # same at real speed, rendered, a screenshot per line
tools/build_apk.sh            # → ../dist/Hysteria.apk, signed, or it fails
godot --path . -- --start=wake   # jump to waking up (or --start=door)
```

Needs Godot 4.7 with its export templates, and for the APK the Android SDK (build-tools) and a
JDK set in Godot's editor settings.

## Not rebuilt yet (from the master documents, and in `legacy/hysteria/`)

Everything after Scene A: the escape from Flat 47, Flat 48, the town and the labyrinth, Marta as
a hunter, weapons, skill trees, saving, the dialogue graph and cutscene tools. The infected
enemies for the town are on the `ccr-51f7ea99-p2a8i9` branch. The plan is to bring each one over
as its own scene, tested the same way.
