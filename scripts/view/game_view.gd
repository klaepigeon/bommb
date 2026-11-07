class_name GameView
extends Node
## A match on screen. You're sat at the Caller's table in the bingo hall (LAST CALL: The
## Campaign's Stage and Hall: its low-resolution render, its ink post-process, its lamps,
## candles, flashboard and rooms). On the table: the board, and the four voodoo dolls.
## Follows the views Net sends (the same on the host, offline, or a client): moves the
## dolls, plays the Caller's lines and gestures, stages deaths, swaps minigame views in and
## out, and turns local input (touch, keyboard, pads) into actions for this device's seats.

const TABLE_SCALE := 0.085

signal leave_requested
signal lobby_requested

var stage: Stage
var table: Node3D               # doll units: everything on the board lives under this
var venue: TableBoard
var caller: CallerActor
var contestants: Dictionary = {}    # seat -> Contestant (the meat puppet on the board)
var guests: Dictionary = {}         # seat -> TableGuest (the person at the table)
var hud: Hud
var mgv: MgView
var view: Dictionary = {}
var dice: LcDice3D
var _phase := ""
var _cam_pos := Vector3(0, 1.62, 1.72)
var _cam_look := Vector3(0, 0.74, -0.12)
var _fov := 52.0
var _shake := 0.0
var _move_sent: Dictionary = {}
var _move_t := 0.0
var _deaths_shown: Dictionary = {}
## The view: "board" (straight down at the board: the default) or "room" (sat up, looking
## at him and the others). Swipe down for the room, up for the board; Tab; the HUD button.
var look_mode := "board"
var _drag := Vector2.ZERO
var _dragging := false
var _ghost_t: Dictionary = {}       # seat -> seconds until their puppet turns into a ghost


func _ready() -> void:
	stage = Stage.new()
	add_child(stage)
	stage.set_internal_height(Settings.screen_lines() if Settings.screen_lines() > 0 else 540)
	var hall := stage.hall
	table = Node3D.new()
	table.name = "MeatParty"
	table.scale = Vector3.ONE * TABLE_SCALE
	hall.board_root.add_child(table)
	venue = TableBoard.new()
	table.add_child(venue)
	venue.build(Assets.load_json("res://assets/data/board.json").get("spaces", []), Net.match_seed)
	caller = CallerActor.wrap(hall.caller)
	hall.add_child(caller)
	dice = LcDice3D.new()
	dice.setup(6, Color("e8dcc0"), Color("8a1a12"), 0.3)
	dice.visible = false
	table.add_child(dice)
	for s in Seats.seats:
		var c := Contestant.new()
		table.add_child(c)
		c.setup(int(s.seat), int(s.face), s.color, str(s.name))
		c.place(venue.stand_pos(0, int(s.seat)))
		contestants[int(s.seat)] = c
	_seat_guests()
	hud = Hud.new()
	add_child(hud)
	hud.act.connect(func(seat, a): Net.send_action(seat, a))
	hud.look_toggled.connect(func(): set_look("room" if look_mode == "board" else "board"))
	hud.leave_pressed.connect(func(): leave_requested.emit())
	hud.lobby_pressed.connect(func(): lobby_requested.emit())
	Net.state.connect(_on_state)
	Audio.music("board")
	Audio.ambience("hall")
	if not Net.last_view.is_empty():
		_on_state(Net.last_view, [])


## The people round the table. Whoever's playing on this screen sits where the camera is;
## everyone else round from there.
func _seat_guests() -> void:
	var me: int = int(Net.my_seats[0]) if not Net.my_seats.is_empty() else 0
	var order: Array = []
	for k in Seats.MAX:
		order.append((me + k) % Seats.MAX)
	for slot in order.size():
		var s: int = order[slot]
		if s >= Seats.seats.size():
			continue
		var g := TableGuest.new()
		stage.hall.add_child(g)
		g.setup(s, slot, int(Seats.seats[s].face), Seats.seats[s].color)
		guests[s] = g


