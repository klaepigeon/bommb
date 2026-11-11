class_name Flat48
extends Node3D
## Flat 48, across the landing: Flat 47 as reality only sketched it. The same rooms in pale draft
## plaster, the room names pencilled on the walls, every piece of furniture a white block with a paper
## tag that says what it was like. The rule here: what something is, is what's written on it.
##   - the hall wall of loose notes ("what it is"): take one, stick it on a block. The right word and
##     the block is the thing (Flat 47's own, copied in). GUN SAFE on the cold tall block in the box room.
##   - six red notes, one in each room. On the hall's other wall, a pencil plan of the flat with a box
##     for each room: put each red note in the box of the room it was found in, and read the plan the way
##     you'd read a page. It says something. Behind the plan, a seventh red note: 51.
##   - the POINTLESS DOOR in the hall opens onto plaster. Peel its label off. Write it something else.
##   - MAMA, PAPA, CHILD, white, wrong in the neck and the arm, closer whenever you look away.
## Its heart: the plan read right (the street door's 48 bolt goes back).

const AT := Vector3(40, 0, 0)
const ZONE := 48
const DRAFT := Color(0.86, 0.85, 0.81)
const NOTE_WALL := [Vector3(4.62, 0, 3.874), Vector3(6.38, 0, 3.874)]
const PLAN := Vector3(9.45, 1.45, 3.874)
const POINTLESS := Vector3(8.05, 0.0, 5.13)     ## on the hall wall between the cupboard and the bathroom door
const SAFE_AT := Vector3(1.35, 0.0, 7.62)
const RED := {
	"living": [Vector3(0.9, 0.62, 2.5), "Sometimes"], "bedroom": [Vector3(5.4, 0.62, 1.6), "it's easier"],
	"kitchen": [Vector3(9.7, 0.92, 2.65), "to make the choice"], "hall": [Vector3(9.55, 0.04, 4.75), "that makes no sense,"],
	"storage": [Vector3(0.45, 0.04, 6.9), "when your back"], "child": [Vector3(3.3, 0.5, 7.1), "is against the wall"],
}
const PLAN_ORDER := ["living", "bedroom", "kitchen", "hall", "storage", "child"]
const ROOM_NAME := {"living": "living room", "bedroom": "bedroom", "kitchen": "kitchen", "hall": "hall", "storage": "box room", "child": "Sonya's room"}

var data: Dictionary
var flat47: Flat47
var story
var blocks := {}               ## collider index -> {node, word, tag, real, mesh}
var wall_words: Array = []     ## the notes still on the "what it is" wall
var wall_i := 0
var plan := {}                 ## room -> red-note room it holds ("" empty)
var pointless_label := "POINTLESS DOOR"
var entry: Usable
var _draft: ShaderMaterial
var _block: ShaderMaterial
var _wall_lbl: Label3D
var _door_lbl: Label3D
var _plan_lbls := {}

func build(p_flat47: Flat47) -> void:
	flat47 = p_flat47
	name = "Flat48"
	data = JSON.parse_string(FileAccess.get_file_as_string("res://content/flat48.json"))
	_draft = Mats.tex(Tex.get_tex("draft"), ZONE).duplicate() as ShaderMaterial
	_draft.set_shader_parameter("ambient", Vector3(0.32, 0.32, 0.33))
	_block = Mats.flat(Color(0.93, 0.93, 0.9), ZONE).duplicate() as ShaderMaterial
	_block.set_shader_parameter("ambient", Vector3(0.34, 0.34, 0.35))
	_shell()
	_collision()
	_lamps()
	for b in data.blocks: _make_block(int(b[0]), String(b[1]), String(b[2]))
	_safe_block()
	wall_words = (data.words as Array).duplicate()
	wall_words.append("OUTSIDE")
	_note_wall()
	_plan_board()
	_red_notes()
	_pointless_door()
	for r in PLAN_ORDER: plan[r] = ""
	World.register("flat48", _save, _load)

func local(p: Vector3) -> Vector3:
	return AT + p

