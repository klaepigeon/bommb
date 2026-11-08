class_name Flat48
extends Node3D
## Flat 48, across the landing: Flat 47 as reality only sketched it. The same rooms, the same doors,
## in pale draft plaster with the room names pencilled on the walls; every piece of furniture a
## white block exactly where 47's is, with a paper tag on it that says what it was like, not what
## it is; three white figures standing in it, facing the walls, that turn when you aren't looking.
## (The JS build's "draft" flat, ported; the master documents' white-placeholder flat.)
##
## The rule of the place: what something is, is what's written on it. In the hall a wall of loose
## sticky notes, each with a word. Take one; stick it on a block. If the word is right, the block
## becomes the thing: Flat 47's own furniture, there, solid, with the note stuck to it. If it
## isn't, the note won't stay on. In the box room a tall narrow block whose tag says it's Papa's
## and nobody touches it; the GUN SAFE note makes it a steel cabinet, and in it, on two pegs, a
## sawn-off shotgun and a box of shells.
##
## The figures' names (MAMA, PAPA, CHILD on their tags) come later: who they are is the next part.

const AT := Vector3(0, 0, -400)          # far from 47 and the town; one place is shown at a time
const DRAFT := Color(0.86, 0.85, 0.81)
const BLOCK := Color(0.93, 0.93, 0.9)
const LABELS := {"living": "living room", "bedroom": "bedroom", "kitchen": "kitchen", "hall": "hall", "storage": "box room?", "child": "Sonya's", "bath": "bath + wc"}

## The blocks: [collider index in level.json, identity (the word that makes it real, or ""), tag]
const BLOCKS := [
	[23, "SOFA", "the green one with the burn"],
	[24, "", "something low, by the sofa"],
	[26, "TABLE", "three pale circles where the plates would go"],
	[25, "WALL UNIT", "the good glasses, the television, the doll"],
	[27, "", "turned to face the room"],
	[22, "RADIATOR", "warm, under the window"],
	[35, "BED", "two pillows; one side never slept on"],
	[38, "WARDROBE", "the back of it isn't the back of it"],
	[39, "", "her things, in rows"],
	[36, "", ""], [37, "", ""],
	[34, "RADIATOR", "warm, under the window"],
	[40, "", ""],
	[41, "RADIATOR", "warm, under the window"],
	[42, "", ""], [43, "SINK", "it drips"], [44, "", ""],
	[45, "COOKER", "four rings, one that works"],
	[46, "FRIDGE", "a note on the door: what did it say?"],
	[47, "", ""], [48, "", ""],
	[49, "TABLE", "the kitchen one, oilcloth"],
	[50, "SONYA'S BED", "smaller; rubbed out and written again"],
	[51, "", "a child's things"],
	[52, "", ""],
	[53, "BATH", "full, and black"],
	[54, "", ""], [55, "", ""], [56, "SINK", "a glass on it, two toothbrushes, one small"],
	[57, "SHELVES", "jars, and jars, and jars"],
	[58, "", ""], [59, "", ""],
	[21, "", "coats"], [28, "", "shoes, a red one"], [29, "", "keys go here"],
]
## Not in 47: Papa's gun safe, in the box room against the far wall. [centre x, z, half-size]
const SAFE_AT := Vector3(1.35, 0.0, 7.62)
const SAFE_HALF := Vector3(0.27, 0.73, 0.19)
## The note wall: the hall's north wall between the living room and the bedroom door.
const WALL_X0 := 4.62
const WALL_X1 := 6.38
const WALL_Z := 3.874
## The words on it: everything the blocks need, and some that fit nothing here.
const WORDS := ["SOFA", "TABLE", "WALL UNIT", "BED", "WARDROBE", "SINK", "COOKER", "FRIDGE", "TABLE",
	"SONYA'S BED", "BATH", "SINK", "SHELVES", "RADIATOR", "RADIATOR", "RADIATOR", "GUN SAFE",
	"PIANO", "DOG", "WINDOW", "HOME", "LATER"]

