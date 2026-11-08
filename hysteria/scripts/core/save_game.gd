class_name SaveGame
extends Node
## Saving and continuing (prompt §14). One slot, user://save.json, kept quietly: every half minute
## once Socko is on the hand, when the game is paused, and when the app is put away or closed.
## Launching the game continues from it. What's kept is what the world is made of: the flags, where
## Kurt stands and which place he's in, the revolver, the wardrobe, the bath and the chain, the
## nuggets he's taken, and which of Socko's lines he's already said (he doesn't repeat himself).
##
## Developer reset: "Restart chapter" in the pause menu wipes the slot; so does launching with
## `-- fresh`. Finishing the chapter wipes it too (the next launch starts at the beginning).

const PATH := "user://save.json"
const VERSION := 1
const EVERY := 30.0

var main: Node
var _t := 0.0
var loaded_from_save := false

var _start := {}      # prop name -> where it was at the start (only what's moved is saved)

func setup(p_main: Node) -> void:
	main = p_main
	_remember_start.call_deferred()

func _remember_start() -> void:
	for b in _props(): _start[String(b.name)] = b.global_transform

## every loose thing in both places (not what's in Marta's hands)
func _props() -> Array:
	var out := []
	for parent in [main.world, main.labyrinth]:
		for b in parent.find_children("*", "RigidBody3D", true, false):
			if b.get_script() and String(b.get_script().resource_path).ends_with("prop.gd") and not main.hunter.is_ancestor_of(b):
				out.append(b)
	return out

static func _t2a(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]

static func _a2t(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func wipe() -> void:
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _process(delta: float) -> void:
	_t += delta
	if _t >= EVERY:
		_t = 0.0
		save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save()

## Is now a fair moment to save? Not before Socko (the opening plays every time until then), not
## mid-cutscene or mid-push, not once the chapter's over.
func can_save() -> bool:
	var f: Dictionary = Game.flags
	if not f.get("socko_intro_done", false) or f.get("chapter_1_done", false): return false
	var p: Node = main.player
	if p.locked: return false
	var esc = main.get("escape")
	if esc and esc._ended: return false
	return true

## Said in the pause menu when Save can't: what's in the way.
func why_not() -> String:
	var f: Dictionary = Game.flags
	if not f.get("socko_intro_done", false): return "Not yet. Get up first."
	if f.get("chapter_1_done", false): return "The chapter's over."
	return "Not now. Wait until you can move."

func save() -> bool:
	if not main or not can_save(): return false
	var p: Node = main.player
	var d := {
		"version": VERSION,
		"flags": Game.flags.duplicate(true),
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z],
		"yaw": p.yaw, "pitch": p.pitch,
		"in_labyrinth": main.in_labyrinth,
		"socko_said": main.socko_tutorial.said.duplicate(),
		"lab_said": main.socko_lab.said.duplicate(),
		"objective": main.socko_hud.text.text,
		"escape": main.escape.save_state(),
	}
	if main.in_labyrinth:
		var local: Vector3 = main.labyrinth.to_local(p.global_position)
		d["pos"] = [local.x, local.y, local.z]
	# things he's moved, where he left them, and which place they're in
	var props := {}
	for b in _props():
		var nm := String(b.name)
		var lab: bool = main.labyrinth.is_ancestor_of(b)
		var t: Transform3D = b.global_transform
		if lab: t = main.labyrinth.global_transform.affine_inverse() * t
		if lab or not _start.has(nm) or (_start[nm] as Transform3D).origin.distance_to(b.global_position) > 0.03:
			props[nm] = {"lab": lab, "t": _t2a(t)}
	d["props"] = props
	var gun = p.get("gun")
	if gun:
		d["gun"] = {"loaded": gun.loaded, "spare": gun.spare, "drawn": gun.drawn}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(d))
	return true

