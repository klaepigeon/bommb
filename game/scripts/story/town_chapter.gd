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
##
## How it's put together (so that nothing piles up on one frame):
##   - One phase at a time: BLACK (building and prewarming), ARRIVING, FREE (he's walking about),
##     SCENE (something has hold of the controls: a talk, the lever, being caught), LEAVING, DONE.
##     `busy` is simply "not FREE".
##   - Scenes are numbered. A scene that's overtaken (he's caught while pulling the lever) sees
##     its number is stale after its next wait and stops, without touching anything.
##   - Nothing per-frame waits. The physics step only looks and decides.
##   - What's said in passing goes through one queue: a line starts only when nobody is speaking,
##     only while he's FREE, never in the frame something was picked up, and in the order asked.

signal finished(route: String)

enum Phase { BLACK, ARRIVING, FREE, SCENE, LEAVING, DONE }

var main: Node
var town: Town
var player: Player
var hud: Hud
var weapon: Weapon
var porter: Monster
var lamplighter: Monster
var marta: MartaHunter
var data := {}
var route := ""
var phase := Phase.BLACK
## Something has the controls (or he isn't in the town yet / any more).
var busy: bool:
	get:
		return phase != Phase.FREE

var _said := {}
var _queue: Array[Dictionary] = []      ## lines waiting their turn: {id, at}
var _clock := 0.0                       ## the chapter's own time (stops while paused)
var _quiet_frame := -1                  ## no line starts on this frame (a pickup happened)
var _scene_n := 0
var _catching := false
var _steer_t := 18.0
var _count_t := 45.0
var _unpoint_at := -1.0
var _in_nursery := false
var _chalk_on := false

# --- setting up --------------------------------------------------------------------------------

func setup() -> void:
	add_to_group("director")
	data = _read_json("res://content/town.json")
	for e in get_tree().get_nodes_in_group("examine"):
		e.connect("used", _read.bind(e))
	for d in get_tree().get_nodes_in_group("sonya_door"):
		d.connect("used", _sonya_door)
	for p in town.pickups:
		var h: Hotspot = p[0]
		h.used.connect(_take.bind(h, String(p[1])))
	town.revolver_spot.used.connect(_take_revolver)
	town.lever_spot.used.connect(_pull_lever)
	var mons: Dictionary = data.get("monsters", {})
	porter = _spawn(Monster, "porter", mons.get("porter", {}), town.porter_home, 4, Rect2(52.4, 34.7, 5.9, 6.6))
	porter.rotation.y = -PI * 0.5      # facing the wall of the hotel room, his back to the door
	lamplighter = _spawn(Monster, "lamplighter", mons.get("lamplighter", {}), town.lamplighter_path[0], 13, Rect2(4.5, 16.5, 51.0, 7.0))
	lamplighter.wanders = [town.to_global(town.lamplighter_path[0]), town.to_global(town.lamplighter_path[1])]
	lamplighter.speed = 0.8
	marta = _spawn(MartaHunter, "marta", mons.get("marta", {}), town.marta_post, 47, Rect2(28.5, 32.5, 27.0, 35.0)) as MartaHunter
	marta.away_point = town.to_global(town.marta_away)
	weapon.reloaded_first.connect(func(): line("reloaded"))
	weapon.emptied.connect(func(): line("empty"))
	Game.skill_bought.connect(_on_bought)
	Trail.mark("town: chapter set up")

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

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

func monsters() -> Array[Monster]:
	var a: Array[Monster] = [porter, lamplighter, marta]
	return a

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

func local_pos() -> Vector3:
	return town.to_local(player.global_position)

## Where he comes out of the hole, facing down the lane.
func _to_arrival() -> void:
	var a: Transform3D = town.arrive
	player.global_position = town.to_global(a.origin)
	player.face(town.to_global(a.origin - a.basis.z * 3.0 + Vector3(0, 1.5, 0)))

# --- what's said in passing ----------------------------------------------------------------------

## How soon a line gets its turn. Replies answer what he has just done and go first; beats are
## the story's (and Socko's agenda); neither is ever dropped. Anything else is a passing remark,
## and lapses if it has waited too long.
const REPLIES := ["gun", "poster_known", "marta_dead", "marta_dead_2", "caught", "caught_other", "talked",
	"loop_kurt", "loop_socko"]
