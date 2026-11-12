# Systems under the hunt

These systems feed each other. Kurt's fear makes him louder. Loudness brings Marta. Marta brings fear. Hiding stops her seeing him, but not hearing him. His held breath stops her hearing him, but it runs out, and running out is loud.

## Nerve (`scripts/player/nerve.gd`, `Game.fear` 0..1)

| | |
|---|---|
| **Rises** | Seeing her, more the nearer she is (up to +0.7/s). Her chasing him (+0.35/s). Her being within 6 m, seen or not. Scripted frights add to it directly through `spike()`: the jump scare, the scream, the maze's first sighting. The Infection tree can scale all of this with `Game.stat("fear_rise")`. |
| **Falls** | Slowly anywhere (0.04/s). Twice as fast crouched and still. Much faster in a safe room (0.3/s). |
| **Heart** | The `heart_loop`. Silent below about 0.15, and faster and louder as fear rises (pitch 0.9 to 1.75). |
| **Hands** | Above 0.3, the viewmodel trembles. Above 0.4, the pistol's aim drifts by up to about 2°. |
| **Sight** | The post shader closes the vignette in and drains the colour. It is steady and never pulses (photosensitivity). |
| **Breathing** | Above 0.5, ragged breaths come every 1.6 to 3.4 s. Each one is a noise Marta can hear (0.1 to 0.22), unless he's holding his breath. |

Fear isn't saved. He calms down between sessions.

## Holding his breath

Bound to **B**, the right stick click, or the touch **BREATH** button. The button appears when he's hidden, or when his fear is above 0.25.

- **While held:** no ragged breaths, so he's silent. Fear creeps up slightly.
- **Limit:** 7 s, or more with the Lungs node.
- **When he can't hold any longer:** he gasps. That's a 0.45 noise, which she hears from about 7 m. He can't hold his breath again until half his air is back, which takes about 1.5 s.
- **HUD:** a white bar while held. It turns red under 30%.

## Hiding (`scripts/world/hide_spot.gd`)

There are five wardrobes in the maze. They're along corridors and in dead ends, never next to a safe room. Placement is seeded, the same every time.

- **Getting in or out** creaks the doors, a 0.22 noise.
- **Inside**, he looks out through the gap between the doors. He can look about ±25° left and right and a little up and down. The torch still works, and its light shows through.
- **She can't see into a wardrobe.**
- **She saw him get in:** if she had him in sight within the last 1.2 s, or was chasing him within 2.5 s, she switches to `fetch`. She goes straight to it and drags him out.
- **She's hunting nearby:** if she's investigating or searching and stops within 3.2 m of the wardrobe he's in, she switches to `listen`. She's bent to the doors, with her ear to them.
  - Each second she's "sure" by 0.08 + 0.35 × fear, unless he's holding his breath, in which case it's 0.
  - Any noise from inside counts at once: a gasp, the doors.
  - After 4.5 s she gives up on that wardrobe for 25 s.
- **HUD hint:** when she starts listening, he's told to hold his breath.

## The torch's battery (`Game.torch_charge`, saved)

- **Drain:** a battery lasts 5 minutes of light.
- **Running down:** it doesn't cut out. It stays at full brightness down to a quarter, then sags slowly to 15%, so it never strobes.
- **Batteries:** there are three in the maze's dead ends. Each one fills it again.
- **HUD:** an amber bar while the torch is on, which turns red under a quarter.
- **The trade-off:** the torch also makes him visible from 1.6× further away. Light against being seen.

## Lures

Anything thrown makes a noise where it lands. It's louder for heavier, faster things, and louder still for glass. She investigates noises. So a bottle thrown down a side corridor pulls her off the route he wants.

## Tests

`tools/systems_test.gd` checks every rule above. It also checks three of the feel features: the landing, leaning and the hit-stop.
