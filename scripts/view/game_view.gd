class_name GameView
extends Node
## A match on screen. The robot's party in the slaughterhouse (the Hall, dressed by
## PartyVenue); you at the operating table with the others; MURDERLAND on it (the board
## diorama), with the Caller's mechanical head and arms in the table (TableCaller); the
## meat puppets on the board; the minigames off in their own arenas (ArenaWorld), where the
## puppets go to play them; the special events played in person (FULL_CHARACTER).
##
## It follows the views Net sends (host, offline or client alike): moves and animates the
## puppets and the people (BodyAnimator: the AnimationEventManager is _animate()), plays the
## Caller, asks the CameraDirector for shots, stages cutscenes, swaps minigame views in and
## out, walks you round the facility in first person when you get up, and turns local
## input (touch, keys, pads) into actions for this device's seats.

const TABLE_SCALE := 0.085
const PUPPET_SCALE := 0.9
## The board is its own place (not a model on the table): MURDERLAND, full size.
const BOARD_POS := Vector3(0, 0, -160)
const ARENA_POS := Vector3(80, 0, 0)
const FP_SPEED := 2.6
const EYE := 1.6

signal leave_requested
signal lobby_requested

var stage: Stage
var table: Node3D
var venue: MurderlandBoard
var graph: BoardGraph
var caller: CallerActor
var robot: TableCaller
var contestants: Dictionary = {}
var guests: Dictionary = {}
var anims: Dictionary = {}          # seat -> BodyAnimator (puppet)
var guest_anims: Dictionary = {}    # seat -> BodyAnimator (person)
var hud: Hud
var mgv: MgView
var arena_root: Node3D
var arena: ArenaWorld
var director := CameraDirector.new()
var view: Dictionary = {}
var dice: LcDice3D
var _phase := ""
var _move_sent: Dictionary = {}
var _move_t := 0.0
var _deaths_shown: Dictionary = {}
var look_mode := "board"
var _drag := Vector2.ZERO
var _dragging := false
var _ghost_t: Dictionary = {}
var _robot_idle := 0.0
var _walking: Dictionary = {}       # seat -> [spaces to walk through]
var _walk_t: Dictionary = {}
# first person
var fp_pos := Vector2.ZERO
var fp_yaw := PI
var fp_pitch := -0.1
var _fp_active := false
var _fp_send := 0.0
var _fp_look_drag := false
var _last_area := ""
var _cutscene_id := ""
var _dbg_t := 0.0


func _ready() -> void:
	stage = Stage.new()
	add_child(stage)
	stage.set_internal_height(Settings.screen_lines() if Settings.screen_lines() > 0 else 540)
	stage.party_look()
	var hall := stage.hall
	table = Node3D.new()
	table.name = "Murderland"
	table.scale = Vector3.ONE * TABLE_SCALE
	table.position = BOARD_POS
	hall.add_child(table)
	graph = BoardGraph.load_board()
	venue = MurderlandBoard.new()
	table.add_child(venue)
	venue.build(graph)
	robot = TableCaller.new()
	table.add_child(robot)
	robot.scale = Vector3.ONE * 1.8
	robot.build([Vector3(-4.0, 0, 0), Vector3(4.0, 0, 0)])
	caller = CallerActor.wrap(hall.caller)
	hall.add_child(caller)
	dice = LcDice3D.new()
	dice.setup(6, Color("fff4dc"), Color("ff3b3b"), 0.3)
	dice.visible = false
	table.add_child(dice)
	arena_root = Node3D.new()
	arena_root.name = "Arenas"
	arena_root.position = ARENA_POS
	arena_root.scale = Vector3.ONE * TABLE_SCALE
	hall.add_child(arena_root)
	for s in Seats.seats:
		var c := Contestant.new()
		table.add_child(c)
		c.setup(int(s.seat), int(s.face), s.color, str(s.name))
		c.scale = Vector3.ONE * PUPPET_SCALE
		c.place(venue.stand_pos(0, int(s.seat)))
		contestants[int(s.seat)] = c
		_attach_anim(int(s.seat))
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
	director.table_center = on_table(Vector3.ZERO)
	director.table_forward = Vector3(0, 0, 1)
	director.shot_scale = 1.45
	director.room_center = Vector3.ZERO
	if not Net.last_view.is_empty():
		_on_state(Net.last_view, [])


