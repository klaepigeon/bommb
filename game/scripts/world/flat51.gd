class_name Flat51
extends Node3D
## Flat 51, upstairs: the flat from the note in the box room. The same flat, the same paper on the
## walls, never lived in: no furniture, the dust unbroken except for one set of footprints going in.
## Past the living room the building stops: no north wall, just the floor going on into the grey,
## his footprints going on with it, figures standing a long way off. Follow them far enough and
## you're standing in 47's hallway, and something in 47 has moved. (Its heart: the end of the prints.)

const AT := Vector3(80, 0, 0)
const ROOMZ := 70                 ## zones: 47's room numbers + 70
var flat47: Flat47
var story
var entry: Usable
var _prints: MultiMeshInstance3D
var _done := false

func build(p_flat47: Flat47) -> void:
	flat47 = p_flat47
	name = "Flat51"
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Rooms"
	add_child(flat)
	flat.position = AT
	for c in flat.get_children():
		var nm := String(c.name)
		var keep := false
		for r in Flat47.ROOMS:
			if nm.begins_with(r + "-") and not (nm in ["living-n", "bedroom-n", "kitchen-n"]): keep = true
		if not keep: c.free()
	for mi in flat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var room := ""
		var n: Node = m
		while n and n != flat:
			if "-" in String(n.name): room = String(n.name).split("-")[0]; break
			n = n.get_parent()
		var z := int(Flat47.ROOMS.get(room, 4)) + ROOMZ
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			if src:
				var mm := (Mats.convert(src, z) as ShaderMaterial).duplicate() as ShaderMaterial
				mm.set_shader_parameter("albedo_color", Color(1.05, 1.03, 0.98))     # dust
				m.set_surface_override_material(i, mm)
	_collision()
	_void()
	_prints_path()
	# one bulb in the hall; the grey from the north
	Lamp.make(self, AT + Vector3(7.3, 2.2, 4.5), Color(1.0, 0.93, 0.8), 0.7, 6.0, PackedInt32Array([74, 72, 73, 71, 75, 76, 77]), "", "")
	Lamp.make(self, AT + Vector3(3.0, 2.0, -1.5), Color(0.75, 0.77, 0.8), 0.6, 9.0, PackedInt32Array([71, 72, 73, 79]))
	entry = Usable.make(self, Transform3D(Basis(), AT + Vector3(10.0, 1.04, 4.56)), Vector3(0.12, 2.08, 0.84), [{"id": "leave", "label": "Leave"}], true)
	entry.title = "Front door"
	entry.acted.connect(func(_v, _k): story.travel.call("51", false))
	var k := Kit.new()
	k.box(Mats.tex(Tex.get_tex("cloth"), 74, Color(0.5, 0.42, 0.34)), AT + Vector3(10.02, 1.04, 4.56), Vector3(0.06, 2.06, 0.82))
	# a chair in the living room, facing where the wall should be
	k.box(Mats.tex(Tex.get_tex("floorboards"), 71), AT + Vector3(2.2, 0.45, 1.6), Vector3(0.42, 0.04, 0.42))
	k.box(Mats.tex(Tex.get_tex("floorboards"), 71), AT + Vector3(2.2, 0.7, 1.8), Vector3(0.4, 0.45, 0.03))
	for sx in [-0.18, 0.18]:
		for sz in [-0.18, 0.18]: k.box(Mats.tex(Tex.get_tex("floorboards"), 71), AT + Vector3(2.2 + sx, 0.22, 1.6 + sz), Vector3(0.035, 0.44, 0.035))
	k.commit(self, "Chair")
	World.register("flat51", func(): return {"done": _done}, func(d): _done = bool(d.get("done", false)))

func contains(p: Vector3) -> bool:
	var q := p - AT
	return q.x > -2.0 and q.x < 10.6 and q.z > -70.0 and q.z < 8.6 and absf(q.y) < 3.0

func zone_of(p: Vector3) -> int:
	var q := p - AT
	if q.z < 0.0: return 79
	for k in flat47.level.rooms:
		var r: Dictionary = flat47.level.rooms[k]
		if q.x >= r.x0 and q.x < r.x1 and q.z >= r.z0 and q.z < r.z1: return int(Flat47.ROOMS[k]) + ROOMZ
	return 74

