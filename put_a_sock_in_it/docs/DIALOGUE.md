# Writing conversations

Conversations are data. They live in `data/dialogue/*.json`; the `Dialogue` autoload plays them. Nothing about a conversation is in code: what's said, who says it, what the player can answer, what each answer changes, and where it goes next.

## A conversation

A conversation is a list of steps, played in order.

```json
"super_hello": [
	{"pause": 0.6, "who": "super", "text": "You. Visitor.", "event": "super_looks"},
	{"who": "kurt", "text": "...You're naked.", "tone": "quiet"},
	{"with": "super", "choices": [ ... ]},
	{"id": "book", "who": "super", "text": "Name. Flat. Time in. Time out."}
]
```

### A step can have

| key | does |
|---|---|
| `who`, `text` | A line. Shown as a subtitle, typed out with the speaker's voice blips. |
| `tone` | `quiet` or `aside` (smaller, slower); `shout`. |
| `pause` | Seconds of silence before the step. |
| `hold` | Extra seconds after a line. |
| `socko` | A cue for Socko's performance: `{"emotion", "gesture", "look", "hold"}`. See below. |
| `event` | A stage direction the level acts on, such as `super_book` or `super_stare`. `wait` holds for that many seconds. |
| `if` | A condition. The step is skipped unless it holds. See below. |
| `do` | Consequences, applied when the step is reached. See below. |
| `id` | A name to jump to. |
| `goto` | Jump to an `id`: in this conversation, or `"other_conversation:id"`. |
| `end` | `true` ends the conversation here. |

### Choices

```json
{"with": "super", "choices": [
	{"text": "Sorry. Didn't mean to barge in.", "approach": "cooperative",
	 "do": [{"rel": "super", "add": {"trust": 2}}],
	 "steps": [ {"who": "super", "text": "Polite. I like polite."} ],
	 "goto": "book"},
	{"text": "The committee will want to see the lift.", "approach": "deceptive",
	 "if": "flags.has('ch2_said_committee')", "locked": true, ...}
]}
```

- **`text`:** what Kurt says.
- **`steps`:** what follows that choice. Then the conversation carries on, or jumps to `goto`.
- **`do`:** consequences, applied the moment it's picked.
- **`approach`:** one of `cooperative`, `neutral`, `suspicious`, `hostile`, `deceptive`. It's counted on the character named by the list's `with` (`rel.<with>.approach`). Approaches are how Kurt behaves, not a morality score.
- **`if`:** the choice only appears when the condition holds. With `"locked": true`, it shows greyed out instead of hidden.
- **`tag`:** `memory` or `telepathy` marks the choice as coming from a skill.

**Picking:** number keys, the mouse, a gamepad (focus plus A), or touch (the choices are buttons).

## Conditions

A condition is a Godot `Expression`. It can use:

| Name | What it is |
|---|---|
| `flags` | Story flags: `flags.has('x')`, `flags.get('x', 0) > 2`. |
| `rel` | Relationships: `rel.super.hostility < 2`, `rel.super.disposition == 'cooperative'`, `rel.kurt.known.has('wife_tula')`. |
| `inv` | The inventory: `inv.has('crowbar')`. |
| `memories` | The memories count. |
| `skills` | The skills: `skills.has('s_telepathy')`. |

## Consequences (`do`)

`do` is a list. Each entry is one of these:

| Entry | Effect |
|---|---|
| `{"rel": "super", "add": {"suspicion": 1.5}}` | Adds to a relationship number. |
| `{"rel": "super", "set": {"threatened": true}}` | Sets a relationship value. |
| `{"flag": "ch2_signed"}` or `{"flag": {"x": 3}}`, `{"unflag": "x"}` | Story flags. |
| `{"know": ["kurt", "wife_tula"]}` | Something someone now knows. |
| `{"give": "maint_key"}`, `{"take": "maint_key"}` | Inventory. |
| `{"event": "name"}` | The level acts on it. |
| `{"objective": "Flat 27."}` | The objective line. |

Code can apply the same consequences: `Dialogue.apply([...])`.

## Relationships (`Game.rel`)

Each character has these values:

- `suspicion`, `hostility`, `trust`
- `threatened`, `offended`, `lied`
- `known`: a list of facts
- `approach`: counts of each approach

`Game.disposition(who)` turns those numbers into a disposition:

| Disposition | Rule |
|---|---|
| hostile | threatened, or hostility 4+ |
| suspicious | suspicion 4+ |
| cooperative | trust 3+ |
| deceived | trust 3+, but `lied` |
| neutral | anything else |

Disposition is saved with the game. Levels read it to decide what a character does. The player never sees the numbers.

## Speakers

Kurt, Socko and Marta are built in. Add others in any file:

```json
"_speakers": {"super": {"name": "THE SUPER", "color": "#b9a27c"}}
```

A voice blip is used if `v_<who>0..3` exists in `Sfx` (the super has one).

## Socko's performance

Socko's cues take these values:

| Cue | Values |
|---|---|
| `emotion` | `neutral`, `happy`, `excited`, `curious`, `nervous`, `disappointed`, `uncanny`, `artificial` (too much smile, held), `irritated`, `angry`, `still` |
| `gesture` | `recoil`, `tilt`, `nod`, `bounce`, `point`, `shake`, `snap` (whips round to Kurt), `jab` (at his face), `tremble` |
| `look` | `kurt`, `ahead`, or a named point the level set |

Anything in a file that isn't a list of steps is ignored, so `_about` and similar notes are safe.
