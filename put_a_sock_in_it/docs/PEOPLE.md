# The inhabitants' bodies

Chapter 2's inhabitants are low-poly, PS1-style biomechanical models, about 5,000–11,500 triangles each, with coral growing through all of them as the common thread. They are built the way late-90s characters were box-modelled. Each one has its own hand-painted 256×256 texture page. They use the same shader as the rest of the building (`shaders/ps1.gdshader`): no texture filtering, vertices snapped to a coarse screen grid, and the PS1 wobble setting applies to them too.

Each inhabitant is two files: `assets/people/<name>.glb` (the mesh, skeleton and skin) and `assets/people/<name>.png` (the page). The files are:

- `super`
- `hunter`
- `listener`
- `laundress`
- `caretaker`
- `cook`
- `rearranger`
- `crawler`, shared by all three crawlers and tinted differently for each

## Remaking them

```
python3 tools/people/cast.py              # everyone (a few seconds)
python3 tools/people/cast.py super cook   # some
godot --headless --path . --import        # pick up the new files
```

The only dependency is numpy.

To look at one model in a test room, from five angles and in four poses:

```
xvfb-run godot --rendering-driver opengl3 --path . -s tools/people_view.gd -- model=super out=<dir> light=torch
```

`tools/lobby_people_view.gd` shows the cast in the lobby, from Kurt's eye.

## How a body is made (`tools/people/lowpoly.py`)

- **Lofts.** A body is a handful of lofts: the trunk, the head, each arm, each leg, the feet, the fingers, the ears, and a skirt and hair if the character has them. A loft is a run of rings (cross-sections) along a path. Each ring is an ellipse with bulges (a nose, a belly, a chin), and is weighted to the bones it moves with. The jaw takes the front of the lower face.
- **The mouth.** The mouth is the band between two rings: the upper lip's ring is on the head and the lower lip's ring is on the jaw. When the jaw opens, that band stretches, and the dark mouth and teeth painted on it open with it.
- **Painting.** Each loft gets a rectangle of the page. For every texel, the tool works out where it lands on the body (a 3D point, a normal, and the loft's own around/along coordinates) and asks the character's paint function what's there:
  - the face is painted in the head's coordinates. Faces are masks of bone, not human faces: eye pits, a seam, a slit of teeth. No noses, lips, wrinkles or grimaces. Monstrous features come from what has grown into the bodies, never from exaggerated human features
  - skin details: ribs, collarbones, spots, sores, veins, hair, grime
  - clothes: dresses, aprons, stains, blood
- **Baked light.** Light from above and in front is baked into the page, then the colours are cut to 15 bits with a 4×4 ordered dither.

`tools/people/cast.py` holds the characters. `figure()` builds the skeleton and lofts from a dict of proportions (height, girth, chest, waist, belly, stoop, neck, head, jaw width, nose, mouth, fingers, extra joints, skirt, hair and so on). Each character then has its own paint function.

## The biomechanical parts (`tools/people/biomech.py`)

| Part | What it is | Who has it |
|---|---|---|
| Sinew cables | Cables down the limbs, twisting, standing off the elbows and knees like bowstrings | Most of the cast |
| Face hoses | From the cheeks into the chest | Everyone |
| Temple hoses | From ports in the temples into the neck | Everyone |
| Back hoses | Plugged from ports in the back into the shoulders | Everyone |
| Spine ridge | Running up into the skull | Most of the cast |
| Crest | A low ribbed ridge over the crown | Everyone |
| Rib hoops | The ribs standing outside the body | The super, the crawlers, the hunter, the listener, the cook |
| Plates | Segmented plates down the back and over the belly | Back plates on everyone without a skirt; belly plates on the super, the hunter, the listener, the cook, the crawlers |
| Long skulls | The skull drawn out backward | Most of the cast |
| Clothes | Skirts as hanging cloth, with folds that deepen toward a torn, filthy hem (bloodied on the caretaker and STIGMATA). The dress is painted up over the body and down the arms to the elbow. The caretaker's hood is a segmented shell. | The laundress, the caretaker, the rearranger; STIGMATA's cassock (torn open to the waist) |
| Hanging hoses | Hoses hanging from the skull instead of hair | The laundress |
| Coral | Staghorn branches with bulbous orange tips, knobbed crusts, fan coral where the listener's ears were, brain-coral grooves on skulls | Everyone: coral is the thread that ties every design together |

## Faces

Every face is an inhuman mask, never an exaggerated human face. Each one is its own horror, built in geometry and paint (`biomech.py`: `on_face` places things on the head's surface):

| Who | Face |
|---|---|
| The super | The mask is split from crown to chin: two raised lips of gristle either side of a wet red seam, small teeth along its edges, and bone pincers hooking in from either side of the mouth. |
| The hunter | A round lamprey maw: a raised ring of gristle with fangs all round it pointing in, painted rings of teeth going down, and eye pits scattered above. |
| The listener | No face: the front of its head is covered in pores rimmed in red, with coral nubs breaking out among them. |
| The laundress | A cage of bone bars standing off her face, with eye pits behind. |
| The caretaker | Her eyes are stapled shut with heavy bars, and coral breaks out of the sockets. |
| The cook | The jaw split into two hooked pincers, toothed on the inside. |
| The rearranger | Tube coral pours out of its mouth. |
| The crawlers | A vertical mouth from chin to crown, with fangs along both edges. |

## The rig

The bones are FleshBody's joints:

- hips, spine, chest, neck, head, jaw
- sh_l/r, el_l/r, ex_l/r (extra joints), hip_l/r, kn_l/r
- belly, for the cook and the rearranger

Every bone's rest pose has no rotation, so the euler offsets in `body.pose` mean what they always meant. Inhabitant animation is unchanged.

`Inhabitant` gives each body the model named after the inhabitant's id (`crawler_*` uses `crawler`). If there is no file, FleshBody builds the old procedural body instead.

On top of the poses, FleshBody adds:

- **Jaw.** The jaw opens with the voice: each `Dialogue.syllable` from that speaker opens it a little.
- **Belly.** Bellies swing on a spring and breathe.
- **Damage.** The skin darkens steadily as hp drops, with no flashing.
- **Keys.** The super's keys hang on a cord on his chest.
- **`at(joint)`.** `at(joint)` and anything hung on a joint work through `BoneAttachment3D`s.

## Making one by hand

The files are ordinary glTF and PNG. To replace a body with a hand-made one:

1. Model it in Blender.
2. Keep the bone names and rest positions, with no rotation on any bone's rest.
3. UV-map it to a 256×256 page.
4. Export it over `<name>.glb` and save the texture as `<name>.png`.

The game uses yours as it is.
