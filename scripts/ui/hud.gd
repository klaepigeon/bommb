class_name Hud
extends CanvasLayer
## Everything on the glass during a match: the contestants' cards (rats, injuries,
## items, the key), the Caller's dialogue box, toasts, the context buttons for whoever
## on this device has something to do, prompts, the minigame card, results, and the
## ending. It only shows the view and sends actions (via `act`); no rules live here.

signal act(seat: int, a: Dictionary)
signal leave_pressed
signal lobby_pressed

var root: Control
var cards: Array = []
var dialog: PanelContainer
var dialog_text: Label
var toast_box: VBoxContainer
var actions: VBoxContainer
var modal: PanelContainer
var modal_box: VBoxContainer
var card: PanelContainer        # minigame instructions / results / ending
var card_box: VBoxContainer
var stick: TouchStick
var chambers: Label
var status_line: Label
var view: Dictionary = {}
var local: Array = []
var _typing := ""
var _typed := 0.0
var _act_sig := ""
var _modal_sig := ""
var _card_sig := ""
var menu_mode := ""             # "" | items | give_item | give_to:<id> | mirror


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# the character sheets, down the left like his
	var left := UiKit.vbox(6)
	left.position = Vector2(12, 96)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	for i in 4:
		var c := _card_ui()
		left.add_child(c.root)
		cards.append(c)
	# what he says, across the top of the room
	dialog_text = UiKit.voice("", 34)
	dialog_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	dialog_text.offset_left = -520
	dialog_text.offset_right = 520
	dialog_text.offset_top = 14
	dialog_text.offset_bottom = 110
	root.add_child(dialog_text)
	dialog = PanelContainer.new()   # (kept for API; the voice has no box)
	status_line = UiKit.label("", 12, UiKit.CREAM)
	status_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_line.offset_left = -360
	status_line.offset_right = -16
	status_line.offset_top = 10
	status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	status_line.add_theme_constant_override("outline_size", 6)
	status_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_line)
	toast_box = UiKit.vbox(4)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.offset_top = 118
	toast_box.offset_left = -330
	toast_box.offset_right = 330
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	actions = UiKit.vbox(6)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_right = -14
	actions.offset_bottom = -14
	actions.offset_left = -330
	actions.offset_top = -470
	actions.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(actions)
	chambers = UiKit.voice("", 30)
	chambers.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	chambers.offset_top = -120
	chambers.offset_bottom = -20
	chambers.offset_left = -260
	chambers.offset_right = 260
	root.add_child(chambers)
	stick = TouchStick.new()
	stick.custom_minimum_size = Vector2(220, 220)
	stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 30
	stick.offset_top = -260
	stick.offset_bottom = -40
	stick.offset_right = 250
	stick.visible = false
	root.add_child(stick)
	modal = UiKit.panel()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -320
	modal.offset_right = 320
	modal.offset_top = -160
	modal.offset_bottom = 120
	modal.visible = false
	root.add_child(modal)
	modal_box = UiKit.vbox(8)
	modal.add_child(modal_box)
	card = UiKit.panel()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -360
	card.offset_right = 360
	card.offset_top = -200
	card.offset_bottom = 180
	card.visible = false
	root.add_child(card)
	card_box = UiKit.vbox(6)
	card.add_child(card_box)


