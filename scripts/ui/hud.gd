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
var modal_scroll: ScrollContainer
var card_scroll: ScrollContainer
var modal_footer: HBoxContainer
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
	var mcol := PartyUi.vbox(8)
	modal.add_child(mcol)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.custom_minimum_size = Vector2(700, 120)
	mcol.add_child(modal_scroll)
	modal_box = PartyUi.vbox(10)
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_scroll.add_child(modal_box)
	# always on screen, never scrolled away: DONE / BACK live here
	modal_footer = PartyUi.hbox(10)
	modal_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	mcol.add_child(modal_footer)
	modal_box.resized.connect(_fit_modal)
	modal.visibility_changed.connect(_fit_modal)
	card = PartyUi.panel(PartyUi.CREAM, PartyUi.INK, 30)
	card.visible = false
	root.add_child(card)
	card_scroll = ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(card_scroll)
	card_box = PartyUi.vbox(8)
	card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.custom_minimum_size = Vector2(760, 0)
	card_scroll.add_child(card_box)
	card_box.resized.connect(_fit_card)
	card.visibility_changed.connect(_fit_card)
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
	# the presentation's own captions (the arena's name...) and the 3-2-1-GO
	stage_lbl = PartyUi.shout("", 44, PartyUi.YELLOW)
	stage_lbl.visible = false
	root.add_child(stage_lbl)
	# the turn's panel (whose turn: their Teeth, Dead Rats, pockets) and the landing's (what that square is)
	info_panel = PartyUi.panel(PartyUi.CREAM, PartyUi.INK, 16)
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info_panel)
	info_box = PartyUi.vbox(4)
	info_panel.add_child(info_box)
	# the flow debug overlay (--flow-debug / --flow-step)
	debug_lbl = PartyUi.label("", 14, PartyUi.MINT, false, true)
	debug_lbl.visible = OS.get_cmdline_user_args().has("--flow-debug") or OS.get_cmdline_user_args().has("--flow-step")
	root.add_child(debug_lbl)
	step_btn = PartyUi.button("NEXT STAGE ▶", func(): act.emit(_me(), {"t": "flow_next"}), PartyUi.MINT, 200.0, 16)
	step_btn.visible = false
	root.add_child(step_btn)
	countdown_lbl = PartyUi.shout("", 200, PartyUi.YELLOW)
	countdown_lbl.visible = false
	countdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(countdown_lbl)
	look_btn = PartyUi.button("LOOK UP", func(): look_toggled.emit(), PartyUi.TURQ, 150.0, 20)
	root.add_child(look_btn)
	root.move_child(top, -1)   # the menu button stays tappable over any panel
	Ui.changed.connect(_layout)
	Ui.tip.connect(func(t): toast(t, true))
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
	_fit_modal.call_deferred()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	(letterbox[0] as ColorRect).position = Vector2.ZERO
	(letterbox[0] as ColorRect).size = Vector2(vp.x, vp.y * 0.12)
	(letterbox[1] as ColorRect).position = Vector2(0, vp.y * 0.88)
	(letterbox[1] as ColorRect).size = Vector2(vp.x, vp.y * 0.12)
	cutscene_lbl.position = Vector2(0, vp.y * 0.89)
	cutscene_lbl.size = Vector2(vp.x, vp.y * 0.1)
	info_panel.position = Vector2(vp.x * 0.5 - 260 * PartyUi.k(), vp.y * 0.62)
	info_panel.custom_minimum_size = Vector2(520, 0) * PartyUi.k()
	debug_lbl.position = Vector2(vp.x * 0.3, m.position.y + 4)
	step_btn.position = Vector2(vp.x * 0.5 - 100, m.position.y + 40)
	stage_lbl.position = Vector2(0, vp.y * 0.78)
	stage_lbl.size = Vector2(vp.x, vp.y * 0.14)
	countdown_lbl.position = Vector2(0, vp.y * 0.25)
	countdown_lbl.size = Vector2(vp.x, vp.y * 0.5)
	countdown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	look_btn.position = Vector2(m.position.x, vp.y - m.size.y - 70 * PartyUi.bk()) if right else Vector2(vp.x - m.size.x - 160, vp.y - m.size.y - 70 * PartyUi.bk())


## The action column sits above the minigame controls when there are any, never over them.
func _stack_actions() -> void:
	var vp := root.get_viewport_rect().size
	var m: Rect2 = Ui.margins
	var need := actions.get_combined_minimum_size()
	var h := maxf(need.y, 10.0)
	var bottom := vp.y - m.size.y
	var ctl_h := 0.0
	for c in controls_box.get_children():
		if c is Control and (c as Control).visible:
			ctl_h = maxf(ctl_h, (c as Control).get_combined_minimum_size().y)
	if ctl_h > 0.0:
		bottom = vp.y - m.size.y - ctl_h - 12.0
	actions.size = Vector2(maxf(need.x, 360.0 * PartyUi.bk()), h)
	var right := not Ui.left_handed
	actions.position = Vector2(vp.x - m.size.x - actions.size.x if right else m.position.x, bottom - h)


