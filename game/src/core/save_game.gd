class_name SaveGame
## Saving and loading. One slot plus an autosave at checkpoints. A save holds: the story ledger
## and flags, the infection, the level and Kurt (position, injuries, inventory, the revolver), and
## every persistent object in the level (doors, drawers, padlocks, breakables, props moved or taken).
## Versioned; new fields are added, never renamed.

const PATH := "user://save.json"
const VERSION := 1

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func save_game(main: Node, label := "") -> bool:
	var lvl: Level = main.level
	var p: Player = main.player
	if not lvl or not p:
		return false
	var objs := {}
	for n in lvl.get_tree().get_nodes_in_group("persist"):
		var i := n as Interactable
		if i and i.persist_id != "" and lvl.is_ancestor_of(i):
			objs[i.persist_id] = i.get_state()
	for n in lvl.get_tree().get_nodes_in_group("persist_props"):
		var pr := n as Prop
		if pr and lvl.is_ancestor_of(pr):
			objs["prop:" + pr.persist_id] = pr.get_state()
	var d := {
		"version": VERSION, "label": label, "time": Time.get_datetime_string_from_system(),
		"level": lvl.level_name, "story": Story.to_dict(), "infection": Infection.to_dict(),
		"player": p.get_state(), "gun": p.gun.get_state() if p.gun else {},
		"power": lvl.power.get_state(), "objects": objs,
		"director": main.director.get_state() if main.director and main.director.has_method("get_state") else {},
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(d))
	return true

static func read() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if not f:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

static func load_game(main: Node) -> bool:
	var d := read()
	if d.is_empty():
		return false
	Story.from_dict(d.get("story", {}))
	Infection.from_dict(d.get("infection", {}))
	var lname := String(d.get("level", "flat47"))
	main.set_meta("restoring", d)
	await main.load_level(lname, "restore")
	var lvl: Level = main.level
	var p: Player = main.player
	p.set_state(d.get("player", {}))
	var gun_d: Dictionary = d.get("gun", {})
	if not gun_d.is_empty():
		main.director.give_gun(false) if main.director and main.director.has_method("give_gun") else null
		if p.gun: p.gun.set_state(gun_d)
	lvl.power.set_state(d.get("power", {}))
	var objs: Dictionary = d.get("objects", {})
	for n in lvl.get_tree().get_nodes_in_group("persist"):
		var i := n as Interactable
		if i and objs.has(i.persist_id):
			i.set_state(objs[i.persist_id])
	for n in lvl.get_tree().get_nodes_in_group("persist_props"):
		var pr := n as Prop
		if not pr:
			continue
		if Story.flag("gone:" + pr.persist_id, false):
			pr.queue_free()
		elif objs.has("prop:" + pr.persist_id):
			pr.set_state(objs["prop:" + pr.persist_id])
	if main.director and main.director.has_method("set_state"):
		main.director.set_state(d.get("director", {}))
	main.remove_meta("restoring")
	return true

static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
