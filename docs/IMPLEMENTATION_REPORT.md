# HYSTERIA — Implementation report (Godot)

Measured against the owner's two master documents ("Master Character, Narrative, Gameplay &
Implementation Document" and "Narrative Systems, Socko, Immersive Sim Quests, Persistent Monsters
& Creator Toolkit"), as of the `claude/android-lighting-flicker-rghd2u` branch, November 2026.
`docs/AUDIT.md` describes the earlier Three.js build and is superseded by this report for the
Godot project in `hysteria/`.

Status words used here: **working** (in the game, tested), **partial** (in the game, but short of
the documents), **missing** (not started). Nothing is called working because a menu or a
placeholder exists.

---

## 1. Canon conflicts (the owner's later instructions in this session are followed)

The master documents predate several of the owner's own later directions. Where they disagree,
the later direction is in the game, and the conflict is listed here rather than silently resolved.

| # | Master documents say | Owner's later direction (followed) | Effect |
|---|---|---|---|
| 1 | The woman in Flat 47 is **Sonya**, "an old villain"; the return to Flat 47 is Sonya curled on the floor | The woman is **Marta Sokolova**, psychic, Rasputin's lover, Trickshot's (Kurt's) lover; **Sonya** is their daughter, whom Kurt abandoned; finding Sonya is the heart of HYSTERIA | The "return to Flat 47" scene is designed for Marta (see §4.8) unless the owner says otherwise |
| 2 | The **pursuer cannot be killed** through ordinary combat | Socko pushes Kurt to **kill Marta**; Headshot is an insta-kill; she can die (permanently) | Marta is killable. The unkillable-pursuer framework is kept for a future pursuer; Marta also has a non-lethal resolution (Sonya's shoes) |
| 3 | Kurt's gun is found in **Flat 48's gun safe** | Kurt meets Marta and **gets the gun in the labyrinth** behind the wardrobe | The revolver is in the labyrinth. Flat 48's GUN SAFE can still hold it if Kurt hasn't found it, or the owner may move it |
| 4 | "Husband" material in some older text | **No husband** in Flat 47 | Removed from the flat's text |
| 5 | Kurt "Hawkeye-style marksman" (earlier prompt) | Circus → assassin → Champion's League → freelance | Both may be true; the Trickshot name is the owner's |

## 2. What exists and works

| Area | Status | Where |
|---|---|---|
| Rendering for PC and Android | working: Compatibility renderer, PS1 shader (vertex snap, specular/alpha anti-aliasing), 1/3-res viewport with 15-bit dither and film-speed grain | `shaders/`, `main.gd` |
| Lighting stability | working: room light director, calm flicker models, no shadowed lights but the torch, steady torch (no jaw pulse, smoothed aim), precision-safe screen noise | `flat47.gd`, `socko.gd`, `ps1_screen.gdshader` |
| Flat 47 | working: rooms, doors, drawers, ~130 physics props, documents, "outside" white void and sticky notes, modelled skirting/coving/roses | `flat47.gd`, `flat_detail.gd` |
| Kurt's right arm and hand | working: anatomical two-bone IK, articulated fingers, grips, reach | `kurt_arm.gd`, `player.gd` |
| Socko | working: skinned sock on the hand, mouth formed by fingers and thumb, googly-eye physics, layered animation (hand, puppet, springs, intention), gestures, gaze, torch from his mouth | `scripts/socko/` |
| Socko's agenda | partial: tutorial lines, labyrinth agenda (rush, kill Marta, headshot), reactions to clues, shoes, killing, the escape; emotional progression (presenter → companion → manipulator, frustrated / angry from defiance) in `SockoDirector` (see SOCKO.md) | `socko_tutorial.gd`, `socko_labyrinth.gd` |
| The opening | working: Marta at the table, look/touch/grab, "Have you seen the boxes?", blackout, Socko's introduction | `marta_encounter.gd`, `socko_intro.gd` |
| The labyrinth | working: the impossible town under the Romanovs, wrapping main street, modelled facades, interiors, the frozen fight, environmental story (Rasputin, Trickshot, Sonya) | `scripts/labyrinth/` |
| Marta the hunter | working: hunts by sound and sight, holds Kurt, can be shot dead, or calmed with Sonya's shoes (one for a while, the pair for good) | `marta_hunter.gd` |
| Noise | working: one hub every listener hears (footsteps, impacts, gunshots, gurgles, axe blows) | `noise.gd` |
| Revolver | working: draw, fire, reload round by round, holes, skill effects | `scripts/weapons/` |
| Skill trees | partial: Memory and Survival trees in data, nuggets, buy anything, effects; Memory skills change play (handwriting, sense, chalk, counting); `Skills.aggression()` scales Marta | `scripts/progress/` |
| Flat 47 escape | working: axe, bath key, two rounds, thrown objects; the end of the chapter | `flat_escape.gd` |
| Carrying between places | working: what's in hand goes through the wardrobe gap | `wardrobe_gap.gd` |
| Saving | working: autosave, Save in the pause menu, Continue / New game, props where left, Marta's state, the escape's state | `save_game.gd` |
| Pause, settings, touch | working | `pause_menu.gd`, `touch.gd` |
| Tests | working: 11 headless suites (smoke, marta, doors, socko, pause, wardrobe, gun, hunt, escape, save, systems) | `hysteria/tools/` |

## 3. What's missing or short

| Area | Status | Gap |
|---|---|---|
| Kurt's full body (look down: chest to feet) | **missing** | Only the right arm exists; the left hand is Socko. Needs torso, pelvis, legs, feet on the same rig, aligned to the camera at 177.8 cm |
| Kurt's movement character (age, balance, economy) | partial | Hand flexing and grips exist; gait, stiffness, recoveries, falls don't |
| Dialogue runtime (branching, intents, conditions, consequences) | **missing** | Lines are hard-coded in Socko scripts and `Game.say` toasts |
| Kurt's voiced lines | **missing** | Kurt never speaks |
| NPC knowledge and relationships | **missing** | No NPCs besides Marta |
| Socko in dialogue (interrupt, proxy, reinterpret, hijack) | **missing** | Depends on the dialogue runtime |
| Contextual bark director (priorities, cooldowns, history) | partial | Socko's queue has stale expiry and urgent cut-in; not shared, not data-driven |
| Voice library (stable IDs, takes, import) | **missing** | Platform TTS stands in |
| Subtitles (speaker, timing, safe areas, localisation) | partial | Toasts only; no speaker labels, no safe-area handling |
| Cutscene runtime and timeline editor | **missing** | Scenes are hand-written state machines |
| Threat manager (central, configurable) | partial | `Skills.aggression()` is a single number Marta reads |
| Persistent monster framework | partial | Marta keeps state across saves; no general identity/encounter-history system |
| Quest framework (problem / Socko's reading / solutions / consequences) | **missing** as data | The escape and Marta are built systemically, but by hand |
| Flat 48 (white placeholders, sticky notes, Mama/Papa/Child, GUN SAFE, Suite 51) | **missing** | |
| Return to Flat 47 | **missing** | See conflict 1 |
| Creator toolkit (asset registry, dialogue/voice/cutscene/quest/skill editors, inspector, localisation, validation) | **missing** | No editor plugins exist |
| Localisation | **missing** | Text is inline |

## 4. Proposed architecture (Godot-native, content separate from code)

1. **Content registry** (`content/`): stable IDs for characters, lines, voice takes, assets,
   quests, skills. JSON for text-heavy data that writers edit, `.tres` Resources where the editor
   benefits. One autoload, `Content`, resolves IDs; nothing in gameplay code refers to a filename
   for authored content.
2. **Dialogue**: `DialogueGraph` resources (nodes: line, choice-by-intent, branch, condition,
   action, Socko interjection, end). A runtime, `Conversation`, plays them through one
   `Speech` channel shared with barks, so nothing talks over anything. Conditions and actions
   read and write one `WorldState` (the flags that already exist, plus per-NPC knowledge and
   relationship dimensions).
3. **Speech and voice**: `Speech.play(line_id)` picks the preferred take for the language from
   the voice library, falls back to TTS, drives subtitles and the speaker's mouth (Socko's
   fingers, a character's jaw) from the clip's envelope, or authored visemes if present.
4. **Subtitles**: one layer, safe-area aware, speaker label, timing from the clip or authored,
   localised by line ID.
5. **Cutscenes**: `CutsceneTimeline` resources with tracks (camera, actor, Socko, speech, sound,
   light, gameplay event, control, branch). The runtime drives the real actors in the real scene
   (no cinematic duplicates). The timeline editor is an editor plugin over the same resource.
6. **Threat manager**: one autoload combining base aggression, Survival and Memory contributions,
   narrative state and encounter modifiers into separate behaviour levers (detection range,
   search persistence, pressure, recovery). Marta reads levers, not a single multiplier.
7. **Quests**: `QuestDef` resources: the problem, Socko's reading, solutions (each a physical
   condition the world already reports), consequences. Quests observe the world; they never force
   a route.
8. **Creator toolkit**: Godot editor plugins (desktop only, never exported): content browser,
   asset replacement by ID with backups, dialogue graph editor, voice library, cutscene timeline,
   quest editor, skill editor, monster inspector, localisation table, validation report.

## 5. Implementation order (adapted to what exists)

1. **Narrative runtime foundation**: content registry, world state, speech channel, subtitles,
   dialogue graphs and conversation runtime; Socko's existing lines moved into data; Kurt's first
   voiced (TTS for now) responses. Tested with a small conversation.
2. **Threat manager**: replace `Skills.aggression()` with levers; Marta's AI reads them.
3. **Kurt's full body**: torso, pelvis, legs, feet on the arm's rig; look-down test scene.
4. **Quest definitions** for what exists (the escape, Marta), then Flat 48.
5. **Flat 48**: Flat 47's layout in white placeholders; sticky-note wall; transformations;
   Mama, Papa, Child; GUN SAFE; Socko's pressure; Suite 51 route preserved.
6. **Voice library and cutscene timeline** (runtime first, then editor plugins).
7. **Creator toolkit** plugins and the validation report.
8. **Return to Flat 47** once conflict 1 is settled.

## 6. Risks to existing content

- Moving Socko's lines into data must keep every existing line, trigger and once-only rule
  (tests cover the main ones).
- A full body on Kurt must not break the arm's IK, the revolver grip, or Socko's mount.
- Android performance: the modelled town is ~960 meshes with fine detail range-limited; a full
  body and Flat 48 must be measured on the same budget.
- Save compatibility: the save has a version number; new systems add fields, never rename them.
- The APK is just over GitHub's 50 MB recommendation (51 MB); Git LFS or a release asset would
  be better before it grows further.