func _corner(c: Control, right: bool, sz: Vector2, m: Rect2) -> void:
	var vp := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1280, 720)
	c.size = sz
	c.position = Vector2(vp.x - m.size.x - sz.x if right else m.position.x, vp.y - m.size.y - sz.y)


func _card_ui(i: int) -> Dictionary:
	var p := PartyUi.panel(PartyUi.CREAM.lerp(PartyUi.seat_colour(i), 0.3), PartyUi.INK, 16)
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
	var teeth := PartyUi.chip("0 TEETH", PartyUi.CREAM, 16)
	var rats := PartyUi.chip("0 DEAD RATS", PartyUi.YELLOW, 16)
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
	_stack_actions.call_deferred()
	_stage_overlay(v)
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


## The card (instructions, results...) fits its content up to most of the screen, centred.
func _fit_card() -> void:
	if not card or not card.visible or not root.is_inside_tree():
		return
	var vp := root.get_viewport_rect().size
	var want := card_box.get_combined_minimum_size()
	card_scroll.custom_minimum_size = Vector2(minf(want.x, vp.x - 100.0), minf(want.y, vp.y * 0.86 - 70.0))
	card.reset_size()
	card.position = ((vp - card.size) * 0.5).floor()


## The modal fits its content up to most of the screen, centred; past that it scrolls.
func _fit_modal() -> void:
	if not modal or not modal.visible or not root.is_inside_tree():
		return
	var vp := root.get_viewport_rect().size
	var want := modal_box.get_combined_minimum_size()
	var footer_h := modal_footer.get_combined_minimum_size().y if modal_footer.get_child_count() > 0 else 0.0
	modal_scroll.custom_minimum_size = Vector2(minf(maxf(want.x, 700.0), vp.x - 120.0), minf(want.y, vp.y * 0.78 - footer_h - 60.0))
	modal.reset_size()
	modal.position = ((vp - modal.size) * 0.5).floor()


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _actions(v: Dictionary) -> void:
	_clear(actions)
	if _menu_open:
		return     # the menu has the modal; the actions wait till it's closed
	modal.visible = false
	var phase := str(v.phase)
	var me := _me()
	if phase == "mg_intro":
		return   # READY lives on the HOW TO PLAY card
	if phase in ["intro", "mg_results", "finale"]:
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
	var lbl := {"low": "ROLL (1-4)", "high": "ROLL (6-9)", "d10": "ROLL THE D10", "double": "ROLL TWICE", "loaded_double": "ROLL TWO DICE", "six": "ROLL (it's loaded)"}.get(nr, "ROLL (1-%d)" % dmax)
	actions.add_child(PartyUi.primary(lbl, func(): act.emit(s, {"t": "roll"}), 300.0))


func _modal_title(text: String, sub := "") -> void:
	modal_box.add_child(PartyUi.label(text, 30, PartyUi.INK, true))
	if sub != "":
		modal_box.add_child(PartyUi.label(sub, 18, PartyUi.INK))


func _prompt(s: int, pr: Dictionary, v: Dictionary) -> void:
	modal.visible = true
	_clear(modal_box)
	_clear(modal_footer)
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
			grid.columns = 3 if root.get_viewport_rect().size.x > 1500 else 2
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
			modal_footer.add_child(PartyUi.primary("DONE", func(): ans.call({"done": true})))
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
	var counts := {}
	for c in v.mg.get("controls", []):
		if str(c.kind) == "stick":
			continue
		var kd := str(c.kind)
		var n := int(counts.get(kd, 0))
		counts[kd] = n + 1
		# the key/button it answers to, on a keyboard or pad (touch: the button itself)
		var hint := "" if Ui.device == "touch" or not kd in ["tap", "hold", "timing"] else " [%s]" % Ui.control_binding(kd, n).replace("hold ", "")
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


