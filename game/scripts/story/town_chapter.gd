class_name TownChapter
extends Node
## The town, as a tutorial that doesn't tell you what to do: get out. The gate's at the top of
## the square, and Marta keeps to it.
##
##   The gun: the revolver in the frozen fight. Taking it wakes her. Shot, she reels; four hits
##   and she drifts off for a while (the gate's free); with Headshot, a shot to the head ends her.
##   Sneaking: she hears. A thrown cobble draws her off; the lever is loud.
##   Talking: every monster here was someone. With the right Memory and what he's read or noticed,
##   Kurt knows who, and he can talk to them as himself. They stop. Marta too.
##
## Socko wants the gun, the nuggets and the headshot, and says so.

signal finished(route: String)

var main: Node
var town: Town
var player: Player
var hud: Hud
var weapon: Weapon
var porter: Monster
var lamplighter: Monster
var marta: MartaHunter
var data := {}
var busy := false
var route := ""
var _said := {}
var _steer_t := 18.0
var _count_t := 45.0
var _in_nursery := false
var _done := false
var _catching := false
var _caught_n := 0

func setup() -> void:
	add_to_group("director")
	var f := FileAccess.open("res://content/town.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	for e in get_tree().get_nodes_in_group("examine"):
		e.connect("used", _read.bind(e))
	for d in get_tree().get_nodes_in_group("sonya_door"):
		d.connect("used", _sonya_door)
	for p in town.pickups:
		var h: Hotspot = p[0]
		h.used.connect(_take.bind(h, String(p[1])))
	town.revolver_spot.used.connect(_take_revolver)
	town.lever_spot.used.connect(_pull_lever)
	var mons: Dictionary = data["monsters"]
	porter = _spawn(Monster, "porter", mons["porter"], town.porter_home, 4, Rect2(52.4, 34.7, 5.9, 6.6))
	porter.rotation.y = -PI * 0.5      # facing the wall of the hotel room, his back to the door
	lamplighter = _spawn(Monster, "lamplighter", mons["lamplighter"], town.lamplighter_path[0], 13, Rect2(4.5, 16.5, 51.0, 7.0))
	lamplighter.wanders = [town.to_global(town.lamplighter_path[0]), town.to_global(town.lamplighter_path[1])]
	lamplighter.speed = 0.8
	marta = _spawn(MartaHunter, "marta", mons["marta"], town.marta_post, 47, Rect2(28.5, 32.5, 27.0, 35.0)) as MartaHunter
	marta.away_point = town.to_global(town.marta_away)
	weapon.fired.connect(_on_fired)
	weapon.reloaded_first.connect(func(): line("reloaded"))
	weapon.emptied.connect(func(): line("empty"))
	Game.skill_bought.connect(_on_bought)

func _spawn(cls, id: String, d: Dictionary, local_at: Vector3, seed: int, local_bounds: Rect2) -> Monster:
	var m: Monster = cls.new()
	m.name = id.capitalize()
	town.add_child(m)
	var at := town.to_global(local_at)
	m.setup(id, d, player, at, seed)
	m.town = town
	m.bounds = local_bounds
	m.caught.connect(_caught)
	m.died.connect(_died)
	m.calmed.connect(_calmed)
	return m

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

## A line, once (unless again is true). Doesn't wait.
func line(id: String, again := false) -> void:
	if _said.has(id) and not again:
		return
	_said[id] = true
	Speech.say_id(id)

func local_pos() -> Vector3:
	return town.to_local(player.global_position)

## Where he comes out of the hole, facing down the lane.
func _to_arrival() -> void:
	var a: Transform3D = town.arrive
	player.global_position = town.to_global(a.origin)
	player.face(town.to_global(a.origin - a.basis.z * 3.0 + Vector3(0, 1.5, 0)))

# --- arriving ----------------------------------------------------------------------------------

func arrive() -> void:
	busy = true
	_to_arrival()
	player.can_move = false
	player.can_look = false
	hud.set_crosshair(false)
	hud.fade_to(0.0, 1.5)
	await wait(1.6)
	# Socko points the way: to the square, and what's in it
	var sk := player.socko
	sk.set_pose("up", 0.5)
	sk.emotion = "happy"
	sk.gesture("bounce", 0.6)
	sk.point_at(town.to_global(town.revolver_at + Vector3(0, 1.0, 0)))
	await wait(2.0)
	sk.point_at(Vector3.INF)
	sk.set_pose("low", 0.8)
	sk.emotion = "neutral"
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)
	busy = false