func _attach_anim(seat: int) -> void:
	var c: Contestant = contestants[seat]
	var a := BodyAnimator.new()
	c.add_child(a)
	a.setup(c.human, "puppet", seat)
	anims[seat] = a


func _seat_guests() -> void:
	var me: int = int(Net.my_seats[0]) if not Net.my_seats.is_empty() else 0
	for k in Seats.MAX:
		var s: int = (me + k) % Seats.MAX
		if s >= Seats.seats.size():
			continue
		var g := TableGuest.new()
		stage.hall.add_child(g)
		g.setup(s, k, int(Seats.seats[s].face), Seats.seats[s].color)
		guests[s] = g
		if g.human:
			var a := BodyAnimator.new()
			g.add_child(a)
			a.setup(g.human, "full", s)
			guest_anims[s] = a


func on_table(p: Vector3) -> Vector3:
	return table.to_global(p)


func on_arena(p: Vector3) -> Vector3:
	return arena_root.to_global(p)


## Where seat s's chair is, on the floor (hall metres x/z): for getting up.
func seat_floor_pos(s: int) -> Vector2:
	var g: TableGuest = guests.get(s)
	if g:
		return Vector2(g.global_position.x, g.global_position.z)
	return Vector2(0, 1.9)


func _exit_tree() -> void:
	if Net.state.is_connected(_on_state):
		Net.state.disconnect(_on_state)
	Audio.music("")
	Audio.ambience("")


func viewer_body() -> Dictionary:
	if view.is_empty() or Net.my_seats.is_empty():
		return {}
	return view.players[int(Net.my_seats[0])].body


func viewer_sight() -> float:
	var b := viewer_body()
	return Body.sight(b) if not b.is_empty() else 1.0


func shake(amount: float) -> void:
	if Settings.get_v("screen_shake", true) and not Ui.reduced_fx:
		stage.add_shake(amount)


# --- following the view -------------------------------------------------------------------

func _on_state(v: Dictionary, events: Array) -> void:
	var first := view.is_empty()
	view = v
	# the scene first (into or out of an arena), then what happened in it
	if str(v.phase) != _phase:
		_phase_changed(str(v.phase))
	for e in events:
		_event(e)
	for p in v.players:
		var s := int(p.seat)
		var c: Contestant = contestants.get(s)
		if c == null:
			continue
		c.set_body(p.body, p.helmet)
		if anims.has(s):
			anims[s].set_state(p.body, p.statuses, p.ghost)
			anims[s].personality = {"nerve": 0.5, "coop": 0.5, "greed": 0.5}
		var g: TableGuest = guests.get(s)
		if g:
			g.set_body(p.body)
			if guest_anims.has(s):
				guest_anims[s].set_state(p.body, p.statuses, false)
			g.lean_in(v.phase == "turn" and int(v.turn.get("seat", -1)) == s)
			if not p.alive:
				g.die()
			elif str(p.location) == "away" and not Net.my_seats.has(s):
				var pp: Array = p.get("pos", [0, 0])
				g.walk_to(Vector3(float(pp[0]), 0, float(pp[1])))
			elif str(p.location) == "table":
				g.sit_back()
		if not p.alive and not c.dead and not _deaths_shown.has(s):
			_deaths_shown[s] = true
			c.die(str(p.death), on_table(Vector3(0, 3, 0)))
			_ghost_t[s] = 0.1
		if p.ghost and c.is_ghost and mgv == null:
			c.walk_to(venue.stand_pos(int(p.space), s) + Vector3(0, 0.6, 0))
		if first and mgv == null and not c.is_ghost:
			c.place(venue.stand_pos(int(p.space), s))
	caller.set_unrest(float(v.unrest))
	var m: Dictionary = v.get("machines", {})
	if not m.is_empty():
		venue.set_gates(m.get("gates", {}))
		venue.set_parade(int(m.get("parade", -1)))
	venue.set_rat(int(v.get("rat_space", -1)))
	venue.set_traps(v.get("traps", []))
	var pr: Dictionary = v.turn.get("prompt", {})
	if v.phase == "turn" and str(pr.get("kind", "")) == "path":
		var s := int(v.turn.seat)
		venue.show_choices(int(v.players[s].space), pr.options)
	else:
		venue.show_choices(-1, [])
	var alive := 0
	for p in v.players:
		if p.alive:
			alive += 1
	stage.hall.flashboard.set_left("ROUND", "%02d" % int(v.round))
	stage.hall.flashboard.set_right("LEFT", "%02d" % alive, alive <= 1)
	stage.post.set_shader_parameter("dread", clampf(float(v.unrest) / 3.0, 0.0, 1.0) * 0.5)


