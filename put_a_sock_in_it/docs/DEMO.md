# The demo

The demo is Flat 47 and the maze, ending at 48's door. After the last chapter card the title room comes back with the end panel:

- a thank-you
- how the player's run went: time, times caught, times hidden, times they put Marta down, memories found (of 3), secrets found (of 1)
- **Wishlist** / **Follow** buttons
- **Play again**

The run summary is there to invite a second run played differently.

## `data/demo.json`

| key | |
|---|---|
| `is_demo` | Shows the red DEMO tag on the title, and the end panel after the last card. |
| `store_url`, `store_label` | The wishlist button, in gold. An empty URL hides it. |
| `follow_url`, `follow_label` | A second button, for a Discord, newsletter or social account. An empty URL hides it. |
| `hide_placeholders` | Lets the demo ship before the writing is in. Placeholder dialogue lines are skipped, placeholder graffiti isn't drawn, and placeholder item descriptions are blank. Nothing is written in their place. |

## Writing still needed

These show the "neenor … placeholder" text today:

| Where | What | When the player meets it |
|---|---|---|
| The landing, outside 47 | 4 pieces of graffiti (`scripts/world/stairwell.gd`, `_graffiti`) | **The first thing anyone sees** |
| `flat47.json` → `socko_chair` | 4 lines | Socko, at Marta's empty chair |
| `flesh47.json` → `marta_evolved_b` | 2 lines | Her second sighting in the maze |
| `flesh47.json` → `marta_evolved_c` | 4 lines | Her third sighting |
| `exported_flat.gd` → `TEXT_PATCH` | Wedding photograph, bundle of letters | Inspecting them |
| `skills.gd` → `m_1`, `m_2`, `m_3` | What each memory node brings back | The skills menu |

Writing those, or setting `hide_placeholders` to `true` for a public build, is the one thing standing between this build and showing it to people.

## What you did (Chapter 2)

After the cathedral, the end screen adds a line for each of Chapter 2's choices (`title.gd` `_what_he_did`):

- **The super:** what he became, from his disposition. "He gave you his key", "you lied to him, and he believed you", "he watched you all the way up", "he hunted you", "he let you be", or "you killed him".
- **Twenty-seven:** the last nail driven, him taken down, or him left there.
- **Socko:** how many times Kurt did what Socko wanted, out of how many. Then "He remembers." if Kurt ever refused, or "He's very pleased with you." if he never did.
