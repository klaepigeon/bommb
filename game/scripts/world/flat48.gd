class_name Flat48
extends Node3D
## Flat 48, across the landing: Flat 47 as reality only sketched it. The same rooms and doors in
## pale draft plaster, the room names pencilled on the walls; every piece of furniture a white
## block exactly where 47's is, with a paper tag that says what it was like, not what it is; three
## white figures that turn toward you when you aren't looking.
##
## The rule of the place: what something is, is what's written on it. In the hall, a wall of
## loose sticky notes. Take one (it's in Kurt's hand); stick it on a block. The right word and the
## block becomes the thing: Flat 47's own furniture, there, solid, the note stuck on it. The wrong
## word won't stay on. A note can be peeled off again (the thing goes back to a block) and put
## back on the wall. The GUN SAFE note makes the tall block in the box room a steel cabinet with
## a sawn-off shotgun on its pegs. MARTA and KURT dress two of the figures. SONYA won't stay on
## the third: she isn't here.
##
## The data (blocks, tags, words, texts) is content/flat48.json.

signal transformed(what: String, thing: Node)

const AT := Vector3(0, 0, -400)          # far from 47 and the town; one place is shown at a time
const DRAFT := Color(0.86, 0.85, 0.81)
const BLOCK := Color(0.93, 0.93, 0.9)
const SAFE_AT := Vector3(1.35, 0.0, 7.62)
const SAFE_HALF := Vector3(0.27, 0.73, 0.19)
const WALL_X0 := 4.62
const WALL_X1 := 6.38
const WALL_Z := 3.874

var flat47: Flat47
var weapon: Weapon
var hud: Hud
var data := {}
var spawn := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(9.35, 0.0, 4.55))    # local: inside the front door
var entry: HingeDoor
var blocks: Array = []
var figures: Array = []
var safe: GunSafe
var pointless: Usable48
var slots := {}                 ## note id -> {pos, rot, word, node (or null when it's off the wall)}
var _draft: ShaderMaterial
var _block_mat: ShaderMaterial

func build(p_flat47: Flat47, p_weapon: Weapon, p_hud: Hud) -> void:
	flat47 = p_flat47; weapon = p_weapon; hud = p_hud
	name = "Flat48"
	position = AT
	data = JSON.parse_string(FileAccess.get_file_as_string("res://content/flat48.json"))
	_draft = _mat(DRAFT)
	_block_mat = _mat(BLOCK)
	_shell()
	_collision()
	_lights()
	for b in data["blocks"]:
		_block(int(b[0]), String(b[1]), String(b[2]))
	safe = GunSafe.new(); safe.flat = self
	add_child(safe); safe.position = SAFE_AT; safe.build()
	_note_wall()
	_figures()
	_pointless_door()

func text(key: String) -> String:
	return String(data["captions"].get(key, key))

func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ps1_lit.gdshader")
	m.set_shader_parameter("albedo_tex", TownKit._white())
	m.set_shader_parameter("albedo_color", c)
	m.set_shader_parameter("roughness", 1.0)
	m.set_shader_parameter("specular", 0.05)
	m.set_shader_parameter("emission", Vector3(c.r, c.g, c.b) * 0.03)
	return m

func apply_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 1, 1)
	env.background_energy_multiplier = 1.6
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.86)
	env.ambient_light_energy = 0.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.9, 0.9)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95

# --- the rooms ----------------------------------------------------------------------------------

## 47's own rooms and doors from the same model, everything else left out, all in draft plaster.
func _shell() -> void:
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Rooms"
	add_child(flat)
	var labels: Dictionary = data["room_labels"]
	for c in flat.get_children():
		var nm := String(c.name)
		var keep := nm.begins_with("door_")
		for r in labels:
			if nm.begins_with(String(r) + "-"):
				keep = true
		if not keep:
			c.free()
	for mi in flat.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.material_override = _draft
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for d in flat.find_children("door_*", "", false, false):
		if d.has_meta("extras"):
			var ex: Dictionary = (d.get_meta("extras") as Dictionary).duplicate()
			if String(d.name) == "door_dEntry":
				ex["open"] = 0.55
				ex["max"] = 0.56
			d.set_script(load("res://scripts/world/hinge_door.gd"))
			d.call("setup", ex)         # nothing in 48 is locked; it was never locked
			if String(d.name) == "door_dEntry":
				entry = d
				entry.custom = true
				entry.body.set("prompt", "Leave")
	# the room names in pencil, on a wall of each room, at eye height
	var rooms: Dictionary = flat47.level.rooms
	for id in labels:
		var r: Dictionary = rooms[id]
		var l := Label3D.new(); l.text = labels[id]; l.font_size = 40; l.pixel_size = 0.0016
		l.modulate = Color(0.32, 0.32, 0.36, 0.85); l.shaded = true; l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		add_child(l)
		l.position = Vector3(r.x0 + 0.5 + (r.x1 - r.x0) * 0.15, 1.72, r.z0 + 0.075)
		if id == "hall":
			l.position = Vector3(8.6, 2.25, r.z0 + 0.075)
		if id in ["living", "bedroom", "kitchen"]:      # their north walls are mostly window
			l.position = Vector3(r.x0 + 0.075 + (0.07 if id != "living" else 0.0), 1.72, {"living": 3.4, "bedroom": 3.2, "kitchen": 2.6}[id])
			l.rotation.y = PI * 0.5
		l.rotation.z = randf_range(-0.04, 0.04)