const BEATS := ["nuggets", "enough", "marta_here", "gate_seen", "nursery",
	"bought_headshot", "bought_memory"]
const LAPSE := 8.0

func _tier(id: String) -> int:
	return 2 if REPLIES.has(id) else (1 if BEATS.has(id) else 0)

## A line, once (unless again is true), when its turn comes: after `delay` seconds, when nobody
## is speaking and he's free. Doesn't wait.
func line(id: String, again := false, delay := 0.0) -> void:
	if phase == Phase.DONE:
		return
	if _said.has(id) and not again:
		return
	_said[id] = true
	var entry := {"id": id, "at": _clock + delay, "tier": _tier(id)}
	# behind everything already waiting at its tier or above, ahead of the rest
	var i := 0
	while i < _queue.size() and int(_queue[i]["tier"]) >= int(entry.tier):
		i += 1
	_queue.insert(i, entry)

## The first line in the queue that's due, if it's a good moment to say it.
func _pump() -> void:
	if _queue.is_empty():
		return
	# remarks that missed their moment go
	for i in range(_queue.size() - 1, -1, -1):
		if int(_queue[i]["tier"]) == 0 and _clock > float(_queue[i]["at"]) + LAPSE:
			_queue.remove_at(i)
	if phase != Phase.FREE or Speech.speaking != "":
		return
	if Engine.get_physics_frames() == _quiet_frame:
		return
	for i in _queue.size():
		if float(_queue[i]["at"]) <= _clock:
			var id: String = _queue[i]["id"]
			_queue.remove_at(i)
			Speech.say_id(id)
			return

# --- behind the black ----------------------------------------------------------------------------

## Draw the whole town once before anyone sees it: a camera stands at each of the town's views
## and looks four ways round, with the lamps lit as they will be there. Every shader and light
## combination the town needs is compiled now, behind the black, instead of in the middle of
## the street (which is where, and how, the town used to crash on phones).
func prewarm() -> void:
	phase = Phase.BLACK
	_to_arrival()
	for m in monsters():
		m.process_mode = Node.PROCESS_MODE_DISABLED     # nobody moves while the camera's away
	var cam := Camera3D.new()
	cam.name = "Prewarm"
	cam.fov = 95.0
	cam.near = player.camera.near
	cam.far = player.camera.far
	town.add_child(cam)
	cam.make_current()
	var views := town.prewarm_views()
	for i in views.size():
		for k in 4:
			var at := town.to_global(views[i])
			cam.global_transform = Transform3D(Basis(Vector3.UP, k * PI * 0.5), at)
			town.update_lights(at)
			await get_tree().process_frame
		if i % 4 == 3:
			Trail.mark("town: prewarmed %d/%d views" % [i + 1, views.size()])
	# and once through his own eyes, where he'll be standing
	player.camera.make_current()
	town.update_lights(player.camera.global_position)
	cam.queue_free()
	for k in 3:
		await get_tree().process_frame
	for m in monsters():
		m.process_mode = Node.PROCESS_MODE_INHERIT
	Trail.mark("town: prewarmed")

# --- arriving ----------------------------------------------------------------------------------

func arrive() -> void:
	phase = Phase.ARRIVING
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
	if phase != Phase.ARRIVING:
		return
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)
	phase = Phase.FREE
	Trail.mark("town: free")

# --- every frame: look, decide, never wait ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	if town == null or not town.visible or phase in [Phase.BLACK, Phase.DONE]:
		return
	_clock += delta
	var lp := local_pos()
	_wrap(lp)
	var chalk_on := Game.owned("these_streets")
	if chalk_on != _chalk_on:
		_chalk_on = chalk_on
		town.show_chalk(chalk_on)
	if phase != Phase.LEAVING:
		_nuggets()
	if _unpoint_at >= 0.0 and _clock >= _unpoint_at:
		_unpoint_at = -1.0
		player.socko.point_at(Vector3.INF)
	if phase == Phase.FREE:
		_steer(delta)
		_nursery(lp, delta)
		if lp.z > 57.0 and lp.x > 28.0 and lp.x < 56.0:
			line("gate_seen")
		if not town.gate_open and lp.z > Town.GATE_Z - 1.6 and lp.x > Town.GATE_X0 and lp.x < Town.GATE_X1:
			line("gate_shut")
		# the gate: through it and out
		if town.gate_open and lp.z > Town.GATE_Z + 2.5 and lp.x > Town.GATE_X0 and lp.x < Town.GATE_X1:
			_leave()
			return
	_pump()

