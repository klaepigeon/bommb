# Flat 48

After the maze, through 48's door. Rebuilt from scratch in this game: `scripts/levels/flat48.gd`, `scripts/world/draft_block.gd`, `scripts/world/draft_figure.gd` and `scripts/weapons/shotgun.gd`. Tested by `tools/flat48_test.gd`.

**Every line and tag is a placeholder.** The dialogue lives in `data/dialogue/flat48.json`, one entry per beat, named for the moment it plays. The only real words are the ones the puzzle runs on:

- the furniture words on the note wall
- GUN SAFE
- the names MARTA, KURT and SONYA
- the decoys PIANO, DOG, WINDOW, HOME and LATER
- the figures' tags MAMA, PAPA and CHILD

## The place

- **The flat:** it's Flat 47's own export, built again. Every surface inside is pale draft plaster, lit by one steady, cold, shadowless light per room. The windows look out on the white.
- **The landing:** stays 47's real landing.
- **The door:** reads 48.

## The blocks

- **What they are:** each of 47's 35 pieces of furniture is a white block standing exactly where it stands in 47. The real furniture is still there underneath, hidden: the export's meshes, plus the loose things on it. That's 455 pieces in all.
- **Tags:** each block has a tag, which shows its text when read. The text is a placeholder for now.
- **Blocks that stay white:** blocks with no word, such as the coats, the shoes and some of the cupboards, stay white for good.

## The note wall

The note wall is on the hall's north wall and holds 25 notes.

1. Take a note. It goes into Kurt's hand. Taking another puts the first one back up.
2. Aim it at a block. The prompt reads *Stick "SOFA" on it*.
3. The right word makes the block real: the white goes, 47's own furniture is there, and the note stays stuck to it.
4. Any other word falls off. It lands on the floor, and he can pick it up again.

## Papa's gun safe

- **Where:** a tall narrow block in the box room that isn't in 47.
- **Making it real:** the GUN SAFE note turns it into a steel cabinet.
- **Inside:** opening it reveals the sawn-off on two pegs and a box of ten shells.

## The sawn-off (`Shotgun`)

- **Firing:** two barrels, one per pull. Each barrel fires nine pellets in a cone about 5° wide, out to 25 m.
- **Damage:** every pellet that hits counts. Each thing hit is `shot()` once per blast.
- **Reload:** break-open, both barrels at once, taking shells from his pocket.
- **Noise and kick:** very loud. It kicks the view up and punches the FOV.
- **Switching guns:** "holster" now cycles pistol → shotgun → fists. The HUD shows the barrels as ●○ alongside the shells left.

## The three figures (`DraftFigure`)

- **Who they are:** MAMA at the stove, PAPA at the bedroom window, CHILD beside Sonya's bed.
- **How they look:** white and wrong in proportion: a long neck, a small head, arms that hang to the knee.
- **How they move:** only while unseen. They turn to face him at once, so they're never caught turning, and creep nearer at 0.35 m/s if the way is clear, never closer than 1.1 m.
- **When he looks back:** if one is nearer than it was, there's a creak and his nerve jumps.
- **Putting them down:** shot, or beaten down with 30 damage of melee, they fall and stay down.
- **Naming them:**
  - MARTA on MAMA makes a mannequin dressed as her: the blue cardigan, a dark skirt, her hair up, a red painted mouth.
  - KURT on PAPA makes a mannequin dressed as Kurt: a dark jacket, a domino mask, a bow across the back and a quiver.
  - SONYA won't stay on the child.
  - Dressed mannequins still turn when unseen, and can still be shot.

## LOBBY, and back to 47

1. **The unveiling.** Once every name has been tried, a note that wasn't there before is on the wall, low and on its own: **LOBBY**. The beat is `f48_end`. The door across the landing opens; from 48's side it's **47**.
2. **Across the landing.** Holding LOBBY, "use" on 47's door. 47 loads as he left it: her gone from the chair, the white where outside was, the giant sticky note saying "outside" past the balcony. He starts on the landing with LOBBY still in his hand, and the beat `f47_back` plays.
3. **The balcony.** Looking out from the balcony with LOBBY in hand, the prompt reads *Stick "LOBBY" on outside*. The note goes out over the rail, grows, and lands over the word, so the big note reads "LOBBY". Then the white comes up and goes. The beat is `f47_lobby`.
4. **The lobby.** Where outside was is the block's ground-floor lobby (`scripts/world/lobby.gd`), level with the balcony:
   - metlakh tiles
   - green paint to shoulder height with whitewash above, and a dark line along the top of the green
   - three rows of tin mailboxes
   - a radiator under a small high window
   - the double doors out, with reeded glass, shut
   - a stair up the east wall to a landing and a dark way on
   - one steady bare bulb
5. **The rail opens.** The balcony's rail and its invisible wall are gone, so he steps off into the lobby.
6. **Into it.** A few metres in, the beat `f47_lobby_in` plays, then the "Lobby" card and the demo's end screen.

All the new beats are placeholders: `f48_end` is in `data/dialogue/flat48.json`, and `f47_back`, `f47_lobby` and `f47_lobby_in` are in `flat47.json`.

**Saving.** It checkpoints when he leaves 48 with LOBBY, when he arrives back in 47, and on entering the lobby. A continue in 48 after LOBBY has appeared puts it straight back on the wall.

## Open (decisions for you)

- What the lobby leads to. The demo ends on entering it for now.
- Whether 48's figures should be "helped" beyond naming. The old Hysteria notes left that open.
