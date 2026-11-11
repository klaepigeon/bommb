extends Node
## Loads every script and shader in the project, so parse errors anywhere show up in one run.
func _ready() -> void:
	var bad := 0
	for dir in ["res://src", "res://preserved"]:
		bad += _walk(dir)
	print("CHECK done, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)

func _walk(path: String) -> int:
	var bad := 0
	var d := DirAccess.open(path)
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdshader"):
			var r := load(path + "/" + f)
			if r == null or (r is GDScript and not (r as GDScript).can_instantiate() and not f.ends_with("_layout.gd")):
				print("CHECK FAIL ", path + "/" + f)
				bad += 1
	for sub in d.get_directories():
		bad += _walk(path + "/" + sub)
	return bad
