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
	"voices": false,            ## text-to-speech for spoken lines (placeholder voices; off by default)
	"quality": "auto",          ## auto / low / high (render scale)
	"screen_shake": 1.0,        ## camera shake, hit-stop, fov kicks (0 = none)
	"safe_mode": false,         ## after a crash: no voices, low picture, no particles or dust
}
const PATH := "user://settings.cfg"

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in values:
			values[k] = cf.get_value("s", k, values[k])
		if int(cf.get_value("s", "_v", 1)) < 2:
			values["voices"] = false           # 1.3.1: placeholder TTS off (a crash risk on some phones)
	_apply()

func get_v(k: String):
	return values.get(k)

func set_v(k: String, v) -> void:
	values[k] = v
	var cf := ConfigFile.new()
	for key in values:
		cf.set_value("s", key, values[key])
	cf.set_value("s", "_v", 2)
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
