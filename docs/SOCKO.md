# Socko in Godot: what's built

How the Socko animation bible maps onto `hysteria/`, and what isn't done yet. Canon from
`docs/STORY_BIBLE.md` is unchanged: a dirty striped sock with big googly eyes and a red felt
tongue on the protagonist's **left** hand, there **only** after he wakes.

## Files

| File | What it is |
|---|---|
| `scripts/socko/sock_rig.gd` (`SockRig`) | The forearm, hand and sock as **one skinned mesh on one skeleton**: forearm → hand → fingers → fingertips (upper jaw) / thumb → thumbtip (lower jaw), plus two **mouth-corner bones** in the cheeks (smile, frown, wide, pucker). Stretch and twist. The coat sleeve. The **ping-pong-ball eyes** (skinned seats, independent googly eyes, physical pupils). The **stain layers**. |
| `scripts/socko/socko.gd` (`Socko`) | The performance controller: the bible's four layers (§3), emotions (§5), gestures (§6), gaze priority (§7.2), speech (§7.5), independent intention (§9). Adds the director's offsets, springs stretch and twist, shapes the mouth per syllable. |
| `scripts/socko/socko_clips.gd` (`SockoClips`) | The animation library: 73 authored clips (idles, faces, head, talking, physical comedy, entrances, exits) and 16 expressions, as functions of time on shared channels. |
| `scripts/socko/socko_director.gd` (`SockoDirector`) | The animation director: prioritised clip layers, the held expression, the emotional performance state, each eye's attention, dialogue cues, cutscene timelines and transitions. |
| `scripts/socko/socko_intro.gd` (`SockoIntro`) | Story bible beats 9–10: the hand rising, then the six introduction lines, waiting on the player. |
| `scripts/socko/socko_tutorial.gd` (`SockoTutorial`) | The bible's tutorial lines, each once, when relevant: walking, crouching (prompted, then "you've done this before"), the first pickup, turning something over too long, the first loud drop or throw. Each comes with a short control hint (keyboard, pad or touch wording). |
| `scripts/socko/socko_hud.gd` (`SockoHud`) | Top left: "OBJECTIVE · Find Marta Sokolova." before him, then "SOCKO SAYS · Find a way out of Flat 47.", as in the JS build, plus the hint line. |
| `scripts/core/noise.gd` (`Noises`) | Noises things can hear. Thrown and dropped props thud and report an impact (loudness from speed and mass). Socko turns his head to any noise; Marta's hunting can listen to the same thing. |
| `shaders/ps1_cloth.gdshader` | The PS1 shader for cloth: unfiltered, vertex-snapped, double-sided, with felt's fuzzy rim. |
| `scenes/socko_test.tscn` | The test bench (bible §16). A panel (Tab) plays every clip, holds every expression, sets every state (and obeyed / defied), aims each eye by hand or runs every eye behaviour (one button for the sympathetic listening glance), tests pupil inertia, deforms the head by hand, previews the transitions and performed dialogue, jumps the camera to front / three-quarter / side / top / back / low, and inspects the stains (each layer on a slider) under five lights. Keys still work; listed at the top of `socko_test.gd`. `-- shots=<dir>` renders a review tour. |
| `tools/socko_test.gd` | Automated check: the rig's mechanics, then the introduction in the real flat with a scripted player, with frames saved at each beat. |
| `tools/socko_anim_test.gd` | Automated check of the overhaul, by measurement on the bench: eye separation and clipping over 42 extreme poses and every clip, independent eyes and divided attention, pupil inertia and rest, expressions, all 73 clips (and that none leaves him deformed), states, cues, entrances, interruption, stains. |

## How the hand makes the puppet

- **The mouth is the hand.** Opening the mouth lifts the finger bones at the knuckles and drops
  the thumb from the web. The cloth of the head is weighted to those bones and splits along the
  mouth line. Inside are two muted red felt mouth plates, a palate glued under
  the upper jaw and a floor over the lower one (tongue on it), folded together at the hinge
  between the corners. Each is skinned to its own jaw, so an open mouth shows a felt puppet mouth,
  not a membrane sagging between the jaws into a black pit. Near the corners the cloth is weighted to both jaws, so a wide mouth
  pulls the cheeks in rather than hinging. There is no separate jaw object.
- **Fist / extend** (`curl`) folds the head in or stretches it. **Squash** slumps or tenses the
  cloth. Both are driven by emotion and by jolts of the hand.
- **The arm is attached to the body**, below and left of the camera. Three held poses are
  blended: ahead (default), low (running), and turned to face Kurt. Facing him works the way
  people hold a puppet up to themselves: **palm down the whole time** (the thumb stays under the
  fingers, so his head stays the right way up), elbow out in front, forearm brought across the
  body toward the right, and the wrist turned in so the face comes round to him at about three
  quarters. Only the swing from the elbow lags behind a turn. A ray pulls the hand in against
  walls and doors.
