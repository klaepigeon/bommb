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

func setup(p_main: Node) -> void:
	main = p_main

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
	var gun = p.get("gun")
	if gun:
		d["gun"] = {"loaded": gun.loaded, "spare": gun.spare, "drawn": gun.drawn}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(d))
	return true

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
