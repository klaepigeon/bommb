class_name GameView
extends Node3D
## A match on screen. Builds the hall, the Caller and the contestants, then follows the
## views Net sends (the same on the host, offline, or a client): moves people, plays the
## Caller's lines and gestures, stages deaths, swaps minigame views in and out, and turns
## local input (touch, keyboard, pads) into actions for this device's seats.

signal leave_requested
signal lobby_requested

var venue: Venue
var caller: CallerActor
var contestants: Dictionary = {}    # seat -> Contestant
var cam: Camera3D
var hud: Hud
var mgv: MgView
var view: Dictionary = {}
var dice: LcDice3D
var _phase := ""
var _cam_pos := Vector3(0, 12, 13)
var _cam_look := Vector3.ZERO
var _shake := 0.0
var _move_sent: Dictionary = {}
var _move_t := 0.0
var _retro: RetroScreen
var _deaths_shown: Dictionary = {}


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a0c18")
	env.environment = e
	add_child(env)
	venue = Venue.new()
	add_child(venue)
	venue.build(Assets.load_json("res://assets/data/board.json").get("spaces", []))
	caller = CallerActor.new()
	caller.scale = Vector3.ONE * 1.3
	caller.position = venue.caller_spot()
	caller.rotation.y = -0.6
	add_child(caller)
	dice = LcDice3D.new()
	dice.setup(6, Color("e8dcc0"), Color("8a1a12"), 0.22)
	dice.visible = false
	add_child(dice)
	for s in Seats.seats:
		var c := Contestant.new()
		add_child(c)
		c.setup(int(s.seat), int(s.face), s.color, str(s.name))
		c.place(venue.stand_pos(0, int(s.seat)))
		contestants[int(s.seat)] = c
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 80
	add_child(cam)
	cam.current = true
	cam.position = _cam_pos
	cam.look_at(Vector3.ZERO)
	hud = Hud.new()
	add_child(hud)
	hud.act.connect(func(seat, a): Net.send_action(seat, a))
	hud.leave_pressed.connect(func(): leave_requested.emit())
	hud.lobby_pressed.connect(func(): lobby_requested.emit())
	Net.state.connect(_on_state)
	RetroScreen.lines = Settings.screen_lines()
	_retro = RetroScreen.install(self)
	Audio.music("board")
	Audio.ambience("hall")
	if not Net.last_view.is_empty():
		_on_state(Net.last_view, [])


func _exit_tree() -> void:
	if Net.state.is_connected(_on_state):
		Net.state.disconnect(_on_state)
	Audio.music("")
	Audio.ambience("")


## The body of whoever is looking at this screen (their eyes and ears colour the tells).
func viewer_body() -> Dictionary:
	if view.is_empty() or Net.my_seats.is_empty():
		return {}
	return view.players[int(Net.my_seats[0])].body


func viewer_sight() -> float:
	var b := viewer_body()
	return Body.sight(b) if not b.is_empty() else 1.0


func shake(amount: float) -> void:
	if Settings.get_v("screen_shake", true):
		_shake = maxf(_shake, amount)


func _on_state(v: Dictionary, events: Array) -> void:
	view = v
	for e in events:
		_event(e)
	if str(v.phase) != _phase:
		_phase_changed(str(v.phase))
	for p in v.players:
		var c: Contestant = contestants.get(int(p.seat))
		if c == null:
			continue
		c.set_body(p.body, p.helmet)
		if not p.alive and not c.dead and not _deaths_shown.has(int(p.seat)):
			# joined late or missed it: show them gone
			_deaths_shown[int(p.seat)] = true
			c.die(str(p.death), caller.global_position)
	caller.set_unrest(float(v.unrest))
	if v.key_space != null:
		venue.show_key(int(v.key_space))


func _phase_changed(p: String) -> void:
	var was := _phase
	_phase = p
	if p in ["mg_intro"] and mgv == null:
		var script := MinigameRegistry.view_script(str(view.mg_id))
		mgv = script.new()
		add_child(mgv)
		mgv.setup(self, view)
	if p in ["turn", "ceremony", "ending", "door"] and mgv != null:
		mgv.queue_free()
		mgv = null
		Audio.music("board")
		for s in contestants:
			var c: Contestant = contestants[s]
			if not c.dead:
				c.sit(false)
				c.rotation = Vector3(0, c.rotation.y, 0)
				c.human.hips.position.y = 0.92
				c.walk_to(venue.stand_pos(int(view.players[s].space), s))
				for j in [c.human.arm_l, c.human.arm_r]:
					j.rotation.x = 0.0
	if p == "ending" and view.ending == "escape":
		venue.open_door()
		Audio.music("sting")
		for s in contestants:
			var c: Contestant = contestants[s]
			if not c.dead:
				c.walk_to(Venue.DOOR + Vector3(0, 0, -2.5))
		caller.play("panic")