var main: Node
var world: Node3D
var player: Node
var env: Environment
var spawn := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(9.35, 0.0, 4.55))   # local: inside the front door
var blocks := {}                # Placeholder -> true
var figures: Array = []
var safe: GunSafe
var _draft: ShaderMaterial
var _block_mat: ShaderMaterial

signal transformed(block: Node, identity: String)

func build(p_main: Node) -> void:
	main = p_main; world = main.world; player = main.player
	name = "Flat48"
	position = AT
	_draft = _mat(DRAFT); _block_mat = _mat(BLOCK)
	_shell()
	_collision()
	_lights()
	_env()
	for b in BLOCKS:
		_block(b[0], b[1], b[2])
	safe = GunSafe.new(); safe.flat = self; add_child(safe); safe.position = SAFE_AT; safe.build()
	_note_wall()
	_figures()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/ps1.gdshader")
	m.set_shader_parameter("albedo_tex", TownKit._white())
	m.set_shader_parameter("albedo_color", c)
	m.set_shader_parameter("roughness", 1.0); m.set_shader_parameter("specular", 0.05)
	m.set_shader_parameter("emission", Vector3(c.r, c.g, c.b) * 0.03)
	return m

# ---------------------------------------------------------------- the rooms
## 47's own rooms and doors from the same export, everything else left out, all in draft plaster.
func _shell() -> void:
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Rooms"
	add_child(flat)
	for c in flat.get_children():
		var nm := String(c.name)
		var keep := nm.begins_with("door_")
		for r in LABELS:
			if nm.begins_with(r + "-"): keep = true
		if not keep: c.free()
	for mi in flat.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.material_override = _draft
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lv: Dictionary = world.get("level")
	for d in flat.find_children("door_*", "", false, false):
		if d.has_meta("extras"):
			var ex: Dictionary = (d.get_meta("extras") as Dictionary).duplicate()
			ex["locked"] = null                  # nothing in 48 is locked; it was never locked
			if String(d.name) == "door_dEntry": ex["open"] = 0.55
			d.set_script(load("res://scripts/world/door.gd")); d.call("setup", ex)
	# the room names in pencil, on a wall of each room, at eye height
	for id in LABELS:
		var r: Dictionary = lv.rooms[id]
		var l := Label3D.new(); l.text = LABELS[id]; l.font_size = 40; l.pixel_size = 0.0016
		l.modulate = Color(0.32, 0.32, 0.36, 0.85); l.shaded = true; l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		add_child(l)
		l.position = Vector3(r.x0 + 0.5 + (r.x1 - r.x0) * 0.15, 1.72, r.z0 + 0.075)
		if id == "hall": l.position = Vector3(8.6, 2.25, r.z0 + 0.075)
		l.rotation.z = randf_range(-0.04, 0.04)

func _collision() -> void:
	var lv: Dictionary = world.get("level")
	var walls := StaticBody3D.new(); walls.name = "Collision"; add_child(walls)
	var cols: Array = lv.colliders
	for i in cols.size():
		var c: Dictionary = cols[i]
		var wall: bool = float(c.y1) >= 3.0 and float(c.y0) <= -0.4
		if not ((i < 90 and wall) or (i >= 103 and i <= 120)): continue
		if absf(float(c.z) + 1.0) < 1.0 and float(c.z) < -0.3: continue      # the balcony's, outside
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		var h: float = c.y1 - c.y0
		b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0); sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	for f in lv.floors:
		if float(f.z1) <= 0.0: continue
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = Vector3(f.x1 - f.x0, 0.4, f.z1 - f.z0); sh.shape = b
		sh.position = Vector3((f.x0 + f.x1) * 0.5, f.y - 0.2, (f.z0 + f.z1) * 0.5)
		walls.add_child(sh)
	var ceil := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(11, 0.4, 9); ceil.shape = cb
	ceil.position = Vector3(5, 2.95, 4); walls.add_child(ceil)
	# the windows: white, overexposed, and nothing past them
	var stop := CollisionShape3D.new(); var sb := BoxShape3D.new(); sb.size = Vector3(11, 3.5, 0.3); stop.shape = sb
	stop.position = Vector3(5, 1.5, -0.3); walls.add_child(stop)

