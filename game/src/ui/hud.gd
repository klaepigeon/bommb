extends CanvasLayer
## The HUD and every input path into the player.
##
## Touch (Android first): a floating stick anywhere on the left, look by dragging anywhere on the
## right, a tap on the view uses what's under the crosshair. Buttons are few and contextual: the
## big Use button (its label is what it will do), secondary actions as chips beside it only when
## there are any, Crouch, Run (or push the stick to its edge), Torch only once there's a light,
## the revolver's Aim / Fire / Reload only while it's out. Every button can be moved and resized.
## Touches are routed here by finger index (not through GUI focus), so any number of fingers work.
##
## Keyboard/mouse and gamepad drive the same intents. Menus are ordinary controls.

const READER := preload("res://src/ui/reader.gd")
const INVENTORY := preload("res://src/ui/inventory_ui.gd")
const PAUSE := preload("res://src/ui/pause_menu.gd")

## id -> default centre (fraction of the safe screen), base size (px at 720p), label
const BUTTONS := {
	"use":    [Vector2(0.86, 0.70), 132.0, "Use"],
	"crouch": [Vector2(0.955, 0.90), 78.0, "Crouch"],
	"run":    [Vector2(0.06, 0.50), 74.0, "Run"],
	"torch":  [Vector2(0.955, 0.50), 66.0, "Light"],
	"inv":    [Vector2(0.93, 0.08), 66.0, "Bag"],
	"pause":  [Vector2(0.045, 0.08), 58.0, "II"],
	"fire":   [Vector2(0.72, 0.52), 100.0, "Fire"],
	"aim":    [Vector2(0.72, 0.80), 84.0, "Aim"],
	"reload": [Vector2(0.955, 0.31), 66.0, "Load"],
	"gun":    [Vector2(0.84, 0.08), 66.0, "Gun"],
}

var player: Player
var main: Node
var root: Control
var touch_mode := false
var edit_layout := false

var _buttons := {}                # id -> {node: Panel, label: Label, center: Vector2 px, size: float, shown: bool}
var _owner := {}                  # finger index -> "stick" | "look" | "btn:<id>" | "chip:<n>" | "edit:<id>"
var _look_last := {}              # finger -> last position
var _tap := {}                    # finger -> [start time, start pos, moved]
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _stick_base: Panel
var _stick_knob: Panel
var _chips: Array = []            # [Panel]
var _chip_box: VBoxContainer
var _crosshair: Panel
var _prompt: Label
var _keys_hint: Label
var _progress: ProgressBar
var _progress_label: Label
var _sub_panel: PanelContainer
var _sub_label: RichTextLabel
var _toast: Label
var _toast_t := 0.0
var _ammo: Label
var _hurt: Label
var _sub_hide_t := -1.0
var _run_toggle := false
var _crouch_toggle := false
var _mouse_captured := false
var reader: Control
var inventory: Control
var pause: Control
var _edit_bar: HBoxContainer

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	touch_mode = DisplayServer.is_touchscreen_available() or Settings.is_mobile()
	Speech.subtitle.connect(_on_subtitle)
	Speech.subtitle_clear.connect(func(): _sub_hide_t = 0.35)
	Events.toast.connect(_on_toast)
	Events.show_document.connect(func(id): open_reader(id))
	Events.open_inventory.connect(open_inventory)
	Settings.changed.connect(func(_k): _layout_buttons())
	get_viewport().size_changed.connect(_layout_buttons)
	_layout_buttons()

func bind(p: Player, m: Node) -> void:
	if player and player.verbs_changed.is_connected(_on_verbs):
		player.verbs_changed.disconnect(_on_verbs)
		player.hold_progress.disconnect(_on_hold)
	player = p
	main = m
	player.verbs_changed.connect(_on_verbs)
	player.hold_progress.connect(_on_hold)
	_on_verbs(null, [])

# ---------------------------------------------------------------------------------- building