func _restore_props(saved: Dictionary) -> void:
	if saved.is_empty(): return
	var by_name := {}
	for b in _props(): by_name[String(b.name)] = b
	for nm in saved:
		var b: RigidBody3D = by_name.get(nm)
		if not b and String(nm).ends_with("_body"):
			b = _loosen(String(nm).trim_suffix("_body"))
		if not b: continue
		var e: Dictionary = saved[nm]
		var home: Node = main.labyrinth if e.get("lab", false) else main.world
		if b.get_parent() != home: b.reparent(home)
		var t := _a2t(e.t)
		b.global_transform = (main.labyrinth.global_transform * t) if e.get("lab", false) else t
		b.linear_velocity = Vector3.ZERO; b.sleeping = true

## something still sitting in a drawer or on a shelf (a Pickable) that he'd taken out: make it loose
func _loosen(base: String) -> RigidBody3D:
	for parent in [main.world, main.labyrinth]:
		var n: Node = parent.find_child(base, true, false)
		if not n: continue
		for c in n.get_children():
			if c.get_script() and String(c.get_script().resource_path).ends_with("pickable.gd"):
				var ex: Dictionary = c.ex
				var e := {"name": ex.get("name", "thing"), "desc": ex.get("desc", ""), "mass": ex.get("mass", 0.2), "size": [0.1, 0.1, 0.1], "centre": [0, 0, 0]}
				c.free()
				return load("res://scripts/world/prop.gd").make(n, e)
	return null

## Marta had Sonya's shoes: give them back to her
func _restore_shoes(n: int) -> void:
	var h: Node = main.hunter
	h.wake()
	var found := []
	for b in _props():
		if String(b.get("title")).to_lower().begins_with("child's shoe"): found.append(b)
	if found.size() < n:
		var right := _loosen("Child's shoe (right)")
		if right: found.append(right)
	for i in mini(n, found.size()): h.take_shoe(found[i])
	if h.at_peace and not h._path.is_empty():
		h.position = h._path[h._path.size() - 1]; h._path.clear()

## Continue from the slot, if there is one. Called once everything else is set up.
func load_game() -> bool:
	if not exists(): return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary or int(d.get("version", 0)) != VERSION:
		wipe(); return false
	var p: Node = main.player
	# the flags first: everything else reads them. Same dictionary, new contents.
	Game.flags.clear()
	Game.flags.merge(d.get("flags", {}), true)
	if Game.flags.has("nuggets"): Game.flags["nuggets"] = int(Game.flags.nuggets)   # JSON made it a float
	# the opening's done: Marta gone from the chair, Socko on the hand
	main.encounter.skip()
	main.socko_intro.skip()
	main.socko_tutorial.said.merge(d.get("socko_said", {}), true)
	main.socko_lab.said.merge(d.get("lab_said", {}), true)
	if String(d.get("objective", "")) != "":
		main.socko_hud.set_objective(String(d.objective), true)
	# the world as he left it
	if Game.flags.get("wardrobe_pushed", false): main.wardrobe.restore_pushed()
	var taken: Dictionary = Game.flags.get("nuggets_taken", {})
	for parent in [main.world, main.labyrinth]:
		for n in parent.get_children():
			if n is Nugget and taken.has(String(n.name)): n.free()
	main.escape.restore(d.get("escape", {}))
	_restore_props(d.get("props", {}))
	if Skills.owned("the_bow"): p.set("throw_power", 1.35)
	if Game.flags.get("has_revolver", false):
		for n in main.labyrinth.find_children("*", "StaticBody3D", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("revolver_pickup.gd"):
				n.interact(p); break
		var g = p.get("gun")
		if g and d.has("gun"):
			g.loaded = int(d.gun.loaded); g.spare = int(d.gun.spare); g.drawn = bool(d.gun.drawn)
	if Game.flags.get("marta_dead", false):
		main.hunter.wake(); main.hunter._die()
	elif int(Game.flags.get("marta_shoes", 0)) > 0:
		_restore_shoes(int(Game.flags.marta_shoes))
	# where he stood
	var at := Vector3(d.pos[0], d.pos[1], d.pos[2])
	if d.get("in_labyrinth", false):
		main.enter_labyrinth()
		at = main.labyrinth.to_global(at)
	p.global_position = at; p.velocity = Vector3.ZERO
	p.yaw = float(d.get("yaw", 0.0)); p.pitch = float(d.get("pitch", 0.0))
	loaded_from_save = true
	Game.say("Continued.", 2.5)
	return true
