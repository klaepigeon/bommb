extends SceneTree
## Loads every script under res://scripts (and its folders) so parse errors show up at once.
var bad := 0

func _initialize() -> void:
	await process_frame
	_dir("res://scripts")
	print("PARSE_ALL bad=", bad)
	quit()

func _dir(d: String) -> void:
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".gd"):
			var s = load(d + "/" + f)
			if s == null or not s.can_instantiate(): print("BAD ", d, "/", f); bad += 1
	for sub in DirAccess.get_directories_at(d): _dir(d + "/" + sub)
