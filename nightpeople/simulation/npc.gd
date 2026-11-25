class_name NPC
extends CharacterBody3D
## One inhabitant. Its Mind picks what to do and where; the body gets there and does it.
##
## Movement has two modes, chosen by the Society each tick:
## - physical (near a player, normal time): NavigationAgent3D + move_and_slide, doors open for it;
## - kinematic (far away, or while time is fast-forwarded): it slides along a navigation path at
##   walking pace in game time, without physics, and is hidden when DISTANT.
## Perception (sight with line-of-sight, hearing by loudness) runs only when ACTIVE; nobody far
## away can witness anything, and nobody learns of a crime except through Memory.

enum Tier { ACTIVE, NEARBY, DISTANT }

const SPEED := 1.3                 ## m/s, and metres per game minute in kinematic mode
const SIGHT := 14.0
const FOV_COS := 0.34              ## ~70° either side
const EYE := 1.55
const BARK_COOLDOWN := 12.0

var id := ""
var def: Dictionary
var mind: Mind
var memory := Memory.new()
var puppet: Puppet
var agent: NavigationAgent3D
var talk: Interactable

var tier := Tier.ACTIVE
var physical := true
var activity: Dictionary = {}
var arrived := false
var hidden_away := false

var _path := PackedVector3Array()
var _path_i := 0
var _perceive_t := 0.0
var _bark_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _patrol_i := 0
var _alarm_t := 0.0
var _alarm_at := Vector3.ZERO
var _greet_i := 0
var _stride := 0.0
var gone := false                  ## vanished from the world for good (World.gone)
var carrying := ""                 ## item id held while walking (Walk_Carry)
var _on_arrive: Callable

func npc_id() -> String:
	return id

func setup(d: Dictionary) -> void:
	def = d
	id = d.id
	name = "NPC_" + id
	mind = Mind.new(d)
	World.purses[id] = int(d.get("money", 20))
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	puppet = Puppet.new()
	add_child(puppet)
	puppet.setup(d.look)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.35
	agent.radius = 0.3
	agent.height = 1.7
	add_child(agent)
	talk = preload("res://simulation/npc_talk.gd").new()
	talk.npc = self
	talk.label = d.name
	add_child(talk)
	_patrol_i = absi(hash(id)) % 8
	Events.world_event.connect(_on_world_event)

## Put the person where their current activity has them, as if the night had been running.
func start() -> void:
	activity = mind.decide(global_position)
	activity.block_from = mind.block().from
	if activity.place != "":
		World.reserve(activity.place, id)
	var p = _target_pos()
	if activity.do == "away" or p == null:
		_go_away(true)
		return
	global_position = p
	_arrive()

# ------------------------------------------------------------------ the loop

func _physics_process(delta: float) -> void:
	if gone:
		return
	_bark_t -= delta
	if Clock.total_minutes >= float(activity.get("until", 0.0)) or (not activity.get("pinned", false) and _block_changed()):
		_finish()
	if _alarm_t > 0.0:
		_alarm_t -= delta
		_face(_alarm_at, delta)
		puppet.locomote(0.0)
		return
	if not arrived:
		if physical:
			_walk_physical(delta)
		else:
			_walk_kinematic(Clock.minutes_per_second * delta * (1.0 if Clock.running else 0.0))
	if tier == Tier.ACTIVE and physical:
		_perceive_t -= delta
		if _perceive_t <= 0.0:
			_perceive_t = 0.4
			_perceive()

func _block_changed() -> bool:
	var b := mind.block()
	return activity.has("block_from") and b.from != activity.block_from

## Send them somewhere now, overriding their schedule until `until` (game minutes) or until
## release(); `on_arrive` runs when they get there. Story events use this; the walk, the doors,
## who sees them on the way, all stay the ordinary simulation.
func command(act: Dictionary, on_arrive := Callable(), until := INF) -> void:
	if activity.get("place", "") != "":
		World.release(activity.place, id)
	act.pinned = true
	act.until = until
	if not act.has("place"):
		act.place = ""
	_on_arrive = on_arrive
	_alarm_t = 0.0
	_begin(act)

func release() -> void:
	_on_arrive = Callable()
	activity.pinned = false
	_finish()

## Carry an item visibly (or nothing, with ""): it rides in the arms, and the walk changes.
func carry(item_id: String, prop := "cardboardBoxClosed") -> void:
	carrying = item_id
	var old := puppet.get_node_or_null("Carried")
	if old:
		old.queue_free()
	if item_id != "":
		var box := Assets.prop(prop)
		box.name = "Carried"
		box.scale = Vector3.ONE * 0.6
		box.position = Vector3(0, 0.85, 0.32)
		puppet.add_child(box)

