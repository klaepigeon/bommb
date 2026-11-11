class_name Flat44
extends Node3D
## Flat 44, downstairs: a flat's hallway, and then a corridor of identical cells going east, a long
## way further than the building does. In every cell a chair facing the back wall, a bulb, a door.
## Past the eighth cell it quietly hands you back to the second (and the chairs turn a little more
## toward the doors each time). One of them is the child's: Flat 48's CHILD wore the note that says
## so. Stick it on a cell door and that's what the cell is. Or keep walking: on the fourth time round
## the last door is a child's size. (Its heart: the child's cell.)

const AT := Vector3(40, 0, 40)
const ZONE := 50
const CELLS := 10
const END := 64.0
var story
var entry: Usable
var chairs: Array[Node3D] = []
var loops := 0
var child_cell := -1
var _cell_doors: Array[Usable] = []
var _labels: Array[Label3D] = []

func cx(k: int) -> float:
	return 5.0 + k * 6.0

func build() -> void:
	name = "Flat44"
	var wall := Mats.tex(Tex.get_tex("paint_green"), ZONE, Color(1.3, 1.25, 1.0))
	var floor_m := Mats.tex(Tex.get_tex("tile"), ZONE, Color(0.75, 0.73, 0.65))
	var ceil_m := Mats.tex(Tex.get_tex("plaster"), ZONE)
	var k := Kit.new()
	var body := StaticBody3D.new(); add_child(body); body.position = AT
	# the vestibule (x 0..2.6), the corridor (x 2.6..END, z 4.15..5.35), cells to the north (z 1.6..4.15)
	k.quad(floor_m, AT + Vector3(0, 0, 6.0), AT + Vector3(2.6, 0, 6.0), AT + Vector3(2.6, 0, 3.5), AT + Vector3(0, 0, 3.5))
	k.quad(floor_m, AT + Vector3(2.6, 0, 6.0), AT + Vector3(END, 0, 6.0), AT + Vector3(END, 0, 4.15), AT + Vector3(2.6, 0, 4.15))
	k.quad(wall, AT + Vector3(2.6, 0, 3.5), AT + Vector3(2.6, 0, 4.15), AT + Vector3(2.6, 2.6, 4.15), AT + Vector3(2.6, 2.6, 3.5))
	k.quad(ceil_m, AT + Vector3(0, 2.6, 3.5), AT + Vector3(END, 2.6, 3.5), AT + Vector3(END, 2.6, 6.0), AT + Vector3(0, 2.6, 6.0))
	_solid(body, Vector3(END * 0.5, -0.2, 4.0), Vector3(END + 2, 0.4, 8.0))
	_solid(body, Vector3(END * 0.5, 2.8, 4.0), Vector3(END + 2, 0.4, 8.0))
	# vestibule walls
	k.quad(wall, AT + Vector3(0, 0, 3.5), AT + Vector3(2.6, 0, 3.5), AT + Vector3(2.6, 2.6, 3.5), AT + Vector3(0, 2.6, 3.5))
	k.quad(wall, AT + Vector3(0, 0, 6.0), AT + Vector3(END, 0, 6.0), AT + Vector3(END, 2.6, 6.0), AT + Vector3(0, 2.6, 6.0))
	k.quad(wall, AT + Vector3(0, 0, 3.5), AT + Vector3(0, 0, 6.0), AT + Vector3(0, 2.6, 6.0), AT + Vector3(0, 2.6, 3.5))
	_solid(body, Vector3(-0.15, 1.3, 4.75), Vector3(0.3, 2.6, 2.6))
	_solid(body, Vector3(END * 0.5, 1.3, 6.15), Vector3(END + 2, 2.6, 0.3))
	_solid(body, Vector3(1.3, 1.3, 3.35), Vector3(2.6, 2.6, 0.3))
	_solid(body, Vector3(END + 0.15, 1.3, 4.75), Vector3(0.3, 2.6, 2.6))
	# the corridor's north wall, with a door every six metres, and the cells behind
	var x := 2.6
	for c in CELLS:
		var d0 := cx(c) - 0.38; var d1 := cx(c) + 0.38
		k.quad(wall, AT + Vector3(x, 0, 4.15), AT + Vector3(d0, 0, 4.15), AT + Vector3(d0, 2.6, 4.15), AT + Vector3(x, 2.6, 4.15))
		k.quad(wall, AT + Vector3(d0, 2.0, 4.15), AT + Vector3(d1, 2.0, 4.15), AT + Vector3(d1, 2.6, 4.15), AT + Vector3(d0, 2.6, 4.15))
		_solid(body, Vector3((x + d0) * 0.5, 1.3, 4.0), Vector3(d0 - x, 2.6, 0.3))
		_solid(body, Vector3(cx(c), 2.3, 4.0), Vector3(0.76, 0.6, 0.3))
		x = d1
		# the cell: 2 m wide, back wall at z 1.6
		var c0 := cx(c) - 1.0; var c1 := cx(c) + 1.0
		k.quad(floor_m, AT + Vector3(c0, 0, 4.15), AT + Vector3(c1, 0, 4.15), AT + Vector3(c1, 0, 1.6), AT + Vector3(c0, 0, 1.6))
		k.quad(wall, AT + Vector3(c0, 0, 1.6), AT + Vector3(c1, 0, 1.6), AT + Vector3(c1, 2.6, 1.6), AT + Vector3(c0, 2.6, 1.6))
		k.quad(wall, AT + Vector3(c0, 0, 1.6), AT + Vector3(c0, 0, 4.15), AT + Vector3(c0, 2.6, 4.15), AT + Vector3(c0, 2.6, 1.6))
		k.quad(wall, AT + Vector3(c1, 0, 4.15), AT + Vector3(c1, 0, 1.6), AT + Vector3(c1, 2.6, 1.6), AT + Vector3(c1, 2.6, 4.15))
		k.quad(ceil_m, AT + Vector3(c0, 2.6, 1.6), AT + Vector3(c1, 2.6, 1.6), AT + Vector3(c1, 2.6, 4.15), AT + Vector3(c0, 2.6, 4.15))
		_solid(body, Vector3(cx(c), 1.3, 1.45), Vector3(2.0, 2.6, 0.3))
		_solid(body, Vector3(c0 - 0.15, 1.3, 2.9), Vector3(0.3, 2.6, 2.6))
		_solid(body, Vector3(c1 + 0.15, 1.3, 2.9), Vector3(0.3, 2.6, 2.6))
		# the chair facing the back wall
		var ch := Node3D.new(); add_child(ch); ch.position = AT + (Vector3(cx(c), 0, 2.3))
		var ck := Kit.new()
		var wood := Mats.tex(Tex.get_tex("floorboards"), ZONE, Color(0.9, 0.75, 0.6))
		ck.box(wood, Vector3(0, 0.44, 0), Vector3(0.42, 0.04, 0.42))
		ck.box(wood, Vector3(0, 0.68, 0.19), Vector3(0.4, 0.42, 0.03))
		for sx in [-0.18, 0.18]:
			for sz in [-0.18, 0.18]: ck.box(wood, Vector3(sx, 0.22, sz), Vector3(0.035, 0.44, 0.035))
		ck.commit(ch, "Chair")
		chairs.append(ch)
		Lamp.make(self, AT + Vector3(cx(c), 2.2, 2.9), Color(1.0, 0.94, 0.82), 0.5, 3.6, PackedInt32Array([ZONE]), "", "")
		if c % 2 == 0: Lamp.make(self, AT + Vector3(cx(c) + 3.0, 2.4, 4.75), Color(0.9, 0.95, 1.0), 0.55, 6.0, PackedInt32Array([ZONE]), "", "fluoro")
		# its door (open; it's the label that matters)
		var u := Usable.make(self, Transform3D(Basis(), AT + Vector3(cx(c), 1.0, 4.18)), Vector3(0.76, 2.0, 0.08), [])
		u.title = "Cell"
		var idx := c
		u.offer = func(_k): return [{"id": "look", "label": "Look"}]
		u.set_meta("hold", func(_k, held): return [{"id": "label", "label": "Stick it on the door", "held": true}] if held.item == "note:CHILD'S CELL" else [])
		u.acted.connect(func(v, kk): _cell_act(idx, v, kk))
		_cell_doors.append(u)
		var lb := Label3D.new(); lb.font_size = 30; lb.pixel_size = 0.0015; lb.modulate = Color(0.15, 0.15, 0.2); lb.shaded = false; lb.outline_size = 0
		add_child(lb); lb.position = AT + Vector3(cx(c), 1.55, 4.26); lb.rotation.y = PI
		_labels.append(lb)
	k.quad(wall, AT + Vector3(x, 0, 4.15), AT + Vector3(END, 0, 4.15), AT + Vector3(END, 2.6, 4.15), AT + Vector3(x, 2.6, 4.15))
	_solid(body, Vector3((x + END) * 0.5, 1.3, 4.0), Vector3(END - x, 2.6, 0.3))
	for mi in k.commit(self, "Corridor"):
		var mm := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		mm.set_shader_parameter("ambient", Vector3(0.17, 0.17, 0.15)); mi.material_override = mm
	entry = Usable.make(self, Transform3D(Basis(), AT + Vector3(0.05, 1.04, 4.75)), Vector3(0.12, 2.08, 0.84), [{"id": "leave", "label": "Leave"}], true)
	entry.title = "Front door"
	entry.acted.connect(func(_v, _k): story.travel.call("44", false))
	World.register("flat44", func(): return {"loops": loops, "child": child_cell}, func(d):
		loops = int(d.get("loops", 0)); var cc := int(d.get("child", -1))
		if cc >= 0: _make_child_cell(cc))