func _phase_changed(p: String) -> void:
	var was := _phase
	_phase = p
	if p == "mg_intro" and mgv == null:
		_enter_arena()
	if p in ["turn", "ceremony", "ending", "door", "finale"] and mgv != null:
		_leave_arena()
	if p == "finale":
		robot.play("trophy")
		_robot_idle = 8.0
	if p == "ending":
		var w: Array = view.get("ending_info", {}).get("winners", [])
		for s in contestants:
			if anims.has(s):
				anims[s].play("victory" if w.has(s) else "defeat")
			if guest_anims.has(s):
				guest_anims[s].play("victory" if w.has(s) else "defeat")


## Into the minigame's attraction: its arena is built, the puppets are carried there.
func _enter_arena() -> void:
	var id := str(view.mg_id)
	for c in arena_root.get_children():
		c.queue_free()
	if id != "roulette":
		arena = ArenaWorld.new()
		arena_root.add_child(arena)
		arena.build(ArenaWorld.theme_for(id))
	var script := MinigameRegistry.view_script(id)
	mgv = script.new()
	if id == "roulette":
		# Russian Roulette happens right there on the table
		table.add_child(mgv)
	else:
		arena_root.add_child(mgv)
		mgv.center = Vector3.ZERO
		if str(view.get("presentation", "MEAT_PUPPET")) == "MEAT_PUPPET":
			for s in contestants:
				var c: Contestant = contestants[s]
				c.reparent(arena_root, false)
				c.scale = Vector3.ONE
				c.place(Vector3((int(s) - 1.5) * 1.6, 0, 6.0))
	mgv.setup(self, view)
	# the reveal: a slow look round the attraction before it starts
	director.request("arena", {"pos": on_arena(Vector3(10, 7, 12)), "look": on_arena(Vector3(0, 1, 0)), "fov": 58.0}, 30, 2.5)
	Audio.sfx("bell", 0.0, -4.0, 1.2)


func _leave_arena() -> void:
	if mgv:
		mgv.queue_free()
	mgv = null
	for c in arena_root.get_children():
		if not c is Contestant:
			c.queue_free()
	arena = null
	Audio.music("board")
	for s in contestants:
		var c: Contestant = contestants[s]
		if c.get_parent() != table:
			c.reparent(table, false)
		c.scale = Vector3.ONE * PUPPET_SCALE
		if not c.dead:
			c.sit(false)
			c.rotation = Vector3(0, c.rotation.y, 0)
			c.human.hips.position.y = 0.92
			c.place(venue.stand_pos(int(view.players[s].space), s))
			for j in [c.human.arm_l, c.human.arm_r]:
				j.rotation.x = 0.0
	director.request("overview", {}, 25, 1.5)


# --- the animation event manager: game events to animations, camera, sound ----------------

