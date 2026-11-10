class_name Super
extends Monster
## The Super. Building 14's superintendent: an old man the height of a doorway, skin and bone and
## loose skin, naked, the top of his head gone (his body is SuperRig). He walks the stairs of the building itself, top to bottom and back, and he does
## not stop. Nothing Kurt carries puts him down: a shot staggers him (in what's left of his head,
## for longer) and that is all it does. He hears; he comes; if he gets hold of Kurt, Kurt wakes up
## on his own landing a while later. Flat 48's door is the one he doesn't come through.
##
## NEW (the owner's brief: "indestructible naked elderly Hulk sized brute with the top of his head
## blown off named The Super … roams the halls of the BUILDING ITSELF"). He says nothing.

enum Mode { WAIT, PATROL, HUNT, STAGGER, GRAB }

var building: Building
var mode := Mode.WAIT
var mode_t := 0.0
var wait_for := 20.0            ## before his first round (Kurt has only just come out onto the landing)
var last_known := Vector3.ZERO
var patrol_to := Building.HIGH
var stagger_for := 1.0
var shots_taken := 0
var catches := 0
var _step := 0.0
var _breath: AudioStreamPlayer3D

const WALK_SPEED := 0.95        ## Kurt walks at 1.5: he can always be outwalked, never outlasted
const HUNT_SPEED := 1.38
const REACH := 1.3

func _init() -> void:
	body_radius = 0.4
	body_height = 2.3
	talks = false
	sight = 16.0
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)

var rig: SuperRig

func build_body() -> void:
	rig = SuperRig.new(); rig.name = "Rig"
	body.add_child(rig)
	rig.build()
	head = Node3D.new(); head.name = "Head"
	body.add_child(head)
	_follow_head()

func _follow_head() -> void:
	if rig:
		head.global_position = rig.bone_global("head").origin + Vector3(0, 0.1, 0)

func _animate(delta: float, spd: float) -> void:
	var m := "idle"
	match mode:
		Mode.GRAB: m = "grab"
		Mode.STAGGER: m = "stagger"
		Mode.HUNT: m = "hunt"
		_: m = "walk" if spd > 0.05 else "idle"
	var look = null
	if player and mode in [Mode.HUNT, Mode.GRAB]:
		look = rig.skel.global_transform.affine_inverse() * player.camera.global_position
	rig.animate(delta, {"speed": spd, "mode": m, "look": look})
	_follow_head()
	if hit_head:
		hit_head.global_position = head.global_position

func place_at(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	home = p

func _set_mode(m: int) -> void:
	mode = m
	mode_t = 0.0

## What he can hear, he comes to: anywhere in the stairwell for a shot, a floor or so for a step.
func _on_noise(pos: Vector3, radius: float, source: String) -> void:
	if not is_inside_tree() or not can_process() or mode in [Mode.GRAB, Mode.STAGGER]:
		return
	var reach := radius * (4.0 if source == "gunshot" else 1.6)
	if global_position.distance_to(pos) <= reach:
		last_known = pos
		if mode != Mode.HUNT:
			_set_mode(Mode.HUNT)

func can_see_player() -> bool:
	if player == null or not player.can_move:
		return false
	var eye := global_position + Vector3(0, 2.15, 0)
	var to := player.camera.global_position - eye
	var d := to.length()
	if d > sight:
		return false
	if d > 2.5 and (-global_transform.basis.z).dot(to.normalized()) < 0.1:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, player.camera.global_position, 1, [player.get_rid(), get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(delta: float) -> void:
	_t += delta
	mode_t += delta
	if _breath == null:
		_breath = Sfx.loop_at("breath", global_position, -9.0, 0.62)
	_breath.global_position = global_position + Vector3(0, 2.0, 0)
	var to := Vector3.INF
	var spd := WALK_SPEED
	var sees := mode != Mode.GRAB and can_see_player()
	if sees:
		last_known = player.global_position
	match mode:
		Mode.WAIT:
			if sees:
				_set_mode(Mode.HUNT)
			elif mode_t > wait_for:
				_set_mode(Mode.PATROL)
		Mode.PATROL:
			to = building.landing_point(patrol_to)
			if global_position.distance_to(to) < 0.7:
				patrol_to = Building.LOW if patrol_to == Building.HIGH else Building.HIGH
				wait_for = 4.0
				_set_mode(Mode.WAIT)
			if sees:
				_set_mode(Mode.HUNT)
		Mode.HUNT:
			to = last_known
			spd = HUNT_SPEED
			if sees:
				mode_t = 0.0
			var d := player.global_position - global_position
			if player.can_move and Vector2(d.x, d.z).length() < REACH and absf(d.y) < 1.0:
				_set_mode(Mode.GRAB)
				catches += 1
				caught.emit(self)
			elif not sees and (mode_t > 14.0 or (global_position.distance_to(last_known) < 0.9 and mode_t > 3.0)):
				wait_for = 3.0
				_set_mode(Mode.WAIT)
		Mode.STAGGER:
			if mode_t > stagger_for:
				_set_mode(Mode.HUNT)
		Mode.GRAB:
			pass
	_walk_to(to, spd, delta)

func _walk_to(to: Vector3, spd: float, delta: float) -> void:
	var v := Vector3.ZERO
	if to != Vector3.INF:
		var step := building.next_step(global_position, to)
		var d := _flat(step) - _flat(global_position)
		if d.length() > 0.15:
			v = d.normalized() * spd
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(delta * 3.5, 1.0))
	velocity.x = move_toward(velocity.x, v.x, delta * 4.0)
	velocity.z = move_toward(velocity.z, v.z, delta * 4.0)
	velocity.y = -0.2 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var moved := Vector2(velocity.x, velocity.z).length()
	# his weight on the stairs: you hear which floor he's on before you see him
	_step += moved * delta
	if _step > 0.95:              # (the rig's stride: a foot down every 0.95 m)
		_step = 0.0
		Sfx.play_at("thud", global_position, 1.0, randf_range(0.5, 0.58)).max_distance = 40.0
		if player and player.global_position.distance_to(global_position) < 5.0:
			player.shake(0.012, 0.15)
	state = S.GRAB if mode == Mode.GRAB else (S.HURT if mode == Mode.STAGGER else (S.CHASE if mode == Mode.HUNT else S.IDLE))
	_animate(delta, moved)

## Bullets: he feels them. That's all.
func shot(part: String) -> void:
	if mode == Mode.GRAB:
		return
	shots_taken += 1
	stagger_for = 2.4 if part == "head" else 0.9
	if player:
		last_known = player.global_position
		rig.flinch((global_position - player.global_position).normalized(), 1.6 if part == "head" else 0.9, part == "head")
	Sfx.play_at("thud", global_position + Vector3(0, 1.6, 0), -4.0, 1.3)
	_set_mode(Mode.STAGGER)

func die() -> void:
	pass

func calm() -> void:
	pass

## After he's had hold of Kurt: off to one end of the building, and a while before he starts again.
func send_away(from_floor: int) -> void:
	var f := Building.LOW if from_floor >= 4 else Building.HIGH
	place_at(building.landing_point(f))
	patrol_to = Building.HIGH if f == Building.LOW else Building.LOW
	wait_for = 25.0
	_set_mode(Mode.WAIT)
