extends Node
## Player settings (user://settings.cfg): volumes, graphics quality, frame cap, name,
## the relay server. Everything else reads from here; nothing here knows about gameplay.

signal changed

const PATH := "user://settings.cfg"
const QUALITY := ["LOW", "MEDIUM", "HIGH"]

var values := {
	"master": 0.9, "music": 0.7, "sfx": 0.9, "voice": 0.9, "ambience": 0.6,
	"quality": 1,          # 0 LOW (240 lines, 30 fps), 1 MEDIUM (360 lines), 2 HIGH (full res)
	"fps": 60,             # 30 or 60
	"name": "",
	"relay_url": "",
	"face": 0,
	"screen_shake": true,
	"text_size": 1.0,
	"reduced_motion": false,
	# v0.2.5 accessibility / layout (UiManager reads these)
	"ui_scale": 1.0,           # everything on the glass
	"button_size": 1.0,        # touch targets
	"reduced_fx": false,       # fewer particles, flashes, glitches
	"reduced_gore": false,     # less to look at; the consequences still happen
	"left_handed": false,      # swap the stick and the buttons
	"match_turns": 15,
	"match_mode": "classic",
}


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in values.keys():
			values[k] = cf.get_value("s", k, values[k])
	if str(values.name) == "":
		values.name = ["GUEST", "MEAT", "PAL", "FRIEND", "BUDDY"][randi() % 5] + str(randi() % 90 + 10)
	apply()


func get_v(key: String, default: Variant = null) -> Variant:
	return values.get(key, default)


## (The campaign's name for get_v.)
func get_value(key: String, default: Variant = null) -> Variant:
	return values.get(key, default)


func set_v(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save()
	changed.emit()


func save() -> void:
	var cf := ConfigFile.new()
	for k in values.keys():
		cf.set_value("s", k, values[k])
	cf.save(PATH)


func relay_url() -> String:
	var u := str(values.relay_url)
	return u if u != "" else str(ProjectSettings.get_setting("meat_party/net/relay_url", "ws://127.0.0.1:9080"))


func screen_lines() -> int:
	return [240, 360, 0][clampi(int(values.quality), 0, 2)]


func apply() -> void:
	Engine.max_fps = int(values.fps) if int(values.quality) > 0 else mini(int(values.fps), 30)
	RenderingServer.global_shader_parameter_set("detail", 0.0 if int(values.quality) == 0 else 1.0)
	RenderingServer.global_shader_parameter_set("retro", 1.0 if int(values.quality) < 2 else 0.0)
	if get_node_or_null("/root/Audio"):
		get_node("/root/Audio").apply_volumes()