func _card_ui() -> Dictionary:
	var p := UiKit.card()
	p.custom_minimum_size = Vector2(290, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UiKit.hbox(8)
	p.add_child(h)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(40, 50)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(face)
	var v := UiKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := UIKit.label("", 21, UiKit.HOT, true)
	nm.clip_text = true
	var line := UIKit.label("", 15, UiKit.INK)
	var hurt := UIKit.label("", 13, Color("7a1a12"))
	hurt.clip_text = true
	hurt.custom_minimum_size = Vector2(200, 0)
	v.add_child(nm)
	v.add_child(line)
	v.add_child(hurt)
	return {"root": p, "face": face, "name": nm, "line": line, "hurt": hurt}


# --- updates --------------------------------------------------------------------------

func update(v: Dictionary, local_seats: Array, delta: float) -> void:
	view = v
	local = local_seats
	if v.is_empty():
		return
	for i in mini(4, v.players.size()):
		_fill_card(cards[i], v.players[i], v)
	_typed += delta * 45.0
	dialog_text.text = _typing.substr(0, int(_typed))
	_status(v)
	_actions(v)
	_cards(v)
	_stick(v)


func _fill_card(c: Dictionary, p: Dictionary, v: Dictionary) -> void:
	(c.face as TextureRect).texture = Assets.face_texture(int(p.face))
	var turn: bool = int(v.turn.get("seat", -1)) == int(p.seat) and v.phase == "turn"
	c.name.text = ("> " if turn else "") + str(p.name) + ("  (YOU)" if local.has(int(p.seat)) and local.size() == 1 else "")
	c.name.add_theme_color_override("font_color", UiKit.HOT if p.alive else UiKit.DIM)
	if not p.alive:
		c.line.text = "OUT (%s)" % str(p.death).to_upper()
		c.hurt.text = ""
		(c.root as Control).modulate = Color(0.6, 0.6, 0.6)
		return
	(c.root as Control).modulate = Color.WHITE
	var bits := ["%d rats" % int(p.rats), "%d items" % int(p.item_count)]
	if p.has_key:
		bits.append("KEY")
	if p.helmet:
		bits.append("HELMET")
	if p.at_door:
		bits.append("@DOOR")
	if int(p.clue_count) > 0:
		bits.append("?%d" % int(p.clue_count))
	c.line.text = "  ".join(bits)
	var hurts := []
	for part in Body.PARTS:
		var s: String = p.body[part].s
		if s != "ok":
			hurts.append(_short(part) + " " + s.substr(0, 4))
	c.hurt.text = ("pins: " + ", ".join(hurts)) if not hurts.is_empty() else "not a pin in it"


func _short(part: String) -> String:
	return {"hand_l": "LH", "hand_r": "RH", "arm_l": "LA", "arm_r": "RA", "leg_l": "LL", "leg_r": "RL", "eye_l": "LE", "eye_r": "RE", "ears": "EAR"}[part]


func _status(v: Dictionary) -> void:
	var s := ""
	match str(v.phase):
		"turn":
			s = "ROUND %d / %d" % [int(v.round), int(v.max_rounds)]
			var known: Dictionary = v.shared_code
			if not known.is_empty():
				var parts := []
				for i in 3:
					parts.append(str(known[i]) if known.has(i) else "_")
				s += "     the numbers: " + " ".join(parts)
		"mg_play":
			s = str(v.mg.get("title", ""))
			match str(v.mg_id):
				"musical_chairs":
					s += "   round %d/%d   %s" % [int(v.mg.round) + 1, int(v.mg.rounds), {"music": "WALK...", "scramble": "SIT!", "reveal": "", "between": ""}.get(str(v.mg.sub), "")]
				"hot_potato":
					s += "   " + "TICK " .repeat(1 + int(float(v.mg.urgency) * 5))
		"door":
			s = "THE DOOR: everyone has to push"
	status_line.text = s
	chambers.text = ""
	if v.phase == "mg_play" and v.mg_id == "roulette":
		var mg: Dictionary = v.mg
		var row := ""
		for i in int(mg.chambers):
			row += ("x " if i < int(mg.clicks) else "o ")
		chambers.text = row + "\n%d in the drum" % int(mg.loaded)


## Who on this device has something to do right now, and the buttons for it.
func _actions(v: Dictionary) -> void:
	var sig := _action_signature(v)
	if sig == _act_sig:
		return
	_act_sig = sig
	for c in actions.get_children():
		c.queue_free()
	modal.visible = false
	var phase := str(v.phase)
	if phase in ["intro", "mg_intro", "mg_results"]:
		actions.add_child(UiKit.primary("READY", func():
			for s in local:
				act.emit(s, {"t": "ready"})))
		return
	if phase == "door":
		for s in local:
			if v.players[s].alive and not v.door_push.has(s):
				actions.add_child(UiKit.button("PUSH (%s)" % v.players[s].name, func(): act.emit(s, {"t": "push"}), 52))
		return
	if phase == "turn":
		var s := int(v.turn.seat)
		if not local.has(s):
			return
		var me: Dictionary = v.players[s]
		if v.turn.sub == "pre":
			_board_actions(s, me, v)
		elif v.turn.sub == "prompt":
			_prompt(s, v.turn.prompt, v)
		return
	if phase == "mg_play":
		var mg: Dictionary = v.mg
		match str(v.mg_id):
			"roulette":
				var s := int(mg.turn)
				if local.has(s) and mg.sub == "turn":
					_roulette_actions(s, v)
			"hot_potato":
				var h := int(mg.holder)
				if local.has(h) and mg.sub == "play" and mg.flight.is_empty() and mg.busy.is_empty():
					_potato_actions(h, v)


func _action_signature(v: Dictionary) -> String:
	var mg: Dictionary = v.get("mg", {})
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [v.phase, v.turn.get("seat", -1), v.turn.get("sub", ""), menu_mode,
		mg.get("turn", ""), mg.get("sub", ""), mg.get("holder", ""), str(mg.get("flight", {}).is_empty()), mg.get("step", ""),
		str(mg.get("busy", {}).is_empty()), str(v.door_push.size()) + str(v.players.map(func(p): return p.items.size())) + str(mg.get("peeks", {}))]


func _board_actions(s: int, me: Dictionary, v: Dictionary) -> void:
	if menu_mode == "items":
		for it in me.items:
			if Items.usable_on_board(it):
				actions.add_child(UiKit.button("USE " + Items.name_of(it), func():
					menu_mode = ""
					act.emit(s, {"t": "item", "id": it})))
		actions.add_child(UiKit.button("BACK", func(): menu_mode = ""))
		return
	if menu_mode == "give_item":
		for it in me.items:
			actions.add_child(UiKit.button("GIVE " + Items.name_of(it), func(): menu_mode = "give_to:" + it))
		actions.add_child(UiKit.button("BACK", func(): menu_mode = ""))
		return
	if menu_mode.begins_with("give_to:"):
		var it := menu_mode.substr(8)
		for p in v.players:
			if p.alive and int(p.seat) != s:
				actions.add_child(UiKit.button("TO " + str(p.name), func():
					menu_mode = ""
					act.emit(s, {"t": "give", "id": it, "target": int(p.seat)})))
		actions.add_child(UiKit.button("BACK", func(): menu_mode = ""))
		return
	if me.at_door:
		actions.add_child(UiKit.button("TRY THE DOOR", func(): act.emit(s, {"t": "try_door"})))
		actions.add_child(UiKit.button("WAIT HERE", func(): act.emit(s, {"t": "stay"})))
	if me.items.any(func(it): return Items.usable_on_board(it)):
		actions.add_child(UiKit.button("USE ITEM", func(): menu_mode = "items"))
	if not me.items.is_empty():
		actions.add_child(UiKit.button("GIVE ITEM", func(): menu_mode = "give_item"))
	if int(me.clue_count) > 0:
		actions.add_child(UiKit.button("TELL EVERYONE", func(): act.emit(s, {"t": "share"})))
	var b := UiKit.primary("ROLL  (1-%d)" % Body.dice_max(me.body, int(me.painkillers) > 0), func(): act.emit(s, {"t": "roll"}), 52)
	actions.add_child(b)
	b.grab_focus.call_deferred()


func _prompt(s: int, pr: Dictionary, v: Dictionary) -> void:
	modal.visible = true
	for c in modal_box.get_children():
		c.queue_free()
	if pr.kind == "door_stop":
		modal_box.add_child(UiKit.label("%s, you're passing the door. Stop here?" % v.players[s].name, 16))
		var h := UiKit.hbox(8)
		modal_box.add_child(h)
		h.add_child(UiKit.button("STOP AT THE DOOR", func(): act.emit(s, {"t": "answer", "yes": true})))
		h.add_child(UiKit.button("KEEP WALKING", func(): act.emit(s, {"t": "answer", "yes": false})))
	elif pr.kind == "steal":
		modal_box.add_child(UiKit.label("STICKY FINGERS. Take something from:", 16))
		for o in pr.options:
			var p: Dictionary = v.players[int(o)]
			modal_box.add_child(UiKit.button("%s (%d items, %d rats)" % [p.name, p.items.size(), int(p.rats)], func(): act.emit(s, {"t": "answer", "target": int(o)})))


func _roulette_actions(s: int, v: Dictionary) -> void:
	var me: Dictionary = v.players[s]
	var mg: Dictionary = v.mg
	if mg.peeks.has(s):
		actions.add_child(UiKit.label("YOU PEEKED: " + ("IT'S LOADED" if mg.peeks[s] else "EMPTY"), 14, UiKit.CREAM))
	if menu_mode == "mirror":
		for p in v.players:
			if p.alive and int(p.seat) != s:
				actions.add_child(UiKit.button("AT " + str(p.name), func():
					menu_mode = ""
					act.emit(s, {"t": "mg", "do": "item", "id": "mirror", "target": int(p.seat)})))
		actions.add_child(UiKit.button("BACK", func(): menu_mode = ""))
		return
	for it in me.items:
		if Items.CATALOGUE.get(it, {}).get("use", "") == "roulette":
			if it == "mirror":
				actions.add_child(UiKit.button(Items.name_of(it), func(): menu_mode = "mirror"))
			else:
				actions.add_child(UiKit.button(Items.name_of(it), func(): act.emit(s, {"t": "mg", "do": "item", "id": it})))
	actions.add_child(UiKit.button("put it down", func(): act.emit(s, {"t": "mg", "do": "lower"}), 32))
	var b := UiKit.primary("PULL THE STRING", func(): act.emit(s, {"t": "mg", "do": "pull"}), 52)
	actions.add_child(b)
	b.grab_focus.call_deferred()


func _potato_actions(h: int, v: Dictionary) -> void:
	var mg: Dictionary = v.mg
	if int(mg.step) == -1:
		actions.add_child(UiKit.button("fiddle with it", func(): act.emit(h, {"t": "mg", "do": "fiddle"}), 32))
	elif str(mg.next) != "":
		var allowed := int(mg.last_doer) != h
		var b := UiKit.button(str(mg.next) if allowed else "(it won't let you)", func(): act.emit(h, {"t": "mg", "do": "step"}), 40)
		b.disabled = not allowed
		actions.add_child(b)
	for p in v.players:
		if p.alive and int(p.seat) != h:
			actions.add_child(UiKit.button("PASS TO " + str(p.name), func(): act.emit(h, {"t": "mg", "do": "pass", "target": int(p.seat)}), 44))


func _cards(v: Dictionary) -> void:
	var phase := str(v.phase)
	var sig := phase + str(v.get("mg_id", "")) + str(v.get("ending", ""))
	if sig == _card_sig:
		return
	_card_sig = sig
	for c in card_box.get_children():
		c.queue_free()
	card.visible = false
	match phase:
		"mg_intro":
			var mg: Dictionary = v.mg
			card.visible = true
			card_box.add_child(UiKit.label(str(mg.title), 26, UiKit.HOT, true))
			for line in mg.instructions:
				card_box.add_child(UiKit.label("- " + str(line), 15))
			if v.mg_id == "musical_chairs":
				card_box.add_child(UiKit.label("Move: stick / WASD / arrows / d-pad", 11, UiKit.DIM))
		"mg_results":
			card.visible = true
			card_box.add_child(UiKit.label("RESULTS", 24, UiKit.HOT, true))
			for p in v.players:
				var won := int(v.mg.get("rats", {}).get(int(p.seat), 0))
				card_box.add_child(UiKit.label("%s   %s   rats %d (%+d)" % [p.name, "ALIVE" if p.alive else "OUT", int(p.rats), won], 14,
					UiKit.INK if p.alive else UiKit.DIM))
		"ceremony":
			pass
		"ending":
			card.visible = true
			card.offset_top = -250
			card.offset_bottom = 230
			var esc: bool = v.ending == "escape"
			card_box.add_child(UiKit.label("YOU GOT OUT" if esc else "TOTAL ELIMINATION", 28, UiKit.TEAL if esc else UiKit.HOT, true))
			card_box.add_child(UiKit.label("The door was never painted on." if esc else "Nobody went home. Nobody ever does.", 15))
			for st in v.ending_info.get("standings", []):
				card_box.add_child(UiKit.label("%s  -  %s  -  %d rats" % [st.name, "out the door" if st.alive else str(st.death), int(st.rats)], 13))
			var h := UiKit.hbox(8)
			card_box.add_child(h)
			if Net.is_authority():
				h.add_child(UiKit.button("PLAY AGAIN", func(): lobby_pressed.emit()))
			h.add_child(UiKit.button("MAIN MENU", func(): leave_pressed.emit()))


func _stick(v: Dictionary) -> void:
	var show := false
	if v.phase == "mg_play" and v.mg_id == "musical_chairs" and local.size() >= 1:
		var s: int = local[0]
		show = v.players[s].alive and not v.mg.seated.has(s) and DisplayServer.is_touchscreen_available()
	stick.visible = show or (v.phase == "mg_play" and v.mg_id == "musical_chairs" and OS.has_feature("mobile"))


func say(text: String) -> void:
	_typing = text
	_typed = 0.0


func toast(text: String, private := false) -> void:
	var l := UIKit.label(text, 17, UiKit.CREAM if not private else Color("e8c060"), false, true)
	l.add_theme_font_override("font", UIKit.ital_font)
	l.custom_minimum_size = Vector2(600, 0)
	var p := UiKit.dark()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := p.create_tween()
	tw.tween_interval(6.0 if private else 4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