func contains(p: Vector3) -> bool:
	var q := p - AT
	return q.x > -0.6 and q.x < 10.6 and q.z > -0.6 and q.z < 8.6 and absf(q.y) < 3.0

# ------------------------------------------------------------------------------ the rooms
func _shell() -> void:
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Rooms"
	add_child(flat)
	flat.position = AT
	for c in flat.get_children():
		var nm := String(c.name)
		var keep := nm.begins_with("door_") and nm != "door_dStore" and nm != "door_balDoor"
		for r in Flat47.ROOMS:
			if nm.begins_with(r + "-"): keep = true
		if not keep: c.free()
	for mi in flat.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _draft
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for d in flat.get_children():
		if not String(d.name).begins_with("door_") or not d.has_meta("extras"): continue
		var ex: Dictionary = (d.get_meta("extras") as Dictionary).duplicate()
		if String(d.name) == "door_dEntry":
			continue          # the door out is the landing's
		var door := Door.new(); door.name = "D48_" + String(ex.get("id", d.name))
		var xf: Transform3D = (d as Node3D).global_transform
		flat.add_child(door)
		door.global_transform = xf
		(d as Node3D).reparent(door, true)
		(d as Node3D).transform = Transform3D.IDENTITY
		ex["open"] = 1.2
		door.setup("48" + String(ex.get("id", "")), ex)
		door.zone_a = ZONE; door.zone_b = ZONE
	# the windows: overexposed, white, nothing to see
	for w in [[1.65, 1.6, 1.7, 1.4], [6.0, 1.6, 1.4, 1.4], [8.85, 1.65, 1.1, 1.3], [3.17, 1.2, 0.7, 2.2]]:
		var mi := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(w[2], w[3]); mi.mesh = qm
		mi.material_override = Mats.flat(Color(1, 1, 0.97), -1, 1.0)
		add_child(mi); mi.position = AT + (Vector3(w[0], w[1], 0.06))
	# the room names in pencil, at eye height
	var labels: Dictionary = data.room_labels
	var rooms: Dictionary = flat47.level.rooms
	for id in labels:
		var r: Dictionary = rooms[id]
		var l := Label3D.new(); l.text = labels[id]; l.font_size = 40; l.pixel_size = 0.0016
		l.modulate = Color(0.32, 0.32, 0.36, 0.85); l.shaded = false; l.outline_size = 0
		add_child(l)
		l.position = AT + (Vector3(r.x0 + 0.5 + (r.x1 - r.x0) * 0.15, 1.72, r.z0 + 0.08))
		if id == "hall": l.position = AT + (Vector3(5.2, 2.3, 3.88))
		if id in ["living", "bedroom", "kitchen"]:
			l.position = AT + Vector3(r.x0 + 0.08, 1.72, {"living": 3.4, "bedroom": 3.2, "kitchen": 2.6}[id]); l.rotation.y = PI * 0.5
	# the door out: on the hall's east end, as in 47
	entry = Usable.make(self, Transform3D(Basis(), local(Vector3(10.0, 1.04, 4.56))), Vector3(0.12, 2.08, 0.84), [{"id": "leave", "label": "Leave"}], true)
	entry.title = "Front door"
	entry.acted.connect(func(_v, _k): story.travel.call("48", false))
	var k := Kit.new()
	k.box(Mats.tex(Tex.get_tex("cloth"), ZONE, Color(0.55, 0.3, 0.28)), local(Vector3(10.02, 1.04, 4.56)), Vector3(0.06, 2.06, 0.82))
	k.commit(self, "Entry")

func _collision() -> void:
	var walls := StaticBody3D.new(); walls.name = "Walls48"; add_child(walls)
	walls.position = AT
	for c in flat47.level.colliders:
		if float(c.x) > 10.5 or float(c.y1) < 2.0: continue        # the walls, not the furniture
		var h: float = c.y1 - c.y0
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0); sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	var fl := CollisionShape3D.new(); var fb := BoxShape3D.new(); fb.size = Vector3(10.6, 0.4, 8.6); fl.shape = fb
	fl.position = Vector3(5.0, -0.2, 4.0); walls.add_child(fl)
	var ce := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(10.6, 0.4, 8.6); ce.shape = cb
	ce.position = Vector3(5.0, 2.95, 4.0); walls.add_child(ce)

