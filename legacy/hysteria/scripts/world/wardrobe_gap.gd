class_name WardrobeGap
extends Node
## The wardrobe in the room he wakes up in (owner: "the wardrobe in the room you wake up in"), and
## what's behind it. It stood in front of the box room door; it's been pushed along the same wall,
## to where the wall backs onto Sonya's room. Use it from anywhere you can see it: Kurt steps to its
## end, sets his shoulder to it, and it grinds along the wall in three shoves, loud enough to hear
## through the flat. Behind it the plaster has been knocked through, low down, ragged. Sonya's room
## is on the other side of that wall; the hole doesn't go into Sonya's room. It goes into the dark,
## and the dark goes on. Squeeze through (use) and you're in the labyrinth; come back the same way.

const PROP := "prop_34_Wardrobe"
const AT := Vector3(3.35, 0.0, 4.84)             # where it stands now: its middle (it faces into the room, -z)
const WALL_Z := 5.13                              # the face of the wall behind it
const SLIDE := -0.62                              # along the wall toward the box room (it stops short of its door)
const SIDE_SPOT := Vector3(4.12, 0.0, 4.8)        # its free end, between it and the hall door
const HOLE_MIN := Vector3(3.27, 0.04, 5.04)
const HOLE_MAX := Vector3(3.83, 1.8, 5.36)
const BACK_TO := Vector3(3.55, 0.0, 4.5)          # coming back: in front of the hole, facing into the room

var world: Node3D
var player: Node
var main: Node
var pivot: Node3D
var body: AnimatableBody3D
var pushed := false
var gap: StaticBody3D
var _t := -1.0
var _approaching := false

func setup(p_world: Node3D, p_player: Node, p_main: Node) -> void:
	world = p_world; player = p_player; main = p_main
	RenderingServer.global_shader_parameter_set("hole_min", Vector4(HOLE_MIN.x, HOLE_MIN.y, HOLE_MIN.z, 0.0))
	RenderingServer.global_shader_parameter_set("hole_max", Vector4(HOLE_MAX.x, HOLE_MAX.y, HOLE_MAX.z, 0.0))
	_gather()

## The wardrobe was a loose (heavy) prop: its model goes under one pivot here, at its new place, with
## a body that moves, and the prop body goes.
func _gather() -> void:
	pivot = Node3D.new(); pivot.name = "Wardrobe"
	world.add_child(pivot); pivot.position = AT
	var n := 0
	var model: Node3D = world.find_child(PROP, true, false)
	var old_body: Node = model.get_parent() if model and model.get_parent() is RigidBody3D else null
	if model:
		var rot := model.global_basis
		model.reparent(pivot, false)
		model.transform = Transform3D(rot, Vector3.ZERO)
		n = model.find_children("*", "MeshInstance3D", true, false).size()
	if old_body: old_body.queue_free()
	body = AnimatableBody3D.new(); body.name = "WardrobeBody"; body.sync_to_physics = false; body.set_script(load("res://scripts/world/wardrobe_body.gd"))
	body.set("gap", self)
	pivot.add_child(body)
	var shape := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(1.0, 1.9, 0.59)
	shape.shape = b; shape.position = Vector3(0, 0.95, -0.025)
	body.add_child(shape)
	if OS.is_debug_build(): print("wardrobe: ", n, " meshes")

## From close beside its free end, it moves; from anywhere else he steps there first.
func can_push() -> bool:
	if pushed or _t >= 0.0: return false
	var p: Vector3 = player.global_position
	return Vector2(p.x - SIDE_SPOT.x, p.z - SIDE_SPOT.z).length() < 0.45

func approach_and_push() -> void:
	if pushed or _t >= 0.0 or _approaching: return
	_approaching = true
	player.set("locked", true)
	var a: Vector3 = player.global_position
	var to := Vector3(SIDE_SPOT.x, a.y, SIDE_SPOT.z)
	var dur := clampf(a.distance_to(to) / 2.0, 0.2, 0.9)
	player.set("look_target", Vector3(AT.x + 0.5, 1.15, AT.z))
	var t := 0.0
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		player.global_position = a.lerp(to, smoothstep(0.0, 1.0, t / dur))
	_approaching = false
	player.set("locked", false)
	push()

func push() -> void:
	if main.get("crash"): main.crash.note("pushing the wardrobe")
	if not can_push(): return
	_t = 0.0
	player.set("locked", true)
	player.set("look_target", Vector3(AT.x + 0.5, 1.15, AT.z))
	_scrape()
	Noises.make(get_tree(), AT + Vector3(0, 1.0, 0), 0.75, "scrape", player)

## Three shoves: each one he leans in (a jolt), it gives a little more; between them, the grind.
func _process(delta: float) -> void:
	if _t < 0.0: return
	_t += delta
	var u := clampf(_t / 2.1, 0.0, 1.0)
	var shove := (sin(u * PI * 3.0 - PI * 0.5) * 0.5 + 0.5)
	var slide := (u - sin(u * TAU * 1.5) / (TAU * 1.5)) * SLIDE            # steps along, in three surges
	pivot.position = AT + Vector3(slide, 0, 0)
	player.set("shake", 0.12 + 0.25 * shove)
	# he moves with it, a step behind its end
	var spot: Vector3 = Vector3(SIDE_SPOT.x + slide, player.global_position.y, SIDE_SPOT.z)
	player.global_position = player.global_position.lerp(spot, 1.0 - exp(-delta * 6.0))
	player.set("look_target", Vector3(AT.x + 0.5 + slide, 1.15, AT.z))
	if u >= 1.0:
		_t = -1.0; pushed = true
		player.set("locked", false); player.set("look_target", null)
		Game.flags["wardrobe_pushed"] = true
		_open_hole()
		if main.get("crash"): main.crash.note("wardrobe aside, hole open")

