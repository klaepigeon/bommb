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
A bare room with a door per experiment, and one back to the title.

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

## Ideas for more rooms
- A corridor that's longer walking one way than the other.
- A room where looking at something holds it in place (and everything you don't moves).
- A door that opens on the room you're already in, seen from behind.
