class_name SuspicionManager
extends RefCounted
## What each player has done to get his attention (0..100; at 100 he kills them), and
## his attention itself: he watches, then he looks away (at the clock, the piñata, his
## drink), and a shudder runs through his cage just before he turns back. Doing anything
## while he watches gets you caught; while he's away it works; in the shudder it's a coin
## toss. He watches the most suspicious people longest.

const THRESHOLDS := [25, 50, 75, 100]

var core: MatchCore
var watching := true
var watch_target := -1          # who he's looking at, when watching
var turning := false            # the shudder before he turns back
var _t := 0.0
var _dur := 4.0
var distracted := 0.0           # forced away (lights, a bell, a ghost)
var looking_at := "you"


func _init(c: MatchCore) -> void:
	core = c
	_dur = core.rng.randf_range(3.0, 6.0)


func tick(dt: float) -> void:
	if distracted > 0.0:
		distracted -= dt
		watching = false
		turning = distracted < 0.8
		if distracted <= 0.0:
			_turn(true)
		return
	_t += dt
	turning = not watching and _t > _dur - 0.9
	if _t >= _dur:
		_turn(not watching)


func _turn(watch: bool) -> void:
	watching = watch
	_t = 0.0
	turning = false
	if watching:
		_dur = core.rng.randf_range(3.0, 6.5)
		# he watches the worst of you
		var best := -1
		var bs := -1.0
		for s in core.living():
			var w := float(core.p(s).suspicion) + core.rng.randf() * 30.0
			if w > bs:
				bs = w
				best = s
		watch_target = best
		looking_at = "you"
	else:
		_dur = core.rng.randf_range(2.5, 5.0)
		watch_target = -1
		looking_at = ["clock", "pinata", "drink", "exit", "ceiling", "tv"][core.rng.randi_range(0, 5)]
	core.emit({"e": "attention", "watching": watching, "target": watch_target, "at": looking_at})


## Make him look away for a while.
func distract(seconds: float) -> void:
	distracted = maxf(distracted, seconds)
	_turn(false)
	core.emit({"e": "attention", "watching": false, "target": -1, "at": "distracted"})


## Would he see `seat` do something right now?
func sees(seat: int) -> bool:
	if watching:
		return watch_target == seat or core.rng.randf() < 0.55
	if turning:
		return core.rng.randf() < 0.5
	return false


func add(seat: int, amount: int, why: String) -> void:
	var p := core.p(seat)
	if not p.alive or amount == 0:
		return
	var before := p.suspicion
	p.suspicion = clampi(p.suspicion + amount, 0, 100)
	core.emit({"e": "suspicion", "seat": seat, "value": p.suspicion, "delta": amount, "why": why})
	for th in THRESHOLDS:
		if before < th and p.suspicion >= th:
			_threshold(seat, th)


func _threshold(seat: int, th: int) -> void:
	var nm := core.p(seat).name
	match th:
		25:
			core.say("suspicion_25", {"name": nm})
		50:
			core.say("suspicion_50", {"name": nm})
			core.cage.tighten(seat, "suspicion")
		75:
			core.say("suspicion_75", {"name": nm})
			core.cage.tighten(seat, "suspicion")
		100:
			core.say("suspicion_100", {"name": nm})
			core.kill(seat, "audit", [], true)


func view() -> Dictionary:
	return {"watching": watching, "target": watch_target, "turning": turning, "at": looking_at, "distracted": distracted > 0.0}
