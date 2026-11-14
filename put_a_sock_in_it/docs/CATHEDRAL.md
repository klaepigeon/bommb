# Flat 27: the cathedral

The end of Chapter 2. When 27's door lets go, Kurt goes through it (`scripts/levels/lobby.gd` `_enter_27`) and into `scripts/levels/cathedral.gd`.

## The place

27 opens onto a flat's hallway: wallpaper, a coat on a hook, shoes. At the end of the hallway is a cathedral far bigger than the building it's in.

| Part | What's there |
|---|---|
| **The narthex** | The west wall reaches up to the vault, with the flat's doorway in the bottom of it. Above the doorway are three lancet windows: MANUS (a hand), PEDES (feet) and LATUS (a side). A bell rope hangs under each. Over the door it says *WHOSOEVER TURNETH HIS BACK UPON THE ALTAR SHALL COME UNTO IT*. There's a font (with something red in it) and a lectern. |
| **The nave** | Ribbed columns like ducting, with coral up their feet, and pews both sides of a red runner. A ring of candles hangs in every bay, and candles sit in sconces on the columns. Stained glass is lit from nowhere. Nothing flickers. |
| **The vault** | The same pews hang upside down from it, about 12 m up, with people sitting in them: the building's own (the caretaker, the laundress, a crawler, the rearranger). Their heads turn after Kurt. The first time he walks under them, Socko says quietly: "Kurt. Don't look up." Every 16 to 32 seconds one of them lets go of a hymn book, which falls and stays where it lands; the newest 14 stay. |
| **The apse** | A dais of three steps, the cross and a rose window. STIGMATA is on the cross, his feet and his right hand nailed. His free left hand holds out the last nail, and the hammer lies at his feet. Behind the altar is a flat's padded front door marked 27. |

## The loop, and the two ways through

Walking up the nave facing the altar, past the middle (z −26), puts Kurt back two bays (12 m). Every two bays of the nave are identical, so it looks seamless: the altar just never gets closer. Kurt and Socko comment after the 1st, 3rd and 6th time. The third time, Socko hints: "Read the walls."

There are two ways to break the loop:

- **The bells.** Ring the ropes in the order he nailed himself. His page on the lectern gives it: "First the feet… Then the right hand… The side I leave open." So the order is PEDES, MANUS, LATUS. Each correct pull tolls a bell. A wrong one clanks dead and the sequence starts again.
- **Backwards.** Do what the inscription says: walk the nave facing the door. Facing away from the altar never sends you back, and past z −40 the loop lets go.

Either way the flag `c27_loop_broken` is set, plus `c27_broken_bells` or `c27_broken_backwards`, and the game checkpoints.

## Him

**STIGMATA** (`tools/people/cast.py` `stigmata`):
- tall and starved, in a cassock torn open to the waist
- the clerical collar still on
- a crown of thorns that is coral grown into the skull
- blood running down the mask from it, and from the eyes
- the wounds through both palms and both feet, the spear wound in his side
- a mask with a mouth, so he talks (his jaw moves with his voice)

Reaching the dais starts the conversation (`data/dialogue/cathedral.json` `c27_meet`):
- He can be asked what this place is ("It was my mother's. Two rooms and a balcony. I kept praying in it. And it kept getting bigger.").
- He can be asked why he did it (the congregation that stopped coming, and the one up there that came back).
- He says what he wants: the last nail. "You can't do the last hand yourself. Nobody can."
- Socko pushes: "One more bang and he's finished."

He won't look at Socko, and asks Kurt to keep it away from the altar.

| Kurt chooses | Then |
|---|---|
| **Take the nail** | STIGMATA lays his arm along the beam. Kurt takes the hammer and strikes three times: hit-stop and a burst each time, and the body goes rigid and sags. Then: "Thank you… Now go home, Kurt." The rose window brightens slowly. Flags `c27_nailed` and `ch2_obey_nail`. |
| **Get him down** | Kurt pulls the nail from the hand and the nail from the feet, with the hammer's claw. He slides off the cross onto the dais: "I was nearly finished." Socko: "You ALWAYS do this." Flags `c27_freed` and `ch2_defy_nail`. |
| **Leave** | At the door, STIGMATA: "Lock the door on your way out." Socko is furious. Flags `c27_left` and `ch2_defy_nail`. |

The door behind the altar opens once he has chosen. Through it, the chapter ends (`ch2_done`, then *End of Chapter Two*).

## Sound

These are all generated (`SoundLib`):

| Sound | What it is |
|---|---|
| `cath_bed` | An organ's lowest pipe held forever, a fifth that won't settle, a choir with no words far off, air |
| `bell_toll` | A great bell |
| `bell_dull` | A bell rung out of turn |
| `nail_strike` | The hammer |
| `stig_breath` | His breathing, through the teeth |
| `v_stigmata` | His voice blips: a whisper with a voice in it |

Blood drips under the cross.

## Tests and tools

- `tools/cathedral_test.gd` checks:
  - the loop
  - the bells wrong and right
  - walking backwards
  - meeting him
  - driving the nail (without the hammer, then with it)
  - pulling the nails (he comes down)
  - leaving
  - the door ending the chapter
- `tools/chapter2_test.gd` checks that 27's door leads into the cathedral.
- `tools/cathedral_view.gd` takes screenshots from Kurt's eye.

## The writing

The lines and his three pages are drafted in the script's voice, for Jules and ki to rewrite. They're all in `data/dialogue/cathedral.json`, and the pages are in `cathedral.gd` `_pages()`.
