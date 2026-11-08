class_name WardrobeGap
extends Node
## The bedroom wardrobe, and what's behind it. Come at it from the side (the door side, between
## it and the bedroom door) and use it: Kurt puts his shoulder to it and it grinds along the
## kitchen wall and swings out, loud enough to hear through the flat. Behind it the plaster has
## been knocked through, low down, ragged. The kitchen is on the other side of that wall; the
## hole doesn't go into the kitchen. It goes into the dark, and the dark goes on.
## Squeeze through (use) and you're in the labyrinth; come back the same way.

const WARDROBE_BOX := AABB(Vector3(6.3, -0.05, 0.22), Vector3(1.3, 2.2, 1.36))   # its parts, in the flat
const PIVOT := Vector3(7.53, 0.0, 0.3)          # its back corner by the window
const SLIDE := -0.12                            # along the wall toward the window, first
const SWING := 0.95                             # then it swings out, its far end dragged away from the wall (radians)
const HOLE_MIN := Vector3(7.44, 0.04, 0.92)
const HOLE_MAX := Vector3(7.585, 1.82, 1.58)

var world: Node3D
var player: Node
var main: Node
var pivot: Node3D
var body: AnimatableBody3D
var pushed := false
var gap: StaticBody3D
var _t := -1.0

func setup(p_world: Node3D, p_player: Node, p_main: Node) -> void:
	world = p_world; player = p_player; main = p_main
	RenderingServer.global_shader_parameter_set("hole_min", Vector4(HOLE_MIN.x, HOLE_MIN.y, HOLE_MIN.z, 0.0))
	RenderingServer.global_shader_parameter_set("hole_max", Vector4(HOLE_MAX.x, HOLE_MAX.y, HOLE_MAX.z, 0.0))
	_gather()

## The wardrobe is baked into the flat's model: collect the meshes that make it up (its carcass,
## doors, hangers, the clothes left on them) under one pivot, and give it a body that moves.
func _gather() -> void:
	pivot = Node3D.new(); pivot.name = "Wardrobe"
	world.add_child(pivot); pivot.position = PIVOT
	var n := 0
	for mi in world.get_node("Apartment").find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() < 2.6 and WARDROBE_BOX.has_point(a.get_center()) and a.get_center().y > 0.04:
			m.reparent(pivot, true); n += 1
	# its collision: the flat's static box for it goes, a moving one takes its place
	for cs in world.find_child("Collision", false, false).get_children():
		if cs is CollisionShape3D and Vector2(cs.position.x - 7.23, cs.position.z - 0.9).length() < 0.05:
			cs.queue_free()
	body = AnimatableBody3D.new(); body.name = "WardrobeBody"; body.sync_to_physics = false; body.set_script(load("res://scripts/world/wardrobe_body.gd"))
	body.set("gap", self)
	pivot.add_child(body)
	var shape := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.6, 2.0, 1.2)
	shape.shape = b; shape.position = Vector3(7.23, 1.0, 0.9) - PIVOT
	body.add_child(shape)
	if OS.is_debug_build(): print("wardrobe: ", n, " meshes")

## Who can push it: someone standing at its side, between it and the bedroom door.
func can_push() -> bool:
	if pushed or _t >= 0.0: return false
	var p: Vector3 = player.global_position
	return p.z > 1.45 and p.z < 2.6 and p.x > 6.55 and p.x < 7.55

func push() -> void:
	if not can_push(): return
	_t = 0.0
	player.set("locked", true)
	player.set("look_target", Vector3(7.25, 1.1, 0.9))
	_scrape()
	Noises.make(get_tree(), Vector3(7.2, 1.0, 1.0), 0.75, "scrape", player)

func _process(delta: float) -> void:
	if _t < 0.0: return
	_t += delta
	var u := clampf(_t / 2.8, 0.0, 1.0)
	# it sticks, gives, grinds; a slide first, then the swing (the far end comes away from the wall)
	var slide := smoothstep(0.0, 0.35, u) * SLIDE
	var swing := smoothstep(0.3, 1.0, u) * SWING
	pivot.transform = Transform3D(Basis(Vector3.UP, -swing), PIVOT + Vector3(0, 0, slide))
	player.set("shake", 0.25 + 0.2 * sin(_t * 23.0))
	if u >= 1.0:
		_t = -1.0; pushed = true
		player.set("locked", false); player.set("look_target", null)
		Game.flags["wardrobe_pushed"] = true
		_open_hole()

## Loading a save: already pushed aside, the hole already there.
func restore_pushed() -> void:
	if pushed: return
	pushed = true; _t = -1.0
	pivot.transform = Transform3D(Basis(Vector3.UP, -SWING), PIVOT + Vector3(0, 0, SLIDE))
	_open_hole()

## The hole: the plaster cut away (the PS1 shader's wall-hole box), broken brick at its edge,
## rubble on the floor, and behind it a black that the torch doesn't find the end of.
func _open_hole() -> void:
	RenderingServer.global_shader_parameter_set("hole_min", Vector4(HOLE_MIN.x, HOLE_MIN.y, HOLE_MIN.z, 1.0))
	RenderingServer.global_shader_parameter_set("hole_max", Vector4(HOLE_MAX.x, HOLE_MAX.y, HOLE_MAX.z, 1.0))
	var kit := TownKit.new(world)
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	var f := Facades.Frame.new(Vector3(7.53, 0, 1.6), Vector3(0, 0, -1), Vector3(-1, 0, 0))   # facing into the bedroom
	Facades.ragged_rim(kit, f, 0.02, 0.66, 0.04, 1.8, "stucco_cream", rng, 38)
	for i in 14:      # what came out of the wall, on the floor
		var p := Vector3(7.45 - rng.randf() * 0.5, 0.0, 1.0 + rng.randf() * 0.6)
		var s := rng.randf_range(0.02, 0.07)
		kit.box("brick" if rng.randf() < 0.5 else "stucco_cream", p + Vector3(0, s * 0.5, 0), Vector3(s, s * 0.5, s * 0.8), Basis(Vector3.UP, rng.randf() * TAU))
	kit.finish()
	var black := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.75, 1.85); black.mesh = qm
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color.BLACK
	black.material_override = bm; world.add_child(black)
	black.position = Vector3(7.6, 0.93, 1.25); black.rotation.y = -PI * 0.5
	# the way through
	gap = StaticBody3D.new(); gap.name = "Gap"; gap.set_script(load("res://scripts/world/gap_way.gd"))
	gap.set("gap", self); gap.set("inward", true)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.12, 1.7, 0.6)
	cs.shape = b; gap.add_child(cs); world.add_child(gap); gap.position = Vector3(7.5, 0.9, 1.25)
	gap.collision_layer = 1

func go_through(inward: bool) -> void:
	player.set("locked", true)
	Game.fade.emit(1.0, 0.45)
	await get_tree().create_timer(0.55).timeout
	if inward:
		main.call("enter_labyrinth")
	else:
		main.call("leave_labyrinth", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(7.05, 0, 1.25)))
	player.set("crouched", false)
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
	world.add_child(ap); ap.global_position = Vector3(7.2, 1.0, 0.9); ap.play()
	ap.finished.connect(ap.queue_free)
