# MEAT PARTY: game flow, minigame presentation, pacing (v0.2.6)

The game runs like a party board game: every turn has a beginning, middle and end, and every
minigame is presented the same way. Three pieces make that happen, all host-side (so every
screen in an online match sees the same thing at the same time):

| Piece | File | Job |
|---|---|---|
| `GameFlow` | `scripts/core/game_flow.gd` | the one explicit state the match is in; legal changes only |
| `MinigamePresenter` | `scripts/core/minigame_presenter.gd` | the 15-stage presentation every minigame goes through |
| `Pacing` | `scripts/core/pacing.gd` | every presentation timing, in three presets |

## The flow

```
MATCH_INTRO
ROUND_START
  TURN_ANNOUNCEMENT -> PLAYER_MOVEMENT -> LANDING_EVENT -> EVENT_RESOLUTION -> TURN_END   (x each player)
  (SEARCH: a SEARCH square, inside EVENT_RESOLUTION; DOOR: the way out)
ROUND_END
  MINIGAME_SELECTION -> MINIGAME_INTRO -> MINIGAME_INSTRUCTIONS -> MINIGAME_ARENA_INTRO
  -> MINIGAME_COUNTDOWN -> MINIGAME_ACTIVE -> MINIGAME_RESULTS -> MINIGAME_RETURN   (x each game queued)
ROUND_CONTINUE -> ROUND_START ...  -> FINALE -> GAME_END
```

`GameFlow.ALLOWED` is the table of legal changes; anything else is refused and counted
(`flow.invalid`, which the tests require to be empty). The board is frozen in every
`MINIGAME_*` state: board logic doesn't tick, board actions are ignored, nobody moves.

## The minigame presentation (every game, no exceptions)

1 board_freeze, 2 selection (category), 3 title (title + description), 4 arena_preview,
5 teams, 6 instructions (HOW TO PLAY; mandatory; NEXT), 7 controls (the real bindings for
the player's device, touch diagrams, PRACTICE; READY), 8 arena_intro (registration: anyone
away forfeits), 9 positioning, 10 countdown (3, 2, 1, GO!), 11 play, 12 play_freeze,
13 results (placings, shown), 14 rewards (Teeth, pots, prizes, consequences, applied),
15 return (a fade back to the board).

Instructions and controls are gates: a minimum reading time (Pacing), then every person
playing confirms (AI players "read" for the minimum time and confirm themselves). The
countdown can't start while either is up. A safety limit (`mg_instructions_max`) stops an
absent player holding the table forever.

## Adding a minigame

1. Write its gameplay: a `Minigame` subclass (`start`, `tick`, `action`, `ai`, `placings`,
   `summary`, `instructions()`, and `controls(seat)` or `buttons_only()`).
2. Give it a view (`scripts/view/mg_*.gd`) and an arena (`ArenaWorld.THEMES`).
3. Add one line to `MinigameRegistry.GAMES` (id, title, format, players, script, view) and its
   presentation metadata to `assets/data/minigames.json` (description, special animations,
   any timing overrides).
4. Run the validator. It isn't finished until it passes:

```
godot --headless res://tools/validate_minigames.tscn            # registrations
godot --headless res://tools/validate_minigames.tscn -- --play  # + a real run through all 15 stages
```

A game whose registration is incomplete is never put in front of people: `MatchCore`
refuses to start it, flags it (`incomplete`, an error in the log) and moves on.

## Pacing

`Pacing.PRESETS`: `standard` (readable, the default), `relaxed` (more time), `fast` (quicker,
never drops a stage). Picked in the lobby (PACE). Keys: round_start, turn_announce, step,
landing, event, turn_end, round_end, and one per presentation stage (mg_*). A game may
override timings through its registration's `pacing`; it can't remove a stage.

## Input

`UiManager.ACTIONS` defines the keyboard and controller bindings (mg_tap, mg_tap2, mg_tap3,
mg_hold, mg_hold2, mg_swipe_*, mg_timing...). The minigame HUD answers to those actions,
and the controls screen reads them back (`Ui.control_binding`) for the device the player
last used (touch, keyboard, controller), so what's shown is what's bound.

## Debugging

- `--flow-debug`: an overlay with the flow state, how long it's been, and what it's waiting on.
- `--flow-step`: the presenter stops at the end of every stage until NEXT STAGE is pressed
  (`{"t": "flow_next"}`).
- `core.flow.waiting_on` says what's holding things up ("READY from DORIS", "reading time").

## Tests

`test_presentation` (FFA, 2v2, 1v3, duel, co-op, special event, encounter; AI only and with
a person; instructions can't be skipped; presets; validation; debug stepping),
`test_turn_flow` (whole four-player matches, one person and three AI, at real pacing: every
turn's states, the round's end, the presentation, results before rewards, the next round, no
invalid change), `test_input_bindings`, and `tests/touch_bot.tscn` (a whole match by touch).