## The table, in hall coordinates (for the camera).
func on_table(p: Vector3) -> Vector3:
	return table.to_global(p)


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
	stage.add_shake(amount)


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
		var g: TableGuest = guests.get(int(p.seat))
		if g:
			g.set_body(p.body)
			g.lean_in(v.phase == "turn" and int(v.turn.get("seat", -1)) == int(p.seat))
			if not p.alive:
				g.die()
		if not p.alive and not c.dead and not _deaths_shown.has(int(p.seat)):
			# joined late or missed it: show them gone
			_deaths_shown[int(p.seat)] = true
			c.die(str(p.death), caller.fig.global_position)
			_ghost_t[int(p.seat)] = 0.1
		if p.ghost and c.is_ghost:
			c.walk_to(venue.stand_pos(int(p.space), int(p.seat)) + Vector3(0, 0.6, 0))
	caller.set_unrest(float(v.unrest))
	if v.key_space != null:
		venue.show_key(int(v.key_space))
	# the flashboard over the stage: the round, and how many are left
	var alive := 0
	for p in v.players:
		if p.alive:
			alive += 1
	stage.hall.flashboard.set_left("ROUND", "%02d" % int(v.round))
	stage.hall.flashboard.set_right("LEFT", "%02d" % alive, alive <= 1)
	# the room reacts: dread with his unrest, red at the edges when he's watching hard
	stage.post.set_shader_parameter("dread", clampf(float(v.unrest) / 3.0, 0.0, 1.0) * 0.8)


func _phase_changed(p: String) -> void:
	var was := _phase
	_phase = p
	if p in ["mg_intro"] and mgv == null:
		var script := MinigameRegistry.view_script(str(view.mg_id))
		mgv = script.new()
		table.add_child(mgv)
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
		for g in guests.values():
			g.stand()
		venue.open_door()
		Audio.music("sting")
		for s in contestants:
			var c: Contestant = contestants[s]
			if not c.dead:
				c.walk_to(venue.door_node.position + Vector3(0.6, 0, -3.0))
		caller.play("panic")


func _event(e: Dictionary) -> void:
	match str(e.e):
		"say":
			hud.say(str(e.text))
			caller.play(str(e.gesture))
			caller.set_mood(str(e.mood))
			var gz := 0.55 if str(e.mood) == "intense" else 0.0
			stage.post.set_shader_parameter("gaze", gz)
			if str(e.mood) == "glitch":
				_glitch(0.6)
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
			var to := c.position + Vector3(0.8, 0.3, 0.8)
			var from := table.to_local(caller.fig.global_position + Vector3(0, 1.2, 0.6))
			dice.roll_to(int(e.n), from, to, 0.9)
			Sfx.play("dice_rattle", -2.0)
			stage.hall.flashboard.light(int(e.n))
			get_tree().create_timer(3.0).timeout.connect(func(): dice.visible = false)
		"revive":
			_rebuild(int(e.seat), false)
			Sfx.play("relic_found", -2.0)
			stage.flash(0.15)
		"sacrifice":
			Audio.sfx("slam", 0.0, 2.0, 0.6)
			shake(0.6)
			_glitch(0.8)
		"caught":
			Audio.sfx("slam", 0.05, 0.0)
			stage.flash(0.25)
			shake(0.4)
			caller.look(guests[int(e.seat)].global_position + Vector3(0, 1.2, 0) if guests.has(int(e.seat)) else "you")
		"leave", "go":
			var g: TableGuest = guests.get(int(e.seat))
			if g and e.has("pos"):
				g.walk_to(Vector3(e.pos[0], 0, e.pos[2]))
			elif g:
				g.get_up()
		"sit":
			var g2: TableGuest = guests.get(int(e.seat))
			if g2:
				g2.sit_back()
		"attention":
			stage.post.set_shader_parameter("gaze", 0.35 if e.watching and Net.my_seats.has(int(e.target)) else 0.0)
			if not e.watching:
				caller.look(str(e.at) if str(e.at) in ["clock", "tv", "exit", "ceiling", "floor", "drink"] else "exit")
			else:
				caller.look("you")
		"death":
			var s := int(e.seat)
			_ghost_t[s] = 3.2
			_deaths_shown[s] = true
			contestants[s].die(str(e.anim), caller.fig.global_position)
			shake(0.5)
			stage.flash(0.35)
			Sfx.play("death", -2.0)
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
			_glitch(1.0)
		"key":
			Audio.sfx("bell", 0.0, -4.0, 1.5)
	if mgv:
		mgv.on_event(e)


func _process(delta: float) -> void:
	for sk in _ghost_t.keys():
		_ghost_t[sk] -= delta
		if _ghost_t[sk] <= 0.0:
			_ghost_t.erase(sk)
			if view.is_empty() or view.players[sk].ghost:
				_rebuild(sk, true)
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