func _event(e: Dictionary) -> void:
	var kind := str(e.e)
	var s := int(e.get("seat", -1))
	match kind:
		"say":
			hud.say(str(e.text))
			caller.play(str(e.get("gesture", "")))
			caller.set_mood(str(e.get("mood", "")))
			robot.speak(clampf(str(e.text).length() * 0.05, 0.8, 4.0))
			robot.mood(str(e.get("mood", "")))
			var key := str(e.get("key", ""))
			if key.begins_with("space_caller") or key.begins_with("event_") or key.begins_with("rule") or key.begins_with("special") or key in ["final_round", "finale", "award", "machine_warn", "missed_turn", "punch", "death"]:
				robot.emerge()
				_robot_idle = 4.0
			if str(e.get("mood", "")) == "glitch":
				_glitch(0.6)
			caller.speak(clampf(str(e.text).length() * 0.05, 0.8, 4.0))
			Audio.voice(str(e.get("id", "")), str(e.text))
		"toast":
			hud.toast(str(e.text), int(e.get("to", -1)) >= 0)
		"turn":
			if contestants.has(s):
				director.request("intro", {"at": _puppet_at(s)}, 15, 1.6)
				_anim(s, "look_around")
		"roll":
			var c: Contestant = contestants[s]
			_anim(s, "dice_throw")
			dice.visible = true
			var to := c.position + Vector3(0.8, 0.3, 0.8)
			dice.roll_to(int(e.n), c.position + Vector3(0, 2.5, 0), to, 0.9)
			Sfx.play("dice_rattle", -2.0)
			stage.hall.flashboard.light(int(e.n))
			director.request("dice", {"at": _puppet_at(s)}, 18, 1.4)
			get_tree().create_timer(2.4).timeout.connect(func(): dice.visible = false)
		"move":
			var c2: Contestant = contestants[s]
			if e.get("slide", false):
				c2.walk_to(venue.stand_pos(int(e.space), s))
			else:
				c2.walk_to(venue.stand_pos(int(e.space), s))
				Audio.sfx("step", 0.15, -10.0)
			var at := on_table(venue.space_pos(int(e.space)))
			var nxt: Array = graph.next_of(int(e.space))
			var dir := (on_table(venue.space_pos(int(nxt[0]))) - at).normalized() if not nxt.is_empty() else Vector3.ZERO
			director.request("follow", {"at": at, "dir": dir}, 12, 0.9)
		"prompt":
			if str(e.kind) == "path" and contestants.has(s):
				director.request("junction", {"at": _puppet_at(s)}, 16, 20.0)
		"path":
			director.clear("junction")
		"land":
			_anim(s, "land")
			director.request("landing", {"at": _puppet_at(s)}, 14, 1.4)
			var t := str(e.type)
			if t in ["normal", "bonus", "start", "item", "hidden"]:
				_anim(s, "good", false)
			elif t in ["bad", "trap", "punish"]:
				_anim(s, "bad", false)
		"swap":
			for q in [int(e.a), int(e.b)]:
				contestants[q].walk_to(venue.stand_pos(int(view.players[q].space), q))
			robot.play("grab", contestants[int(e.a)].position)
		"teeth":
			if int(e.delta) >= 5:
				_anim(s, "good", false)
			elif int(e.delta) <= -5:
				_anim(s, "bad", false)
		"rats":
			if int(e.delta) > 0:
				_anim(s, "celebrate")
				director.request("award", {"at": _puppet_at(s)}, 20, 1.8)
				Audio.sfx("bell", 0.0, -2.0, 1.6)
			else:
				_anim(s, "disbelief")
		"rat_bought":
			robot.play("dispense", contestants[s].position)
		"item", "give":
			_anim(s, "pickup", false)
			Audio.sfx("unlock", 0.1, -6.0, 1.3)
		"steal":
			_anim(s, "taunt")
			_anim(int(e.get("from", -1)), "disbelief")
		"use":
			Audio.sfx("heal", 0.1, -4.0)
			if str(e.item) in ["antidote", "first_aid", "bandage", "surgery", "painkillers"]:
				_anim(s, "inject" if str(e.item) == "antidote" else "relief")
		"buy":
			_anim(s, "good")
			director.request("shop", {"at": _puppet_at(s)}, 12, 1.2)
		"injure":
			_anim(s, "stump" if str(e.status) == "lost" else "hurt")
			Audio.sfx("hurt", 0.15, -2.0)
			if str(e.status) == "lost":
				Audio.sfx("snap", 0.05, 0.0, 0.7)
				shake(0.3)
		"status":
			var react := {"rat_fever": "scratch", "paralytic": "twitch", "blindness": "hands_out", "thinner": "flinch", "hallucinogen": "look_around",
				"stimulant": "dance", "necrosis": "stagger", "memory": "shrug", "hunger": "clutch_stomach", "cure": "relief"}.get(str(e.id), "cough")
			_anim(s, "drink")
			_anim(s, react, false)
			director.request("poison", {"at": _puppet_at(s)}, 18, 1.8)
		"revive":
			_rebuild(s, false)
			_anim(s, "rise")
			Sfx.play("relic_found", -2.0)
			stage.flash(0.15)
			director.request("resurrection", {"at": _puppet_at(s)}, 22, 2.2)
		"sacrifice":
			Audio.sfx("slam", 0.0, 2.0, 0.6)
			shake(0.6)
			_glitch(0.8)
			robot.play("seizure")
		"caught":
			Audio.sfx("slam", 0.05, 0.0)
			stage.flash(0.25)
			shake(0.4)
			caller.look(guests[s].global_position + Vector3(0, 1.2, 0) if guests.has(s) else "you")
			robot.play("angry")
			_robot_idle = 3.0
		"leave":
			var g: TableGuest = guests.get(s)
			if g:
				g.get_up()
			if Net.my_seats.has(s) and e.has("pos"):
				fp_pos = Vector2(float(e.pos[0]), float(e.pos[1]))
				fp_yaw = atan2(fp_pos.x, fp_pos.y)
		"sit":
			var g2: TableGuest = guests.get(s)
			if g2:
				g2.sit_back()
		"attention":
			stage.post.set_shader_parameter("gaze", 0.35 if e.watching and Net.my_seats.has(int(e.target)) else 0.0)
			if not e.watching:
				caller.look(str(e.at) if str(e.at) in ["clock", "tv", "exit", "ceiling", "floor", "drink"] else "exit")
			else:
				caller.look("you")
		"death":
			_ghost_t[s] = 3.2
			_deaths_shown[s] = true
			contestants[s].die(str(e.anim), on_table(Vector3(0, 3, 0)))
			if guest_anims.has(s):
				guest_anims[s].play("collapse")
			shake(0.5)
			stage.flash(0.35)
			Sfx.play("death", -2.0)
			Audio.duck(2.0)
			director.request("death", {"at": _puppet_at(s)}, 26, 2.6)
			for q in guest_anims:
				if q != s:
					guest_anims[q].play(["panic", "disgust", "disbelief"][q % 3], false)
		"helmet":
			Audio.sfx("kick", 0.05, 0.0)
		"gate", "machine_warn":
			venue.flash_console()
			robot.play("excited")
			_robot_idle = 3.0
			director.request("machine", {"at": on_table(Vector3(0, 0.5, 0))}, 17, 2.2)
			Audio.sfx("door", 0.0, -6.0, 0.8)
		"parade":
			Audio.sfx("bell", 0.0, -12.0, 1.8)
		"encounter":
			if str(e.id) == "roulette":
				robot.play("roulette", contestants[int(view.turn.seat)].position if contestants.has(int(view.turn.get("seat", -1))) else Vector3.INF)
		"cutscene":
			_cutscene(e)
		"cutscene_impact":
			pass
		"cutscene_end":
			director.clear("cutscene")
		"results":
			_results(e)
		"finale":
			director.request("board_wide", {"at": on_table(Vector3.ZERO)}, 20, 6.0)
		"award":
			for q in e.seats:
				_anim(int(q), "victory")
		"lead_change":
			_anim(s, "celebrate")
		"door_open":
			pass
		"unrest":
			caller.play("glitch")
			_glitch(1.0)
		"escaped":
			if guest_anims.has(s):
				guest_anims[s].play("relief")
	if mgv:
		mgv.on_event(e)


