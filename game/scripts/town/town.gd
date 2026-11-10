class_name Town
extends Labyrinth
## The town behind the wardrobe: the first build's labyrinth (Kerzhansk under the Romanovs, at
## night: the main street that goes on for ever, the square with the fight stopped in mid-air, the
## photographer's salon, the hotel room, the nursery izba, the chapel plaza), plus what this
## chapter needs: a gate south out of the plaza (the only way out) with a lever beside it, the
## revolver lying in the frozen fight, rounds, loose cobbles, nuggets, and a grid the monsters
## find their way round by. Local coordinates (the node sits far from the flat).

const LOOP := PERIOD * CELL
const GATE_Z := 68.0
const GATE_X0 := 40.0
const GATE_X1 := 44.0

var revolver_at := Vector3.ZERO
var revolver_mesh: Node3D
var revolver_spot: Hotspot
var marta_post := Vector3(42.0, 0, 66.2)
var marta_away := Vector3(30.0, 0, 58.0)
var gate: Node3D
var gate_body: StaticBody3D
var gate_open := false
var lever: Node3D
var lever_spot: Hotspot
var chalk: Array[Node3D] = []
var pickups: Array = []
var nuggets: Array[Node3D] = []
var nursery := Rect2(6.2, 59.6, 5.6, 4.8)
var nursery_center := Vector3(9.0, 1.2, 62.0)
var porter_home := Vector3(57.4, 0.45, 40.4)
var lamplighter_path: Array[Vector3] = [Vector3(8.0, 0, 20.4), Vector3(52.0, 0, 19.6)]

func build() -> void:
	super.build()
	revolver_at = fight.gun_at.origin
	_revolver()
	_gate()
	_chalk()
	_pickups()

# --- the revolver, where the fight stopped --------------------------------------------------------

func _revolver() -> void:
	revolver_mesh = Weapon.make_gun_model()
	add_child(revolver_mesh)
	revolver_mesh.transform = fight.gun_at
	revolver_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), revolver_at + Vector3(0, 0.12, 0)), Vector3(0.5, 0.35, 0.5), "Take")

# --- the gate ---------------------------------------------------------------------------------------

func _gate() -> void:
	# the lane beyond it ends in white
	var white := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(4.2, 9.0); white.mesh = qm
	var wm := StandardMaterial3D.new(); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = Color(1.4, 1.4, 1.45); wm.disable_fog = true
	white.material_override = wm
	add_child(white)
	white.position = Vector3((GATE_X0 + GATE_X1) * 0.5, 4.5, 75.8)
	white.rotation.y = PI
	var glow := OmniLight3D.new(); glow.light_color = Color(0.9, 0.93, 1.0); glow.light_energy = 1.2
	glow.omni_range = 6.0; glow.shadow_enabled = false
	add_child(glow); glow.position = Vector3(42, 2.5, 74.5)
	# two leaves of iron bars, pillars, a lever on the right-hand pillar (seen from the plaza)
	gate = Node3D.new(); gate.name = "Gate"; add_child(gate)
	gate.position = Vector3(GATE_X0, 0, GATE_Z)
	var iron := kit.material("iron")
	var gold := kit.material("gold")
	for leaf_i in 2:
		var leaf := Node3D.new(); leaf.name = "Leaf%d" % leaf_i
		gate.add_child(leaf)
		leaf.position = Vector3(0.0 if leaf_i == 0 else GATE_X1 - GATE_X0, 0, 0)
		var dirx := 1.0 if leaf_i == 0 else -1.0
		for i in 9:
			var bar := MeshInstance3D.new(); var bm := CylinderMesh.new()
			bm.top_radius = 0.018; bm.bottom_radius = 0.018; bm.height = 3.2; bm.radial_segments = 6
			bar.mesh = bm; bar.material_override = iron
			bar.position = Vector3(dirx * (0.12 + i * 0.22), 1.75, 0)
			leaf.add_child(bar)
			var tip := MeshInstance3D.new(); var tm := PrismMesh.new(); tm.size = Vector3(0.06, 0.12, 0.03)
			tip.mesh = tm; tip.material_override = gold
			tip.position = Vector3(dirx * (0.12 + i * 0.22), 3.4, 0)
			leaf.add_child(tip)
		for y in [0.25, 1.6, 3.05]:
			var rail := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(2.0, 0.05, 0.05)
			rail.mesh = rm; rail.material_override = iron
			rail.position = Vector3(dirx * 1.0, y, 0)
			leaf.add_child(rail)
	gate_body = StaticBody3D.new(); gate.add_child(gate_body)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(GATE_X1 - GATE_X0, 4.0, 0.3)
	cs.shape = bs; cs.position = Vector3((GATE_X1 - GATE_X0) * 0.5, 2.0, 0)
	gate_body.add_child(cs)
	# the lever: an iron arm on a plate, on the plaza face of the building right of the gate
	lever = Node3D.new(); lever.name = "Lever"; add_child(lever)
	lever.position = Vector3(GATE_X1 + 0.7, 1.25, GATE_Z - 0.06)
	var plate := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.22, 0.34, 0.03)
	plate.mesh = pb; plate.material_override = iron
	lever.add_child(plate)
	var arm := MeshInstance3D.new(); var ab := BoxMesh.new(); ab.size = Vector3(0.04, 0.42, 0.04)
	arm.mesh = ab; arm.material_override = iron; arm.position = Vector3(0, 0.16, -0.06); arm.rotation.z = -0.5; arm.name = "Arm"
	lever.add_child(arm)
	var knob := MeshInstance3D.new(); var kb := SphereMesh.new(); kb.radius = 0.035; kb.height = 0.07
	knob.mesh = kb; knob.material_override = gold; knob.position = Vector3(0.1, 0.35, -0.06)
	lever.add_child(knob)
	lever_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), lever.position + Vector3(0, 0.1, -0.25)), Vector3(0.6, 0.8, 0.5), "Pull")

