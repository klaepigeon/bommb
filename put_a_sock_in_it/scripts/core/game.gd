extends Node
## The game's state and its level changes (autoload "Game").
##
## Levels are separate scenes, not one seamless world. Between them: the outgoing level plays a
## cutscene that ends in black, the next level loads behind a loading card on that black, and the
## incoming level opens on its own cutscene from black. The player never sees a cut to a menu.
##
## State that crosses levels (flags, inventory, the pistol, memories) lives here and is saved at
## each level's start (a checkpoint), so dying in a level restarts that level as you entered it.

signal level_started(id: String)
## Something made a sound the infected can hear: where, and how loud (0 a breath .. 1 a gunshot).
signal noise(pos: Vector3, loudness: float)

const LEVELS := {
	"flat47": {"scene": "res://scenes/levels/flat47.tscn", "title": "Flat 47", "sub": "Kerzhansk, 1996"},
	"flesh47": {"scene": "res://scenes/levels/flesh47.tscn", "title": "Flat 47", "sub": "again"},
}
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"

var flags := {}
var memories := 0               # memory points invested (the memory tree is a later system)
var inventory := {}             # item id -> count
var pistol := {"have": false, "mag": 0}
var level_id := ""
var level: Node = null
var settings := {"sensitivity": 1.0, "invert_y": false, "touch_scale": 1.0, "touch_opacity": 0.55,
	"force_touch": false, "volume": 0.8, "post_fx": true, "shadows": true}
var busy := false               # a level change is under way

var _loading: CanvasLayer
var _black: ColorRect
var _card: VBoxContainer
var _title: Label
var _sub: Label
var _dots: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_loading()
	_setup_input()

func make_noise(pos: Vector3, loudness: float) -> void:
	noise.emit(pos, loudness)

## The one input map every platform shares. The touch overlay presses these same actions.
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "crouch": [KEY_C, KEY_CTRL], "interact": [KEY_E], "reload": [KEY_R],
		"skip": [KEY_SPACE], "pause": [KEY_ESCAPE, KEY_P], "inspect": [KEY_Q], "torch": [KEY_F], "fire": [], "look_left": [], "look_right": [], "look_up": [], "look_down": []}
	var pad := {"interact": JOY_BUTTON_A, "crouch": JOY_BUTTON_B, "reload": JOY_BUTTON_X, "skip": JOY_BUTTON_Y,
		"pause": JOY_BUTTON_START, "sprint": JOY_BUTTON_LEFT_STICK, "torch": JOY_BUTTON_RIGHT_SHOULDER}
	var axes := {"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0], "move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0], "look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0], "fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "inspect": [JOY_AXIS_TRIGGER_LEFT, 1.0]}
	for a in keys:
		if not InputMap.has_action(a): InputMap.add_action(a, 0.25)
		for k in keys[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k; InputMap.action_add_event(a, ev)
		if pad.has(a):
			var jb := InputEventJoypadButton.new(); jb.button_index = pad[a]; InputMap.action_add_event(a, jb)
		if axes.has(a):
			var ja := InputEventJoypadMotion.new(); ja.axis = axes[a][0]; ja.axis_value = axes[a][1]; InputMap.action_add_event(a, ja)
	var lmb := InputEventMouseButton.new(); lmb.button_index = MOUSE_BUTTON_LEFT; InputMap.action_add_event("fire", lmb)
	var rmb := InputEventMouseButton.new(); rmb.button_index = MOUSE_BUTTON_RIGHT; InputMap.action_add_event("inspect", rmb)

# ------------------------------------------------------------------ flags and inventory
func flag(k: String) -> bool:
	return flags.get(k, false)

func set_flag(k: String, v := true) -> void:
	flags[k] = v

func add_item(id: String, n := 1) -> void:
	inventory[id] = inventory.get(id, 0) + n

func take_item(id: String, n := 1) -> bool:
	if inventory.get(id, 0) < n:
		return false
	inventory[id] -= n
	if inventory[id] <= 0:
		inventory.erase(id)
	return true

func count(id: String) -> int:
	return inventory.get(id, 0)

func uses_touch() -> bool:
	return settings.force_touch or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

# ------------------------------------------------------------------ new game, continue, save
func new_game() -> void:
	flags = {}; memories = 0; inventory = {}; pistol = {"have": false, "mag": 0}
	change_level("flat47", {"fade": 1.5, "card": false})

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func continue_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		new_game(); return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not LEVELS.has(d.get("level", "")):
		new_game(); return
	_restore(d)
	change_level(d.level, {"checkpoint": true})

func _snapshot() -> Dictionary:
	return {"level": level_id, "flags": flags.duplicate(true), "memories": memories,
		"inventory": inventory.duplicate(true), "pistol": pistol.duplicate(true)}

func _restore(d: Dictionary) -> void:
	flags = d.get("flags", {}).duplicate(true)
	memories = int(d.get("memories", 0))
	inventory = {}
	for k in d.get("inventory", {}): inventory[k] = int(d.inventory[k])
	var p: Dictionary = d.get("pistol", {})
	pistol = {"have": bool(p.get("have", false)), "mag": int(p.get("mag", 0))}

var _checkpoint := {}
## Called by a level once its opening has played: what a restart returns to.
func checkpoint() -> void:
	_checkpoint = _snapshot()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_checkpoint))

