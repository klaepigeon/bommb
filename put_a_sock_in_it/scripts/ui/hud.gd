class_name Hud
extends CanvasLayer
## What's on screen in play, kept small: a dot to aim with, what you can do with what you're
## looking at, the current objective (top left, fading after a while), and the pistol's rounds
## when he has it. No health bar, no minimap.

var player: Player
var _prompt: Label
var _objective: Label
var _ammo: Label
var _dot: ColorRect
var _obj_t := 0.0
var _strain: ProgressBar
var _breath: ProgressBar
var _batt: ProgressBar

func _ready() -> void:
	layer = 20
	_dot = ColorRect.new(); _dot.color = Color(1, 1, 1, 0.5); _dot.size = Vector2(4, 4)
	_dot.set_anchors_preset(Control.PRESET_CENTER); _dot.position -= Vector2(2, 2)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dot)
	_prompt = _label(22, Color("e8e0cc"))
	_prompt.anchor_left = 0.5; _prompt.anchor_right = 0.5; _prompt.anchor_top = 0.5; _prompt.anchor_bottom = 0.5
	_prompt.offset_left = -300; _prompt.offset_right = 300; _prompt.offset_top = 40; _prompt.offset_bottom = 80
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_objective = _label(20, Color("cfc6ae"))
	_objective.position = Vector2(28, 22); _objective.size = Vector2(600, 40)
	add_child(_objective)
	_ammo = _label(26, Color("e8e0cc"))
	_ammo.anchor_left = 1; _ammo.anchor_right = 1; _ammo.anchor_top = 1; _ammo.anchor_bottom = 1
	_ammo.offset_left = -220; _ammo.offset_right = -30; _ammo.offset_top = -64; _ammo.offset_bottom = -24
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_ammo)

func _bar(at: Vector2, c: Color) -> ProgressBar:
	var b := ProgressBar.new(); b.show_percentage = false; b.max_value = 1.0
	b.custom_minimum_size = Vector2(160, 6); b.position = at; b.size = Vector2(160, 6)
	b.modulate = c; b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b

func _label(size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2); l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A quiet one-off hint about a control (shown once, fades).
var _hints: Array = []
func hint(t: String, secs := 6.0) -> void:
	_hints = _hints.filter(func(x): return is_instance_valid(x))
	var l := _label(18, Color("a89f8a")); l.text = t
	l.anchor_left = 0.5; l.anchor_right = 0.5; l.anchor_top = 1.0; l.anchor_bottom = 1.0
	var up := 32.0 * _hints.size()          # (stacked above any still showing)
	l.offset_left = -300; l.offset_right = 300; l.offset_top = -200 - up; l.offset_bottom = -170 - up
	_hints.append(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween(); tw.tween_interval(secs); tw.tween_property(l, "modulate:a", 0.0, 1.5); tw.tween_callback(l.queue_free)

## Observant: a mark at the edge of the screen, toward where she made a sound.
func ping(world_pos: Vector3) -> void:
	if not player: return
	var cam := player.cam
	var local := cam.global_transform.affine_inverse() * world_pos
	var dir := Vector2(local.x, -local.y if local.z < 0.0 else local.y).normalized()
	if local.z > 0.0 and absf(local.x) < 0.01: dir = Vector2(0, 1)
	var vp := get_viewport().get_visible_rect().size
	var c := vp * 0.5
	var r := minf(vp.x, vp.y) * 0.42
	var mark := Label.new(); mark.text = "◆"
	mark.add_theme_font_size_override("font_size", 26); mark.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 0.9))
	mark.position = c + dir * r - Vector2(10, 16); mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)
	var tw := create_tween(); tw.tween_property(mark, "modulate:a", 0.0, 1.4); tw.tween_callback(mark.queue_free)

func set_objective(t: String) -> void:
	_objective.text = t
	_obj_t = 9.0
	_objective.modulate.a = 1.0

func _process(delta: float) -> void:
	if not player: return
	var p := player.prompt() if player.controls or player.hidden_in else ""
	_prompt.text = p
	var touch := Game.uses_touch()
	if p != "" and not touch: _prompt.text = "[E]  " + p
	_dot.visible = player.controls
	if not _strain:
		_strain = ProgressBar.new(); _strain.show_percentage = false; _strain.max_value = 1.0
		_strain.custom_minimum_size = Vector2(160, 8); _strain.position = Vector2(28, 64); _strain.size = Vector2(160, 8)
		_strain.modulate = Color(0.6, 0.85, 1.0, 0.8); _strain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_strain)
	_strain.value = Game.strain
	_strain.visible = Game.strain > 0.01
	# his held breath (white, while it's held or coming back), and the torch's battery (amber,
	# while it's on, and red under a quarter)
	if not _breath:
		_breath = _bar(Vector2(28, 76), Color(0.95, 0.95, 0.95, 0.8))
		_batt = _bar(Vector2(28, 88), Color(1.0, 0.75, 0.35, 0.7))
	var nv = player.get_parent().get("nerve")
	if nv:
		_breath.value = nv.air
		_breath.visible = nv.holding or nv.air < 0.99
		_breath.modulate = Color(1.0, 0.45, 0.4, 0.9) if nv.air < 0.3 else Color(0.95, 0.95, 0.95, 0.8)
	_batt.value = Game.torch_charge
	_batt.visible = player.torch_on or Game.torch_charge < 0.25
	_batt.modulate = Color(1.0, 0.35, 0.25, 0.8) if Game.torch_charge < 0.25 else Color(1.0, 0.75, 0.35, 0.7)
	_obj_t -= delta
	_objective.modulate.a = clampf(_obj_t, 0.25, 1.0)
	if player.held:
		var d := Weapons.durability(player.held)
		var cls: String = Weapons.profile(player.held)["class"]
		if d >= 0:
			var full: int = int(Weapons.CLASSES[cls].dur)
			var pips := mini(full, 10)
			var lit := int(ceil(float(d) / float(full) * pips))
			_ammo.text = "▮".repeat(lit) + "▯".repeat(pips - lit)
		else:
			_ammo.text = ""
	elif Game.gun_out() == "pistol":
		_ammo.text = "%d  |  %d" % [Game.pistol.mag, Game.count("ammo")]
	elif Game.gun_out() == "shotgun":
		_ammo.text = "%s  |  %d" % ["●".repeat(int(Game.shotgun.loaded)) + "○".repeat(2 - int(Game.shotgun.loaded)), Game.count("shells")]
	else:
		_ammo.text = ""