## Gone for good: off the street, out of every system that looks for people.
func vanish_forever() -> void:
	gone = true
	World.gone[id] = true
	if activity.get("place", "") != "":
		World.release(activity.place, id)
	activity = {"do": "missing", "place": "", "until": INF}
	_vanish()

func _finish() -> void:
	mind.finish(activity, self)
	if activity.get("place", "") != "":
		World.release(activity.place, id)
	_begin(mind.decide(global_position))

func _begin(act: Dictionary) -> void:
	activity = act
	activity.block_from = mind.block().from
	if act.place != "":
		World.reserve(act.place, id)
	if act.do == "away":
		_go_away(false)
		return
	if hidden_away:
		_return_from_away()
	var p = _target_pos()
	if p == null:
		arrived = true
		puppet.locomote(0.0)
		return
	arrived = false
	_set_destination(p)

func _target_pos():
	match activity.do:
		"patrol":
			var pts: Array = World.patrol
			_patrol_i = (_patrol_i + 1) % pts.size()
			return pts[_patrol_i]
		"wander":
			var pts: Array = World.patrol
			return pts[mind.rng.randi() % pts.size()] + Vector3(mind.rng.randf_range(-2, 2), 0, mind.rng.randf_range(-0.8, 0.8))
	if activity.place != "" and World.places.has(activity.place):
		return World.places[activity.place].pos
	return null

func _set_destination(p: Vector3) -> void:
	agent.target_position = p
	_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, p, true)
	_path_i = 0
	_stuck_t = 0.0

func _walk_physical(delta: float) -> void:
	if agent.is_navigation_finished():
		_arrive()
		return
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		_arrive()
		return
	dir = dir.normalized()
	velocity = dir * SPEED
	velocity.y = -4.0 if not is_on_floor() else 0.0
	move_and_slide()
	_face(global_position + dir, delta)
	puppet.locomote(SPEED, carrying != "")
	_stride += SPEED * delta
	if _stride > 0.62:
		_stride = 0.0
		if World.players.size() > 0 and global_position.distance_to(World.players[0].global_position) < 14.0:
			Sfx.play_at("step_" + Sfx.surface_at(global_position), global_position, -5.0)
	_stuck_t += delta
	if _stuck_t > 3.0:
		if global_position.distance_to(_last_pos) < 0.4:
			global_position = next + Vector3.UP * 0.05          # unstick: hop to the next corner
		_last_pos = global_position
		_stuck_t = 0.0

func _walk_kinematic(minutes: float) -> void:
	if _path.is_empty():
		_arrive()
		return
	# At normal pace a game minute lasts 1 / BASE_RATE real seconds, so walking pace in game
	# time is SPEED / BASE_RATE metres per game minute; fast-forwarding covers ground faster.
	var step := SPEED * minutes / Clock.BASE_RATE
	while step > 0.0 and _path_i < _path.size():
		var to := _path[_path_i] - global_position
		var d := to.length()
		if d <= step:
			global_position = _path[_path_i]
			step -= d
			_path_i += 1
		else:
			global_position += to / d * step
			if to.length() > 0.05:
				puppet.rotation.y = atan2(to.x, to.z)
			step = 0.0
	if tier != Tier.DISTANT:
		puppet.locomote(SPEED, carrying != "")
	if _path_i >= _path.size():
		_arrive()

## Switch movement mode; going physical keeps the target, going kinematic re-plans from here.
func set_mode(new_tier: int, want_physical: bool) -> void:
	tier = new_tier
	visible = new_tier != Tier.DISTANT and not hidden_away
	puppet.set_animating(new_tier != Tier.DISTANT)
	if want_physical == physical:
		return
	physical = want_physical
	if not arrived and activity.has("place"):
		var p = agent.target_position
		_set_destination(p)

func _arrive() -> void:
	arrived = true
	velocity = Vector3.ZERO
	if activity.get("place", "") != "" and World.places.has(activity.place):
		var pl: Dictionary = World.places[activity.place]
		global_position = pl.pos
		puppet.rotation.y = deg_to_rad(pl.yaw)
		puppet.hold(pl.pose if activity.do != "sleep" else "sleep")
		_check_belongings()
		if _on_arrive.is_valid():
			var cb := _on_arrive
			_on_arrive = Callable()
			cb.call()
	else:
		puppet.locomote(0.0)
		if activity.do in ["patrol", "wander"]:
			arrived = false
			_set_destination(_target_pos())

func _face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		puppet.rotation.y = lerp_angle(puppet.rotation.y, atan2(d.x, d.z), 8.0 * delta)

# ------------------------------------------------------------------ off the map

func _go_away(instant: bool) -> void:
	var edge := World.nearest_edge(global_position)
	if instant:
		global_position = edge
		_vanish()
		return
	arrived = false
	activity.place = ""
	_set_destination(edge)
	activity["leaving"] = true

func _vanish() -> void:
	hidden_away = true
	arrived = true
	visible = false
	collision_layer = 0