func _collision() -> void:
	var lv: Dictionary = flat47.level
	var walls := StaticBody3D.new(); walls.name = "Collision"; add_child(walls)
	var cols: Array = lv.colliders
	for i in cols.size():
		var c: Dictionary = cols[i]
		var wall: bool = float(c.y1) >= 3.0 and float(c.y0) <= -0.4
		if not ((i < 60 and wall) or (i >= 103 and i <= 120)):
			continue
		if absf(float(c.z) + 1.0) < 1.0 and float(c.z) < -0.3:      # the balcony's, outside
			continue
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		var h: float = c.y1 - c.y0
		b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0); sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	var fl := CollisionShape3D.new(); var fb := BoxShape3D.new(); fb.size = Vector3(11.5, 0.4, 9.0); fl.shape = fb
	fl.position = Vector3(5, -0.2, 4); walls.add_child(fl)
	var ceil := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(11, 0.4, 9); ceil.shape = cb
	ceil.position = Vector3(5, 2.95, 4); walls.add_child(ceil)
	# the windows and the front doorway: white, overexposed, and nothing past them
	for box in [[Vector3(5, 1.5, -0.3), Vector3(11, 3.5, 0.3)], [Vector3(10.6, 1.5, 4.56), Vector3(0.3, 3.5, 1.4)]]:
		var stop := CollisionShape3D.new(); var sb := BoxShape3D.new(); sb.size = box[1]; stop.shape = sb
		stop.position = box[0]; walls.add_child(stop)

## One even, cold light per room, steady: nothing in 48 flickers, nothing casts a shadow.
func _lights() -> void:
	var rooms: Dictionary = flat47.level.rooms
	for id in rooms:
		var r: Dictionary = rooms[id]
		var l := OmniLight3D.new(); l.light_color = Color(0.93, 0.95, 1.0); l.light_energy = 0.42
		l.omni_range = maxf(r.x1 - r.x0, r.z1 - r.z0) * 0.95 + 1.2; l.omni_attenuation = 0.8; l.shadow_enabled = false
		l.light_specular = 0.1
		add_child(l); l.position = Vector3((r.x0 + r.x1) * 0.5, 2.3, (r.z0 + r.z1) * 0.5)

# --- the blocks -----------------------------------------------------------------------------------

func _block(index: int, identity: String, tag: String) -> void:
	var c: Dictionary = flat47.level.colliders[index]
	var p := Placeholder.new(); p.flat = self; p.identity = identity; p.tag = tag; p.index = index
	p.half = Vector3(c.hx, (c.y1 - maxf(c.y0, 0.0)) * 0.5, c.hz)
	add_child(p)
	p.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, maxf(c.y0, 0.0) + p.half.y, c.z))
	p.build(_block_mat)
	blocks.append(p)

## Flat 47's meshes that stand inside this block's space: copied in, here, as the real thing.
func realise(p: Placeholder) -> Node3D:
	var apt: Node = flat47.get_node("Apartment")
	var inv := p.transform.affine_inverse()     # 47 is at the origin, so 47's world = 48's local
	var real := Node3D.new(); real.name = "Real_%s" % p.identity
	add_child(real)
	var n := 0
	for mi in apt.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if String(m.name).contains("-"):                 # the room shells
			continue
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > 4.0 or a.size.length() < 0.004:
			continue
		var lc := inv * a.get_center()
		var h := p.half + Vector3(0.06, 0.06, 0.06)
		if absf(lc.x) > h.x or absf(lc.z) > h.z or lc.y < -h.y - 0.05 or lc.y > h.y + 0.45:
			continue
		var d := m.duplicate(0) as MeshInstance3D
		for ch in d.get_children():
			ch.free()
		real.add_child(d)
		d.transform = m.global_transform
		d.visible = true
		n += 1
	real.set_meta("count", n)
	return real

## The flash and the sound of a thing becoming what it is.
func flash(at: Vector3) -> void:
	var l := OmniLight3D.new(); l.light_color = Color(1, 1, 0.95); l.omni_range = 2.5; l.light_energy = 3.0
	l.shadow_enabled = false
	add_child(l); l.position = at
	var tw := l.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.6); tw.tween_callback(l.queue_free)
	Sfx.play_at("thrum", to_global(at), 2.0)

# --- the note wall --------------------------------------------------------------------------------

