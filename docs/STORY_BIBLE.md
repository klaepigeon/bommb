# HYSTERIA — Flat 47 Story Bible and Opening Beat Sheet

Deliverable 1. Status: **draft for approval.** Everything marked **PROPOSED** is a decision the
master prompt leaves open; it is written down here so it can be approved or changed before
anything is built on it. Nothing in the established opening (prompt §3.1) has been altered.

---

## 1. Setting

- **Kerzhansk, Russia, October 1996.** A mid-sized industrial city (fictional). Building 14,
  Ulitsa Gagarina: a 1950s brick block, nine storeys, on a courtyard.
- The district around Plant No. 3 was **evacuated on 15 October**: buses from the school yard at
  06:00, one bag each, tap water declared unsafe, "do not go down to the basements". The official
  line is a precautionary water-contamination measure. (Already in the game's environmental
  text; dates fit 1996. The notice's issuer becomes the city administration rather than a Soviet
  "District Executive Committee" — **PROPOSED** wording fix for 1996.)
- Most residents left. Some didn't. Something has been growing in the building since.

## 2. Characters

### The protagonist
- An older man, about sixty. In the 1960s he was a masked marksman — a Hawkeye-style hero with
  a bow and later a rifle. Retired for decades. **Name: undecided.** The current build calls him
  Lebedev; the prompt doesn't name him. **PROPOSED:** keep *Lebedev* as the name on the papers
  in his coat, which he reads after waking and doesn't recognise.
- **Why he is at Flat 47 (PROPOSED, consistent with the current cutscene):** Marta Sokolova's
  sister in Kursk hasn't heard from her in eight days; phones in the district are down. Someone
  gave her his name as a man who "finds people quietly". He took the job because he takes jobs
  like it now: small, discreet, paid in cash. He is not a policeman.
- **After the attack:** no memory of who he is, why he's here, or his past. His body remembers:
  how to clear a doorway, how to hold a pistol, how to stay low and quiet, how to weigh an object
  for throwing. He is surprised by his own competence and never explains it.
- Old injuries: a stiff left shoulder, a bad right knee. They show in idle, running and crouching.

### Marta Sokolova
- Forty-one. Lived in 47 with her husband **Ilya** (night shift, Plant No. 3) and daughter
  **Sonya** (seven, eight on the 22nd). The family's story is already told by the flat: the
  calendar, the fridge note, the half-packed suitcase, the made bed, the drawing for Papa.
- **Her condition:** alive. Fused to a kitchen chair at her place at the dining table, before
  the uneaten dinner for three. Grey-green mould across her skin and clothes; coral-like growths
  out of her shoulders, ribs, jaw and hands, rooted through the chair into the floor. Her body
  has been sitting long enough that chair and woman are one shape.
- She is lucid in a narrow way: she knows she is waiting. She does not know how long.

### Socko
- A dirty striped sock with big googly eyes and a red felt tongue, worn on the protagonist's
  left hand. Appears **only** after the protagonist wakes.
- **What Socko claims:** that he's always been there ("Course I know you, bud. I'm on your
  hand."); that he's here to help get them both out.
