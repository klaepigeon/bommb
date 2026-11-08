class_name FlatEscape
extends Node
## Getting out of Flat 47 (story bible §5, beat 12): the front door is on its chain, and the chain
## is padlocked on this side. Any of these gets you through it; they're the world's rules, not a
## script, and they can be mixed:
##
##   the axe     the hatchet from the box room: three blows on the chain, each one loud
##   the key     pull the bath's plug and wait while the black water goes down (gurgling: anything
##               listening hears it, again and again); at the bottom, in the silt, the other red
##               shoe and a ring of keys with a little brass one for the padlock. Quiet.
##   the gun     two rounds into the padlock. Very loud.
##
## Through the door: the white, and the end of the chapter. Ported from the JS build's openings.js
## and dress2.js (the chain, the bath, the keys); the text about the keys no longer names a husband.

const BATH := Vector3(7.35, 0.0, 7.62)
const PLUG := Vector3(6.55, 0.52, 7.62)      # the plug chain hangs over the rim at the tap end
const LINK_PITCH := 0.044    # one oval link's share of the chain
const WATER_TOP := 0.46
const WATER_BOTTOM := 0.105
const DRAIN_SECONDS := 30.0

var world: Node3D
var player: Node
var main: Node
var door: Node3D
var links: Array[MeshInstance3D] = []
var padlock: Hotspot
var padlock_mesh: MeshInstance3D
var water: MeshInstance3D
var draining := false
var drained := false
var has_key := false
var free := false
var _level := WATER_TOP
var _water_y0 := 0.0
var _gurgle_t := 0.0
var _padlock_hits := 0
var _ended := false
var _cutting := false
var _plate := Vector3.ZERO

signal freed(how: String)
signal chapter_end

func setup(p_world: Node3D, p_player: Node, p_main: Node) -> void:
	world = p_world; player = p_player; main = p_main
	door = world.find_child("door_dEntry", true, false)
	door.set("chain_handler", self)
	_chain()
	_bath()

# ---------------------------------------------------------------- the chain and the padlock
func _chain() -> void:
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color(0.42, 0.4, 0.38); steel.metallic = 0.85; steel.roughness = 0.42
	var tm := TorusMesh.new(); tm.inner_radius = 0.0095; tm.outer_radius = 0.0155; tm.rings = 10; tm.ring_segments = 5
	for i in 7:
		var m := MeshInstance3D.new(); m.mesh = tm; m.material_override = steel
		world.add_child(m); links.append(m)
	# the plate on the frame the chain runs to, the padlock hung through the last link
	var leaf_w: float = door.get("leaf_w")
	_plate = (door as Node3D).global_transform * Vector3(leaf_w + 0.05, 1.55, 0.06)
	var plate := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.1, 0.06, 0.02); plate.mesh = pb; plate.material_override = steel
	world.add_child(plate); plate.global_transform = Transform3D((door as Node3D).global_transform.basis, _plate)
	padlock = Hotspot.make(world, _plate + Vector3(0, -0.05, 0), Vector3(0.08, 0.08, 0.06), "", Callable(), func(_p): return padlock_shot())
	padlock.name = "Padlock"
	padlock_mesh = MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.032, 0.036, 0.013); padlock_mesh.mesh = lm
	var brass := StandardMaterial3D.new(); brass.albedo_color = Color(0.55, 0.45, 0.26); brass.metallic = 0.8; brass.roughness = 0.4
	padlock_mesh.material_override = brass; padlock.add_child(padlock_mesh)
	var shackle := MeshInstance3D.new(); var sm := TorusMesh.new(); sm.inner_radius = 0.009; sm.outer_radius = 0.013; shackle.mesh = sm
	shackle.material_override = steel; shackle.position = Vector3(0, 0.022, 0); shackle.rotation.x = PI * 0.5; padlock.add_child(shackle)

func _process(delta: float) -> void:
	if not free:
		# the chain from the leaf to the plate: a fixed length of oval links, alternately upright and
		# flat, hanging in a curve that pulls taut as the door opens up to it
		var leaf_w: float = door.get("leaf_w")
		var a := (door as Node3D).global_transform * Vector3(leaf_w - 0.08, 1.55, 0.05)
		var span := a.distance_to(_plate)
		var length := links.size() * LINK_PITCH
		var sag := sqrt(maxf(0.0, 3.0 * span * (length - span) / 8.0))
		var dir := (_plate - a).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		for i in links.size():
			var t := (i + 0.5) / links.size()
			var p := a.lerp(_plate, t) - Vector3(0, 4.0 * t * (1.0 - t) * sag, 0)
			# the local slope of the curve, so each link lies along it
			var tan_ := (dir * span - Vector3(0, 4.0 * (1.0 - 2.0 * t) * sag, 0)).normalized()
			var ring_axis := side if i % 2 == 0 else tan_.cross(side).normalized()
			var x := ring_axis.cross(tan_).normalized()
			links[i].global_transform = Transform3D(Basis(x, ring_axis, tan_ * 1.7), p)
	if draining and not drained:
		_level = maxf(WATER_BOTTOM, _level - delta * (WATER_TOP - WATER_BOTTOM) / DRAIN_SECONDS)
		if water: water.global_position.y = _water_y0 + (_level - WATER_TOP)
		_gurgle_t -= delta
		if _gurgle_t <= 0.0:
			_gurgle_t = randf_range(2.5, 4.0)
			_sfx(_gurgle(), PLUG, -4.0)
			Noises.make(get_tree(), PLUG, 0.42, "gurgle", player)    # it carries; she hears it
		if _level <= WATER_BOTTOM + 0.001: _drained()
	# through the door: the end of the chapter
	if free and not _ended and player.global_position.x > 10.35 and absf(player.global_position.z - 4.56) < 0.7:
		_end()