func _lamps() -> void:
	# steady, cold, even: a light with nowhere it comes from
	for p in [Vector3(2.2, 2.3, 2.6), Vector3(6.0, 2.3, 1.9), Vector3(8.8, 2.3, 1.9), Vector3(7.2, 2.3, 4.5), Vector3(1.4, 2.3, 6.6), Vector3(4.6, 2.3, 6.6), Vector3(8.2, 2.3, 6.6)]:
		Lamp.make(self, local(p), Color(0.93, 0.95, 1.0), 0.55, 5.5, PackedInt32Array([ZONE]))

# ------------------------------------------------------------------------------ the blocks
func _make_block(idx: int, word: String, tag: String) -> void:
	var c: Dictionary = flat47.level.colliders[idx]
	var size := Vector3(c.hx * 2.0, c.y1 - c.y0, c.hz * 2.0)
	var xf := Transform3D(Basis(Vector3.UP, c.rot), local(Vector3(c.x, c.y0 + size.y * 0.5, c.z)))
	var u := Usable.make(self, xf, size, [], true)
	u.title = "A white block"
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _block
	u.add_child(mi)
	if tag != "":
		var l := Label3D.new(); l.text = tag; l.font_size = 22; l.pixel_size = 0.0012; l.modulate = Color(0.25, 0.25, 0.3)
		l.shaded = false; l.outline_size = 0; l.width = 300; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		u.add_child(l); l.position = Vector3(0, size.y * 0.5 + 0.005, 0); l.rotation.x = -PI * 0.5
	var b := {"node": u, "mesh": mi, "word": word, "tag": tag, "real": false, "copy": null, "c": c}
	blocks[idx] = b
	u.offer = func(_k): return _block_verbs(b)
	u.acted.connect(func(v, k): _block_act(b, v, k))
	u.set_meta("hold", func(k, held): return _block_hold(b, held))

func _block_verbs(b: Dictionary) -> Array:
	if b.real: return [{"id": "peel", "label": "Peel the note off"}, {"id": "look", "label": "Look"}]
	return [{"id": "look", "label": "Look"}]

func _block_hold(b: Dictionary, held) -> Array:
	if held.item.begins_with("note:") and not b.real: return [{"id": "stick", "label": "Stick it on", "held": true}]
	return []

func _block_act(b: Dictionary, v: String, k) -> void:
	var cap: Dictionary = data.captions
	match v:
		"look":
			var t: String
			if b.real: t = String(cap.real).replace("%s", String(b.word).to_lower())
			elif b.tag != "": t = String(cap.block_tag) % b.tag
			else: t = String(cap.block_blank)
			World.emit_event("looked", {"title": "Block", "desc": t, "key": "block48"})
		"stick":
			var word := String(k.held.item).substr(5)
			if word == String(b.word) and word != "":
				var h = k.held
				k.held = null
				h.queue_free()
				_become(b)
				World.emit_event("looked", {"title": word, "desc": String(cap.real).replace("%s", word.to_lower()), "key": "real48"})
				World.emit_event("f48_real", {"word": word})
			else:
				Audio.play("pickup", (b.node as Node3D).global_position, -8.0, 1.4)
				World.emit_event("looked", {"title": "", "desc": String(cap.wont_stay if b.word != "" else cap.wont_stay_blank), "key": "wont48"})
		"peel":
			_unbecome(b)
			k.give_item("note:" + String(b.word), "Note: " + String(b.word), "A yellow sticky note, in pencil: " + String(b.word))
			World.emit_event("looked", {"title": "", "desc": String(cap.peeled), "key": "peel48"})

