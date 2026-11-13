extends Level
## Flat 48, across the landing (docs/FLAT48.md): Flat 47 as reality only sketched it. The same
## rooms and doors in pale draft plaster, a steady cold light, no shadows; the windows are the
## white. Every piece of 47's furniture a white block exactly where it stands in 47, a tag on it;
## three white figures standing in it, who move when he isn't looking.
##
## The rule of the place: what something is, is what's written on it. In the hall, a wall of
## sticky notes, a word on each. Take one, stick it on a block: the right word and the block is
## gone and the thing is there, solid, the note on it; any other word won't stay on.
## In the box room, a tall narrow block that isn't in 47: GUN SAFE makes it Papa's steel cabinet,
## and in it the sawn-off and a box of shells. The names on the wall dress the figures: MARTA on
## MAMA, KURT on PAPA. SONYA won't stay on the child. Once each name has been tried, a note that
## wasn't there is on the wall: LOBBY. Across the landing is 47 (the door that's 48 from 47's side);
## he takes LOBBY there, to the balcony, where outside is a sticky note that says "outside".
##
## Every line is a placeholder for the writers (data/dialogue/flat48.json); the only real words
## are the ones the puzzle runs on.

const DRAFT := Color(1.18, 1.16, 1.1)          # tint over the plaster: pale, chalky
const BLOCK := Color(1.32, 1.32, 1.28)
const START := Vector3(12.4, 0, 4.5)
## [collider index in level.json, the word that makes it real ("" never)]
const BLOCKS := [
	[23, "SOFA"], [24, ""], [26, "TABLE"], [25, "WALL UNIT"], [27, ""], [22, "RADIATOR"],
	[35, "BED"], [38, "WARDROBE"], [39, ""], [36, ""], [37, ""], [34, "RADIATOR"], [40, ""],
	[41, "RADIATOR"], [42, ""], [43, "SINK"], [44, ""], [45, "COOKER"], [46, "FRIDGE"], [47, ""], [48, ""],
	[49, "TABLE"], [50, "SONYA'S BED"], [51, ""], [52, ""], [53, "BATH"], [54, ""], [55, ""], [56, "SINK"],
	[57, "SHELVES"], [58, ""], [59, ""], [21, ""], [28, ""], [29, ""],
]
## Not in 47: Papa's gun safe, in the box room against the far wall.
const SAFE_AT := Vector3(1.35, 0.0, 7.62)
const SAFE_HALF := Vector3(0.27, 0.73, 0.19)
## The note wall: the hall's north wall between the living room and the bedroom door.
const WALL_X0 := 4.62
const WALL_X1 := 6.38
const WALL_Z := 3.874
const WORDS := ["SOFA", "TABLE", "WALL UNIT", "BED", "WARDROBE", "SINK", "COOKER", "FRIDGE", "TABLE",
	"BATH", "SINK", "SHELVES", "RADIATOR", "RADIATOR", "RADIATOR", "SONYA'S BED", "GUN SAFE",
	"MARTA", "KURT", "SONYA", "PIANO", "DOG", "WINDOW", "HOME", "LATER"]
## The three: [id, where, height, tag, the name that dresses it]
const FIGURES := [["mama", Vector3(9.2, 0, 2.65), 1.72, "MAMA", "MARTA"],
	["papa", Vector3(6.0, 0, 0.6), 1.78, "PAPA", "KURT"],
	["child", Vector3(4.05, 0, 6.55), 1.22, "CHILD", ""]]

var flat: ExportedFlat
var blocks: Array = []
var figures: Array = []
var safe_block: DraftBlock
var front_door: ExportDoor
var _draft: Material
var _said := {}
var _sonya_tried := false
var _ending := false
var door47: Hotspot            # across the landing: 47 (opens once LOBBY is on the wall)
var lobby_spot: Hotspot

