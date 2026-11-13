# The inhabitants' bodies

Chapter 2's inhabitants are sculpted and rigged models. They used to be built from primitives at runtime. Each one is now a single continuous skinned mesh in `assets/people/<name>.glb`, made by `tools/sculpt/`.

| Model | Used by | Triangles |
|---|---|---|
| `super` | the super | ~90k |
| `hunter` | the hunter | ~53k |
| `cook` | the cook | ~42k |
| `laundress` | the laundress | ~39k |
| `listener` | the listener | ~35k |
| `rearranger` | the rearranger | ~35k |
| `caretaker` | the caretaker | ~31k |
| `crawler` | all three crawlers, tinted differently | ~23k |

Godot generates LODs for these on import, so the triangle counts above only apply up close.

## Remaking them

```
python3 tools/sculpt/people.py            # everyone (about 2.5 minutes)
python3 tools/sculpt/people.py super cook # some
godot --headless --path . --import        # pick up the new .glb files
```

The only dependency is numpy.

To look at a model on its own, in a test room, from five angles and in four poses:

```
xvfb-run godot --rendering-driver opengl3 --path . -s tools/people_view.gd -- model=super out=<dir> [light=torch]
```

`tools/lobby_people_view.gd` shows all of them in the lobby, from Kurt's eye.

## How a body is made

Each body is a signed distance field, built in stages:

1. **Shapes.** Capsules and ellipsoids, each pinned to a bone and given a colour and a wetness. They are grouped (a trunk, a limb, a jaw) and smooth-unioned, so fat flows into fat and a joint stays a joint.
2. **Displacements.** Creases (`fold`, which curves up at the sides), cellulite, and ribs.
3. **Carves.** The mouth, the eye sockets, the navel and the cleft are cut in with a smooth subtraction.
4. **Details.** Teeth, eyeballs, lids, nails and the tongue are added after the carves, so the carves don't cut into them.
5. **Mesh.** Surface nets on a voxel grid, then every vertex is projected back onto the true surface, with normals from the field.
6. **Paint.** Vertex colour starts as a blend of the colours of the shapes the vertex came from. Ambient occlusion from the field darkens creases. Each character's own paint function adds the rest:
   - the super: liver spots, sores, hair, veins, bruising, grime, the comb-over and raw folds
   - the dressed ones: stains on the cloth and painted aprons
   - the cook and the caretaker: blood
7. **Skinning.** Each vertex is weighted to the bones of the shapes nearest it, smoothed across the mesh, with four influences per vertex.

The rest position is stored in UV and UV2.x, and wetness in UV2.y. `shaders/flesh.gdshader` uses the rest position for fine skin detail that stays put when the body moves, and wetness for the sheen. Nothing in the shader animates over time, so there is no shimmer.

## The rig

The bones are FleshBody's joints:

- hips, spine, chest, neck, head, jaw
- sh_l/r, el_l/r, ex_l/r (extra joints), hip_l/r, kn_l/r
- belly (only on the super and the cook)

Every bone's rest pose has no rotation, so the euler offsets in `body.pose` mean exactly what they meant on the old bodies. Inhabitant animation didn't need to change.

`FleshBody` loads `assets/people/<model>.glb` when the profile's body has a `model`. `Inhabitant` sets it from the inhabitant's id (`crawler_*` → `crawler`). If there is no file, the old procedural body is built instead.

On top of the poses, FleshBody adds:

- **Jaw.** The jaw opens with the voice: each `Dialogue.syllable` from that speaker opens it a little. On this rig the jaw's sign is flipped, so pose + still means open.
- **Belly.** The belly swings on a spring behind the body's movement, and breathes.
- **Wounds.** They show on the skin as hp drops (the shader's `hurt` uniform).
- **Keys.** The super's keys hang on a cord on his chest.
- **`at(joint)`.** Every joint has a `BoneAttachment3D`, so `at(joint)` and anything hung on a joint still work.

## Making one by hand

The `.glb` files are ordinary glTF. You can:

1. Open one in Blender.
2. Resculpt it, or replace it with a hand-made model.
3. Keep the bone names and rest positions; each bone's rest rotation must be none.
4. Export it over the same path.

The game uses your model as it is. Vertex colours are optional; without UVs the flesh shader's fine detail just stays flat.