## One even, cold light per room, steady: nothing in 48 flickers, nothing casts a shadow.
func _lights() -> void:
	var lv: Dictionary = world.get("level")
	for id in lv.rooms:
		var r: Dictionary = lv.rooms[id]
		var l := OmniLight3D.new(); l.light_color = Color(0.93, 0.95, 1.0); l.light_energy = 0.42
		l.omni_range = maxf(r.x1 - r.x0, r.z1 - r.z0) * 0.95 + 1.2; l.omni_attenuation = 0.8; l.shadow_enabled = false
		l.light_specular = 0.1
		add_child(l); l.position = Vector3((r.x0 + r.x1) * 0.5, 2.3, (r.z0 + r.z1) * 0.5)

func _env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(1, 1, 1); env.background_energy_multiplier = 1.6
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.86); env.ambient_light_energy = 0.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true; env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.9, 0.9, 0.9); env.fog_density = 0.012; env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 0.95

# ---------------------------------------------------------------- the blocks
func _block(index: int, identity: String, tag: String) -> void:
	var c: Dictionary = (world.get("level") as Dictionary).colliders[index]
	var p := Placeholder.new(); p.flat = self; p.identity = identity; p.tag = tag; p.index = index
	p.half = Vector3(c.hx, (c.y1 - maxf(c.y0, 0.0)) * 0.5, c.hz)
	add_child(p)
	p.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, maxf(c.y0, 0.0) + p.half.y, c.z))
	p.build(_block_mat)
	blocks[p] = true

## Flat 47's meshes that stood inside this block's space: copied in, here, as the real thing.
func realise(p: Placeholder) -> int:
	var apt: Node = world.get_node("Apartment")
	var inv := p.transform.affine_inverse()     # 47 is at the origin, so 47's world = 48's local
	var n := 0
	var real := Node3D.new(); real.name = "Real_%s" % p.identity; add_child(real)
	for mi in apt.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if String(m.name).contains("-"): continue                     # the room shells
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > 4.0 or a.size.length() < 0.004: continue
		var lc := inv * a.get_center()
		var h := p.half + Vector3(0.06, 0.06, 0.06)
		if absf(lc.x) > h.x or absf(lc.z) > h.z or lc.y < -h.y - 0.05 or lc.y > h.y + 0.45: continue
		var d := m.duplicate(0) as MeshInstance3D
		for ch in d.get_children(): ch.free()
		real.add_child(d)
		d.transform = m.global_transform
		n += 1
	p.real = real
	return n

# ---------------------------------------------------------------- the note wall
func _note_wall() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4848
	var cols := 6
	for i in WORDS.size():
		var cx := i % cols; var cy := i / cols
		var x := lerpf(WALL_X0 + 0.12, WALL_X1 - 0.12, cx / float(cols - 1)) + rng.randf_range(-0.04, 0.04)
		var y := 1.9 - cy * 0.24 + rng.randf_range(-0.03, 0.03)
		var n := WallNote.new(); n.flat = self; n.word = WORDS[i]; n.wall_id = i
		add_child(n)
		n.position = Vector3(x, y, WALL_Z + 0.004)
		n.rotation.z = rng.randf_range(-0.18, 0.18)
		n.build()
	var head := Label3D.new(); head.text = "what it is"; head.font_size = 36; head.pixel_size = 0.0016
	head.modulate = Color(0.3, 0.3, 0.34); head.shaded = true; head.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	add_child(head); head.position = Vector3((WALL_X0 + WALL_X1) * 0.5, 2.18, WALL_Z + 0.003)