func _is_axe(item: Node) -> bool:
	return item != null and is_instance_valid(item) and String(item.get("title")).to_lower().contains("axe")

func use_with_prompt(item: Node) -> String:
	return "Cut the chain with the axe" if _is_axe(item) and not free else ""

func use_with(item: Node) -> bool:
	if not _is_axe(item) or free or _cutting: return false
	_axe(); return true

func chain_prompt(_d: Node) -> String:
	if has_key: return "Unlock the padlock"
	return "Close" if float(door.get("target")) > 0.05 else "Open"

func chain_use(_d: Node, _p: Node) -> bool:
	if has_key:
		_free("key"); return true
	if float(door.get("target")) > 0.05:
		door.set("target", 0.0)
	else:
		door.set("target", 0.11)
		_sfx(_rattle(), _plate, -2.0)
		if not Game.flags.get("chain_seen", false):
			Game.flags["chain_seen"] = true
			Game.say("The chain is padlocked on this side. No key on the ring by the door.", 4.5)
			if main.get("socko_hud"): main.socko_hud.set_objective("The chain's padlocked. Get through it.")
			if Game.flags.get("has_revolver", false): _socko("chain_gun", "Locked? Shoot it. Two seconds.", "happy", 1.2)
			else: _socko("chain_axe", "Locked. There's an axe in the box room. Hit it till it stops being a chain.", "impatient", 1.2)
	return true

## three blows; the chain gives on the third
func _axe() -> void:
	_cutting = true
	player.set("locked", true)
	for i in 3:
		player.set("shake", 0.9)
		_sfx(_clang(0.9 + i * 0.1), _plate, 0.0)
		Noises.make(get_tree(), _plate, 0.85, "axe", player)
		await get_tree().create_timer(0.62).timeout
	player.set("locked", false)
	_free("axe")

## the revolver: two rounds into the padlock (Revolver calls shot() on it)
func padlock_shot() -> bool:
	if free: return false
	_padlock_hits += 1
	_sfx(_clang(1.6), padlock.global_position, -2.0)
	padlock_mesh.rotation.z += 0.4
	if _padlock_hits >= 2: _free("gun")
	return true

func _free(how: String, quiet := false) -> void:
	if free: return
	free = true
	# the chain falls in a heap under its plate (it stays there)
	var floor_at := Vector3(_plate.x - 0.06, 0.012, _plate.z - 0.05)
	for i in links.size():
		var b := Basis.from_euler(Vector3(randf_range(-0.5, 0.5) + PI * 0.5 * (i % 2), randf() * TAU, randf_range(-0.4, 0.4))) * Basis.from_scale(Vector3(1, 1, 1.7))
		links[i].global_transform = Transform3D(b, floor_at + Vector3(randf_range(-0.05, 0.05), 0.008 * (i % 3), randf_range(-0.05, 0.05)))
	# the padlock drops (to the floor, as a thing you could pick up)
	padlock.visible = false; padlock.process_mode = Node.PROCESS_MODE_DISABLED
	door.set("locked", ""); door.set("max_angle", 1.45); door.set("target", 1.45)
	Game.flags["escaped_by"] = how
	if main.get("socko_hud"): main.socko_hud.set_objective("Out.")
	if quiet: return
	_sfx(_rattle(), _plate, 0.0)
	match how:
		"axe": Game.say("Three blows. The chain gives on the third and falls in a heap. The door swings out on its own weight.", 5.0)
		"key": Game.say("The little key turns. The padlock drops into your hand, cold. The chain slides off.", 5.0)
		"gun": Game.say("The padlock comes apart on the second round. The chain drops. The door swings out.", 5.0)
	freed.emit(how)
	match how:
		"axe", "gun": _socko("freed", "Ha! That's how you open a door.", "happy", 1.0); _socko_judges(1.5)
		"key": _socko("freed", "Finally. I aged.", "disappointed", 1.0); _socko_judges(-1.5)

