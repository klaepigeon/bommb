# HYSTERIA: engine evaluation (rebuild, Milestone A)

Status: **recommendation, awaiting the owner's decision.** Nothing has been built on it yet.

Candidates: Unreal Engine 5, Unity 6, Godot 4 (4.7). The brief's criteria are mandatory: Android
performance, touch interaction, physics, lighting, memory consumption and development complexity.
Two criteria specific to this project are added and kept separate, so they can be weighed (or
discounted) on their own:

- **Preserved assets.** Kurt, Socko and his rigged animations, and the monsters must survive the rebuild.
- **Who builds it and how it gets tested.** Every milestone needs a playable build.

## What the game asks of an engine

- PS1-era look: low-poly geometry, low-resolution unfiltered textures, vertex snapping, a render
  at reduced resolution, grain and dither, severe darkness. **None of this needs a modern
  high-end renderer.** It needs cheap custom shaders, a low-resolution render target, a few
  dynamic lights (torch, flicker, muzzle flash) over baked or vertex lighting, and fog.
- Interiors only: two versions of one apartment, built from one modular kit. Rooms behind doors
  are what occlusion culling is best at.
- Many small physics props (pick up, throw, stack, push), doors on hinges, drawers.
- One hunting AI on a navmesh, with hearing and sight. Dynamic obstacles (moved furniture,
  barricaded doors) must change her paths.
- Spatial audio with room-dependent reverb and occlusion.
- Touch-first UI with rearrangeable controls. Phone screens of every aspect ratio.
- Mid-range Android as the performance floor, sustained (thermal), not only the first minute.

## The criteria

### 1. Android performance

| | |
|---|---|
| **Unreal 5** | The weakest fit. Lumen, Nanite and virtual shadow maps are desktop/console only. The mobile renderer (ES3.1 / Vulkan forward) works, but the baseline cost is high: a large runtime, heavy shader permutations and compile hitches, and APKs that start at 100 MB or more. It suits high-end phones. A mid-range floor means fighting the engine's defaults all the way. |
| **Unity 6** | The strongest. URP is built for mobile: SRP Batcher, GPU instancing, forward+ rendering, ASTC, IL2CPP + ARM64, and Burst/Jobs for AI and perception budgets. **Adaptive Performance** reads thermal state and scales quality on supported devices. The Android profiler and Frame Debugger attach to a real phone. It is the most proven engine for mid-range Android 3D. |
| **Godot 4.7** | Adequate for this art style, with less margin and weaker tools. Two renderers: Compatibility (GLES3, widest device support) and Mobile (Vulkan). The previous build went through two device crash investigations (`e27c030`, `0bf7d89`, `c12dca4` comparing Compatibility against Vulkan). Most of those were the old build's own bugs, but debugging on device is mostly logs and home-made crash trails. Godot has no equivalent of Unity's on-device profiler or Adaptive Performance: a thermal governor would be our own code (frame-time watchdog → quality step-down). |

### 2. Touch interaction

All three need a custom control layer: none of them ships a production-quality mobile FPS scheme.

- **Unity:** the Input System with EnhancedTouch, and on-screen stick and button components, which are basic but extensible. Safe-area API.
- **Godot:** raw `InputEventScreenTouch` / `Drag` with multitouch indices, Control nodes with
  anchors for any aspect ratio, and `DisplayServer.get_display_safe_area()`. Building the control
  layer is direct.
- **Unreal:** a virtual joystick, plus UMG for the rest. It works, but it is the most awkward of the three to customise for rearrangeable, resizable controls.

Unity and Godot are effectively even here. Unreal is behind.

### 3. Physics

- **Unity:** PhysX. Mature and fast, with sleeping, layers, joints for doors and drawers, and continuous collision detection for thrown objects.
- **Godot 4.7:** Jolt is built in. It is stable and fast for rigid bodies and has hinge and slider joints. It is now comparable to PhysX for a game of this scale.
- **Unreal:** Chaos. Capable, but the heaviest on mobile.

Unity and Godot are effectively even.

### 4. Lighting (for this look)

- **Unity:** the progressive lightmapper, light probes and Adaptive Probe Volumes. Real-time lights are cheap in Forward+. Baking two versions of one apartment with different lighting is a standard workflow, and it is the best tooled of the three.
- **Godot:** LightmapGI bakes (Compatibility supports lightmaps) and ReflectionProbe. Real-time OmniLight and SpotLight shadows are expensive on phones, and the old build had to drop the torch shadow on phones (`fce66fe`). The PS1 look reduces how much this matters: darkness, vertex lighting and one shadowless torch carry it. It is workable, but with less headroom than Unity.
- **Unreal:** the best desktop lighting. On mobile, most of it is unavailable.

### 5. Memory consumption

Godot has the smallest runtime footprint and the smallest APKs. Unity (IL2CPP) is moderate: an
empty URP APK is around 20–30 MB. Unreal is the largest by a wide margin. At PS1 texture sizes,
the game's own content is small in all three, so this matters less than the runtime baseline.

### 6. Occlusion, LOD, pooling (brief §2, Performance)

- **Unity:** baked Umbra occlusion culling (ideal for rooms behind doors), LOD Groups, and an ObjectPool API.
- **Godot:** OccluderInstance3D (CPU raster occlusion, baked from the level), automatic mesh LOD, visibility ranges (HLOD), and pooling by hand. It also allows manual room/portal visibility, which in a two-apartment game is simple and very effective.
- **Unreal:** strong, but desktop-oriented.

### 7. Development complexity

