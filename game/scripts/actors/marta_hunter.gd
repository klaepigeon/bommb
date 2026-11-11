class_name MartaHunter
extends Monster
## Marta in the town: floating, still seated in a chair that isn't there, a cold light about her.
## She comes after the revolver is taken, hunts by sound and sight, and keeps to the gate when she
## has nothing to follow. Bullets don't kill her (unless Kurt has Headshot and takes her head):
## enough of them and she breaks off and drifts away for a while. The gate's open then.

var marta: Marta
var away_point := Vector3.ZERO
var _light: OmniLight3D
var _pressure: AudioStreamPlayer3D
var _sensed := false
var awake := false      ## until the revolver's taken she only listens (or, prowling, sees him close to)
var prowling := false   ## she walks her round (wanders) instead of sitting by the way out

## She walks her round from the start, listening, and sees him if he comes close.
func prowl() -> void:
	prowling = true
	sight = 4.5

func wake() -> void:
	awake = true
	sight = 11.0
	listen_speed = 1.5

func head_follows_bone() -> bool:
	return false

func _animate(_delta: float, _spd: float) -> void:
	pass

func build_body() -> void:
	marta = Marta.new()
	body.add_child(marta)
	marta.build()
	marta.spot.queue_free()
	if is_instance_valid(marta._breath):
		marta._breath.volume_db = -16.0
	for c in marta.chair:
		c.visible = false        # still seated, in a chair that isn't there
	marta.breathing = true
	marta.head_lift = 0.6
	marta.position.y = 0.35
	head = marta.head
	speed = 0.9
	chase_speed = 1.8
	hearing = 1.4
	sight = 0.0
	listen_time = 40.0
	head_hp = 999
	body_hp = 999
	_light = OmniLight3D.new()
	_light.light_color = Color("9fc4d8"); _light.light_energy = 0.7; _light.omni_range = 4.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3(0, 1.4, 0.4)
	_pressure = AudioStreamPlayer3D.new()
	_pressure.stream = Sfx.streams["pressure"]
	_pressure.unit_size = 6.0
	_pressure.max_distance = 24.0
	_pressure.volume_db = -80.0
	add_child(_pressure)

func _physics_process(delta: float) -> void:
	super(delta)
	if hit_head:
		hit_head.global_position = marta.head.global_position + Vector3(0, 0.1, 0)
	if state == S.DEAD:
		return
	marta.look_target = player.camera.global_position if state == S.CHASE else Vector3.ZERO
	marta.head_lift = lerpf(marta.head_lift, 0.0 if (not awake and state == S.IDLE) or state == S.AWAY else 0.7, delta * 2.0)
	body.position.y = 0.05 * sin(_t * 0.9)
	# How She Moves: a pressure in the ears, louder as she nears, from where she is
	if Game.owned("how_she_moves") and state != S.CALM:
		if not _pressure.playing:
			_pressure.play()
		var d := global_position.distance_to(player.global_position)
		_pressure.volume_db = lerpf(-36.0, 0.0, clampf(1.0 - (d - 2.0) / 18.0, 0.0, 1.0))
		if not _sensed and d < 15.0:
			_sensed = true
			get_tree().call_group("director", "line", "senses")
	elif _pressure.playing:
		_pressure.stop()

func can_see_player() -> bool:
	if not awake and state == S.IDLE and not prowling:
		return false
	return super()

func _on_noise(pos: Vector3, radius: float, source: String) -> void:
	super(pos, radius, source)
	if state == S.LISTEN and not awake and source == "gunshot":
		wake()

func shot(part: String) -> void:
	if not awake:
		wake()
	if state in [S.DEAD, S.AWAY]:
		return
	_hits += 1
	if part == "head" and Game.owned("headshot"):
		die()
		return
	state = S.HURT
	_state_t = 0.0
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", -0.3, 0.08)
	tw.tween_property(body, "rotation:x", 0.0, 0.5)
	get_tree().call_group("director", "on_marta_hit", _hits)
	if _hits % 4 == 0:
		# she's had enough: away from the gate, head down, for a while
		state = S.AWAY
		_state_t = 0.0
		home_backup = home
		home = away_point

var home_backup := Vector3.ZERO

func _process(_d: float) -> void:
	if state == S.IDLE and home_backup != Vector3.ZERO:
		home = home_backup
		home_backup = Vector3.ZERO

func calm() -> void:
	super()
	_light.light_color = Color("ffc890")
	marta.head_lift = 0.0
	marta.look_target = Vector3.ZERO
	if _pressure.playing:
		_pressure.stop()

func die() -> void:
	super()
	_light.light_energy = 0.0
	marta.breathing = false
	if _pressure.playing:
		_pressure.stop()