## Flat 47's own furniture, copied in where the block is: what the block always was.
func _become(b: Dictionary) -> void:
	b.real = true
	(b.mesh as MeshInstance3D).visible = false
	var c: Dictionary = b.c
	var box := AABB(Vector3(c.x - c.hx - 0.15, c.y0 - 0.05, c.z - c.hz - 0.15), Vector3(c.hx * 2.0 + 0.3, c.y1 - c.y0 + 0.4, c.hz * 2.0 + 0.3))
	var copy := Node3D.new(); copy.name = "Real_" + String(b.word)
	add_child(copy)
	for mi in flat47.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree(): continue
		var skip := false
		var n: Node = m
		while n and n != flat47:
			if n is Prop or n is Door or String(n.name).contains("-"): skip = true; break
			n = n.get_parent()
		if skip: continue
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > 4.0 or not box.has_point(a.get_center()): continue
		var d := m.duplicate() as MeshInstance3D
		copy.add_child(d)
		d.global_transform = Transform3D(m.global_basis, local(m.global_position))
		Mats.own_zone(d, ZONE)
	if copy.get_child_count() == 0:
		(b.mesh as MeshInstance3D).visible = true
		(b.mesh as MeshInstance3D).material_override = Mats.flat(Color(0.55, 0.45, 0.35), ZONE)
	b.copy = copy
	Audio.play("pop", (b.node as Node3D).global_position, -6.0, 0.6)

func _unbecome(b: Dictionary) -> void:
	b.real = false
	if b.copy: (b.copy as Node).queue_free(); b.copy = null
	(b.mesh as MeshInstance3D).visible = true
	(b.mesh as MeshInstance3D).material_override = _block

# ------------------------------------------------------------------------------ the gun safe
var safe_real := false
var safe_open := false
var _safe: Usable
var _safe_mesh: MeshInstance3D

func _safe_block() -> void:
	var size := Vector3(0.54, 1.46, 0.38)
	_safe = Usable.make(self, Transform3D(Basis(), local(SAFE_AT + Vector3(0, size.y * 0.5, 0))), size, [], true)
	_safe.title = "A tall block"
	_safe_mesh = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; _safe_mesh.mesh = bm; _safe_mesh.material_override = _block
	_safe.add_child(_safe_mesh)
	var l := Label3D.new(); l.text = String(data.safe.tag); l.font_size = 22; l.pixel_size = 0.0012; l.modulate = Color(0.25, 0.25, 0.3)
	l.shaded = false; l.outline_size = 0; _safe.add_child(l); l.position = Vector3(0, 0.3, -size.z * 0.5 - 0.005); l.rotation.y = PI
	_safe.offer = func(_k):
		if not safe_real: return [{"id": "look", "label": "Look"}]
		if not safe_open: return [{"id": "open", "label": "Open"}]
		return [{"id": "look", "label": "Look"}]
	_safe.set_meta("hold", func(k, held): return [{"id": "stick", "label": "Stick it on", "held": true}] if held.item.begins_with("note:") and not safe_real else [])
	_safe.acted.connect(_safe_act)

func _safe_act(v: String, k) -> void:
	var cap: Dictionary = data.captions
	match v:
		"look": World.emit_event("looked", {"title": "", "desc": String(cap.safe_open if safe_open else (cap.safe_real if safe_real else cap.safe_block)), "key": "safe48"})
		"stick":
			var word := String(k.held.item).substr(5)
			if word == "GUN SAFE":
				var h = k.held; k.held = null; h.queue_free()
				safe_real = true
				_safe_mesh.material_override = Mats.tex(Tex.get_tex("metal"), ZONE, Color(0.55, 0.62, 0.58))
				World.emit_event("looked", {"title": "", "desc": String(cap.safe_real), "key": "safe48"})
				World.emit_event("f48_safe", {})
			else:
				World.emit_event("looked", {"title": "", "desc": String(cap.wont_stay), "key": "wont48"})
		"open":
			safe_open = true
			Audio.play("latch", _safe.global_position, -2.0)
			World.emit_event("looked", {"title": "", "desc": String(cap.safe_open), "key": "safe48"})
			k.give_item("shotgun", "Sawn-off shotgun", "An IZh-43 side-by-side, sawn off: two barrels, a pistol grip.")
			k.give_item("shells", "Shells", "A box of 12-bore shells: ten.")
			k.shells += 10
			World.emit_event("f48_gun", {})