func _puppet_at(s: int) -> Vector3:
	if not contestants.has(s):
		return on_table(Vector3.ZERO)
	return (contestants[s] as Node3D).global_position + Vector3(0, 0.08, 0)


func _anim(s: int, name: String, now := true) -> void:
	if anims.has(s):
		anims[s].play(name, now)


## A forced cutscene: everyone's camera goes to the target; they act it out; the others react.
func _cutscene(e: Dictionary) -> void:
	_cutscene_id = str(e.id)
	var s := int(e.target)
	var full := str(e.mode) == "FULL_CHARACTER" and guests.has(s)
	var at: Vector3 = (guests[s] as Node3D).global_position + Vector3(0, 1.1, 0) if full else _puppet_at(s)
	director.request("cutscene", {"at": at, "back": 0.9 if full else 0.6, "height": 0.35 if full else 0.45}, 40, float(e.length))
	var fx := str(e.effect)
	var clip := {"poison": "drink", "injure": "flinch", "kill": "panic", "teeth": "celebrate", "rats": "celebrate", "revive": "rise", "heal": "relief"}.get(fx, "look_around")
	if full and guest_anims.has(s):
		guest_anims[s].play(clip)
	_anim(s, clip)
	robot.play("stare" if fx in ["kill", "poison", "injure"] else "excited", contestants[s].position if contestants.has(s) else Vector3.INF)
	_robot_idle = float(e.length) + 1.0
	for q in guest_anims:
		if q != s:
			guest_anims[q].look_at = at
			guest_anims[q].play("disgust" if fx in ["poison", "injure", "kill"] else "clap", false)


