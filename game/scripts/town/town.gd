class_name Town
extends Labyrinth
## The town behind the wardrobe: the first build's labyrinth (Kerzhansk under the Romanovs, at
## night: the main street that goes on for ever, the square with the fight stopped in mid-air, the
## photographer's salon, the hotel room, the nursery izba, the chapel plaza), plus what this
## chapter needs: a gate south out of the plaza (the only way out) with a lever beside it, the
## revolver lying in the frozen fight, rounds, loose cobbles, nuggets, and a grid the monsters
## find their way round by. Local coordinates (the node sits far from the flat).
##
## How it stays up on a phone (the town used to close itself a few seconds in, always at the
## same spot, just after the first nugget):
##   - It is built a slice per frame behind the black (build_async), never in one long frame.
##   - Before the black lifts, every part of it is drawn once from a set of views (prewarm_views,
##     driven by TownChapter.prewarm), so every shader and every light combination is compiled
##     while nobody is looking, and nothing is drawn for the first time mid-walk.
##   - Lit lamps are a fixed budget, the nearest few, re-chosen four times a second: no mesh is
##     ever touched by more lights than the renderer is comfortable with, wherever he stands.
##   - Monsters find their way with a table worked out once at build (no searching per frame).
##   - Pickups are inert: taking one hides it; nothing is created, tweened or freed.

const LOOP := PERIOD * CELL
const GATE_Z := 68.0
const GATE_X0 := 40.0
const GATE_X1 := 44.0

## Lamps lit at once (and how far off one may be): a phone keeps every mesh under 8 lights.
const LAMPS_PHONE := 5
const LAMPS_DESKTOP := 12
const LAMP_RANGE_PHONE := 22.0
const LAMP_RANGE_DESKTOP := 30.0
const LIGHT_EVERY := 0.25

var revolver_at := Vector3.ZERO
var revolver_mesh: Node3D
var revolver_spot: Hotspot
var marta_post := Vector3(42.0, 0, 66.2)
var marta_away := Vector3(30.0, 0, 58.0)
var gate: Node3D
var gate_body: StaticBody3D
var gate_open := false
var gate_glow: OmniLight3D
var lever: Node3D
var lever_spot: Hotspot
var chalk: Array[Node3D] = []
var pickups: Array = []
var nuggets: Array[Node3D] = []
var nursery := Rect2(6.2, 59.6, 5.6, 4.8)
var nursery_center := Vector3(9.0, 1.2, 62.0)
var porter_home := Vector3(57.4, 0.45, 40.4)
var lamplighter_path: Array[Vector3] = [Vector3(8.0, 0, 20.4), Vector3(52.0, 0, 19.6)]
var built := false

var _t := 0.0
var _light_t := 0.0
var _lit: Array[OmniLight3D] = []
var _hop := PackedInt32Array()       ## [from cell * N + to cell] -> the next cell on the way, or -1
const _W := 16                       ## the map's width in cells

# --- building ---------------------------------------------------------------------------------------

func build_steps() -> Array[Callable]:
	var steps := super.build_steps()
	steps.append(func():
		revolver_at = fight.gun_at.origin
		_revolver()
		_gate()
		return true)
	steps.append(func():
		_chalk()
		_pickups()
		return true)
	steps.append(func():
		_route_table()
		built = true
		return true)
	return steps

## Builds the town a step a frame (the owner awaits this, behind the black).
func build_async() -> void:
	var steps := build_steps()
	var i := 0
	for step in steps:
		i += 1
		while not (step as Callable).call():
			await get_tree().process_frame
		if i % 6 == 0:
			Trail.mark("town: built %d/%d" % [i, steps.size()])
		await get_tree().process_frame

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
	gate_glow = OmniLight3D.new(); gate_glow.light_color = Color(0.9, 0.93, 1.0); gate_glow.light_energy = 1.2
	gate_glow.omni_range = 6.0; gate_glow.shadow_enabled = false
	add_child(gate_glow); gate_glow.position = Vector3(42, 2.5, 74.5)
	# two leaves of iron bars, pillars, a lever on the right-hand pillar (seen from the plaza)
	gate = Node3D.new(); gate.name = "Gate"; add_child(gate)
	gate.position = Vector3(GATE_X0, 0, GATE_Z)
	var iron := kit.material("iron")
	var gold := kit.material("gold")
	# one bar mesh, one tip mesh, one rail mesh, shared by every bar, tip and rail
	var bm := CylinderMesh.new()
	bm.top_radius = 0.018; bm.bottom_radius = 0.018; bm.height = 3.2; bm.radial_segments = 6
	var tm := PrismMesh.new(); tm.size = Vector3(0.06, 0.12, 0.03)
	var rm := BoxMesh.new(); rm.size = Vector3(2.0, 0.05, 0.05)
	for leaf_i in 2:
		var leaf := Node3D.new(); leaf.name = "Leaf%d" % leaf_i
		gate.add_child(leaf)
		leaf.position = Vector3(0.0 if leaf_i == 0 else GATE_X1 - GATE_X0, 0, 0)
		var dirx := 1.0 if leaf_i == 0 else -1.0
		for i in 9:
			var bar := MeshInstance3D.new()
			bar.mesh = bm; bar.material_override = iron
			bar.position = Vector3(dirx * (0.12 + i * 0.22), 1.75, 0)
			leaf.add_child(bar)
			var tip := MeshInstance3D.new()
			tip.mesh = tm; tip.material_override = gold
			tip.position = Vector3(dirx * (0.12 + i * 0.22), 3.4, 0)
			leaf.add_child(tip)
		for y in [0.25, 1.6, 3.05]:
			var rail := MeshInstance3D.new()
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
	if gate_open:
		return
	gate_open = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gate.get_node("Leaf0"), "rotation:y", deg_to_rad(100), 3.0)
	tw.tween_property(gate.get_node("Leaf1"), "rotation:y", deg_to_rad(-100), 3.0)
	tw.tween_property(lever.get_node("Arm"), "rotation:z", 0.5, 0.4)
	# the bars stop being in the way: switched off, not freed mid-physics-step
	gate_body.collision_layer = 0
	gate_body.process_mode = Node.PROCESS_MODE_DISABLED
	Sfx.play_at("creak", to_global(Vector3(42, 1.5, GATE_Z)), 4.0, 0.7)