- **Kurt's hands:** the right (`KurtArm`, see docs/KURT.md) does everything: interacting,
  carrying, throwing, weapons. The left is Socko's and is never busy.
- **The torch is in his mouth.** From the moment Socko appears, Kurt's torch light comes out from
  between his jaws, and nobody explains it. [F] / the TORCH button switches it. He holds his mouth
  open for it and aims it where Kurt is looking (what's under the crosshair). It's as bright as
  his mouth is open, so it pulses when he talks, and the felt inside his mouth glows. Layer D
  `attend()` can take the beam off somewhere on its own.
- **The head aims within a wrist's range** (about ±50° to the side, 60–65° up and down). Layer D's
  `beyond` lets him go up to 70% further: that's the supernatural tell, off by default.

## The eyes (rebuilt)

**Why they overlapped:** the old eyes were flat discs of radius 0.024 m glued at ±0.5 rad on the
narrow top of the head, which put their centres ~0.025 m apart: they overlapped by ~0.022 m in the
model itself.

**Now:** each eye is a white **ping-pong ball** (radius 18.5 / 19.1 mm: one's a touch bigger; a
moulding seam, a worn printed star, a scuff, yellowed underneath) glued into a nest in the felt,
with a craft-store **googly eye** stuck on it: black rim, black card, clear raised dome, loose
black pupil. The seats are set wide on the head (±0.7 rad) so the balls stand 20 mm apart, and
each seat is **skinned on the CPU with the cloth's own weights** at that point, so the balls ride
squash, stretch, twist, the jaw and the fist exactly, without drifting, sinking or changing size.
Over 42 extreme poses and every clip the gap never drops below ~6 mm (`socko_anim_test`).

**Independent gaze:** each googly eye turns on its ball (up to 1 rad from straight ahead, never
into the felt) toward its own target at its own rate. By default both follow his attention, the
left a touch quicker. The director can give either eye its own target (`eye_track`), and has the
behaviours: `divided_attention` (the signature, below), `examine`, `sound_glance`,
`staggered_return`, `upward_glance`, `fixed_while_turning`, `converge`, `track_and_distracted`,
`sync_snap`. How often an eye wanders on its own depends on the state (never as presenter, now and
then as companion, most as manipulator).

**Divided attention:** while he's listening to Kurt, warm, eyes on him, one eye (the one on that
side) slides off to the thing he wants Kurt to notice (`agenda`, or any target), holds ~0.75 s, and
comes back unhurried; the other never leaves Kurt and the head doesn't move. Triggered by
`{divided:...}` in a line, a cue, a timeline, the bench, or on its own (manipulator; sympathetic
lines with an agenda). In the labyrinth his agenda is the next turn toward the revolver.

**Pupils:** the googly physics as before (gravity, the hand's acceleration, sticking, sliding,
bouncing, running to the lowest point), now with per-eye friction and bounce (they settle apart),
the rim's own friction (no chatter: idling, they rest), and the googly eye's turn carried by the
shortest arc (its "down" never jumps).

## Material: contamination

Three layers in a stain map (UV2, wrapped round the arm so it runs over the head without a seam),
multiplied into the cloth so the knit, stripes, folds and grime show through; soaked fibres lose
some fuzz. Vertex colours (skinned with the cloth) mark what faces down and what's near a seam.
- **Old blood:** faded rust to dark brown, absorbed edges, darker tide lines and clots; round the
  mouth and chin, a washed-out wash under the forearm, a run back from the chin, flecks by his
  right eye.
- **Mould:** grey-green patches and speckle, growing from the cuff, the wrist's bunching, the mouth
  line and the nose.
- **Urine:** broad yellow-brown tide-marked patches, kept to the faces that point down.
`SockRig.set_stains(amount, blood, mould, urine)`; the bench has sliders and five lights.

## The director