func build() -> void:
	add_to_group("level")
	flat = ExportedFlat.new(0.0)
	world.add_child(flat)
	_draft = Tex.mat("plaster", 0.7, {"tint": DRAFT})
	front_door = flat.doors.dEntry
	front_door.locked = false; front_door.name_text = "door"
	front_door.angle = 0.0; front_door.target = 0.0; front_door._apply(); front_door.is_open = false
	for lb in front_door.find_children("*", "Label3D", true, false):
		if (lb as Label3D).text == "47": (lb as Label3D).text = "48"
	for id in flat.doors:
		if String(id).begins_with("bal"): flat.doors[id].locked = true
	var sw := Stairwell.build(flat)
	# the door across the landing is 47 from here
	var d: Node3D = sw.get("door48")
	if d:
		for lb in d.find_children("*", "Label3D", true, false):
			if (lb as Label3D).text == "48": (lb as Label3D).text = "47"
		door47 = Hotspot.make(world, d.global_position + Vector3(0, 1.0, -0.25), Vector3(1.0, 2.0, 0.3), "Flat 47", _to_47)
		door47.enabled = false
	_environment()
	_blocks()
	_draft_everything()
	_lights()
	_outside()
	_note_wall()
	_figures()
	socko.visible = true
	player.position = START
	player.set_view(PI * 0.5, 0.0)

func ao_area() -> Array:
	return [Rect2(-0.6, -1.95, 14.8, 10.4), 0.0, ExportedFlat.H]

func ao_name() -> String: return "flat48"

func _environment() -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.93, 0.93, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9ccd2"); e.ambient_light_energy = 0.42
	e.fog_enabled = true; e.fog_light_color = Color("d8d9dc"); e.fog_density = 0.01
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 0.9
	e.glow_enabled = false

# ------------------------------------------------------------------ the draft
## Everything 47 has, in pale plaster: the furniture already hidden under its blocks, the loose
## things too. Glass stays glass (the white shows through it).
func _draft_everything() -> void:
	var hidden := {}
	for b in blocks:
		for n in b.real_nodes: hidden[n] = true
	# loose things not on any block: gone (a sketch has none)
	for k in flat.props:
		var pr: Node3D = flat.props[k]
		if is_instance_valid(pr) and not hidden.has(pr):
			pr.visible = false
			if pr is CollisionObject3D: (pr as CollisionObject3D).collision_layer = 0
			if pr is RigidBody3D: (pr as RigidBody3D).freeze = true
	for mi in flat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if hidden.has(m) or _under_hidden(m, hidden): continue
		if m.global_position.x > 10.42 and (m.get_aabb().size.length() < 30.0) and _on_landing(m): continue      # the landing is 47's, as it was
		var cur = m.material_override if m.material_override else (m.mesh.surface_get_material(0) if m.mesh and m.mesh.get_surface_count() > 0 else null)
		if cur is ShaderMaterial and (cur as ShaderMaterial).get_shader_parameter("glass"): continue
		if cur is BaseMaterial3D and (cur as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		m.material_override = _draft

## Outside 48's front door (the stairwell, the landing): real, not drafted.
func _on_landing(m: MeshInstance3D) -> bool:
	var a: AABB = m.global_transform * m.get_aabb()
	return a.position.x > 10.40

func _under_hidden(n: Node, hidden: Dictionary) -> bool:
	var p := n.get_parent()
	while p and p != flat:
		if hidden.has(p): return true
		p = p.get_parent()
	return false

## Steady, cold, everywhere the same: a light in each room, no shadows, nothing that moves.
func _lights() -> void:
	for l in flat.find_children("*", "Light3D", true, false): (l as Light3D).visible = false
	for k in flat.level.rooms:
		var r: Dictionary = flat.level.rooms[k]
		var o := OmniLight3D.new()
		o.light_color = Color("e4e9f2"); o.light_energy = 0.6; o.shadow_enabled = false
		o.omni_range = maxf(float(r.x1) - float(r.x0), float(r.z1) - float(r.z0)) * 0.9 + 1.0; o.omni_attenuation = 0.6
		world.add_child(o); o.position = Vector3((float(r.x0) + float(r.x1)) * 0.5, 2.3, (float(r.z0) + float(r.z1)) * 0.5)

## Out of the windows: white, even.
func _outside() -> void:
	var white := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(80, 40, 80); white.mesh = bm
	var wm := StandardMaterial3D.new(); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; wm.albedo_color = Color(0.93, 0.93, 0.92)
	wm.cull_mode = BaseMaterial3D.CULL_FRONT; wm.disable_fog = true
	white.material_override = wm; white.position = Vector3(5, 5, 4); world.add_child(white)

# ------------------------------------------------------------------ the blocks
func _blocks() -> void:
	var cols: Array = flat.level.colliders
	var bm := Tex.mat("plaster", 1.2, {"tint": BLOCK})
	for spec in BLOCKS:
		var c: Dictionary = cols[int(spec[0])]
		var half := Vector3(float(c.hx), (float(c.y1) - maxf(float(c.y0), 0.0)) * 0.5, float(c.hz))
		var xf := Transform3D(Basis(Vector3.UP, float(c.rot)), Vector3(float(c.x), maxf(float(c.y0), 0.0) + half.y, float(c.z)))
		var b := _block(xf, half, String(spec[1]), bm)
		b.hide_real(_inside(xf, half))
	# Papa's gun safe: no furniture in 47 here to hide
	safe_block = _block(Transform3D(Basis.IDENTITY, SAFE_AT + Vector3(0, SAFE_HALF.y, 0)), SAFE_HALF, "GUN SAFE", bm)
	safe_block.realised.connect(_on_safe_real)

func _block(xf: Transform3D, half: Vector3, identity: String, m: Material) -> DraftBlock:
	var b := DraftBlock.new(); b.identity = identity; b.half = half
	b.tag = ExportedFlat.PLACEHOLDER
	world.add_child(b); b.transform = xf
	b.build(m)
	b.realised.connect(_on_real)
	blocks.append(b)
	return b

## 47's meshes (and loose things) standing in a block's space.
func _inside(xf: Transform3D, half: Vector3) -> Array:
	var out := []
	var inv := xf.affine_inverse()
	var h := half + Vector3(0.08, 0.08, 0.08)
	for mi in flat.model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name).contains("-") or not m.mesh: continue           # the room shells
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > 4.5 or a.size.length() < 0.004: continue
		var lc := inv * a.get_center()
		if absf(lc.x) > h.x or absf(lc.z) > h.z or lc.y < -h.y - 0.05 or lc.y > h.y + 0.5: continue
		if _is_door_part(m): continue
		out.append(m)
	for k in flat.props:
		var pr: Node3D = flat.props[k]
		if not is_instance_valid(pr): continue
		var lc := inv * pr.global_position
		if absf(lc.x) <= h.x and absf(lc.z) <= h.z and lc.y >= -h.y - 0.05 and lc.y <= h.y + 0.6: out.append(pr)
	return out

