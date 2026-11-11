class_name SuperHunter
extends MartaHunter
## The Super. The building's caretaker, or what's left of him: a huge frame with the skin of a much
## heavier man hanging off it, naked, the top of his skull gone. He walks the ground floor.
## Body: the preserved SuperRig (its own skeleton; the loose skin and his genitals are sprung bones
## that swing with his stride). Brain: the same hunter as Marta (marta_hunter.gd), with a different
## temperament:
##   - he can't see much (what's left of his eyes): short sight, worse in the dark
##   - he hears everything: noises carry further to him
##   - he lumbers when he patrols, but he can cover ground when he's after you
##   - the lullaby means nothing to him; bullets stagger him, but it takes a lot to put him down
##   - every step is a thud you can hear coming (that's the stealth: listen, then move)

var rig: SuperRig
var _step_phase := 0.0

func _init() -> void:
	who = "super"
	eye_height = 2.1
	sight_dark = 2.2
	sight_lit = 7.0
	hearing = 1.45
	pacifiable = false
	hit_points = 260.0
	SPD = {"patrol": 0.7, "investigate": 1.15, "chase": 2.35, "search": 1.0, "retreat": 2.0, "pound": 0.0}

func _build_body() -> void:
	rig = SuperRig.new()
	rig.name = "Rig"
	model = rig
	add_child(rig)
	rig.build()
	# a tall body: a taller collider than Marta's
	for c in get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
			var cap := (c as CollisionShape3D).shape as CapsuleShape3D
			cap.radius = 0.38; cap.height = 2.2
			(c as CollisionShape3D).position.y = 1.1

func _animate(delta: float) -> void:
	if not rig:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	var m := "walk" if spd > 0.05 else "idle"
	match state:
		"chase", "pound": m = "hunt"
		"stunned": m = "stagger"
		"dead": m = "stagger"
	var look = null
	if player and state in ["chase", "suspicious", "investigate", "pound"]:
		look = rig.skel.global_transform.affine_inverse() * player.camera.global_position
	rig.animate(delta, {"speed": spd, "mode": m, "look": look})
	# each foot down is a thud you can hear coming
	_step_phase += spd * delta / 0.95
	if _step_phase >= 1.0:
		_step_phase = 0.0
		Sfx.play_at("step_concrete", global_position, 2.0 if state == "chase" else -2.0, 0.55)

func _hurt_sound() -> void:
	Sfx.play_at("grab", eye(), 2.0, 0.6)

## his breath: a wet, heavy rasp; no words, ever
func _voice(delta: float, _d: float) -> void:
	_click_t -= delta
	if _click_t <= 0.0 and state not in ["dormant", "stunned", "dead"]:
		_click_t = _rng.randf_range(2.0, 4.0) if state == "chase" else _rng.randf_range(5.0, 9.0)
		Sfx.play_at("whisper", eye(), -4.0 if state != "chase" else 0.0, _rng.randf_range(0.35, 0.5))

func _die(key: String) -> void:
	set_state("dead")
	Story.record(key)
	Story.set_flag(who + "_dead", true)
	velocity = Vector3.ZERO
	if _presence:
		_presence.queue_free()
	Sfx.set_tension(0.0)
	var t := create_tween()
	t.tween_property(rig, "rotation:x", -1.4, 1.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	collision_layer = 0

func iverbs(_p: Node) -> Array:
	return []                     # no finishing him with your hands
