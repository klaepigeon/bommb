extends Node
## The app: one screen at a time (menu, settings, setup, online, lobby, match). Screens
## are plain Controls built in code with UiKit; the match is a GameView.

var screen: Node
var _ui: Control
var _status: Label
var _lobby_box: VBoxContainer


func _ready() -> void:
	get_tree().root.theme = UiKit.theme()
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
	add_child(n)


func _page(title: String) -> VBoxContainer:
	var c := Control.new()
	c.theme = UiKit.theme()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swap(c)
	UiKit.bg(c)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	c.add_child(m)
	var v := UiKit.vbox(8)
	m.add_child(v)
	v.add_child(UiKit.label(title, 26, UiKit.GOLD, true))
	_ui = c
	return v


func _toast(t: String) -> void:
	if _status:
		_status.text = t


# --- main menu ----------------------------------------------------------------------

func menu() -> void:
	Audio.music("board")
	var c := Control.new()
	c.theme = UiKit.theme()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swap(c)
	# the Caller waits behind the menu
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(vpc)
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vpc.add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1e1028")
	w.add_child(env)
	var cl := CallerActor.new()
	cl.position = Vector3(1.2, -0.2, 0)
	cl.rotation.y = -0.35
	w.add_child(cl)
	var cam := Camera3D.new()
	cam.position = Vector3(0.2, 1.9, 4.2)
	w.add_child(cam)
	cam.look_at(Vector3(0.6, 1.6, 0))
	Lamp.create(w, Vector3(0.5, 3.0, 1.5), Color(1, 0.6, 0.7), 0.9, 6.0)
	var t := Timer.new()
	t.wait_time = 2.6
	t.autostart = true
	t.timeout.connect(func(): cl.play(["wave", "spread", "dance", "tip_hat", "beckon", "conduct", "laugh", "look_door", "head_spin"][randi() % 9]))
	c.add_child(t)
	var v := UiKit.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = 24
	v.offset_right = 270
	v.offset_top = 24
	c.add_child(v)
	v.add_child(UiKit.label("MEAT PARTY", 30, UiKit.HOT, true))
	v.add_child(UiKit.label("hosted by THE CALLER", 13, UiKit.GOLD))
	var b := UiKit.button("PLAY (vs. AI)", single, 40)
	v.add_child(b)
	b.grab_focus.call_deferred()
	v.add_child(UiKit.button("LOCAL PARTY (2-4)", local_setup, 40))
	v.add_child(UiKit.button("ONLINE", online, 40))
	v.add_child(UiKit.button("SETTINGS", settings, 40))
	if not OS.has_feature("mobile"):
		v.add_child(UiKit.button("QUIT", func(): get_tree().quit(), 36))
	_status = UiKit.label("", 12, UiKit.TEAL)
	v.add_child(_status)


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
	v.add_child(UiKit.label("Phones and PCs can share a room. On the same Wi-Fi, a room is found by its code. Over the internet, rooms go through the relay (%s)." % Settings.relay_url(), 12, UiKit.DIM))
	var h := UiKit.hbox(8)
	v.add_child(h)
	h.add_child(UiKit.button("HOST ON THIS NETWORK", func():
		if Net.host_lan() == OK:
			lobby(), 46, 200))
	h.add_child(UiKit.button("HOST OVER THE INTERNET", func():
		if Net.host_relay() == OK:
			lobby(), 46, 200))
	var code := LineEdit.new()
	code.placeholder_text = "ROOM CODE"
	code.max_length = 5
	code.custom_minimum_size = Vector2(160, 44)
	var ip := LineEdit.new()
	ip.placeholder_text = "or an address (192.168.1.20)"
	ip.custom_minimum_size = Vector2(240, 44)
	var h2 := UiKit.hbox(8)
	v.add_child(h2)
	h2.add_child(code)
	h2.add_child(UiKit.button("JOIN", func():
		if code.text.strip_edges() != "":
			Net.join_code(code.text)
			lobby(), 44))
	var h3 := UiKit.hbox(8)
	v.add_child(h3)
	h3.add_child(ip)
	h3.add_child(UiKit.button("JOIN ADDRESS", func():
		if ip.text.strip_edges() != "":
			var parts := ip.text.strip_edges().split(":")
			Net.join_ip(parts[0], int(parts[1]) if parts.size() > 1 else 0)
			lobby(), 44, 140))
	_status = UiKit.label("", 13, UiKit.TEAL)
	v.add_child(_status)
	v.add_child(UiKit.button("BACK", menu, 40))


# --- the lobby (every mode) --------------------------------------------------------------

func lobby() -> void:
	var v := _page("THE GREEN ROOM")
	_status = UiKit.label("", 13, UiKit.TEAL)
	v.add_child(_status)
	if Net.online():
		_status.text = "Room code: %s" % Net.code if Net.code != "" else "Connecting..."
	_lobby_box = UiKit.vbox(6)
	v.add_child(_lobby_box)
	_fill_lobby()


