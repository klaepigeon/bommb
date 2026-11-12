# Skill trees, powers and dialogue choices

Code: `scripts/core/skills.gd` (the nodes, points, effects), `scripts/ui/skills_menu.gd` (the
screen), `scripts/player/powers.gd` (telekinesis, the shove, telepathy), `scripts/world/cracked_wall.gd`
(Breach), `MartaHunter.die/revive` (Coup de Grace), `scripts/dialogue/dialogue.gd` (choices).
Test: `tools/skills_test.gd`.

**Writing.** Everything that is writing (what Kurt remembers on each Memory node, and the lines
of any choice conversation) is for the authors. The Memory nodes' texts and the example choice
conversation are placeholders.

## Two trees

Open with **Skills** (Tab / K / gamepad Back / the touch SK button). The game pauses. Memory on
the left, Infection on the right; a lit node is his, an outlined one can be bought now, a dim one
isn't reachable yet. The panel says what the selected node does and buys it.

### Memory (memory points)

Kurt getting himself back. Each "Memory" node raises `Game.memories`, which the dialogue's
memory branches test (`"if": "memories >= 1"`): the sandwich conversation and entering the maze
already use it.

| Node | Cost | Needs | Does |
|---|---|---|---|
| Memory I | 1 | | memories +1 (memory text: authors') |
| Talkative | 1 | Memory I | idle conversations twice as often |
| Resourceful | 1 | Memory I | weapons wear a third slower; boxes of rounds have a 50% chance of an extra |
| Observant | 1 | Memory I | when she's within 12 m and out of sight, a mark at the screen edge shows where her sounds come from; held things show their weapon class, damage and wear |
| Memory II | 1 | Memory I | memories +1 |
| Old Training | 2 | Memory II | heavy blows wind up in half the time; crouched, he moves a third faster |
| Memory III | 2 | Memory II | memories +1 |

**Earning memory points:** things of theirs that bring something back to him, once each: Sonya's
story (the note under her bed), the photo album, the drawing, the wedding photograph (picked up).

### Infection (skill points)

What the thing in him can do.

| Node | Cost | Needs | Does |
|---|---|---|---|
| Sinew | 1 | | strength ×1.25 (melee damage) |
| Lungs | 1 | | stamina ×1.5 (running and blows) |
| Telekinesis | 1 | | POWER at a loose thing ≤ 8 m, ≤ 6 kg: it flies to his hand (strain 0.25) |
| Sinew II | 2 | Sinew | strength ×1.5; blows cost a quarter less stamina |
| Soft Tread | 1 | Lungs | footsteps 40% quieter |
| Telekinetic Shove | 2 | Telekinesis | POWER at her ≤ 8 m: half her poise, thrown back (strain 0.5) |
| Breach | 2 | Sinew | a heavy blow, fist or blunt, goes through a cracked wall |
| Telepathy | 2 | Telekinesis | [Telepathy] choices; POWER with nothing in reach: she shows through walls for 3 s (strain 0.5) |
| Coup de Grace | 3 | Sinew II, Telekinetic Shove | a heavy blow with an edge (knife, razor, shard, axe) kills her if she's stunned, or if he's behind her and she hasn't seen him |

**Earning skill points:** waking with it in him; each tear between copies of the flat; the first
time he stuns her.

**Strain.** The powers draw on it (0..1, refilling 0.08 a second, shown as a thin bar under the
objective while it's not empty). Too little left: a ringing in his ears and nothing happens.

**POWER** (T / D-pad down / touch PWR) does the first that applies: she's in his sights and he has
the Shove → shove; a loose thing is → pull it (Telekinesis); otherwise → listen (Telepathy).

**Breach walls.** In copies B and C of the flesh flat the bathroom doorway is walled up with
cracked plaster (a box of rounds behind it in B). Without Breach a blow just thuds.

**Coup de Grace and her coming back.** She goes down for good in that copy; when he tears into the
next one she's there again, further along (`MartaHunter.revive`, `evolve`).

## Dialogue choices

A conversation step can stop for the player to choose what Kurt says:

```json
{"choices": [
  {"text": "…", "steps": [ …what follows… ]},
  {"tag": "memory", "if": "memories >= 1", "locked": true, "text": "…", "steps": [ … ]},
  {"tag": "telepathy", "if": "skills.has('s_telepathy')", "locked": true, "text": "…", "steps": [ … ]}
]}
```

- `tag` marks and colours an option: **[Memory]** (gold) or **[Telepathy]** (blue).
- `if` is a condition over `memories`, `flags` and `skills`; an option whose condition fails is
  hidden, or shown greyed if `locked` is true (so the player sees what they're missing).
- The chosen option's `steps` play, then the conversation carries on after the choice.
- Kurt stands still while choosing. Pick with the mouse, a tap, the gamepad (up/down, accept), or
  the number keys.

`data/dialogue/examples.json` has one example (`_example_choices`), all placeholder text; nothing in
the game plays it.