# ------------------------------------------------------------------------------ the notes on the wall
func _note_wall() -> void:
	var u := Usable.make(self, Transform3D(Basis(), local(Vector3(5.5, 1.45, 3.9))), Vector3(1.6, 0.9, 0.06), [])
	u.title = "Notes"
	var bg := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(1.7, 1.0); bg.mesh = qm
	bg.material_override = Mats.tex(Tex.get_tex("sticky"), ZONE)
	add_child(bg); bg.position = AT + (Vector3(5.5, 1.45, 3.885))
	var head := Label3D.new(); head.text = String(data.wall_heading); head.font_size = 40; head.pixel_size = 0.0018
	head.modulate = Color(0.3, 0.3, 0.34); head.shaded = false; head.outline_size = 0
	add_child(head); head.position = AT + (Vector3(5.5, 2.08, 3.884))
	_wall_lbl = Label3D.new(); _wall_lbl.font_size = 34; _wall_lbl.pixel_size = 0.0016; _wall_lbl.modulate = Color(0.12, 0.13, 0.2)
	_wall_lbl.shaded = false; _wall_lbl.outline_size = 0; _wall_lbl.width = 900; _wall_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_wall_lbl); _wall_lbl.position = AT + (Vector3(5.5, 1.45, 3.883))
	_refresh_wall()
	u.offer = func(_k):
		if wall_words.is_empty(): return []
		return [{"id": "take", "label": "Take “%s”" % wall_words[wall_i % wall_words.size()]}, {"id": "next", "label": "Another one"}]
	u.acted.connect(func(v, k):
		if v == "next": wall_i = (wall_i + 1) % maxi(wall_words.size(), 1); _refresh_wall(); return
		var w: String = wall_words[wall_i % wall_words.size()]
		wall_words.remove_at(wall_i % wall_words.size())
		if wall_words.size() > 0: wall_i = wall_i % wall_words.size()
		k.give_item("note:" + w, "Note: " + w, "A yellow sticky note, in pencil: " + w)
		k.hold_from_pocket("note:" + w)
		_refresh_wall()
		World.emit_event("f48_note", {"word": w}))
	u.set_meta("hold", func(k, held): return [{"id": "back", "label": "Put it back on the wall", "held": true}] if held.item.begins_with("note:") else [])
	u.acted.connect(func(v, k):
		if v == "back" and k.held:
			var w := String(k.held.item).substr(5)
			var h = k.held; k.held = null; h.queue_free()
			wall_words.insert(wall_i, w)
			_refresh_wall())

func _refresh_wall() -> void:
	var parts: Array = []
	for i in wall_words.size():
		parts.append(("[" + String(wall_words[i]) + "]") if i == wall_i else String(wall_words[i]))
	_wall_lbl.text = "   ".join(parts)

# ------------------------------------------------------------------------------ the red notes and the plan
func _red_notes() -> void:
	for r in RED:
		var spec: Array = RED[r]
		var p := Prop.make(self, Transform3D(Basis(), local(spec[0] + Vector3(0, 0.01, 0))), Vector3(0.08, 0.01, 0.08), 0.01)
		p.key = "rednote_" + r; p.item = "rednote:" + r; p.title = "Red note"
		p.desc = "A red sticky note. In pencil, in a hand like yours: “%s”" % spec[1]
		p.stuff = "paper"
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.004, 0.08); mi.mesh = bm
		mi.material_override = Mats.flat(Color(0.85, 0.12, 0.1), ZONE, 0.4)
		p.add_child(mi)

