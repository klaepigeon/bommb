extends Node
## The thing in Kurt. A psychic god that wants him to kill, and to become one of them.
##
## Not an illness bar and not shown as a number. It rises from what Kurt does (the Story ledger)
## and from where he is (close to Marta, inside the Backrooms), and it leaks into everything:
## the post-process (shader global `infection`), the sound (whispers, Marta's clicks starting to
## mean something), Socko's confidence, which interactions are offered, and the state Kurt is in
## when he reaches Flat 48. The player should notice the world changing before they work out why.

signal stage_changed(stage: int)
signal surge(amount: float)        # a sudden rise: a visual/audio jolt

## stage thresholds: 0 calm, 1 noticing, 2 hearing her, 3 wanting it
const STAGES := [0.0, 0.18, 0.42, 0.7]

## What raises it. Keys are Story ledger keys.
const RULES := {
	"violence.shot_marta": 0.07,
	"violence.killed_marta": 0.25,
	"violence.struck_marta": 0.04,
	"violence.finished_marta": 0.3,
	"violence.shot_super": 0.05,
	"violence.killed_super": 0.2,
	"resource.fired": 0.015,
	"caught": 0.09,
	"socko.obeyed": 0.035,
	"clue.examined:box": 0.04,
	"backrooms.entered": 0.08,
}

var level := 0.0
var stage := 0
var suppressed := 0.0              # seconds left of the pills' dulling
var _pulse := 0.0
var _t := 0.0

func _ready() -> void:
	Story.recorded.connect(_on_record)

func _on_record(key: String, _d: Dictionary) -> void:
	if RULES.has(key):
		add(RULES[key])

func add(amount: float) -> void:
	if amount <= 0.0:
		return
	level = clampf(level + amount, 0.0, 1.0)
	_pulse = minf(1.0, _pulse + amount * 6.0)
	surge.emit(amount)
	_update_stage()

## passive exposure (Marta nearby, the Backrooms): amount per second
func expose(per_second: float, delta: float) -> void:
	level = clampf(level + per_second * delta, 0.0, 1.0)
	_update_stage()

func _update_stage() -> void:
	var s := 0
	for i in STAGES.size():
		if level >= STAGES[i]:
			s = i
	if s != stage:
		stage = s
		stage_changed.emit(stage)

## what the senses get: the level, plus the jolt of a recent surge, minus the pills
func effective() -> float:
	var e := level + _pulse * 0.35
	if suppressed > 0.0:
		e *= 0.35
	return clampf(e, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 0.5)
	suppressed = maxf(0.0, suppressed - delta)
	RenderingServer.global_shader_parameter_set("infection", effective())
	RenderingServer.global_shader_parameter_set("world_time", _t)

func reset() -> void:
	level = 0.0
	stage = 0
	_pulse = 0.0
	suppressed = 0.0

func to_dict() -> Dictionary:
	return {"level": level}

func from_dict(d: Dictionary) -> void:
	level = float(d.get("level", 0.0))
	_update_stage()
