# Skill trees, powers and dialogue choices

Code: `scripts/core/skills.gd` (the nodes, the one pool, effects, the lean), `scripts/ui/skills_menu.gd` (the
screen), `scripts/player/powers.gd` (telekinesis, the shove, telepathy), `scripts/world/cracked_wall.gd`
(Breach), `MartaHunter.die/revive` (Coup de Grace), `scripts/dialogue/dialogue.gd` (choices).
Test: `tools/skills_test.gd`.

**Writing.** Everything that is writing (what Kurt remembers on each Memory node, and the lines
of any choice conversation) is for the authors. The Memory nodes' texts and the example choice
conversation are placeholders.

## Two trees, one pool

Open with **Skills** (Tab / K / gamepad Back / the touch SK button). The game pauses. Memory on
the left, Infection on the right; a lit node is his, an outlined one can be bought now, a dim one
isn't reachable yet. The panel says what the selected node does and buys it.

**One pool.** Both trees are bought with the same points (`Game.points`). Every point spent on
Kurt getting himself back is one the thing in him doesn't get, and the other way about. The top
of the screen says how many he has and which way he's been going: "more himself", "both", or
"more it". `Skills.lean()` is that number, from −1 (all Memory) to +1 (all Infection). The
dialogue can test it (`"if": "lean > 0.5"`).

**The infection shows.** His arm greys, and goes bluer under the skin, the more he's spent on
Infection (and the more one-sided he's been). It changes only when he buys.

**Earning points.** They all go into the same pool. The HUD says where each came from:

| Kind | Where it comes from |
|---|---|
| **Something comes back** | Sonya's story (the note under her bed); the photo album; the drawing; the wedding photograph in 47. In the lobby: Vera's letters, Lyuda's handbag (the ticket never punched), the wedding photograph. In 27: his page about the nails. Taking STIGMATA down. |
| **It grows** | Waking with it in him; each tear between copies of the flat; the first time he stuns her; driving the last nail. |
| **It feeds** | Every one of the building's people Kurt kills (him dealing the last hurt; a hazard doesn't count). |

Old saves have their two pools added together.

### Memory

Kurt getting himself back. Each "Memory" node raises `Game.memories`, which the dialogue's
memory branches test (`"if": "memories >= 1"`).

| Node | Cost | Needs | Does |
|---|---|---|---|
| Memory I | 1 | | memories +1 (memory text: authors') |
| Talkative | 1 | Memory I | idle conversations twice as often |
| Resourceful | 1 | Memory I | weapons wear a third slower; boxes of rounds have a 50% chance of an extra |
| Observant | 1 | Memory I | when she's within 12 m and out of sight, a mark at the screen edge shows where her sounds come from; held things show their weapon class, damage and wear |
| Read People | 1 | Talkative | each choice in a conversation shows how it'll land: (warm), (plain), (prying), (hostile) or (a lie). When a choice comes up, the HUD says how the other one feels about him now ("The Super doesn't trust you.") |
| Memory II | 1 | Memory I | memories +1 |
| Steady | 1 | Observant | fear builds a third slower (so her aim-shake and the drained screen come later) |
| Old Training | 2 | Memory II | heavy blows wind up in half the time; crouched, he moves a third faster |
| First Aid | 1 | Memory II | out of danger (unhurt for 5 s), crouched and still, he heals four times as fast |
| Memory III | 2 | Memory II | memories +1 |
| Locksmith | 2 | Old Training | locked doors he could crowbar (in the lobby: maintenance, the ladder's closet, flats 1, 2 and 16), he can pick instead: four seconds working at it, then it gives. Quiet (a little noise, nothing like the crowbar). Picking the super's flat makes him a little more suspicious. |

### Infection

What the thing in him can do.

| Node | Cost | Needs | Does |
|---|---|---|---|
| Sinew | 1 | | strength ×1.25 (melee damage) |
| Lungs | 1 | | stamina ×1.5 (running and blows) |
| Telekinesis | 1 | | POWER at a loose thing ≤ 8 m, ≤ 6 kg: it flies to his hand (strain 0.25) |
| Sinew II | 2 | Sinew | strength ×1.5; blows cost a quarter less stamina |
| Soft Tread | 1 | Lungs | footsteps 40% quieter |
| Telekinetic Shove | 2 | Telekinesis | POWER at her, or at any of the building's people, ≤ 8 m: its stance broken (Marta: half her poise; the inhabitants: reeling 1.6 s), thrown back (strain 0.5) |
| Breach | 2 | Sinew | a heavy blow, fist or blunt, goes through a cracked wall |
| Regrowth | 1 | Lungs | heals 2.5× as fast, starting after 4 s unhurt instead of 9 |
| Telepathy | 2 | Telekinesis | [Telepathy] choices; POWER with nothing in reach: for 3 s he sees everything alive within 25 m through the walls (her, and the building's people) (strain 0.5) |
| Feed | 2 | Sinew II | a kill heals him (+0.35) and gives back half his strain |
| Shade | 1 | Soft Tread | out of the light (and with his torch off), the inhabitants see him half as far |
| Throw Voice | 2 | Telepathy | POWER while crouched: a sound where he's looking (up to 20 m). Whatever hears it goes to look (strain 0.3) |
| Coup de Grace | 3 | Sinew II, Telekinetic Shove | a heavy blow with an edge (knife, razor, shard, axe) kills outright anything that's reeling, or that has its back to him and hasn't seen him: her, or any of the building's people |

**Strain.** The powers draw on it (0..1, refilling 0.08 a second, shown as a thin bar under the
objective while it's not empty). Too little left: a ringing in his ears and nothing happens.

**POWER** (T / D-pad down / touch PWR) does the first that applies:

1. He's crouched and has Throw Voice: a sound where he's looking.
2. A foe is in his sights and he has the Shove: the shove.
3. A loose thing is in his sights and he has Telekinesis: it's pulled to his hand.
4. Otherwise, with Telepathy: he listens.

**Breach walls.** In copies B and C of the flesh flat the bathroom doorway is walled up with
cracked plaster (a box of rounds behind it in B). Without Breach a blow just thuds.

**Coup de Grace and her coming back.** She goes down for good in that copy; when he tears into the
next one she's there again, further along (`MartaHunter.revive`, `evolve`). The building's people
stay dead (`ch2_dead_<id>`).

## Tests

- `tools/skills_test.gd` covers Flat 47 and the flesh flat:
  - the one pool
  - the lean
  - the nodes' numbers
  - telekinesis, telepathy and the shove
  - Breach
  - Coup de Grace
  - the choices
  - the screen
- `tools/skills2_test.gd` covers the lobby:
  - Read People
  - a point from the letters
  - the shove, Coup de Grace and Feed on an inhabitant (and its point)
  - telepathy showing them
  - Throw Voice drawing the listener
  - Shade, Regrowth, Locksmith and First Aid

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