# ---------------------------------------------------------------- the bath
func _bath() -> void:
	# the black water: the thin slab in the bath, from the model
	for mi in world.get_node("Apartment").find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.y < 0.05 and a.size.x > 1.2 and a.size.x < 1.9 and absf(a.get_center().y - WATER_TOP) < 0.06 and a.get_center().distance_to(BATH + Vector3(0, WATER_TOP, 0)) < 0.5:
			water = m; _water_y0 = m.global_position.y; break
	# the silt under the black water: you only see it once the water's gone
	var silt := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(1.22, 0.004, 0.46); silt.mesh = sm
	var smat := StandardMaterial3D.new(); smat.albedo_color = Color(0.36, 0.31, 0.24); smat.roughness = 0.35; smat.metallic_specular = 0.7
	silt.material_override = smat; silt.name = "Silt"
	world.add_child(silt); silt.global_position = BATH + Vector3(0, WATER_BOTTOM + 0.003, 0)
	Hotspot.make(world, PLUG, Vector3(0.1, 0.12, 0.12), "Pull the plug", pull_plug).name = "Plug"

func pull_plug() -> void:
	if draining:
		Game.say("It's draining. Slowly.", 2.5); return
	draining = true
	_sfx(_gurgle(), PLUG, 0.0)
	Game.say("You put your arm into the cold to the elbow and find the chain. Something gives. The water begins to turn.", 5.0)
	Game.flags["bath_draining"] = true
	_socko_judges(-1.0)
	_socko("bath", "Or. Or. We shoot the lock. Takes two seconds. The bath takes forever.", "impatient", 3.0)

func _drained(quiet := false) -> void:
	drained = true; draining = true; _level = WATER_BOTTOM
	if water: water.visible = false
	if not quiet: Game.say("At the bottom, in the silt: the other red shoe. Right foot. And a ring of keys.", 5.0)
	var keys := Hotspot.make(world, BATH + Vector3(-0.2, WATER_BOTTOM + 0.004, -0.1), Vector3(0.16, 0.06, 0.12), "Take the keys")
	keys.name = "Keys"; keys.on_use = func(): take_keys(keys)
	var kit := TownKit.new(keys)
	kit.cyl_axis("iron", Vector3(-0.002, 0.004, 0), Vector3(0.002, 0.004, 0), 0.02, 10)
	for i in 3:
		kit.box("gold", Vector3(0.035 + i * 0.005, 0.004, (i - 1) * 0.013), Vector3(0.024 - i * 0.004, 0.0015, 0.006), Basis(Vector3.UP, (i - 1) * 0.4))
	kit.box("china", Vector3(-0.045, 0.005, 0), Vector3(0.026, 0.004, 0.013))     # the plastic fob, pale
	kit.finish()
	# the pair to the hall's shoe: the same shoe, mirrored for the right foot, lying on its side
	var shoe := Node3D.new(); shoe.name = "Child's shoe (right)"
	var left: Node = world.find_child("*Child_s_shoe*", true, false)
	var copied := 0
	if left:
		for mi in left.find_children("*", "MeshInstance3D", true, false) + ([left] if left is MeshInstance3D else []):
			var m := (mi as MeshInstance3D).duplicate(0) as MeshInstance3D
			for c in m.get_children(): c.queue_free()
			m.transform = (left as Node3D).global_transform.affine_inverse() * (mi as Node3D).global_transform
			shoe.add_child(m); copied += 1
	if copied == 0:
		var sk := TownKit.new(shoe)
		sk.box("lipstick", Vector3(0, 0.02, 0), Vector3(0.035, 0.02, 0.075))
		sk.box("lipstick", Vector3(0, 0.035, 0.04), Vector3(0.03, 0.012, 0.035))
		sk.box("iron", Vector3(0.036, 0.038, -0.01), Vector3(0.004, 0.006, 0.012))
		sk.finish()
	world.add_child(shoe)
	shoe.global_transform = Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.FORWARD, 0.3) * Basis.from_scale(Vector3(-1, 1, 1)), BATH + Vector3(0.3, WATER_BOTTOM + 0.008, 0.05))
	load("res://scripts/world/pickable.gd").make(shoe, {"kind": "pick", "name": "Child's shoe", "desc": "A girl's red buckle shoe, right foot. The pair to the one in the hall.", "mass": 0.2})

func take_keys(node: Node) -> void:
	has_key = true
	Game.flags["has_key"] = true
	Game.say("A ring of keys on a plastic fob. A flat key, a letterbox key, and a little brass one for a padlock. Somebody dropped them in the bath, or hid them there.", 6.0)
	node.queue_free()

# ---------------------------------------------------------------- saving
func save_state() -> Dictionary:
	return {"free": free, "how": Game.flags.get("escaped_by", ""), "draining": draining, "drained": drained,
		"level": _level, "has_key": has_key, "hits": _padlock_hits}

