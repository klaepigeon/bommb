# Socko in Godot: what's built

How the Socko animation bible maps onto `hysteria/`, and what isn't done yet. Canon from
`docs/STORY_BIBLE.md` is unchanged: a dirty striped sock with big googly eyes and a red felt
tongue on the protagonist's **left** hand, there **only** after he wakes.

## Files

| File | What it is |
|---|---|
| `scripts/socko/sock_rig.gd` (`SockRig`) | The forearm, hand and sock as **one skinned mesh on one skeleton**: forearm → hand → fingers → fingertips (upper jaw) / thumb → thumbtip (lower jaw). The coat sleeve, the googly eyes (on a `BoneAttachment3D` on the finger bone, with loose simulated pupils). |
| `scripts/socko/socko.gd` (`Socko`) | The performance controller: the bible's four layers (§3), emotions (§5), gestures (§6), gaze priority (§7.2), speech (§7.5), independent intention (§9). |
| `scripts/socko/socko_intro.gd` (`SockoIntro`) | Story bible beats 9–10: the hand rising, then the six introduction lines, waiting on the player. |
| `shaders/ps1_cloth.gdshader` | The PS1 shader for cloth: unfiltered, vertex-snapped, double-sided, with felt's fuzzy rim. |
| `scenes/socko_test.tscn` | The test bench (bible §16): first person, close-up and side views, a skeleton overlay, every emotion and gesture on a key, speech, the jaw and fist by hand, the lights, the layer-D switches, playback speed. Keys are listed at the top of `socko_test.gd`. |
| `tools/socko_test.gd` | Automated check: the rig's mechanics, then the introduction in the real flat with a scripted player, with frames saved at each beat. |

## How the hand makes the puppet

- **The mouth is the hand.** Opening the mouth lifts the finger bones at the knuckles and drops
  the thumb from the web. The cloth of the head is weighted to those bones and splits along the
  mouth line. The fabric between the jaws is a pocket that folds flat when shut and stretches
  open (red felt) when open. Near the corners the cloth is weighted to both jaws, so a wide mouth
  pulls the cheeks in rather than hinging. There is no separate jaw object.
- **Fist / extend** (`curl`) folds the head in or stretches it. **Squash** slumps or tenses the
  cloth. Both are driven by emotion and by jolts of the hand.
- **The arm is attached to the body**, below and left of the camera. Three held poses are
  blended: ahead (default), low (running, or both hands busy inspecting something), and turned
  back to face Kurt (forearm up, back of the hand away, the wrist bent forward so the face comes
  round to him with the top of the head up). Only the swing from the elbow lags behind a turn. A
  ray pulls the hand in against walls and doors.
- **The head aims within a wrist's range** (about ±50° to the side, 60–65° up and down). Layer D's
  `beyond` lets him go up to 70% further: that's the supernatural tell, off by default.

## Layers

| Bible | Built as |
|---|---|
| A: hand | arm poses, walk bob, lag, pull-in, hand busy → lowered |
| B: puppet | 12 emotions (neutral, happy, curious, nervous, impatient, distracted, disappointed, angry, furious, lying, uncanny, sleeping) blended over ~0.4 s; 11 gestures (nod, shake, point, recoil, wave, cover, lean_in, beckon, wince, bounce, look_round) with anticipation and settle |
| C: secondary | the head on a spring behind the wrist (overshoot, lag from the arm's turn), squash from vertical jolts, loose googly pupils (gravity, the hand's acceleration, rattle on the rim) |
| D: intention | `attend()` holds his gaze on a point regardless of the arm; `stillness` kills every wobble; `beyond` lets him turn too far; `resist` makes the hand drag behind the arm; `ghost_mouth` keeps the mouth going after the line ends |

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
- **Hand occupancy** is coarse: he lowers out of the way only while an object is being turned
  over. The torch and carrying are in the right hand.
- Tested on desktop under software rendering only, not on an Android device yet.
