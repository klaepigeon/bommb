# MEAT PARTY

A four-player survival party game in Godot 4.7, hosted by **THE CALLER**: a plaid-suited
robot with a brass bingo cage full of dice for a head, ported from *LAST CALL: The
Campaign* (via RATFORMER in `klaepigeon/Video-Game`). Roll round the board, play the
minigames, collect items, lose limbs. Or notice that the door isn't painted on.

Android and PC, the same game on both: single-player against AI, local party (2-4 on one
device), and online (phones and PCs in the same room by room code).

**The look is LAST CALL: The Campaign's**, taken from its source in `klaepigeon/Video-Game`
(branch `claude/new-session-rc175w`, `last-call-campaign/`): you sit at the Caller's
table in his bingo hall (its rooms, doors, lamps, candles, pint, flashboard and red
curtain), rendered at low resolution through his ink post-process, with his card stock,
IM Fell English and Special Elite for every word on screen. His figure is the campaign's
own. Those scripts are in `scripts/lcc/`, its shaders in `shaders/`, its sounds in
`assets/audio/`, its paper and pen-work in `assets/ink/`, its building data in `data/`.

**LAST CALL 3's hall** is done up for a party: flickering neon (some of it dying),
crepe-paper streamers from the ceiling, balloons going soft, a piñata over the stage that
has been leaking, and the chairs pushed in under the tables. The Caller has a new suit:
a sequinned dinner jacket the colour of a fresh bruise, black satin lapels, ruffles, a
gold bow tie and a dead carnation.

**Four people sit at his table**: the players, PS1 humans wearing the players' photos for
faces (your own seat is the camera; you see your hands). He hosts from the stage.

**The figures on the board are meat puppets of the players**: cartoon PS1 bodies of
rotting muscle and fat, stitched together, no faces (a stitched slit for a mouth),
and real eyes (veined, wet, the one thing on them that isn't crude) that follow you. Strings go up
into the dark; flies. What happens to the puppet happens to its person at the table (casts, bandaged
sockets, stumps; dead puppet, face-down on the table): on the puppet every injury goes in as
a pin, a lost limb is cut off with the thread left hanging, a lost eye hangs out on its
nerve, a prosthetic is brass screwed on in its place.

**The board is a drawing of a place**, like a children's board game: a road of coloured
squares winding through a sweet little land made of meat (ham hills, a gravy river,
sausage trees, bone fences, gumdrops with eyes in). Beside the road, eight numbered
drawings tell a story, a different one each match, and it's always a bad one
(`assets/data/board_stories.json`: add your own).

## Android

`apk/LAST_CALL_3.apk` (arm64, Android 7.0+). Allow installs from unknown sources, install,
play landscape. To rebuild: [docs/BUILDING.md](docs/BUILDING.md).

## Run

```
godot --path .                 # the game
godot --path . -- --quick      # straight into a match against three AI
```

## Test

```
tools/check_scripts.sh                                  # parse-check every script
godot --headless res://tests/run_tests.tscn -- --seeds=40   # rules: whole AI matches, every system
tools/net_test.sh relay 3        # 3 humans through the relay (separate processes)
tools/net_test.sh relay 4 | lan 4 | ip 3 | rejoin 3
xvfb-run godot --rendering-driver opengl3 res://tests/shots.tscn -- --out=/tmp/shots   # screenshots of a whole match
```

## Layout

```
assets/data/        board.json (the board), caller_lines.json (everything he says),
                    assets.json (every replaceable asset, by id)
assets/faces/       face photos (32x40, PS1-style; tools/make_faces.py in RATFORMER makes them)
scripts/core/       MatchCore (phases, deaths, endings), BoardRules, Body (injuries),
                    Items, PlayerState, CallerLines. No nodes: host-authoritative, testable
scripts/minigames/  Minigame base, MinigameRegistry, musical_chairs, roulette, hot_potato
scripts/ai/         AiBrain: plays through the same actions humans do, sees only their view
scripts/net/        Net (the match link for every mode), RelayPeer, LanBeacon
server/relay/       relay.js: the relay for internet play (Node; deploy: docs/NETWORKING.md)
server/             relay_server.gd: the same relay in Godot (local testing)
render.yaml         one-click deploy of the relay on Render
scripts/view/       GameView (sat at his table), TableBoard (the board on it), Contestant
                    (the voodoo dolls: pins, deaths), minigame views
scripts/lcc/        LAST CALL: The Campaign's Stage, Hall, CallerFigure, building and UI kit
scripts/visual/     CallerActor (40 animations), Ps1Human, lastcall/ (the Caller's figure,
                    dice cage, textures, mesh builder), the ink shader's lamps, RetroScreen
scripts/ui/         App (menus, lobby), Hud, UiKit, TouchStick
tests/              run_tests (rules), net_test + view_bot (network), shots (screenshots)
```

How a match flows, how to add a minigame, and what's done: [docs/CHECKLIST.md](docs/CHECKLIST.md).
v0.2 (ghosts, Dead Rats, suspicion and the Cage, cheating, leaving the table, poisons, ten
new games, the Russian Roulette encounter): [docs/V02.md](docs/V02.md).
v0.2.5 and MURDERLAND (the party board, Control System, arenas, ORGAN TRAIL, escape room,
saves, match length and mode): [docs/V025.md](docs/V025.md). Game flow, the minigame presentation framework, pacing and adding minigames: [docs/FLOW.md](docs/FLOW.md).
Networking, the relay, and what still needs real devices: [docs/NETWORKING.md](docs/NETWORKING.md).
