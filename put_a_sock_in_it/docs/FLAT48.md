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

## The end (a decision for you)

The old Hysteria notes leave open how 48 ends, and how each figure is "helped". For now 48 ends once every name has been tried: MAMA dressed or put down, PAPA dressed or put down, and SONYA tried on the child. Then the `f48_end` lines play, then the Flat 48 card, then the demo's end screen.

When you decide what 48 is for, the ending can change.
