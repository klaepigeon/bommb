class_name Hud
extends CanvasLayer
## Everything on the glass during a match, in MURDERLAND's party style (PartyUi): the round
## and the rulebook along the top, the contestants' cards (Teeth, Dead Rats, items,
## conditions), what the Caller says, toasts, whatever this device's players have to do
## (their turn, a prompt, a ghost's turn, getting up from the table), the minigame card,
## each minigame's own controls, the results sequence, the cutscene letterbox, the finale
## and the standings. It only shows the view and sends actions (`act`); no rules here.
## Layout follows UiManager (safe areas, the profile, the player's sizes).

signal act(seat: int, a: Dictionary)
signal leave_pressed
signal lobby_pressed
signal look_toggled

var root: Control
var top: HBoxContainer
var round_lbl: Label
var rules_box: HFlowContainer
var cards_box: BoxContainer
var cards: Array = []
var dialog_text: Label
var toast_box: VBoxContainer
var actions: VBoxContainer
var modal: PanelContainer
var modal_box: VBoxContainer
var card: PanelContainer
var card_box: VBoxContainer
var controls_box: HBoxContainer
var stick: TouchStick
var fp_stick: TouchStick
var info: Label
var attention: Label
var look_btn: Button
var menu_btn: Button
var letterbox: Array = []
var cutscene_lbl: Label
var facility_panel: PanelContainer
var facility_box: VBoxContainer
var organ_panel: PanelContainer
var organ_box: VBoxContainer
var view: Dictionary = {}
var local: Array = []
var menu_mode := ""
var _typing := ""
var _typed := 0.0
var _sig := {}
var _rings: Array = []
var _tracepads: Array = []
var _holds: Array = []
var _swipes: Array = []
var _taps: Array = []
var _menu_open := false


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = PartyUi.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# the top bar: the round, the amendments in force, the Control System's next move
	top = PartyUi.hbox(10)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	menu_btn = PartyUi.button("≡", func(): _toggle_menu(), PartyUi.CREAM, 64.0, 26)
	top.add_child(menu_btn)
	round_lbl = PartyUi.shout("", 28, PartyUi.YELLOW)
	round_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(round_lbl)
	rules_box = PartyUi.flow(6)
	rules_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rules_box)
	attention = PartyUi.label("", 20, PartyUi.MINT, true, true)
	attention.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(attention)
	# the cards
	cards_box = VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 6)
	cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cards_box)
	for i in 4:
		var c := _card_ui(i)
		cards_box.add_child(c.root)
		cards.append(c)
	# what he says
	dialog_text = PartyUi.shout("", 30, PartyUi.CREAM)
	dialog_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	root.add_child(dialog_text)
	toast_box = PartyUi.vbox(4)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	root.add_child(toast_box)
	info = PartyUi.label("", 20, PartyUi.CREAM, true, true)
	info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info)
	actions = PartyUi.vbox(8)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(actions)
	controls_box = PartyUi.hbox(12)
	controls_box.alignment = BoxContainer.ALIGNMENT_END
	controls_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(controls_box)
	stick = TouchStick.new()
	stick.custom_minimum_size = Vector2(240, 240)
	stick.visible = false
	root.add_child(stick)
	fp_stick = TouchStick.new()
	fp_stick.custom_minimum_size = Vector2(240, 240)
	fp_stick.visible = false
	root.add_child(fp_stick)
	facility_panel = PartyUi.panel(Color(0.1, 0.04, 0.1, 0.82), PartyUi.TURQ)
	facility_panel.visible = false
	root.add_child(facility_panel)
	facility_box = PartyUi.vbox(6)
	facility_panel.add_child(facility_box)
	organ_panel = PartyUi.panel(Color(0.06, 0.02, 0.04, 0.86), PartyUi.SILVER)
	organ_panel.visible = false
	root.add_child(organ_panel)
	organ_box = PartyUi.vbox(4)
	organ_panel.add_child(organ_box)
	modal = PartyUi.panel(PartyUi.CREAM, PartyUi.INK, 28)
	modal.visible = false
	root.add_child(modal)
	var ms := ScrollContainer.new()
	ms.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ms.custom_minimum_size = Vector2(700, 300)
	modal.add_child(ms)
	modal_box = PartyUi.vbox(10)
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.mouse_filter = Control.MOUSE_FILTER_PASS
	ms.add_child(modal_box)
	card = PartyUi.panel(PartyUi.CREAM, PartyUi.INK, 30)
	card.visible = false
	root.add_child(card)
	card_box = PartyUi.vbox(8)
	card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_box.mouse_filter = Control.MOUSE_FILTER_PASS
	card_box.custom_minimum_size = Vector2(760, 0)
	card.add_child(card_box)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.visible = false
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(bar)
		letterbox.append(bar)
	cutscene_lbl = PartyUi.shout("", 34, PartyUi.PINK)
	cutscene_lbl.visible = false
	root.add_child(cutscene_lbl)
	look_btn = PartyUi.button("LOOK UP", func(): look_toggled.emit(), PartyUi.TURQ, 150.0, 20)
	root.add_child(look_btn)
	Ui.changed.connect(_layout)
	_layout()


## Lay it out for this screen: safe insets, phone/tablet/desktop, left-handed.
func _layout() -> void:
	var m: Rect2 = Ui.margins
	var vp := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1280, 720)
	var portrait := vp.y > vp.x
	top.offset_left = m.position.x
	top.offset_right = -m.size.x
	top.offset_top = m.position.y
	# cards: down the left in landscape, along the top in portrait
	var horizontal := portrait
	if horizontal != (cards_box is HBoxContainer):
		var nb: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
		nb.add_theme_constant_override("separation", 6)
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in cards:
			cards_box.remove_child(c.root)
			nb.add_child(c.root)
		root.remove_child(cards_box)
		cards_box.queue_free()
		cards_box = nb
		root.add_child(cards_box)
		root.move_child(cards_box, 1)
	cards_box.position = Vector2(m.position.x, m.position.y + 78 * PartyUi.k())
	for c in cards:
		(c.root as Control).custom_minimum_size = Vector2((vp.x - 40) / 4.2 if horizontal else 300 * PartyUi.k(), 0)
	dialog_text.offset_left = -vp.x * 0.32
	dialog_text.offset_right = vp.x * 0.32
	dialog_text.offset_top = m.position.y + 70 * PartyUi.k()
	dialog_text.offset_bottom = dialog_text.offset_top + 120
	toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_box.offset_left = -vp.x * 0.24
	toast_box.offset_right = vp.x * 0.24
	toast_box.offset_top = -m.size.y - 230 * PartyUi.k()
	toast_box.offset_bottom = -m.size.y - 70 * PartyUi.k()
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	info.offset_left = -vp.x * 0.3
	info.offset_right = vp.x * 0.3
	info.offset_top = -m.size.y - 60
	info.offset_bottom = -m.size.y - 10
	var right := not Ui.left_handed
	_corner(actions, right, Vector2(360, 600) * PartyUi.bk(), m)
	_corner(controls_box, right, Vector2(vp.x * 0.7, 300), m)
	_corner(stick, not right, Vector2(240, 240) * PartyUi.bk(), m)
	_corner(fp_stick, not right, Vector2(240, 240) * PartyUi.bk(), m)
	facility_panel.position = Vector2(vp.x - m.size.x - 420 * PartyUi.k(), m.position.y + 80) if right else Vector2(m.position.x, m.position.y + 80)
	facility_panel.custom_minimum_size = Vector2(400, 0) * PartyUi.k()
	organ_panel.position = Vector2(vp.x * 0.5 - 330 * PartyUi.k(), m.position.y + 70)
	organ_panel.custom_minimum_size = Vector2(660, 0) * PartyUi.k()
	modal.position = vp * 0.5 - Vector2(380, 230) * PartyUi.k()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	(letterbox[0] as ColorRect).position = Vector2.ZERO
	(letterbox[0] as ColorRect).size = Vector2(vp.x, vp.y * 0.12)
	(letterbox[1] as ColorRect).position = Vector2(0, vp.y * 0.88)
	(letterbox[1] as ColorRect).size = Vector2(vp.x, vp.y * 0.12)
	cutscene_lbl.position = Vector2(0, vp.y * 0.89)
	cutscene_lbl.size = Vector2(vp.x, vp.y * 0.1)
	look_btn.position = Vector2(m.position.x, vp.y - m.size.y - 70 * PartyUi.bk()) if right else Vector2(vp.x - m.size.x - 160, vp.y - m.size.y - 70 * PartyUi.bk())