func restore(d: Dictionary) -> void:
	_padlock_hits = int(d.get("hits", 0))
	if d.get("drained", false):
		_drained(true)
		if d.get("has_key", false):
			var k := world.find_child("Keys", true, false)
			if k: k.free()
	elif d.get("draining", false):
		draining = true; _level = float(d.get("level", WATER_TOP))
		if water: water.global_position.y = _water_y0 + (_level - WATER_TOP)
	has_key = bool(d.get("has_key", false))
	if d.get("free", false): _free(String(d.get("how", "axe")), true)

# ---------------------------------------------------------------- the end of the chapter
func _end() -> void:
	_ended = true
	player.set("locked", true)
	SaveGame.wipe()            # the chapter's done: next time starts at the beginning
	chapter_end.emit()
	if Game.flags.get("marta_dead", false): _socko("end", "Look at us. Look at us go. Didn't even need the tutorial.", "happy")
	else: _socko("end", "See? Easy. Next time we just do it my way.", "happy")
	await get_tree().create_timer(3.5).timeout
	Game.fade.emit(1.0, 2.5)
	await get_tree().create_timer(3.0).timeout
	var card := CanvasLayer.new(); card.layer = 30; card.name = "ChapterEnd"
	var bg := ColorRect.new(); bg.color = Color.BLACK; bg.set_anchors_preset(Control.PRESET_FULL_RECT); card.add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); card.add_child(c)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); c.add_child(v)
	for line in [["H Y S T E R I A", 30, Color(0.85, 0.82, 0.75)], ["Flat 47", 20, Color(0.72, 0.6, 0.38)], ["the end of the first chapter", 16, Color(0.6, 0.6, 0.58)]]:
		var l := Label.new(); l.text = line[0]; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", line[1]); l.add_theme_color_override("font_color", line[2]); v.add_child(l)
	main.add_child(card)
	Game.flags["chapter_1_done"] = true

# ---------------------------------------------------------------- Socko on the way out
## He wants it done fast and loud. Lines once each; nothing if he isn't on the hand yet.
var _said := {}
func _socko(key: String, text: String, emo := "impatient", delay := 0.0) -> void:
	if _said.has(key): return
	var s = main.get("socko")
	if not s or not (s as Node3D).visible: return
	_said[key] = true
	if delay > 0.0: await get_tree().create_timer(delay).timeout
	while s.get("talking"): await get_tree().create_timer(0.3).timeout
	s.call("say", text, emo, 1.0)

## What Socko makes of what Kurt chose: + did it his way (loud, violent), - didn't. His
## performance state (SockoDirector) follows: enough defiance and the friendliness wears thin.
func _socko_judges(w: float) -> void:
	var s = main.get("socko")
	if not s or not s.get("director"): return
	if w > 0.0: s.director.obeyed(w)
	else: s.director.defied(-w)

# ---------------------------------------------------------------- sounds
func _sfx(w: AudioStreamWAV, at: Vector3, db: float) -> void:
	var ap := AudioStreamPlayer3D.new(); ap.stream = w; ap.unit_size = 4.0; ap.volume_db = db
	world.add_child(ap); ap.global_position = at; ap.play(); ap.finished.connect(ap.queue_free)

static func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size(): bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = bytes
	return w

static func _gurgle() -> AudioStreamWAV:
	const R := 22050
	var n := int(R * 2.2); var s := PackedFloat32Array(); s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / R
		lp += (randf_range(-1, 1) - lp) * 0.05
		var bub := sin(TAU * (180.0 + 120.0 * sin(t * 23.0)) * t) * (0.5 + 0.5 * sin(t * TAU * 3.7))
		s[i] = (lp * 1.2 + bub * 0.25) * exp(-pow(t - 1.0, 2.0) * 1.5) * 0.7
	return _wav(s, R)

static func _clang(pitch: float) -> AudioStreamWAV:
	const R := 22050
	var n := int(R * 1.0); var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / R
		s[i] = (sin(TAU * 620.0 * pitch * t) + 0.6 * sin(TAU * 1490.0 * pitch * t) + 0.3 * sin(TAU * 2830.0 * pitch * t)) * exp(-t * 7.0) * 0.4 + randf_range(-1, 1) * exp(-t * 60.0) * 0.5
	return _wav(s, R)

static func _rattle() -> AudioStreamWAV:
	const R := 22050
	var n := int(R * 0.6); var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / R
		var tick := 1.0 if fmod(t * 23.0 + sin(t * 40.0), 1.0) < 0.08 else 0.0
		s[i] = (sin(TAU * 2600.0 * t) * tick + randf_range(-1, 1) * tick * 0.5) * (1.0 - t / 0.6) * 0.5
	return _wav(s, R)