# --- every frame -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if town == null or not town.visible or _done:
		return
	var lp := local_pos()
	# the street comes round on itself
	var wrapped := town.wrap(lp)
	if wrapped != lp:
		player.global_position = town.to_global(Vector3(wrapped.x, player.global_position.y - town.global_position.y, wrapped.z))
		if not Game.flag("looped"):
			Game.set_flag("looped")
		if Game.owned("these_streets"):
			line("loop_kurt")
			if not _said.has("loop_socko"):
				_said["loop_socko"] = true
				await Speech.line_finished
				line("loop_socko")
	for c in town.chalk:
		c.visible = Game.owned("these_streets")
	# nuggets
	for n in town.nuggets:
		_try_nugget(n)
	# Socko steers to the gun, now and then
	if not Game.has_gun and not busy:
		_steer_t -= delta
		if _steer_t <= 0.0 and Speech.speaking == "":
			_steer_t = 22.0
			Speech.say_id(["steer_1", "steer_2", "steer_3"][randi() % 3])
			player.socko.point_at(town.to_global(town.revolver_at + Vector3(0, 1, 0)))
			get_tree().create_timer(2.0, false).timeout.connect(func(): player.socko.point_at(Vector3.INF))
	# Counting: a girl's voice from the nursery's direction, never in it
	var near_nursery := town.nursery.has_point(Vector2(lp.x, lp.z))
	if near_nursery and not _in_nursery:
		_in_nursery = true
		if not _said.has("nursery"):
			player.socko.emotion = "neutral"
			player.socko.face_kurt = 0.0
			get_tree().create_timer(2.5, false).timeout.connect(func(): line("nursery"))
	elif not near_nursery:
		_in_nursery = false
	if Game.owned("counting") and not near_nursery:
		_count_t -= delta
		if _count_t <= 0.0 and Speech.speaking == "":
			_count_t = 50.0
			Speech.say_id("count")
	if lp.z > 57.0 and lp.x > 28.0 and lp.x < 56.0:
		line("gate_seen")
	if not town.gate_open and lp.z > Town.GATE_Z - 1.6 and lp.x > Town.GATE_X0 and lp.x < Town.GATE_X1:
		line("gate_shut")
	# the gate: through it and out
	if town.gate_open and lp.z > Town.GATE_Z + 2.5 and lp.x > Town.GATE_X0 and lp.x < Town.GATE_X1:
		_leave()

func _try_nugget(n: Nugget) -> void:
	if n.taken or not n.visible:
		return
	if n.global_position.distance_to(player.global_position + Vector3(0, 0.6, 0)) < 0.9:
		n.take()
		Game.add_nuggets(1)
		line("nuggets")
		if Game.nuggets >= 4 and not Game.owned("headshot") and _said.has("nuggets"):
			get_tree().create_timer(4.0, false).timeout.connect(func(): line("enough"))

# --- things ------------------------------------------------------------------------------------

## The town's things to look at (the first build's text): what it is, and with Her Handwriting,
## what's written on the back. Socko waves most of them away, once each.
func _read(e: Node) -> void:
	var title := String(e.get("title"))
	var key := title.to_lower()
	Game.set_flag("read_" + key)
	hud.reader.open({"title": title, "text": String(e.get("desc")), "handwriting": String(e.get("more"))})
	get_tree().paused = true
	await hud.reader.closed
	get_tree().paused = false
	var waves: Dictionary = data.get("socko_on", {})
	if key == "poster" and Game.owned("old_name"):
		line("poster_known")
	elif waves.has(key) and not _said.has("doc_" + key):
		_said["doc_" + key] = true
		Speech.say("socko", String(waves[key]))

func _take(h: Hotspot, kind: String) -> void:
	if not h.enabled:
		return
	if kind == "rock" and weapon.busy:
		return
	h.enabled = false
	var mesh: Node3D = h.get_meta("mesh")
	mesh.visible = false
	match kind:
		"ammo":
			Game.ammo_spare += 7
			Sfx.play("load", -4.0)
		"rock":
			weapon.equip("rock")
			# the cobble comes back, a while later, where it was (there are always more cobbles)
			get_tree().create_timer(20.0, false).timeout.connect(func():
				mesh.visible = true
				h.enabled = true)