## Minigame results: freeze, then each puppet's own reaction (placement, team, the game).
func _results(e: Dictionary) -> void:
	var winners: Array = e.get("winners", [])
	var draw: bool = e.get("draw", false)
	var pl: Array = e.get("placings", [])
	var last: Array = pl[pl.size() - 1] if pl.size() > 1 else []
	for s in contestants:
		if not view.players[s].alive:
			continue
		if draw:
			_anim(s, "shrug")
		elif winners.has(s):
			_anim(s, "victory")
		elif last.has(s):
			_anim(s, {"floor_is_meat": "fall", "spin_cycle": "stagger", "tug_of_war": "fall", "last_man_breathing": "collapse", "dont_press_it": "panic"}.get(str(e.id), "defeat"))
		else:
			_anim(s, "defeat")


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
	_robot_idle -= delta
	if _robot_idle <= 0.0 and robot.up and view.get("cutscene", {}).is_empty():
		robot.retract()
	_facility(delta)
	_camera(delta)
	_local_input(delta)
	# name tags only over whoever's turn it is (the cards say who everyone is)
	var cur := int(view.turn.get("seat", -1)) if view.phase == "turn" else -1
	for q in contestants:
		var tag = contestants[q].get("_name_tag")
		if tag:
			tag.visible = q == cur or mgv != null
	if view.phase == "turn":
		var s := int(view.turn.get("seat", -1))
		if contestants.has(s):
			caller.look(contestants[s].global_position + Vector3(0, 1.5, 0))
			robot.look(contestants[s].position)


func _rebuild(seat: int, ghost: bool) -> void:
	var old: Contestant = contestants.get(seat)
	var at := old.position if old else venue.stand_pos(0, seat)
	var parent: Node3D = old.get_parent() if old else table
	if old:
		old.queue_free()
	var s: Dictionary = Seats.seats[seat]
	var c := Contestant.new()
	parent.add_child(c)
	c.setup(seat, int(s.face), s.color, str(s.name))
	c.scale = Vector3.ONE * (PUPPET_SCALE if parent == table else 1.0)
	c.place(Vector3(at.x, 0.05, at.z))
	if ghost:
		c.make_ghost()
	else:
		_deaths_shown.erase(seat)
	contestants[seat] = c
	_attach_anim(seat)
	if not ghost and guests.has(seat):
		var g: TableGuest = guests[seat]
		var slot := g.slot
		g.queue_free()
		var ng := TableGuest.new()
		stage.hall.add_child(ng)
		ng.setup(seat, slot, int(s.face), s.color)
		guests[seat] = ng
		if ng.human:
			var a := BodyAnimator.new()
			ng.add_child(a)
			a.setup(ng.human, "full", seat)
			guest_anims[seat] = a