func _note_wall() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4848
	var words: Array = data["words"]
	var cols := 6
	for i in words.size():
		var cx := i % cols; var cy := i / cols
		var x := lerpf(WALL_X0 + 0.12, WALL_X1 - 0.12, cx / float(cols - 1)) + rng.randf_range(-0.04, 0.04)
		var y := 1.9 - cy * 0.24 + rng.randf_range(-0.03, 0.03)
		slots[i] = {"pos": Vector3(x, y, WALL_Z + 0.004), "rot": rng.randf_range(-0.18, 0.18), "word": String(words[i]), "node": null}
		_put_on_wall(i)
	var head := Label3D.new(); head.text = String(data["wall_heading"]); head.font_size = 36; head.pixel_size = 0.0016
	head.modulate = Color(0.3, 0.3, 0.34); head.shaded = true; head.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	add_child(head); head.position = Vector3((WALL_X0 + WALL_X1) * 0.5, 2.18, WALL_Z + 0.003)
	# the wall itself: where a note in the hand goes back
	var board := Usable48.new(); board.name = "NoteWall"
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(WALL_X1 - WALL_X0, 1.5, 0.01); cs.shape = b
	board.add_child(cs)
	board.collision_layer = 8
	add_child(board); board.position = Vector3((WALL_X0 + WALL_X1) * 0.5, 1.4, WALL_Z - 0.002)
	board.prompt_fn = func() -> String: return "Put the note back" if holding_wall_note() else ""
	board.used.connect(put_note_back)

func _put_on_wall(id: int) -> void:
	var s: Dictionary = slots[id]
	var n := WallNote.new(); n.flat = self; n.word = s["word"]; n.wall_id = id
	add_child(n)
	n.position = s["pos"]
	n.rotation.z = s["rot"]
	n.build()
	s["node"] = n

## Is the note in his hand one of this wall's?
func holding_wall_note() -> bool:
	return weapon.held == "note" and slots.has(weapon.note_id)

func holding_note() -> bool:
	return weapon.held == "note"

## A note off the wall into Kurt's hand. If he's holding one already, that one goes back first.
func take_note(n: WallNote) -> void:
	if holding_wall_note():
		_put_on_wall(weapon.note_id)
	Sfx.play_at("paper", n.global_position, 0.0)
	slots[n.wall_id]["node"] = null
	weapon.take_note(n.word, n.wall_id)
	n.queue_free()
	var taken: Array = Game.flags.get("f48_notes_taken", [])
	if not taken.has(n.wall_id):
		taken.append(n.wall_id)
	Game.flags["f48_notes_taken"] = taken
	transformed.emit("NOTE_TAKEN", n)

func put_note_back() -> void:
	if not holding_wall_note():
		return
	_put_on_wall(weapon.note_id)
	Sfx.play_at("paper", (slots[weapon.note_id]["node"] as Node3D).global_position, -4.0, 1.2)
	weapon.clear_note()
	hud.caption(text("note_back"), 2.0)

## The wrong word: it's on for a moment, then it lets go and it's back in his hand.
func reject(at_global: Vector3, key: String) -> void:
	var temp := Node3D.new(); add_child(temp)
	temp.global_position = at_global
	temp.rotation.x = -PI * 0.5
	Weapon.make_note(weapon.note_word, temp)
	weapon.note_mesh.visible = false
	Sfx.play_at("paper", at_global, -2.0, 0.8)
	hud.caption(text(key), 3.0)
	var tw := temp.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(temp, "position:y", temp.position.y - 0.25, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(temp, "rotation:z", 1.2, 0.35)
	tw.tween_callback(func():
		temp.queue_free()
		if weapon.held == "note":
			weapon.note_mesh.visible = true)

## The note stuck on a thing: a small yellow square you can peel off again.
func stick_note(on: Node3D, local: Transform3D, word: String, id: int, peel: Callable) -> StuckNote:
	var s := StuckNote.new(); s.word = word; s.wall_id = id
	on.add_child(s)
	s.transform = local
	Weapon.make_note(word, s)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.1, 0.1, 0.03); cs.shape = b
	s.add_child(cs)
	s.collision_layer = 8
	s.prompt_fn = func() -> String: return "" if holding_note() else "Peel the note off"
	s.used.connect(peel)
	return s

# --- the three of them ---------------------------------------------------------------------------

func _figures() -> void:
	var figs: Dictionary = data["figures"]
	for id in ["mama", "papa", "child"]:
		var f: Dictionary = figs[id]
		var g := Figure48.new(); g.flat = self; g.id = id; g.tall = float(f["tall"]); g.info = f
		add_child(g)
		g.position = Vector3(f["at"][0], f["at"][1], f["at"][2])
		g.build()
		figures.append(g)