# --- These Streets: the chalk circle where the street comes round ----------------------------------

func _chalk() -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.92, 0.92, 0.88)
	m.emission_enabled = true; m.emission = Color(0.25, 0.25, 0.25)
	var dash := BoxMesh.new(); dash.size = Vector3(0.24, 0.004, 0.05)
	var cross := BoxMesh.new(); cross.size = Vector3(1.7, 0.004, 0.05)
	for x in [CELL * 1.0, CELL * (PERIOD + 1)]:
		var ring := Node3D.new(); add_child(ring)
		ring.position = Vector3(x + 0.6, 0.006, 20.0)
		for i in 16:
			var a := TAU * i / 16.0
			var mi := MeshInstance3D.new()
			mi.mesh = dash; mi.material_override = m
			mi.position = Vector3(cos(a), 0, sin(a)) * 0.75
			mi.rotation.y = -a + PI * 0.5
			ring.add_child(mi)
		for s in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.mesh = cross; mi.material_override = m; mi.rotation.y = PI * 0.25 * s
			ring.add_child(mi)
		ring.visible = false
		chalk.append(ring)

func show_chalk(on: bool) -> void:
	for c in chalk:
		if c.visible != on:
			c.visible = on

# --- things to take ---------------------------------------------------------------------------------

const NUGGETS_AT := [Vector3(10.0, 0.6, 18.2), Vector3(30.0, 0.6, 22.0), Vector3(50.0, 0.6, 17.6), Vector3(26.0, 0.6, 10.0),
	Vector3(35.0, 0.6, 34.0), Vector3(49.0, 0.6, 46.0), Vector3(53.4, 1.05, 35.4), Vector3(15.0, 1.05, 29.6),
	Vector3(7.6, 0.95, 63.6), Vector3(30.5, 0.6, 59.5), Vector3(53.5, 0.6, 66.0), Vector3(18.0, 0.6, 62.0)]

func _pickups() -> void:
	var ammo := BoxMesh.new(); ammo.size = Vector3(0.14, 0.07, 0.09)
	var rock := BoxMesh.new(); rock.size = Vector3(0.1, 0.07, 0.11)
	var rng := RandomNumberGenerator.new(); rng.seed = 1910
	for p in [Vector3(55.6, 0.47, 35.3), Vector3(21.2, 0.47, 29.7), Vector3(33.4, 0.13, 33.4)]:
		_pickup(p, "ammo", ammo, rng)
	for p in [Vector3(34.6, 0.0, 46.4), Vector3(49.4, 0.0, 33.6), Vector3(29.6, 0.0, 66.4), Vector3(54.2, 0.0, 57.6), Vector3(39.0, 0.0, 61.0), Vector3(7.2, 0.13, 16.9)]:
		_pickup(p, "rock", rock, rng)
	for i in NUGGETS_AT.size():
		var n := Nugget.new()
		n.name = "Nugget%d" % i
		add_child(n)
		n.position = NUGGETS_AT[i]
		nuggets.append(n)

