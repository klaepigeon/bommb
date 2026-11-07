extends Node
## The app: one screen at a time (menu, settings, setup, online, lobby, match). Screens
## are plain Controls built in code with UiKit; the match is a GameView.

var screen: Node
var _ui: Control
var bg_stage: Stage           # the hall behind every menu (a match builds its own)
var bg_caller: CallerActor
var _idle: Timer
var _status: Label
var _lobby_box: VBoxContainer


func _ready() -> void:
	get_tree().root.theme = PartyUi.theme()
	Net.status.connect(func(s): if _status: _status.text = s)
	Net.lobby_changed.connect(func(): if _lobby_box: _fill_lobby())
	Net.match_started.connect(_start_match)
	Net.left.connect(func(r):
		menu()
		_toast(r))
	Net.back_to_lobby.connect(lobby)
	if OS.get_cmdline_user_args().has("--quick"):
		Seats.reset("single")
		Seats.set_seat(0, {"kind": "local", "name": str(Settings.get_v("name")), "device": "primary"})
		Net.start_offline()
		Net.launch()
		return
	menu()


func _swap(n: Node) -> void:
	if screen:
		screen.queue_free()
	screen = n
	_status = null
	_lobby_box = null
	if n is GameView:
		_drop_stage()
	else:
		_ensure_stage()
	add_child(n)


## The hall, for the menus: you're sat at his table; he's waiting.
func _ensure_stage(pose := "title") -> void:
	if bg_stage == null:
		bg_stage = Stage.new()
		add_child(bg_stage)
		move_child(bg_stage, 0)
		bg_stage.set_internal_height(Settings.screen_lines() if Settings.screen_lines() > 0 else 540)
		bg_caller = CallerActor.wrap(bg_stage.hall.caller)
		bg_stage.hall.add_child(bg_caller)
		bg_stage.hall.flashboard.set_left("LAST", "CALL")
		bg_stage.hall.flashboard.set_right("PART", "03")
		_idle = Timer.new()
		_idle.wait_time = 3.2
		_idle.autostart = true
		_idle.timeout.connect(func(): if bg_caller: bg_caller.play(["wave", "spread", "tip_hat", "beckon", "drum", "look_door", "head_spin", "stare", "tap", "lean"][randi() % 10]))
		add_child(_idle)
	bg_stage.set_pose(pose, 0.9)


func _drop_stage() -> void:
	if bg_stage:
		bg_stage.queue_free()
		bg_stage = null
		bg_caller = null
	if _idle:
		_idle.queue_free()
		_idle = null


## A sheet of his card stock laid on the table, with a heading in red ink.
func _page(title: String) -> VBoxContainer:
	var c := Control.new()
	c.theme = PartyUi.theme()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swap(c)
	bg_stage.set_pose("deal", 0.9)
	var sheet := PartyUi.panel()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.offset_left = -470
	sheet.offset_right = 470
	sheet.offset_top = -320
	sheet.offset_bottom = 320
	c.add_child(sheet)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(sc)
	var v := PartyUi.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(_lbl(title, 26, PartyUi.PINK, true))
	_ui = c
	return v


func _toast(t: String) -> void:
	if _status:
		_status.text = t


# --- main menu ----------------------------------------------------------------------

