extends SceneTree
## Loads every script so parse errors show up at once.
func _initialize() -> void:
	await process_frame
	var bad := 0
	for d in ["res://scripts/core", "res://scripts/player", "res://scripts/ui", "res://scripts/dialogue", "res://scripts/socko", "res://scripts/world", "res://scripts/characters", "res://scripts/weapons", "res://scripts/levels"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate(): print("BAD ", f); bad += 1
	print("PARSE_ALL bad=", bad)
	quit()
