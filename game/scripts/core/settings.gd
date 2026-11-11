extends Node
## Player settings (user://settings.cfg): look, brightness, subtitles, the HUD, controls.
signal changed

var values := {
	"look_sensitivity": 1.0,
	"invert_y": false,
	"brightness": 1.0,          ## gamma on the finished picture
	"subtitle_size": 1.0,       ## 0.75 .. 1.75
	"subtitles": true,
	"socko_side": "left",       ## where Socko and the touch stick sit (left-handed players: "right")
	"prompts": "socko",         ## "socko": Socko points, the USE button names the verb; "text": also a line of text
	"hud_opacity": 1.0,         ## the touch buttons
	"master_volume": 1.0,
	"voices": true,             ## text-to-speech for spoken lines
	"quality": "auto",          ## auto / low / high (render scale)
}
const PATH := "user://settings.cfg"

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in values:
			values[k] = cf.get_value("s", k, values[k])
	_apply()

func get_v(k: String):
	return values.get(k)

func set_v(k: String, v) -> void:
	values[k] = v
	var cf := ConfigFile.new()
	for key in values:
		cf.set_value("s", key, values[key])
	cf.save(PATH)
	_apply()
	changed.emit()

func _apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(values.master_volume), 0.001)))

func is_touch() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")

func is_phone() -> bool:
	return OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--phone")