func _build() -> void:
	var u := UIKit.unit(root)
	_crosshair = Panel.new()
	_crosshair.add_theme_stylebox_override("panel", UIKit.circle_style(Color(1, 1, 1, 0.5), Color(0, 0, 0, 0.6)))
	_crosshair.size = Vector2(6, 6)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	_prompt = UIKit.label("", 20, Color(0.95, 0.92, 0.82, 0.9))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)
	_keys_hint = UIKit.label("", 18, Color(0.9, 0.88, 0.8, 0.85))
	root.add_child(_keys_hint)
	_progress = ProgressBar.new(); _progress.show_percentage = false; _progress.max_value = 1.0
	_progress.custom_minimum_size = Vector2(220, 10); _progress.visible = false
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(0.9, 0.75, 0.5); fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.6); bg.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("fill", fill); _progress.add_theme_stylebox_override("background", bg)
	root.add_child(_progress)
	_progress_label = UIKit.label("", 18)
	_progress_label.visible = false
	root.add_child(_progress_label)
	# subtitles
	_sub_panel = PanelContainer.new()
	_sub_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0, 0, 0, 0.6), 8, Color(0, 0, 0, 0)))
	_sub_panel.visible = false
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_label = RichTextLabel.new()
	_sub_label.bbcode_enabled = true
	_sub_label.fit_content = true
	_sub_label.scroll_active = false
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_panel.add_child(_sub_label)
	root.add_child(_sub_panel)
	_toast = UIKit.label("", 22, Color(0.95, 0.9, 0.75))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	_ammo = UIKit.label("", 22, Color(0.9, 0.85, 0.7))
	root.add_child(_ammo)
	# stick
	_stick_base = Panel.new(); _stick_base.add_theme_stylebox_override("panel", UIKit.circle_style(Color(1, 1, 1, 0.07)))
	_stick_knob = Panel.new(); _stick_knob.add_theme_stylebox_override("panel", UIKit.circle_style(Color(1, 1, 1, 0.22)))
	for n in [_stick_base, _stick_knob]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.visible = false
		root.add_child(n)
	# buttons
	for id in BUTTONS:
		var b := Panel.new()
		b.name = "Btn_" + id
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_stylebox_override("panel", UIKit.circle_style(Color(0.05, 0.05, 0.05, 0.55), Color(1, 1, 1, 0.3)))
		var l := UIKit.label(String(BUTTONS[id][2]), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		root.add_child(b)
		_buttons[id] = {"node": b, "label": l, "center": Vector2.ZERO, "size": float(BUTTONS[id][1]), "shown": false}
	_chip_box = VBoxContainer.new()
	_chip_box.add_theme_constant_override("separation", int(8 * u))
	_chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_chip_box)
	# overlays
	reader = READER.new(); reader.hud = self; root.add_child(reader); reader.visible = false
	inventory = INVENTORY.new(); inventory.hud = self; root.add_child(inventory); inventory.visible = false
	pause = PAUSE.new(); pause.hud = self; root.add_child(pause); pause.visible = false
	_edit_bar = HBoxContainer.new()
	_edit_bar.visible = false
	var done := UIKit.button("Done"); done.pressed.connect(func(): set_edit_layout(false))
	var reset := UIKit.button("Reset layout"); reset.pressed.connect(func(): Settings.reset_layout())
	var bigger := UIKit.button(" + "); bigger.pressed.connect(func(): Settings.set_v("button_scale", minf(1.6, float(Settings.get_v("button_scale")) + 0.1)))
	var smaller := UIKit.button(" - "); smaller.pressed.connect(func(): Settings.set_v("button_scale", maxf(0.7, float(Settings.get_v("button_scale")) - 0.1)))
	for b in [smaller, bigger, reset, done]:
		_edit_bar.add_child(b)
	root.add_child(_edit_bar)