## Kurt died: back to the level's checkpoint, through the loading card.
func restart_level() -> void:
	if not _checkpoint.is_empty():
		_restore(_checkpoint)
	change_level(level_id, {"checkpoint": true})

## The end of what's built: fade out, the next chapter's card, back to the title.
func end_chapter(title: String, sub: String) -> void:
	busy = true
	await _fade(1.0, 1.5)
	Dialogue.stop(); Sfx.stop_loops()
	_title.text = title; _sub.text = sub; _dots.text = ""
	_card.modulate.a = 0.0; _card.visible = true
	var tw := create_tween(); tw.tween_property(_card, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(4.0).timeout
	var tw2 := create_tween(); tw2.tween_property(_card, "modulate:a", 0.0, 1.0)
	await tw2.finished
	_card.visible = false
	busy = false
	await to_title()

func reset_save() -> void:
	if has_save(): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func to_title() -> void:
	get_tree().paused = false
	busy = true
	await _fade(1.0, 0.5)
	if level: level.queue_free(); level = null
	Dialogue.stop()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await get_tree().process_frame
	await _fade(0.0, 0.5)
	busy = false

# ------------------------------------------------------------------ level changes
## Go to a level. The screen is assumed to be on its way to black already if the outgoing level
## ended on a cutscene; otherwise it fades. opts: card (show the title card, default true),
## checkpoint (start from the level's checkpoint instead of its opening), fade (seconds).
func change_level(id: String, opts := {}) -> void:
	if busy: return
	busy = true
	get_tree().paused = false
	var info: Dictionary = LEVELS[id]
	await _fade(1.0, opts.get("fade", 0.6))
	Dialogue.stop()
	var show_card: bool = opts.get("card", true)
	if show_card:
		_title.text = info.title; _sub.text = info.sub
		var tw := create_tween(); _card.modulate.a = 0.0; _card.visible = true
		tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	var t0 := Time.get_ticks_msec()
	ResourceLoader.load_threaded_request(info.scene)
	while ResourceLoader.load_threaded_get_status(info.scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_tick_dots(); await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(info.scene)
	Sfx.stop_loops()
	if level: level.queue_free(); level = null
	if get_tree().current_scene and get_tree().current_scene.name != "Levels":
		get_tree().current_scene.queue_free()
	await get_tree().process_frame
	level_id = id
	level = packed.instantiate()
	level.set_meta("from_checkpoint", opts.get("checkpoint", false))
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	# levels build their geometry in _ready; give it a few frames to settle (and the card time
	# to be read) before the curtain lifts
	for i in 3: _tick_dots(); await get_tree().process_frame
	var min_ms := 2200 if show_card else 600
	while Time.get_ticks_msec() - t0 < min_ms:
		_tick_dots(); await get_tree().process_frame
	if show_card:
		var tw := create_tween(); tw.tween_property(_card, "modulate:a", 0.0, 0.5)
		await tw.finished
		_card.visible = false
	busy = false
	level_started.emit(id)
	if level.has_method("begin"):
		level.begin()
	else:
		await _fade(0.0, 1.0)

## Lift or drop the curtain (0 clear, 1 black). Levels use it for their own cutscene fades.
func fade(to: float, secs: float) -> void:
	await _fade(to, secs)

func _fade(to: float, secs: float) -> void:
	_black.visible = true
	var tw := create_tween()
	tw.tween_property(_black, "color:a", to, secs)
	await tw.finished
	if to <= 0.0: _black.visible = false

var _dot_t := 0
func _tick_dots() -> void:
	_dot_t += 1
	_dots.text = ".".repeat(1 + (_dot_t / 20) % 3)

func _build_loading() -> void:
	_loading = CanvasLayer.new(); _loading.layer = 90
	add_child(_loading)
	_black = ColorRect.new(); _black.color = Color(0, 0, 0, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.visible = false
	_loading.add_child(_black)
	_card = VBoxContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_loading.add_child(_card)
	_title = _label(46, Color("d8cdb4")); _sub = _label(20, Color("8a7f6c")); _dots = _label(20, Color("8a7f6c"))
	_card.add_child(_title); _card.add_child(_sub); _card.add_child(_dots)

func _label(size: int, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l

# ------------------------------------------------------------------ settings
func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(settings))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, settings.volume)))

func _load_settings() -> void:
	if OS.has_feature("mobile"): settings.shadows = false     # phones: on in Pause if the phone can take it
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			for k in d: if settings.has(k): settings[k] = d[k]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(settings.volume))))
