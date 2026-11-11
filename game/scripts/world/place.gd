class_name Place
extends Node3D
## A place off the stairs you can go into: a flat, a cellar, a roof. Everything the rest of the game
## needs to know about one comes from here and from its entry in content/places.json, so a new one is
## a script that extends Place (build_content, and reached_heart() when Kurt gets to what it's for)
## plus an entry naming its landing door, where you arrive, its air (fog, ambience) and whether the
## street door has a bolt for it. See docs/EXPANDING.md.

signal heart(place: Place)

var id := ""
var data := {}                 ## its entry in places.json
var level                      ## the Level
var story                      ## the Story (set when the story starts)
var at := Vector3.ZERO         ## where in the world it's built (each place has its own space)

func build_place(p_level, p_id: String, p_data: Dictionary) -> void:
	level = p_level; id = p_id; data = p_data
	name = "Place" + id
	var a: Array = data.get("at", [0, 0, 0])
	at = Vector3(a[0], a[1], a[2])
	build_content()
	if data.get("shell", true): _shell()

## A box round the whole place, just outside its bounds, in its own air: whatever a hairline gap
## between two walls shows, it's this (bright places a little darker than their fog, dark ones
## near black). Turn off with "shell": false in places.json.
func _shell() -> void:
	var b: Array = data.get("bounds", [[-1, -1, -1], [11, 3, 9]])
	var lo := at + Vector3(b[0][0], b[0][1], b[0][2]) - Vector3.ONE * 0.6
	var hi := at + Vector3(b[1][0], b[1][1], b[1][2]) + Vector3.ONE * 0.6
	var f: Color = fog()[0]
	var c := f.darkened(0.15) if f.get_luminance() > 0.5 else f.darkened(0.7)
	var k := Kit.new()
	k.box(Mats.flat(c, -1, 1.0), (lo + hi) * 0.5, hi - lo)
	k.commit(self, "Shell")

## Build everything (override). Positions are world positions: add `at`.
func build_content() -> void:
	pass

func contains(p: Vector3) -> bool:
	var b: Array = data.get("bounds", [[-1, -1, -1], [11, 3, 9]])
	var lo := at + Vector3(b[0][0], b[0][1], b[0][2]); var hi := at + Vector3(b[1][0], b[1][1], b[1][2])
	return p.x > lo.x and p.y > lo.y and p.z > lo.z and p.x < hi.x and p.y < hi.y and p.z < hi.z

## Which lamps light a point here (override for rooms of their own).
func zone_of(_p: Vector3) -> int:
	return int(data.get("zone", 0))

## Where Kurt comes in, and facing which way: [position, yaw]. `via` names another way in.
func arrive(via := "") -> Array:
	var spec: Array = data.get("arrive_via", {}).get(via, data.get("arrive", [[0, 0, 0], 0.0]))
	return [at + Vector3(spec[0][0], spec[0][1], spec[0][2]), float(spec[1])]

func floor_index() -> int:
	return int(data.get("floor", 1))

func side() -> int:
	return int(data.get("side", 0))

func fog() -> Array:
	var f: Array = data.get("fog", ["#050506", 16.0])
	return [Color(String(f[0])), float(f[1])]

func ambience() -> String:
	return String(data.get("ambience", "building"))

func done() -> bool:
	return World.flag("heart_" + id)

## Where Kurt comes out when he leaves: [position, yaw], or [] for "on its landing" (the default).
func exit_point() -> Array:
	var e: Array = data.get("exit", [])
	if e.is_empty(): return []
	return [Vector3(e[0][0], e[0][1], e[0][2]), float(e[1])]

# ----------------------------------------------------------------- a door that isn't on a landing
## Places with an "entrance" (the basement) are let into through a door the Building builds; the
## door asks the place what can be done to it. "locked": "padlock" (with "key": an item id) gives
## the ways through a padlock: the key, an axe, a gun, Coral Grip.
func is_open() -> bool:
	return String(data.get("locked", "")) != "padlock" or World.flag(id + "_open")

func entrance_verbs(k) -> Array:
	if is_open(): return [{"id": "in", "label": "Go down" if floor_index() == 1 else "Go in"}]
	var v: Array = []
	if k.has_item(String(data.get("key", ""))): v.append({"id": "unlock", "label": "Unlock the padlock"})
	if k.held and "axe" in String(k.held.title).to_lower(): v.append({"id": "axe", "label": "Break the padlock", "held": true})
	if Progress.has("coral_grip"): v.append({"id": "wrench", "label": "Wrench the chain"})
	if k.has_item("revolver") and k.rounds > 0: v.append({"id": "shoot", "label": "Shoot the padlock"})
	v.append({"id": "knock", "label": "Knock"})
	v.append({"id": "look", "label": "Look"})
	return v

var _lock_hits := 0
func entrance_act(v: String, k, door: Node3D) -> void:
	var at: Vector3 = door.global_position
	match v:
		"in": story.travel.call(id, true, "")
		"unlock":
			Audio.play("latch", at, -4.0); Audio.play("chain", at, -6.0)
			_opened("key")
		"axe":
			_lock_hits += 1
			Audio.play("axe", at, 0.0, randf_range(0.9, 1.1)); Noises.make(at, 12.0, "axe", k)
			if _lock_hits >= 3: Audio.play("chain", at, 0.0); _opened("axe")
		"wrench":
			Audio.play("chain", at, 0.0, 0.7); Audio.play("pressure", at, -8.0, 2.0)
			k.hurt(4.0, "grip"); Noises.make(at, 5.0, "chain", k)
			_opened("grip")
		"shoot":
			k.rounds -= 1
			Audio.play("gunshot", at, 4.0); Noises.make(at, 30.0, "gunshot", k)
			Audio.play("chain", at, -2.0)
			_opened("shot")
		"look":
			World.emit_event("looked", {"title": String(data.get("title", "")), "desc": String(data.get("look", "Chained, and the chain padlocked.")), "key": id + "_door"})

func _opened(how: String) -> void:
	World.set_flag(id + "_open", how)
	World.emit_event("unlocked", {"place": id, "how": how})

## Kurt has got to what this place is for (once).
func reached_heart() -> void:
	if done(): return
	World.set_flag("heart_" + id)
	Log.mark("heart " + id)
	World.emit_event("heart", {"place": id})
	heart.emit(self)
