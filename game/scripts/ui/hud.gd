class_name Hud
extends CanvasLayer
## What sits over the picture that isn't Socko: reading a paper, a quiet line when Kurt looks at
## something, a small dot to aim by, the fades, the menus (pause and settings, pockets, the two
## trees), and Continue. Socko is the HUD in the game's sense (see SockoHud); this is what must
## never depend on him: the controls, the text of things, the settings.

var main: Node
var fade: ColorRect
var dot: Control
var _focus := 0.0              ## 0 nothing, 1 something to do (the dot opens into a ring)
var _hit_t := 0.0              ## a hit marker, fading
var _hit_head := false
var _use_t := 0.0              ## the ring pulses when he does something
var look_line: Label
var reader: PanelContainer
var reader_text: RichTextLabel
var menu: Control
var notice: Label
var _look_t := 0.0
var _notice_t := 0.0
var _pages := {}

func setup(m: Node) -> void:
	main = m
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	dot = Control.new(); dot.set_anchors_preset(Control.PRESET_CENTER); dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(_draw_dot)
	add_child(dot)
	look_line = Label.new(); look_line.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	look_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; look_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	look_line.modulate = Color(1, 1, 1, 0); look_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(look_line)
	notice = Label.new(); notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; notice.modulate = Color(1, 1, 1, 0)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notice)
	_reader()
	Controls.pressed.connect(_on_pressed)
	World.event.connect(_on_event)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var fs := int(clampf(vp.y * 0.03, 14, 48) * float(Settings.get_v("subtitle_size")))
	look_line.add_theme_font_size_override("font_size", fs)
	look_line.size = Vector2(vp.x * 0.7, fs * 4)
	look_line.position = Vector2(vp.x * 0.15, vp.y * 0.72)
	notice.add_theme_font_size_override("font_size", fs)
	notice.size = Vector2(vp.x * 0.8, fs * 2); notice.position = Vector2(vp.x * 0.1, vp.y * 0.08)
	dot.position = vp * 0.5
	if reader:
		reader.size = Vector2(minf(vp.x * 0.62, vp.y * 1.1), vp.y * 0.78)
		reader.position = (vp - reader.size) * 0.5
		reader_text.add_theme_font_size_override("normal_font_size", int(fs * 1.05))

func _reader() -> void:
	reader = PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("e9e3cf"); sb.set_content_margin_all(28)
	sb.shadow_size = 12; sb.shadow_color = Color(0, 0, 0, 0.6)
	reader.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new(); reader.add_child(box)
	reader_text = RichTextLabel.new(); reader_text.bbcode_enabled = true
	reader_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader_text.add_theme_color_override("default_color", Color("23263a"))
	box.add_child(reader_text)
	var close := Button.new(); close.text = "Put it down"; close.custom_minimum_size.y = 56
	close.pressed.connect(close_reader)
	box.add_child(close)
	reader.visible = false
	add_child(reader)

func reading() -> bool:
	return reader.visible

func show_text(title: String, text: String) -> void:
	reader_text.text = "[b]%s[/b]\n\n%s" % [title, text]
	reader.visible = true
	Controls.enabled = false
	Controls.capture_mouse(false)

func close_reader() -> void:
	reader.visible = false
	Controls.enabled = true
	Controls.capture_mouse(true)
	World.emit_event("reader_closed", {})

func say_look(t: String) -> void:
	look_line.text = t
	_look_t = 3.0 + t.length() * 0.045

func flash(t: String, secs := 3.0) -> void:
	notice.text = t
	_notice_t = secs

func fade_to(a: float, secs: float) -> void:
	var tw := create_tween(); tw.tween_property(fade, "color:a", a, secs)
	await tw.finished

## The dot: opens into a ring when there's something to do (and pulses when he does it), a small
## cross while the gun's up, and a hit marker when a shot lands (bigger for the head).
func _draw_dot() -> void:
	var k = main.kurt if main else null
	var a := 0.6
	if k and k.gun_out:
		var g := 6.0 if k.aiming else 10.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			dot.draw_line(d * g * 0.45, d * g, Color(1, 1, 1, 0.7), 1.5)
	else:
		var r := lerpf(2.0, 7.0, _focus) + _use_t * 4.0
		if _focus < 0.35: dot.draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, a))
		else: dot.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1, 0.95, 0.85, a * _focus), 1.6, true)
	if _hit_t > 0.0:
		var s := (9.0 if _hit_head else 6.0) + (1.0 - _hit_t) * 4.0
		var c := Color(1, 0.35, 0.25, _hit_t) if _hit_head else Color(1, 1, 1, _hit_t)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			dot.draw_line(d.normalized() * s * 0.45, d.normalized() * s, c, 2.0)