func menu() -> void:
	Audio.music("title")
	var c := Control.new()
	c.theme = PartyUi.theme()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swap(c)
	bg_stage.set_pose("title", 1.2)
	var title := PartyUi.shout("LAST CALL 3", 96, PartyUi.PINK)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	title.offset_left = -720
	title.offset_right = -40
	title.offset_top = 24
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(title)
	var sub := PartyUi.shout("MEAT PARTY: WELCOME TO MURDERLAND", 34, PartyUi.YELLOW)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sub.offset_left = -720
	sub.offset_right = -46
	sub.offset_top = 140
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(sub)
	var v := PartyUi.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 60
	v.offset_right = 420
	v.offset_top = -170
	v.offset_bottom = 300
	c.add_child(v)
	if Saves.has_save():
		v.add_child(_pbtn("CONTINUE (%s)" % Saves.summary(), resume, 44))
	var b := _pbtn("PLAY (vs. AI)", single, 44)
	v.add_child(b)
	v.add_child(_btn("LOCAL PARTY (2-4)", local_setup, 44))
	v.add_child(_btn("ONLINE", online, 44))
	v.add_child(_btn("SETTINGS", settings, 40))
	if not OS.has_feature("mobile"):
		v.add_child(_btn("LEAVE", func(): get_tree().quit(), 36))
	_status = _lbl("", 12, PartyUi.CREAM)
	v.add_child(_status)


## Pick up a saved match where it was (the start of its round, the same dice).
func resume() -> void:
	var d := Saves.read()
	if d.is_empty():
		menu()
		return
	Net.resume_offline(d)


func single() -> void:
	Net.start_offline()
	Seats.reset("single")
	Seats.set_seat(0, {"kind": "local", "name": str(Settings.get_v("name")), "device": "primary", "face": int(Settings.get_v("face", 0)), "ready": true})
	lobby()


# --- local: several people, one device ----------------------------------------------

const DEVICES := ["primary", "wasd", "arrows", "ijkl", "pad0", "pad1", "pad2", "pad3"]


func local_setup() -> void:
	Net.start_offline()
	Seats.reset("local")
	Seats.set_seat(0, {"kind": "local", "name": "PLAYER 1", "device": "primary", "face": 0, "ready": true})
	Seats.set_seat(1, {"kind": "local", "name": "PLAYER 2", "device": "arrows", "face": 1, "ready": true})
	lobby()


# --- online -------------------------------------------------------------------------

func online() -> void:
	var v := _page("ONLINE")
	v.add_child(_lbl("Phones and PCs can share a room. On the same Wi-Fi, a room is found by its code. Over the internet, rooms go through the relay (%s)." % Settings.relay_url(), 12, PartyUi.INK))
	var h := PartyUi.hbox(8)
	v.add_child(h)
	h.add_child(_btn("HOST ON THIS NETWORK", func():
		if Net.host_lan() == OK:
			lobby(), 46, 200))
	h.add_child(_btn("HOST OVER THE INTERNET", func():
		if Net.host_relay() == OK:
			lobby(), 46, 200))
	var code := LineEdit.new()
	code.placeholder_text = "ROOM CODE"
	code.max_length = 5
	code.custom_minimum_size = Vector2(160, 44)
	var ip := LineEdit.new()
	ip.placeholder_text = "or an address (192.168.1.20)"
	ip.custom_minimum_size = Vector2(240, 44)
	var h2 := PartyUi.hbox(8)
	v.add_child(h2)
	h2.add_child(code)
	h2.add_child(_btn("JOIN", func():
		if code.text.strip_edges() != "":
			Net.join_code(code.text)
			lobby(), 44))
	var h3 := PartyUi.hbox(8)
	v.add_child(h3)
	h3.add_child(ip)
	h3.add_child(_btn("JOIN ADDRESS", func():
		if ip.text.strip_edges() != "":
			var parts := ip.text.strip_edges().split(":")
			Net.join_ip(parts[0], int(parts[1]) if parts.size() > 1 else 0)
			lobby(), 44, 140))
	_status = _lbl("", 13, PartyUi.PINK)
	v.add_child(_status)
	v.add_child(_btn("BACK", menu, 40))


# --- the lobby (every mode) --------------------------------------------------------------

func lobby() -> void:
	var v := _page("THE SEATING PLAN")
	_status = _lbl("", 13, PartyUi.PINK)
	v.add_child(_status)
	if Net.online():
		_status.text = "Room code: %s" % Net.code if Net.code != "" else "Connecting..."
	_lobby_box = PartyUi.vbox(6)
	v.add_child(_lobby_box)
	_fill_lobby()