## A dead contestant's puppet, or a revived one: replace it (fresh build, then the view
## puts their injuries back on).
func _rebuild(seat: int, ghost: bool) -> void:
	var old: Contestant = contestants.get(seat)
	var at := old.position if old else venue.stand_pos(0, seat)
	if old:
		old.queue_free()
	var s: Dictionary = Seats.seats[seat]
	var c := Contestant.new()
	table.add_child(c)
	c.setup(seat, int(s.face), s.color, str(s.name))
	c.place(Vector3(at.x, 0.05, at.z))
	if ghost:
		c.make_ghost()
	else:
		_deaths_shown.erase(seat)
	contestants[seat] = c
	if not ghost and guests.has(seat):
		var g: TableGuest = guests[seat]
		var slot := g.slot
		g.queue_free()
		var ng := TableGuest.new()
		stage.hall.add_child(ng)
		ng.setup(seat, slot, int(s.face), s.color)
		guests[seat] = ng


func set_look(mode: String) -> void:
	look_mode = mode
	if mode == "board":
		stage.set_glance(Vector2.ZERO)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_TAB:
		set_look("room" if look_mode == "board" else "board")
		return
	if ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		_dragging = ev.pressed
		_drag = Vector2.ZERO
		if not ev.pressed:
			stage.set_glance(Vector2.ZERO)
	elif (ev is InputEventScreenDrag or (ev is InputEventMouseMotion and _dragging)) and _dragging:
		_drag += ev.relative
		var h := get_viewport().get_visible_rect().size.y
		if _drag.y > h * 0.12 and look_mode == "board":
			set_look("room")
			_drag = Vector2.ZERO
		elif _drag.y < -h * 0.12 and look_mode == "room":
			set_look("board")
			_drag = Vector2.ZERO
		elif look_mode == "room":
			stage.set_glance(Vector2(_drag.x / h * 2.0, -_drag.y / h * 1.5))


func _glitch(amount: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): stage.post.set_shader_parameter("glitch", v), amount, 0.0, 0.7)


## Seated at the table. Leans in over the board for a turn or a game; looks up at him for
## the ceremonies and the door.
## Two ways to look. BOARD (the default): straight down over the board (or the game on
## it), from your side, so you can read it. ROOM: sat up in your chair (his stage, the
## others round the table; drag to look round). His big moments, and you getting up from
## the table, take you to the room whatever you'd picked.
func _camera(delta: float) -> void:
	var want_pos := Vector3(0, 2.28, 0.42)
	var want_look := Vector3(0, 0.78, -0.03)
	var fov := 50.0
	var me: int = int(Net.my_seats[0]) if not Net.my_seats.is_empty() else -1
	var me_v: Dictionary = view.players[me] if me >= 0 and me < view.players.size() else {}
	var forced := ""
	if view.phase in ["ceremony", "door", "intro"]:
		forced = "stage"
	elif view.phase == "ending" and view.ending == "escape":
		forced = "door"
	elif not me_v.is_empty() and str(me_v.get("location", "table")) not in ["table"] and view.phase == "turn":
		forced = "walk"
	if forced == "stage":
		want_pos = Vector3(0, 1.45, 1.72)
		want_look = Vector3(0, 2.0, -5.6)
	elif forced == "door":
		want_look = on_table(venue.door_node.position + Vector3(0.6, 1.0, 0))
		want_pos = want_look + Vector3(0, 0.25, 0.7)
	elif forced == "walk":
		var g: TableGuest = guests.get(me)
		var at := g.global_position if g else Vector3.ZERO
		want_look = at + Vector3(0, 1.0, 0) + (at - Vector3(0, 0, 0)).normalized() * 0.8
		want_pos = at + Vector3(0, 1.65, 0) - (at - Vector3(0, 0, 0)).normalized() * 0.6
		fov = 62.0
	elif look_mode == "room":
		want_pos = Vector3(0, 1.58, 1.62)
		want_look = Vector3(0, 0.95, -1.5)
		fov = 60.0
	elif mgv:
		var c := mgv.camera()
		want_look = on_table(c[1])
		var dist: float = float(c[2]) if c.size() > 2 else 1.05
		want_pos = want_look + Vector3(0, dist * 1.05, dist * 0.32)
		fov = 52.0
	var k := minf(1.0, delta * 2.4)
	_cam_pos = _cam_pos.lerp(want_pos, k)
	_cam_look = _cam_look.lerp(want_look, k)
	_fov = lerpf(_fov, fov, k)
	stage._base_pos = _cam_pos
	stage._look_at = _cam_look
	stage._fov = _fov
	stage._apply_camera()


## Movement for local seats in real-time games: each seat's device (touch stick, a
## keyboard block, a pad), sent ~20 times a second when it changes.
func _local_input(delta: float) -> void:
	if not (view.phase == "mg_play" and (view.mg_id == "musical_chairs" or view.mg.get("arena", false))):
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
