# The Lab (development only)

A place to try things that aren't the game yet. Reached from the title's **Lab (dev)** button,
which only exists when `DevOverlay.wanted()` (a debug build run from the editor, or with `--dev`).
Release builds never show it. The Lab never saves a checkpoint, so it can't become a save's
"continue". F3 (the developer overlay) works in every room.

Code: `scripts/levels/lab/` (`lab_kit.gd` has the shared pieces: rooms, signs, doors to levels,
lamps, navigation baking, and the building's people as templates). Scenes: `scenes/levels/lab/`.
Test: `tools/lab_test.gd` (each room loads; sandbox spawns and aggro; Echo's click, fade and
hearing; the mirror's camera, layers and the figure's approach and reset).

## The hub
A bare room with six doors to the experiments (three on each long wall, each with a line
saying what it is), and one back to the title. Doors can be gated (`LabKit.portal(..., gate)`):
a shut one says Locked and rattles.

## AI Sandbox
An arena (pillars, a wall with a wide doorway, low cover, loose boxes, a wardrobe to hide in,
five lamps) to spawn the building's people and watch them think. Being knocked down just puts
him back at the door.

| key | does |
|---|---|
| 1-8 | spawn super, hunter, listener, laundress, cook, rearranger, crawler, caretaker where he's looking |
| J | they hate him / they leave him be |
| N | a noise where he's looking |
| U | kill them all |
| V | clear them all |
| L | lights on / off (`lit()` follows, so the crawler and Shade react) |
| I | god mode |
| Y | time: 1x, 0.5x, 0.25x, 2x |
| O | freeze / unfreeze them |

(H, K, C, G, T and P are the game's own keys, so the sandbox stays off them.)

## Echo
A 6x6 maze in total dark: no ambient light, no torch, his own fill light off. He sees by sound.
POWER (T) clicks his tongue: a wash of light spreads from him and fades. Every sound anything
makes washes light from where it was; the listener's footsteps wash dim red. The listener is
blind and hunts by sound, so every click that shows him the walls is one it hears. The faint
green EXIT goes back to the Lab. Caught: the maze starts again.

Photosensitivity: each wash rises over 0.25 s and fades over 1.5 s, the brightest is dim, the
click has a 1.2 s cooldown, and one place washes at most every 0.8 s. Nothing flashes.

## Mirror
A small bathroom with a mirror over the sink. The mirror is a second camera, Kurt's reflected
across the glass, drawn into a texture the glass samples at its screen position (flipped left
for right). Render layers keep things in their place:

| layer | what | seen by |
|---|---|---|
| 1 | the room | both cameras |
| 2 | the mirror and its wall | him only (the reflection looks through it) |
| 3 | the one in the mirror | the reflection only |
| 4 | Kurt and what's on him | him only: he has no reflection |

Each time he looks away from the glass, the figure in the mirror comes nearer to where he
stands. When it's right behind him and he looks, a breath, and fear rises. The next time he
looks away, it's back by the far wall. No flash, no sting. The figure uses the laundress model
for now.

## Still
A hall of pillars, five figures, a switch at the far end. The figures move only while nothing
sees them, and "seen" is honest: in his view (`is_position_in_frustum` at feet, waist and
head), not behind a pillar (a ray), and lit (near a lamp, or in the torch's cone). Seen, a
figure is stone, not even a joint. Unseen, it snaps to a new pose and comes along a navmesh
path at 2.6 m/s. Every 11-17 s the lamps sag (down over 1.5 s, two seconds low, back over 1.5 s:
no flicker), so the torch matters, and it has a battery. A figure that reaches him knocks him
down and they all go back. The switch drops them.

## Through
A small room with a doorway in the north wall and one in the south, and both open onto this
room. Each doorway is a camera, his own moved one room along, drawn into the doorway with
SCREEN_UV (a window, not a mirror, so no flip). Walking through one brings him in by the other,
seamlessly. Layers: each doorway's wall is its own layer, so the camera looking through the
north doorway (standing one room south, behind the south wall) can look past that wall. The
doorway cameras can't see each other's doorways, so the far doorway in the copy is dark.

Through the doorway, someone stands where he stands, doing what he did 1.5 s ago. He never
meets them: they're always one room along. (Kurt himself is on a layer the doorway cameras
don't draw.)

## Breath
A room of meat (`shaders/breath.gdshader`: fine grids that swell in along their normals, most
mid-wall, none at the edges) that closes in while he stands still and eases back while he
moves. It breathes, and a heartbeat plays, both quickening as it closes (a breath every 4 s at
rest, every 1.6 s at its closest). The colliders don't move: the level holds him inside the
bulge. Three valves open the door, and turning one means standing still for 2.5 s. If it closes
all the way it lets him go: back at the door, the valves undone. Only the shape moves; the light
on it doesn't.

## Ideas for more rooms
- A corridor that's longer walking one way than the other (27's nave already loops one way).
- A room that's only there in the dark: lights on, it's an empty box; lights off, the torch
  shows furniture, a door, someone sitting.
- Sound that comes from where he was standing a few seconds ago.
- A stairwell where the floor numbers don't add up.