static func note_mesh(word: String, parent: Node3D) -> void:
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.09, 0.09); q.mesh = qm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.98, 0.9, 0.36); m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material_override = m; parent.add_child(q)
	var l := Label3D.new(); l.text = word; l.font_size = 30 if word.length() < 9 else 22; l.pixel_size = 0.001
	l.modulate = Color(0.12, 0.12, 0.16); l.outline_size = 0; l.position = Vector3(0, 0, 0.0015)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.width = 82.0; l.double_sided = false
	parent.add_child(l)

## A note off the wall into Kurt's hand: a little prop, light as paper, that knows its word.
func take_note(n: WallNote) -> void:
	var holder := Node3D.new(); holder.name = "Note_%s" % n.word
	note_mesh(n.word, holder)
	add_child(holder); holder.global_transform = n.global_transform
	var body: RigidBody3D = load("res://scripts/world/prop.gd").make(holder, {"name": "Sticky note: %s" % n.word, "desc": "A yellow sticky note. In neat capitals: %s." % n.word, "mass": 0.02, "size": [0.076, 0.076, 0.01], "centre": [0, 0, 0]})
	body.set_meta("identity", n.word); body.set_meta("wall_id", n.wall_id)
	body.linear_damp = 6.0; body.angular_damp = 6.0
	body.global_position = player.get("hold").global_position
	n.queue_free()
	player.call("grab", body)
	Game.flags["f48_notes_taken"] = (Game.flags.get("f48_notes_taken", []) as Array) + [n.wall_id]

# ---------------------------------------------------------------- the three of them
func _figures() -> void:
	for f in [["mama", Vector3(9.2, 0, 2.65), 1.72, "MAMA", "At the stove. A paper tag pinned where a heart would be: MAMA."],
			["papa", Vector3(6.0, 0, 0.55), 1.84, "PAPA", "At the bedroom window, looking out at the white. The tag: PAPA."],
			["child", Vector3(3.3, 0, 6.3), 1.22, "CHILD", "By the small bed. The tag says CHILD, and it's the only one with a drawing on it: a house with black windows."]]:
		var g := Figure48.new(); g.flat = self; g.id = f[0]; g.tall = f[2]; g.tag = f[3]; g.desc = f[4]
		add_child(g); g.position = f[1]; g.build()
		figures.append(g)

# ---------------------------------------------------------------- saving
func save_state() -> Dictionary:
	var real := []
	for p in blocks:
		if (p as Placeholder).real: real.append((p as Placeholder).index)
	var shot := {}
	for g in figures: shot[g.id] = g.down
	return {"real": real, "safe_real": safe.real, "safe_open": safe.open, "gun_taken": safe.gun_taken, "shells_taken": safe.shells_taken, "shot": shot}

func restore(d: Dictionary) -> void:
	var real: Array = d.get("real", [])
	for p in blocks:
		var pl := p as Placeholder
		if real.has(float(pl.index)) or real.has(pl.index): pl.make_real(true)
	for wid in Game.flags.get("f48_notes_taken", []):
		for n in find_children("*", "", false, false):
			if n is WallNote and (n as WallNote).wall_id == int(wid): n.free()
	if real.has(-1.0) or real.has(-1) or d.get("safe_real", false): safe.make_real(true)
	if d.get("safe_open", false): safe.set_open(true, true)
	if d.get("gun_taken", false): safe.take_gun(true)
	if d.get("shells_taken", false): safe.take_shells(true)
	var shot: Dictionary = d.get("shot", {})
	for g in figures:
		if shot.get(g.id, false): g.fall(true)