func _safe_rect() -> Rect2:
	var vp := root.get_viewport_rect()
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or scr.x <= 0 or not Settings.is_mobile():
		return vp.grow(-8)
	var k := vp.size / Vector2(scr)
	return Rect2(Vector2(safe.position) * k, Vector2(safe.size) * k).grow(-8)

func _layout_buttons() -> void:
	if not root.is_inside_tree():
		return
	var u := UIKit.unit(root)
	var safe := _safe_rect()
	var custom: Dictionary = Settings.get_v("layout")
	var bs := float(Settings.get_v("button_scale"))
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var n: Vector2 = BUTTONS[id][0]
		if custom.has(id):
			var c = custom[id]
			n = Vector2(float(c[0]), float(c[1])) if c is Array else n
		var sz := float(BUTTONS[id][1]) * u * bs
		b.size = sz
		b.center = safe.position + safe.size * n
		var node: Panel = b.node
		node.size = Vector2(sz, sz)
		node.position = b.center - node.size * 0.5
		(b.label as Label).add_theme_font_size_override("font_size", int(clampf(sz * 0.2, 14, 30)))
	var vp := root.get_viewport_rect().size
	for o in [reader, inventory, pause]:
		if o and o.visible: o.fit()
	_crosshair.position = vp * 0.5 - _crosshair.size * 0.5
	_edit_bar.position = Vector2(vp.x * 0.5 - 300 * u, vp.y * 0.42)

# ---------------------------------------------------------------------------------- state → UI

func _on_verbs(_focus: Object, verbs: Array) -> void:
	var b: Dictionary = _buttons["use"]
	if verbs.is_empty():
		(b.label as Label).text = "Use"
	else:
		(b.label as Label).text = String(verbs[0].label)
	for c in _chips:
		c.queue_free()
	_chips.clear()
	if touch_mode:
		for i in range(1, verbs.size()):
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.05, 0.05, 0.05, 0.7), 22))
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l := UIKit.label(String(verbs[i].label), 20)
			chip.add_child(l)
			chip.set_meta("verb", i)
			_chip_box.add_child(chip)
			_chips.append(chip)
	# desktop: the keys
	var lines := []
	for i in verbs.size():
		var key := "E" if i == 0 else str(i + 1)
		lines.append("[%s] %s" % [key, verbs[i].label])
	_keys_hint.text = "" if touch_mode else "\n".join(lines)
	var name := ""
	if _focus and _focus is Interactable:
		name = (_focus as Interactable).display_name
	_prompt.text = name

func _on_hold(k: float, label: String) -> void:
	_progress.visible = k >= 0.0
	_progress_label.visible = k >= 0.0
	_progress.value = maxf(k, 0.0)
	_progress_label.text = label