func _fill_lobby() -> void:
	if _lobby_box == null:
		return
	for c in _lobby_box.get_children():
		c.queue_free()
	var authority := Net.is_authority()
	if Net.online() and Net.code != "":
		_lobby_box.add_child(UiKit.label("ROOM  %s" % Net.code, 28, UiKit.GOLD, true))
	for s in Seats.seats:
		var h := UiKit.hbox(8)
		_lobby_box.add_child(h)
		var face := TextureRect.new()
		face.texture = Assets.face_texture(int(s.face))
		face.custom_minimum_size = Vector2(28, 34)
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
		var l := UiKit.label("%d. %s" % [int(s.seat) + 1, desc], 15, (s.color as Color).lightened(0.3) if s.kind != "empty" else UiKit.DIM)
		l.custom_minimum_size = Vector2(300, 0)
		h.add_child(l)
		var seat := int(s.seat)
		if authority and s.kind in ["empty", "ai"]:
			h.add_child(UiKit.button("REMOVE AI" if s.kind == "ai" else "ADD AI", func():
				Net.toggle_ai(seat)
				_fill_lobby(), 34, 110))
		if Seats.mode == "local" and s.kind == "empty":
			h.add_child(UiKit.button("ADD PLAYER", func():
				Seats.set_seat(seat, {"kind": "local", "name": "PLAYER %d" % (seat + 1), "device": DEVICES[mini(seat + 1, DEVICES.size() - 1)], "face": seat, "ready": true})
				_fill_lobby(), 34, 120))
		if Seats.mode == "local" and s.kind == "local":
			h.add_child(UiKit.button("CONTROLS", func():
				var d := DEVICES.find(str(s.get("device", "primary")))
				Seats.seats[seat].device = DEVICES[(d + 1) % DEVICES.size()]
				_fill_lobby(), 34, 100))
			if seat > 0:
				h.add_child(UiKit.button("X", func():
					Seats.clear_seat(seat)
					_fill_lobby(), 34, 40))
		if s.kind == "local" or (s.kind == "remote" and Net.my_seats.has(seat)):
			h.add_child(UiKit.button("FACE", func():
				Seats.seats[seat].face = (int(Seats.seats[seat].face) + 1) % Assets.face_count()
				if seat == 0:
					Settings.set_v("face", Seats.seats[seat].face)
				_fill_lobby(), 34, 70))
	var row := UiKit.hbox(8)
	_lobby_box.add_child(row)
	if authority:
		var go := UiKit.button("START THE PARTY", func(): Net.launch(), 50, 220)
		go.disabled = not Net.all_ready() or (Net.online() and Net.code in ["", "....."])
		row.add_child(go)
		go.grab_focus.call_deferred()
	elif Net.role == "client" and not Net.my_seats.is_empty():
		var mine: Dictionary = Seats.seats[int(Net.my_seats[0])]
		row.add_child(UiKit.button("NOT READY" if mine.ready else "READY", func():
			Net.set_ready(not mine.ready), 50, 160))
	row.add_child(UiKit.button("LEAVE", func():
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
	var hn := UiKit.hbox(8)
	hn.add_child(UiKit.label("NAME", 15))
	hn.add_child(name)
	v.add_child(hn)
	for k in ["master", "music", "sfx", "voice", "ambience"]:
		var h := UiKit.hbox(8)
		var l := UiKit.label(k.to_upper(), 14)
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
	var hq := UiKit.hbox(8)
	v.add_child(hq)
	var q := UiKit.button("GRAPHICS: " + Settings.QUALITY[int(Settings.get_v("quality"))], func(): pass, 40, 220)
	q.pressed.connect(func():
		Settings.set_v("quality", (int(Settings.get_v("quality")) + 1) % 3)
		q.text = "GRAPHICS: " + Settings.QUALITY[int(Settings.get_v("quality"))])
	hq.add_child(q)
	var f := UiKit.button("FRAME RATE: %d" % int(Settings.get_v("fps")), func(): pass, 40, 180)
	f.pressed.connect(func():
		Settings.set_v("fps", 30 if int(Settings.get_v("fps")) == 60 else 60)
		f.text = "FRAME RATE: %d" % int(Settings.get_v("fps")))
	hq.add_child(f)
	var relay := LineEdit.new()
	relay.text = str(Settings.get_v("relay_url"))
	relay.placeholder_text = Settings.relay_url()
	relay.custom_minimum_size = Vector2(320, 40)
	relay.text_changed.connect(func(t): Settings.set_v("relay_url", t.strip_edges()))
	var hr := UiKit.hbox(8)
	hr.add_child(UiKit.label("RELAY", 14))
	hr.add_child(relay)
	v.add_child(hr)
	v.add_child(UiKit.button("BACK", menu, 40))