- **Unreal:** Blueprints or C++, very long builds and shader compiles, and a 100+ GB toolchain. It is the highest complexity for the least benefit to this game.
- **Unity:** C#, a mature editor, and the largest pool of mobile know-how. Scenes and prefabs are editor-authored YAML with GUID references, so the work is editor-centred. A licence is needed (Personal is free under the revenue cap, but it must be activated with a Unity account).
- **Godot:** GDScript or C#. Scenes are plain text, and everything can be built, tested and exported from the command line with no licence. It is quick to iterate on, with less ecosystem depth.

### 8. Preserved assets (project-specific)

The assets the brief preserves are **not model files**. They are Godot code that generates
them at runtime:

| Asset | Where it is | What it is |
|---|---|---|
| Kurt | `game/scripts/art/kurt_body.gd`, `arm_rig.gd`, `kurt_textures.gd` | Procedural skinned arm and hand (bone chain, lofted mesh, IK `solve_arm`), and the body |
| Socko | `game/scripts/art/sock_rig.gd` (798 lines) | One skinned mesh on a skeleton, mouth-corner bones, googly eyes with pupil inertia, and stain layers |
| Socko's animations | `game/scripts/socko/socko_clips.gd`, `socko.gd` | **73 clips and 16 expressions written as functions of time**, layered and sprung at runtime. These are not keyframe tracks. |
| Marta | `game/scripts/art/marta_model.gd` | A jointed, generated model with a face and jaw |
| Monsters | `game/scripts/infected/*` (≈1,100 lines), `actors/super_rig.gd` | A generator: every infected body is built from a genome |

- **Godot:** they carry over as they are.
- **Unity:** they must be ported. Static meshes and skeletons can be baked out to glTF from Godot and imported. The animation clips can be baked to keyframes, but Socko's performance layer can't be baked: the springs, gaze, independent eyes and per-syllable mouth are computed live, so it needs a C# rewrite. The infected generator either becomes a fixed set of baked bodies, or it gets ported too. That is roughly 4,000 lines of careful port, with a real risk that what survives is a reconstruction rather than the preserved asset.
- **Unreal:** the same as Unity, and harder.

### 9. Who builds it, and how it is verified (project-specific)

This work is being done by Claude in a cloud container, without a GUI editor.

- **Godot:** I can write, run headless, play through automatically, render screenshots and export a signed APK here. Godot 4.7, its Android templates and the Android SDK are installed and working in this container now.
- **Unity:** I can write C# and editor scripts, but I can't open the editor. I also can't activate a licence without your Unity account. Builds and scene assembly would need you, or a CI runner with a Unity licence (GameCI on GitHub Actions can do batch-mode Android builds with licence secrets).
- **Unreal:** not practical in this environment.

Neither environment can test on an actual Android device, which the brief requires. That needs you, or a device farm (Firebase Test Lab, AWS Device Farm), whichever engine is chosen.

## Scores (1–5)

| Criterion (weight) | UE5 | Unity 6 | Godot 4.7 |
|---|---|---|---|
| Android performance (×3) | 2 | **5** | 3 |
| Touch interaction (×2) | 3 | 4 | 4 |
| Physics (×2) | 3 | 4 | 4 |
| Lighting for this look (×2) | 3 | **5** | 3 |
| Memory (×1) | 1 | 4 | 5 |
| Development complexity (×2) | 1 | 4 | 4 |
| **Engine merit subtotal** | **28** | **56** | **45** |
| Preserved assets (×3) | 1 | 2 | **5** |
| Buildable and verifiable here (×2) | 1 | 2 | **5** |
| **Total** | **33** | **66** | **70** |

## Conclusion

- **Unreal 5 is rejected.** It is the wrong engine for a mid-range-Android, PS1-styled interior game.
- **On engine merit alone, Unity 6 wins.** It has the best Android performance tooling, thermal management, lighting bakes and occlusion culling.
- **Once the preserved assets and the means of production are counted, Godot 4.7 wins narrowly.** The assets the brief says to keep already exist in it, and everything can be built and tested here.

**Decision (owner, this session): Godot 4.7.** Mitigations for its weaknesses:

1. **Renderer:** Compatibility (GLES3) on every platform: the widest Android support, no Vulkan driver crashes, and it is what the automated tests render. (Changed from Vulkan + fallback during Milestone A.)
2. **Performance budget:** written down before production. See the targets below.
3. **Thermal governor:** our own frame-time watchdog that steps render scale, lights and shadows down, and back up.
4. **Lighting:** baked LightmapGI for both apartments, plus at most one real-time shadowed light (the torch) on the High preset only.
5. **Culling:** room/portal visibility for the apartment, plus OccluderInstance3D.
6. **On-device diagnostics:** an on-screen frame-time graph, and memory and draw-call counters, from day one.

**If you have a Unity licence and will drive the editor** (or will fund a CI runner and accept
porting the characters), choose Unity 6 instead. It is the stronger Android engine. The cost is the
port described in §8 and editor work that only you can do.

## Performance targets (either engine)

| | |
|---|---|
| Floor device | Mid-range 2022 phone: Snapdragon 695 / Dimensity 900 class, 4–6 GB RAM, Adreno 619 / Mali-G68 |
| Frame rate | 30 fps locked, sustained for 30 minutes without dropping a preset. 60 fps on High where the device holds it |
| Frame time | 95th percentile ≤ 33.3 ms; no hitch > 50 ms outside loading |
| Draw calls | ≤ 150 per frame (Medium) |
| Triangles | ≤ 150k visible |
| Real-time lights | ≤ 4 visible, ≤ 1 shadowed (High only) |
| Memory | ≤ 900 MB resident on the floor device |
| Textures | ASTC/ETC2, mostly 64–256 px (PS1 scale), atlased per room |
| APK | ≤ 150 MB |
| Physics | ≤ 40 awake rigid bodies; sleep aggressively |
| AI | Perception at 10 Hz; pathing at most once per 0.25 s; distance-based processing |