# ================================================================ the pieces
## A white block where a piece of 47's furniture is. Its tag is a clue, not a name.
class Placeholder extends StaticBody3D:
	var flat: Flat48
	var identity := ""
	var tag := ""
	var index := 0
	var half := Vector3.ONE * 0.3
	var mesh: MeshInstance3D
	var real: Node3D

	func build(mat: Material) -> void:
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0; cs.shape = b; add_child(cs)
		mesh = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = half * 2.0; mesh.mesh = bm
		mesh.material_override = mat; add_child(mesh)
		if tag != "":
			var t := Label3D.new(); t.text = tag; t.font_size = 24; t.pixel_size = 0.0012
			t.modulate = Color(0.25, 0.25, 0.3); t.shaded = true; t.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			t.autowrap_mode = TextServer.AUTOWRAP_WORD; t.width = 260.0
			add_child(t)
			t.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, randf_range(-0.3, 0.3)), Vector3(0, half.y + 0.002, 0))

	func prompt() -> String:
		return "" if real else "Look at it"

	func interact(_p: Node) -> void:
		Game.say(("A white block, the size of something. On a paper tag, in pencil: “%s”." % tag) if tag != "" else "A white block, the size of something. No tag. Nobody's said what it is.", 5.0)

	func use_with_prompt(item: Node) -> String:
		return "Stick the note on it" if not real and item.has_meta("identity") else ""

	func use_with(p: Node, item: Node) -> bool:
		if real or not item.has_meta("identity"): return false
		var word := String(item.get_meta("identity"))
		if identity != "" and word == identity:
			p.set("held", null); item.queue_free()
			make_real(false)
			return true
		# the wrong word: it won't stay on
		p.call("drop")
		Game.say("It won't stay on. Not that." if identity != "" else "It won't stay on. Nothing will, on this one. Not yet.", 3.0)
		return true

	func make_real(quiet: bool) -> void:
		if real: return
		var n := flat.realise(self)
		mesh.visible = false
		for ch in get_children(): if ch is Label3D: ch.visible = false
		# the note stays on it, on top, where it was stuck
		var note := Node3D.new(); add_child(note)
		note.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, randf_range(-0.4, 0.4)), Vector3(randf_range(-0.1, 0.1), half.y + 0.012, 0))
		Flat48.note_mesh(identity, note)
		Game.flags["f48_real_%d" % index] = true
		if not quiet:
			_flash()
			Game.say("The note stays. And it's a %s: it always was. %s" % [identity.to_lower(), "" if n > 0 else "(There's nothing in it.)"], 4.0)
			flat.transformed.emit(self, identity)

	func _flash() -> void:
		var l := OmniLight3D.new(); l.light_color = Color(1, 1, 0.95); l.omni_range = 2.5; l.light_energy = 3.0; add_child(l)
		l.position = Vector3(0, half.y, 0)
		var tw := create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.6); tw.tween_callback(l.queue_free)
		var ap := AudioStreamPlayer3D.new(); ap.stream = Flat48._thrum(); add_child(ap); ap.play(); ap.finished.connect(ap.queue_free)

## One loose note on the hall wall.
class WallNote extends StaticBody3D:
	var flat: Flat48
	var word := ""
	var wall_id := 0
	func build() -> void:
		Flat48.note_mesh(word, self)
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.08, 0.08, 0.02); cs.shape = b; add_child(cs)
	func prompt() -> String:
		return "Take the note: %s" % word
	func interact(_p: Node) -> void:
		flat.take_note(self)