## The street comes round on itself.
func _wrap(lp: Vector3) -> void:
	var wrapped := town.wrap(lp)
	if wrapped == lp:
		return
	player.global_position = town.to_global(Vector3(wrapped.x, player.global_position.y - town.global_position.y, wrapped.z))
	town.update_lights(player.camera.global_position)      # the lamps where he is now, this frame
	Trail.mark("town: the street came round")
	Game.set_flag("looped")
	if Game.owned("these_streets"):
		line("loop_kurt")
		line("loop_socko")

## Walk into a nugget and it's his. This frame: it goes, it's counted. What Socko makes of it
## comes later, from the queue.
func _nuggets() -> void:
	var n := town.nugget_at(player.global_position + Vector3(0, 0.6, 0))
	if n == null:
		return
	n.take()
	Game.add_nuggets(1)
	_quiet_frame = Engine.get_physics_frames()
	Trail.mark("town: nugget %s counted (%d)" % [n.name, Game.nuggets])
	if Game.nuggets >= 4 and not Game.owned("headshot") and _said.has("nuggets"):
		line("enough", false, 4.0)
	line("nuggets", false, 0.6)

## Socko steers to the gun, now and then.
func _steer(delta: float) -> void:
	if Game.has_gun:
		return
	_steer_t -= delta
	if _steer_t <= 0.0 and Speech.speaking == "" and _queue.is_empty():
		_steer_t = 22.0
		line(["steer_1", "steer_2", "steer_3"][randi() % 3], true)
		player.socko.point_at(town.to_global(town.revolver_at + Vector3(0, 1, 0)))
		_unpoint_at = _clock + 2.0

## Counting: a girl's voice from the nursery's direction, never in it.
func _nursery(lp: Vector3, delta: float) -> void:
	var near := town.nursery.has_point(Vector2(lp.x, lp.z))
	if near and not _in_nursery:
		_in_nursery = true
		if not _said.has("nursery"):
			player.socko.emotion = "neutral"
			player.socko.face_kurt = 0.0
			line("nursery", false, 2.5)
	elif not near:
		_in_nursery = false
	if Game.owned("counting") and not near:
		_count_t -= delta
		if _count_t <= 0.0 and Speech.speaking == "":
			_count_t = 50.0
			line("count", true)

# --- scenes: something has the controls ----------------------------------------------------------

func _begin_scene() -> int:
	phase = Phase.SCENE
	_scene_n += 1
	return _scene_n

## Still this scene's turn (nothing has overtaken it).
func _still(n: int) -> bool:
	return n == _scene_n and phase == Phase.SCENE

func _end_scene(n: int) -> void:
	if _still(n):
		phase = Phase.FREE

# --- things ------------------------------------------------------------------------------------

## The town's things to look at (the first build's text): what it is, and with Her Handwriting,
## what's written on the back. Socko waves most of them away, once each.
func _read(e: Node) -> void:
	if phase != Phase.FREE:
		return
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
	if not h.enabled or phase != Phase.FREE:
		return
	if kind == "rock" and weapon.busy:
		return
	h.enabled = false
	var mesh: Node3D = h.get_meta("mesh")
	mesh.visible = false
	_quiet_frame = Engine.get_physics_frames()
	Trail.mark("town: took " + kind)
	match kind:
		"ammo":
			Game.ammo_spare += 7
			Sfx.play("load", -4.0)
		"rock":
			weapon.equip("rock")
			# the cobble comes back, a while later, where it was (there are always more cobbles)
			get_tree().create_timer(20.0, false).timeout.connect(func():
				if is_instance_valid(mesh) and is_instance_valid(h):
					mesh.visible = true
					h.enabled = true)

func _take_revolver() -> void:
	if Game.has_gun or phase != Phase.FREE:
		return
	town.revolver_spot.enabled = false
	town.revolver_mesh.visible = false
	_quiet_frame = Engine.get_physics_frames()
	Trail.mark("town: took the revolver")
	Game.ammo_loaded = 3
	weapon.give_gun()
	line("gun", false, 0.3)
	line("gun_hint", false, 4.0)
	# she's been sitting by the gate the whole time. Now she isn't.
	await wait(3.0)
	if phase in [Phase.LEAVING, Phase.DONE]:
		return
	if marta.state != Monster.S.CALM and marta.state != Monster.S.DEAD:
		marta.wake()
		marta.listen_to(player.global_position)    # she heard him take it; she comes
		line("marta_here")