func _plan_board() -> void:
	var bg := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.95, 0.75); bg.mesh = qm
	bg.material_override = Mats.tex(Tex.get_tex("paper"), ZONE)
	add_child(bg); bg.position = AT + (PLAN + Vector3(0, 0, 0.012))
	var t := Label3D.new(); t.text = "48 — as it was"; t.font_size = 28; t.pixel_size = 0.0014; t.modulate = Color(0.3, 0.3, 0.35)
	t.shaded = false; t.outline_size = 0; add_child(t); t.position = AT + (PLAN + Vector3(0, 0.33, 0.014))
	# the rooms, where they are on the plan (it's 47's plan, drawn small)
	var boxes := {"living": Vector2(-0.33, 0.14), "bedroom": Vector2(0.0, 0.14), "kitchen": Vector2(0.3, 0.14), "hall": Vector2(0.12, -0.04), "storage": Vector2(-0.33, -0.2), "child": Vector2(0.0, -0.2)}
	for r in boxes:
		var at := PLAN + Vector3(boxes[r].x, boxes[r].y, 0.03)
		var u := Usable.make(self, Transform3D(Basis(), local(at)), Vector3(0.2, 0.14, 0.04), [])
		u.title = ROOM_NAME[r]
		var l := Label3D.new(); l.text = ROOM_NAME[r]; l.font_size = 18; l.pixel_size = 0.0011; l.modulate = Color(0.35, 0.35, 0.4)
		l.shaded = false; l.outline_size = 0; add_child(l); l.position = AT + (at + Vector3(0, -0.05, -0.012))
		var n := Label3D.new(); n.text = ""; n.font_size = 20; n.pixel_size = 0.0011; n.modulate = Color(0.75, 0.08, 0.06)
		n.shaded = false; n.outline_size = 0; n.width = 160; n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(n); n.position = AT + (at + Vector3(0, 0.015, -0.012))
		_plan_lbls[r] = n
		var slot := String(r)
		u.offer = func(_k): return [{"id": "peel", "label": "Peel it off"}] if plan[slot] != "" else [{"id": "look", "label": "Look"}]
		u.set_meta("hold", func(k, held): return [{"id": "place", "label": "Stick it in the %s" % ROOM_NAME[slot], "held": true}] if held.item.begins_with("rednote:") and plan[slot] == "" else [])
		u.acted.connect(func(v, k): _plan_act(slot, v, k))

func _plan_act(slot: String, v: String, k) -> void:
	match v:
		"look":
			World.emit_event("looked", {"title": "Plan", "desc": "A box on the plan, pencilled: %s. Empty." % ROOM_NAME[slot], "key": "plan48"})
		"place":
			var from := String(k.held.item).substr(8)
			var h = k.held; k.held = null; h.queue_free()
			plan[slot] = from
			_refresh_plan()
			if not plan.values().has(""): _read_plan(k)
		"peel":
			var from: String = plan[slot]
			plan[slot] = ""
			_refresh_plan()
			k.give_item("rednote:" + from, "Red note", "A red sticky note: “%s”" % RED[from][1])

func _refresh_plan() -> void:
	for r in _plan_lbls:
		(_plan_lbls[r] as Label3D).text = String(RED[plan[r]][1]) if plan[r] != "" else ""

## Read the way you'd read a page: across the top, the hall, then the bottom.
func _read_plan(k) -> void:
	var words: Array = []
	var right := true
	for r in PLAN_ORDER:
		words.append(RED[plan[r]][1])
		if plan[r] != r: right = false
	var sentence := " ".join(words)
	if right:
		World.set_flag("48_plan")
		await Speech.say("kurt", "Sometimes it's easier to make the choice that makes no sense, when your back is against the wall", {"style": "quiet"})
		# behind the plan, where it was pinned: one more
		var p := Prop.make(self, Transform3D(Basis(), local(PLAN + Vector3(0, -0.5, 0.15))), Vector3(0.08, 0.01, 0.08), 0.01)
		p.key = "note51"; p.item = "note:51"; p.title = "Red note"; p.desc = "Red, like the others, and on its own: 51."
		p.stuff = "paper"
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.004, 0.08); mi.mesh = bm
		mi.material_override = Mats.flat(Color(0.85, 0.12, 0.1), ZONE, 0.4); p.add_child(mi)
		p.wake()
		World.emit_event("f48_plan", {})
	else:
		await Speech.say("kurt", sentence[0].to_upper() + sentence.substr(1) + "?", {"style": "quiet"})
		await Speech.say("kurt", "No. That's not it.", {"style": "quiet"})