## The door that goes nowhere, in Sonya's room: in the outside wall, four floors up.
func _pointless_door() -> void:
	var pd: Dictionary = data["pointless_door"]
	pointless = Usable48.new(); pointless.name = "PointlessDoor"
	add_child(pointless)
	pointless.position = Vector3(5.6, 0, 7.93)
	var k := TownKit.new(pointless)
	k.box("whitewash", Vector3(0, 1.0, 0.0), Vector3(0.4, 1.0, 0.02))
	for fr in [[Vector3(-0.43, 1.03, 0), Vector3(0.03, 1.03, 0.03)], [Vector3(0.43, 1.03, 0), Vector3(0.03, 1.03, 0.03)], [Vector3(0, 2.03, 0), Vector3(0.46, 0.03, 0.03)]]:
		k.box("whitewash", fr[0], fr[1])
	k.box("iron", Vector3(-0.3, 1.0, -0.04), Vector3(0.05, 0.012, 0.02))
	k.finish()
	for mi in pointless.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _block_mat
	var l := Label3D.new(); l.text = String(pd["label"]); l.font_size = 30; l.pixel_size = 0.0016
	l.modulate = Color(0.3, 0.3, 0.34); l.shaded = true; l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	pointless.add_child(l); l.position = Vector3(0, 1.55, -0.025); l.rotation = Vector3(0, PI, 0.03)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.86, 2.06, 0.08); cs.shape = b
	cs.position.y = 1.03
	pointless.add_child(cs)
	pointless.prompt_fn = func() -> String: return "Stick the note on it" if holding_note() else "Look"
	pointless.used.connect(func():
		if holding_note():
			reject(pointless.global_position + Vector3(0, 1.3, -0.05), "wont_stay")
		else:
			Game.set_flag("f48_looked_pointless")
			hud.caption(String(pd["look"]), 6.0))

# ================================================================== the pieces

## Anything in 48 the crosshair can use: `used`, `enabled`, and a prompt that can change.
class Usable48 extends StaticBody3D:
	signal used
	var enabled := true
	var prompt_fn := Callable()
	var prompt: String:
		get:
			return String(prompt_fn.call()) if prompt_fn.is_valid() else "Look"

## One loose note on the hall wall.
class WallNote extends Usable48:
	var flat: Flat48
	var word := ""
	var wall_id := 0
	func build() -> void:
		Weapon.make_note(word, self)
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.085, 0.085, 0.02); cs.shape = b
		add_child(cs)
		collision_layer = 8
		prompt_fn = func() -> String: return "Take: %s" % word
		used.connect(func(): flat.take_note(self))

## A note stuck on something.
class StuckNote extends Usable48:
	var word := ""
	var wall_id := -1

## A white block where a piece of 47's furniture is. Its tag is a clue, not a name.
class Placeholder extends Usable48:
	var flat: Flat48
	var identity := ""
	var tag := ""
	var index := 0
	var half := Vector3.ONE * 0.3
	var mesh: MeshInstance3D
	var label: Label3D
	var real: Node3D
	var note: StuckNote

	func build(mat: Material) -> void:
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0; cs.shape = b
		add_child(cs)
		mesh = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = half * 2.0; mesh.mesh = bm
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		if tag != "":
			label = Label3D.new(); label.text = tag; label.font_size = 24; label.pixel_size = 0.0012
			label.modulate = Color(0.25, 0.25, 0.3); label.shaded = true; label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			label.autowrap_mode = TextServer.AUTOWRAP_WORD; label.width = 260.0
			add_child(label)
			label.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, randf_range(-0.3, 0.3)), Vector3(0, half.y + 0.002, 0))
		prompt_fn = func() -> String:
			if real:
				return ""
			return "Stick the note on it" if flat.holding_note() else "Look"
		used.connect(_use)

	func _use() -> void:
		if real:
			return
		if not flat.holding_note():
			Game.set_flag("f48_looked_block_%d" % index)
			flat.hud.caption((flat.text("block_tag") % tag) if tag != "" else flat.text("block_blank"), 5.0)
			return
		if identity != "" and flat.weapon.note_word == identity:
			make_real()
		else:
			flat.reject(global_position + Vector3(0, half.y + 0.01, 0), "wont_stay" if identity != "" else "wont_stay_blank")

	## The right word: the block is the thing, with the note stuck on top of it.
	func make_real() -> void:
		if real:
			return
		var id: int = flat.weapon.note_id
		var word: String = flat.weapon.note_word
		flat.weapon.clear_note()
		real = flat.realise(self)
		mesh.visible = false
		if label:
			label.visible = false
		real.scale = Vector3(1, 0.02, 1)
		real.create_tween().tween_property(real, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		note = flat.stick_note(self, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, randf_range(-0.4, 0.4)), Vector3(randf_range(-0.08, 0.08), half.y + 0.014, 0)), word, id, peel)
		Game.set_flag("f48_real_%d" % index)
		flat.flash(position + Vector3(0, half.y, 0))
		var n: int = real.get_meta("count", 0)
		flat.hud.caption(flat.text("real" if n > 0 else "real_empty") % identity.to_lower(), 4.0)
		flat.transformed.emit("REAL", self)

	## The note comes off: it's a block again, and the note's in his hand.
	func peel() -> void:
		if not real or flat.holding_note():
			return
		var id := note.wall_id
		var word := note.word
		note.queue_free(); note = null
		real.queue_free(); real = null
		mesh.visible = true
		if label:
			label.visible = true
		Game.flags.erase("f48_real_%d" % index)
		Sfx.play_at("paper", global_position, 0.0)
		flat.weapon.take_note(word, id)
		flat.hud.caption(flat.text("peeled"), 3.0)
		flat.transformed.emit("PEELED", self)