func _on_subtitle(_sp: String, display: String, color: Color, text: String, style: String) -> void:
	if not Settings.get_v("subtitles"):
		return
	var size := int(26 * float(Settings.get_v("subtitle_size")) * (0.85 if style == "quiet" else 1.0))
	_sub_label.add_theme_font_size_override("normal_font_size", size)
	_sub_label.add_theme_font_size_override("italics_font_size", size)
	var name_part := "[color=#%s]%s:[/color] " % [color.to_html(false), display] if Settings.get_v("speaker_names") else ""
	var body := "[i]%s[/i]" % text if style == "quiet" else text
	_sub_label.text = name_part + body
	_sub_label.modulate.a = 0.75 if style == "quiet" else 1.0
	(_sub_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a = 0.6 if Settings.get_v("subtitle_background") else 0.0
	_sub_panel.visible = true
	_sub_hide_t = -1.0

func _on_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = 2.6

# ---------------------------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	var vp := root.get_viewport_rect().size
	var u := UIKit.unit(root)
	var op := float(Settings.get_v("hud_opacity"))
	var in_menu := menu_open()
	var playing := player != null and not in_menu
	# which buttons exist right now
	var gun_out: bool = playing and player.gun != null and player.gun.equipped
	var show := {
		"use": playing and touch_mode, "crouch": playing and touch_mode, "run": playing and touch_mode and player.mode == "normal",
		"torch": playing and touch_mode and (player.inv.has("torch") or player.inv.has("lighter")),
		"inv": playing and touch_mode, "pause": touch_mode and not in_menu,
		"fire": gun_out and touch_mode, "aim": gun_out and touch_mode, "reload": gun_out and touch_mode,
		"gun": playing and touch_mode and player.gun != null,
	}
	if edit_layout:
		for k in show: show[k] = true
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		b.shown = show.get(id, false)
		var n: Panel = b.node
		n.visible = b.shown
		var pressed := _owner.values().has("btn:" + id)
		var lit: bool = (id == "crouch" and player != null and player.crouching) or (id == "run" and _run_toggle) or (id == "torch" and player != null and player.torch_on) or (id == "aim" and gun_out and player.gun.aiming)
		n.modulate = Color(1, 1, 1, op * (1.6 if pressed or lit else 1.0))
		if id == "use" and player and player.verbs.is_empty():
			n.modulate.a = op * 0.45
		if id == "gun" and player and player.gun:
			(b.label as Label).text = "Put away" if player.gun.equipped else "Gun"
	# chips beside the Use button
	var ub: Dictionary = _buttons["use"]
	_chip_box.visible = playing and touch_mode and not _chips.is_empty()
	_chip_box.position = Vector2(ub.center.x - ub.size * 0.5 - _chip_box.size.x - 14 * u, ub.center.y - _chip_box.size.y + ub.size * 0.3)
	# crosshair, prompt
	_crosshair.visible = playing and player.mode != "hidden"
	_crosshair.position = vp * 0.5 - _crosshair.size * 0.5
	_prompt.visible = playing
	_prompt.position = Vector2(vp.x * 0.5 - _prompt.size.x * 0.5, vp.y * 0.5 + 18 * u)
	_keys_hint.visible = playing and not touch_mode
	_keys_hint.position = Vector2(vp.x * 0.5 + 30 * u, vp.y * 0.5 + 10 * u)
	_progress.position = Vector2(vp.x * 0.5 - 110, vp.y * 0.5 + 54 * u)
	_progress_label.position = _progress.position + Vector2(0, 14)
	# subtitles: bottom centre, clear of the thumbs
	var sw := minf(vp.x * 0.62, 900.0 * u)
	_sub_panel.custom_minimum_size = Vector2(sw, 0)
	_sub_label.custom_minimum_size = Vector2(sw - 28, 0)
	_sub_panel.position = Vector2(vp.x * 0.5 - sw * 0.5, vp.y - _sub_panel.size.y - 22 * u)
	if _sub_hide_t >= 0.0:
		_sub_hide_t -= delta
		if _sub_hide_t < 0.0:
			_sub_panel.visible = false
	_toast.position = Vector2(vp.x * 0.5 - _toast.size.x * 0.5, 70 * u)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	# ammo
	if player and player.gun and player.gun.equipped:
		_ammo.visible = true
		_ammo.text = "%d / %d" % [player.gun.loaded, player.inv.count("ammo")]
		_ammo.position = Vector2(vp.x - _ammo.size.x - 30 * u, vp.y * 0.18 if touch_mode else vp.y - 50 * u)
	else:
		_ammo.visible = false
	_edit_bar.visible = edit_layout
	if playing:
		_poll_keyboard_gamepad()
		player.running = _run_toggle or (touch_mode and _stick_vec.length() > 0.96)

func menu_open() -> bool:
	return reader.visible or inventory.visible or pause.visible or edit_layout

# ---------------------------------------------------------------------------------- touch

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not touch_mode:
			touch_mode = true
			_on_verbs(player.focus if player else null, player.verbs if player else [])
		if edit_layout:
			_edit_touch(event)
			if not (event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0) and not (event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0):
				_forward_to_menus(event)
			return
		if menu_open() or not player:
			# Godot turns only the first finger into mouse input for the menus; a thumb still
			# resting on the glass would make every menu dead. Forward the other fingers too.
			_forward_to_menus(event)
			return
		if event is InputEventScreenTouch:
			_touch(event as InputEventScreenTouch)
		else:
			_drag(event as InputEventScreenDrag)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).device == InputEvent.DEVICE_ID_EMULATION:
		return      # touch already handled above
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
		return
	_desktop_input(event)

