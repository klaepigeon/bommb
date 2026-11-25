class_name Hud
extends Control
## What the player sees over the world: the clock, what they're looking at and what they can do
## to it, notices, people's lines heard nearby, the reader for notes, the bag, the pause menu.

const WAIT_RATE := 30.0           ## minutes per second while waiting
const HEAR_RANGE := 16.0

var player: Player
var controls: Controls

var _clock: Label
var _prompt: Label
var _who: Label
var _notices: VBoxContainer
var _subs: VBoxContainer
var _reader: PanelContainer
var _reader_text: Label
var _bag: PanelContainer
var _bag_text: Label
var _pause: PanelContainer
var _pause_text: Label
var _waiting := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock = _label(Vector2(24, 18), 26, Color(1.0, 0.85, 0.55))
	_who = _label(Vector2.ZERO, 22, Color(0.9, 0.9, 1.0))
	_prompt = _label(Vector2.ZERO, 24, Color.WHITE)
	for l in [_who, _prompt]:
		l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_who.position = Vector2(-400, -150)
	_prompt.position = Vector2(-400, -116)
	_who.size.x = 800
	_prompt.size.x = 800
	_notices = VBoxContainer.new()
	_notices.position = Vector2(24, 60)
	add_child(_notices)
	_subs = VBoxContainer.new()
	_subs.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subs.position = Vector2(-420, -260)
	_subs.size = Vector2(840, 100)
	_subs.alignment = BoxContainer.ALIGNMENT_END
	add_child(_subs)
	_reader = _panel(Vector2(760, 460))
	_reader_text = _reader.get_child(0) as Label
	_bag = _panel(Vector2(640, 420))
	_bag_text = _bag.get_child(0) as Label
	_pause = _panel(Vector2(560, 360))
	_pause_text = _pause.get_child(0) as Label
	Events.notice.connect(_notice)
	Events.bark.connect(_bark)
	Events.read.connect(_read)

func bind(p: Player, c: Controls) -> void:
	player = p
	controls = c
	p.focus_changed.connect(_on_focus)
	p.inventory_changed.connect(_refresh_bag)
	c.use_pressed.connect(_on_use)
	c.button.connect(_on_button)

func _label(pos: Vector2, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _panel(sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.92)
	sb.border_color = Color(0.6, 0.45, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.size = sz
	p.position = -sz * 0.5
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	p.add_child(l)
	p.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_close_panels())
	add_child(p)
	return p

func _process(_delta: float) -> void:
	_clock.text = "%s  %s%s" % [Clock.START_DATE.split(" ")[0], Clock.text(), "   >> WAITING" if _waiting else ""]
	if player and player.focus and is_instance_valid(player.focus):
		var f := player.focus
		_who.text = f.label + (("  —  " + f.call("activity_text")) if f.has_method("activity_text") else "")
	else:
		_who.text = ""

func _on_focus(target: Interactable) -> void:
	var v: Array[String] = []
	if target and is_instance_valid(target):
		v = target.verbs(player)
	controls.verbs = v
	if v.is_empty():
		_prompt.text = ""
	else:
		_prompt.text = "[E] " + v[0] + (("    [Q] " + v[1]) if v.size() > 1 else "")

func _on_use(i: int) -> void:
	if _any_panel():
		_close_panels()
		return
	player.act(i)
	_on_focus.call_deferred(player.focus)

func _on_button(n: String) -> void:
	match n:
		"bag":
			Sfx.ui("ui")
			if _bag.visible:
				_close_panels()
			else:
				_refresh_bag()
				_close_panels()
				_bag.visible = true
		"wait":
			_waiting = not _waiting
			Clock.minutes_per_second = WAIT_RATE if _waiting else 1.0
			Events.notice.emit("Waiting... (WAIT again to stop)" if _waiting else "You stop waiting.")
		"pause":
			if _pause.visible:
				_close_panels()
			else:
				_show_pause()

func _show_pause() -> void:
	_close_panels()
	get_tree().paused = true
	_pause.visible = true
	_pause_text.text = "PAUSED\n\nThe goal for now: walk the block. Go into the bar, the diner, the shops. Watch who goes where, and when.\n\nRender: %d lines   (tap here to resume)\nDither: %s\nFolks on the block: %d\n\nCREDITS: %s" % [Settings.render_height, "on" if Settings.dither else "off", World.npcs.size(),
		", ".join(Assets.registry.packs.values().map(func(p): return "%s by %s (%s)" % [p.name, p.creator, p.license]))]

func _any_panel() -> bool:
	return _reader.visible or _bag.visible or _pause.visible

func _close_panels() -> void:
	_reader.visible = false
	_bag.visible = false
	_pause.visible = false
	get_tree().paused = false

func _refresh_bag() -> void:
	var lines := ["YOUR THINGS        cash: $%d" % player.cash, ""]
	for i in player.inventory:
		var owner: String = i.get("owner", "")
		lines.append("- " + i.name + ("" if owner in ["", "player"] else "   (not yours)"))
	_bag_text.text = "\n".join(lines)

func _read(title: String, text: String) -> void:
	_close_panels()
	_reader_text.text = title.to_upper() + "\n\n" + text
	_reader.visible = true

func _notice(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	_notices.add_child(l)
	var t := l.create_tween()
	t.tween_interval(4.0)
	t.tween_property(l, "modulate:a", 0.0, 1.0)
	t.tween_callback(l.queue_free)

func _bark(speaker: String, text: String, from: Node3D) -> void:
	if player and from and from.global_position.distance_to(player.global_position) > HEAR_RANGE:
		return
	var l := Label.new()
	l.text = "%s: %s" % [speaker, text]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	_subs.add_child(l)
	while _subs.get_child_count() > 3:
		_subs.get_child(0).free()
	var t := l.create_tween()
	t.tween_interval(4.5)
	t.tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)
