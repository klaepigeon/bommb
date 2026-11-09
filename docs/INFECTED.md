# The infected: a generator of people it took differently

Everyone takes the infection differently. The same thing that grew coral through Marta grows
shelves of fungus out of one person, bone out of another, swells a third; it takes limbs, or it adds
them. So there are no enemy *types*: there is a generator, and every seed is one person, always the
same person for the same seed.

## Files

| File | What it is |
|---|---|
| `hysteria/scripts/infected/infected_genome.gd` (`InfectedGenome`) | Who they were and what it made of them: `generate(seed)`. Limbs, head, skin, growth, clothes, habit, the one thing they still say, senses, speed. Chances in `CHANCE`. |
| `hysteria/scripts/infected/infected_body.gd` (`InfectedBody`) | The body: a real `Skeleton3D` built from the genome and **one skinned mesh** over it (skin, clothes and growth as surfaces on the same skeleton, every vertex weighted to the bones near it, blended across joints). Procedural animation for every gait, habit, grab, flinch and death. `sever(limb)`. |
| `hysteria/scripts/infected/infected.gd` (`Infected`) | The person loose: a `CharacterBody3D` that hears (`Noises`), sees, chases, grabs and dies; hit shapes on the bones; shots take limbs off. |
| `hysteria/scripts/infected/infected_textures.gd` (`InfectedTextures`) | Four skins, four growths, four kinds of clothes in three cuts, a wound. Painted in code at PS1 resolution; `rot` and `coral` are Marta's own (RotTextures) so it reads as one infection. |
| `hysteria/scenes/infected_lab.tscn` | The bench: a lineup of eight to regenerate and look at, a close-up, every mode (idle, move, attack, hurt, dead, sever), and a hunt mode with a stand-in Kurt (WASD; Space makes a noise). `-- shots=<dir>` renders a review tour. |
| `hysteria/tools/infected_test.gd` | The checks (below). |

## The generator

- **Limbs.** Everyone starts with two arms and two legs. Each one independently may be **missing**
  (a puckered scar), a **stump** (a short limb ending in a cut), **short**, **long**, or **fused** (the
  growth has gone through the joint and set it stiff); a whole or long limb may have **an extra
  joint**. Legs are lost less often than arms (a body that lost them didn't get far). Then 0-3
  **extra limbs** grow (52 / 31 / 13 / 4 %): arms from the back, the ribs or a second shoulder, legs
  from the hips or the belly. Over 2,000 seeds: ~48 % have an extra limb, ~42 % have lost one.
- **How they move** follows from what they have: two legs **walk** (or **limp** if one is short,
  long or fused), three or more **skitter**, one leg **lurches** on an arm as a crutch (or **hops**
  with no arm), no legs **crawl** on their arms, nothing left **drags**. Over 2,000 seeds: walk 38 %,
  limp 34 %, skitter 15 %, lurch 12 %, the rest rare. Shooting limbs off changes it on the spot.
- **The head:** whole, **split** (cheeks torn back into a grin, as Marta's), **sunk** (one side
  caved in), or **overgrown** (the growth has the face; no eyes). The jaw hangs as far as it hangs;
  one eye or two.
- **The body:** height 1.52-1.94 m, build thin to swollen (the belly, the clothes straining), a
  hunch, a lean.
- **Skin:** rot (Marta's), pallid (waxy, mould-white, blue veins), char (dark, cracked to red),
  bloat (stretched yellow-purple, split). **Growth:** coral, fungus (bracket shelves), bone (spurs),
  tumour (glossy clusters), mostly over the back and shoulders where Marta's came out, some on the
  head and limbs; fused limbs are crusted with it.
- **Who they were:** clothes (coat, nightclothes, overalls, dress, or nothing), in one of three cuts;
  a **habit** they kept (rocking, knocking on nothing, counting with nods, searching, folding their
  hands, standing still); **one thing they still say** ("Is it Tuesday?", "Mind the step.", "Not
  the good plates."): mundane, never the boxes, never an explanation.
- **Senses and pace** per person (hearing, sight, persistence, speed), times the threat manager's
  levers, as Marta's are.

## Behaviour

IDLE (their habit) → WANDER near home → LISTEN (a noise carries to them: they go to it) → SEARCH
(there, looking round, for as long as they keep at things) → CHASE (they see him: as fast as their
body goes, to arm's length) → GRAB (as Marta does: held to their face, their line, black, he comes
to a few metres back; `on_caught` can do something else), then they lose interest for eight seconds
and drift off. **DEAD:** they collapse and stay down.

**Shots** land on a part (the nearest bone segment to the hit): the head (4 hits, or one with
Headshot), the trunk (9), a limb (3, one more if fused). A limb shot through comes off: it falls as
a piece, the stump shows a cut, and they go on with what's left.

## Tested (`tools/infected_test.gd`)

The same seed gives the same person; all seven gaits, every skin, growth, clothing, habit and head
occur; the distributions above; every gait follows from the limbs. 42 built bodies: a real skeleton
(trunk, head, jaw and a chain per limb), every vertex of skin, clothes and growth weighted to real
bones with weights summing to 1, body-sized, crawlers' heads near the floor and walkers' up, every
gait animating and staying finite through moving, idle, grabbing and dying; ~12 ms to build one.
Severing: a leg off → one leg, both → crawl, all → drag, still animating. The hunter: doesn't see
him behind it, hears a noise and goes, sees him and comes, takes hold of him, loses an arm to three
shots, dies to a headshot with Headshot.

## Not done

- **Not placed in the story.** Where they appear (Flat 47's stairwell? the labyrinth? Flat 48?) and
  how many is the owner's call; `Infected.new()`, `setup(InfectedGenome.generate(seed), player)`,
  `add_child` is all it takes. They hunt by straight steering with wall feelers, not a navmesh; in the
  labyrinth they should route over its cell graph as Marta does.
- **No sounds** of their own (steps, breathing, the drag). The fragment uses the system voice.
- **Severed limbs** fall as capsules in their skin, not as the exact limb mesh.
- Bodies are procedural (no hand-made models): the variety is the point, the detail is PS1-level.