func _return_from_away() -> void:
	hidden_away = false
	collision_layer = 4
	visible = tier != Tier.DISTANT
	var dest = World.places[activity.place].pos if activity.place != "" and World.places.has(activity.place) else global_position
	global_position = World.nearest_edge(dest)

func _process(_delta: float) -> void:
	if activity.get("leaving", false) and arrived and not hidden_away:
		_vanish()

# ------------------------------------------------------------------ senses

func eye() -> Vector3:
	return global_position + Vector3.UP * EYE

func asleep() -> bool:
	return arrived and activity.get("do", "") == "sleep"

## Could this person see `target` (a Node3D) right now?
func can_see(target: Node3D) -> bool:
	if hidden_away or asleep() or tier == Tier.DISTANT:
		return false
	var to := target.global_position + Vector3.UP * 1.2 - eye()
	var d := to.length()
	if d > SIGHT:
		return false
	var fwd := Vector3(sin(puppet.rotation.y), 0, cos(puppet.rotation.y))
	if d > 2.0 and fwd.dot(Vector3(to.x, 0, to.z).normalized()) < FOV_COS:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye(), eye() + to, 1 | 8)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _perceive() -> void:
	for p in World.players:
		if not can_see(p):
			continue
		var room := World.room_at(p.global_position + Vector3.UP * 0.5)
		memory.remember("seen", "player", Memory.Source.WITNESSED, {}, room)
		if room != "" and not World.may_enter("player", room):
			_witness_trespass(p, room)

func _witness_trespass(p: Node3D, room: String) -> void:
	var fresh := memory.remember("trespass", "player", Memory.Source.WITNESSED, {}, room)
	if fresh or _bark_t <= 0.0:
		_react(p, "trespass", room)

func _react(p: Node3D, kind: String, room: String) -> void:
	var mine: bool = World.rooms.has(room) and id in World.rooms[room].owners
	var r: Dictionary = World.rooms.get(room, {})
	var text := ""
	match kind:
		"trespass", "break_in":
			if mine and r.get("public", false):
				text = "We're closed. Out. Now."
			elif mine:
				text = ["Hey! What are you doing in my place?!", "Get out of here! I'll call the cops!", "Who let you in? GET OUT!"][mind.rng.randi() % 3]
			else:
				text = "You're not supposed to be in there."
	_alarm(p.global_position, 6.0)
	say(text)

func _alarm(at: Vector3, seconds: float) -> void:
	_alarm_at = at
	_alarm_t = seconds
	if not arrived or puppet._pose in ["sit", "sleep"]:
		puppet.locomote(0.0)

func _on_world_event(e: Dictionary) -> void:
	if hidden_away or tier == Tier.DISTANT:
		return
	var actor: Node3D = e.get("actor")
	var pos: Vector3 = e.position
	var heard: bool = pos.distance_to(global_position) < float(e.get("loudness", 0.0)) and not (asleep() and e.kind != "knock")
	var saw := actor != null and actor != self and can_see(actor)
	match e.kind:
		"take":
			var item: Dictionary = e.item
			var owner: String = e.owner
			if saw and owner != "" and owner != "player":
				memory.remember("theft", "player", Memory.Source.WITNESSED, {"item": item.name, "victim": owner}, e.place)
				_alarm(actor.global_position, 5.0)
				say("Hey! That's mine! Put it back!" if owner == id else "I saw that. That's not yours.")
		"lockpick":
			if saw:
				memory.remember("break_in", "player", Memory.Source.WITNESSED, {}, e.place)
				_alarm(actor.global_position, 5.0)
				say("Hey! What are you doing to that door?")
			elif heard:
				memory.remember("lockpick", "unknown", Memory.Source.HEARD, {}, e.place)
				say("...What was that?")
		"knock":
			if World.room_at(global_position + Vector3.UP * 0.5) == e.place:
				say("Mmph... it's the middle of the night. Go away!" if asleep() else "Who is it? I'm not expecting anybody.")

## Coming back to their things, they notice what's gone. Nobody told them; they found out.
func _check_belongings() -> void:
	var here := World.room_at(global_position + Vector3.UP * 0.5)
	for m in World.missing:
		if m.owner != id or m.room != here or m.has("found_" + id):
			continue
		m["found_" + id] = true
		var known := memory.about("player", "theft")
		var culprit := "unknown"
		for e in known:
			if e.get("item", "") == m.item.name:
				culprit = "player"
		memory.remember("theft", culprit, Memory.Source.FOUND, {"item": m.item.name, "victim": id}, here)
		say("My %s... it's gone. Somebody's been in here." % _short(m.item.name) if culprit == "unknown" else "You. You took my %s." % _short(m.item.name))

static func _short(item_name: String) -> String:
	return item_name.split(" (")[0].to_lower()