func _event(e: Dictionary) -> void:
	match str(e.e):
		"say":
			hud.say(str(e.text))
			caller.play(str(e.gesture))
			caller.set_mood(str(e.mood))
			caller.speak(clampf(str(e.text).length() * 0.05, 0.8, 4.0))
			Audio.voice(str(e.get("id", "")), str(e.text))
		"toast":
			hud.toast(str(e.text), int(e.get("to", -1)) >= 0)
		"move":
			var c: Contestant = contestants[int(e.seat)]
			c.walk_to(venue.stand_pos(int(e.space), int(e.seat)))
			Audio.sfx("step", 0.15, -10.0)
		"swap":
			for s in [int(e.a), int(e.b)]:
				contestants[s].walk_to(venue.stand_pos(int(view.players[s].space), s))
		"roll":
			var c: Contestant = contestants[int(e.seat)]
			dice.visible = true
			var to := c.position + Vector3(0.6, 0.25, 0.6)
			dice.roll_to(int(e.n), caller.global_position + Vector3(0, 2.0, 0), to, 0.9)
			Audio.sfx("dice_clack", 0.1, 0.0)
			get_tree().create_timer(3.0).timeout.connect(func(): dice.visible = false)
		"death":
			var s := int(e.seat)
			_deaths_shown[s] = true
			contestants[s].die(str(e.anim), caller.global_position)
			shake(0.5)
			Audio.duck(2.0)
		"injure":
			Audio.sfx("hurt", 0.15, -2.0)
			if str(e.status) == "lost":
				Audio.sfx("snap", 0.05, 0.0, 0.7)
				shake(0.3)
		"item", "give", "steal":
			Audio.sfx("unlock", 0.1, -6.0, 1.3)
		"use":
			Audio.sfx("heal", 0.1, -4.0)
		"helmet":
			Audio.sfx("kick", 0.05, 0.0)
		"door_open":
			venue.open_door()
		"door":
			Audio.sfx("door", 0.0, 0.0, 0.7)
			caller.play("panic")
		"ceremony":
			caller.play("beckon")
			caller.play("hatch")
		"unrest":
			caller.play("glitch")
		"key":
			Audio.sfx("bell", 0.0, -4.0, 1.5)
	if mgv:
		mgv.on_event(e)


func _process(delta: float) -> void:
	if view.is_empty():
		return
	hud.update(view, Net.my_seats, delta)
	if mgv:
		mgv.update_view(view, delta)
	_camera(delta)
	_local_input(delta)
	# the Caller watches whoever's turn it is
	if view.phase == "turn":
		var s := int(view.turn.get("seat", -1))
		if contestants.has(s):
			caller.look(contestants[s].global_position + Vector3(0, 1.5, 0))
		elif randf() < delta * 0.1:
			caller.play("look_door")
	elif view.phase == "door":
		caller.look("exit")


func _camera(delta: float) -> void:
	var want_pos := Vector3(0, 12.5, 13.5)
	var want_look := Vector3(0, 0, 0.5)
	if mgv:
		var c := mgv.camera()
		want_pos = c[0]
		want_look = c[1]
	elif view.phase == "turn":
		var s := int(view.turn.get("seat", -1))
		if contestants.has(s):
			var p: Vector3 = contestants[s].position
			want_look = p * 0.45 + Vector3(0, 0.5, 0)
			want_pos = want_look + Vector3(0, 9.0, 10.0)
	elif view.phase in ["ceremony", "door"]:
		want_look = caller.global_position + Vector3(-2, 1.0, 0)
		want_pos = want_look + Vector3(-1, 4.0, 7.5)
	_cam_pos = _cam_pos.lerp(want_pos, minf(1.0, delta * 2.5))
	_cam_look = _cam_look.lerp(want_look, minf(1.0, delta * 2.5))
	_shake = maxf(0.0, _shake - delta * 1.5)
	var j := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.3
	cam.position = _cam_pos + j
	cam.look_at(_cam_look, Vector3.UP)


## Movement for local seats in real-time games: each seat's device (touch stick, a
## keyboard block, a pad), sent ~20 times a second when it changes.
func _local_input(delta: float) -> void:
	if not (view.phase == "mg_play" and view.mg_id == "musical_chairs"):
		return
	_move_t += delta
	if _move_t < 0.05:
		return
	_move_t = 0.0
	for s in Net.my_seats:
		var dev := str(Seats.seats[s].get("device", "primary")) if Net.role == "offline" else "primary"
		var v := InputMap_read(dev)
		if dev == "primary" and hud.stick.visible and hud.stick.value != Vector2.ZERO:
			v = hud.stick.value
		v = Vector2(v.x, v.y)
		if _move_sent.get(s, Vector2(9, 9)) != v:
			_move_sent[s] = v
			Net.send_move(s, v)


## Read a seat's device: "primary" (WASD, arrows, any pad), "wasd", "arrows", "ijkl", "padN".
static func InputMap_read(dev: String) -> Vector2:
	var v := Vector2.ZERO
	var keys := {"wasd": [KEY_A, KEY_D, KEY_W, KEY_S], "arrows": [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN], "ijkl": [KEY_J, KEY_L, KEY_I, KEY_K]}
	var sets: Array = ["wasd", "arrows"] if dev == "primary" else ([dev] if keys.has(dev) else [])
	for k in sets:
		var ks: Array = keys[k]
		v.x += float(Input.is_physical_key_pressed(ks[1])) - float(Input.is_physical_key_pressed(ks[0]))
		v.y += float(Input.is_physical_key_pressed(ks[3])) - float(Input.is_physical_key_pressed(ks[2]))
	var pads: Array = []
	if dev == "primary":
		pads = Input.get_connected_joypads()
	elif dev.begins_with("pad"):
		pads = [int(dev.substr(3))]
	for p in pads:
		var a := Vector2(Input.get_joy_axis(p, JOY_AXIS_LEFT_X), Input.get_joy_axis(p, JOY_AXIS_LEFT_Y))
		if a.length() > 0.2:
			v += a
		v.x += float(Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_LEFT))
		v.y += float(Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_UP))
	return v.limit_length(1.0)
