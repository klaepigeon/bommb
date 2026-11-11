extends Control
## Pause: resume, save, load, settings, arrange the controls. Settings cover everything the brief
## lists: camera sensitivity and inversion, stick and button size and position, interaction
## sensitivity, subtitles (on, size, background, names), audio volumes and voice, graphics preset,
## frame rate, the governor, the performance overlay, brightness and grain.

var hud: Node
var _pages := {}
var _tabs: HBoxContainer
var _body: ScrollContainer
var _note: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.fullscreen_dim(0.88))
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 26)
	add_child(m)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)
	_tabs = HBoxContainer.new(); _tabs.add_theme_constant_override("separation", 10)
	vb.add_child(_tabs)
	_note = UIKit.label("", 20, Color(0.9, 0.8, 0.6))
	vb.add_child(_note)
	_body = ScrollContainer.new(); _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_body)
	_page("Game", _game_page())
	_page("Controls", _controls_page())
	_page("Subtitles", _subs_page())
	_page("Sound", _audio_page())
	_page("Graphics", _gfx_page())
	_show("Game")

func open() -> void:
	visible = true
	_note.text = ""
	_show("Game")

func _page(name: String, content: Control) -> void:
	var b := UIKit.button("  %s  " % name, 24, 58)
	b.pressed.connect(func(): _show(name))
	_tabs.add_child(b)
	_pages[name] = content

func _show(name: String) -> void:
	for c in _body.get_children():
		_body.remove_child(c)
	_body.add_child(_pages[name])

func _col() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v

func _game_page() -> Control:
	var v := _col()
	var resume := UIKit.button("Resume"); resume.pressed.connect(func(): hud.close_all())
	var save := UIKit.button("Save"); save.pressed.connect(func():
		_note.text = "Saved." if SaveGame.save_game(hud.main, "manual") else "Couldn't save here.")
	var load := UIKit.button("Load last save"); load.pressed.connect(func():
		if SaveGame.exists():
			hud.close_all()
			SaveGame.load_game(hud.main)
		else:
			_note.text = "No save yet.")
	var arrange := UIKit.button("Arrange the on-screen controls"); arrange.pressed.connect(func(): hud.set_edit_layout(true))
	var quit := UIKit.button("Quit"); quit.pressed.connect(func(): get_tree().quit())
	for b in [resume, save, load, arrange, quit]:
		v.add_child(b)
	return v

func _row(text: String, ctl: Control) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 20)
	var l := UIKit.label(text, 22); l.custom_minimum_size = Vector2(380, 0)
	h.add_child(l); h.add_child(ctl)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

func _slider(key: String, a: float, b: float, step: float) -> HSlider:
	var s := UIKit.slider(a, b, step, float(Settings.get_v(key)))
	s.value_changed.connect(func(x): Settings.set_v(key, x))
	return s

func _check(key: String) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_v(key))
	c.custom_minimum_size = Vector2(80, 52)
	c.toggled.connect(func(x): Settings.set_v(key, x))
	return c

func _options(key: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 22)
	o.custom_minimum_size = Vector2(240, 56)
	for i in items.size():
		o.add_item(str(items[i]))
		if str(items[i]) == str(Settings.get_v(key)):
			o.select(i)
	o.item_selected.connect(func(i): Settings.set_v(key, items[i]))
	return o

func _controls_page() -> Control:
	var v := _col()
	v.add_child(_row("Look sensitivity", _slider("look_sensitivity", 0.2, 3.0, 0.05)))
	v.add_child(_row("Invert look up/down", _check("invert_y")))
	v.add_child(_row("Invert look left/right", _check("invert_x")))
	v.add_child(_row("Stick size", _slider("stick_scale", 0.6, 1.6, 0.05)))
	v.add_child(_row("Stick appears under your thumb", _check("stick_floating")))
	v.add_child(_row("Button size", _slider("button_scale", 0.7, 1.6, 0.05)))
	v.add_child(_row("Button opacity", _slider("hud_opacity", 0.2, 1.0, 0.05)))
	v.add_child(_row("Tap-to-use window (s)", _slider("interact_hold_time", 0.15, 0.8, 0.05)))
	var arrange := UIKit.button("Arrange the on-screen controls"); arrange.pressed.connect(func(): hud.set_edit_layout(true))
	v.add_child(arrange)
	return v

func _subs_page() -> Control:
	var v := _col()
	v.add_child(_row("Subtitles", _check("subtitles")))
	v.add_child(_row("Subtitle size", _slider("subtitle_size", 0.75, 1.75, 0.05)))
	v.add_child(_row("Subtitle background", _check("subtitle_background")))
	v.add_child(_row("Speaker names", _check("speaker_names")))
	return v

func _audio_page() -> Control:
	var v := _col()
	v.add_child(_row("Master", _slider("vol_master", 0.0, 1.0, 0.05)))
	v.add_child(_row("Effects", _slider("vol_sfx", 0.0, 1.0, 0.05)))
	v.add_child(_row("Music", _slider("vol_music", 0.0, 1.0, 0.05)))
	v.add_child(_row("Voices", _slider("vol_voice", 0.0, 1.0, 0.05)))
	v.add_child(_row("Spoken voices (device speech)", _check("tts_voice")))
	return v

func _gfx_page() -> Control:
	var v := _col()
	v.add_child(_row("Quality", _options("preset", ["auto", "low", "medium", "high"])))
	v.add_child(_row("Frame rate", _options("fps_target", [30, 60])))
	v.add_child(_row("Step down when the phone gets hot", _check("governor")))
	v.add_child(_row("Brightness", _slider("brightness", 0.6, 1.6, 0.05)))
	v.add_child(_row("Film grain", _slider("grain", 0.0, 1.5, 0.05)))
	v.add_child(_row("Performance overlay", _check("show_perf")))
	return v