func _is_door_part(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is ExportDoor or p is ExportDrawer: return true
		p = p.get_parent()
	return false

func _on_real(_b: DraftBlock) -> void:
	_line_once("f48_first_real")

# ------------------------------------------------------------------ the notes
func _note_wall() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4848
	var cols := 6
	for i in WORDS.size():
		var cx := i % cols; var cy := i / cols
		var x := lerpf(WALL_X0 + 0.12, WALL_X1 - 0.12, cx / float(cols - 1)) + rng.randf_range(-0.04, 0.04)
		var y := 1.9 - cy * 0.24 + rng.randf_range(-0.03, 0.03)
		var at := Vector3(x, y, WALL_Z + 0.006)
		var word: String = WORDS[i]
		var vis := Node3D.new(); world.add_child(vis); vis.position = at; vis.rotation.z = rng.randf_range(-0.18, 0.18)
		_note_face(vis, word)
		var h := Hotspot.make(world, at + Vector3(0, 0, 0.02), Vector3(0.1, 0.1, 0.05), "Take the note: %s" % word, Callable())
		h.action = _take_note.bind(word, h, vis)

## A sticky note: yellow paper and the word in neat capitals.
func _note_face(parent: Node3D, word: String) -> void:
	var q := MeshInstance3D.new(); q.mesh = Build.box_mesh(Vector3(0.09, 0.09, 0.002))
	q.material_override = Tex.mat("enamel", 1.0, {"tint": Color(1.0, 0.92, 0.42)}); parent.add_child(q)
	var l := Label3D.new(); l.text = word; l.font_size = 30 if word.length() < 9 else 22; l.pixel_size = 0.001
	l.modulate = Color(0.12, 0.12, 0.16); l.outline_size = 0; l.shaded = true; l.position = Vector3(0, 0, 0.0015)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.width = 82.0
	parent.add_child(l)

## Off the wall into his hand (one at a time: the one he had goes back up).
func _take_note(word: String, spot: Hotspot, vis: Node3D) -> void:
	if player.held and player.held.has_meta("word"):
		_return_note(player.held)
	elif player.held:
		player.drop_held()
	var n := Prop.make(world, spot.global_position, Vector3(0.08, 0.08, 0.004), Tex.mat("enamel", 1.0, {"tint": Color(1.0, 0.92, 0.42)}), "note: %s" % word, 0.02, 0.05)
	n.collision_layer = 16
	var l := Label3D.new(); l.text = word; l.font_size = 30 if word.length() < 9 else 22; l.pixel_size = 0.001
	l.modulate = Color(0.12, 0.12, 0.16); l.outline_size = 0; l.position = Vector3(0, 0, 0.003); l.double_sided = true
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.width = 82.0
	n.add_child(l)
	n.set_meta("word", word); n.set_meta("spot", spot); n.set_meta("vis", vis)
	spot.enabled = false; vis.visible = false
	Sfx.play("paper", -6.0, 1.2)
	player.pick_up(n)
	_line_once("f48_wall")

func _return_note(n: RigidBody3D) -> void:
	if player.held == n: player.drop_held()
	var spot = n.get_meta("spot", null); var vis = n.get_meta("vis", null)
	if is_instance_valid(spot): spot.enabled = true
	if is_instance_valid(vis): vis.visible = true
	n.queue_free()

## On a block: the right word, and it's real; any other, it falls off.
func stick_note(b: DraftBlock, p) -> void:
	var n: RigidBody3D = p.held
	var word := String(n.get_meta("word"))
	if word == b.identity:
		p.drop_held()
		n.freeze = true; n.collision_layer = 0; n.liftable = false
		n.global_transform = Transform3D(b.global_basis, b.to_global(Vector3(-b.half.x * 0.35, b.half.y - 0.07, b.half.z + 0.004)))
		Sfx.play_at("paper", n.global_position, -4.0, 1.0)
		Sfx.play_at("thud", b.global_position, -10.0, 1.4)
		Fx.burst("dust", b.global_position + Vector3(0, b.half.y, 0), Vector3.UP)
		b.make_real()
	else:
		_falls_off(n, b.global_position + Vector3(0, b.half.y, 0))

func _falls_off(n: RigidBody3D, at: Vector3) -> void:
	player.drop_held()
	n.global_position = at + (player.global_position - at).normalized() * 0.2 * Vector3(1, 0, 1)
	n.linear_velocity = Vector3(randf_range(-0.3, 0.3), -0.2, randf_range(-0.3, 0.3))
	n.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	n.linear_damp = 3.0
	Sfx.play_at("paper", at, -8.0, 0.8)
	_line_once("f48_wrong")

# ------------------------------------------------------------------ the safe
var safe_door: Node3D
var _safe_open := false
func _on_safe_real(b: DraftBlock) -> void:
	var cab := Node3D.new(); world.add_child(cab); cab.position = SAFE_AT
	var steel := Tex.mat("gunmetal", 3.0, {"tint": Color(0.75, 0.8, 0.78), "rough": 0.5})
	var h := SAFE_HALF
	for part in [[Vector3(0, h.y, -h.z + 0.01), Vector3(h.x * 2, h.y * 2, 0.02)], [Vector3(-h.x + 0.01, h.y, 0), Vector3(0.02, h.y * 2, h.z * 2)],
			[Vector3(h.x - 0.01, h.y, 0), Vector3(0.02, h.y * 2, h.z * 2)], [Vector3(0, h.y * 2 - 0.01, 0), Vector3(h.x * 2, 0.02, h.z * 2)],
			[Vector3(0, 0.01, 0), Vector3(h.x * 2, 0.02, h.z * 2)], [Vector3(0, 0.55, 0), Vector3(h.x * 2 - 0.04, 0.015, h.z * 2 - 0.04)]]:
		var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(part[1]); mi.material_override = steel; mi.position = part[0]; cab.add_child(mi)
	# the door, hinged on the left
	safe_door = Node3D.new(); cab.add_child(safe_door); safe_door.position = Vector3(-h.x, 0, h.z)
	var dm := MeshInstance3D.new(); dm.mesh = Build.box_mesh(Vector3(h.x * 2, h.y * 2, 0.025)); dm.material_override = steel
	dm.position = Vector3(h.x, h.y, 0.0); safe_door.add_child(dm)
	var knob := MeshInstance3D.new(); knob.mesh = Build.box_mesh(Vector3(0.03, 0.08, 0.03)); knob.material_override = Tex.mat("brass")
	knob.position = Vector3(h.x * 1.8, h.y * 1.1, 0.025); safe_door.add_child(knob)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = h * 2.0; cs.shape = sh
	sb.add_child(cs); cab.add_child(sb); sb.position = Vector3(0, h.y, 0)
	# the note, on the door
	var n := Hotspot.make(world, SAFE_AT + Vector3(0, h.y, h.z + 0.05), Vector3(h.x * 2, h.y * 2, 0.1), "Open it", Callable())
	n.action = _open_safe.bind(n)
	_line_once("f48_safe")

func _open_safe(h: Hotspot) -> void:
	if _safe_open: return
	_safe_open = true; h.enabled = false
	Sfx.play_at("door_creak", SAFE_AT + Vector3(0, 1, 0), -4.0, 0.7)
	Sfx.play_at("metal", SAFE_AT + Vector3(0, 1, 0), -10.0, 0.8)
	var tw := create_tween().set_trans(Tween.TRANS_SINE); tw.tween_property(safe_door, "rotation:y", -1.9, 1.1)
	# on two pegs, the sawn-off; on the shelf, a box of shells
	var g := Pickup.new(); g.item = "shotgun"; g.amount = 2; g.label = "the sawn-off"
	world.add_child(g); g.position = SAFE_AT + Vector3(0, 0.95, 0)
	var steel := Tex.mat("gunmetal", 8.0, {"rough": 0.35})
	for sx in [-0.012, 0.012]:
		var b := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.0115; cy.bottom_radius = 0.0115; cy.height = 0.32; cy.radial_segments = 8
		b.mesh = cy; b.material_override = steel; b.position = Vector3(sx, 0.05, 0); g.add_child(b)
	var grip := MeshInstance3D.new(); grip.mesh = Build.box_mesh(Vector3(0.04, 0.16, 0.05)); grip.material_override = Tex.mat("wood", 10.0, {"tint": Color(0.55, 0.32, 0.2)})
	grip.position = Vector3(0, -0.16, 0.02); grip.rotation.x = 0.4; g.add_child(grip)
	var gcs := CollisionShape3D.new(); var gsh := BoxShape3D.new(); gsh.size = Vector3(0.3, 0.6, 0.3); gcs.shape = gsh; g.add_child(gcs)
	g.taken.connect(func(_p): _line_once("f48_shotgun"); hud.hint("H / D-pad up: change gun. R: reload." if not Game.uses_touch() else "GUN: change gun. RLD: reload.", 6.0))
	var s := Pickup.new(); s.item = "shells"; s.amount = 10; s.label = "box of shells"
	world.add_child(s); s.position = SAFE_AT + Vector3(0.08, 0.58, 0.02)
	var bx := MeshInstance3D.new(); bx.mesh = Build.box_mesh(Vector3(0.12, 0.06, 0.08)); bx.material_override = Tex.mat("cardboard", 8.0, {"tint": Color(0.8, 0.5, 0.35)})
	bx.position.y = 0.03; s.add_child(bx)
	var scs := CollisionShape3D.new(); var ssh := BoxShape3D.new(); ssh.size = Vector3(0.25, 0.15, 0.25); scs.shape = ssh; s.add_child(scs)

# ------------------------------------------------------------------ the three of them
func _figures() -> void:
	for f in FIGURES:
		var g := DraftFigure.new(); g.id = f[0]; g.tall = f[2]; g.tag = f[3]; g.identity = f[4]; g.player = player
		world.add_child(g); g.position = f[1]
		g.rotation.y = randf() * TAU
		g.downed.connect(func(_g): _line_once("f48_shot_figure"))
		figures.append(g)

func name_figure(f: DraftFigure, p) -> void:
	var n: RigidBody3D = p.held
	var word := String(n.get_meta("word"))
	if f.id == "child" and word == "SONYA":
		_sonya_tried = true
		_falls_off(n, f.global_position + Vector3(0, f.tall * 0.7, 0))
		_line_once("f48_sonya")
		_check_end()
		return
	if f.identity != "" and word == f.identity and f.dressed == "":
		p.drop_held(); n.queue_free()
		Sfx.play_at("paper", f.global_position + Vector3(0, 1.2, 0), -4.0, 1.0)
		Sfx.play_at("scrape", f.global_position + Vector3(0, 0.3, 0), -8.0, 1.3)
		Fx.burst("dust", f.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		f.dress(word)
		_line_once("f48_mama" if f.id == "mama" else "f48_papa")
		_check_end()
		return
	_falls_off(n, f.global_position + Vector3(0, f.tall * 0.7, 0))

## Each name has been tried: a note that wasn't on the wall before.
func _check_end() -> void:
	var done := _sonya_tried
	for f in figures:
		if f.identity != "" and f.dressed == "" and not f.down: done = false
	if done and not _ending: _unveil()

const LOBBY_AT := Vector3(5.5, 0.95, WALL_Z + 0.006)      # (low on the wall, under the others, on its own)
func _unveil(quiet := false) -> void:
	_ending = true
	if not quiet:
		await get_tree().create_timer(2.0).timeout
		Sfx.play_at("paper", LOBBY_AT, -2.0, 0.8)
		Sfx.play("sting", -16.0, 1.3)
		Fx.kick("fringe", 0.6, 1.2)
	var vis := Node3D.new(); world.add_child(vis); vis.position = LOBBY_AT; vis.rotation.z = -0.05
	_note_face(vis, "LOBBY")
	lobby_spot = Hotspot.make(world, LOBBY_AT + Vector3(0, 0, 0.02), Vector3(0.1, 0.1, 0.05), "Take the note: LOBBY", Callable())
	lobby_spot.action = _take_note.bind("LOBBY", lobby_spot, vis)
	if door47: door47.enabled = true
	Game.set_flag("lobby_unveiled")
	Game.set_flag("flat48_done")
	objective("47.")
	if not quiet: _line_once("f48_end")

## Across the landing, with LOBBY in his hand.
func _to_47() -> void:
	if not (player.held and String(player.held.get_meta("word", "")) == "LOBBY"):
		hud.hint("The note.", 3.0)
		return
	set_cutscene(true)
	Sfx.play_at("door_creak", door47.global_position, -6.0, 1.0)
	Game.set_flag("lobby_note")
	Game.checkpoint()
	Game.change_level("flat47", {"card": false})

func _line_once(id: String) -> void:
	if _said.has(id) or Dialogue.busy: return
	_said[id] = true
	Dialogue.play(id)

# ------------------------------------------------------------------ the story
func begin() -> void:
	Sfx.loop("drone", "drone", -24.0)
	Fx.reset({"grain": 0.04, "vignette": 0.35})
	Sfx.set_room(0.5, 0.2)
	Game.checkpoint()
	set_cutscene(false)
	random_talk = false
	objective("Flat 48.")
	await Game.fade(0.0, 1.0)
	if Game.flag("lobby_unveiled"): _unveil(true)        # (back from a checkpoint after it)
	else: _line_once("f48_enter")

## The first time one of them is in sight.
var _figures_seen := false
func _process(delta: float) -> void:
	super._process(delta)
	if not _figures_seen and not cutscene:
		for f in figures:
			if f.is_seen() and f.global_position.distance_to(player.global_position) < 7.0:
				_figures_seen = true; _line_once("f48_figures"); break