## Say something out loud. If the player is in earshot and the line carries news, they learn it.
func say(text: String, clue := "") -> void:
	if text == "" or gone:
		return
	if clue != "":
		for p in World.players:
			if p.global_position.distance_to(global_position) < 16.0:
				Journal.learn(clue)
	_bark_t = BARK_COOLDOWN
	Events.bark.emit(def.name.split(" ")[0] if not def.name.begins_with("Officer") else "Doyle", text, self)

# ------------------------------------------------------------------ conversation

func activity_text() -> String:
	if hidden_away:
		return ""
	var what: String = Mind.DOING.get(activity.get("do", ""), "")
	return "%s, %s" % [def.role, what] if what != "" else def.role

## The player speaks to them. What they say depends on what they know.
func talk_to(p: Node3D) -> void:
	var lines: Dictionary = def.lines
	if asleep():
		var room := World.room_at(global_position + Vector3.UP * 0.5)
		memory.remember("trespass", "player", Memory.Source.WITNESSED, {}, room)
		_alarm(p.global_position, 4.0)
		say("Wha-? Who's there?! How did you get in here?!")
		return
	_alarm(p.global_position, 2.5)
	var d := memory.disposition("player")
	var crimes := memory.about("player").filter(func(e): return Memory.WEIGHT.get(e.kind, 0.0) < -0.2)
	if d < -0.4 and not crimes.is_empty():
		var worst: Dictionary = crimes[0]
		match worst.kind:
			"theft":
				say("You took %s. I saw you. Give it back or get lost." % _short(worst.get("item", "something")) if worst.source == Memory.Source.WITNESSED else "I heard what you did. Stay away from me.")
			_:
				say("You were in %s. Don't think I forgot. Get away from me." % World.rooms.get(worst.place, {"name": "a place you shouldn't be"}).name)
		return
	if not crimes.is_empty():
		say("People are saying things about you. I don't know you, and I'd like to keep it that way.")
		return
	var rumour := memory.gossip()
	if not rumour.is_empty() and mind.rng.randf() < 0.5:
		say("Watch your things. Somebody's been %s around here." % ("taking stuff" if rumour.kind == "theft" else "breaking in"))
		return
	var first := memory.remember("met", "player", Memory.Source.WITNESSED)
	var pool: Array = lines.get("busy", []) if activity.get("do", "") == "work" and mind.rng.randf() < 0.25 else lines.get("greet", [])
	if pool.is_empty():
		pool = ["..."]
	say(pool[(_greet_i if not first else 0) % pool.size()])
	_greet_i += 1

## Answer the player face to face: they hear it, so they learn what it carries.
func _answer(text: String, clue := "") -> void:
	say(text)
	Journal.learn(clue)

## A topic the player raises (data/story.json "topics"). Answers come from what this person
## knows; a few people have their own answer (and may be lying).
func ask(topic: String, p: Node3D) -> void:
	_alarm(p.global_position, 2.5)
	var own: Dictionary = Journal.story.answers.get(id, {})
	match topic:
		"abe":
			if own.has("abe") and World.gone.has("abe"):
				_answer(own.abe[0], own.abe[1])
				return
			var seen := memory.about("abe", "saw_vesper")
			if not seen.is_empty():
				_answer("I saw him go into the Vesper after he closed up. Didn't see him come out." if seen[0].source == Memory.Source.WITNESSED else "Word is he went into the Vesper and never came out.", "witness_vesper")
			elif memory.knows("missing", "abe"):
				_answer("He's gone. Shop's dark when it should be open. Nobody knows where he went.", "abe_gone_heard")
			elif World.gone.has("abe"):
				say("Abe? Haven't seen him tonight. Why?")
			elif id == "abe":
				say("What about me? I'm busy.")
			else:
				say("Abe? Behind his counter till half twelve, then Lucky's. Like a clock. Why?")
		"warn":
			if id != "abe":
				return
			if memory.disposition("player") < -0.2:
				say("You? You've got some nerve. Mind your own business.")
				return
			say("You've been reading my mail? ...No. No, you're right. I'm not going anywhere tonight.")
			Journal.learn("abe_warned")
			Events.world_event.emit({"kind": "warned", "actor": p, "who": id, "position": global_position, "loudness": 0.0})
		"show":
			if id == "doyle":
				_answer("These are Kessler's. Where'd you get- the Vesper? ...Alright. I'm gonna sit on that place.", "told_doyle")
				Events.world_event.emit({"kind": "reported", "actor": p, "who": id, "position": global_position, "loudness": 0.0})
			elif id in ["claudette", "ray"]:
				say("Never seen them before in my life.")
			else:
				memory.remember("evidence", "abe", Memory.Source.TOLD, {}, "club_back", "player")
				say("Those are Abe's! Where did you find those? ...The Vesper? Jesus, Mary and Joseph.")
