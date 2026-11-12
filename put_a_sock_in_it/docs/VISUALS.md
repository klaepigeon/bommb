# Visuals

## Ambient occlusion (`scripts/world/ao_map.gd`)

The levels are built when the game runs: the flat from the exported kit, and the maze from its seed. So they can't be lightmapped, and GL Compatibility has no SSAO. Instead, each level gets a top-down occlusion map.

**Baking.** The physics world is probed on a 10 cm grid with two thin boxes: one at ankle height (0.07 to 0.37 m) and one just under the ceiling. Each probe records where something solid is: walls, furniture, the wardrobes. The result is box-blurred twice, about 0.4 m of falloff, then turned into brightness with an exponential response, so a 14 cm maze wall still shades its corner. The red channel is the floor and the green channel is the ceiling.

**Shading.** `world.gdshader` and `ps1.gdshader` look the map up at each fragment's world position:

- Up to 0.75 m above the floor, they darken by the red channel. That covers the floor next to walls and under furniture, wall bases, and the feet of things.
- In the top 0.5 m below the ceiling, they darken by the green channel. That covers the ceiling's corners and the tops of walls.
- Below `floor - 0.15` nothing changes, so the stairwell going down isn't affected.

**Where the maps live.** The levels are the same every time, so the maps are baked once by `tools/bake_ao.gd` to `assets/ao/<level>.png`, which the game loads. Rebake after changing walls or furniture. If a map is missing or the wrong size, it's baked on the spot instead. That takes 45 ms for the flat and 150 ms for the maze on a desktop.

**Which levels.** A level opts in through `ao_area()` (its XZ rectangle, floor height and ceiling height) and `ao_name()`. A level that returns `[]` turns AO off on all its materials, since materials are shared between levels.

## Fear in the picture

The post shader's `fear` input closes in the vignette and drains the colour, as far as Kurt's nerve goes. It's steady: no pulsing, no flashing.

## The torch

The torch adapts to how close it's pointed (see FEEL.md), so near walls don't blow out.
