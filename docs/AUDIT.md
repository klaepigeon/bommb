# HYSTERIA — Project and Asset Audit

Deliverable 2. What exists in `klaepigeon/bommb` as of commit `5276b90`, measured against the
master development prompt. No assets or systems are listed here that are not in the repository.

## 0. The headline problem: engine

The master prompt specifies **Godot 4**. **There is no Godot project for HYSTERIA.** What exists
is a **Three.js (WebGL) game in JavaScript**: about 7,300 lines in `src/`, bundled by esbuild into
one HTML file (`dist/index.html`), and an Android app (`android/`) that wraps it in a WebView.
(The only Godot project in reach is RATFORMER in `klaepigeon/video-game`, an unrelated game.)

There are **no imported 3D models, rigs, skeletons, animation clips, textures, or audio files** at
all. Every mesh, texture and sound is generated in code at load time. So the prompt's audit items
"player models and rigs", "Socko model and rig", "animations" refer to things that **do not exist
as assets** — what exists are procedural equivalents, described below.

Everything else in this audit is written so it's useful whichever way the engine decision goes.

## 1. What already works

| Area | What exists | Files |
|---|---|---|
| Flat 47 layout | 7 rooms + balcony, real door/window openings, collision, floors, ceilings, two ceiling collapses, a floor hole | `plan.js`, `shell.js` |
| Surfaces | Per-face procedural painting: wallpaper, damp, mould, peel, brick, tiles, parquet; bump maps | `textures.js`, `surfaces.js` |
| Dressing | Furniture with working doors and drawers, ~120 physics props, readable documents, the family's story in objects | `furniture.js`, `dress.js`, `dress2.js`, `docs.js` |
| Interaction | Raycast targeting, use/open/take/read, carry, inspect (rotate in hand), throw | `interact.js`, `props.js` (cannon-es physics) |
| Doors | Hinged leaves with collision and physics; locked/stuck/bolted variants; the chained front door with padlock; peephole | `openings.js` |
| Movement | Walk/run/crouch, circle-vs-box collision, floor regions and stair ramps, footsteps per surface | `player.js`, `core.js` |
| Lighting | Switches, fuse box with circuits, flicker models, torch; pooled lights in the building | `lighting.js`, `building.js` |
| Audio | All synthesised: ambience director, positional sources with room occlusion, footsteps, doors, knocks, stings | `audio.js` |
| Opening | Cutscene (courtyard → lobby → stairs → door → shut behind you) with subtitles and skip | `cutscene.js` |
| The woman | Marta: low-poly PS1-style (vertex snapping, pixel textures), coral, breathing; look → touch → grab → "Have you seen the boxes?" → blackout → wake | `marta.js` |
| Hands | Procedural first-person arms: two-bone IK from an off-screen shoulder, finger curl, torch hand, held items, reach; drawn in their own pass | `hands.js` |
| Socko | Procedural tube along a bending spine on the left hand: googly eyes with loose pupils, hinged mouth, tongue, posture/nod/lag, talks via TTS | `hands.js`, `voice.js` |
| Dialogue | TTS (Android native / browser / babble fallback), Socko line queue, objectives HUD, first-time tips | `voice.js` |
| Platforms | Desktop browsers, Android APK; keyboard/mouse, touch, gamepad (incl. native Android bridge) | `main.js`, `gamepad.js`, `android/` |
| Tests | Headless scripted playthroughs and screenshot tours (Playwright) | `tools/*.mjs` |

## 2. What can be reused (either engine)

- **The apartment design**: floor plan dimensions, room purposes, door swings, furniture layout
  and the environmental story (calendar, fridge note, den, bath key, barricade, bolt). This is
  engine-independent data and design.
- **All written text**: documents, item descriptions, Socko lines (to be rewritten per the bible).
- **The opening's shot list and pacing**, Marta's staging, the encounter state machine.
- **System designs** that map directly to Godot nodes: doors (hinge + kinematic body), drawers,
  props (RigidBody3D), circuits/switches, pooled lights, the ambience director, the decay shader
  idea (Godot shader), PS1 vertex snapping (Godot spatial shader), first-person hands IK
  (SkeletonIK3D / custom two-bone IK).
- **If staying in Three.js**: effectively all of it.

## 3. What needs improvement (measured against the prompt)

