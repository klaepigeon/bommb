# Level 2: the maze

Code: `scripts/world/maze.gd` (the plan), `scripts/levels/maze47.gd` (building it, the story),
`ExportedFlat` in kit mode (the flat's pieces). Tools: `tools/maze_view.gd` (prints the plan,
renders views), `tools/walkthrough.gd` (walks the way through), `tools/hunt_test.gd`.

## What it is

Flat 47 come apart and grown back wrong: its rooms rearranged into a labyrinth of 3 m cells on
an 8 × 8 grid. Kurt comes out of the hole in the wall at one corner; 48's padded door stands open,
lit warm, in the far wall. Marta hunts it.

It's built from the flat itself (`ExportedFlat` in kit mode: the model loaded but not built, its
materials converted, its pieces handed out):

- **Rooms.** Each cell belongs to a zone wearing one of the flat's rooms: the hall's paper, the
  living room's, the kitchen's and bathroom's tiles, Sonya's room, the bedroom, the box room. Every
  wall face wears its own cell's room (so a wall between the kitchen and the bath is tiled on both
  sides, differently), with the export's own texture scale.
- **Doorways.** Where one room gives on to another: a 1 m doorway with a painted casing and an open
  panel door. Cells of the same room open into each other fully.
- **Furniture.** The flat's own pieces as landmarks against the walls, by room: the shelf unit, the
  dining table and chairs, the standard lamp; the kitchen cupboards and a stool; the bath; Sonya's
  bed and toy chest; the wardrobe; the box room's shelves.
- **Meat.** The blue of the hole, deepening the further from the hole a cell is (three strengths):
  near the start the wallpaper reads through; by 48's door it's nearly all meat.
- **Light.** Steady bulbs on cords, every third cell; the safe rooms warm.

Geometry is merged per material in 2 × 2-cell chunks, so no mesh is lit by more than a handful of
lights (the phone renderer's limit is 8 a mesh).

## The plan

`Maze.generate_good(seed)` tries seeds from 4747 and keeps the first good one: a perfect maze
(recursive backtracker); the way out at the far (east) cell that's longest to walk to; three safe
rooms; loops knocked through off the main route (never shortcutting it, never into a safe room);
two cracked walls; a route of 24-40 cells. The same seed always gives the same maze.

## Safe rooms

Three pockets of the flat as it was: no meat, the bedroom's paper and floor, a warm lamp, a chair,
a box of rounds. Each is a dead end just off the way through, at about a quarter, a half and
five-sixths of the way, with one door.

- Marta won't go in (they're solid on her grid) and can't see in or hear in (`MartaHunter.refuge`).
  Chasing him when he gets inside, she gives up and goes searching elsewhere.
- Each is a checkpoint: caught, he starts again in the last one reached.
- The first time he reaches each, the infection grows: a skill point.
- At the second, out of his sight, she changes (stage 2).

## Guidance

Lines written for guiding the player (in the authors' Socko and Kurt), in
`data/dialogue/flesh47.json`:

- `safe_first`: the first safe room; that she won't come in.
- `safe_escape`: the first time he gets into one with her on his heels.
- `maze_hint_1`, `maze_hint_2`: lost (a minute without finding a new cell): Socko smells the way and
  points (towards the next safe room he hasn't reached, else the way out). Up to three times.

## Cracked walls

Two walls on the route, each a shortcut of 5-12 cells, have a cracked doorway in them: with Breach
(the Infection tree) a heavy blow goes through.