# ------------------------------------------------------------------------------ the pointless door
func _pointless_door() -> void:
	var u := Usable.make(self, Transform3D(Basis(), local(POINTLESS + Vector3(0, 1.0, -0.02))), Vector3(0.75, 2.0, 0.08), [], true)
	u.title = "A door"
	var k := Kit.new()
	k.box(_block, local(POINTLESS + Vector3(0, 1.0, -0.03)), Vector3(0.75, 2.0, 0.05))
	k.box(Mats.flat(Color(0.6, 0.6, 0.6), ZONE), local(POINTLESS + Vector3(0.28, 1.0, -0.07)), Vector3(0.03, 0.03, 0.05))
	k.commit(self, "Pointless")
	_door_lbl = Label3D.new(); _door_lbl.font_size = 30; _door_lbl.pixel_size = 0.0015; _door_lbl.modulate = Color(0.15, 0.15, 0.2)
	_door_lbl.shaded = false; _door_lbl.outline_size = 0; _door_lbl.rotation.y = PI
	add_child(_door_lbl); _door_lbl.position = AT + (POINTLESS + Vector3(0, 1.5, -0.065))
	_refresh_door()
	u.offer = func(_k):
		var v: Array = [{"id": "open", "label": "Open"}]
		if pointless_label != "": v.append({"id": "peel", "label": "Peel the note off"})
		return v
	u.set_meta("hold", func(k2, held): return [{"id": "label", "label": "Stick it on the door", "held": true}] if held.item.begins_with("note:") and pointless_label == "" else [])
	u.acted.connect(_pointless_act)

func _pointless_act(v: String, k2) -> void:
	match v:
		"open": _pointless_open(k2)
		"peel":
			k2.give_item("note:" + pointless_label, "Note: " + pointless_label, "A yellow sticky note, in pencil: " + pointless_label)
			pointless_label = ""
			_refresh_door()
		"label":
			pointless_label = String(k2.held.item).substr(5)
			var h = k2.held; k2.held = null; h.queue_free()
			_refresh_door()
			World.emit_event("relabelled", {"word": pointless_label})

func _refresh_door() -> void:
	_door_lbl.text = pointless_label

## What a door is, is what's written on it.
func _pointless_open(k) -> void:
	Audio.play("creak", local(POINTLESS + Vector3(0, 1, 0)), -6.0)
	match pointless_label:
		"51", "44", "47": story.travel.call(pointless_label, false, "48door")
		"OUTSIDE":
			World.emit_event("looked", {"title": "", "desc": "White. All the way out. You shut it again before it can come in.", "key": "pointless_out"})
		_:
			var what := pointless_label if pointless_label != "" else "door"
			World.emit_event("looked", {"title": "", "desc": "It opens onto plaster. It's a %s, and that's all it's ever been." % what.to_lower(), "key": "pointless"})

# ------------------------------------------------------------------------------ saving
func _save() -> Dictionary:
	var real := []
	for i in blocks:
		if blocks[i].real: real.append(i)
	return {"real": real, "wall": wall_words, "plan": plan, "label": pointless_label, "safe": [safe_real, safe_open]}

func _load(d: Dictionary) -> void:
	for i in d.get("real", []):
		if blocks.has(int(i)) and not blocks[int(i)].real: _become(blocks[int(i)])
	wall_words = d.get("wall", wall_words); plan = d.get("plan", plan); pointless_label = String(d.get("label", pointless_label))
	var sf: Array = d.get("safe", [false, false]); safe_real = bool(sf[0]); safe_open = bool(sf[1])
	if safe_real: _safe_mesh.material_override = Mats.tex(Tex.get_tex("metal"), ZONE, Color(0.55, 0.62, 0.58))
	_refresh_wall(); _refresh_plan(); _refresh_door()