`SockoDirector` (Socko's `director`) layers clips by priority: **0 cutscene, 1 reaction,
2 dialogue, 3 idle, 4 background**. A clip that masks "body" or "face" fades the layers below it
out of that group as it fades in; the cutscene layer masks everything. Clips without masks add
(a nod over talking over an idle). The **expression** sits above the idles. The eyes are their own
channel (they run under any body clip). Everything is an offset that ends at zero; the QA checks
no clip leaves him deformed.

**States** (`set_stage` from the story, `obeyed` / `defied` from the player, `set_state` for
scripts): **presenter** (bouncy, big smile, excited talking), **companion** (settled, leaning in,
nods), **manipulator** (still, held smile, sympathetic talking, divided attention),
**frustrated** (sharp, forced smile, irritation flashes that he covers), **angry** (threatening
idles, forced smile; now and then he goes dead still, then straight back to cheerful). Defiance
2 → frustrated, 4.5 → angry; it decays, and doing what he wants brings him back. Wired: the
intro (presenter), walking off (companion), the labyrinth (manipulator), looking at clues and
buying memory skills (defied), calming Marta with Sonya's shoes (heavily defied), the revolver, Headshot, Marta dead (obeyed), the key and the bath
(defied), the axe or gun on the chain (obeyed).

**Dialogue:** `say(text, emotion, volume, style, cues)`. Inline cues in `{}` fire on the next word
and are stripped from the subtitle and the voice: `{expr:NAME[:hold]}`, `{eye:L|R|B:SPEC[:hold]}`,
`{eyes:SPEC}`, `{divided[:SPEC]}`, `{clip:NAME}`, `{g:GESTURE}`, `{state:NAME}`, `{pause:secs}`,
`{interrupt}`, `{notice:SPEC}`. SPEC: kurt, up, down, agenda, ahead, or a registered target. The
talking clip follows the line's emotion and his state unless `style` names one. Mouth shapes vary
per syllable (o/u purse, e/i widen, m/b/p close). `perform([{t, do, ...}])` runs a cutscene
timeline; `sequence(name)` the six transitions (presenter_laugh, presenter_manipulative,
sympathetic_divided, friendly_frustrated, observe_snap, angry_realize).

**Entrances / exits** move the real arm (no teleports): from behind (the frame's edge), doorway
(forward from against the body), pop, rise, lean in, already there when you turn round
(`appear_when_turned`), retreat, drop, between cuts (`exit_between_cuts`: gone during the next
fast camera turn).

## Layers

| Bible | Built as |
|---|---|
| A: hand | arm poses, walk bob, lag, pull-in, hand busy → lowered |
| B: puppet | 12 emotions (neutral, happy, curious, nervous, impatient, distracted, disappointed, angry, furious, lying, uncanny, sleeping) blended over ~0.4 s; 11 gestures (nod, shake, point, recoil, wave, cover, lean_in, beckon, wince, bounce, look_round) with anticipation and settle |
| C: secondary | the head on a spring behind the wrist (overshoot, lag from the arm's turn), squash from vertical jolts, real googly eyes (below) |
| D: intention | `attend()` holds his gaze on a point regardless of the arm; `stillness` kills every wobble; `beyond` lets him turn too far; `resist` makes the hand drag behind the arm; `ghost_mouth` keeps the mouth going after the line ends |

**Googly eyes** behave like real ones: each pupil is a loose disc between a card and a clear dome,
simulated in real units. Gravity, plus the hand's acceleration felt as a push the other way,
slides it. It sticks on the card when the slope is gentle, bounces off the rim, and runs round the
rim to the lowest point. The pupils have no idea where he's looking; his attention is in his head.
The one exception is layer D: when he's being wrong (stillness, `beyond`) the pupils can hold on a
target against gravity, which no googly eye can do.

**Lying** is precise, not bubbly: high stillness, minimal wobble, eyes held on Kurt, a fixed
slight smile (bible §5.7). In the introduction, "Physically." and "She's gone. Don't look at the
chair, bud. Look at me." are performed as lies.

**Speech:** the subtitle, plus the system TTS in a higher register (pitch and rate vary with
emotion). The mouth follows a syllable schedule built from the text: each vowel sets how far it
opens, m/b/p close the lips, punctuation pauses. Where the platform reports TTS word boundaries
(Android does), the schedule is resynced to the voice word by word. Quiet lines open less;
angry and furious lines open wider and lopsided.

## Not done / known gaps

- **Blinking (bible §7.3):** googly eyes have no lids, so nothing is built. Attention is carried by
  head aim and the drift of the pupils instead. If lids are wanted, that's a design change to the
  canon look.
- **Full first-person body** (other prompts): not started. Only the left forearm and hand exist;
  there's no right hand, legs or torso. The left hand also isn't visible *before* the blackout,
  because it would need a bare-hand mesh.
- **Recorded voice / visemes:** the system is ready for timing data, but there are no recordings.
  TTS can't whisper or rage, so emotional delivery today comes from the puppet, not the voice.
- **Fabric wrinkles** are static folds plus skinning. There are no dynamic wrinkle maps.
- **The library is procedural, not keyframed:** clips are authored functions on shared channels
  (so they work on any arm pose and stack), not AnimationPlayer tracks. An animator can't scrub
  them in the editor; the bench is the place to look at them.
- **Talking styles and states have no recorded voice to match:** TTS can't whisper or rage.
- **Ricky** was a reference for principles only (anticipation, overshoot, holds, peeking); no
  model, proportions, look or animation is taken from him.
- **Not yet wired in the story:** most of the 73 clips (comedy, entrances) are available to
  scripts and the bench but only the gestures, talking, idles, states and glances run in play.
- **Tutorial lines not yet wired:** the pistol, reloading, the bath, the bolt, and sparing or
  killing her. They need systems that don't exist in Godot yet.
- **Weapons:** none exist in Godot yet; they go in Kurt's right hand (`KurtArm`, docs/KURT.md).
- Tested on desktop under software rendering only, not on an Android device yet.