func _pickup(p: Vector3, kind: String, mesh: BoxMesh, rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = kit.material("brick" if kind == "rock" else "leather")
	add_child(mi)
	mi.position = p + Vector3(0, mesh.size.y * 0.5, 0)
	mi.rotation.y = rng.randf() * TAU
	var h := Hotspot.make(self, global_transform * Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(0.5, 0.4, 0.5), "Take")
	h.set_meta("mesh", mi)
	pickups.append([h, kind])

## The nugget he's walking into this frame, if any (a world position: his middle).
func nugget_at(p: Vector3) -> Nugget:
	for n in nuggets:
		if (n as Nugget).within(p):
			return n
	return null

# --- while he's here --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not built or not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_t += delta
	var eye := cam.global_position
	# the dome keeps its distance
	if dome:
		dome.global_position = Vector3(eye.x, global_position.y + 4.0, eye.z + 46.0)
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = LIGHT_EVERY
		update_lights(eye)
	# gas: a slow, soft breathing, never a flicker (only the lit ones)
	for l in _lit:
		var sd: float = l.get_meta("seed")
		l.light_energy = 2.4 * (0.93 + 0.05 * sin(_t * 1.3 + sd) + 0.02 * sin(_t * 3.1 + sd * 2.0))

## Light the nearest few lamps to `eye` (world space) and no others. Lamps change only when the
## set changes, so a lamp isn't touched while it stays among the nearest.
func update_lights(eye: Vector3) -> void:
	var phone := Game.is_phone()
	var budget := LAMPS_PHONE if phone else LAMPS_DESKTOP
	var reach := LAMP_RANGE_PHONE if phone else LAMP_RANGE_DESKTOP
	var near: Array = []
	for l in lamps:
		var d := l.global_position.distance_squared_to(eye)
		if d < reach * reach:
			near.append([d, l])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var want: Array[OmniLight3D] = []
	for i in mini(budget, near.size()):
		want.append(near[i][1])
	for l in _lit:
		if not want.has(l):
			l.visible = false
	for l in want:
		if not l.visible:
			l.visible = true
	_lit = want
	# the white past the gate only matters near it
	if gate_glow:
		var g := gate_glow.global_position.distance_to(eye) < 16.0
		if gate_glow.visible != g:
			gate_glow.visible = g

## The views TownChapter draws once, behind the black, before he arrives (local space: eye
## points; each is looked at four ways round). Between them they see every street, room and
## person in the town.
func prewarm_views() -> Array[Vector3]:
	var v: Array[Vector3] = []
	for c in [Vector2i(6, 2), Vector2i(1, 4), Vector2i(4, 5), Vector2i(8, 4), Vector2i(11, 5), Vector2i(14, 4),
			Vector2i(10, 7), Vector2i(9, 9), Vector2i(11, 10), Vector2i(10, 13), Vector2i(4, 15), Vector2i(9, 15),
			Vector2i(12, 15), Vector2i(10, 17)]:
		v.append(center(c.x, c.y) + Vector3(0, 1.6, 0))
	# the rooms behind the open doors: the photographer's salon, the hotel room, the nursery
	v.append(Vector3(18.0, 1.6, 26.0))
	v.append(porter_home + Vector3(-1.5, 1.2, -1.0))
	v.append(nursery_center + Vector3(0, 0.4, 0))
	return v

# --- finding the way: the town is a 4 m grid -----------------------------------------------------

func cell_of(local: Vector3) -> Vector2i:
	return Vector2i(floori(local.x / CELL), floori(local.z / CELL))

func _on_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < _W and c.y >= 0 and c.y < MAP.size() and String(MAP[c.y])[c.x] != "#"

## Once, at build: for every pair of street cells, the first cell on the shortest way from one to
## the other (a breadth-first search back from each destination).
func _route_table() -> void:
	var n := _W * MAP.size()
	_hop.resize(n * n)
	_hop.fill(-1)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for ty in MAP.size():
		for tx in _W:
			var t := Vector2i(tx, ty)
			if not _on_map(t):
				continue
			var ti := ty * _W + tx
			var seen := {t: true}
			var q: Array[Vector2i] = [t]
			var head := 0
			while head < q.size():
				var c: Vector2i = q[head]
				head += 1
				for d in dirs:
					var nb: Vector2i = c + d
					if seen.has(nb) or not _on_map(nb):
						continue
					seen[nb] = true
					# from nb, the way to t starts by stepping to c
					_hop[(nb.y * _W + nb.x) * n + ti] = c.y * _W + c.x
					q.append(nb)

## The next point to head for, walking the street grid from `from` toward `to` (local space).
## Straight there if they're in the same cell, or either isn't on the street.
func next_step(from: Vector3, to: Vector3) -> Vector3:
	var a := cell_of(from)
	var b := cell_of(to)
	if a == b or not _on_map(a) or not _on_map(b) or _hop.is_empty():
		return to
	var n := _W * MAP.size()
	var hop := _hop[(a.y * _W + a.x) * n + b.y * _W + b.x]
	if hop < 0:
		return to
	var step := Vector2i(hop % _W, hop / _W)
	if step == b:
		return to
	return center(step.x, step.y)
