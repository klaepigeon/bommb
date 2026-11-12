# Feel

How moving, looking and hitting are tuned so Kurt has weight.

## Moving (`scripts/player/player.gd`)

- **Footsteps on the bob.** Each step plays at the bottom of the head bob, so the sound and the camera agree. Standing still, the bob settles back to centre instead of freezing mid-stride.
- **Landing.** After at least 0.12 s in the air, his knees take the landing. A damped spring dips the head and recovers with a slight overshoot. The dip is deeper the further he fell. A step plays, a thud plays if the drop was hard, the camera shakes, and the landing makes a noise she can hear.
- **Lean** (**Z** / **X**, or the D-pad left and right). His head moves up to 34 cm to the side and tips about 6°, so he can look round a corner without stepping out. It stops short of walls.
- **Strafe roll.** Moving sideways tips the head slightly.
- **Breathing.** Standing, the view rises and falls with his breath. It's faster when he's winded.
- **FOV.** The base is 72°. It widens by 5° at a full run, and narrows for a moment on a heavy blow (`fov_kick`).

## The things in his hands

The hands, Socko and the pistol share one sway (`_viewmodel`):

- They lag behind where he looks.
- They ride the walk.
- They dip on a landing.
- They pull back slightly at a run.
- They shake with his fear (see SYSTEMS.md).

## Hitting

- **Hit-stop.** `Fx.hitstop(secs)` holds the world at 5% speed for a few hundredths of a second as a blow lands:

  | What was hit | Normal blow | Heavy blow |
  |---|---|---|
  | Marta | 0.05 s | 0.09 s |
  | A wall | 0.035 s | 0.06 s |
  | A loose thing | 0.03 s | 0.03 s |
  | Bullet into her | 0.05 s | – |

  It never stacks and never lasts longer than 0.12 s. Afterwards `Engine.time_scale` is put back exactly as it was, so scripted slow motion survives. It can be turned off with the `hitstop` setting.
- **Impact bursts.** `Fx.burst(kind, pos, normal)` throws a one-shot spray of bits off the surface that was hit:
  - **dust:** plaster, from walls and bullet holes
  - **wood:** splinters, from furniture and props
  - **glass**
  - **flesh:** from her
  - **spark:** from a bullet off something hard

  They use CPU particles (GL Compatibility), cast no shadows, and free themselves.
- **Knock.** A blow sends a loose thing forward and slightly up, never down into the table it's on, which would only pin it there by friction.

## The torch

The light comes down as the thing it's pointed at gets closer: 22% at a wall in his face, full from 2.2 m. The spot also widens from 26° to 34°. So a near wall gets a soft pool of light instead of a flat white disc.