func _process(delta: float) -> void:
	_look_t -= delta
	look_line.modulate.a = clampf(_look_t, 0.0, 1.0) * 0.85
	_notice_t -= delta
	notice.modulate.a = clampf(_notice_t, 0.0, 1.0)
	var k = main.kurt if main else null
	var want_focus := 1.0 if k != null and k.target_verbs.size() > 0 else 0.0
	_focus = move_toward(_focus, want_focus, delta * 7.0)
	_hit_t = maxf(_hit_t - delta * 3.0, 0.0)
	_use_t = maxf(_use_t - delta * 4.0, 0.0)
	dot.visible = k != null and not reader.visible and (_focus > 0.01 or k.gun_out or _hit_t > 0.0)
	if dot.visible: dot.queue_redraw()
	if k and k.target and String(Settings.get_v("prompts")) == "text" and k.target_verbs.size() > 0 and _look_t <= 0.0:
		look_line.text = String(k.target_verbs[0].label); look_line.modulate.a = 0.6

func _on_event(name: String, d: Dictionary) -> void:
	if name == "used": _use_t = 1.0
	if name == "hit_marker": _hit_t = 1.0; _hit_head = bool(d.get("head", false))
	match name:
		"read":
			var doc: Dictionary = main.level.flat.docs.get(d.doc, {})
			var text := String(doc.get("text", "(The writing has run. You can't read it.)"))
			if Progress.has("handwriting") and doc.has("hand"):
				text += "\n\n[i]" + String(doc.hand) + "[/i]"
			show_text(String(doc.get("title", d.title)), text)
			if doc.has("memory") and (not doc.has("memory_needs") or Progress.has(String(doc.memory_needs))):
				if Progress.remember(String(doc.memory)): flash("Something comes back.")
		"looked":
			var doc: Dictionary = main.level.flat.docs.get(d.key, {})
			var t := String(d.desc)
			if Progress.has("handwriting") and doc.has("hand"): t += " " + String(doc.hand)
			say_look(t)
			if doc.has("memory") and (not doc.has("memory_needs") or Progress.has(String(doc.memory_needs))):
				if Progress.remember(String(doc.memory)): flash("Something comes back.")
		"memory": flash("A memory.  (%d to spend)" % Progress.memories, 2.5)
		"shard": flash("Something gets in.  (%d)" % Progress.shards, 2.5)

func _on_pressed(a: String) -> void:
	match a:
		"pause": toggle_menu("pause")
		"bag": toggle_menu("pockets")
		"skills": toggle_menu("skills")
		"use":
			if reader.visible: close_reader()

# --------------------------------------------------------------------------------------- menus
func toggle_menu(which: String) -> void:
	if menu:
		menu.queue_free(); menu = null
		get_tree().paused = false
		Controls.capture_mouse(true)
		return
	if reader.visible: close_reader()
	get_tree().paused = true
	Controls.capture_mouse(false)
	menu = _panel()
	match which:
		"pause": _pause_menu()
		"pockets": _pockets_menu()
		"skills": _skills_menu()

func _panel() -> Control:
	var root := ColorRect.new(); root.color = Color(0, 0, 0, 0.72)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var sc := ScrollContainer.new(); sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp := get_viewport().get_visible_rect().size
	sc.offset_left = vp.x * 0.12; sc.offset_right = -vp.x * 0.12; sc.offset_top = vp.y * 0.06; sc.offset_bottom = -vp.y * 0.06
	root.add_child(sc)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", int(vp.y * 0.012))
	sc.add_child(box)
	root.set_meta("box", box)
	return root

func _box() -> VBoxContainer:
	return menu.get_meta("box")

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text
	var vp := get_viewport().get_visible_rect().size
	b.custom_minimum_size.y = maxf(vp.y * 0.075, 44)
	b.add_theme_font_size_override("font_size", int(clampf(vp.y * 0.03, 14, 40)))
	b.pressed.connect(cb)
	_box().add_child(b)
	return b

