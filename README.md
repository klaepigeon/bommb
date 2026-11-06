# MEAT PARTY (working title)

A four-player survival party game in Godot 4.7, hosted by **THE CALLER**: a plaid-suited
robot with a brass bingo cage full of dice for a head, ported from *LAST CALL: The
Campaign* (via RATFORMER in `klaepigeon/Video-Game`). Roll round the board, play the
minigames, collect items, lose limbs. Or notice that the door isn't painted on.

Android and PC, the same game on both: single-player against AI, local party (2-4 on one
device), and online (phones and PCs in the same room by room code).

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
server/             relay_server.gd: rooms + packet relay for internet play
scripts/view/       GameView, Venue (hall + board), Contestant (injuries, deaths), minigame views
scripts/visual/     CallerActor (40 animations), Ps1Human, lastcall/ (the Caller's figure,
                    dice cage, textures, mesh builder), the ink shader's lamps, RetroScreen
scripts/ui/         App (menus, lobby), Hud, UiKit, TouchStick
tests/              run_tests (rules), net_test + view_bot (network), shots (screenshots)
```

How a match flows, how to add a minigame, and what's done: [docs/CHECKLIST.md](docs/CHECKLIST.md).
Networking, the relay, and what still needs real devices: [docs/NETWORKING.md](docs/NETWORKING.md).