func _fill_lobby() -> void:
	if _lobby_box == null:
		return
	for c in _lobby_box.get_children():
		c.queue_free()
	var authority := Net.is_authority()
	if Net.online() and Net.code != "":
		_lobby_box.add_child(_lbl("ROOM  %s" % Net.code, 28, PartyUi.PINK, true))
	for s in Seats.seats:
		var h := PartyUi.hbox(8)
		_lobby_box.add_child(h)
		var face := TextureRect.new()
		face.texture = Assets.face_texture(int(s.face))
		face.custom_minimum_size = Vector2(40, 50)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.visible = s.kind != "empty"
		h.add_child(face)
		var desc := "(empty: the Caller will fill it)"
		match str(s.kind):
			"local":
				desc = "%s  (here%s)" % [s.name, ", " + str(s.get("device", "")) if Seats.mode == "local" else ""]
			"remote":
				desc = "%s  %s" % [s.name, "READY" if s.ready else "not ready"]
			"ai":
				desc = "%s  (AI)" % s.name
		var l := _lbl("%d. %s" % [int(s.seat) + 1, desc], 15, (s.color as Color).darkened(0.45) if s.kind != "empty" else PartyUi.DIM)
		l.custom_minimum_size = Vector2(380, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(l)
		var seat := int(s.seat)
		if authority and s.kind in ["empty", "ai"]:
			h.add_child(_btn("REMOVE AI" if s.kind == "ai" else "ADD AI", func():
				Net.toggle_ai(seat)
				_fill_lobby(), 34, 110))
		if Seats.mode == "local" and s.kind == "empty":
			h.add_child(_btn("ADD PLAYER", func():
				Seats.set_seat(seat, {"kind": "local", "name": "PLAYER %d" % (seat + 1), "device": DEVICES[mini(seat + 1, DEVICES.size() - 1)], "face": seat, "ready": true})
				_fill_lobby(), 34, 120))
		if Seats.mode == "local" and s.kind == "local":
			h.add_child(_btn("CONTROLS", func():
				var d := DEVICES.find(str(s.get("device", "primary")))
				Seats.seats[seat].device = DEVICES[(d + 1) % DEVICES.size()]
				_fill_lobby(), 34, 100))
			if seat > 0:
				h.add_child(_btn("X", func():
					Seats.clear_seat(seat)
					_fill_lobby(), 34, 40))
		if s.kind == "local" or (s.kind == "remote" and Net.my_seats.has(seat)):
			h.add_child(_btn("FACE", func():
				Seats.seats[seat].face = (int(Seats.seats[seat].face) + 1) % Assets.face_count()
				if seat == 0:
					Settings.set_v("face", Seats.seats[seat].face)
				_fill_lobby(), 34, 70))
	if authority:
		var opt := PartyUi.hbox(8)
		_lobby_box.add_child(opt)
		var lengths := [[10, "QUICK"], [15, "STANDARD"], [20, "EXTENDED"], [30, "MARATHON"]]
		for L in lengths:
			var n: int = L[0]
			var sel := int(Settings.get_v("match_turns", 15)) == n
			opt.add_child(PartyUi.button("%s\n%d ROUNDS" % [L[1], n], func():
				Settings.set_v("match_turns", n)
				_fill_lobby(), PartyUi.YELLOW if sel else PartyUi.CREAM, 130.0, 16))
		var modes := PartyUi.hbox(8)
		_lobby_box.add_child(modes)
		for M in [["classic", "CLASSIC: MOST DEAD RATS WINS"], ["callers_game", "THE CALLER'S GAME: HIDDEN RULES"]]:
			var m: String = M[0]
			var sel2 := str(Settings.get_v("match_mode", "classic")) == m
			modes.add_child(PartyUi.button(M[1], func():
				Settings.set_v("match_mode", m)
				_fill_lobby(), PartyUi.TURQ if sel2 else PartyUi.CREAM, 270.0, 15))
	var row := PartyUi.hbox(8)
	_lobby_box.add_child(row)
	if authority:
		var go := _pbtn("SIT DOWN", func(): Net.launch(), 50, 200)
		go.disabled = not Net.all_ready() or (Net.online() and Net.code in ["", "....."])
		row.add_child(go)
		go.grab_focus.call_deferred()
	elif Net.role == "client" and not Net.my_seats.is_empty():
		var mine: Dictionary = Seats.seats[int(Net.my_seats[0])]
		row.add_child(_btn("NOT READY" if mine.ready else "READY", func():
			Net.set_ready(not mine.ready), 50, 160))
	row.add_child(_btn("LEAVE", func():
		Net.leave_quiet()
		menu(), 50, 100))


func _start_match() -> void:
	var g := GameView.new()
	g.leave_requested.connect(func():
		Net.leave_quiet()
		menu())
	g.lobby_requested.connect(func(): Net.return_to_lobby())
	_swap(g)


# --- settings -------------------------------------------------------------------------

func settings() -> void:
	var v := _page("SETTINGS")
	var name := LineEdit.new()
	name.text = str(Settings.get_v("name"))
	name.max_length = 12
	name.custom_minimum_size = Vector2(200, 40)
	name.text_changed.connect(func(t): Settings.set_v("name", t.to_upper()))
	var hn := PartyUi.hbox(8)
	hn.add_child(_lbl("NAME", 15))
	hn.add_child(name)
	v.add_child(hn)
	for k in ["master", "music", "sfx", "voice", "ambience"]:
		var h := PartyUi.hbox(8)
		var l := _lbl(k.to_upper(), 14)
		l.custom_minimum_size = Vector2(110, 0)
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Settings.get_v(k))
		sl.custom_minimum_size = Vector2(260, 30)
		sl.value_changed.connect(func(x): Settings.set_v(k, x))
		h.add_child(sl)
		v.add_child(h)
	var hq := PartyUi.hbox(8)
	v.add_child(hq)
	var q := _btn("GRAPHICS: " + Settings.QUALITY[int(Settings.get_v("quality"))], func(): pass, 40, 220)
	q.pressed.connect(func():
		Settings.set_v("quality", (int(Settings.get_v("quality")) + 1) % 3)
		q.text = "GRAPHICS: " + Settings.QUALITY[int(Settings.get_v("quality"))])
	hq.add_child(q)
	var f := _btn("FRAME RATE: %d" % int(Settings.get_v("fps")), func(): pass, 40, 180)
	f.pressed.connect(func():
		Settings.set_v("fps", 30 if int(Settings.get_v("fps")) == 60 else 60)
		f.text = "FRAME RATE: %d" % int(Settings.get_v("fps")))
	hq.add_child(f)
	var relay := LineEdit.new()
	relay.text = str(Settings.get_v("relay_url"))
	relay.placeholder_text = Settings.relay_url()
	relay.custom_minimum_size = Vector2(320, 40)
	relay.text_changed.connect(func(t): Settings.set_v("relay_url", t.strip_edges()))
	var hr := PartyUi.hbox(8)
	hr.add_child(_lbl("RELAY", 14))
	hr.add_child(relay)
	v.add_child(hr)
	v.add_child(_btn("BACK", menu, 40))



func _btn(text: String, cb: Callable, min_h := 40, min_w := 120) -> Button:
	return PartyUi.button(text, cb, PartyUi.CREAM, float(min_w) * 1.3, 18)


func _pbtn(text: String, cb: Callable, min_h := 48, min_w := 200) -> Button:
	return PartyUi.button(text, cb, PartyUi.YELLOW, float(min_w) * 1.3, 22)


func _lbl(text: String, size := 14, color := PartyUi.INK, title := false) -> Label:
	return PartyUi.label(text, int(size * 1.3), color, title)