func set_look(mode: String) -> void:
	look_mode = mode
	if mode == "board":
		stage.set_glance(Vector2.ZERO)


# --- the facility, in first person ---------------------------------------------------------

func _me() -> int:
	return int(Net.my_seats[0]) if not Net.my_seats.is_empty() else -1


func _away() -> bool:
	var me := _me()
	return me >= 0 and not view.is_empty() and str(view.players[me].location) == "away"


func _facility(delta: float) -> void:
	var b: Building = stage.hall.building
	var fac: Dictionary = view.get("facility", {})
	# doors: open the ones the facility says are open
	for id in stage.hall.world.doors.keys():
		var open: bool = (fac.get("open", []) as Array).has(id)
		var leaf: DoorLeaf = stage.hall.world.doors[id]
		if leaf.get_meta("open", false) != open:
			leaf.set_meta("open", open)
			leaf.set_open(open)
			if open:
				b.open_portals[id] = true
			else:
				b.open_portals.erase(id)
	var away := _away()
	if away and not _fp_active:
		_fp_active = true
		var g: TableGuest = guests.get(_me())
		if g:
			g.visible = false
		stage.walk_mode = true
		var me_p: Array = view.players[_me()].get("pos", [0, 0])
		if fp_pos == Vector2.ZERO:
			fp_pos = Vector2(float(me_p[0]), float(me_p[1]))
	elif not away and _fp_active:
		_fp_active = false
		stage.walk_mode = false
		var g2: TableGuest = guests.get(_me())
		if g2:
			g2.visible = true
		fp_pos = Vector2.ZERO
		stage.hall.world.hide_all()
	if not _fp_active:
		return
	# move: the stick (touch), WASD/arrows, a pad
	var mv := Vector2.ZERO
	if hud.fp_stick.visible and hud.fp_stick.value != Vector2.ZERO:
		mv = hud.fp_stick.value
	else:
		mv = InputMap_read("primary")
	var look_pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)) if not Input.get_connected_joypads().is_empty() else Vector2.ZERO
	if look_pad.length() > 0.2:
		fp_yaw -= look_pad.x * delta * 2.4
		fp_pitch = clampf(fp_pitch - look_pad.y * delta * 1.6, -1.2, 1.0)
	if Input.is_physical_key_pressed(KEY_Q):
		fp_yaw += delta * 2.0
	if Input.is_physical_key_pressed(KEY_E):
		fp_yaw -= delta * 2.0
	var fwd := Vector2(-sin(fp_yaw), -cos(fp_yaw))
	var right := Vector2(cos(fp_yaw), -sin(fp_yaw))
	var step := (fwd * -mv.y + right * mv.x) * FP_SPEED * Body.speed(viewer_body()) * delta
	if step.length() > 0.0:
		fp_pos = b.slide(fp_pos, step)
	_fp_send += delta
	if _fp_send >= 0.12:
		Net.send_action(_me(), {"t": "walk", "pos": [fp_pos.x, fp_pos.y], "dt": _fp_send, "yaw": fp_yaw})
		_fp_send = 0.0
	var area := b.area_at(fp_pos)
	if area != _last_area:
		_last_area = area
		stage.hall.world.show_from(area)
	var fy := b.floor_at(fp_pos, area)
	stage._base_pos = Vector3(fp_pos.x, fy + EYE * (0.6 if Body.legs(viewer_body()) < 0.3 else 1.0), fp_pos.y)
	stage.walk_yaw = fp_yaw
	stage.walk_pitch = fp_pitch


