class_name CameraDirector
extends RefCounted
## The one thing that moves the camera. Mario Party style: everything else ASKS for a shot
## (request(name, data, priority, seconds)); the director plays the highest-priority shot
## that's still live over the base shot for the phase, and eases between them (position,
## look-at and field of view on critically-damped springs; each shot its own speed).
##
## Shots (world space; GameView converts table positions with on_table()):
##   overview   the whole table, from an elevated three-quarter angle (between turns)
##   intro      pull in on whoever's turn it is, the squares round them still in frame
##   dice       the puppet and the dice together
##   follow     behind and above a moving puppet, looking ahead along its path
##   junction   wider, centred on the junction, the ways out in frame
##   landing    on the square it landed on
##   event      a preset framing on a point: roulette, death, resurrection, poison, shop,
##              cage, award, machine (the Control System), board_wide
##   arena      a minigame arena (its own centre and distance)
##   room       sat up in your chair: the stage, the others
##   fp         first person (walking the facility)
##   cutscene   the target of a forced cutscene
##   stage      the host's stage (the intro, the finale)
## Safety: the camera never goes below the table top or out through the walls, and a
## request with bad data is ignored rather than followed.

## Board shots share ONE angle and one field of view (a steady high three-quarter view, the
## way a party board game is watched); they differ only a little in distance, and the camera
## glides between them slowly. Nothing on the board swings, spins or punches in.
const PRESETS := {
	"overview": {"height": 6.2, "back": 3.0, "fov": 50.0, "speed": 0.9},
	"intro": {"height": 1.9, "back": 1.6, "fov": 50.0, "speed": 1.0},
	"dice": {"height": 1.9, "back": 1.6, "fov": 50.0, "speed": 1.0},
	"follow": {"height": 1.9, "back": 1.6, "fov": 50.0, "speed": 1.1},
	"junction": {"height": 2.2, "back": 1.8, "fov": 50.0, "speed": 0.9},
	"landing": {"height": 1.7, "back": 1.45, "fov": 50.0, "speed": 0.9},
	"event": {"height": 1.6, "back": 1.4, "fov": 50.0, "speed": 0.9},
	"roulette": {"height": 1.4, "back": 1.25, "fov": 50.0, "speed": 0.9},
	"death": {"height": 1.4, "back": 1.25, "fov": 50.0, "speed": 0.8},
	"resurrection": {"height": 1.5, "back": 1.3, "fov": 50.0, "speed": 0.8},
	"poison": {"height": 1.5, "back": 1.3, "fov": 50.0, "speed": 0.9},
	"shop": {"height": 1.5, "back": 1.3, "fov": 50.0, "speed": 0.9},
	"award": {"height": 1.5, "back": 1.3, "fov": 50.0, "speed": 0.8},
	"machine": {"height": 1.4, "back": 1.3, "fov": 50.0, "speed": 0.8},
	"board_wide": {"height": 4.0, "back": 3.2, "fov": 50.0, "speed": 0.8},
	"cutscene": {"height": 1.0, "back": 1.0, "fov": 46.0, "speed": 1.2},
	"arena": {"speed": 1.6},
	"room": {"speed": 1.2},
	"fp": {"speed": 12.0},
	"stage": {"speed": 0.9},
}
const FLOOR_Y := 0.85
const CEILING := 3.6
const ROOM := Rect2(-7.2, -9.7, 14.4, 16.4)

var pos := Vector3(0, 2.6, 2.4)
var look := Vector3(0, 0.78, 0)
var fov := 52.0
var _vel_p := Vector3.ZERO
var _vel_l := Vector3.ZERO
var base := {"name": "overview", "data": {}}
var requests: Array = []     # [{name, data, priority, until}]
var _t := 0.0
var current := "overview"
var debug_text := ""
var table_center := Vector3(0, 0.78, 0)
var table_forward := Vector3(0, 0, 1)   # from the board toward the viewer
var shot_scale := 1.0                   # board shots' distances (the board's own scale)
var room_center := Vector3.ZERO         # the hall: the room clamp only applies near it


func set_base(name: String, data := {}) -> void:
	base = {"name": name, "data": data}


