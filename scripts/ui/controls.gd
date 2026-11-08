class_name PartyControls
extends RefCounted
## The touch controls a minigame (or the facility, or ORGAN TRAIL) asks for, each built
## for its mechanic: HOLD (press and hold; sends on and off), SWIPE (a flick in a
## direction), TIMING (a ring that closes on the beat: tap when it meets the line), TRACE
## (draw a line with your finger), PICK (one button per option), TAP. Every one also
## answers to the keyboard and a pad, so a desktop player isn't stuck.

## Build the widget for one control spec; `send` gets the action dict (without "t").
static func make(spec: Dictionary, send: Callable, key_hint := "") -> Control:
	match str(spec.kind):
		"hold":
			return HoldButton.new().setup(spec, send, key_hint)
		"swipe":
			return SwipePad.new().setup(spec, send)
		"timing":
			return TimingRing.new().setup(spec, send, key_hint)
		"trace":
			return TracePad.new().setup(spec, send)
		"pick":
			var box: VBoxContainer = PartyUi.vbox(4)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(PartyUi.label(str(spec.get("label", "")), 16, PartyUi.CREAM, true, true))
			var fl := PartyUi.flow(6)
			fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for o in spec.get("options", []):
				var opt := str(o)
				var sel := str(spec.get("selected", "")) == opt
				var b := PartyUi.button(opt.replace("_", " ").to_upper(), func(): send.call({"do": spec.do, "pick": opt}), PartyUi.YELLOW if sel else PartyUi.CREAM, 92.0, 18)
				fl.add_child(b)
			box.add_child(fl)
			return box
		_:
			return PartyUi.button(str(spec.get("label", spec.get("do", "GO"))) + key_hint, func(): send.call({"do": spec.do}), PartyUi.PINK, 180.0, 24)


class HoldButton:
	extends Button
	var spec: Dictionary
	var send: Callable
	var held := false

	func setup(s: Dictionary, cb: Callable, key_hint: String) -> HoldButton:
		spec = s
		send = cb
		text = str(s.get("label", "HOLD")) + key_hint
		add_theme_font_override("font", PartyUi.title_font())
		add_theme_font_size_override("font_size", int(24 * PartyUi.k()))
		add_theme_stylebox_override("normal", PartyUi.box(PartyUi.TURQ))
		add_theme_stylebox_override("hover", PartyUi.box(PartyUi.TURQ.lightened(0.2)))
		add_theme_stylebox_override("pressed", PartyUi.box(PartyUi.MINT, PartyUi.INK, 18, 4, 1))
		add_theme_color_override("font_color", PartyUi.INK)
		custom_minimum_size = Vector2(200, 96) * PartyUi.bk()
		focus_mode = Control.FOCUS_NONE
		button_down.connect(func(): set_held(true))
		button_up.connect(func(): set_held(false))
		return self

	func set_held(on: bool) -> void:
		if on == held:
			return
		held = on
		send.call({"do": spec.do, "on": on})


class SwipePad:
	extends Panel
	var spec: Dictionary
	var send: Callable
	var _start := Vector2.ZERO
	var _down := false
	var _arrow := Vector2.ZERO
	var _arrow_t := 0.0

	func setup(s: Dictionary, cb: Callable) -> SwipePad:
		spec = s
		send = cb
		custom_minimum_size = Vector2(300, 220) * PartyUi.bk()
		add_theme_stylebox_override("panel", PartyUi.box(Color(0.1, 0.05, 0.1, 0.55), PartyUi.TURQ, 26, 4, 0))
		mouse_filter = Control.MOUSE_FILTER_STOP
		var l := PartyUi.label(str(s.get("label", "SWIPE")), 18, PartyUi.CREAM, true, true)
		l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.offset_top = -40
		l.offset_left = -140
		l.offset_right = 140
		add_child(l)
		return self

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch or (e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION and e.button_index == MOUSE_BUTTON_LEFT):
			if e.pressed:
				_down = true
				_start = e.position
			elif _down:
				_down = false
				var d: Vector2 = e.position - _start
				if d.length() < 18.0:
					# a tap: hop toward where you tapped, from the middle
					d = e.position - size / 2.0
				fire(d)
		elif (e is InputEventScreenDrag or (e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION)) and _down:
			var d2: Vector2 = e.position - _start
			if d2.length() > 70.0:
				fire(d2)
				_start = e.position

	func fire(d: Vector2) -> void:
		var v := Vector2(signf(d.x), 0) if absf(d.x) >= absf(d.y) else Vector2(0, signf(d.y))
		_arrow = v
		_arrow_t = 0.25
		queue_redraw()
		send.call({"do": spec.do, "dir": [v.x, v.y]})

	func _process(delta: float) -> void:
		if _arrow_t > 0.0:
			_arrow_t -= delta
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		for v in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var hot: bool = _arrow_t > 0.0 and v == _arrow
			var tip: Vector2 = c + v * minf(size.x, size.y) * 0.36
			var side := Vector2(-v.y, v.x) * 16.0
			draw_colored_polygon(PackedVector2Array([tip, tip - v * 30.0 + side, tip - v * 30.0 - side]), PartyUi.YELLOW if hot else Color(1, 1, 1, 0.35))