## Loading a save: already pushed aside, the hole already there.
func restore_pushed() -> void:
	if pushed: return
	pushed = true; _t = -1.0
	pivot.position = AT + Vector3(SLIDE, 0, 0)
	_open_hole()

## The hole: the plaster cut away (the PS1 shader's wall-hole box), broken brick at its edge,
## rubble on the floor, and in it a black that the torch doesn't find the end of.
func _open_hole() -> void:
	RenderingServer.global_shader_parameter_set("hole_min", Vector4(HOLE_MIN.x, HOLE_MIN.y, HOLE_MIN.z, 1.0))
	RenderingServer.global_shader_parameter_set("hole_max", Vector4(HOLE_MAX.x, HOLE_MAX.y, HOLE_MAX.z, 1.0))
	var kit := TownKit.new(world)
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	var f := Facades.Frame.new(Vector3(HOLE_MIN.x, 0, WALL_Z - 0.01), Vector3(1, 0, 0), Vector3(0, 0, -1))   # facing into the room
	Facades.ragged_rim(kit, f, 0.0, HOLE_MAX.x - HOLE_MIN.x, 0.04, 1.76, "stucco_cream", rng, 38)
	for i in 14:      # what came out of the wall, on the floor
		var p := Vector3(HOLE_MIN.x + rng.randf() * 0.6, 0.0, WALL_Z - 0.08 - rng.randf() * 0.45)
		var s := rng.randf_range(0.02, 0.07)
		kit.box("brick" if rng.randf() < 0.5 else "stucco_cream", p + Vector3(0, s * 0.5, 0), Vector3(s, s * 0.5, s * 0.8), Basis(Vector3.UP, rng.randf() * TAU))
	kit.finish()
	var black := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(HOLE_MAX.x - HOLE_MIN.x + 0.04, 1.8, 0.04); black.mesh = bx
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color.BLACK
	black.material_override = bm; world.add_child(black)
	black.position = Vector3((HOLE_MIN.x + HOLE_MAX.x) * 0.5, 0.92, WALL_Z + 0.07)
	# the way through
	gap = StaticBody3D.new(); gap.name = "Gap"; gap.set_script(load("res://scripts/world/gap_way.gd"))
	gap.set("gap", self); gap.set("inward", true)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(HOLE_MAX.x - HOLE_MIN.x, 1.7, 0.14)
	cs.shape = b; gap.add_child(cs); world.add_child(gap); gap.position = Vector3((HOLE_MIN.x + HOLE_MAX.x) * 0.5, 0.9, WALL_Z - 0.02)
	gap.collision_layer = 1

func go_through(inward: bool) -> void:
	player.set("locked", true)
	Game.fade.emit(1.0, 0.45)
	await get_tree().create_timer(0.55).timeout
	# what he's carrying comes through with him: kept where it is relative to his hand
	var held: RigidBody3D = player.get("held")
	var rel := Transform3D()
	if held: rel = (player.get("hold") as Node3D).global_transform.affine_inverse() * held.global_transform
	if inward:
		if main.get("crash"): main.crash.note("through the gap")
		main.call("enter_labyrinth")
	else:
		main.call("leave_labyrinth", Transform3D(Basis(), BACK_TO))
	player.set("crouched", false)
	if held and is_instance_valid(held):
		held.global_transform = (player.get("hold") as Node3D).global_transform * rel
		held.linear_velocity = Vector3.ZERO
		# the prop now belongs to the place he's in, so it hides and shows with it
		var home: Node = main.labyrinth if inward else world
		if held.get_parent() != home: held.reparent(home)
	await get_tree().create_timer(0.15).timeout
	player.set("locked", false)
	Game.fade.emit(0.0, 0.7)

# ---------------------------------------------------------------- the sound of it
func _scrape() -> void:
	const RATE := 22050
	var n := int(RATE * 2.8)
	var s := PackedFloat32Array(); s.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var lp := 0.0; var judder := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / 2.8
		judder = 0.5 + 0.5 * sin(t * TAU * (9.0 + 5.0 * sin(t * 3.0)))           # wood juddering on boards
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		var env := smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.85, 1.0, u)) * (0.4 + 0.6 * judder)
		var groan := sin(t * TAU * (55.0 + 8.0 * sin(t * 1.7))) * 0.25 * smoothstep(0.3, 0.5, u)
		s[i] = (lp * 1.6 + groan) * env * 0.7
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	for i in n: bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	var ap := AudioStreamPlayer3D.new(); ap.stream = w; ap.unit_size = 4.0
	world.add_child(ap); ap.global_position = AT + Vector3(0, 1.0, 0); ap.play()
	ap.finished.connect(ap.queue_free)