## Papa's gun safe: a white block until it's called what it is; then a Soviet hunting-gun cabinet,
## green-grey sheet steel, two lock barrels, a handle; inside on two pegs the sawn-off, and a box
## of shells on the shelf.
class GunSafe extends Usable48:
	var flat: Flat48
	var real := false
	var open := false
	var gun_taken := false
	var shells_taken := false
	var block: MeshInstance3D
	var tag: Label3D
	var cabinet: Node3D
	var door: Node3D
	var gun: Node3D
	var shells: Node3D
	var gun_spot: Hotspot
	var shells_spot: Hotspot
	var note: StuckNote

	func build() -> void:
		var h := Flat48.SAFE_HALF
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = h * 2.0; cs.shape = b; cs.position.y = h.y
		add_child(cs)
		block = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = h * 2.0; block.mesh = bm
		block.material_override = flat._block_mat; block.position.y = h.y
		add_child(block)
		tag = Label3D.new(); tag.text = String(flat.data["safe"]["tag"]); tag.font_size = 24; tag.pixel_size = 0.0012
		tag.modulate = Color(0.25, 0.25, 0.3); tag.shaded = true; tag.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD; tag.width = 200.0
		add_child(tag); tag.position = Vector3(0, 1.1, -h.z - 0.002); tag.rotation.y = PI
		prompt_fn = func() -> String:
			if not real:
				return "Stick the note on it" if flat.holding_note() else "Look"
			return "Close the safe" if open else "Open the safe"
		used.connect(_use)

	func _use() -> void:
		if real:
			set_open(not open)
			return
		if not flat.holding_note():
			Game.set_flag("f48_looked_safe")
			flat.hud.caption(flat.text("safe_block"), 6.0)
		elif flat.weapon.note_word == "GUN SAFE":
			make_real()
		else:
			flat.reject(global_position + Vector3(0, 1.2, -Flat48.SAFE_HALF.z - 0.01), "wont_stay")

	func make_real() -> void:
		if real:
			return
		real = true
		var id: int = flat.weapon.note_id
		flat.weapon.clear_note()
		block.visible = false; tag.visible = false
		_cabinet()
		note = flat.stick_note(self, Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.1), Vector3(-Flat48.SAFE_HALF.x - 0.004, 1.2, 0.02)), "GUN SAFE", id, peel)
		note.rotation = Vector3(0, -PI * 0.5, 0.1)
		Game.set_flag("f48_safe_real")
		flat.flash(position + Vector3(0, 1.0, -0.3))
		flat.hud.caption(flat.text("safe_real"), 6.0)
		flat.transformed.emit("GUN SAFE", self)

	## Shut, its note comes off, and it's a cold white block again (what's in it stays in it).
	func peel() -> void:
		if not real or open or flat.holding_note():
			return
		var id := note.wall_id
		note.queue_free(); note = null
		cabinet.queue_free(); cabinet = null; door = null; gun = null; shells = null
		if gun_spot: gun_spot.queue_free(); gun_spot = null
		if shells_spot: shells_spot.queue_free(); shells_spot = null
		real = false
		block.visible = true; tag.visible = true
		Game.flags.erase("f48_safe_real")
		Sfx.play_at("paper", global_position + Vector3(0, 1, 0), 0.0)
		flat.weapon.take_note("GUN SAFE", id)
		flat.hud.caption(flat.text("peeled"), 3.0)
		flat.transformed.emit("PEELED", self)

	func _cabinet() -> void:
		var h := Flat48.SAFE_HALF
		cabinet = Node3D.new(); cabinet.name = "Cabinet"; add_child(cabinet)
		var k := TownKit.new(cabinet)
		# the carcass: back, sides, top, bottom; the open front faces -z (into the room)
		k.box("safe_paint", Vector3(0, h.y, h.z - 0.01), Vector3(h.x, h.y, 0.01))
		k.box("safe_paint", Vector3(-h.x + 0.01, h.y, 0), Vector3(0.01, h.y, h.z))
		k.box("safe_paint", Vector3(h.x - 0.01, h.y, 0), Vector3(0.01, h.y, h.z))
		k.box("safe_paint", Vector3(0, h.y * 2.0 - 0.01, 0), Vector3(h.x, 0.01, h.z))
		k.box("safe_paint", Vector3(0, 0.03, 0), Vector3(h.x, 0.03, h.z))
		# inside: a shelf near the top, two pegs on the back for a gun, felt on the floor, baize behind
		k.box("safe_paint", Vector3(0, h.y * 2.0 - 0.3, 0.02), Vector3(h.x - 0.02, 0.008, h.z - 0.03))
		k.box("cloth_dark", Vector3(0, 0.062, 0.0), Vector3(h.x - 0.02, 0.002, h.z - 0.02))
		k.box("baize", Vector3(0, h.y, h.z - 0.022), Vector3(h.x - 0.025, h.y - 0.08, 0.002))
		for py in [0.47, 0.8]:
			k.cyl_axis("iron", Vector3(-0.045, py, h.z - 0.02), Vector3(-0.045, py, h.z - 0.1), 0.008, 6)
		k.finish()
		# the door: hinged on the left, two lock barrels and a T-handle
		door = Node3D.new(); door.name = "Door"; cabinet.add_child(door); door.position = Vector3(-h.x, 0, -h.z)
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
			gun = Weapon.make_shotgun_model(); cabinet.add_child(gun)
			# hung in profile against the baize, muzzle up: the barrels, the action, the sawn grip
			gun.transform = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.02, 0.5, h.z - 0.06))
			gun_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(-0.07, 0.66, -h.z - 0.025)), Vector3(0.22, 0.7, 0.04), "Take the shotgun")
			gun_spot.used.connect(take_gun)
			gun_spot.enabled = false
		if not shells_taken:
			shells = Node3D.new(); cabinet.add_child(shells); shells.position = Vector3(0.12, h.y * 2.0 - 0.29, 0.0)
			var ks := TownKit.new(shells)
			ks.box("paper_old", Vector3(0, 0.035, 0), Vector3(0.05, 0.035, 0.035))
			for i in 4:
				ks.cyl("lipstick", Vector3(-0.03 + i * 0.02, 0.07, 0.015), 0.009, 0.03, 6)
			ks.finish()
			shells_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(0.13, h.y * 2.0 - 0.23, -h.z - 0.025)), Vector3(0.2, 0.16, 0.04), "Take the shells")
			shells_spot.used.connect(take_shells)
			shells_spot.enabled = false
		for mi in cabinet.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func set_open(o: bool) -> void:
		open = o
		if door:
			door.create_tween().tween_property(door, "rotation:y", 1.9 if open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
		Sfx.play_at("creak", global_position + Vector3(0, 1, 0), -8.0, 1.6)
		# what's inside can only be reached with the door open; the door's solid when it's shut
		if gun_spot: gun_spot.enabled = open
		if shells_spot: shells_spot.enabled = open
		Game.flags["f48_safe_open"] = open
		if open and not gun_taken:
			flat.hud.caption(flat.text("safe_open"), 6.5)
			flat.transformed.emit("OPENED", self)

	func take_gun() -> void:
		if gun_taken or not open:
			return
		gun_taken = true
		if gun: gun.queue_free(); gun = null
		if gun_spot: gun_spot.queue_free(); gun_spot = null
		flat.weapon.give_shotgun()
		Game.set_flag("has_shotgun")
		flat.hud.caption(flat.text("shotgun"), 6.0)
		flat.transformed.emit("SHOTGUN", self)

	func take_shells() -> void:
		if shells_taken or not open:
			return
		shells_taken = true
		if shells: shells.queue_free(); shells = null
		if shells_spot: shells_spot.queue_free(); shells_spot = null
		Game.shells_spare += 10
		Sfx.play("load", -4.0)
		flat.hud.caption(flat.text("shells"), 3.5)

## One of the three: a white standing figure, wrong in its proportions (the neck too long, the
## head too small, the arms too long), a paper tag pinned on. When you aren't looking at it, it
## turns a little toward you. The right name dresses it; it can be shot, and then it's down.
class Figure48 extends Usable48:
	var flat: Flat48
	var id := ""
	var tall := 1.7
	var info := {}
	var down := false
	var dressed := false
	var body: Node3D
	var note: StuckNote
	var _tag: Label3D

	func build() -> void:
		body = Node3D.new(); add_child(body)
		_white()
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(tall * 0.3, tall, tall * 0.18); cs.shape = b; cs.position.y = tall * 0.5
		add_child(cs)
		# where a shot lands: the head, the rest
		for part in [["head", Vector3(0, tall * 0.88, 0), Vector3(tall * 0.16, tall * 0.16, tall * 0.16)], ["body", Vector3(0, tall * 0.42, 0), Vector3(tall * 0.34, tall * 0.76, tall * 0.2)]]:
			var a := Area3D.new(); a.collision_layer = 4; a.collision_mask = 0; a.monitoring = false
			a.set_meta("monster", self); a.set_meta("part", part[0])
			var hs := CollisionShape3D.new(); var hb := BoxShape3D.new(); hb.size = part[2]; hs.shape = hb
			a.add_child(hs); add_child(a); a.position = part[1]
		rotation.y = atan2(position.x - 5.0, position.z - 4.0) + PI     # its back to the middle of the flat: facing the wall
		prompt_fn = func() -> String:
			if down:
				return ""
			return "Stick the note on it" if flat.holding_note() and not dressed else "Look"
		used.connect(_use)

	func _white() -> void:
		for c in body.get_children():
			c.free()
		var m: Material = flat._block_mat
		var h := tall
		_part(m, Vector3(0, h * 0.18 + h * 0.31, 0), Vector3(h * 0.12, h * 0.31, h * 0.075))        # the trunk
		_part(m, Vector3(0, h * 0.86, 0), Vector3(h * 0.055, h * 0.06, h * 0.06))                    # the head, small
		_part(m, Vector3(0, h * 0.79, 0), Vector3(h * 0.025, h * 0.04, h * 0.025))                   # the neck, long
		for s in [-1.0, 1.0]:
			_part(m, Vector3(s * h * 0.05, h * 0.1, 0), Vector3(h * 0.04, h * 0.1, h * 0.04))        # legs
			_part(m, Vector3(s * h * 0.15, h * 0.42, 0), Vector3(h * 0.025, h * 0.27, h * 0.025))    # arms, too long
		_tag = Label3D.new(); _tag.text = String(info["tag"]); _tag.font_size = 26; _tag.pixel_size = 0.0013
		_tag.modulate = Color(0.2, 0.2, 0.26); _tag.shaded = true; _tag.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		body.add_child(_tag); _tag.position = Vector3(-h * 0.04, h * 0.66, -h * 0.076); _tag.rotation.y = PI

	func _part(m: Material, at: Vector3, half: Vector3) -> void:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = half * 2.0; mi.mesh = bm; mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi); mi.position = at

	func _use() -> void:
		if down:
			return
		if not flat.holding_note() or dressed:
			Game.set_flag("f48_looked_" + id)
			flat.hud.caption(String(info["dressed"] if dressed else info["look"]), 6.5)
			flat.transformed.emit("LOOKED", self)
			return
		var word: String = flat.weapon.note_word
		if String(info.get("name", "")) != "" and word == String(info["name"]):
			dress()
			return
		var refuses: Dictionary = info.get("refuses", {})
		if refuses.has(word):
			flat.reject(global_position + Vector3(0, tall * 0.7, 0) - global_transform.basis.z * 0.12, "wont_stay")
			flat.hud.caption(String(refuses[word]), 4.5)
			Game.set_flag("f48_%s_refused_%s" % [id, word.to_lower()])
			flat.transformed.emit("NOT " + word, self)
		else:
			flat.reject(global_position + Vector3(0, tall * 0.7, 0) - global_transform.basis.z * 0.12, "wont_stay")

	## The name, and the white figure is a shop mannequin dressed as them: faceless, jointed, on
	## its stand. Marta in her cardigan, her hair up, a red mouth painted on; Kurt in a dark jacket,
	## a domino mask on the blank face, a bow on its back (the man in Sonya's drawing).
	func dress() -> void:
		if dressed or down:
			return
		dressed = true
		var nid: int = flat.weapon.note_id
		var word: String = flat.weapon.note_word
		flat.weapon.clear_note()
		Game.set_flag("f48_dressed_" + id)
		_mannequin()
		note = flat.stick_note(body, Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.BACK, 0.12), Vector3(-tall * 0.04, tall * 0.66, -tall * 0.085)), word, nid, undress)
		flat.flash(position + Vector3(0, tall * 0.6, 0))
		flat.hud.caption(String(info["becomes"]), 7.0)
		flat.transformed.emit("DRESSED_" + id.to_upper(), self)

	func undress() -> void:
		if not dressed or down or flat.holding_note():
			return
		var nid := note.wall_id; var word := note.word
		note = null
		dressed = false
		Game.flags.erase("f48_dressed_" + id)
		_white()
		Sfx.play_at("paper", global_position + Vector3(0, tall * 0.6, 0), 0.0)
		flat.weapon.take_note(word, nid)
		flat.hud.caption(flat.text("undressed"), 3.0)
		flat.transformed.emit("PEELED", self)

	func _mannequin() -> void:
		for c in body.get_children():
			c.free()
		var k := TownKit.new(body)
		var h := tall
		var hip := h * 0.52; var sh := h * 0.8
		k.cyl("iron", Vector3(0, 0, 0.06), 0.17, 0.02, 12)
		k.cyl("iron", Vector3(-h * 0.05, 0.02, h * 0.02), 0.008, h * 0.2, 6)
		var top := "cardigan" if id == "mama" else "jacket"
		var legs := "mannequin" if id == "mama" else "trousers"
		for s: float in [-1.0, 1.0]:
			var x := s * h * 0.055
			k.cyl_axis(legs, Vector3(x, hip, 0), Vector3(x * 1.05, h * 0.28, -h * 0.005), h * 0.05, 8, h * 0.036)
			k.cyl_axis(legs, Vector3(x * 1.05, h * 0.28, -h * 0.005), Vector3(x * 1.1, h * 0.05, 0), h * 0.034, 8, h * 0.022)
			k.box("wig" if id == "mama" else "trousers", Vector3(x * 1.1, h * 0.022, -h * 0.03), Vector3(h * 0.028, h * 0.022, h * 0.065))
			var s0 := Vector3(s * h * 0.125, sh - h * 0.02, 0); var e := Vector3(s * h * 0.145, h * 0.6, -h * 0.01); var w := Vector3(s * h * 0.13, h * 0.44, -h * 0.05)
			k.cyl_axis(top, s0, e, h * 0.03, 8, h * 0.026)
			k.cyl_axis(top, e, w, h * 0.026, 8, h * 0.02)
			k.box("mannequin", w + Vector3(0, -h * 0.05, -h * 0.005), Vector3(h * 0.01, h * 0.045, h * 0.026))
		var trunk := Node3D.new(); body.add_child(trunk); trunk.scale = Vector3(1, 1, 0.68)
		var kt := TownKit.new(trunk)
		kt.cyl_axis(top if id == "papa" else "skirt", Vector3(0, hip - h * 0.03, 0), Vector3(0, h * 0.6, 0), h * 0.105, 10, h * 0.09)
		kt.cyl_axis(top, Vector3(0, h * 0.6, 0), Vector3(0, sh, 0), h * 0.09, 10, h * 0.115)
		kt.cyl_axis(top, Vector3(0, sh, 0), Vector3(0, sh + h * 0.012, 0), h * 0.115, 10, h * 0.04)
		kt.finish()
		k.cyl_axis("mannequin", Vector3(0, sh, 0), Vector3(0, h * 0.86, 0), h * 0.028, 8)
		if id == "mama":
			k.cyl_axis("skirt", Vector3(0, h * 0.58, 0), Vector3(0, h * 0.3, 0), h * 0.085, 10, h * 0.11)
			for i in 5:
				k.box("china", Vector3(0, h * 0.62 + i * h * 0.035, -h * 0.078), Vector3(h * 0.006, h * 0.006, h * 0.003))
		else:
			for i in 9:
				var a0 := -0.9 + 1.8 * i / 9.0; var a1 := -0.9 + 1.8 * (i + 1) / 9.0
				var p0 := Vector3(sin(a0) * h * 0.08 + h * 0.03, h * 0.66 + sin(a0 * 1.75) * h * 0.24, h * 0.1 + cos(a0) * h * 0.03)
				var p1 := Vector3(sin(a1) * h * 0.08 + h * 0.03, h * 0.66 + sin(a1 * 1.75) * h * 0.24, h * 0.1 + cos(a1) * h * 0.03)
				k.cyl_axis("walnut", p0, p1, h * 0.007, 5)
			k.cyl_axis("leather", Vector3(-h * 0.05, h * 0.55, h * 0.09), Vector3(h * 0.04, h * 0.86, h * 0.1), h * 0.03, 8)
			for i in 4:
				k.box("cloth_white", Vector3(h * (0.03 + i * 0.008), h * 0.9, h * 0.1), Vector3(h * 0.004, h * 0.025, h * 0.012))
		k.finish()
		var head := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = h * 0.06; sm.height = h * 0.15
		sm.radial_segments = 10; sm.rings = 6; head.mesh = sm; head.material_override = k.material("mannequin")
		body.add_child(head); head.position = Vector3(0, h * 0.92, 0)
		var kh := TownKit.new(head)
		if id == "mama":
			kh.box("wig", Vector3(0, h * 0.02, h * 0.012), Vector3(h * 0.062, h * 0.05, h * 0.055))
			kh.cyl_axis("wig", Vector3(0, h * 0.05, h * 0.04), Vector3(0, h * 0.075, h * 0.05), h * 0.03, 8)
			kh.box("lipstick", Vector3(0, -h * 0.035, -h * 0.058), Vector3(h * 0.013, h * 0.004, h * 0.002))
		else:
			kh.box("wig", Vector3(0, h * 0.008, -h * 0.052), Vector3(h * 0.05, h * 0.011, h * 0.012))
		kh.finish()
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(delta: float) -> void:
		if down or not flat.visible:
			return
		var cam := get_viewport().get_camera_3d()
		if not cam:
			return
		# it turns toward him, a little, only while he isn't looking at it
		var at := global_position + Vector3(0, tall * 0.5, 0)
		if cam.is_position_in_frustum(at):
			return
		var want := atan2(cam.global_position.x - global_position.x, cam.global_position.z - global_position.z) + PI
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 0.25))

	## Shot (Weapon calls this, with where it landed): it goes over, and it stays down.
	func shot(_part: String) -> void:
		if down:
			return
		down = true
		Game.set_flag("f48_shot_" + id)
		for c in get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", true)
			elif c is Area3D:
				(c as Area3D).collision_layer = 0
		var tw := create_tween()
		tw.tween_property(body, "rotation:x", 0.18, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "rotation:x", -PI * 0.48, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(body, "position:y", -tall * 0.02, 0.55)
		tw.tween_callback(func():
			Sfx.play_at("thud", global_position, 0.0)
			Noises.make(global_position, 12.0, "impact"))
		flat.transformed.emit("SHOT", self)
