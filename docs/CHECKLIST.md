# Development checklist (vertical slice)

Legend: [x] done and tested here · [~] done, not yet tested where it must be · [ ] not done

## How a match flows
intro → **board round** (each living contestant: use/give items, tell what they know,
roll, walk, land) → **minigame** (Musical Chairs → Popper Roulette → Hot Potato, then
round again, nastier) → results → next round … until everyone's dead (**total
elimination**: the last one standing is "the winner" and gets the prize; round 10 is
LAST CALL for everyone) or they get out (**the escape**).

**The escape, not explained anywhere in game** (spoilers): the three CLUE spaces each
hide one number of the door's dials (landing shows it to you only; walking past, a sharp
eye might); TELL EVERYONE shares them. Hot Potato can be defused: FIDDLE with the toy,
then do what its face lights up, a different person each step (pass it on); the last one
keeps its winding key. Everyone alive stops at the door and waits there; one of them
tries it with the key and the numbers; then everyone has to PUSH. One holdout and it shuts.
Putting the popper down in Roulette (everyone, in a row) voids the game: another
crack in the rules, and he gets stranger every time (`unrest`).

## Adding a minigame
1. `scripts/minigames/<id>.gd` extends `Minigame` (setup/start/tick/action/view_for/ai).
2. `scripts/view/mg_<id>_view.gd` extends `MgView`.
3. One line in `MinigameRegistry.GAMES` (+ `ROTATION` to put it in the order).
4. HUD buttons for its actions in `Hud._actions`, Caller lines in caller_lines.json.

## Status
- [x] Godot 4.7 project, GL Compatibility (Android + PC), data-driven board/lines/assets
- [x] Match state, turns, board spaces, items (8), give/steal/share, endings (both)
- [x] Musical Chairs: chairs = players+1, never fewer; rigged chairs persist and grow
      each round; five hazards, each with its own sight and sound tell and death
- [x] Popper Roulette: host-side seeded probability, Spinner/Peeker/Skip/Mirror, the hidden "put it down"
- [x] Hot Potato: passing, hidden ordered defusal (no two steps in a row by the same
      hands), key, Caller reactions; two-handed steps slower for the one-handed
- [x] Injuries: 9 body parts, temporary/persistent/lost, prosthetics; legs → dice and
      speed, hands → passing and two-handed steps, eyes → spotting tells and clues,
      ears → hearing tells; shown on the figures (casts, scorch, patches, stumps, brass)
- [x] 8 staged deaths (trapdoor, launch, zap, pop, boom/dismember, jaws, clapper, prize)
- [x] AI: same actions and same view as a human; cooperative tables can escape
- [x] The Caller (ported figure + hatch + party hat), 40 named animations, moods, unrest
- [x] UI: menu, settings, single/local/online lobby, HUD, touch stick, results, endings
- [x] Networking: host-authoritative RPC link; ENet + LAN room codes; relay + room codes;
      AI takes dropped seats; rejoin; lobby ready/AI seats/return to lobby
- [x] Headless rules tests (thousands of checks over whole matches); multi-process net tests
- [~] Local multiplayer: device per seat (WASD/arrows/IJKL/pads/touch) for Chairs; turn
      games are hot-seat on shared buttons. Not tried with real pads or a tablet
- [x] Android APK builds and signs (apk/MEAT_PARTY.apk); [ ] not yet run on a device
- [x] LAST CALL: The Campaign's look: its hall, Stage, post shader, Caller, fonts, card stock
- [x] Voodoo dolls: photo faces, sacking, pins for injuries, thread for lost parts
- [~] Windows/Linux export presets written; not exported (templates not installed here)
- [ ] Real-device and real-internet networking tests (docs/NETWORKING.md)
- [ ] Deployed relay server (needs a public host: blocker for internet play)
- [ ] Voice lines (placeholders: babble from the hum; drop files into assets.json "voice")
- [ ] Per-seat corner pads for 4 people around one tablet
- [ ] Graphics profiling on actual Android hardware
- [ ] The other seven minigames (framework ready)
- [x] LAST CALL: The Campaign found (Video-Game, branch claude/new-session-rc175w)
