class_name SkillsMenu
extends CanvasLayer
## The two trees, side by side (docs/SKILLS.md): Memory on the left, Infection on the right.
## Each node is a button in its tree's grid (tier = row, col = column); a node lit is his, one
## outlined can be had now, one dim isn't reachable yet. The panel at the bottom says what the
## selected node does (and, for a Memory node he has, what he remembers) and buys it.
## "skills" (Tab / K / Back / the SKILLS button) opens and closes it; the game pauses while it's up.
## Mouse, touch and gamepad (focus moves between the buttons; accept buys).

const COL_MEMORY := Color("e0c890")
const COL_INFECT := Color("9fd4ff")

var _root: Control
var _buttons := {}           # id -> Button
var _points := {}            # tree -> Label
var _sel := ""
var _title: Label
var _body: Label
var _buy: Button

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func toggle() -> void:
	if visible: close()
	else: open()

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	var first: String = _sel if _sel != "" else String(Skills.NODES.keys()[0])
	_select(first)
	(_buttons[first] as Button).grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	if not Game.uses_touch(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if not visible: return
	if e.is_action_pressed("skills") or e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		close(); get_viewport().set_input_as_handled()

func _build() -> void:
	_root = Control.new(); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new(); dim.color = Color(0.02, 0.02, 0.03, 0.88); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	_root.add_child(margin)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); margin.add_child(v)
	var trees := HBoxContainer.new(); trees.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trees.add_theme_constant_override("separation", 40)
	v.add_child(trees)
	for tree in ["memory", "infection"]:
		var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 10)
		trees.add_child(col)
		var head := HBoxContainer.new(); col.add_child(head)
		var t := Label.new(); t.text = "MEMORY" if tree == "memory" else "INFECTION"
		t.add_theme_font_size_override("font_size", 28); t.add_theme_color_override("font_color", COL_MEMORY if tree == "memory" else COL_INFECT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var pts := Label.new(); pts.add_theme_font_size_override("font_size", 20); head.add_child(pts)
		_points[tree] = pts
		var grid := GridContainer.new(); grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
		col.add_child(grid)
		# a 4 x 3 grid: blanks where a tree has no node
		var cells := {}
		for id in Skills.NODES:
			var n: Dictionary = Skills.NODES[id]
			if n.tree == tree: cells[Vector2i(int(n.col), int(n.tier))] = id
		for row in 4:
			for c in 3:
				var key := Vector2i(c, row)
				if cells.has(key):
					var id: String = cells[key]
					var b := Button.new(); b.custom_minimum_size = Vector2(150, 64)
					b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					b.add_theme_font_size_override("font_size", 17)
					b.focus_entered.connect(func(): _select(id))
					b.mouse_entered.connect(func(): _select(id))
					b.pressed.connect(func(): _select(id); _try_buy())
					grid.add_child(b); _buttons[id] = b
				else:
					var gap := Control.new(); gap.custom_minimum_size = Vector2(150, 64); grid.add_child(gap)
	# the details
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.08, 0.1, 0.95); sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	v.add_child(panel)
	var pv := VBoxContainer.new(); panel.add_child(pv)
	_title = Label.new(); _title.add_theme_font_size_override("font_size", 24); pv.add_child(_title)
	_body = Label.new(); _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.add_theme_font_size_override("font_size", 18)
	_body.custom_minimum_size = Vector2(0, 70); pv.add_child(_body)
	var row := HBoxContainer.new(); pv.add_child(row)
	_buy = Button.new(); _buy.text = "Unlock"; _buy.add_theme_font_size_override("font_size", 20); _buy.custom_minimum_size = Vector2(160, 44)
	_buy.pressed.connect(_try_buy); row.add_child(_buy)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
	var close_b := Button.new(); close_b.text = "Close"; close_b.add_theme_font_size_override("font_size", 20); close_b.custom_minimum_size = Vector2(120, 44)
	close_b.pressed.connect(close); row.add_child(close_b)

func _refresh() -> void:
	(_points.memory as Label).text = "%d point%s" % [Game.memory_points, "" if Game.memory_points == 1 else "s"]
	(_points.infection as Label).text = "%d point%s" % [Game.skill_points, "" if Game.skill_points == 1 else "s"]
	for id in _buttons:
		var b: Button = _buttons[id]
		var n: Dictionary = Skills.NODES[id]
		var c: Color = COL_MEMORY if n.tree == "memory" else COL_INFECT
		b.text = "%s\n%s" % [n.name, "✓" if Skills.has(id) else "%d pt" % int(n.cost)]
		var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(4); sb.set_content_margin_all(6)
		if Skills.has(id):
			sb.bg_color = c.darkened(0.55); b.add_theme_color_override("font_color", c.lightened(0.3))
		elif _reachable(id):
			sb.bg_color = Color(0.12, 0.12, 0.14); sb.border_color = c; sb.set_border_width_all(2)
			b.add_theme_color_override("font_color", c)
		else:
			sb.bg_color = Color(0.07, 0.07, 0.08); b.add_theme_color_override("font_color", Color(0.4, 0.4, 0.42))
		b.add_theme_stylebox_override("normal", sb)
		var f := sb.duplicate() as StyleBoxFlat; f.border_color = Color.WHITE; f.set_border_width_all(3)
		b.add_theme_stylebox_override("focus", f); b.add_theme_stylebox_override("hover", f)

func _reachable(id: String) -> bool:
	for r in Skills.NODES[id].req:
		if not Skills.has(r): return false
	return true

func _select(id: String) -> void:
	_sel = id
	var n: Dictionary = Skills.NODES[id]
	_title.text = n.name
	_title.add_theme_color_override("font_color", COL_MEMORY if n.tree == "memory" else COL_INFECT)
	var lines := [String(n.effect)]
	if n.req.size() > 0:
		var names := []
		for r in n.req: names.append(Skills.NODES[r].name)
		lines.append("Needs: " + ", ".join(names))
	if Skills.has(id) and n.has("memory"): lines.append("\n" + String(n.memory))
	_body.text = "\n".join(lines)
	if Skills.has(id): _buy.text = "Unlocked"; _buy.disabled = true
	else:
		_buy.text = "Unlock (%d)" % int(n.cost)
		_buy.disabled = not Skills.can_unlock(id)

func _try_buy() -> void:
	if _sel == "" or not Skills.can_unlock(_sel): return
	Skills.unlock(_sel)
	Sfx.play("sting", -14.0, 1.4)
	_refresh(); _select(_sel)