- **Story** (prompt §3): the current build diverges from the established opening — see §5.
- **Protagonist** (§4): no body animation beyond procedural arm poses. No idle layers, no
  age/injury in movement, no contextual animations for doors, drawers, pickups, being grabbed,
  falling. No muscle-memory behaviours.
- **Socko** (§5): he is a tube *over* the hand, not a sock *conforming to* a hand. The mouth is a
  separate hinged shell, not fabric driven by fingers and thumb. There is no shared hand+puppet
  rig: the hand meshes are simply hidden when Socko is on. No emotional states beyond
  talking/idle. No gestures (pointing, covering his face, pulling away, resisting). Speech
  animation is a sine-based flap, not phoneme-like.
- **Character test scene** (§5.9, §10): none.
- **Visual consistency** (§11): Marta is PS1-styled; the flat is higher-detail procedural PBR.
  The prompt wants one late-90s look throughout.

## 4. What is missing entirely

- **Inventory** (no inventory at all: one held item at a time).
- **Weapons**: no firearms, aiming, ammunition or reloading; no melee.
- **Health, injury, recovery**: none.
- **Enemy AI**: no hearing, vision, investigation, detection or search. (A noise hook,
  `G.onNoise`, is emitted by footsteps and impacts but nothing listens.)
- **Stealth**: crouch exists; cover, hiding, detection and distraction systems don't.
- **Two escape approaches as systems**: only the key and the axe exist; no infected inhabitant
  to deal with.
- **Save and reset** (§14): none (refresh restarts).
- **Socko's agenda**: his lines are friendly guidance only; no manipulation, no emotional
  progression, no reactions to player choices.

## 5. Story divergences to resolve (current build vs. prompt §3.1)

| Prompt | Current build | Fix |
|---|---|---|
| Russia, 1996 | Fictional city, date unspecified; Soviet-era wording | Set 1996; adjust notice wording |
| Woman fused to a chair | Sitting on the box-room floor, rooted by coral | Move her to her chair at the dinner table (bible §5) |
| Covered in mould *and* coral | Coral only | Add mould |
| Player has time to observe; she asks; *then* grabs suddenly | Grab triggered by touching her face | Proximity/linger trigger; question first; grab without warning |
| Protagonist: retired superhero, amnesiac | PI named Lebedev; no amnesia beat; no past | Bible §2: keep the name on his papers; amnesia on waking; past only in his body |
| Socko friendly but secretly manipulative | Friendly guide only | Rewrite lines (bible §6); add agenda reactions |
| Tutorial with threat, stealth, combat | Exploration and puzzles only; no threat | Infected Marta as the hunting threat after waking |
| Focus on Flat 47; don't expand the building | The whole building exists (stairwell, 44, 48, 51, lobby, void, decay system) | Freeze it: gate it off for the vertical slice (keep the code) |

## 6. Technical problems to address

1. **Engine decision** (§0) before any further implementation.
2. **Real-device performance is unmeasured.** All testing has been headless with a software
   renderer. Android performance in a WebView is unknown.
3. **Animation fidelity ceiling in the current stack**: there is no skinned mesh, skeleton or
   animation-clip pipeline. A convincing hand-inside-a-sock with finger-driven fabric (prompt §5)
   needs a skinned hand plus a skinned or deformation-driven sock sharing bones. That is possible
   in Three.js (SkinnedMesh, procedural bones), but it would have to be built from scratch in code
   with no modelling tools; Godot would at least provide Skeleton3D, IK and AnimationTree.
4. **No authored assets.** A PS1 look and a convincing hand rig are both much easier with
   modelled assets (Blender → glTF) than fully procedural geometry. There is no Blender in this
   environment; procedural generation remains the only asset source here unless models are
   supplied.
5. **Mixed rendering styles** (PBR flat vs. PS1 Marta) need one direction.
6. **TTS voices vary by device** and are not tunable for emotion beyond pitch and rate; the
   prompt's emotional delivery (whispering, anger) will need either recorded lines or a richer
   synthesis approach.

## 7. Recommendation

The prompt's priorities (skinned first-person body, finger-driven puppet, AnimationTree-style
layering, PS1 look, PC + Android) point to **Godot 4**, and Godot 4 can be downloaded and run
headless here for building and testing. A port would reuse the design, story, layout and text
above, but **not the code**: it is a rewrite of every system. The alternative is to continue in
Three.js, which already runs on both targets, and treat the prompt's Godot terms as functional
requirements. This is the owner's call; nothing further is implemented until it's made.
