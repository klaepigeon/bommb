extends Node
## The one place asset paths live (assets/data/assets.json). Gameplay asks for things by
## id; replacing a face, a sound or a song is an edit to that file (or a file dropped in
## user://faces/), never to gameplay code. Anything missing gets a fallback.

const MANIFEST := "res://assets/data/assets.json"

var manifest: Dictionary = {}
var faces: Array[Texture2D] = []
var _cache: Dictionary = {}
var _fallback_sfx: AudioStreamWAV


func _ready() -> void:
	manifest = load_json(MANIFEST)
	for p in manifest.get("faces", []):
		faces.append(_load_tex(str(p)))
	# Developer-supplied photos (tools/make_faces.py output, or any small PNG).
	var d := DirAccess.open("user://faces")
	if d:
		for f in d.get_files():
			if f.get_extension().to_lower() == "png":
				var img := Image.load_from_file("user://faces/" + f)
				if img:
					faces.append(ImageTexture.create_from_image(img))


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Assets: missing %s" % path)
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func face_count() -> int:
	return maxi(faces.size(), 1)


func face_texture(i: int) -> Texture2D:
	if faces.is_empty():
		return LcTex.solid(Color(0.86, 0.7, 0.6))
	var t := faces[posmod(i, faces.size())]
	return t if t else LcTex.solid(Color(0.86, 0.7, 0.6))


func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p)
	push_warning("Assets: missing face %s" % p)
	return null


func stream(group: String, id: String) -> AudioStream:
	var key := group + ":" + id
	if _cache.has(key):
		return _cache[key]
	var p := str((manifest.get(group, {}) as Dictionary).get(id, ""))
	var s: AudioStream = null
	if p != "" and ResourceLoader.exists(p):
		s = load(p)
	if s == null and group == "sfx":
		push_warning("Assets: no sound '%s', using a blip" % id)
		s = fallback_sfx()
	_cache[key] = s
	return s


## A short square blip, for any sound that hasn't been made yet.
func fallback_sfx() -> AudioStreamWAV:
	if _fallback_sfx:
		return _fallback_sfx
	var rate := 22050
	var data := PackedByteArray()
	for i in int(rate * 0.08):
		var v := (1.0 if sin(i * TAU * 660.0 / rate) > 0.0 else -1.0) * (1.0 - float(i) / (rate * 0.08)) * 0.3
		data.append(int(v * 127.0) & 0xff)
	_fallback_sfx = AudioStreamWAV.new()
	_fallback_sfx.format = AudioStreamWAV.FORMAT_8_BITS
	_fallback_sfx.mix_rate = rate
	_fallback_sfx.data = data
	return _fallback_sfx
