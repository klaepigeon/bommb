# Kurt Federov: character reference and right-hand rig specification

Status: canon is taken from the owner's documents (HYSTERIA master prompt; "Kurt Federov, Full-Body
First-Person Character & Socko Animation System"; "Master Character, Narrative, Gameplay &
Implementation Document"; "Narrative Systems…"; "Socko: Complete Character Animation Bible").
Nothing below the line marked **Not canon** is lore; it is production data.

---

## 1. Canon

| | |
|---|---|
| Name | **Kurt Federov** |
| Height | **177.8 cm** (5′10″) |
| Background | German-Russian |
| Age | An older man in 1996, retired |
| History, in order | German-Russian circus performer → assassin → superhero, member of the **Champion's League** → the League was absorbed into the **United Front** → freelance investigative work |
| Opening | Sent to Flat 47 on a wellness check; the woman there grabs him; he wakes with amnesia, and only then does Socko appear |
| Mind / body | He has lost his memories. His body has not: it keeps decades of training. |
| Personality | Dry humour, patience, observation, tactical instincts, compassion, restraint, the capacity for extremely efficient violence. A voiced protagonist, not a blank avatar. |

How the history shows in the body (owner's direction, condensed):

- **Circus:** exceptional balance, precise weight distribution, unusual coordination, controlled
  recovery from awkward positions. Grace in ordinary actions, never tricks.
- **Assassin:** economy of movement, weapon familiarity, awareness of exits, quiet efficient
  positioning, controlled handling of objects.
- **Champion's League:** physical confidence, an instinct to put himself between danger and the
  vulnerable, reacting to danger before understanding why.
- **Investigator:** studies objects, pauses to listen, looks at hands and faces.
- **Age:** stiffness in neck and shoulders, **hand flexing**, **unconscious weapon grips**, slightly
  uneven weight, small balance corrections, economical gait. Capable, never frail.

Do not invent: specific circus acts, missions, superhero identity, United Front history,
relationships, memories, or **specific injuries or disabilities**.

## 2. Open conflicts (the owner decides; nothing has been changed for these)

1. **Who the woman in Flat 47 is.** The newer documents call her **Sonya, "an old villain from
   his past"**. In this session the owner confirmed the body is **Marta** (Marta Sokolova), and the
   story bible has **Sonya** as Marta's seven-year-old daughter. The game and bible still say
   Marta. Resolving this changes the bible's family, the fridge note and calendar in the flat, and
   the later "return to Flat 47" design (written for Sonya).
2. **His name in the opening.** The JS build's cutscene and the bible used a placeholder,
   *Lebedev*. Replaced by Kurt Federov in the bible; the JS cutscene (`src/cutscene.js`) still says
   Lebedev until it's ported.
3. **Hawkeye-style marksman (earlier prompt) vs. circus/assassin/Champion's League (newer).** The
   newer, more specific history is used. They may both be true (a marksman in the League); not
   assumed.
4. **Injuries.** The bible's "stiff left shoulder, bad right knee" were invented by me; removed per
   "do not invent specific injuries". Age shows as generic stiffness only.
5. **A truncated line** in the master prompt's closing direction: "an older retired superhero, and
   a bad one. He's misogynistic, deeply [missing] whose body remembers…". This would be a major
   characterisation and is not used until the owner completes it.
6. **The "Strelok" codename slip** in the bible was my proposal; it conflicts with "do not invent a
   superhero identity" and is withdrawn.

---

## 3. Not canon: right-arm rig specification

Everything here is production data derived from standard anthropometry and joint-range norms,
scaled to 177.8 cm. Sources used (from established literature, not fetched in this session):
segment-length ratios after Drillis & Contini (1966) / Winter, *Biomechanics and Motor Control of
Human Movement*; hand dimensions after adult-male anthropometric tables (e.g. NASA-STD-3000 vol. I
§3); phalanx proportions after Buchholz, Armstrong & Goldstein (1992); joint ranges after AAOS /
AMA *Guides* normal ranges.

### 3.1 Lengths (stature H = 1.778 m)

| Segment | Ratio of H | Kurt |
|---|---|---|
| Upper arm (shoulder joint → elbow) | 0.186 | **33.0 cm** |
| Forearm (elbow → wrist) | 0.146 | **26.0 cm** (rig: 26.5) |
| Hand length (wrist crease → middle fingertip) | 0.108 | **19.2 cm** |
| Hand breadth (across the knuckles) | ≈0.05 | **8.6 cm** |

Phalanx bone lengths in the rig (proximal / middle / distal, cm), roughly in the measured
1 : 0.6 : 0.45 progression:

| Finger | P1 | P2 | P3 | radius |
|---|---|---|---|---|
| Index | 4.2 | 2.5 | 1.9 | 0.95 |
| Middle | 4.6 | 2.9 | 2.0 | 0.98 |
| Ring | 4.3 | 2.7 | 2.0 | 0.90 |
| Little | 3.4 | 1.9 | 1.7 | 0.80 |
| Thumb | metacarpal 5.0, P1 3.2, P2 2.5 | | | 1.12 |

The knuckle line is an arc: the middle knuckle is furthest from the wrist (9.7 cm), the little
finger's nearest (8.3 cm). Fingers fan slightly (index −4°, ring +3°, little +8°).

### 3.2 Skeleton (one Skeleton3D, one skinned mesh)

`upper_arm → forearm → forearm_twist → hand → {index, middle, ring, little}_meta → _1 → _2 → _3`,
and `hand → thumb_1 (metacarpal, at the CMC joint) → thumb_2 → thumb_3`. 21 bones.

Every bone's frame: **+Y along the bone, +Z toward the back of the hand (nail side), +X across.**
So flexion is always a rotation about the bone's own X (negative = curl toward the palm), and
spread is about Z. The thumb's frame is turned so its +Z faces out of the thumbnail; its flexion
therefore curls toward the palm, as the real one does.

- **Forearm twist.** Pronation and supination happen along the forearm (radius rolling over the
  ulna), not at the wrist. The `forearm_twist` bone carries it, and forearm skin is weighted
  forearm → twist from elbow to wrist, so the skin twists progressively instead of candy-wrapping
  at the wrist.
- **Metacarpals.** The index and middle metacarpals are nearly rigid; the ring and little
  metacarpals flex a little (4th CMC ≈ 10–15°, 5th ≈ 20–30°), which is what cups the palm in a
  fist. The rig gives them 12% and 20% of the finger's knuckle flexion.
- **Coupling.** The end joint of a finger can't be bent on its own: DIP flexion follows PIP
  (about ⅔). Poses author MCP / PIP / DIP separately, but limits keep them anatomical.

### 3.3 Ranges (normal adult, then the rig's limits for an older man)

| Joint | Normal | Rig (Kurt) |
|---|---|---|
| Finger MCP flexion / hyperextension | 90° / 30–45° | 85° / 20° |
| Finger PIP flexion | 100–110° | 100° |
| Finger DIP flexion | 80–90° | 70° |
| Finger spread (MCP abduction) | ±20° | ±16° |
| Thumb CMC flexion / palmar abduction | 15 / 45–70° | 40° / 55° |
| Thumb MCP / IP flexion | 50–60° / 80° | 50° / 70° |
| Wrist flexion / extension | 80° / 70° | 70° / 60° |
| Radial / ulnar deviation | 20° / 30° | 18° / 28° |
| Pronation / supination | 80–90° each | 80° each |

The reductions are generic age stiffness, not an injury.

### 3.4 What age looks like in the hand (generic, not injury)

Knuckles more prominent than the fingers between them; thinner skin over the back of the hand
showing tendons and veins; pigment spots; ridged, yellowed nails; creases at the knuckles; a fine
physiological tremor (small, ~8–10 Hz). Behaviour: the **hand flexing** and **unconscious grip**
from the owner's direction: every so often he slowly closes the hand most of the way and
opens it again, the ring and little fingers lagging, the way a stiff hand is worked.

### 3.5 First person

The arm is solved from a shoulder point 19 cm right, 26 cm below and 10 cm behind the eye
(two-bone IK, elbow pole down and out), so the hand is always connected to a shoulder and an
elbow the player could see if they looked. The hand lags the camera slightly (it has weight).
Idle: low in the bottom-right of view, palm in, fingers relaxed. Carrying: the object sits in a
curled hand. Using something: the hand reaches for it.

Clothing on the arm (a dark wool coat sleeve and a shirt cuff) is ordinary dress, not lore.