- **Who Socko is (owner's canon, withheld in Flat 47):** Socko is **Psygmund**. Nothing in
  Flat 47 names, hints at, or explains Psygmund; his nature beyond that is the owner's to define.
- **What Socko actually knows (withheld in Flat 47):** the layout of the flat, where useful
  things are, what the infection does, and who the protagonist used to be. He uses that
  knowledge selectively.
- **Agenda:** he wants the protagonist violent, obedient and incurious. Every shortcut he offers
  is the loud, destructive, cruel one. He is never openly evil in Flat 47 — friendly, funny,
  useful, a little impatient when the player looks at things too long.

### Ilya Sokolov (absent)
- Came back after the evacuation to wait for his family, lived in the box room (the den, the
  tally marks, the note), was bolted in from the outside by someone. Not found in Flat 47.
  What happened to him is **withheld**.

## 3. The boxes (the question is load-bearing)

**Owner's direction:** the boxes are **not physical objects**, and they come from **somewhere else
in the story** (to be defined by the owner). Nothing in Flat 47 may suggest they are crates,
parcels, luggage or anything you could find in a room.

Rules for Flat 47:
- Marta asks the question as if it were the most important thing in the world, and as if any
  reasonable person would know what she means.
- No object, document or line in Flat 47 explains or illustrates the boxes.
- The protagonist doesn't understand the question. Neither does the player. Socko changes the
  subject (bible §6) — the one thing he won't joke about.
- Integration point for later: a narrative flag `heard_boxes_question` and the exact wording of
  every line that mentions boxes are recorded so the larger story can pay them off.

## 4. Knowledge ledger

| | Knows at start | Knows at end of Flat 47 |
|---|---|---|
| **Protagonist** | Job, client, Marta's name, the address. Then: nothing (amnesia). | His name from papers in his coat; that he came here to check on a woman; that his hands know violence. |
| **Player** | Everything in the opening cutscene. | The above, plus whatever they read: the family, the evacuation, Ilya's den, the boxes clues. |
| **Socko — claims** | "We're mates. I'm on your hand." | Same, plus "Trust me, bud." |
| **Socko — actually knows** | He is Psygmund. The flat, the infection, the protagonist's past, what the boxes are. | Same. Slips once: calls him by a name the player hasn't heard (**PROPOSED**: his old codename, *Strelok*). Covers it. |
| **Marta** | Her family, the evacuation, the boxes, that she is waiting. | (Infected; no longer reliable.) |

**Withheld deliberately:** that Socko is Psygmund; the protagonist's past beyond his body's habits; what
the infection is; what happened to Ilya and Sonya; what the boxes really contain; who bolted the
box room.

## 5. Opening beat sheet

Timings are targets for pacing, not hard limits.

1. **Arrival (cutscene, ~40 s).** Courtyard at dusk, lobby, stairs, landing. The door of 47
   stands ajar. He knocks: "Mrs Sokolova? My name is Lebedev. Your sister asked me to look in on
   you." He goes in. The door swings shut behind him. *(No chain: he is not trapped yet.)*
2. **Initial exploration (player control, 2–4 min).** Hallway, kitchen, bedroom open; the
   living-room door is half shut. He reads the flat: the calendar, the fridge note, the water
   jars, the suitcase. A smell, and a slow wet sound of breathing from the living room.
3. **Discovering the apartment's condition.** Mould climbing the hall wall toward the living room;
   coral nubs in the skirting; the dinner table seen through the frosted glass of the door.
4. **The woman.** He opens the living-room door. Marta at the table, fused to her chair, facing
   away, in the light from the window. The player can walk round her, look at her, look at the
   table. **No timer.** Nothing happens until the player comes within arm's reach and looks at
   her face (or lingers in the room ~45 s).
5. **The question.** Her head turns, slowly, with a sound like a joint cracking in cold. Her eyes
   are clear. Quiet, polite, tired: *"Have you seen the boxes?"* A pause the player can fill by
   walking away or staying. If he stays, she asks again, more carefully, as if he might not
   have heard: *"The boxes. Have you seen them?"* If he answers by looking at her (interact):
   *"You haven't. No. Nobody has."*
6. **The attack.** Without warning — no sting before it — her arm comes off the table, tearing
   coral, and closes on his wrist. The chair shrieks across the floor as she pulls him down to her.
   Camera driven by his body: yanked forward and down, his free hand braced on the table, plates
   going over. Her face close: *"Have you seen them?"* Darkness from the edges in.
7. **Blackout (~5 s of near silence).** A heartbeat, the building's hum, a child's
   counting-under-breath that may be the pipes.
8. **Waking.** On the living-room floor beside the table, looking at the ceiling. Blurred vision
   clearing. He sits up badly (shoulder). The chair is empty: torn upholstery, coral stumps, mould
   in the shape of where she sat. **She is gone.** He doesn't know where he is, or who.
9. **The hand.** His left hand rises into view on its own, slowly. There is a sock on it. Googly
   eyes. It looks at him.
10. **Socko's introduction (~60 s, not rushed).** Socko speaks. Physical comedy and unease in
    equal measure. He gives a reason to move and nothing else. (Dialogue §6.)
11. **Tutorial and the threat.** The front door now **is** chained and padlocked from the inside
    — and he has no memory of doing it. Marta is loose in the flat: infected, mobile, hunting by
    sound. The player learns movement, interaction, inspection, carrying and throwing, the
    pistol, noise and stealth while finding a way out. Socko keeps nudging toward the gun.
12. **Escape.** Any mix of these (systemic, not scripted routes):
    - **Loud:** shoot the padlock (two rounds; brings her running), or take the axe from the box
      room to the chain (three blows, very loud). Socko's preference: kill her first.
    - **Quiet:** the padlock key is at the bottom of the black bath (drain it, ~30 s of gurgling
      noise you have to manage). Or lure her with a thrown object / the radio / the TV into the box
      room and **slide the bolt** — the same bolt someone used on Ilya.
    - **Mixed:** wound her and bolt her in; distract her and shoot the lock while she's away.
    Leaving: the chain falls, the landing, the stairwell. Socko: *"See? Easy. Next time we just
    do it my way."* — or, if she was killed, he is delighted and the player should feel it.

**End of chapter.** Fade on the landing. The peephole of 48 opposite is dark, then not.

## 6. Dialogue (first draft)

Delivery notes in brackets. Socko's lines are written to be performed with the hand, not read.

### Marta
- **Before the question (breathing only).**
- *"Have you seen the boxes?"* [soft, ordinary, the way you'd ask a neighbour about the post]
- *"The boxes. Have you seen them?"* [patient, careful, as to someone hard of hearing]
- *"You haven't. No. Nobody has."* [a little disappointed; not sinister]
- **Attack:** *"Have you seen them?"* [very close; urgent; human — the same question, begged]
- **Infected, hunting (fragments, overheard):** "Sonya, shoes." / "Have you seen…" / counting
  under her breath. [the same voice, broken up; never shouting]

### Socko — introduction (beat 10)
1. [the hand rises; long silence; the mouth opens a little, closes] *"…Hi."*
2. [leans in, looks him over] *"Oof. Okay. You took a knock. Don't sit up fast."*
3. [he sits up anyway; Socko winces] *"Or do. Sure. You do you."*
4. [player looks at him] *"It's me. Socko. Your hand? We're close."* [beat] *"Physically."*
5. [player looks round the room] *"She's gone. Don't look at the chair, bud. Look at me."*
6. [turns toward the hall] *"Door's that way. Let's get you out before she comes back for
   seconds."*

### Socko — tutorial (contextual, first time only; keyboard or pad wording)
- Movement: *"Walk it off. Slow. Your knee's making noises I don't like."*
- Crouch: *"Get low. Lower. There you go — you've done this before, huh?"*
- Inspect: *"Turn it over. Yeah. Fascinating. Can we go?"* [impatient seed]
- Pick up / throw: *"Heavy end first. Throw it like you mean it. Or — you know where it'd really
  land? On her."* [violent seed]
- Noise: *"Hear that? She hears it too. Everything you drop, she hears."*
- The pistol (found in Ilya's jacket lining **PROPOSED**): *"Ooh. Now we're talking. You know
  what that's for."* [delighted] — reloading: *"Look at you go. Did you see your hands? I didn't
  teach you that."* [the first hint he knows something]
- Bath / key: *"Or. Or. We shoot the lock. Takes two seconds. The bath takes forever."*
- Bolt option: *"You're gonna shut her in a cupboard? Like him?"* [irritated; slips: "like him"]
- If the player spares her: *"…Fine. Fine. Your way. Slower, but fine."* [passive-aggressive]
- If the player kills her: *"Strelok's still got it!"* [delighted; the name slips out]
  *"What? It's a… word. Come on."*

## 7. Tone rules

- Marta is frightening because of what has happened to her and how ordinary she sounds.
- Socko is funny first. The funnier he is, the worse the seeds land later.
- Nobody explains the boxes. Nobody explains Socko. Nobody says "Psygmund".
- Silence is a tool: after the attack, after the first shot, after the bolt slides home.