func _sonya_door() -> void:
	if phase != Phase.FREE:
		return
	Sfx.play_at("rattle", town.to_global(Vector3(6.3, 1.4, 63.2)), -4.0, 1.1)
	line("sonya_door")

func _pull_lever() -> void:
	if phase != Phase.FREE or town.gate_open:
		return
	var n := _begin_scene()
	Trail.mark("town: the lever")
	player.can_move = false
	player.arm.set_pose("handle", 0.3)
	await wait(0.3)
	if not _still(n):
		return
	player.arm.rattle = 0.6
	Noises.make(town.lever_spot.global_position, 8.0, "lever")
	Sfx.play_at("rattle", town.lever_spot.global_position, 2.0, 0.6)
	await wait(1.6)
	player.arm.rattle = 0.0
	if not _still(n):
		return          # she had him before it gave
	town.open_gate()
	weapon.equip(weapon.held)
	player.can_move = true
	_end_scene(n)

func on_marta_hit(n: int) -> void:
	if n == 1:
		line("hit_1")
	elif n == 2:
		line("hit_2")

func _on_bought(id: String) -> void:
	if phase == Phase.DONE:
		return
	if id == "headshot":
		line("bought_headshot")
	elif Game.tree_of(id) == "memory":
		line("bought_memory")

# --- the monsters ------------------------------------------------------------------------------

func talk_to(m: Monster) -> void:
	if phase != Phase.FREE:
		return
	var n := _begin_scene()
	Trail.mark("town: talking to " + m.id)
	player.can_move = false
	var at := m.head.global_position if m.head else m.global_position + Vector3(0, 1.5, 0)
	player.look_toward(at, 0.4)
	if not m.known():
		await Speech.say_id("talk_fail")
		if not _still(n):
			return
		player.can_move = true
		_end_scene(n)
		if m is MartaHunter:
			(m as MartaHunter).wake()
		m.state = Monster.S.CHASE
		return
	# he knows who they were. He says so. (Calm from the first word: nothing can undo that.)
	m.state = Monster.S.CALM
	m.velocity = Vector3.ZERO
	await Speech.say("kurt", String(m.data.get("kurt", "")))
	if _still(n):
		await Speech.say(m.id, String(m.data.get("answer", "")), "quiet")
	m.calm()
	if not _still(n):
		return
	player.can_move = true
	_end_scene(n)
	line("talked", false, 0.6)

func _calmed(m: Monster) -> void:
	Game.set_flag("calmed_" + m.id)
	Game.add_nuggets(1)    # something of his they were holding on to

func _died(m: Monster) -> void:
	Game.set_flag("killed_" + m.id)
	Trail.mark("town: %s died" % m.id)
	if m == marta:
		line("marta_dead", false, 0.8)
		line("marta_dead_2", false, 0.81)
	else:
		line("monster_dead", true)

func _caught(m: Monster) -> void:
	if _catching or phase in [Phase.BLACK, Phase.ARRIVING, Phase.LEAVING, Phase.DONE]:
		m.reset_to_home()
		return
	_catching = true
	var n := _begin_scene()
	Trail.mark("town: caught by " + m.id)
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
	for x in monsters():
		x.reset_to_home()
	_to_arrival()
	town.update_lights(player.camera.global_position)
	hud.fade_to(0.0, 1.5)
	await wait(1.2)
	_catching = false
	if not _still(n):
		return
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)
	weapon.equip(weapon.held)
	_end_scene(n)
	line("caught" if m == marta else "caught_other", true)

# --- out ---------------------------------------------------------------------------------------

func _leave() -> void:
	phase = Phase.LEAVING
	_queue.clear()
	player.can_move = false
	if marta.state == Monster.S.DEAD:
		route = "kill"
	elif marta.state == Monster.S.CALM:
		route = "talk"
	else:
		route = "sneak"
	print("[town] out by the gate: ", route)
	Trail.mark("town: out by the gate, " + route)
	var tw := hud.white_to(1.0, 2.0)
	await Speech.say_id("out_" + route)
	if tw.is_valid() and tw.is_running():
		await tw.finished
	await wait(0.5)
	phase = Phase.DONE
	remove_from_group("director")
	finished.emit(route)