func _take_revolver() -> void:
	if Game.has_gun:
		return
	town.revolver_spot.enabled = false
	town.revolver_mesh.visible = false
	Game.ammo_loaded = 3
	weapon.give_gun()
	line("gun")
	get_tree().create_timer(4.0, false).timeout.connect(func(): line("gun_hint"))
	# she's been sitting by the gate the whole time. Now she isn't.
	await wait(3.0)
	if marta.state != Monster.S.CALM and marta.state != Monster.S.DEAD:
		marta.wake()
		marta.listen_to(player.global_position)    # she heard him take it; she comes
		line("marta_here")

func _sonya_door() -> void:
	Sfx.play_at("rattle", town.to_global(Vector3(6.3, 1.4, 63.2)), -4.0, 1.1)
	line("sonya_door")

func _pull_lever() -> void:
	if busy or town.gate_open:
		return
	busy = true
	var n := _caught_n
	player.can_move = false
	player.arm.set_pose("handle", 0.3)
	await wait(0.3)
	player.arm.rattle = 0.6
	Noises.make(town.lever_spot.global_position, 8.0, "lever")
	Sfx.play_at("rattle", town.lever_spot.global_position, 2.0, 0.6)
	await wait(1.6)
	player.arm.rattle = 0.0
	if n != _caught_n:
		return          # she had him before it gave
	town.open_gate()
	weapon.equip(weapon.held)
	player.can_move = true
	busy = false

func _on_fired(_hit: Dictionary) -> void:
	pass

func on_marta_hit(n: int) -> void:
	if n == 1:
		line("hit_1")
	elif n == 2:
		line("hit_2")

func _on_bought(id: String) -> void:
	if id == "headshot":
		line("bought_headshot")
	elif Game.tree_of(id) == "memory":
		line("bought_memory")

# --- the monsters ------------------------------------------------------------------------------

func talk_to(m: Monster) -> void:
	if busy:
		return
	busy = true
	player.can_move = false
	var at := m.head.global_position if m.head else m.global_position + Vector3(0, 1.5, 0)
	player.look_toward(at, 0.4)
	if not m.known():
		await Speech.say_id("talk_fail")
		player.can_move = true
		busy = false
		if m is MartaHunter:
			(m as MartaHunter).wake()
		m.state = Monster.S.CHASE
		return
	# he knows who they were. He says so.
	m.state = Monster.S.CALM
	m.velocity = Vector3.ZERO
	await Speech.say("kurt", String(m.data["kurt"]))
	await Speech.say(m.id, String(m.data["answer"]), "quiet")
	m.calm()
	player.can_move = true
	busy = false
	if not _said.has("talked"):
		await wait(0.6)
		line("talked")

func _calmed(m: Monster) -> void:
	Game.set_flag("calmed_" + m.id)
	Game.add_nuggets(1)    # something of his they were holding on to

func _died(m: Monster) -> void:
	Game.set_flag("killed_" + m.id)
	if m == marta:
		await wait(0.8)
		await Speech.say_id("marta_dead")
		line("marta_dead_2")
	else:
		line("monster_dead", true)

func _caught(m: Monster) -> void:
	if _catching:
		m.reset_to_home()
		return
	_catching = true
	_caught_n += 1
	busy = true
	player.can_move = false
	player.can_look = false
	hud.set_crosshair(false)
	hud.controls.aiming = false
	weapon.set_aim(false)
	player.look_toward(m.head.global_position if m.head else m.global_position + Vector3(0, 1.5, 0), 0.2)
	player.shake(0.03, 0.5)
	Sfx.play("sting", -2.0)
	if m == marta:
		Speech.say("marta", "Have you seen them?")
	await wait(0.6)
	Sfx.play("gasp", 0.0)
	hud.fade.color.a = 1.0
	Sfx.play("thud", -2.0)
	await wait(1.5)
	for x in [porter, lamplighter, marta]:
		x.reset_to_home()
	_to_arrival()
	hud.fade_to(0.0, 1.5)
	await wait(1.2)
	Speech.say_id("caught" if m == marta else "caught_other")
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)
	weapon.equip(weapon.held)
	busy = false
	_catching = false

# --- out ---------------------------------------------------------------------------------------

func _leave() -> void:
	_done = true
	player.can_move = false
	if marta.state == Monster.S.DEAD:
		route = "kill"
	elif marta.state == Monster.S.CALM:
		route = "talk"
	else:
		route = "sneak"
	print("[town] out by the gate: ", route)
	var tw := hud.white_to(1.0, 2.0)
	await Speech.say_id("out_" + route)
	if tw.is_running():
		await tw.finished
	await wait(0.5)
	finished.emit(route)
