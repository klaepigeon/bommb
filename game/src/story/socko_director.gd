class_name SockoDirector
extends Node
## Socko's mind. He's the friendly guide; he's also the secret antagonist, and this is where that
## lives. He suggests: always the loud, violent, obedient option (shoot her, shoot the lock, smash
## it). The world records whether Kurt did what he said (socko.obeyed) or found another way
## (socko.ignored). Ignored, he gets short with Kurt; then sarcastic; then he loses his temper.
## Obeyed, he's delighted, and the infection likes it too.
##
## He never says what he is. His frustration shows in his face and his idles before his words.
## Once he's frustrated enough, he can give Kurt away: a giggle from the wardrobe at the wrong time.
##
## Also: the random conversations (owner's script), at quiet moments, each once.

static var inst: SockoDirector

var player: Player
var awake := false
var _quiet := 0.0
var _next_convo := 75.0
var _convos := ["a", "b", "c"]
var _pending := {}            # kind -> {t, obey_keys: [ledger keys], other_keys: [...]}
var _tier := 0
var threat_near := false      ## set by the hunt (no chit-chat while she's close)
var _giggle_t := 0.0

const SUGGEST := {
	# kind: [line, obey ledger keys (any), alternative ledger keys (any)]
	"shoot_her": ["s_shoot_her", ["violence.shot_marta"], ["stealth.hid", "stealth.evaded", "used:music_box", "stealth.distraction"]],
	"shoot_lock": ["s_shoot_lock", ["route.padlock_shot"], ["route.padlock_key", "route.padlock_cut", "route.padlock_pried", "route.padlock_smashed", "route.balcony", "route.vent"]],
	"smash": ["s_smash", ["route.smashed:vent", "route.padlock_smashed"], ["route.unscrewed:vent", "route.padlock_key"]],
	"finish": ["s_finish", ["violence.finished_marta"], ["stealth.spared"]],
	"go_gun": ["s_this_way", ["took:revolver"], []],
}

func _enter_tree() -> void:
	inst = self

func _exit_tree() -> void:
	if inst == self:
		inst = null

func _ready() -> void:
	Story.recorded.connect(_on_record)
	_tier = _tier_for(frustration())

func setup(p: Player) -> void:
	player = p

func frustration() -> float:
	return Story.count("socko.ignored") - Story.count("socko.obeyed") * 0.5

func _tier_for(f: float) -> int:
	if f >= 5: return 4
	if f >= 3: return 3
	if f >= 2: return 2
	if f >= 1: return 1
	return 0

## Socko proposes something. Said if he's not talking already; remembered either way.
func suggest(kind: String) -> void:
	if not awake or not SUGGEST.has(kind) or _pending.has(kind) or Story.flag("suggested:" + kind, false):
		return
	Story.set_flag("suggested:" + kind, true)
	_pending[kind] = {"t": Story.play_time}
	Speech.bark(String(SUGGEST[kind][0]))

func _on_record(key: String, _d: Dictionary) -> void:
	for kind in _pending.keys():
		var s: Array = SUGGEST[kind]
		if key in s[1]:
			_pending.erase(kind)
			Story.record("socko.obeyed", {"kind": kind})
			if kind != "go_gun":
				Speech.bark("s_hit" if kind == "shoot_her" else "s_good")
			_mood()
		elif key in s[2]:
			_pending.erase(kind)
			Story.record("socko.ignored", {"kind": kind})
			_mood(true)

func _mood(speak := false) -> void:
	var t := _tier_for(frustration())
	if not player or not player.socko:
		return
	var s := player.socko
	match t:
		0: s.idle_clip = "Idle_Default"; s.expression = "smile"
		1: s.idle_clip = "Idle_Observing"; s.expression = "neutral"
		2: s.idle_clip = "Idle_Impatient"; s.expression = "disappointment"
		3: s.idle_clip = "Idle_Impatient"; s.expression = "irritation"
		_: s.idle_clip = "Idle_Angry"; s.expression = "anger"
	if speak and t > _tier:
		Speech.bark("s_frust_%d" % t)
	_tier = t

func _process(delta: float) -> void:
	if not awake or not player or get_tree().paused:
		return
	if Speech.busy() or threat_near or player.mode != "normal":
		_quiet = 0.0
	else:
		_quiet += delta
	if _quiet > _next_convo and not _convos.is_empty():
		_quiet = 0.0
		_next_convo = randf_range(110.0, 170.0)
		var c: String = _convos.pop_front()
		Story.record("socko.convo_" + c)
		Speech.queue(convo_lines(c))
	# the betrayal: hiding, her close, him fed up
	_giggle_t -= delta
	if player.is_hidden() and threat_near and frustration() >= 3.0 and _giggle_t <= 0.0:
		_giggle_t = 12.0
		if randf() < 0.35:
			s_giggle()

func s_giggle() -> void:
	player.socko.play("Giggling")
	Speech.bark("s_giggle")
	Events.noise.emit(player.global_position, 7.0, "giggle", player)
	Story.record("socko.betrayed")

## the owner's random conversations; C branches on Kurt's recovered memories
static func convo_lines(c: String) -> Array:
	match c:
		"a": return ["ra_1", "ra_2", "ra_3", "ra_4", "ra_5"]
		"b": return ["rb_1", "rb_2", "rb_3", "rb_4", "rb_5"]
		"c":
			var m := Story.memory_points >= 1
			return ["rc_1", "rc_2m" if m else "rc_2", "rc_3", "rc_4m" if m else "rc_4", "rc_5", "rc_6", "rc_7"]
	return []

func get_state() -> Dictionary:
	return {"convos": _convos, "awake": awake}

func set_state(d: Dictionary) -> void:
	_convos = d.get("convos", _convos)
	awake = d.get("awake", awake)
