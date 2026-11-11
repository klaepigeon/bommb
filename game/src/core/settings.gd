extends Node
## Player settings, persisted to user://settings.cfg. Everything the brief asks to be adjustable:
## camera sensitivity and inversion, control layout and size, interaction sensitivity, subtitles,
## audio, graphics presets.

signal changed(key: String)

const PATH := "user://settings.cfg"

const DEFAULTS := {
	# camera
	"look_sensitivity": 1.0,        # multiplier, 0.2 .. 3
	"invert_y": false,
	"invert_x": false,
	# touch layout: control id -> Vector2 centre in normalized screen coordinates (0..1),
	# empty = the default layout. Scales apply to every button / the stick.
	"layout": {},
	"button_scale": 1.0,            # 0.7 .. 1.6
	"stick_scale": 1.0,
	"stick_floating": true,         # the stick appears where the thumb lands (left half)
	"hud_opacity": 0.55,
	# interaction
	"interact_hold_time": 0.35,     # seconds for hold actions (long-press = secondary verb)
	"aim_assist": 0.5,              # 0 .. 1, gentle slow-down over targets when aiming
	# subtitles
	"subtitles": true,
	"subtitle_size": 1.0,           # 0.75 .. 1.75
	"subtitle_background": true,
	"speaker_names": true,
	# audio (linear 0..1)
	"vol_master": 0.9,
	"vol_sfx": 1.0,
	"vol_music": 0.7,
	"vol_voice": 1.0,
	"tts_voice": true,              # synthesized voice under the subtitles, if the device has one
	# graphics
	"preset": "auto",               # auto | low | medium | high
	"fps_target": 30,               # 30 | 60
	"governor": true,               # step quality down when frames run long (thermal throttling)
	"show_perf": false,
	"grain": 1.0,
	"brightness": 1.0,
}

## The preset table. render_div: the 3D view renders at 1/render_div of the screen (PS1 pixels,
## and the biggest single performance lever on phones).
const PRESETS := {
	"low":    {"render_div": 4, "shadows": false, "lights": 2, "far": 22.0, "particles": 0.4, "torch_shadow": false},
	"medium": {"render_div": 3, "shadows": false, "lights": 4, "far": 32.0, "particles": 0.7, "torch_shadow": false},
	"high":   {"render_div": 2, "shadows": true,  "lights": 6, "far": 45.0, "particles": 1.0, "torch_shadow": true},
}

var data := {}

func _ready() -> void:
	data = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in cf.get_section_keys("s"):
			if DEFAULTS.has(k):
				data[k] = cf.get_value("s", k)

func get_v(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))

func set_v(key: String, value: Variant, persist := true) -> void:
	data[key] = value
	changed.emit(key)
	if persist:
		save()

func save() -> void:
	var cf := ConfigFile.new()
	for k in data:
		cf.set_value("s", k, data[k])
	cf.save(PATH)

func reset_layout() -> void:
	set_v("layout", {})
	set_v("button_scale", 1.0)
	set_v("stick_scale", 1.0)

static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web_android")

## The preset actually in effect ("auto" resolves to a guess from the platform; Perf may step it).
func preset_name() -> String:
	var p: String = get_v("preset")
	if p == "auto":
		return "low" if is_mobile() else "medium"
	return p

func preset() -> Dictionary:
	return PRESETS[preset_name()]