## Papa's gun safe: a white block until it's called what it is; then a Soviet hunting-gun cabinet,
## green-grey sheet steel, two lock barrels, a handle; inside on two pegs the sawn-off, and a box
## of shells on the shelf.
class GunSafe extends StaticBody3D:
	var flat: Flat48
	var real := false
	var open := false
	var gun_taken := false
	var shells_taken := false
	var block: MeshInstance3D
	var tag: Label3D
	var door: Node3D
	var gun: Shotgun
	var shells: Node3D
	var _door_t := 0.0

	func build() -> void:
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Flat48.SAFE_HALF * 2.0; cs.shape = b; cs.position.y = Flat48.SAFE_HALF.y; add_child(cs)
		block = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Flat48.SAFE_HALF * 2.0; block.mesh = bm
		block.material_override = flat._block_mat; block.position.y = Flat48.SAFE_HALF.y; add_child(block)
		tag = Label3D.new(); tag.text = "PAPA'S. Locked. Nobody touches it."; tag.font_size = 24; tag.pixel_size = 0.0012
		tag.modulate = Color(0.25, 0.25, 0.3); tag.shaded = true; tag.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD; tag.width = 200.0
		add_child(tag); tag.position = Vector3(0, 1.1, -Flat48.SAFE_HALF.z - 0.002); tag.rotation.y = PI

	func prompt() -> String:
		if not real: return "Look at it"
		return "Close the safe" if open else "Open the safe"

	func interact(_p: Node) -> void:
		if not real:
			Game.say("A tall narrow block against the wall, steel-cold when you touch it, which a block shouldn't be. The tag: “PAPA'S. Locked. Nobody touches it.”", 5.0)
			return
		set_open(not open, false)

	func use_with_prompt(item: Node) -> String:
		return "Stick the note on it" if not real and item.has_meta("identity") else ""

	func use_with(p: Node, item: Node) -> bool:
		if real or not item.has_meta("identity"): return false
		if String(item.get_meta("identity")) == "GUN SAFE":
			p.set("held", null); item.queue_free()
			make_real(false)
		else:
			p.call("drop"); Game.say("It won't stay on. Not that.", 3.0)
		return true

	func make_real(quiet: bool) -> void:
		if real: return
		real = true
		block.visible = false; tag.visible = false
		_cabinet()
		Game.flags["f48_safe_real"] = true
		if not quiet:
			Game.say("The note holds. Steel, green-grey, two locks, a handle worn bright. A gun safe. Of course it is: the law said a hunting gun lives in one.", 5.0)
			flat.transformed.emit(self, "GUN SAFE")

	func _cabinet() -> void:
		var h := Flat48.SAFE_HALF
		var k := TownKit.new(self)
		# the carcass: back, sides, top, bottom; the open front faces -z (into the room)
		k.box("safe_paint", Vector3(0, h.y, h.z - 0.01), Vector3(h.x, h.y, 0.01))
		k.box("safe_paint", Vector3(-h.x + 0.01, h.y, 0), Vector3(0.01, h.y, h.z))
		k.box("safe_paint", Vector3(h.x - 0.01, h.y, 0), Vector3(0.01, h.y, h.z))
		k.box("safe_paint", Vector3(0, h.y * 2.0 - 0.01, 0), Vector3(h.x, 0.01, h.z))
		k.box("safe_paint", Vector3(0, 0.03, 0), Vector3(h.x, 0.03, h.z))
		# inside: a shelf near the top, two pegs on the back for a gun, felt on the floor
		k.box("safe_paint", Vector3(0, h.y * 2.0 - 0.3, 0.02), Vector3(h.x - 0.02, 0.008, h.z - 0.03))
		k.box("cloth_dark", Vector3(0, 0.062, 0.0), Vector3(h.x - 0.02, 0.002, h.z - 0.02))
		# a pale baize lining on the back, so what hangs there stands out against it
		k.box("baize", Vector3(0, h.y, h.z - 0.022), Vector3(h.x - 0.025, h.y - 0.08, 0.002))
		for py in [0.55, 0.95]:
			k.cyl_axis("iron", Vector3(-0.05, py, h.z - 0.02), Vector3(-0.05, py, h.z - 0.09), 0.008, 6)
		k.finish()
		# the door: hinged on the left, two lock barrels and a T-handle
		door = Node3D.new(); door.name = "Door"; add_child(door); door.position = Vector3(-h.x, 0, -h.z)
		var kd := TownKit.new(door)
		kd.box("safe_paint", Vector3(h.x, h.y, -0.012), Vector3(h.x, h.y, 0.012))
		for ly in [0.55, 1.15]:
			kd.cyl_axis("gold", Vector3(h.x * 1.75, ly, -0.025), Vector3(h.x * 1.75, ly, -0.035), 0.012, 10)
			kd.box("iron", Vector3(h.x * 1.75, ly, -0.036), Vector3(0.002, 0.007, 0.001))
		kd.box("iron", Vector3(h.x * 1.75, 0.85, -0.04), Vector3(0.008, 0.008, 0.016))
		kd.box("iron", Vector3(h.x * 1.75, 0.85, -0.058), Vector3(0.05, 0.008, 0.007))
		kd.finish()
		# the sawn-off on its pegs, standing on its butt, muzzle up; the shells on the shelf
		if not gun_taken:
			gun = Shotgun.new(); add_child(gun)
			gun.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI), Vector3(-0.05, 0.42, h.z - 0.07))
			gun.set_process(false); gun.set_process_unhandled_input(false)
			var gh := Hotspot.make(self, global_transform * Vector3(-0.05, 0.62, h.z - 0.07), Vector3(0.1, 0.5, 0.1), "Take the shotgun", func(): take_gun(false))
			gh.name = "GunHotspot"
		if not shells_taken:
			shells = Node3D.new(); add_child(shells); shells.position = Vector3(0.12, h.y * 2.0 - 0.29, 0.0)
			var ks := TownKit.new(shells)
			ks.box("paper_old", Vector3(0, 0.035, 0), Vector3(0.05, 0.035, 0.035))
			for i in 4:
				ks.cyl("lipstick", Vector3(-0.03 + i * 0.02, 0.07, 0.015), 0.009, 0.03, 6)
			ks.finish()
			var sh := Hotspot.make(self, shells.global_position + Vector3(0, 0.04, 0), Vector3(0.12, 0.09, 0.09), "Take the shells", func(): take_shells(false))
			sh.name = "ShellsHotspot"
		set_open(false, true)

	func set_open(o: bool, quiet: bool) -> void:
		open = o
		if door: door.rotation.y = 1.9 if open else 0.0
		# what's inside can only be reached with the door open
		for n in get_children():
			if n is Hotspot: (n as Hotspot).collision_layer = 1 if open else 0
		if not quiet:
			Game.flags["f48_safe_open"] = open
			if open and not gun_taken:
				Game.say("It isn't locked. Inside, on two pegs, standing on what's left of its stock: a shotgun, sawn off short. The cuts are bright and not quite square.", 6.0)
				flat.transformed.emit(self, "OPENED")

	func take_gun(quiet: bool) -> void:
		if gun_taken: return
		gun_taken = true
		var gh := get_node_or_null("GunHotspot"); if gh: gh.queue_free()
		if not gun:
			gun = Shotgun.new(); add_child(gun)
		gun.set_process(true); gun.set_process_unhandled_input(true)
		gun.equip(flat.player)
		Game.flags["has_shotgun"] = true
		if not quiet:
			Game.say("It comes off the pegs into your hand and your hand knows where everything is. The top lever. The fore-end catch. Two triggers.", 5.5)
			flat.transformed.emit(self, "SHOTGUN")

	func take_shells(quiet: bool) -> void:
		if shells_taken: return
		shells_taken = true
		var sh := get_node_or_null("ShellsHotspot"); if sh: sh.queue_free()
		if shells: shells.queue_free()
		var g = flat.player.get("armory").call("get_kind", "shotgun") if flat.player.get("armory") else null
		if g: g.spare += 10
		else: Game.flags["pocket_shells"] = int(Game.flags.get("pocket_shells", 0)) + 10
		if not quiet: Game.say("A paper box of twelve-bore shells, buckshot. Ten left.", 3.0)

