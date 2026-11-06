class_name Icons
extends RefCounted
## The Caller's little drawings: every icon on a card, a map page or a button is one of his
## sketches in blood-red ink (or bone-white ink, for the dark trick cards). They are drawn by
## tools/gen_ink.py (the drawings themselves live in tools/ink_icons.py) into assets/ink/icons.

const RED_DIR := "res://assets/ink/icons/red/"
const PALE_DIR := "res://assets/ink/icons/pale/"

static var _cache: Dictionary = {}
static var _img_cache: Dictionary = {}

static func _path(name: String, pale: bool) -> String:
	var p := (PALE_DIR if pale else RED_DIR) + name + ".png"
	if ResourceLoader.exists(p):
		return p
	return (PALE_DIR if pale else RED_DIR) + "q.png"

## The drawing for a name. Light ink asks for the bone-white version; anything else is red.
## (ink2 and scale are kept for old callers; the drawing carries its own hatching.)
static func tex(name: String, ink: Color = Color("7a0e0a"), _ink2: Color = Color(), _scale: int = 1) -> Texture2D:
	var pale := ink.get_luminance() > 0.55
	var key := name + ("|p" if pale else "|r")
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = load(_path(name, pale))
	_cache[key] = t
	return t

## The drawing as an Image at a given size (for painting into other textures).
static func image(name: String, size: int, pale := false) -> Image:
	var key := "%s|%d|%s" % [name, size, pale]
	if _img_cache.has(key):
		return _img_cache[key]
	var img: Image = tex(name, Color.WHITE if pale else Color("7a0e0a")).get_image()
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	_img_cache[key] = img
	return img

static func has(name: String) -> bool:
	return ResourceLoader.exists(RED_DIR + name + ".png")
