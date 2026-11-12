# The opening scare, and Marta

How the first Marta sequence in Flat 47 is built, and why. Code: `scripts/levels/flat47.gd`
(`_murmur`, `_tells_unseen`, `marta_stirs` / `marta_turns`, `_dead_air`, `_the_jump`,
`_place_jumper`), `scripts/characters/marta_seated.gd` (`reveal`, `gaze`, `unhinge`, `stage`).
Render it with `tools/scare_view.gd`; her stages with `tools/marta_stages.gd`.

## What makes a scare work (what this is built on)

- **Dread beats shock.** Anticipation is most of the fear. The jump is the release of tension
  that's been built, not a replacement for it. Without the build, a jump is a startle that's
  forgotten in seconds.
- **Withhold the creature.** What isn't seen is worse than what is. Every full look at a monster
  spends some of it. The face is the most expensive thing she has; spend it once, late.
- **False security, then a broken rule.** Let the player learn a rule ("she's dead", "she only
  moves when I'm not looking", "she's across the table") and then break it. The scare is the
  violated expectation.
- **Silence before the hit.** Dead air makes the player lean in. Sound dropping out is itself a
  warning, and the contrast makes the hit land.
- **Don't land on the beat.** If the scare comes exactly when the rhythm says it will, it's
  absorbed. Hold it longer than is comfortable.
- **Agency and attention.** The best tells happen where the player isn't looking and are
  discovered when they look back. It makes the player complicit, and doubt their own eyes.
- **Human first, monster second.** A creature that's still recognisably a person, with one
  thing still hers, is worse than a pure monster: pity curdles into horror.

## Creature design: Marta

- **Silhouette first.** At the table she reads as a little old woman bent over her dinner: the
  silhouette is ordinary. The wrongness is in the details as you get close (coral through the
  shoulders, flesh sliding into her lap, the puddle).
- **The face is withheld.** Head bowed to her chest, wet hair hanging straight down over her
  face (`_hang_veil`: it hangs with gravity whatever her head does). Kurt stands and leans over
  the table, so he's looking down at the crown of her head, not up under the hair.
- **One thing still hers.** Her good eye has a real, wet pupil, and when her head comes up it
  finds him and follows him (`gaze`). Everything else is gone; that isn't.
- **Wrong in how she moves.** The head comes up slowly, cracking, and then keeps going past where
  a head stops. The jaw opens past where a jaw stops (`unhinge`). She is perfectly still until
  she isn't. (Her idle animation is off until she stirs: a corpse that fidgets isn't a corpse.)
- **She's changing.** Each time Kurt sees her she's further along (`stage`): at the table (0);
  on her feet in the first copy of the flat, antlers of coral out of her skull, a ridge down her
  spine, her forearms and hands drawn out long (1); in the last copy taller again, coral blooming
  out of her back like a coat split open, the jaw hanging off its hinge for good, the head
  carried at a broken angle (2). Socko notices every time.

## The beat sheet

| Beat | What happens | Why |
|---|---|---|
| Approach | In the flat, before he's seen her: murmuring from the living room, under her breath (no subtitles). The flies. | Something is in there and it's talking. Dread before anything is seen. |
| Discovery | First sight: a dead old woman at her table, head bowed, under the lamp. The murmuring has stopped. Kurt: "Oh... oh no." | False release: grief, not fear. And the silence says she heard him. |
| Tells | While he's in the room and not looking at her, she changes: her head has come round toward him; then her hand has moved, and a nail ticks on the plate. Never on camera, twice at most. | Doubt. Did she...? The player starts checking on her. |
| Close | He leans over the table. "What the hell is this?" | Closest approach while she's still "dead". |
| Stirs | A finger taps. The rattling breath starts. Her voice comes from under the hair: the boxes. | The first rule breaks, small. Her face is still hidden while she talks. |
| Turn | "Marta?" Her head comes up, cracking; the hair falls aside; the grin. The head keeps tilting past where a head stops. Her eye finds him. "Look at the boxes, my little bird." | The creature reveal, spent once, late, slowly. |
| Dead air | Everything stops: her breath, the flies, the flat's own hum. Kurt holds his breath. Her jaw drops, and drops. About three seconds. | Silence before the hit, held too long. |
| The jump | The bulb pops. Dark. In the dark the chair goes over and her joints crack. The light comes back and she's out of the chair, over the table, at his face, arms out either side of his head, jaw off its hinge, screaming. | The broken rule: she was across the table and slow. One change from dark to light, not a strobe. |
| Aftermath | She takes him and throws him. Blackout, ringing, his heart. He wakes on the floor. Her chair is empty, the coral still in it. Socko: "She got up!" | The release, and the first sign she's still changing. |

## Photosensitivity

The jump is a single dark-to-light change (the bulb goes, the light comes back once), not a
flicker, so it stays inside the three-flashes-a-second rule `tools/flash_test.gd` enforces.