func open_gate() -> void:
	gate_open = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gate.get_node("Leaf0"), "rotation:y", deg_to_rad(100), 3.0)
	tw.tween_property(gate.get_node("Leaf1"), "rotation:y", deg_to_rad(-100), 3.0)
	tw.tween_property(lever.get_node("Arm"), "rotation:z", 0.5, 0.4)
	gate_body.queue_free()
	Sfx.play_at("creak", to_global(Vector3(42, 1.5, GATE_Z)), 4.0, 0.7)

# --- These Streets: the chalk circle where the street comes round ----------------------------------

func _chalk() -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.92, 0.92, 0.88)
	m.emission_enabled = true; m.emission = Color(0.25, 0.25, 0.25)
	for x in [CELL * 1.0, CELL * (PERIOD + 1)]:
		var ring := Node3D.new(); add_child(ring)
		ring.position = Vector3(x + 0.6, 0.006, 20.0)
		for i in 16:
			var a := TAU * i / 16.0
			var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.24, 0.004, 0.05)
			mi.mesh = bm; mi.material_override = m
			mi.position = Vector3(cos(a), 0, sin(a)) * 0.75
			mi.rotation.y = -a + PI * 0.5
			ring.add_child(mi)
		for s in [-1.0, 1.0]:
			var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.7, 0.004, 0.05)
			mi.mesh = bm; mi.material_override = m; mi.rotation.y = PI * 0.25 * s
			ring.add_child(mi)
		ring.visible = false
		chalk.append(ring)

# --- things to take ---------------------------------------------------------------------------------

func _pickups() -> void:
	for p in [Vector3(55.6, 0.47, 35.3), Vector3(21.2, 0.47, 29.7), Vector3(33.4, 0.13, 33.4)]:
		_pickup(p, "ammo", Vector3(0.14, 0.07, 0.09))
	for p in [Vector3(34.6, 0.0, 46.4), Vector3(49.4, 0.0, 33.6), Vector3(29.6, 0.0, 66.4), Vector3(54.2, 0.0, 57.6), Vector3(39.0, 0.0, 61.0), Vector3(7.2, 0.13, 16.9)]:
		_pickup(p, "rock", Vector3(0.1, 0.07, 0.11))
	for p in [Vector3(10.0, 0.6, 18.2), Vector3(30.0, 0.6, 22.0), Vector3(50.0, 0.6, 17.6), Vector3(26.0, 0.6, 10.0),
			Vector3(35.0, 0.6, 34.0), Vector3(49.0, 0.6, 46.0), Vector3(53.4, 1.05, 35.4), Vector3(15.0, 1.05, 29.6),
			Vector3(7.6, 0.95, 63.6), Vector3(30.5, 0.6, 59.5), Vector3(53.5, 0.6, 66.0), Vector3(18.0, 0.6, 62.0)]:
		var n := Nugget.new()
		add_child(n)
		n.position = p
		nuggets.append(n)

func _pickup(p: Vector3, kind: String, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = kit.material("brick" if kind == "rock" else "leather")
	add_child(mi)
	mi.position = p + Vector3(0, size.y * 0.5, 0)
	mi.rotation.y = randf() * TAU
	var h := Hotspot.make(self, global_transform * Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(0.5, 0.4, 0.5), "Take")
	h.set_meta("mesh", mi)
	pickups.append([h, kind])

# --- finding the way: the town is a 4 m grid -----------------------------------------------------

func cell_of(local: Vector3) -> Vector2i:
	return Vector2i(floori(local.x / CELL), floori(local.z / CELL))

## The next point to head for, walking the street grid from `from` toward `to` (local space).
## Straight there if they're in the same cell, or either isn't on the street.
func next_step(from: Vector3, to: Vector3) -> Vector3:
	var a := cell_of(from)
	var b := cell_of(to)
	if a == b or not is_street(a.x, a.y) or not is_street(b.x, b.y):
		return to
	var prev := {a: a}
	var q: Array[Vector2i] = [a]
	var found := false
	while not q.is_empty() and prev.size() < 400:
		var c: Vector2i = q.pop_front()
		if c == b:
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not prev.has(n) and n.x >= 0 and n.x < 18 and n.y >= 0 and n.y < MAP.size() and String(MAP[n.y])[n.x] != "#":
				prev[n] = c
				q.append(n)
	if not found:
		return to
	var step := b
	while prev[step] != a:
		step = prev[step]
	if step == b:
		return to
	return center(step.x, step.y)