func _forward_to_menus(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index == 0:
			return                       # the engine already emulates the mouse for this one
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = t.pressed
		mb.position = t.position
		mb.global_position = t.position
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if t.pressed else 0
		get_viewport().set_input_as_handled()
		get_viewport().push_input(mb, true)     # already in viewport coordinates
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == 0:
			return
		var mm := InputEventMouseMotion.new()
		mm.position = d.position
		mm.global_position = d.position
		mm.relative = d.relative
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().set_input_as_handled()
		get_viewport().push_input(mm, true)

func _hit_button(pos: Vector2) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		if b.shown and pos.distance_to(b.center) <= b.size * 0.6:
			return id
	return ""

func _hit_chip(pos: Vector2) -> int:
	if not _chip_box.visible:
		return -1
	for c in _chips:
		var r := Rect2((c as Control).global_position, (c as Control).size).grow(6)
		if r.has_point(pos):
			return int(c.get_meta("verb"))
	return -1

func _touch(e: InputEventScreenTouch) -> void:
	var vp := root.get_viewport_rect().size
	if e.pressed:
		var id := _hit_button(e.position)
		if id != "":
			_owner[e.index] = "btn:" + id
			_button_down(id)
			return
		var chip := _hit_chip(e.position)
		if chip >= 0:
			_owner[e.index] = "chip"
			player.begin_verb(chip)
			return
		if e.position.x < vp.x * 0.45 and not _owner.values().has("stick"):
			_owner[e.index] = "stick"
			var fixed: bool = not Settings.get_v("stick_floating")
			_stick_origin = Vector2(vp.x * 0.14, vp.y * 0.74) if fixed else e.position
			_stick_vec = Vector2.ZERO
			_show_stick(true, e.position)
			_stick_move(e.position)
			return
		_owner[e.index] = "look"
		_look_last[e.index] = e.position
		_tap[e.index] = [Time.get_ticks_msec() / 1000.0, e.position, false]
	else:
		var o: String = _owner.get(e.index, "")
		_owner.erase(e.index)
		if o == "stick":
			_stick_vec = Vector2.ZERO
			player.move_input = Vector2.ZERO
			_show_stick(false, e.position)
		elif o.begins_with("btn:"):
			_button_up(o.substr(4))
		elif o == "chip":
			player.end_verb()
		elif o == "look":
			var t: Array = _tap.get(e.index, [])
			_tap.erase(e.index)
			_look_last.erase(e.index)
			if not t.is_empty() and not t[2] and Time.get_ticks_msec() / 1000.0 - float(t[0]) < float(Settings.get_v("interact_hold_time")) + 0.1:
				_tap_view()

func _drag(e: InputEventScreenDrag) -> void:
	var o: String = _owner.get(e.index, "")
	if o == "stick":
		_stick_move(e.position)
	elif o == "look":
		var last: Vector2 = _look_last.get(e.index, e.position)
		var d := e.position - last
		_look_last[e.index] = e.position
		if _tap.has(e.index) and (e.position - (_tap[e.index][1] as Vector2)).length() > 12.0:
			_tap[e.index][2] = true
		_look(d, 0.0058)

func _look(d: Vector2, k: float) -> void:
	var u := UIKit.unit(root)
	var s := float(Settings.get_v("look_sensitivity")) * k / u
	var aim_k := 0.55 if player.gun and player.gun.aiming else 1.0
	var ix := -1.0 if Settings.get_v("invert_x") else 1.0
	var iy := -1.0 if Settings.get_v("invert_y") else 1.0
	player.look_input += Vector2(d.x * s * ix, d.y * s * iy) * aim_k

func _stick_move(pos: Vector2) -> void:
	var u := UIKit.unit(root)
	var r := 70.0 * u * float(Settings.get_v("stick_scale"))
	var v := (pos - _stick_origin) / r
	if v.length() > 1.0:
		if Settings.get_v("stick_floating") and v.length() > 1.6:
			_stick_origin = pos - v.normalized() * r * 1.0      # the base follows a thumb that wanders off
		v = v.normalized()
	_stick_vec = v
	player.move_input = Vector2(v.x, -v.y)
	_stick_knob.position = _stick_origin + v * r - _stick_knob.size * 0.5
	_stick_base.position = _stick_origin - _stick_base.size * 0.5

func _show_stick(on: bool, pos: Vector2) -> void:
	var u := UIKit.unit(root)
	var r := 70.0 * u * float(Settings.get_v("stick_scale"))
	_stick_base.size = Vector2(r, r) * 2.0
	_stick_knob.size = Vector2(r, r) * 0.9
	_stick_base.visible = on
	_stick_knob.visible = on
	_stick_base.modulate.a = float(Settings.get_v("hud_opacity")) * 1.4
	_stick_knob.modulate.a = float(Settings.get_v("hud_opacity")) * 1.6
	_stick_base.position = _stick_origin - _stick_base.size * 0.5
	_stick_knob.position = pos - _stick_knob.size * 0.5

func _tap_view() -> void:
	if not player.verbs.is_empty() and player.mode == "normal" and player.focus:
		player.use_primary()

func _button_down(id: String) -> void:
	if Settings.is_mobile():
		Input.vibrate_handheld(12)
	match id:
		"use":
			player.use_primary()
		"crouch":
			player.crouching = not player.crouching
		"run":
			_run_toggle = not _run_toggle
		"torch":
			player.toggle_torch()
		"inv":
			open_inventory()
		"pause":
			open_pause()
		"fire":
			if player.gun: player.gun.fire()
		"aim":
			if player.gun: player.gun.set_aim(not player.gun.aiming)
		"reload":
			if player.gun: player.gun.reload()
		"gun":
			if player.gun: player.gun.toggle_equip()

func _button_up(id: String) -> void:
	if id == "use":
		player.end_verb()

# layout editing: drag any button to move it
func _edit_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var id := _hit_button(e.position)
			if id != "":
				_owner[e.index] = "edit:" + id
		else:
			_owner.erase(e.index)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		var o: String = _owner.get(e.index, "")
		if o.begins_with("edit:"):
			var id := o.substr(5)
			var safe := _safe_rect()
			var n := ((e.position - safe.position) / safe.size).clamp(Vector2(0.03, 0.04), Vector2(0.97, 0.96))
			var lay: Dictionary = (Settings.get_v("layout") as Dictionary).duplicate()
			lay[id] = [n.x, n.y]
			Settings.set_v("layout", lay, false)

func set_edit_layout(on: bool) -> void:
	edit_layout = on
	if not on:
		Settings.save()
	pause.visible = false
	get_tree().paused = on

# ---------------------------------------------------------------------------------- desktop / pad

func _desktop_input(event: InputEvent) -> void:
	if menu_open() or not player:
		if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			close_all()
		return
	if event is InputEventMouseMotion and _mouse_captured:
		_look((event as InputEventMouseMotion).relative, 0.0028)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not _mouse_captured and not touch_mode:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_captured = true
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if player.gun and player.gun.equipped: player.gun.fire()
				elif player.held: player.throw()
			pass
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if player.gun and player.gun.equipped: player.gun.set_aim(mb.pressed)
			elif mb.pressed and player.held: player.inspect(player.held)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo:
			return
		if k.pressed:
			match k.keycode:
				KEY_E: player.begin_verb(0)
				KEY_2, KEY_3, KEY_4, KEY_5: player.begin_verb(k.keycode - KEY_1)
				KEY_F: player.toggle_torch()
				KEY_C, KEY_CTRL: player.crouching = not player.crouching
				KEY_TAB, KEY_I: open_inventory()
				KEY_R: if player.gun: player.gun.reload()
				KEY_G: if player.gun: player.gun.toggle_equip()
				KEY_ESCAPE: open_pause()
		else:
			if k.keycode in [KEY_E, KEY_2, KEY_3, KEY_4, KEY_5]:
				player.end_verb()
	elif event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		touch_mode = false
		if j.pressed:
			match j.button_index:
				JOY_BUTTON_A: player.begin_verb(0)
				JOY_BUTTON_B:
					if player.mode == "hidden": player.unhide()
					elif player.held: player.drop()
				JOY_BUTTON_X: player.toggle_torch()
				JOY_BUTTON_Y: player.crouching = not player.crouching
				JOY_BUTTON_START: open_pause()
				JOY_BUTTON_BACK: open_inventory()
				JOY_BUTTON_DPAD_UP: player.begin_verb(1)
				JOY_BUTTON_DPAD_RIGHT: player.begin_verb(2)
				JOY_BUTTON_DPAD_DOWN: player.begin_verb(3)
				JOY_BUTTON_LEFT_SHOULDER: if player.gun: player.gun.reload()
				JOY_BUTTON_RIGHT_SHOULDER: _run_toggle = not _run_toggle
		elif j.button_index in [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]:
			player.end_verb()
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis == JOY_AXIS_TRIGGER_RIGHT and jm.axis_value > 0.6 and player.gun and player.gun.equipped:
			player.gun.fire()
		elif jm.axis == JOY_AXIS_TRIGGER_LEFT and player.gun and player.gun.equipped:
			player.gun.set_aim(jm.axis_value > 0.4)

func _poll_keyboard_gamepad() -> void:
	if touch_mode and _owner.values().has("stick"):
		return
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var j := pads[0]
		var lx := Input.get_joy_axis(j, JOY_AXIS_LEFT_X); var ly := Input.get_joy_axis(j, JOY_AXIS_LEFT_Y)
		if Vector2(lx, ly).length() > 0.18: mv += Vector2(lx, -ly)
		var rx := Input.get_joy_axis(j, JOY_AXIS_RIGHT_X); var ry := Input.get_joy_axis(j, JOY_AXIS_RIGHT_Y)
		var rv := Vector2(rx, ry)
		if rv.length() > 0.15:
			_look(rv * rv.length() * 14.0, 0.0058)
	if not touch_mode or mv != Vector2.ZERO:
		player.move_input = mv.limit_length(1.0)
	if Input.is_key_pressed(KEY_SHIFT):
		player.running = true

# ---------------------------------------------------------------------------------- overlays

func _release_mouse() -> void:
	if _mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured = false

func _reset_touch() -> void:
	_owner.clear()
	_stick_vec = Vector2.ZERO
	if player:
		player.move_input = Vector2.ZERO
		player.end_verb()
	_show_stick(false, Vector2.ZERO)

func open_reader(doc_id: String) -> void:
	_release_mouse(); _reset_touch()
	reader.show_doc(doc_id)
	get_tree().paused = true

func open_inventory() -> void:
	if not player:
		return
	_release_mouse(); _reset_touch()
	inventory.open(player)
	get_tree().paused = true

func open_pause() -> void:
	_release_mouse(); _reset_touch()
	pause.open()
	get_tree().paused = true

func close_all() -> void:
	reader.visible = false
	inventory.visible = false
	pause.visible = false
	get_tree().paused = false
	Events.ui_closed.emit()