## One of the three: a white standing figure, wrong in its proportions (the neck too long, the
## head too small, the arms too long), a paper tag pinned on. When you aren't looking at it, it
## turns a little toward you. It can be shot; then it's down, for good.
class Figure48 extends StaticBody3D:
	var flat: Flat48
	var id := ""
	var tall := 1.7
	var tag := ""
	var desc := ""
	var down := false
	var hits := 0
	var body: Node3D

	func build() -> void:
		body = Node3D.new(); add_child(body)
		var m: Material = flat._block_mat
		var h := tall
		_part(m, Vector3(0, h * 0.18 + h * 0.31, 0), Vector3(h * 0.12, h * 0.31, h * 0.075))         # the trunk
		_part(m, Vector3(0, h * 0.86, 0), Vector3(h * 0.055, h * 0.06, h * 0.06))                     # the head, small
		_part(m, Vector3(0, h * 0.79, 0), Vector3(h * 0.025, h * 0.04, h * 0.025))                    # the neck, long
		for s in [-1.0, 1.0]:
			_part(m, Vector3(s * h * 0.05, h * 0.1, 0), Vector3(h * 0.04, h * 0.1, h * 0.04))         # legs
			_part(m, Vector3(s * h * 0.15, h * 0.42, 0), Vector3(h * 0.025, h * 0.27, h * 0.025))     # arms, too long
		var t := Label3D.new(); t.text = tag; t.font_size = 26; t.pixel_size = 0.0013
		t.modulate = Color(0.2, 0.2, 0.26); t.shaded = true; t.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		body.add_child(t); t.position = Vector3(-h * 0.04, h * 0.66, -h * 0.076); t.rotation.y = PI
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(h * 0.3, h, h * 0.18); cs.shape = b; cs.position.y = h * 0.5; add_child(cs)
		var hs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = h * 0.07; hs.shape = sp; hs.position.y = h * 0.86; add_child(hs)
		rotation.y = atan2(position.x - 5.0, position.z - 4.0)     # facing away from the middle of the flat

	func _part(m: Material, at: Vector3, half: Vector3) -> void:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = half * 2.0; mi.mesh = bm; mi.material_override = m
		body.add_child(mi); mi.position = at

	func prompt() -> String:
		return "Look at it" if not down else ""

	func interact(_p: Node) -> void:
		Game.say(desc, 5.0)
		Game.flags["f48_looked_" + id] = true

	func _process(delta: float) -> void:
		if down or not flat.visible: return
		var cam := get_viewport().get_camera_3d()
		if not cam: return
		var at := global_position + Vector3(0, tall * 0.5, 0)
		var seen := not cam.is_position_behind(at) and Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(cam.unproject_position(at))
		if seen: return
		var want := atan2(cam.global_position.x - global_position.x, cam.global_position.z - global_position.z) + PI
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 0.25))

	func shot(_point: Vector3, _n: Vector3, _hk: bool, _shape: int) -> bool:
		if down: return false
		hits += 1
		Game.flags["f48_shot_" + id] = true
		fall(false)
		return true

	func fall(quiet: bool) -> void:
		down = true
		var tw := create_tween() if not quiet else null
		if tw:
			tw.tween_property(body, "rotation:x", -PI * 0.48, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(body, "position:y", -tall * 0.02, 0.5)
		else:
			body.rotation.x = -PI * 0.48
		for c in get_children(): if c is CollisionShape3D: (c as CollisionShape3D).disabled = true
		if not quiet:
			flat.transformed.emit(self, "SHOT")

## the sound of a thing becoming what it is: a low swell and a paper snap
static func _thrum() -> AudioStreamWAV:
	const R := 22050
	var n := int(R * 0.9); var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / R
		s[i] = sin(TAU * 110.0 * t) * sin(PI * t / 0.9) * 0.5 + sin(TAU * 220.5 * t) * sin(PI * t / 0.9) * 0.2 + (randf() - 0.5) * exp(-t * 40.0) * 0.6
	return FlatEscape._wav(s, R)