func _corner(c: Control, right: bool, sz: Vector2, m: Rect2) -> void:
	var vp := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1280, 720)
	c.size = sz
	c.position = Vector2(vp.x - m.size.x - sz.x if right else m.position.x, vp.y - m.size.y - sz.y)


func _card_ui(i: int) -> Dictionary:
	var p := PartyUi.panel(PartyUi.CREAM, PartyUi.INK, 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := PartyUi.hbox(8)
	p.add_child(h)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(10, 40)
	stripe.color = PartyUi.seat_colour(i)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(stripe)
	var v := PartyUi.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := PartyUi.label("", 20, PartyUi.INK, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	var money := PartyUi.hbox(6)
	var teeth := PartyUi.chip("0 TEETH", PartyUi.CREAM.darkened(0.05), 15)
	var rats := PartyUi.chip("0 DEAD RATS", PartyUi.YELLOW, 15)
	money.add_child(teeth)
	money.add_child(rats)
	var chips := PartyUi.flow(4)
	var hurt := PartyUi.label("", 13, PartyUi.BLOOD)
	v.add_child(nm)
	v.add_child(money)
	v.add_child(chips)
	v.add_child(hurt)
	return {"root": p, "name": nm, "teeth": teeth, "rats": rats, "chips": chips, "hurt": hurt, "sig": ""}


# --- updates --------------------------------------------------------------------------

func update(v: Dictionary, local_seats: Array, delta: float) -> void:
	view = v
	local = local_seats
	if v.is_empty():
		return
	for i in 4:
		(cards[i].root as Control).visible = i < v.players.size()
		if i < v.players.size():
			_fill_card(cards[i], v.players[i], v)
	_typed += delta * 45.0
	dialog_text.text = _typing.substr(0, int(_typed))
	_top(v)
	_status(v)
	_section("actions", _action_signature(v), func(): _actions(v))
	_section("card", _card_signature(v), func(): _cards(v))
	_section("controls", _controls_signature(v), func(): _controls(v))
	_section("facility", _facility_signature(v), func(): _facility(v))
	_section("organ", _organ_signature(v), func(): _organ(v))
	_cutscene(v)
	_sticks(v)
	var t := float(v.get("mg", {}).get("t", 0.0))
	for r in _rings:
		if is_instance_valid(r):
			r.sync(t) if absf(r.t - t) > 0.25 else null
	for tp in _tracepads:
		if is_instance_valid(tp) and v.mg.has("path"):
			tp.guide = v.mg.path
			tp.protected = v.mg.get("protected", []) if v.mg.get("my_role", "") == "patient" else []


func _section(key: String, sig: String, build: Callable) -> void:
	if _sig.get(key, "") == sig:
		return
	_sig[key] = sig
	build.call()


func _me() -> int:
	return int(local[0]) if not local.is_empty() else -1


func _fill_card(c: Dictionary, p: Dictionary, v: Dictionary) -> void:
	var turn: bool = int(v.turn.get("seat", -1)) == int(p.seat) and v.phase == "turn"
	var sig := str([p.name, p.teeth, p.rats, p.alive, p.ghost, p.location, p.statuses.map(func(s): return s.id), p.suspicion, p.cage, turn, p.item_count, p.items, p.helmet, p.armour,
		p.body.values().map(func(b): return b.s), p.away_t if p.location != "table" else 0, p.has_key])
	if sig == c.sig:
		return
	c.sig = sig
	c.name.text = ("▶ " if turn else "") + str(p.name) + ("  (YOU)" if local.has(int(p.seat)) and local.size() == 1 else "")
	(c.root as Control).modulate = Color.WHITE if p.alive else (Color(0.75, 0.85, 1.0, 0.85) if p.ghost else Color(0.6, 0.6, 0.6))
	(c.teeth.get_child(0) as Label).text = "%d TEETH" % int(p.teeth)
	(c.rats.get_child(0) as Label).text = "%d DEAD RAT%s" % [int(p.rats), "" if int(p.rats) == 1 else "S"]
	for ch in c.chips.get_children():
		ch.queue_free()
	if p.ghost:
		c.chips.add_child(PartyUi.chip("GHOST", PartyUi.TURQ, 13))
	if str(p.location) == "away":
		c.chips.add_child(PartyUi.chip("AWAY %ds" % maxi(0, int(float(p.away_limit) - float(p.away_t))), PartyUi.ORANGE, 13))
	elif str(p.location) == "escaped":
		c.chips.add_child(PartyUi.chip("ESCAPED", PartyUi.MINT, 13))
	var mine := local.has(int(p.seat))
	if mine:
		for it in p.items:
			c.chips.add_child(PartyUi.chip(Items.name_of(it), PartyUi.PURPLE.lightened(0.3), 12))
	elif int(p.item_count) > 0:
		c.chips.add_child(PartyUi.chip("%d ITEM%s" % [int(p.item_count), "" if int(p.item_count) == 1 else "S"], PartyUi.PURPLE.lightened(0.3), 12))
	if p.helmet:
		c.chips.add_child(PartyUi.chip("HELMET", PartyUi.SILVER, 12))
	if int(p.get("armour", 0)) > 0:
		c.chips.add_child(PartyUi.chip("ARMOUR %d" % int(p.armour), PartyUi.SILVER, 12))
	for st in p.get("statuses", []):
		c.chips.add_child(PartyUi.chip(str(st.id).to_upper().replace("_", " "), PartyUi.MINT if str(st.id) == "stimulant" else PartyUi.RED.lightened(0.2), 12))
	if p.has_key:
		c.chips.add_child(PartyUi.chip("KEY", PartyUi.YELLOW, 12))
	var levels: Array = v.get("cage_levels", [])
	if int(p.cage) > 0:
		c.chips.add_child(PartyUi.chip("CAGE: " + (str(levels[int(p.cage)]) if int(p.cage) < levels.size() else str(p.cage)), PartyUi.INK.lightened(0.2), 12))
	if int(p.suspicion) > 0:
		c.chips.add_child(PartyUi.chip("SUS %d" % int(p.suspicion), PartyUi.RED if int(p.suspicion) >= 75 else (PartyUi.ORANGE if int(p.suspicion) >= 50 else PartyUi.CREAM), 12))
	var hurts := []
	for part in Body.PARTS:
		var s: String = p.body[part].s
		if s != "ok":
			hurts.append(Body.LABEL.get(part, part).to_lower() + " " + s)
	c.hurt.text = ", ".join(hurts) if not hurts.is_empty() else ""
	c.hurt.visible = not hurts.is_empty()


func _top(v: Dictionary) -> void:
	var r := "ROUND %d/%d" % [int(v.round), int(v.max_rounds)]
	if v.get("final", false):
		r = "FINAL ROUND"
	if v.phase in ["finale", "ending"]:
		r = "THE END OF THE PARTY"
	round_lbl.text = r
	var sig := str(v.get("rules", [])) + str(v.get("machines", {}).get("planned", {})) + str(v.get("objectives", []))
	if _sig.get("top", "") != sig:
		_sig["top"] = sig
		for c in rules_box.get_children():
			c.queue_free()
		for rl in v.get("rules", []):
			var ch := PartyUi.chip("%s%s" % [rl.name, "" if int(rl.left) == 0 else " (%d)" % int(rl.left)], PartyUi.CREAM, 14)
			ch.tooltip_text = str(rl.desc)
			ch.mouse_filter = Control.MOUSE_FILTER_PASS
			rules_box.add_child(ch)
		var pl: Dictionary = v.get("machines", {}).get("planned", {})
		if not pl.is_empty():
			rules_box.add_child(PartyUi.chip("NEXT ROUND: %s" % str(pl.get("name", "")), PartyUi.PINK, 14))
		for o in v.get("objectives", []):
			rules_box.add_child(PartyUi.chip("CALLER'S GAME: %s" % str(o.name), PartyUi.PURPLE.lightened(0.2), 14))
	var att: Dictionary = v.get("attention", {})
	if att.is_empty() or v.phase in ["ending", "finale"]:
		attention.text = ""
	elif att.get("watching", false):
		var tgt := int(att.get("target", -1))
		attention.text = "HE'S WATCHING " + ("YOU" if local.has(tgt) else (str(v.players[tgt].name) if tgt >= 0 else "EVERYONE"))
		attention.add_theme_color_override("font_color", PartyUi.RED)
	elif att.get("turning", false):
		attention.text = "HE'S TURNING ROUND..."
		attention.add_theme_color_override("font_color", PartyUi.YELLOW)
	else:
		attention.text = "HE'S LOOKING AWAY"
		attention.add_theme_color_override("font_color", PartyUi.MINT)


func _status(v: Dictionary) -> void:
	var s := ""
	match str(v.phase):
		"turn":
			var cur := int(v.turn.get("seat", -1))
			if cur >= 0:
				var who: String = "YOUR" if local.has(cur) else str(v.players[cur].name) + "'S"
				s = "%s TURN" % who
				if v.turn.sub == "moving":
					s += "   %d TO GO" % int(v.turn.steps)
				elif v.turn.sub == "missed":
					s = "%s IS AWAY: TURN MISSED" % str(v.players[cur].name)
		"mg_play":
			s = str(v.mg.get("title", ""))
			if v.mg.has("time_left"):
				s += "   %d" % int(v.mg.time_left)
			if v.mg.has("prompt"):
				s += "   " + str(v.mg.prompt)
			if v.mg_id == "roulette":
				var row := ""
				for i in int(v.mg.chambers):
					row += ("x " if i < int(v.mg.clicks) else "o ")
				s += "   " + row
		"door":
			s = "THE DOOR: everyone has to push"
	info.text = s
	look_btn.visible = v.phase == "turn" and not _away()
	look_btn.text = "THE BOARD" if get_parent() and get_parent().get("look_mode") == "room" else "LOOK UP"


func _away() -> bool:
	var me := _me()
	return me >= 0 and str(view.players[me].location) != "table"


# --- what you can do --------------------------------------------------------------------

func _action_signature(v: Dictionary) -> String:
	var mg: Dictionary = v.get("mg", {})
	var me := _me()
	var mp: Dictionary = v.players[me] if me >= 0 else {}
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [v.phase, v.turn.get("seat", -1), v.turn.get("sub", ""), menu_mode, str(v.turn.get("prompt", {}).hash()),
		str(mp.get("items", [])), str(mp.get("location", "")), str(v.players.map(func(p): return [p.alive, p.teeth, p.rats])), mg.get("turn", ""), mg.get("sub", ""),
		str(mg.get("actions", []).hash()) + str(mg.get("cheats", []).size()) + str(mg.get("peeks", {})) + str(mg.get("offer", {})) + str(mg.get("holder", "")) + str(mg.get("step", "")),
		str(v.get("ready", []).has(me)) + str(v.get("ghosts", [])) + str(v.get("cheats", []).size())]


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _actions(v: Dictionary) -> void:
	_clear(actions)
	modal.visible = false
	var phase := str(v.phase)
	var me := _me()
	if phase in ["intro", "mg_intro", "mg_results", "finale"]:
		if not v.get("ready", []).has(me):
			actions.add_child(PartyUi.primary("READY!", func():
				for s in local:
					act.emit(s, {"t": "ready"})))
		return
	if phase == "door":
		for s in local:
			if v.players[s].alive and not v.door_push.has(s):
				actions.add_child(PartyUi.primary("PUSH (%s)" % v.players[s].name, func(): act.emit(s, {"t": "push"})))
		return
	if phase == "turn":
		var s := int(v.turn.seat)
		if local.has(s):
			var mp: Dictionary = v.players[s]
			if v.turn.sub == "pre":
				_board_actions(s, mp, v)
			elif v.turn.sub == "prompt" and not (v.turn.prompt as Dictionary).is_empty():
				_prompt(s, v.turn.prompt, v)
			elif v.turn.sub == "ghost":
				_ghost_actions(s, mp, v)
		# anyone at the table can get up, any time it isn't their own move
		for q in local:
			var p: Dictionary = v.players[q]
			if p.alive and str(p.location) == "table" and not (q == s and v.turn.sub in ["moving", "prompt"]):
				actions.add_child(PartyUi.button("GET UP FROM THE TABLE", func(): act.emit(q, {"t": "leave", "pos": _seat_pos(q)}), PartyUi.ORANGE, 260.0, 18))
				break
		return
	if phase == "mg_play":
		var mg: Dictionary = v.mg
		for s in local:
			if v.players[s].get("ghost", false):
				_ghost_mg_actions(s, v)
				return
		match str(v.mg_id):
			"roulette":
				var s := int(mg.turn)
				if local.has(s) and mg.sub == "turn":
					_roulette_actions(s, v)
				return
			"hot_potato":
				var h := int(mg.holder)
				if local.has(h) and mg.sub == "play" and mg.flight.is_empty() and mg.busy.is_empty():
					_potato_actions(h, v)
				return
		for s in local:
			if v.players[s].alive:
				_generic_mg_actions(s, mg)
				return


func _seat_pos(s: int) -> Array:
	var gv = get_parent()
	if gv and gv.has_method("seat_floor_pos"):
		var p: Vector2 = gv.seat_floor_pos(s)
		return [p.x, p.y]
	return [0, 1.9]


func _board_actions(s: int, me: Dictionary, v: Dictionary) -> void:
	if menu_mode.begins_with("target:"):
		var parts := menu_mode.substr(7).split("|")
		var it := parts[0]
		for p in v.players:
			if p.alive and int(p.seat) != s:
				actions.add_child(PartyUi.button("ON " + str(p.name), func():
					menu_mode = ""
					act.emit(s, {"t": "item", "id": it, "target": int(p.seat)}), PartyUi.seat_colour(int(p.seat)), 220.0))
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	if menu_mode.begins_with("choice:"):
		var it := menu_mode.substr(7)
		for ch in Items.def(it).get("choices", ["LOW", "HIGH"]):
			var c := str(ch)
			actions.add_child(PartyUi.button(c, func():
				menu_mode = ""
				act.emit(s, {"t": "item", "id": it, "choice": c}), PartyUi.YELLOW, 220.0))
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	if menu_mode == "give":
		for it in me.items:
			for p in v.players:
				if (p.alive and int(p.seat) != s) or (it == "lazarus_rat" and p.ghost):
					var tgt := int(p.seat)
					var iid := str(it)
					actions.add_child(PartyUi.button("%s TO %s" % [Items.name_of(iid), p.name], func():
						menu_mode = ""
						act.emit(s, {"t": "give", "id": iid, "target": tgt}), PartyUi.CREAM, 300.0, 16))
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	if menu_mode == "cheat":
		var cat: Dictionary = Assets.load_json("res://assets/data/cheats.json").cheats
		for cid in v.get("cheats", []):
			var d: Dictionary = cat.get(cid, {})
			var id := str(cid)
			if d.get("target", false):
				for p in v.players:
					if p.alive and int(p.seat) != s:
						var tgt := int(p.seat)
						actions.add_child(PartyUi.button("%s: %s" % [d.name, p.name], func():
							menu_mode = ""
							act.emit(s, {"t": "cheat", "id": id, "target": tgt}), PartyUi.CREAM, 300.0, 16))
			else:
				actions.add_child(PartyUi.button(str(d.name), func():
					menu_mode = ""
					act.emit(s, {"t": "cheat", "id": id}), PartyUi.CREAM, 300.0, 16))
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	# the three slots
	var slots := PartyUi.hbox(6)
	for i in Items.MAX_HELD:
		if i < me.items.size():
			var it: String = me.items[i]
			var usable := Items.usable_on_board(it)
			var b := PartyUi.button(Items.name_of(it), func():
				var tgt := Items.target_of(it)
				if tgt == "player":
					menu_mode = "target:" + it
				elif tgt == "choice":
					menu_mode = "choice:" + it
				else:
					act.emit(s, {"t": "item", "id": it}), PartyUi.PURPLE.lightened(0.35) if usable else PartyUi.SILVER, 110.0, 14)
			b.disabled = not usable
			b.tooltip_text = Items.desc_of(it)
			slots.add_child(b)
		else:
			var e := PartyUi.chip("EMPTY", Color("d8cfc0"), 14)
			e.custom_minimum_size = Vector2(110, 60) * PartyUi.bk()
			slots.add_child(e)
	actions.add_child(slots)
	if me.at_door:
		actions.add_child(PartyUi.button("TRY THE DOOR", func(): act.emit(s, {"t": "try_door"})))
		actions.add_child(PartyUi.button("WAIT HERE", func(): act.emit(s, {"t": "stay"})))
	var row := PartyUi.hbox(6)
	if not me.items.is_empty():
		row.add_child(PartyUi.button("GIVE", func(): menu_mode = "give", PartyUi.CREAM, 110.0, 18))
	if int(me.clue_count) > 0:
		row.add_child(PartyUi.button("TELL", func(): act.emit(s, {"t": "share"}), PartyUi.CREAM, 110.0, 18))
	if not v.get("cheats", []).is_empty():
		row.add_child(PartyUi.button("CHEAT", func(): menu_mode = "cheat", PartyUi.CREAM, 110.0, 18))
	actions.add_child(row)
	var dmax := Body.dice_max(me.body, int(me.painkillers) > 0)
	var nr := str(me.get("next_roll", ""))
	var lbl := {"low": "ROLL (1-3)", "high": "ROLL (4-6)", "d10": "ROLL THE D10", "double": "ROLL TWICE", "loaded_double": "ROLL TWO DICE", "six": "ROLL (it's loaded)"}.get(nr, "ROLL (1-%d)" % dmax)
	actions.add_child(PartyUi.primary(lbl, func(): act.emit(s, {"t": "roll"}), 300.0))


func _modal_title(text: String, sub := "") -> void:
	modal_box.add_child(PartyUi.label(text, 30, PartyUi.INK, true))
	if sub != "":
		modal_box.add_child(PartyUi.label(sub, 18, PartyUi.INK))


func _prompt(s: int, pr: Dictionary, v: Dictionary) -> void:
	modal.visible = true
	_clear(modal_box)
	var me: Dictionary = v.players[s]
	var ans := func(a: Dictionary): act.emit(s, a.merged({"t": "answer"}))
	match str(pr.kind):
		"door_stop":
			_modal_title("THE DOOR", "You're passing the door. Stop here?")
			var h := PartyUi.hbox(8)
			h.add_child(PartyUi.button("STOP", func(): ans.call({"yes": true}), PartyUi.YELLOW))
			h.add_child(PartyUi.button("KEEP WALKING", func(): ans.call({"yes": false})))
			modal_box.add_child(h)
		"path":
			_modal_title("WHICH WAY?", "A junction. %d to go." % int(v.turn.steps))
			for o in pr.options:
				var to := int(o.to)
				var txt := str(o.name) + ("" if int(o.toll) == 0 else "  (TOLL: %d TEETH)" % int(o.toll))
				var b := PartyUi.button(txt, func(): ans.call({"to": to}), PartyUi.TURQ if str(o.name) != "THE MAIN ROAD" else PartyUi.CREAM, 600.0, 22)
				b.disabled = not o.can
				modal_box.add_child(b)
				modal_box.add_child(PartyUi.label(str(o.desc), 16, PartyUi.DIM))
		"rat":
			_modal_title("THE DEAD RAT!", "It's yours for %d Teeth (you have %d). Dead Rats win the party." % [int(pr.price), int(me.teeth)])
			var h := PartyUi.hbox(8)
			h.add_child(PartyUi.primary("BUY IT", func(): ans.call({"yes": true})))
			h.add_child(PartyUi.button("NOT NOW", func(): ans.call({"yes": false})))
			modal_box.add_child(h)
		"shop":
			_modal_title(str(pr.get("name", "THE SHOP")), "You have %d Teeth and %d of %d pockets." % [int(me.teeth), me.items.size(), Items.MAX_HELD])
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			for e in pr.get("shelf", []):
				var p := PartyUi.panel(PartyUi.YELLOW.lightened(0.5) if e.special else (PartyUi.PURPLE.lightened(0.6) if e.get("under", false) else Color.WHITE), PartyUi.INK, 16)
				p.custom_minimum_size = Vector2(330, 0) * PartyUi.k()
				var bx := PartyUi.vbox(2)
				bx.add_child(PartyUi.label("%s%s" % [e.name, "  SPECIAL!" if e.special else ""], 20, PartyUi.INK, true))
				bx.add_child(PartyUi.label(str(e.desc), 15))
				bx.add_child(PartyUi.label("%d TEETH   (%d left)   %s" % [int(e.price), int(e.qty), str(e.rarity).to_upper()], 16, PartyUi.BLOOD, true))
				var row := PartyUi.hbox(6)
				var id := str(e.id)
				var bb := PartyUi.button("BUY", func(): ans.call({"buy": id}), PartyUi.MINT, 110.0, 18)
				bb.disabled = not e.can
				row.add_child(bb)
				if str(pr.shop) == "black_market":
					row.add_child(PartyUi.button("STEAL", func(): ans.call({"steal": id}), PartyUi.RED.lightened(0.3), 110.0, 18))
				bx.add_child(row)
				p.add_child(bx)
				grid.add_child(p)
			modal_box.add_child(grid)
			modal_box.add_child(PartyUi.primary("DONE", func(): ans.call({"done": true})))
		"gamble":
			_modal_title("A BET?", "Double or nothing. You have %d Teeth." % int(me.teeth))
			var h := PartyUi.hbox(8)
			for w in pr.options:
				var n := int(w)
				h.add_child(PartyUi.button("%d" % n, func(): ans.call({"wager": n}), PartyUi.YELLOW, 90.0))
			h.add_child(PartyUi.button("NO", func(): ans.call({"wager": 0})))
			modal_box.add_child(h)
		"hidden":
			_modal_title("SOMETHING UNDER THE SQUARE", "Have a look?")
			var h := PartyUi.hbox(8)
			h.add_child(PartyUi.button("LOOK", func(): ans.call({"yes": true}), PartyUi.YELLOW))
			h.add_child(PartyUi.button("LEAVE IT", func(): ans.call({"yes": false})))
			modal_box.add_child(h)
		"poison":
			_modal_title("A DRINK, ON THE HOUSE", "Drink it: %d Teeth, and whatever's in it. Refuse: he notices." % int(pr.get("pay", 6)))
			var h := PartyUi.hbox(8)
			h.add_child(PartyUi.button("DRINK", func(): ans.call({"yes": true}), PartyUi.MINT))
			h.add_child(PartyUi.button("REFUSE", func(): ans.call({"yes": false})))
			modal_box.add_child(h)
		"duel":
			_modal_title("A DUEL!", "Pick who, and what you're both staking.")
			for t in pr.options:
				var tgt := int(t)
				var h := PartyUi.hbox(6)
				h.add_child(PartyUi.label(str(v.players[tgt].name), 20, PartyUi.INK, true))
				for w in pr.get("wagers", [0]):
					var n := int(w)
					h.add_child(PartyUi.button("%d" % n if n > 0 else "FOR NOTHING", func(): ans.call({"target": tgt, "wager": n}), PartyUi.seat_colour(tgt), 90.0, 16))
				modal_box.add_child(h)
		"gavel", "veto":
			_modal_title("PASS A LAW" if pr.kind == "gavel" else "THE VETO", "Choose one.")
			for r in pr.get("rules", []):
				var id := str(r.id)
				modal_box.add_child(PartyUi.button("%s: %s" % [r.name, r.desc], func(): ans.call({"rule": id}), PartyUi.CREAM, 600.0, 18))
			modal_box.add_child(PartyUi.button("NEVER MIND", func(): ans.call({"done": true})))
		"lever":
			_modal_title("THE CONTROL SYSTEM", "Pull a lever.")
			for o in pr.options:
				var g := str(o.gate)
				var val := str(o.value)
				var b := PartyUi.button("%s: %s" % [o.name, o.desc], func(): ans.call({"gate": g, "value": val}), PartyUi.TURQ if not o.now else PartyUi.SILVER, 600.0, 18)
				b.disabled = o.now
				modal_box.add_child(b)
			modal_box.add_child(PartyUi.button("LEAVE IT", func(): ans.call({"done": true})))
		_:
			_modal_title("WHO?")
			for t in pr.get("options", []):
				var tgt := int(t)
				modal_box.add_child(PartyUi.button(str(v.players[tgt].name), func(): ans.call({"target": tgt}), PartyUi.seat_colour(tgt)))


func _ghost_actions(s: int, me: Dictionary, v: Dictionary) -> void:
	if menu_mode in ["haunt", "bless"]:
		for p in v.players:
			if p.alive:
				var tgt := int(p.seat)
				var m := menu_mode
				actions.add_child(PartyUi.button(str(p.name), func():
					menu_mode = ""
					act.emit(s, {"t": "ghost", "do": m, "target": tgt}), PartyUi.seat_colour(tgt)))
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	if menu_mode == "ghost_shop":
		for e in v.get("shelves", {}).get("ghost", []):
			var id := str(e.id)
			var b := PartyUi.button("%s  %d TEETH" % [e.name, int(e.price)], func(): act.emit(s, {"t": "buy", "id": id}), PartyUi.TURQ, 300.0, 16)
			b.tooltip_text = str(e.desc)
			b.disabled = not e.can
			actions.add_child(b)
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	actions.add_child(PartyUi.label("YOU'RE A GHOST", 22, PartyUi.TURQ, true, true))
	var b := PartyUi.primary("COME BACK (1 DEAD RAT)", func(): act.emit(s, {"t": "ghost", "do": "rise"}), 300.0)
	b.disabled = int(me.rats) < 1
	actions.add_child(b)
	for it in me.items:
		if Items.use_of(it) == "ghost":
			var iid := str(it)
			for p in v.players:
				if p.alive and Items.target_of(iid) == "player":
					var tgt := int(p.seat)
					actions.add_child(PartyUi.button("%s: %s" % [Items.name_of(iid), p.name], func(): act.emit(s, {"t": "item", "id": iid, "target": tgt}), PartyUi.TURQ, 280.0, 16))
			if Items.target_of(iid) != "player":
				actions.add_child(PartyUi.button(Items.name_of(iid), func(): act.emit(s, {"t": "item", "id": iid, "choice": "BLESS"}), PartyUi.TURQ, 280.0, 16))
	actions.add_child(PartyUi.button("SCAVENGE FOR TEETH", func(): act.emit(s, {"t": "ghost", "do": "scavenge"})))
	actions.add_child(PartyUi.button("HAUNT SOMEONE", func(): menu_mode = "haunt"))
	actions.add_child(PartyUi.button("PUSH SOMEONE ON", func(): menu_mode = "bless"))
	actions.add_child(PartyUi.button("FLICK THE LIGHTS", func(): act.emit(s, {"t": "ghost", "do": "distract"})))
	actions.add_child(PartyUi.button("THE GHOST SHOP", func(): menu_mode = "ghost_shop", PartyUi.TURQ))


func _ghost_mg_actions(s: int, v: Dictionary) -> void:
	actions.add_child(PartyUi.label("A GHOST CAN CHILL SOMEONE", 18, PartyUi.TURQ, true, true))
	for p in v.players:
		if p.alive and v.mg.get("seats", []).has(int(p.seat)):
			var tgt := int(p.seat)
			actions.add_child(PartyUi.button("CHILL " + str(p.name), func(): act.emit(s, {"t": "ghost", "do": "chill", "target": tgt}), PartyUi.TURQ, 240.0, 18))
			if v.mg.get("arena", false) and v.mg.pos.has(p.seat):
				var at: Vector2 = v.mg.pos[p.seat]
				actions.add_child(PartyUi.button("COLD SPOT ON " + str(p.name), func(): act.emit(s, {"t": "ghost", "do": "cold", "at": at}), PartyUi.TURQ, 240.0, 16))


func _generic_mg_actions(s: int, mg: Dictionary) -> void:
	var cheats: Array = mg.get("cheats", [])
	for c in cheats:
		var id := str(c.id)
		actions.add_child(PartyUi.button("(cheat) " + str(c.name), func(): act.emit(s, {"t": "mg_cheat", "id": id}), PartyUi.SILVER, 260.0, 15))
	# choice games still list their buttons as actions; arena games' buttons are controls
	if mg.get("arena", false) or mg.has("controls") and not (mg.controls as Array).is_empty() and str(mg.controls[0].kind) != "stick" and not mg.has("options"):
		return
	for a in mg.get("actions", []):
		var payload := {"t": "mg"}
		payload.merge(a)
		payload.erase("name")
		var label := str(a.name) + ("  ◀" if a.get("picked", false) else "")
		actions.add_child(PartyUi.primary(label, func(): act.emit(s, payload)) if a.get("primary", false) else PartyUi.button(label, func(): act.emit(s, payload), PartyUi.CREAM, 280.0, 18))


func _roulette_actions(s: int, v: Dictionary) -> void:
	var me: Dictionary = v.players[s]
	var mg: Dictionary = v.mg
	if mg.peeks.has(s):
		actions.add_child(PartyUi.label("YOU PEEKED: " + ("IT'S LOADED" if mg.peeks[s] else "EMPTY"), 20, PartyUi.YELLOW, true, true))
	if menu_mode == "mirror":
		for p in v.players:
			if p.alive and int(p.seat) != s:
				var tgt := int(p.seat)
				actions.add_child(PartyUi.button("AT " + str(p.name), func():
					menu_mode = ""
					act.emit(s, {"t": "mg", "do": "item", "id": "mirror", "target": tgt}), PartyUi.seat_colour(tgt)))
		actions.add_child(PartyUi.button("BACK", func(): menu_mode = ""))
		return
	for it in me.items:
		if Items.use_of(it) == "roulette":
			var iid := str(it)
			if iid == "mirror":
				actions.add_child(PartyUi.button(Items.name_of(iid), func(): menu_mode = "mirror", PartyUi.PURPLE.lightened(0.3)))
			else:
				actions.add_child(PartyUi.button(Items.name_of(iid), func(): act.emit(s, {"t": "mg", "do": "item", "id": iid}), PartyUi.PURPLE.lightened(0.3)))
	for a in mg.get("actions", []):
		if str(a.do) in ["pull", "lower"]:
			continue
		var payload := {"t": "mg"}
		payload.merge(a)
		payload.erase("name")
		actions.add_child(PartyUi.button(str(a.name), func(): act.emit(s, payload), PartyUi.CREAM, 260.0, 16))
	actions.add_child(PartyUi.button("PUT IT DOWN", func(): act.emit(s, {"t": "mg", "do": "lower"}), PartyUi.CREAM, 200.0, 18))
	actions.add_child(PartyUi.primary("PULL THE TRIGGER", func(): act.emit(s, {"t": "mg", "do": "pull"})))


func _potato_actions(h: int, v: Dictionary) -> void:
	var mg: Dictionary = v.mg
	if int(mg.step) == -1:
		actions.add_child(PartyUi.button("FIDDLE WITH IT", func(): act.emit(h, {"t": "mg", "do": "fiddle"})))
	elif str(mg.next) != "":
		var allowed := int(mg.last_doer) != h
		var b := PartyUi.button(str(mg.next) if allowed else "(IT WON'T LET YOU)", func(): act.emit(h, {"t": "mg", "do": "step"}), PartyUi.YELLOW)
		b.disabled = not allowed
		actions.add_child(b)
	for p in v.players:
		if p.alive and int(p.seat) != h:
			var tgt := int(p.seat)
			actions.add_child(PartyUi.button("PASS TO " + str(p.name), func(): act.emit(h, {"t": "mg", "do": "pass", "target": tgt}), PartyUi.seat_colour(tgt)))


# --- a minigame's own controls ------------------------------------------------------------

func _controls_signature(v: Dictionary) -> String:
	if v.phase != "mg_play":
		return "none"
	var me := _me()
	if me < 0 or not v.players[me].alive or not v.mg.get("seats", []).has(me):
		return "none"
	var ctl: Array = v.mg.get("controls", [])
	return str(v.mg_id) + str(ctl.map(func(c): return [c.kind, c.get("do", ""), c.get("options", []), c.get("selected", "")]))


func _controls(v: Dictionary) -> void:
	_clear(controls_box)
	_rings.clear()
	_tracepads.clear()
	_holds.clear()
	_swipes.clear()
	_taps.clear()
	if v.phase != "mg_play":
		return
	var me := _me()
	if me < 0 or not v.mg.get("seats", []).has(me):
		return
	var hints := {"tap": " [SPACE]", "hold": " [SHIFT]", "timing": " [SPACE]"}
	var n_tap := 0
	for c in v.mg.get("controls", []):
		if str(c.kind) == "stick":
			continue
		var hint := ""
		if str(c.kind) == "tap" and n_tap == 0:
			hint = hints.tap
			n_tap += 1
		elif str(c.kind) in ["hold", "timing"]:
			hint = hints[str(c.kind)] if (str(c.kind) == "hold" and _holds.is_empty()) or (str(c.kind) == "timing" and _rings.is_empty()) else ""
		var w := PartyControls.make(c, func(a: Dictionary): act.emit(me, a.merged({"t": "mg"})), hint)
		w.size_flags_vertical = Control.SIZE_SHRINK_END
		controls_box.add_child(w)
		match str(c.kind):
			"timing":
				_rings.append(w)
			"trace":
				_tracepads.append(w)
			"hold":
				_holds.append(w)
			"swipe":
				_swipes.append(w)
			"tap":
				_taps.append(w)


## Keyboard and pad for the minigame controls (GameView forwards input here).
func key_input(ev: InputEvent) -> bool:
	if not (ev is InputEventKey) or ev.echo:
		return false
	var k: int = ev.physical_keycode
	if k == KEY_SPACE and ev.pressed:
		if not _rings.is_empty() and is_instance_valid(_rings[0]):
			_rings[0].tap()
			return true
		if not _taps.is_empty() and is_instance_valid(_taps[0]):
			(_taps[0] as Button).pressed.emit()
			return true
	if k == KEY_SHIFT and not _holds.is_empty() and is_instance_valid(_holds[0]):
		_holds[0].set_held(ev.pressed)
		return true
	if ev.pressed and not _swipes.is_empty() and is_instance_valid(_swipes[0]):
		var d := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN, KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_W: Vector2.UP, KEY_S: Vector2.DOWN}
		if d.has(k):
			_swipes[0].fire(d[k])
			return true
	return false


func _sticks(v: Dictionary) -> void:
	var me := _me()
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var stick_game := false
	if v.phase == "mg_play" and me >= 0 and v.players[me].alive and v.mg.get("seats", []).has(me):
		for c in v.mg.get("controls", []):
			if str(c.kind) == "stick":
				stick_game = true
		if v.mg_id == "musical_chairs":
			stick_game = not v.mg.seated.has(me)
	stick.visible = stick_game and touch
	fp_stick.visible = _away() and touch and str(v.players[me].location) == "away"


# --- the facility ---------------------------------------------------------------------------

func _facility_signature(v: Dictionary) -> String:
	if not _away():
		return "no"
	var me := _me()
	var near: String = get_parent().near_thing() if get_parent() and get_parent().has_method("near_thing") else ""
	var fac: Dictionary = v.get("facility", {})
	var p: Dictionary = v.players[me]
	return "%s|%s|%s|%s|%d|%s" % [near, str(fac.get("things", {}).get(near, {}).get("actions", [])), p.location, str(fac.get("ringing", false)),
		int(float(p.away_limit) - float(p.away_t)), str(get_parent().at_table() if get_parent() and get_parent().has_method("at_table") else false)]


func _facility(v: Dictionary) -> void:
	_clear(facility_box)
	facility_panel.visible = _away()
	if not _away():
		return
	var me := _me()
	var p: Dictionary = v.players[me]
	var fac: Dictionary = v.facility
	var gv = get_parent()
	if str(p.location) == "escaped":
		facility_box.add_child(PartyUi.label("YOU GOT OUT OF THE PARTY.", 24, PartyUi.MINT, true))
		return
	var left := int(float(p.away_limit) - float(p.away_t))
	var area := str(gv.area_name()) if gv and gv.has_method("area_name") else ""
	facility_box.add_child(PartyUi.label(area, 22, PartyUi.YELLOW, true))
	facility_box.add_child(PartyUi.meter(clampf(float(p.away_t) / maxf(1.0, float(p.away_limit)), 0.0, 1.0), PartyUi.RED if left < 10 else PartyUi.ORANGE, 360.0, 22.0,
		"BACK IN %ds" % left if left > 0 else "HE'S NOTICED"))
	# what the board's doing without you
	var cur := int(v.turn.get("seat", -1)) if v.phase == "turn" else -1
	if v.phase == "mg_intro":
		facility_box.add_child(PartyUi.label("A GAME'S ABOUT TO START. GET BACK BEFORE THE COUNTDOWN ENDS!", 18, PartyUi.PINK, true))
	elif cur >= 0:
		var order: Array = v.turn.get("order", [])
		var k := order.find(me)
		var ki := order.find(cur)
		if cur == me:
			facility_box.add_child(PartyUi.label("IT'S YOUR TURN. YOU'RE NOT THERE.", 18, PartyUi.RED, true))
		elif k > ki:
			facility_box.add_child(PartyUi.label("YOUR TURN IN %d." % (k - ki), 18, PartyUi.CREAM, true))
	if fac.get("ringing", false):
		facility_box.add_child(PartyUi.label("Somewhere, a phone is ringing.", 16, PartyUi.TURQ))
	var near: String = gv.near_thing() if gv and gv.has_method("near_thing") else ""
	if near != "":
		var th: Dictionary = fac.things.get(near, {})
		facility_box.add_child(PartyUi.label(str(th.get("name", "")), 20, PartyUi.CREAM, true))
		for a in th.get("actions", []):
			var aid := str(a.id)
			var tid := near
			if a.get("target", false):
				for q in v.players:
					if q.alive and int(q.seat) != me:
						var tgt := int(q.seat)
						facility_box.add_child(PartyUi.button("%s: %s" % [a.name, q.name], func(): act.emit(me, {"t": "interact", "id": tid, "do": aid, "target": tgt}), PartyUi.CREAM, 360.0, 16))
			else:
				var b := PartyUi.button(str(a.name), func(): act.emit(me, {"t": "interact", "id": tid, "do": aid}), PartyUi.YELLOW if aid == "esc_leave" else PartyUi.CREAM, 360.0, 18)
				b.disabled = str(a.get("needs", "")) != "" and not p.items.has(str(a.needs))
				facility_box.add_child(b)
	if gv and gv.has_method("at_table") and gv.at_table():
		facility_box.add_child(PartyUi.primary("SIT DOWN", func(): act.emit(me, {"t": "sit"}), 360.0))
	else:
		facility_box.add_child(PartyUi.label("Walk back to the table to sit down.", 15, PartyUi.DIM))


# --- ORGAN TRAIL's own panel -----------------------------------------------------------------

func _organ_signature(v: Dictionary) -> String:
	if v.phase != "mg_play" or v.mg_id != "organ_trail":
		return "no"
	var mg: Dictionary = v.mg
	var tb: Array = mg.get("tables", [])
	return str(int(mg.get("t", 0.0) * 4.0)) + str(tb.map(func(x): return [x.stage, x.aim, x.clamped, x.order_i, x.warn, x.tool, x.done])) + str(mg.callouts.size())


func _organ(v: Dictionary) -> void:
	_clear(organ_box)
	organ_panel.visible = v.phase == "mg_play" and v.mg_id == "organ_trail"
	if not organ_panel.visible:
		return
	var mg: Dictionary = v.mg
	var mt := int(mg.get("my_team", -1))
	var role := str(mg.get("my_role", ""))
	organ_box.add_child(PartyUi.label("ORGAN TRAIL: %s (%s, %s)" % [mg.organ_name, mg.organ_look, mg.organ_side], 18, PartyUi.YELLOW, true))
	var row := PartyUi.hbox(10)
	for i in 2:
		var st: Dictionary = mg.tables[i]
		var bx := PartyUi.vbox(2)
		bx.add_child(PartyUi.label("TABLE %d%s: %s" % [i + 1, " (YOU)" if i == mt else "", str(st.stage).to_upper()], 15, PartyUi.CREAM, true))
		bx.add_child(PartyUi.meter(float(st.stage_i) / maxf(1.0, (mg.stages as Array).size()), PartyUi.MINT, 290.0, 14.0))
		bx.add_child(PartyUi.label("pain %d  awake %d  panic %d  anaesthetic %d  bleeding %d" % [int(st.pain), int(st.consciousness), int(st.panic), int(st.anaesthetic), int(st.bleed)], 12, PartyUi.CREAM))
		row.add_child(bx)
	organ_box.add_child(row)
	if mt < 0:
		return
	var st: Dictionary = mg.tables[mt]
	if str(st.warn) != "":
		organ_box.add_child(PartyUi.label("!! SOMETHING'S COMING: %s" % str(st.warn).replace("_", " ").to_upper(), 18, PartyUi.RED, true, true))
	if role == "surgeon":
		match str(st.stage):
			"locate":
				for k in st.candidates.size():
					var c: Dictionary = st.candidates[k]
					organ_box.add_child(PartyUi.label("%s: %s, %s" % ["ABCD"[k], c.look, c.side], 15, PartyUi.CREAM))
			"separate":
				organ_box.add_child(PartyUi.label("Connections: %s cut. %s" % [str(st.cut.map(func(x): return x + 1)), "Aiming at %d." % (int(st.aim) + 1) if int(st.aim) >= 0 else ""], 15, PartyUi.CREAM))
			"clamp":
				var vs: Array = mg.vessels
				organ_box.add_child(PartyUi.label("Vessel %d of %d: it's %s." % [int(st.clamped) + 1, vs.size(), str(vs[mini(int(st.clamped), vs.size() - 1)]) if not vs.is_empty() else ""], 15, PartyUi.CREAM))
			"disconnect":
				organ_box.add_child(PartyUi.label("Cut %d of %d. The order's on the chart above the patient." % [int(st.order_i) + 1, int(st.order_len)], 15, PartyUi.CREAM))
			"extract":
				var band: Array = mg.band
				organ_box.add_child(PartyUi.meter(float(st.force) / 100.0, PartyUi.MINT if float(st.force) >= float(band[0]) and float(st.force) <= float(band[1]) else PartyUi.RED, 400.0, 22.0,
					"FORCE: keep it between %d and %d%s" % [int(band[0]), int(band[1]), " (on the out-breath)" if mg.breath else ""]))
		if st.stolen:
			organ_box.add_child(PartyUi.button("FETCH A SPARE INSTRUMENT", func(): act.emit(_me(), {"t": "mg", "do": "spare"}), PartyUi.ORANGE, 300.0, 16))
	elif role == "patient":
		if not (st.nerves as Array).is_empty():
			organ_box.add_child(PartyUi.label("You can feel it: connection%s %s %s a NERVE." % ["s" if st.nerves.size() > 1 else "", ", ".join(st.nerves.map(func(x): return str(x + 1))), "are" if st.nerves.size() > 1 else "is"], 16, PartyUi.YELLOW, true))
		if not (st.order as Array).is_empty():
			organ_box.add_child(PartyUi.label("The chart above you: CUT %s." % "-".join(st.order.map(func(x): return str(x))), 16, PartyUi.YELLOW, true))
		if int(st.aim) >= 0:
			organ_box.add_child(PartyUi.label("They're aiming at connection %d." % (int(st.aim) + 1), 16, PartyUi.CREAM, true))
	for c in (mg.callouts as Array).slice(maxi(0, mg.callouts.size() - 3)):
		organ_box.add_child(PartyUi.label("%s (%s): %s" % [view.players[int(c.seat)].name, "TABLE %d" % (int(c.team) + 1), c.text], 16, PartyUi.PINK, true))


# --- cards: minigame intro, results, finale, ending ---------------------------------------

func _card_signature(v: Dictionary) -> String:
	var phase := str(v.phase)
	match phase:
		"mg_intro":
			return "intro" + str(v.mg_id) + str(int(v.phase_t)) + str(_away())
		"mg_results":
			return "res" + str(v.mg_id) + str(int(float(v.phase_t) * 2.0))
		"finale":
			return "fin" + str(int(float(v.phase_t)))
		"ending":
			return "end" + str(v.ending)
		"intro":
			return "hello"
	return phase


func _cards(v: Dictionary) -> void:
	_clear(card_box)
	card.visible = false
	card.reset_size()
	match str(v.phase):
		"intro":
			card.visible = true
			card_box.add_child(PartyUi.shout("WELCOME TO MURDERLAND!", 44, PartyUi.PINK))
			card_box.add_child(PartyUi.label("%d rounds. Most DEAD RATS wins. Spend your TEETH on anything you like. Everyone's having fun." % int(v.max_rounds), 20))
			if v.mode == "callers_game":
				card_box.add_child(PartyUi.label("THE CALLER'S GAME: he has his own idea of who wins. He'll tell you halfway.", 18, PartyUi.PURPLE, true))
		"mg_intro":
			card.visible = true
			var mg: Dictionary = v.mg
			var e: Dictionary = v.get("mg_entry", {})
			var kind := str(e.get("kind", "main"))
			var head := {"battle": "BATTLE!", "duel": "DUEL!", "bonus": "BONUS GAME!", "special": "SPECIAL EVENT!", "roulette": "ENCOUNTER!"}.get(kind, "MINIGAME!")
			card_box.add_child(PartyUi.shout(head, 30, PartyUi.PINK))
			card_box.add_child(PartyUi.shout(str(mg.title), 46, PartyUi.YELLOW))
			var fmt := str(mg.get("format", "ffa"))
			card_box.add_child(PartyUi.label({"ffa": "EVERYONE FOR THEMSELVES", "2v2": "TWO AGAINST TWO", "1v3": "ONE AGAINST THE REST", "duel": "ONE ON ONE", "coop": "ALL OF YOU, TOGETHER", "special": "AN ENCOUNTER"}.get(fmt, fmt), 20, PartyUi.INK, true))
			if not (mg.get("teams", []) as Array).is_empty():
				var tl := []
				for tm in mg.teams:
					tl.append(" + ".join((tm as Array).map(func(s): return str(v.players[int(s)].name))))
				card_box.add_child(PartyUi.label("  VS  ".join(tl), 18, PartyUi.BLOOD, true))
			if int(e.get("pool", 0)) > 0:
				card_box.add_child(PartyUi.label("THE POT: %d TEETH (%s). Winner takes it." % [int(e.pool), {"fixed": "5 each", "percent": "a fifth of everyone's Teeth", "double": "half of everything you've got"}.get(str(e.get("wager_rule", "")), "the stakes")], 18, PartyUi.BLOOD, true))
			if e.get("rat_prize", false):
				card_box.add_child(PartyUi.label("AND A DEAD RAT FOR THE WINNER.", 18, PartyUi.BLOOD, true))
			if v.get("presentation", "MEAT_PUPPET") == "FULL_CHARACTER":
				card_box.add_child(PartyUi.label("YOU'LL BE DOING THIS ONE YOURSELVES. IN PERSON.", 16, PartyUi.PURPLE, true))
			for line in mg.instructions:
				card_box.add_child(PartyUi.label("• " + str(line), 18))
			if v.mg_id == "organ_trail" and not (mg.get("modifier_text", []) as Array).is_empty():
				for m in mg.modifier_text:
					card_box.add_child(PartyUi.label("THE CALLER'S RULE: " + str(m), 16, PartyUi.PURPLE, true))
			var left := maxi(0, int(MatchCore.MG_INTRO_TIME - float(v.phase_t)))
			card_box.add_child(PartyUi.shout("STARTS IN %d" % left, 30, PartyUi.TURQ))
			if _away():
				card_box.add_child(PartyUi.label("YOU'RE NOT AT THE TABLE. GET BACK NOW OR MISS IT.", 18, PartyUi.RED, true))
		"mg_results":
			card.visible = true
			_results(v)
		"finale":
			card.visible = true
			_finale(v)
		"ending":
			card.visible = true
			_ending(v)


## Mario-style: FINISH! (freeze) -> who won (reveal) -> Teeth counting up (rewards) -> back to the board.
func _results(v: Dictionary) -> void:
	var r: Dictionary = v.get("last_results", {})
	var t := float(v.phase_t)
	card_box.add_child(PartyUi.shout("FINISH!" if t < 1.2 else str(view.mg.get("title", "")), 44, PartyUi.YELLOW))
	if t < 1.2:
		return
	var ws: Array = r.get("winners", [])
	if r.get("draw", false):
		card_box.add_child(PartyUi.shout("A DRAW!", 40, PartyUi.TURQ))
		if str(view.mg.get("format", "")) == "ffa":
			card_box.add_child(PartyUi.label("Every free-for-all draw brings the dead back, and everyone alive pays for it with a part of themselves.", 18, PartyUi.BLOOD, true))
	elif ws.is_empty():
		card_box.add_child(PartyUi.shout("NOBODY WINS!", 40, PartyUi.RED))
	else:
		card_box.add_child(PartyUi.shout("%s WIN%s!" % [" & ".join(ws.map(func(s): return str(view.players[int(s)].name))), "" if ws.size() > 1 else "S"], 38, PartyUi.PINK))
	if t < 2.4:
		return
	var pay: Dictionary = r.get("pay", {})
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	var pl: Array = r.get("placings", [])
	var place := 1
	var places := {}
	for g in pl:
		for s in g:
			places[int(s)] = place
		place += (g as Array).size()
	var k := clampf((t - 2.4) / 1.2, 0.0, 1.0)
	for p in view.players:
		var s := int(p.seat)
		if not pay.has(s) and not pay.has(str(s)):
			continue
		var n := int(pay.get(s, pay.get(str(s), 0)))
		grid.add_child(PartyUi.label(["", "1ST", "2ND", "3RD", "4TH"][mini(4, int(places.get(s, 4)))], 22, PartyUi.BLOOD, true))
		grid.add_child(PartyUi.label(str(p.name) + ("" if p.alive else " (DEAD)"), 22, PartyUi.INK, true))
		grid.add_child(PartyUi.label("%+d TEETH" % int(round(n * k)), 22, PartyUi.MINT.darkened(0.3) if n >= 0 else PartyUi.RED, true))
	card_box.add_child(grid)
	if int(r.get("pool", 0)) > 0 and not (r.get("pool_to", []) as Array).is_empty():
		card_box.add_child(PartyUi.label("THE POT (%d) GOES TO %s." % [int(r.pool), ", ".join(r.pool_to.map(func(s): return str(view.players[int(s)].name)))], 18, PartyUi.BLOOD, true))
	for n in r.get("summary", []):
		card_box.add_child(PartyUi.label(str(n), 16))


func _finale(v: Dictionary) -> void:
	var f: Dictionary = v.get("finale", {})
	var t := float(v.phase_t)
	card_box.add_child(PartyUi.shout("THE CALLER'S AWARDS!", 42, PartyUi.PINK))
	var aw: Array = f.get("awards", [])
	var shown := mini(aw.size(), int(t / 2.5) + 1)
	for i in shown:
		var a: Dictionary = aw[i]
		card_box.add_child(PartyUi.label("%s: %s" % [a.name, a.desc], 22, PartyUi.INK, true))
		card_box.add_child(PartyUi.label("→ %s  (+%d DEAD RAT%s)" % [", ".join(a.seats.map(func(s): return str(v.players[int(s)].name))), int(a.rats), "" if int(a.rats) == 1 else "S"], 20, PartyUi.BLOOD, true))
	if t > 2.5 * aw.size() + 1.0:
		for o in f.get("objectives", []):
			card_box.add_child(PartyUi.label("THE CALLER'S GAME, %s: %s" % [o.name, ", ".join(o.seats.map(func(s): return str(v.players[int(s)].name)))], 18, PartyUi.PURPLE, true))
		_standings(f.get("standings", []))


func _standings(st: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	for x in st:
		grid.add_child(PartyUi.label("%d." % int(x.place), 24, PartyUi.BLOOD, true))
		grid.add_child(PartyUi.label(str(x.name) + ("" if x.alive else " (GHOST)"), 24, PartyUi.INK, true))
		grid.add_child(PartyUi.label("%d DEAD RATS" % int(x.rats), 22, PartyUi.INK, true))
		grid.add_child(PartyUi.label("%d TEETH" % int(x.teeth), 20, PartyUi.DIM, true))
	card_box.add_child(grid)


func _ending(v: Dictionary) -> void:
	var info_d: Dictionary = v.ending_info
	var kind := str(v.ending)
	match kind:
		"escape":
			card_box.add_child(PartyUi.shout("THEY ESCAPED THE PARTY!", 40, PartyUi.MINT))
			card_box.add_child(PartyUi.label("Out: %s. Everyone else stayed for cake." % ", ".join(info_d.get("winners", []).map(func(s): return str(v.players[int(s)].name))), 20))
		"dead":
			card_box.add_child(PartyUi.shout("NOBODY LEFT ALIVE", 40, PartyUi.RED))
			card_box.add_child(PartyUi.label("The party goes on without you. It always does.", 20))
		_:
			var w: Array = info_d.get("winners", [])
			card_box.add_child(PartyUi.shout("%s WIN%s THE PARTY!" % [" & ".join(w.map(func(s): return str(v.players[int(s)].name))), "" if w.size() > 1 else "S"], 40, PartyUi.YELLOW))
	_standings(info_d.get("standings", []))
	# the match in numbers
	var stats := []
	for x in info_d.get("standings", []):
		var s: Dictionary = x.get("stats", {})
		stats.append("%s: %d minigame wins, %d deaths, %d Teeth earned, %d spent, %d squares walked" % [x.name, int(s.get("minigame_wins", 0)), int(x.deaths), int(s.get("teeth_earned", 0)), int(s.get("teeth_spent", 0)), int(s.get("spaces_moved", 0))])
	for line in stats:
		card_box.add_child(PartyUi.label(line, 15, PartyUi.DIM))
	var h := PartyUi.hbox(8)
	if Net.is_authority():
		h.add_child(PartyUi.primary("PLAY AGAIN", func(): lobby_pressed.emit()))
	h.add_child(PartyUi.button("MAIN MENU", func(): leave_pressed.emit()))
	card_box.add_child(h)


# --- the cutscene, the menu -------------------------------------------------------------------

func _cutscene(v: Dictionary) -> void:
	var cs: Dictionary = v.get("cutscene", {})
	var on := not cs.is_empty()
	for b in letterbox:
		(b as ColorRect).visible = on
	cutscene_lbl.visible = on
	if on:
		var tgt := int(cs.target)
		cutscene_lbl.text = "EVERYBODY WATCH: %s" % (str(v.players[tgt].name) if tgt >= 0 and tgt < v.players.size() else "")


func _toggle_menu() -> void:
	_menu_open = not _menu_open
	if not _menu_open:
		modal.visible = false
		_sig.erase("actions")
		return
	modal.visible = true
	_clear(modal_box)
	_modal_title("MENU")
	var toggles := [["REDUCED EFFECTS", "reduced_fx"], ["REDUCED GORE", "reduced_gore"], ["LEFT-HANDED", "left_handed"], ["SCREEN SHAKE", "screen_shake"]]
	for tg in toggles:
		var key: String = tg[1]
		var on := bool(Settings.get_v(key, false))
		modal_box.add_child(PartyUi.button("%s: %s" % [tg[0], "ON" if on else "OFF"], func():
			Settings.set_v(key, not bool(Settings.get_v(key, false)))
			_menu_open = false
			_toggle_menu(), PartyUi.MINT if on else PartyUi.CREAM, 420.0, 20))
	var h := PartyUi.hbox(8)
	for lbl in [["UI SMALLER", -0.1], ["UI BIGGER", 0.1]]:
		var d: float = lbl[1]
		h.add_child(PartyUi.button(lbl[0], func(): Settings.set_v("ui_scale", clampf(float(Settings.get_v("ui_scale", 1.0)) + d, 0.7, 1.6)), PartyUi.CREAM, 200.0, 18))
	modal_box.add_child(h)
	var h2 := PartyUi.hbox(8)
	for lbl in [["TEXT SMALLER", -0.1], ["TEXT BIGGER", 0.1]]:
		var d: float = lbl[1]
		h2.add_child(PartyUi.button(lbl[0], func(): Settings.set_v("text_size", clampf(float(Settings.get_v("text_size", 1.0)) + d, 0.7, 1.8)), PartyUi.CREAM, 200.0, 18))
	modal_box.add_child(h2)
	modal_box.add_child(PartyUi.button("LEAVE THE MATCH", func(): leave_pressed.emit(), PartyUi.RED.lightened(0.3), 420.0, 20))
	modal_box.add_child(PartyUi.primary("BACK TO THE PARTY", func(): _toggle_menu()))


func say(text: String) -> void:
	_typing = text
	_typed = 0.0


func toast(text: String, private := false) -> void:
	var p := PartyUi.panel(Color(0.12, 0.05, 0.12, 0.9) if not private else Color(0.25, 0.1, 0.3, 0.92), PartyUi.YELLOW if private else PartyUi.PINK, 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := PartyUi.label(text, 18, PartyUi.CREAM if not private else PartyUi.YELLOW)
	l.custom_minimum_size = Vector2(560, 0) * PartyUi.k()
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		var c := toast_box.get_child(0)
		toast_box.remove_child(c)
		c.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(6.0 if private else 4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