func request(name: String, data: Dictionary, priority := 10, seconds := 2.0) -> void:
	if not PRESETS.has(name) and not name in ["overview"]:
		return
	requests = requests.filter(func(r): return r.name != name)
	requests.append({"name": name, "data": data, "priority": priority, "until": _t + seconds})


func clear(name := "") -> void:
	requests = requests.filter(func(r): return name != "" and r.name != name)


func _active() -> Dictionary:
	var best := base
	var bp := -1
	for r in requests:
		if r.until >= _t and int(r.priority) > bp:
			bp = int(r.priority)
			best = r
	return best


## Where the camera wants to be for a shot.
func _target(shot: Dictionary) -> Array:
	var name := str(shot.name)
	var d: Dictionary = shot.data
	var pr: Dictionary = PRESETS.get(name, PRESETS.overview)
	match name:
		"overview":
			var c: Vector3 = d.get("center", table_center)
			return [c + table_forward * float(pr.back) + Vector3(0, float(pr.height), 0), c + Vector3(0, 0, 0.3), float(pr.fov)]
		"arena", "stage", "room", "fp":
			return [d.get("pos", pos), d.get("look", look), float(d.get("fov", 52.0))]
		_:
			var at: Vector3 = d.get("at", table_center)
			var dir: Vector3 = d.get("dir", Vector3.ZERO)
			var ahead := float(pr.get("ahead", 0.0))
			var focus := at + dir * ahead
			var k := shot_scale if name != "machine" and name != "board_wide" else 1.0
			var back := float(d.get("back", pr.back)) * k
			var height := float(d.get("height", pr.height)) * k
			# come in from the player's side of the table, a little off-axis
			# always the same angle: never turn with the path
			var from := table_forward
			return [focus + from * back + Vector3(0, height, 0), focus, float(d.get("fov", pr.fov))]


func update(delta: float) -> Dictionary:
	_t += delta
	requests = requests.filter(func(r): return r.until >= _t)
	var shot := _active()
	current = str(shot.name)
	var tgt := _target(shot)
	var want_p: Vector3 = tgt[0]
	var want_l: Vector3 = tgt[1]
	var want_f: float = tgt[2]
	if not (want_p.is_finite() and want_l.is_finite()):
		want_p = pos
		want_l = look
	# don't go through the table or out of the room (except the shots that live elsewhere)
	if not current in ["arena", "fp"] and want_l.distance_to(room_center) < 30.0:
		want_p.y = clampf(want_p.y, FLOOR_Y + 0.12, CEILING - 0.2)
		want_p.x = clampf(want_p.x, ROOM.position.x, ROOM.end.x)
		want_p.z = clampf(want_p.z, ROOM.position.y, ROOM.end.y)
	elif not current in ["arena", "fp"]:
		want_p.y = maxf(want_p.y, want_l.y + 0.15)
	var speed := float(PRESETS.get(current, {}).get("speed", 2.0))
	var big_jump := pos.distance_to(want_p) > 25.0
	if big_jump or current == "fp":
		# a cut, not a fly-through (into an arena, back from one, into your own eyes)
		pos = want_p
		look = want_l
		_vel_p = Vector3.ZERO
		_vel_l = Vector3.ZERO
	else:
		pos = _spring(pos, want_p, "_vel_p", speed, delta)
		look = _spring(look, want_l, "_vel_l", speed * 1.3, delta)
	fov = lerpf(fov, want_f, minf(1.0, delta * speed * 0.6))
	debug_text = "%s  p%s  l%s  fov %.0f" % [current, str(pos.snapped(Vector3.ONE * 0.01)), str(look.snapped(Vector3.ONE * 0.01)), fov]
	return {"pos": pos, "look": look, "fov": fov, "shot": current}


## A critically damped spring (smooth starts and stops, no overshoot).
func _spring(cur: Vector3, want: Vector3, vel_name: String, speed: float, dt: float) -> Vector3:
	var w := speed * 2.0
	var v: Vector3 = get(vel_name)
	var x := w * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - want
	var temp := (v + change * w) * dt
	v = (v - temp * w) * e
	set(vel_name, v)
	return want + (change + temp) * e