func _solid(body: StaticBody3D, c: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = size; cs.shape = bx
	cs.position = c; body.add_child(cs)

func contains(p: Vector3) -> bool:
	var q := p - AT
	return q.x > -0.5 and q.x < END + 1.0 and q.z > 1.0 and q.z < 6.5 and absf(q.y) < 3.0

func _cell_act(c: int, v: String, k) -> void:
	match v:
		"look":
			var t: String = ["A chair facing the wall, as if someone was told to sit here and wait.", "The same chair. The wall in front of it has two pale marks at knee height.", "The same chair."][c % 3]
			if c == child_cell: t = "A child's chair, facing the wall. A drawing pinned at a child's eye height. СОНЯ, scratched into the paint."
			World.emit_event("looked", {"title": "Cell", "desc": t, "key": "cell44"})
		"label":
			var h = k.held; k.held = null; h.queue_free()
			_make_child_cell(c)
			World.emit_event("looked", {"title": "", "desc": "The note stays. It's the child's cell: it always was. The chair in it is small.", "key": "childcell"})

## The child's cell: a small chair, her drawing at her height, her name in the paint.
func _make_child_cell(c: int) -> void:
	if child_cell >= 0: return
	child_cell = c
	_labels[c].text = "CHILD'S CELL"
	chairs[c].scale = Vector3(0.62, 0.62, 0.62)
	var p := Prop.make(self, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), AT + Vector3(cx(c), 0.9, 1.63)), Vector3(0.3, 0.01, 0.22), 0.02)
	p.key = "drawing44"; p.title = "Drawing"; p.doc = "pick_144_Drawing"; p.stuff = "paper"
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.3, 0.004, 0.22); mi.mesh = bm
	mi.material_override = Mats.tex(Tex.get_tex("paper"), ZONE); p.add_child(mi)
	var a := Area3D.new(); a.collision_mask = 16; add_child(a)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(1.8, 2.0, 2.2); cs.shape = b
	a.add_child(cs); a.global_position = AT + Vector3(cx(c), 1.0, 2.8)
	a.body_entered.connect(func(bd): if bd is Kurt and story: story.flat44_child())

## The loop: past the eighth cell the corridor hands you back to the second.
func _physics_process(_delta: float) -> void:
	if story == null: return
	var kurt: Kurt = story.kurt
	var q := kurt.global_position - AT
	if absf(q.y) > 1.5 or q.z < 4.0 or q.z > 5.5: return
	if q.x > cx(8) + 3.0:
		loops += 1
		kurt.global_position.x -= 6.0 * 7.0
		for i in chairs.size():
			chairs[i].rotation.y = -minf(PI, loops * 0.5 + i * 0.05)
		World.emit_event("loop44", {"n": loops})
		if loops == 1: World.emit_event("looked", {"title": "", "desc": "Cell after cell. The same chair. You've been counting: this is the eleventh. There were ten.", "key": "loop44"})
		if loops == 4 and child_cell < 0:
			_make_child_cell(9)
			World.emit_event("looked", {"title": "", "desc": "The last door is smaller than the others. A child's size.", "key": "loop44b"})
