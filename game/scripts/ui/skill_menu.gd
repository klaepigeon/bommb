class_name SkillMenu
extends Control
## The two trees, side by side. Anything can be bought in any order with nuggets.

signal closed

var _cols := {}
var _count: Label
var _first: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.03, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.anchor_left = 0.04; root.anchor_right = 0.96; root.anchor_top = 0.04; root.anchor_bottom = 0.96
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 30)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(180, 64)
	done.add_theme_font_size_override("font_size", 28)
	done.pressed.connect(close)
	top.add_child(done)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	root.add_child(cols)
	for t in ["memory", "survival"]:
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cols.add_child(scroll)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 10)
		scroll.add_child(v)
		_cols[t] = v

func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	if _first:
		_first.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _refresh() -> void:
	_count.text = "Nuggets: %d" % Game.nuggets
	_first = null
	for t in _cols:
		var v: VBoxContainer = _cols[t]
		for c in v.get_children():
			c.queue_free()
		var h := Label.new()
		h.text = "MEMORY" if t == "memory" else "SURVIVAL"
		h.add_theme_font_size_override("font_size", 30)
		h.add_theme_color_override("font_color", Color("c9b8e8") if t == "memory" else Color("e8b8a8"))
		v.add_child(h)
		for s in Game.trees[t]:
			var id: String = s["id"]
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(0, 96)
			b.add_theme_font_size_override("font_size", 22)
			var state := "OWNED" if Game.owned(id) else "%d" % int(s["cost"])
			b.text = "%s   [%s]\n%s" % [s["name"], state, s["desc"]]
			b.disabled = not Game.can_buy(id)
			b.pressed.connect(func():
				Game.buy(id)
				_refresh())
			v.add_child(b)
			if _first == null and not b.disabled:
				_first = b

func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("back") or e.is_action_pressed("pause") or e.is_action_pressed("skills")):
		close()
		get_viewport().set_input_as_handled()