func _label(text: String, big := false) -> Label:
	var l := Label.new(); l.text = text; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vp := get_viewport().get_visible_rect().size
	l.add_theme_font_size_override("font_size", int(clampf(vp.y * (0.04 if big else 0.028), 14, 52)))
	_box().add_child(l)
	return l

func _pause_menu() -> void:
	_label("HYSTERIA", true)
	if Log.previous != "":
		_label("Last time, the game stopped here:\n" + Log.previous)
	_btn("Resume", func(): toggle_menu(""))
	_btn("Save", func(): flash("Saved." if World.save_game() else "Couldn't save.")); 
	var opts := [
		["Look sensitivity", "look_sensitivity", [0.5, 0.75, 1.0, 1.5, 2.0]],
		["Brightness", "brightness", [0.8, 1.0, 1.2, 1.4, 1.6]],
		["Subtitle size", "subtitle_size", [0.75, 1.0, 1.25, 1.5, 1.75]],
		["Subtitles", "subtitles", [true, false]],
		["Socko and the stick on the", "socko_side", ["left", "right"]],
		["Prompts", "prompts", ["socko", "text"]],
		["Buttons", "hud_opacity", [1.0, 0.6, 0.3]],
		["Invert look", "invert_y", [false, true]],
		["Screen shake", "screen_shake", [1.0, 0.5, 0.0]],
		["Picture", "quality", ["auto", "low", "high"]],
		["Volume", "master_volume", [1.0, 0.7, 0.4, 0.0]],
	]
	for o in opts:
		var b := _btn("", func(): pass)
		var upd := func(): b.text = "%s: %s" % [o[0], str(Settings.get_v(o[1]))]
		upd.call()
		b.pressed.connect(func():
			var vals: Array = o[2]
			var i := vals.find(Settings.get_v(o[1]))
			Settings.set_v(o[1], vals[(i + 1) % vals.size()])
			upd.call()
			_layout())
	_btn("Start again", func():
		toggle_menu("")
		World.wipe()
		get_tree().reload_current_scene())

func _pockets_menu() -> void:
	var k: Kurt = main.kurt
	_label("Pockets", true)
	if k.pockets.is_empty() and not k.has_item("revolver"):
		_label("Nothing.")
	for p in k.pockets:
		var id := String(p.id)
		if id in ["shells", "rounds"]: continue
		if id == "shotgun":
			_btn("Sawn-off (%d in it, %d shells) — %s" % [k.barrels, k.shells, "put it away" if k.gun_out and k.weapon == "shotgun" else "take it out"], func():
				if k.gun_out and k.weapon == "shotgun": k.holster()
				else: k.draw_gun("shotgun")
				toggle_menu(""))
			continue
		if id == "revolver":
			_btn("Revolver (%d loaded, %d loose) — %s" % [k.rounds, k.spare, "put it away" if k.gun_out else "take it out"], func():
				if k.gun_out and k.weapon == "revolver": k.holster()
				else: k.draw_gun("revolver")
				toggle_menu(""))
			continue
		_btn("%s — hold it" % p.title, func(): k.hold_from_pocket(id); toggle_menu(""))
	if k.has_item("revolver") or true:
		_label("\nMemories to spend: %d     Shards: %d" % [Progress.memories, Progress.shards])

func _skills_menu() -> void:
	_label("What you are", true)
	_label("Memories: %d        Shards: %d" % [Progress.memories, Progress.shards])
	for tree in ["memory", "gameplay"]:
		_label("\n" + ("MEMORY — what you were" if tree == "memory" else "THE INFECTION — what you could be"), true)
		for s in Progress.trees[tree]:
			var id := String(s.id)
			var owned := Progress.has(id)
			var b := _btn("%s%s  (%d)  %s" % ["✓ " if owned else "", s.name, int(s.cost), s.desc], func():
				if Progress.buy(id):
					toggle_menu(""); toggle_menu("skills"))
			b.disabled = owned or not Progress.can_buy(id)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT

func offer_continue(cont: Callable, fresh: Callable) -> void:
	get_tree().paused = true
	menu = _panel()
	_label("HYSTERIA", true)
	_btn("Continue", func(): menu.queue_free(); menu = null; get_tree().paused = false; cont.call())
	_btn("Begin again", func(): menu.queue_free(); menu = null; get_tree().paused = false; fresh.call())