## Keyboard and controller for the minigame controls (GameView forwards input here). It
## answers to the input actions (UiManager.ACTIONS), the same ones the instruction screens
## show, so what's on the screen is what works.
func key_input(ev: InputEvent) -> bool:
	if not (ev is InputEventKey or ev is InputEventJoypadButton) or (ev is InputEventKey and ev.echo):
		return false
	# the timing ring comes first on the main button
	if ev.is_action_pressed("mg_timing") and not _rings.is_empty() and is_instance_valid(_rings[0]):
		_rings[0].tap()
		return true
	var taps := ["mg_tap", "mg_tap2", "mg_tap3"]
	for i in taps.size():
		if ev.is_action_pressed(taps[i]) and i < _taps.size() and is_instance_valid(_taps[i]):
			(_taps[i] as Button).pressed.emit()
			return true
	var holds := ["mg_hold", "mg_hold2"]
	for i in holds.size():
		if (ev.is_action_pressed(holds[i]) or ev.is_action_released(holds[i])) and i < _holds.size() and is_instance_valid(_holds[i]):
			_holds[i].set_held(ev.is_pressed())
			return true
	if not _swipes.is_empty() and is_instance_valid(_swipes[0]):
		for d in [["mg_swipe_left", Vector2.LEFT], ["mg_swipe_right", Vector2.RIGHT], ["mg_swipe_up", Vector2.UP], ["mg_swipe_down", Vector2.DOWN]]:
			if ev.is_action_pressed(d[0]):
				_swipes[0].fire(d[1])
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
	var se: Dictionary = v.get("search", {})
	return "%s|%d|%s|%s|%s|%s|%s|%s|%d|%s" % [str(se.get("stage", "")), int(float(se.get("t", 0.0))), str(se.get("left", "")), str(se.get("mine", [])), near, str(fac.get("things", {}).get(near, {}).get("actions", [])), p.location, str(fac.get("ringing", false)),
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
	var se: Dictionary = v.get("search", {})
	if se.get("active", false) and str(se.stage) == "search":
		facility_box.add_child(PartyUi.label("SEARCH THE ROOM!", 26, PartyUi.YELLOW, true))
		var tl := maxi(0, int(float(se.limit) - float(se.t)))
		facility_box.add_child(PartyUi.meter(clampf(float(se.t) / float(se.limit), 0.0, 1.0), PartyUi.RED if tl < 10 else PartyUi.ORANGE, 360.0, 22.0, "%ds LEFT" % tl))
		facility_box.add_child(PartyUi.label("Scraps of paper, somewhere in here. Walk over one to pick it up. Most found wins %d Teeth." % SearchEvent.RACE_PRIZE, 16, PartyUi.CREAM))
		facility_box.add_child(PartyUi.label("STILL OUT THERE: %d of %d" % [int(se.left), int(se.total)], 18, PartyUi.CREAM, true))
		var mine: Array = se.get("mine", [])
		if not mine.is_empty():
			facility_box.add_child(PartyUi.label("YOURS: " + "  /  ".join(mine.map(func(w): return "\"%s\"" % w)), 18, PartyUi.MINT, true))
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
			var pz: Dictionary = v.get("presenter", {})
			return "intro" + str(v.mg_id) + str(pz.get("stage", "")) + str(pz.get("confirmed", [])) + str(_away()) + str(_practice) + str(Ui.device) + (str(int(float(pz.get("t", 0)) * 4)) if str(pz.get("stage", "")) == "countdown" else "")
		"mg_results":
			var pr: Dictionary = v.get("presenter", {})
			return "res" + str(v.mg_id) + str(pr.get("stage", "")) + str(int(float(pr.get("t", 0)) * 2.0))
		"mg_return":
			return "ret"
		"finale":
			return "fin" + str(int(float(v.phase_t)))
		"ending":
			return "end" + str(v.ending)
		"intro":
			return "hello"
		"search":
			var se: Dictionary = v.get("search", {})
			return "search" + str(se.get("stage", "")) + str(se.get("chose", false)) + str(se.get("chosen", [])) + str(se.get("result", {}).size())
	return phase


func _cards(v: Dictionary) -> void:
	_clear(card_box)
	card.visible = false
	card.reset_size()
	match str(v.phase):
		"search":
			_search_card(v)
		"intro":
			card.visible = true
			card_box.add_child(PartyUi.shout("WELCOME TO MURDERLAND!", 44, PartyUi.PINK))
			card_box.add_child(PartyUi.label("%d rounds. Most DEAD RATS wins. Spend your TEETH on anything you like. Everyone's having fun." % int(v.max_rounds), 20))
			if v.mode == "callers_game":
				card_box.add_child(PartyUi.label("THE CALLER'S GAME: he has his own idea of who wins. He'll tell you halfway.", 18, PartyUi.PURPLE, true))
		"mg_intro":
			_present(v)
		"mg_results":
			card.visible = true
			_results(v)
		"mg_return":
			card.visible = true
			card_box.add_child(PartyUi.shout("BACK TO THE BOARD...", 40, PartyUi.CREAM))
		"finale":
			card.visible = true
			_finale(v)
		"ending":
			card.visible = true
			_ending(v)


## Mario-style: FINISH! (freeze) -> who won (reveal) -> Teeth counting up (rewards) -> back to the board.
func _results(v: Dictionary) -> void:
	var r: Dictionary = v.get("last_results", {})
	var pst: Dictionary = v.get("presenter", {})
	# play_freeze: FINISH!  results: who won, the placings.  rewards: the Teeth count up.
	var t := {"play_freeze": 0.5, "results": 2.0}.get(str(pst.get("stage", "")), 2.4 + float(pst.get("t", 0.0)))
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
	_nowrap(grid)
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
		for l in [PartyUi.label("%d." % int(x.place), 24, PartyUi.BLOOD, true), PartyUi.label(str(x.name) + ("" if x.alive else " (GHOST)"), 24, PartyUi.INK, true),
				PartyUi.label("%d DEAD RATS" % int(x.rats), 22, PartyUi.INK, true), PartyUi.label("%d TEETH" % int(x.teeth), 20, PartyUi.DIM, true)]:
			(l as Label).autowrap_mode = TextServer.AUTOWRAP_OFF   # a grid cell has no width to wrap in
			grid.add_child(l)
	_nowrap(grid)
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
	Net.paused = _menu_open and Net.role == "offline"
	get_tree().paused = false
	if not _menu_open:
		modal.visible = false
		_sig.erase("actions")
		return
	modal.visible = true
	_clear(modal_box)
	_clear(modal_footer)
	_modal_title("PAUSED" if Net.role == "offline" else "MENU", "" if Net.role == "offline" else "(an online match carries on without you)")
	var toggles := [["REDUCED EFFECTS", "reduced_fx"], ["REDUCED GORE", "reduced_gore"], ["LEFT-HANDED", "left_handed"], ["SCREEN SHAKE", "screen_shake"],
		["VIBRATION", "vibration"], ["BATTERY SAVER", "battery_saver"]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for tg in toggles:
		var key: String = tg[1]
		var on := bool(Settings.get_v(key, key in ["screen_shake", "vibration"]))
		grid.add_child(PartyUi.button("%s: %s" % [tg[0], "ON" if on else "OFF"], func():
			Settings.set_v(key, not bool(Settings.get_v(key, key in ["screen_shake", "vibration"])))
			_menu_open = false
			_toggle_menu(), PartyUi.MINT if on else PartyUi.CREAM, 260.0, 18))
	modal_box.add_child(grid)
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
	# always on screen: the footer never scrolls away
	modal_footer.add_child(PartyUi.button("LEAVE THE MATCH", func(): leave_pressed.emit(), PartyUi.RED.lightened(0.3), 240.0, 18))
	modal_footer.add_child(PartyUi.primary("BACK TO THE PARTY", func(): _toggle_menu(), 260.0))


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


## A big inked banner slammed across the middle: whose turn it is, the round, a death.
## Queued, so two at once play one after the other (and a long queue is cut short).
var _banners: Array = []
var _banner_running := false
func banner(text: String, col := PartyUi.YELLOW, hold := 1.5) -> void:
	_banners.append([text, col, hold])
	if _banners.size() > 3:
		_banners.pop_front()
	if _banner_running:
		return
	_banner_running = true
	while not _banners.is_empty():
		var b: Array = _banners.pop_front()
		await _show_banner(b[0], b[1], b[2] * (0.6 if not _banners.is_empty() else 1.0))
	_banner_running = false


func _show_banner(text: String, col: Color, hold: float) -> void:
	var p := PartyUi.panel(col.lerp(PartyUi.CREAM, 0.15), PartyUi.INK, 18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := PartyUi.label(text, 54, PartyUi.INK if col.get_luminance() > 0.4 else PartyUi.CREAM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	root.add_child(p)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var vp := root.get_viewport_rect().size
	# the upper third: never on top of what it's announcing (that's in the middle)
	p.position = Vector2((vp.x - p.size.x) * 0.5, vp.y * 0.13)
	p.pivot_offset = p.size * 0.5
	p.rotation = -0.03
	p.scale = Vector2(0.9, 0.9)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(p, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(p.queue_free)
	await tw.finished



# --- THE MINIGAME PRESENTATION: one screen per stage (MinigamePresenter) ----------------------

var _practice := false
var _practice_log: Label
var _practice_dot: Control
var _practice_stick: TouchStick
var countdown_lbl: Label
var stage_lbl: Label
var info_panel: PanelContainer
var info_box: VBoxContainer
var _info_sig := ""
var debug_lbl: Label
var step_btn: Button
var _last_count := ""

const CONTROL_HELP := {
	"stick": "MOVE", "tap": "PRESS", "hold": "HOLD", "swipe": "SWIPE", "timing": "ON THE BEAT",
	"trace": "TRACE", "pick": "PICK", "buttons": "CHOOSE",
}
const CATEGORY_COLOUR := {"FREE-FOR-ALL": PartyUi.YELLOW, "2 VS 2": PartyUi.TURQ, "1 VS 3": PartyUi.ORANGE, "DUEL": PartyUi.RED,
	"CO-OP": PartyUi.MINT, "SPECIAL EVENT": PartyUi.PURPLE, "ENCOUNTER": PartyUi.BLOOD}


func _present(v: Dictionary) -> void:
	var pz: Dictionary = v.get("presenter", {})
	var stage := str(pz.get("stage", ""))
	var rg: Dictionary = v.get("registration", {})
	var mg: Dictionary = v.mg
	var e: Dictionary = v.get("mg_entry", {})
	var cat := str(rg.get("category", "MINIGAME"))
	var cc: Color = CATEGORY_COLOUR.get(cat, PartyUi.YELLOW)
	match stage:
		"board_freeze":
			pass    # the board stops; the camera leaves it
		"selection":
			card.visible = true
			var kind := str(e.get("kind", "main"))
			card_box.add_child(PartyUi.shout({"battle": "BATTLE MINIGAME!", "duel": "DUEL!", "bonus": "BONUS GAME!", "special": "SPECIAL EVENT!", "roulette": "AN ENCOUNTER!"}.get(kind, "MINIGAME TIME!"), 52, PartyUi.PINK))
			var chip := PartyUi.chip(cat, cc, 34)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_box.add_child(chip)
		"title":
			card.visible = true
			var chip2 := PartyUi.chip(cat, cc, 20)
			chip2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_box.add_child(chip2)
			card_box.add_child(PartyUi.shout(str(rg.get("name", mg.get("title", ""))), 58, PartyUi.YELLOW))
			var d := PartyUi.label(str(rg.get("description", "")), 24, PartyUi.INK, true)
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_box.add_child(d)
		"arena_preview", "arena_intro":
			card.visible = false
		"teams":
			card.visible = true
			card_box.add_child(PartyUi.shout("WHO'S PLAYING", 40, PartyUi.PINK))
			var teams: Array = mg.get("teams", [])
			var seats: Array = mg.get("seats", [])
			var row := PartyUi.hbox(18)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			if teams.is_empty():
				for s2 in seats:
					row.add_child(_player_card(int(s2), v))
			else:
				for ti in teams.size():
					var col := PartyUi.vbox(6)
					col.add_child(PartyUi.label(["TEAM 1", "TEAM 2", "TEAM 3"][mini(ti, 2)] if (teams[ti] as Array).size() > 1 or cat != "1 VS 3" else "ON THEIR OWN", 22, PartyUi.BLOOD, true))
					for s3 in teams[ti]:
						col.add_child(_player_card(int(s3), v))
					row.add_child(col)
					if ti < teams.size() - 1:
						row.add_child(PartyUi.shout("VS", 40, PartyUi.RED))
			card_box.add_child(row)
			if int(e.get("pool", 0)) > 0:
				card_box.add_child(PartyUi.label("THE POT: %d TEETH. Winner takes it." % int(e.pool), 20, PartyUi.BLOOD, true))
			if e.get("rat_prize", false):
				card_box.add_child(PartyUi.label("AND A DEAD RAT FOR THE WINNER.", 20, PartyUi.BLOOD, true))
			if v.get("presentation", "MEAT_PUPPET") == "FULL_CHARACTER":
				card_box.add_child(PartyUi.label("YOU'LL BE DOING THIS ONE YOURSELVES. IN PERSON.", 18, PartyUi.PURPLE, true))
		"instructions":
			card.visible = true
			card_box.add_child(PartyUi.label(str(rg.get("name", "")), 22, PartyUi.DIM, true))
			card_box.add_child(PartyUi.shout("HOW TO PLAY", 46, PartyUi.RED))
			for line in rg.get("instructions", mg.get("instructions", [])):
				card_box.add_child(PartyUi.label("• " + str(line), 22))
			if v.mg_id == "organ_trail":
				for m in mg.get("modifier_text", []):
					card_box.add_child(PartyUi.label("THE CALLER'S RULE: " + str(m), 18, PartyUi.PURPLE, true))
			_confirm_row(v, pz, "NEXT", "mg_next")
		"controls":
			card.visible = true
			card_box.add_child(PartyUi.label(str(rg.get("name", "")), 22, PartyUi.DIM, true))
			card_box.add_child(PartyUi.shout("CONTROLS", 46, PartyUi.RED))
			card_box.add_child(PartyUi.label({"touch": "ON THE TOUCH SCREEN", "keyboard": "ON THE KEYBOARD", "pad": "ON THE CONTROLLER"}.get(Ui.device, ""), 16, PartyUi.DIM, true))
			_control_diagram(rg)
			if _practice:
				_practice_area(mg)
			_confirm_row(v, pz, "READY!", "ready", true)
		"positioning", "countdown":
			card.visible = false
	if _away():
		card_box.add_child(PartyUi.label("YOU'RE NOT AT THE TABLE. GET BACK NOW OR MISS IT.", 18, PartyUi.RED, true))


func _player_card(s: int, v: Dictionary) -> Control:
	var p: Dictionary = v.players[s]
	var pc := PartyUi.panel(PartyUi.CREAM.lerp(PartyUi.seat_colour(s), 0.45), PartyUi.INK, 16)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := PartyUi.label(str(p.name) + (" (YOU)" if local.has(s) else ""), 24, PartyUi.INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pc.add_child(l)
	return pc


## One row per control: what it does, and how it's worked on your device (read from the
## real bindings). On a touch screen, the actual on-screen control is drawn next to it.
func _control_diagram(rg: Dictionary) -> void:
	var counts := {}
	var touch: Array = rg.get("touch", [])
	if touch.is_empty():
		touch = [{"kind": "buttons", "do": "", "label": "the choices that come up"}]
	for c in touch:
		var kd := str(c.kind)
		var n := int(counts.get(kd, 0))
		counts[kd] = n + 1
		var row := PartyUi.hbox(14)
		var what := str(c.get("label", "")).replace("_", " ").to_upper()
		if what == "":
			what = {"stick": "WALK AROUND"}.get(kd, str(c.get("do", "")).to_upper())
		var key := PartyUi.chip(Ui.control_binding(kd, n).to_upper(), PartyUi.INK, 20)
		key.custom_minimum_size = Vector2(230, 0) * PartyUi.k()
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key)
		var lab := PartyUi.label("%s: %s" % [CONTROL_HELP.get(kd, kd), what], 22, PartyUi.INK, true)
		lab.custom_minimum_size = Vector2(320, 0) * PartyUi.k()
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lab)
		if Ui.device == "touch" and kd != "buttons":
			# the real control, small and inert: this is what it looks like on your screen
			var w: Control = TouchStick.new() if kd == "stick" else PartyControls.make(c, func(_a): pass, "")
			w.custom_minimum_size = Vector2(110, 110) if kd == "stick" else w.custom_minimum_size * 0.6
			w.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for ch in w.find_children("*", "Control", true, false):
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			w.modulate.a = 0.85
			w.set_meta("diagram", true)    # a picture of the control, not the control
			row.add_child(w)
		card_box.add_child(row)


## Who's confirmed, and this screen's button (NEXT / READY), plus PRACTICE on the controls.
func _confirm_row(v: Dictionary, pz: Dictionary, label: String, what: String, practice := false) -> void:
	var me := _me()
	var done: Array = pz.get("confirmed", [])
	var waiting: Array = pz.get("waiting", [])
	var row := PartyUi.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in v.mg.get("seats", []):
		var p: Dictionary = v.players[int(s)]
		var ok := str(p.get("kind", "")) == "ai" or done.has(int(s)) or not waiting.has(int(s))
		row.add_child(PartyUi.chip("%s %s" % [p.name, "✓" if ok else "..."], PartyUi.MINT if ok else PartyUi.CREAM, 17))
	card_box.add_child(row)
	var btns := PartyUi.hbox(12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	if practice:
		btns.add_child(PartyUi.button("STOP PRACTISING" if _practice else "PRACTICE", func():
			_practice = not _practice
			_sig.erase("card"), PartyUi.TURQ, 240.0, 22))
	var mine: bool = me >= 0 and (v.mg.get("seats", []) as Array).has(me)
	var already: bool = done.has(me)
	if mine:
		var b := PartyUi.primary(label if not already else "WAITING FOR THE OTHERS", func():
			_practice = false
			for s in local:
				act.emit(s, {"t": what}), 300.0)
		b.disabled = already
		btns.add_child(b)
	else:
		btns.add_child(PartyUi.label("You're watching this one.", 18, PartyUi.DIM, true))
	card_box.add_child(btns)
	var left := maxf(0.0, float(pz.get("length", 0.0)) - float(pz.get("t", 0.0)))
	if left > 0.5:
		card_box.add_child(PartyUi.label("(take your time: at least %ds to read)" % int(ceil(left)), 15, PartyUi.DIM))


## Practice: the game's real controls, wired to a little feedback line instead of the match.
func _practice_area(mg: Dictionary) -> void:
	var box := PartyUi.panel(PartyUi.TURQ.lerp(PartyUi.CREAM, 0.6), PartyUi.INK, 16)
	var v2 := PartyUi.vbox(8)
	box.add_child(v2)
	v2.add_child(PartyUi.label("PRACTICE: nothing counts. Try it.", 18, PartyUi.INK, true))
	_practice_log = PartyUi.label("", 18, PartyUi.BLOOD, true)
	var row := PartyUi.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ctl: Array = mg.get("controls", [])
	for c in ctl:
		if str(c.kind) == "stick":
			_practice_stick = TouchStick.new()
			_practice_stick.custom_minimum_size = Vector2(170, 170) * PartyUi.bk()
			row.add_child(_practice_stick)
			var pen := Panel.new()
			pen.add_theme_stylebox_override("panel", PartyUi.flat_box(PartyUi.INK.lerp(PartyUi.CREAM, 0.15), PartyUi.INK, 2))
			pen.custom_minimum_size = Vector2(170, 170) * PartyUi.bk()
			pen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_practice_dot = ColorRect.new()
			_practice_dot.color = PartyUi.seat_colour(maxi(0, _me()))
			_practice_dot.size = Vector2(18, 18)
			_practice_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pen.add_child(_practice_dot)
			row.add_child(pen)
			continue
		var cc: Dictionary = c
		var w := PartyControls.make(cc, func(a: Dictionary):
			if is_instance_valid(_practice_log):
				_practice_log.text = "✓ %s" % str(a.get("do", a.get("pick", "that"))).replace("_", " ").to_upper(), "")
		row.add_child(w)
	if ctl.is_empty():
		for a in mg.get("actions", []):
			var lab := str(a.get("label", a.get("name", "?")))
			row.add_child(PartyUi.button(lab, func():
				if is_instance_valid(_practice_log):
					_practice_log.text = "✓ That's how you pick: %s" % lab, PartyUi.CREAM, 160.0, 16))
	v2.add_child(row)
	v2.add_child(_practice_log)
	card_box.add_child(box)


func _process(delta: float) -> void:
	if _practice and is_instance_valid(_practice_stick) and is_instance_valid(_practice_dot):
		var pen := _practice_dot.get_parent() as Control
		var p := _practice_dot.position + _practice_stick.value * 220.0 * delta
		_practice_dot.position = p.clamp(Vector2.ZERO, pen.size - _practice_dot.size)



# --- THE SEARCH: the secret choice, and the reveal -------------------------------------------

func _search_card(v: Dictionary) -> void:
	var se: Dictionary = v.get("search", {})
	var me := _me()
	match str(se.get("stage", "")):
		"choice":
			card.visible = true
			card_box.add_child(PartyUi.shout("TIME'S UP!", 40, PartyUi.RED))
			var mine: Array = se.get("mine", [])
			if se.get("holder", false):
				card_box.add_child(PartyUi.label("You found %d scrap%s:" % [mine.size(), "" if mine.size() == 1 else "s"], 20, PartyUi.INK, true))
				card_box.add_child(PartyUi.label("  ".join(mine.map(func(w): return "\"%s\"" % w)), 26, PartyUi.BLOOD, true))
				card_box.add_child(PartyUi.label("Nobody will see what you choose until everyone has.", 16, PartyUi.DIM))
				if se.get("chose", false):
					card_box.add_child(PartyUi.label("DONE. WAITING FOR THE OTHERS...", 20, PartyUi.INK, true))
				else:
					var row := PartyUi.hbox(12)
					row.alignment = BoxContainer.ALIGNMENT_CENTER
					row.add_child(PartyUi.button("KEEP THEM\n(%d Teeth each)" % SearchEvent.KEEP_EACH, func(): act.emit(me, {"t": "search_choice", "keep": true}), PartyUi.ORANGE, 260.0, 20))
					row.add_child(PartyUi.button("LAY THEM\nON THE TABLE", func(): act.emit(me, {"t": "search_choice", "keep": false}), PartyUi.TURQ, 260.0, 20))
					card_box.add_child(row)
			else:
				card_box.add_child(PartyUi.label("You didn't find a thing. The others are deciding what to do with theirs.", 20, PartyUi.INK, true))
		"reveal":
			card.visible = true
			var r: Dictionary = se.get("result", {})
			var wn: Array = r.get("winners", [])
			card_box.add_child(PartyUi.label("MOST SCRAPS FOUND", 20, PartyUi.DIM, true))
			card_box.add_child(PartyUi.shout(" & ".join(wn.map(func(s): return str(v.players[int(s)].name))) + "  +%d TEETH" % SearchEvent.RACE_PRIZE if not wn.is_empty() else "NOBODY", 32, PartyUi.YELLOW))
			var counts: Dictionary = r.get("counts", {})
			var ch: Dictionary = r.get("choices", {})
			var row2 := PartyUi.hbox(8)
			for s in counts.keys():
				var n := int(counts[s])
				var what := "found nothing" if n == 0 else ("LAID %d" % n if str(ch.get(s, ch.get(str(s), "keep"))) == "lay" else "KEPT %d" % n)
				row2.add_child(PartyUi.chip("%s: %s" % [v.players[int(s)].name, what], PartyUi.TURQ.lerp(PartyUi.CREAM, 0.5) if what.begins_with("LAID") else PartyUi.CREAM, 15))
			card_box.add_child(row2)
			if r.get("whole", false):
				card_box.add_child(PartyUi.shout("THE NOTE, WHOLE:", 30, PartyUi.MINT))
				card_box.add_child(PartyUi.label("\"NOBODY WINS ALONE. PUT US BACK TOGETHER.\"", 26, PartyUi.BLOOD, true))
				card_box.add_child(PartyUi.shout("EVERYONE GETS A DEAD RAT", 34, PartyUi.YELLOW))
			else:
				card_box.add_child(PartyUi.shout("THE NOTE STAYS TORN", 30, PartyUi.RED))
				if not r.get("all_found", false):
					card_box.add_child(PartyUi.label("Not every scrap was found. Whatever it said, nobody will know.", 18))
				else:
					card_box.add_child(PartyUi.label("%d of %d pieces on the table. Somebody kept theirs." % [int(r.laid), int(r.total)], 18))



## Captions and the countdown, every frame, from the presenter's stage and clock.
func _stage_overlay(v: Dictionary) -> void:
	_info(v)
	var fl: Dictionary = v.get("flow", {})
	if debug_lbl.visible:
		debug_lbl.text = "FLOW %s  %.1fs  | %s | stage %s | invalid %d" % [str(fl.get("state", "")), float(fl.get("t", 0)), str(fl.get("waiting_on", "")),
			str(v.get("presenter", {}).get("stage", "-")), int(fl.get("invalid", 0))]
	step_btn.visible = str(fl.get("waiting_on", "")).begins_with("DEBUG STEP")
	var pz: Dictionary = v.get("presenter", {})
	var stage := str(pz.get("stage", ""))
	var rg: Dictionary = v.get("registration", {})
	var cap := ""
	match stage:
		"arena_preview":
			cap = str(rg.get("arena_title", ""))
		"arena_intro":
			cap = "%s: THE ARENA" % str(rg.get("name", ""))
		"positioning":
			cap = "TAKE YOUR PLACES"
		"play_freeze":
			cap = ""
	stage_lbl.visible = cap != ""
	stage_lbl.text = cap
	# 3, 2, 1, GO! over the countdown's length (GO! lingers into the first moment of play)
	var txt := ""
	if stage == "countdown":
		var length := maxf(0.1, float(pz.get("length", 4.0)))
		var k := int(float(pz.get("t", 0.0)) / (length / 4.0))
		txt = ["3", "2", "1", "GO!"][clampi(k, 0, 3)]
	elif stage == "play" and float(pz.get("t", 9.0)) < 0.7:
		txt = "GO!"
	countdown_lbl.visible = txt != ""
	if txt != _last_count:
		_last_count = txt
		countdown_lbl.text = txt
		if txt != "":
			countdown_lbl.add_theme_color_override("font_color", PartyUi.MINT if txt == "GO!" else PartyUi.YELLOW)
			countdown_lbl.pivot_offset = countdown_lbl.size * 0.5
			countdown_lbl.scale = Vector2(1.6, 1.6)
			countdown_lbl.create_tween().tween_property(countdown_lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("bell" if txt == "GO!" else "blip", -2.0, 0.0, 1.4 if txt == "GO!" else 1.0)



## WHO is playing (the turn announcement) and WHAT happened (the landing): one panel, one job.
func _info(v: Dictionary) -> void:
	var fl := str(v.get("flow", {}).get("state", ""))
	var sig := ""
	var s := int(v.get("turn", {}).get("seat", -1)) if str(v.phase) == "turn" else -1
	if s >= 0 and fl == "TURN_ANNOUNCEMENT":
		sig = "turn%d" % s
	elif s >= 0 and fl == "LANDING_EVENT":
		sig = "land%d:%d" % [s, int(v.players[s].space)]
	if sig == _info_sig:
		return
	_info_sig = sig
	_clear(info_box)
	info_panel.visible = sig != ""
	if sig == "":
		return
	var p: Dictionary = v.players[s]
	if fl == "TURN_ANNOUNCEMENT":
		info_panel.add_theme_stylebox_override("panel", PartyUi.box(PartyUi.CREAM.lerp(PartyUi.seat_colour(s), 0.4), PartyUi.INK, 16))
		info_box.add_child(PartyUi.shout("%s'S TURN" % str(p.name).to_upper() if not local.has(s) else "YOUR TURN!", 40, PartyUi.seat_colour(s).lightened(0.2)))
		var row := PartyUi.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(PartyUi.chip("%d TEETH" % int(p.teeth), PartyUi.CREAM, 20))
		row.add_child(PartyUi.chip("%d DEAD RATS" % int(p.rats), PartyUi.YELLOW, 20))
		info_box.add_child(row)
		var items: Array = p.get("items", [])
		if not items.is_empty():
			info_box.add_child(PartyUi.label("POCKETS: " + ", ".join(items.map(func(it): return Items.name_of(it))), 18, PartyUi.INK, true))
		var sts: Array = p.get("statuses", [])
		if not sts.is_empty():
			info_box.add_child(PartyUi.label("AFFLICTED: " + ", ".join(sts.map(func(st): return str(st.get("id", "")).replace("_", " ").to_upper())), 17, PartyUi.BLOOD, true))
		if p.get("ghost", false):
			info_box.add_child(PartyUi.label("A GHOST. Haunt someone, scavenge, or buy your way back.", 17, PartyUi.PURPLE, true))
	else:
		var sp := int(p.space)
		var t := str(v.get("board_types", {}).get(str(sp), v.get("space_type", "")))
		var info: Array = PartyUi.SPACE_INFO.get(t, [t.to_upper(), ""])
		info_panel.add_theme_stylebox_override("panel", PartyUi.box(PartyUi.space_colour(t).lerp(PartyUi.CREAM, 0.45), PartyUi.INK, 16))
		info_box.add_child(PartyUi.shout(str(info[0]), 40, PartyUi.space_colour(t).lightened(0.25)))
		info_box.add_child(PartyUi.label(str(info[1]), 22, PartyUi.INK, true))



## Labels in a grid have no width of their own to wrap in (they'd go one letter a line).
func _nowrap(c: Node) -> void:
	for l in c.find_children("*", "Label", true, false):
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