func _collision() -> void:
	var walls := StaticBody3D.new(); walls.name = "Walls51"; add_child(walls)
	walls.position = AT
	for c in flat47.level.colliders:
		if float(c.x) > 10.5 or float(c.y1) < 2.0: continue
		if float(c.z) < 0.05 and float(c.x) < 10.3: continue        # the north wall isn't there
		var h: float = c.y1 - c.y0
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0); sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	var fl := CollisionShape3D.new(); var fb := BoxShape3D.new(); fb.size = Vector3(12.0, 0.4, 78.0); fl.shape = fb
	fl.position = Vector3(5.0, -0.2, -31.0); walls.add_child(fl)

## The floor going on into the grey, and things standing a long way off.
func _void() -> void:
	var k := Kit.new()
	var m := (Mats.tex(Tex.get_tex("floorboards"), 79, Color(0.7, 0.7, 0.68)) as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("ambient", Vector3(0.3, 0.3, 0.31))
	k.quad(m, AT + Vector3(-1.0, 0, 0.0), AT + Vector3(11.0, 0, 0.0), AT + Vector3(11.0, 0, -70.0), AT + Vector3(-1.0, 0, -70.0))
	var rng := RandomNumberGenerator.new(); rng.seed = 51
	var grey := Mats.flat(Color(0.35, 0.35, 0.37), 79)
	for i in 7:
		var p := AT + Vector3(rng.randf_range(-8.0, 18.0), 0, -rng.randf_range(18.0, 60.0))
		var h := rng.randf_range(1.6, 2.4)
		k.box(grey, p + Vector3(0, h * 0.5, 0), Vector3(0.35, h, 0.25))
		k.box(grey, p + Vector3(0, h + 0.12, 0), Vector3(0.2, 0.22, 0.2))
	# the grey: a room with no walls you can reach, all round the end of the building
	var grey_sky := Mats.flat(Color(0.33, 0.33, 0.35), -1, 1.0)
	var c := AT + Vector3(5.0, 0, -35.0)
	k.box(grey_sky, AT + Vector3(5.0, 10, -32.0), Vector3(90, 30, 74), Basis(), 1 | 2 | 4 | 32)    # not the near side, nor under
	k.commit(self, "Void")
	var a := Area3D.new(); a.collision_mask = 16; add_child(a)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(30, 4, 4); cs.shape = b
	a.add_child(cs); a.global_position = AT + Vector3(5.0, 1.0, -62.0)
	a.body_entered.connect(func(bd): if bd is Kurt: _end_of_prints())

func _prints_path() -> void:
	var path := [[9.8, 4.55], [7.0, 4.6], [4.6, 4.6], [3.6, 3.8], [3.2, 2.0], [3.0, 0.2], [2.8, -4], [2.5, -12], [2.0, -22], [1.6, -40], [1.2, -61]]
	var xs: Array = []
	for i in path.size() - 1:
		var a := Vector2(path[i][0], path[i][1]); var b := Vector2(path[i + 1][0], path[i + 1][1])
		var n := int(a.distance_to(b) / 0.36)
		var dir := (b - a).normalized(); var side := Vector2(-dir.y, dir.x)
		for k in n:
			var p := a.lerp(b, float(k) / maxf(n, 1)) + side * (0.09 if k % 2 == 0 else -0.09)
			xs.append(Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), AT + Vector3(p.x, 0.006, p.y)))
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := PlaneMesh.new(); qm.size = Vector2(0.11, 0.27); mm.mesh = qm
	mm.instance_count = xs.size()
	for i in xs.size(): mm.set_instance_transform(i, xs[i])
	_prints = MultiMeshInstance3D.new(); _prints.multimesh = mm
	_prints.material_override = Mats.flat(Color(0.3, 0.28, 0.24), -1)
	add_child(_prints)
	_prints.global_transform = Transform3D.IDENTITY

func _end_of_prints() -> void:
	if not story: return
	_done = true
	story.flat51_end()
