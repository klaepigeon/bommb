class_name ContentDB
extends RefCounted
## Loads every JSON file under res://data/. Each file holds one object whose keys are
## content categories ("abilities", "enemies", ...) mapping to arrays of definitions with a
## stable "id". Several files may contribute to one category. Duplicate ids are errors.

const CATEGORIES := ["tiles", "statuses", "abilities", "classes", "ancestries", "traits", "enemies",
	"bosses", "layouts", "encounters", "relics", "consumables", "rule_cards", "events", "settings",
	"dialogue", "unlocks", "names", "difficulties", "upgrades", "personas", "lore", "gear", "table_items",
	"totems", "families", "rooms", "areas", "portals", "windows", "things", "triggers", "npcs", "towns", "victims"]

var data: Dictionary = {}       # category -> id -> def
var order: Dictionary = {}      # category -> Array of ids in file order
var errors: Array = []
var source_of: Dictionary = {}  # "category:id" -> file

func _init() -> void:
	for c in CATEGORIES:
		data[c] = {}
		order[c] = []

func load_dir(path: String = "res://data") -> void:
	var files: Array = []
	_collect(path, files)
	files.sort()
	for f in files:
		load_file(f)

func _collect(path: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		errors.append("cannot open data directory %s" % path)
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				_collect(path.path_join(n), out)
		elif n.ends_with(".json"):
			out.append(path.path_join(n))
		n = d.get_next()

func load_file(f: String) -> void:
	var text := FileAccess.get_file_as_string(f)
	if text == "":
		errors.append("%s: empty or unreadable" % f)
		return
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("%s:%d: %s" % [f, json.get_error_line(), json.get_error_message()])
		return
	var root = json.data
	if typeof(root) != TYPE_DICTIONARY:
		errors.append("%s: top level must be an object of categories" % f)
		return
	for cat in root.keys():
		if cat.begins_with("_"):
			continue
		if not data.has(cat):
			errors.append("%s: unknown category '%s'" % [f, cat])
			continue
		var arr = root[cat]
		if typeof(arr) != TYPE_ARRAY:
			errors.append("%s: category '%s' must be an array" % [f, cat])
			continue
		for i in range(arr.size()):
			var e = arr[i]
			if typeof(e) != TYPE_DICTIONARY or not e.has("id"):
				errors.append("%s: %s[%d] has no id" % [f, cat, i])
				continue
			var id := str(e["id"])
			if data[cat].has(id):
				errors.append("%s: duplicate %s id '%s' (also in %s)" % [f, cat, id, source_of.get(cat + ":" + id, "?")])
				continue
			data[cat][id] = e
			order[cat].append(id)
			source_of[cat + ":" + id] = f

func has(cat: String, id: String) -> bool:
	return data.has(cat) and data[cat].has(id)

func get_def(cat: String, id: String) -> Dictionary:
	if data.has(cat) and data[cat].has(id):
		return data[cat][id]
	return {}

func all(cat: String) -> Array:
	var out: Array = []
	for id in order.get(cat, []):
		out.append(data[cat][id])
	return out

func ids(cat: String) -> Array:
	return order.get(cat, []).duplicate()

func ability(id: String) -> Dictionary:
	return get_def("abilities", id)

func status(id: String) -> Dictionary:
	return get_def("statuses", id)

func enemy(id: String) -> Dictionary:
	var e := get_def("enemies", id)
	if e.is_empty():
		e = get_def("bosses", id)
	return e
