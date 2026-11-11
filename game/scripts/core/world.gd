extends Node
## WorldState: one dictionary of everything that persists (story flags, what's been done to the
## building, where things are, how people feel), and the bus the systems talk through. Saving is
## writing this out; every system that owns state registers a saver/loader pair.

signal flag_changed(key: String, value)
signal event(name: String, data: Dictionary)

var flags := {}
var savers := {}                 ## key -> Callable() -> Variant
var loaders := {}                ## key -> Callable(Variant)
var loaded_state := {}           ## the save being restored (systems read their part when they build)
const PATH := "user://save.json"
const VERSION := 1

func set_flag(key: String, value = true) -> void:
	if flags.get(key) == value:
		return
	flags[key] = value
	Log.mark("flag %s=%s" % [key, str(value)])
	flag_changed.emit(key, value)

func flag(key: String, default = false):
	return flags.get(key, default)

func count(key: String, by := 1) -> int:
	var v := int(flags.get(key, 0)) + by
	set_flag(key, v)
	return v

func emit_event(name: String, data := {}) -> void:
	event.emit(name, data)

func register(key: String, saver: Callable, loader: Callable) -> void:
	savers[key] = saver
	loaders[key] = loader
	if loaded_state.has(key):
		loader.call(loaded_state[key])

func unregister(key: String) -> void:
	savers.erase(key)
	loaders.erase(key)

func snapshot() -> Dictionary:
	var d := {"version": VERSION, "flags": flags.duplicate(true), "systems": {}}
	for k in savers:
		var c: Callable = savers[k]
		if c.is_valid():
			d.systems[k] = c.call()
	return d

func save_game() -> bool:
	var d := snapshot()
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_encode(d)))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH))
	Log.mark("saved")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(PATH)

func read_save() -> Dictionary:
	if not has_save():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return {}
	return _decode(d)

## Restores flags now; systems pick up their part as they register (or immediately, if they
## already have).
func restore(d: Dictionary) -> void:
	flags = d.get("flags", {}).duplicate(true)
	loaded_state = d.get("systems", {})
	for k in loaders:
		if loaded_state.has(k):
			(loaders[k] as Callable).call(loaded_state[k])

func wipe() -> void:
	flags.clear()
	loaded_state.clear()
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

# Vector3s and Transform3Ds survive JSON as tagged arrays.
static func _encode(v):
	if v is Vector3: return {"_v3": [v.x, v.y, v.z]}
	if v is Transform3D:
		var b: Basis = v.basis; var o: Vector3 = v.origin
		return {"_xf": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, o.x, o.y, o.z]}
	if v is Dictionary:
		var o := {}
		for k in v: o[str(k)] = _encode(v[k])
		return o
	if v is Array:
		var a := []
		for x in v: a.append(_encode(x))
		return a
	return v

static func _decode(v):
	if v is Dictionary:
		if v.has("_v3"): return Vector3(v._v3[0], v._v3[1], v._v3[2])
		if v.has("_xf"):
			var a: Array = v._xf
			return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))
		var o := {}
		for k in v: o[k] = _decode(v[k])
		return o
	if v is Array:
		var a := []
		for x in v: a.append(_decode(x))
		return a
	return v
