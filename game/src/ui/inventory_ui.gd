extends Control
## The bag. Big tiles (thumb-sized), grouped by what things are for. Tap a tile: its name, what
## it is, and what can be done with it right now (use, read, equip, set down). Closing resumes.

var hud: Node
var player: Player
var _grid: GridContainer
var _detail_name: Label
var _detail_text: Label
var _actions: HBoxContainer
var _status: Label
var _sel := ""

const ORDER := ["weapon", "tool", "key", "consumable", "document", "misc"]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.fullscreen_dim(0.86))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	add_child(margin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	margin.add_child(hb)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var title := UIKit.label("What Kurt's carrying", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := UIKit.button("  Close  ")
	close.pressed.connect(func(): hud.close_all())
	top.add_child(title); top.add_child(close)
	left.add_child(top)
	_status = UIKit.label("", 20, Color(0.8, 0.75, 0.65))
	left.add_child(_status)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new(); _grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12); _grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	left.add_child(scroll)
	hb.add_child(left)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.08, 0.07, 0.06, 0.95)))
	right.custom_minimum_size = Vector2(380, 0)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 16)
	_detail_name = UIKit.label("", 28)
	_detail_text = UIKit.label("", 20, Color(0.85, 0.82, 0.75))
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(340, 0)
	_actions = HBoxContainer.new(); _actions.add_theme_constant_override("separation", 10)
	rv.add_child(_detail_name); rv.add_child(_detail_text); rv.add_child(_actions)
	right.add_child(rv)
	hb.add_child(right)

func open(p: Player) -> void:
	player = p
	visible = true
	fit()
	_refresh()

func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var ids: Array = player.inv.list()
	ids.sort_custom(func(a, b): return ORDER.find(ItemDB.category(a)) < ORDER.find(ItemDB.category(b)))
	var u := UIKit.unit(self)
	_grid.columns = 4 if get_viewport_rect().size.x > 1000 else 3
	for id in ids:
		var b := UIKit.button("", 20, 110.0 * u)
		var n := player.inv.count(id)
		b.text = ItemDB.item_name(id) + ("\n×%d" % n if n > 1 else "")
		b.custom_minimum_size = Vector2(150 * u, 110 * u)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): _select(id))
		_grid.add_child(b)
	var bits := []
	if player.gun:
		bits.append("Revolver: %d loaded" % player.gun.loaded)
	if player.inv.has("torch"):
		bits.append("Torch: %d%%" % int(player.torch_charge() * 100))
	if player.injury > 0:
		bits.append(["", "Bruised", "Hurt", "Badly hurt"][player.injury])
	_status.text = "   ".join(bits)
	if _sel == "" or not player.inv.has(_sel):
		_sel = ids[0] if not ids.is_empty() else ""
	_select(_sel)

func _select(id: String) -> void:
	_sel = id
	for c in _actions.get_children():
		c.queue_free()
	if id == "":
		_detail_name.text = "Nothing."
		_detail_text.text = ""
		return
	var it := ItemDB.get_item(id)
	_detail_name.text = ItemDB.item_name(id)
	var desc := String(it.get("desc", ""))
	if desc == "" and it.has("doc"):
		desc = "Something to read."
	_detail_text.text = desc
	var acts := []
	match ItemDB.category(id):
		"document": acts.append(["Read", id])
		"consumable":
			if id == "battery": acts.append(["Put in the torch", id])
			elif id == "bandage": acts.append(["Bind a wound" if player.injury > 0 else "(not hurt)", id])
			elif id == "pills": acts.append(["Take one", id])
		"weapon":
			if id == "revolver":
				acts.append(["Put it away" if player.gun and player.gun.equipped else "Take it out", id])
				acts.append(["Check the cylinder", "check_cylinder"])
		"tool":
			if id in ["torch", "lighter"]: acts.append(["Switch off" if player.torch_on else "Switch on", id])
		"misc":
			if id == "alarm_clock": acts.append(["Wind it, set it down here", id])
			if id == "music_box": acts.append(["Wind it, set it down here", id])
	for a in acts:
		var b := UIKit.button(String(a[0]))
		b.pressed.connect(func():
			hud.close_all()
			player.use_item(String(a[1])))
		_actions.add_child(b)

## overlays start hidden, and a hidden Control doesn't follow its parent's size: fit on open
func fit() -> void:
	var par := get_parent() as Control
	position = Vector2.ZERO
	size = par.size if par else get_viewport_rect().size