class TimingRing:
	extends Control
	var spec: Dictionary
	var send: Callable
	var period := 0.8
	var window := 0.15
	var t := 0.0
	var _flash := 0.0
	var _good := false
	var options: Array = []
	var choice := ""

	func setup(s: Dictionary, cb: Callable, key_hint: String) -> TimingRing:
		spec = s
		send = cb
		period = float(s.get("period", 0.8))
		window = float(s.get("window", 0.15))
		options = s.get("options", [])
		if not options.is_empty():
			choice = str(options[0])
		custom_minimum_size = Vector2(230, 230) * PartyUi.bk()
		mouse_filter = Control.MOUSE_FILTER_STOP
		var l := PartyUi.label(str(s.get("label", "TAP")) + key_hint, 22, PartyUi.CREAM, true, true)
		l.set_anchors_preset(Control.PRESET_CENTER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.offset_left = -100
		l.offset_right = 100
		l.offset_top = -18
		add_child(l)
		if not options.is_empty():
			var h := PartyUi.hbox(4)
			h.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			h.offset_top = 6
			h.offset_left = -110
			h.offset_right = 110
			h.offset_bottom = 70
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for o in options:
				var opt := str(o)
				h.add_child(PartyUi.button(opt, func(): choice = opt, PartyUi.CREAM, 90.0, 16))
			add_child(h)
		return self

	## The game's clock, so the ring closes on its beat.
	func sync(game_t: float) -> void:
		t = game_t

	func _process(delta: float) -> void:
		t += delta
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or (e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION and e.button_index == MOUSE_BUTTON_LEFT)) and e.pressed:
			tap()

	func tap() -> void:
		var ph := fmod(t, period) / period
		_good = ph < window / period or ph > 1.0 - window / period
		_flash = 0.3
		var a := {"do": spec.do}
		if choice != "":
			a.pick = choice
		send.call(a)

	func _draw() -> void:
		var c := size / 2.0
		var r0 := minf(size.x, size.y) * 0.24
		var ph := fmod(t, period) / period
		draw_circle(c, r0 * 1.9, Color(0.1, 0.05, 0.1, 0.55))
		draw_arc(c, r0, 0, TAU, 48, PartyUi.YELLOW, 8.0)
		var rr := r0 * (1.0 + (1.0 - ph) * 0.9)
		draw_arc(c, rr, 0, TAU, 48, PartyUi.PINK if ph < 0.85 else PartyUi.MINT, 6.0)
		if _flash > 0.0:
			draw_arc(c, r0 * 1.3, 0, TAU, 48, PartyUi.MINT if _good else PartyUi.RED, 10.0 * _flash / 0.3)


class TracePad:
	extends Panel
	var spec: Dictionary
	var send: Callable
	var pts: Array = []
	var guide: Array = []          # the line to follow (0..1)
	var protected: Array = []
	var _down := false

	func setup(s: Dictionary, cb: Callable) -> TracePad:
		spec = s
		send = cb
		custom_minimum_size = Vector2(420, 300) * PartyUi.bk()
		add_theme_stylebox_override("panel", PartyUi.box(Color("4a0f18"), PartyUi.SILVER, 18, 5, 0))
		mouse_filter = Control.MOUSE_FILTER_STOP
		return self

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch or (e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION and e.button_index == MOUSE_BUTTON_LEFT):
			if e.pressed:
				_down = true
				pts = [e.position]
			elif _down:
				_down = false
				var norm := []
				for p in pts:
					norm.append([(p as Vector2).x / size.x, (p as Vector2).y / size.y])
				send.call({"do": spec.do, "pts": norm})
			queue_redraw()
		elif (e is InputEventScreenDrag or (e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION)) and _down:
			if pts.is_empty() or (pts[-1] as Vector2).distance_to(e.position) > 6.0:
				pts.append(e.position)
				queue_redraw()

	func _draw() -> void:
		# the open patient, from above: the field
		draw_rect(Rect2(Vector2.ZERO, size).grow(-8), Color("7a1f2a"))
		for k in range(guide.size() - 1):
			var a := Vector2(guide[k][0], guide[k][1]) * size
			var b := Vector2(guide[k + 1][0], guide[k + 1][1]) * size
			draw_dashed_line(a, b, Color(1, 1, 1, 0.8), 4.0, 14.0)
		for pr in protected:
			draw_circle(Vector2(pr[0], pr[1]) * size, float(pr[2]) * size.x, Color(1, 0.9, 0.2, 0.35))
		if pts.size() > 1:
			draw_polyline(PackedVector2Array(pts), PartyUi.MINT, 5.0, true)