## The facility thing in reach (for the HUD's buttons).
func near_thing() -> String:
	if not _fp_active:
		return ""
	var th: Dictionary = view.get("facility", {}).get("things", {})
	var best := ""
	var bd := INF
	for id in th.keys():
		var p: Array = th[id].pos
		var d := fp_pos.distance_to(Vector2(float(p[0]), float(p[1])))
		if d <= float(th[id].r) + 0.4 and d < bd:
			bd = d
			best = id
	return best


func at_table() -> bool:
	return _fp_active and fp_pos.length() <= 2.5


func area_name() -> String:
	var names: Dictionary = view.get("facility", {}).get("areas", {})
	return str(names.get(_last_area, _last_area.to_upper()))


func _unhandled_input(ev: InputEvent) -> void:
	if hud.key_input(ev):
		return
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_TAB:
		set_look("room" if look_mode == "board" else "board")
		return
	if _fp_active:
		# drag to look round (touch: the right side of the screen; mouse: any drag)
		if ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
			_fp_look_drag = ev.pressed
		elif (ev is InputEventScreenDrag or (ev is InputEventMouseMotion and _fp_look_drag)):
			fp_yaw -= ev.relative.x * 0.006
			fp_pitch = clampf(fp_pitch - ev.relative.y * 0.005, -1.2, 1.0)
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ENTER:
			var nt := near_thing()
			if nt != "":
				var acts: Array = view.facility.things[nt].actions
				if not acts.is_empty():
					Net.send_action(_me(), {"t": "interact", "id": nt, "do": acts[0].id})
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
	if Ui.reduced_fx:
		amount *= 0.3
	var tw := create_tween()
	tw.tween_method(func(v): stage.post.set_shader_parameter("glitch", v), amount, 0.0, 0.7)


## The base shot for what's going on (the director plays requests over it).
func _camera(delta: float) -> void:
	if _fp_active:
		director.set_base("fp", {"pos": stage._base_pos, "look": stage._base_pos + Vector3(-sin(fp_yaw), 0, -cos(fp_yaw))})
		director.update(delta)
		stage._apply_camera()
		return
	var ph := str(view.phase)
	if ph in ["intro", "finale", "ending", "door", "ceremony"]:
		if ph in ["finale", "ending"]:
			director.set_base("overview", {})
		else:
			director.set_base("stage", {"pos": Vector3(0, 1.45, 1.9), "look": Vector3(0, 2.0, -5.6), "fov": 52.0})
	elif mgv and ph in ["mg_intro", "mg_play", "mg_results"]:
		var c := mgv.camera()
		var root: Node3D = mgv.get_parent() as Node3D
		var look := root.to_global(c[1])
		var dist: float = float(c[2]) if c.size() > 2 else 1.05
		director.set_base("arena", {"pos": look + Vector3(0, dist * 0.85, dist * 0.8), "look": look, "fov": 50.0})
	elif look_mode == "room":
		director.set_base("room", {"pos": Vector3(0, 1.58, 1.95), "look": Vector3(0, 0.95, -1.5), "fov": 60.0})
	else:
		director.set_base("overview", {})
	var shot := director.update(delta)
	_dbg_t += delta
	if OS.is_debug_build() and OS.get_environment("MP_CAMDEBUG") != "" and _dbg_t > 1.0:
		_dbg_t = 0.0
		var c0: Node3D = contestants[0]
		print("CAM ", ph, " ", director.debug_text, " walk ", stage.walk_mode, " fp ", _fp_active, " p0 ", c0.global_position, " parent ", c0.get_parent().name, " cam ", stage.camera.global_position)
	stage._base_pos = shot.pos
	stage._look_at = shot.look
	stage._fov = shot.fov
	stage._apply_camera()


## Movement for local seats in real-time games: each seat's device, ~20 times a second.
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
		if _move_sent.get(s, Vector2(9, 9)) != v:
			_move_sent[s] = v
			Net.send_move(s, v)


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
