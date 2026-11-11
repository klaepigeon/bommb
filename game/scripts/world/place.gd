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

## Kurt has got to what this place is for (once).
func reached_heart() -> void:
	if done(): return
	World.set_flag("heart_" + id)
	Log.mark("heart " + id)
	World.emit_event("heart", {"place": id})
	heart.emit(self)
