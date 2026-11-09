class_name SkillMenu
extends CanvasLayer
## The skill trees: [K] / Back on a pad / "Skills" in the pause menu. Two columns, MEMORY and
## SURVIVAL; any skill can be bought, in any order, for gutterspace nuggets. Socko has an opinion
## about which one (he's tagged it). Buying applies at once (SkillEffects).

signal bought(id: String)

var player: Node
var socko: Node
var panel: Control
var count_label: Label
var rows := {}
var open := false

func setup(p_player: Node, p_socko: Node) -> void:
	player = p_player; socko = p_socko

func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("skills"):
		InputMap.add_action("skills")
		var k := InputEventKey.new(); k.physical_keycode = KEY_K; InputMap.action_add_event("skills", k)
		var j := InputEventJoypadButton.new(); j.button_index = JOY_BUTTON_BACK; InputMap.action_add_event("skills", j)
	_build()
	panel.visible = false

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = border; sb.set_border_width_all(2); sb.set_corner_radius_all(6)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	return sb

func _build() -> void:
	panel = Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.72); dim.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(center)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); center.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	var title := Label.new(); title.text = "S K I L L S"; title.add_theme_font_size_override("font_size", 22); title.add_theme_color_override("font_color", Color(0.72, 0.6, 0.38))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	count_label = Label.new(); count_label.add_theme_font_size_override("font_size", 20); count_label.add_theme_color_override("font_color", Color(1.0, 0.45, 1.0))
	head.add_child(count_label)
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", 26); v.add_child(cols)
	for tree in ["memory", "survival"]:
		var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 8); cols.add_child(col)
		var th := Label.new(); th.text = "MEMORY" if tree == "memory" else "SURVIVAL"
		th.add_theme_font_size_override("font_size", 16)
		th.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95) if tree == "memory" else Color(0.95, 0.7, 0.55))
		col.add_child(th)
		for s in Skills.TREES[tree]:
			var b := Button.new(); b.custom_minimum_size = Vector2(380, 74); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 15)
			b.add_theme_stylebox_override("normal", _style(Color(0.08, 0.08, 0.09, 0.95), Color(0.5, 0.5, 0.5, 0.4)))
			b.add_theme_stylebox_override("hover", _style(Color(0.14, 0.13, 0.12, 0.95), Color(0.85, 0.8, 0.7, 0.6)))
			b.add_theme_stylebox_override("focus", _style(Color(0.14, 0.13, 0.12, 0.95), Color(0.95, 0.85, 0.55, 0.9)))
			b.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.1, 0.1, 0.9), Color(0.4, 0.6, 0.4, 0.5)))
			b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
			b.add_theme_color_override("font_disabled_color", Color(0.6, 0.75, 0.6))
			b.pressed.connect(_buy.bind(s.id))
			col.add_child(b); rows[s.id] = b
	var close := Button.new(); close.text = "Back"; close.custom_minimum_size = Vector2(200, 56)
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_stylebox_override("normal", _style(Color(0.08, 0.08, 0.08, 0.9), Color(0.85, 0.82, 0.74, 0.35)))
	close.pressed.connect(toggle); v.add_child(close)
	add_child(panel)

func _refresh() -> void:
	count_label.text = "◆ %d" % Skills.nuggets()
	for tree in Skills.TREES:
		for s in Skills.TREES[tree]:
			var b: Button = rows[s.id]
			var tag := "   ← Socko: \"This one.\"" if s.get("socko", false) else ""
			if Skills.owned(s.id):
				b.text = "%s  ✓\n%s" % [s.name, s.desc]; b.disabled = true
			else:
				b.text = "%s  ◆ %d%s\n%s" % [s.name, s.cost, tag, s.desc]; b.disabled = false
				b.modulate = Color.WHITE if Skills.can_buy(s.id) else Color(0.7, 0.7, 0.7)

func toggle() -> void:
	open = not open
	panel.visible = open
	get_tree().paused = open
	if open:
		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		(rows["headshot"] as Button).grab_focus()
	else:
		if not Game.has_touch(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(e: InputEvent) -> void:
	if e.is_action_pressed("skills") or (open and e.is_action_pressed("ui_cancel")):
		toggle(); get_viewport().set_input_as_handled()

func _buy(id: String) -> void:
	if Skills.buy(id):
		SkillEffects.apply(id, player)
		bought.emit(id)
	_refresh()
