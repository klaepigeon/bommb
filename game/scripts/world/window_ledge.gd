class_name WindowLedge
extends Node3D
## The way round the outside: over the balcony's end rail onto the ledge, back to the wall along
## the bedroom's outside, and in at the bedroom window. Out over the white the whole way.
##
## The window's right-hand casement opens inward on a latch that's on the inside. From the
## inside: open it. From the ledge: break the glass (loud, it cuts), smash it with whatever he's
## holding (loud), reach in through the fortochka (the little vent pane above, always ajar) and
## feel down for the latch (slow, quiet), or send Socko through it (quick, and he loves it).
## State is the World flag "bed_window": shut / open / broken.

const X0 := 3.95                 ## the balcony's end
const X1 := 6.98                 ## the drainpipe
const Z_WALL := -0.42
const Z_EDGE := -0.8
const TOP := -0.12
const WIN := Vector3(6.38, 1.6, -0.21)   ## the casement's middle
const HINGE := Vector3(6.72, 0.0, -0.09)

var flat
var kurt: Kurt
var _sash: CollisionShape3D
var _pivot: Node3D
var _glass: Array[MeshInstance3D] = []
var _shown := ""
var _open_a := 0.0
var _on_ledge := false
var _sway := 0.0
var _looked_down := false

func state() -> String:
	var s = World.flag("bed_window")
	return String(s) if s is String else "shut"

func build(p_flat) -> void:
	flat = p_flat
	var concrete := Mats.tex(Tex.get_tex("concrete"), -1, Color(0.75, 0.74, 0.72))
	var k := Kit.new()
	# the ledge: a strip of concrete under the windows, the width of a shoe
	k.box(concrete, Vector3((X0 + X1) * 0.5, TOP - 0.08, (Z_WALL + Z_EDGE) * 0.5), Vector3(X1 - X0, 0.16, Z_WALL - Z_EDGE))
	# the drainpipe at the end, all the way down into the white
	k.box(Mats.flat(Color(0.22, 0.2, 0.19), -1), Vector3(X1 + 0.05, -2.0, -0.5), Vector3(0.09, 9.0, 0.09))
	for y in [-1.0, 0.9, 2.8]:
		k.box(Mats.flat(Color(0.18, 0.16, 0.15), -1), Vector3(X1 + 0.05, y, -0.47), Vector3(0.13, 0.05, 0.1))
	k.commit(self, "Ledge")
	var body := StaticBody3D.new(); body.name = "LedgeBody"; add_child(body)
	_box(body, Vector3((X0 + X1) * 0.5, TOP - 0.08, (Z_WALL + Z_EDGE) * 0.5), Vector3(X1 - X0, 0.16, Z_WALL - Z_EDGE))
	_box(body, Vector3(X1 + 0.05, 1.0, -0.62), Vector3(0.12, 2.4, 0.4))           # the pipe stops him
	# the casement: a body filling the gap in the wall while it's shut
	var sb := StaticBody3D.new(); sb.name = "Sash"; add_child(sb)
	_sash = _box(sb, Vector3(6.38, 1.6, -0.21), Vector3(0.72, 1.4, 0.4))
	# its glass (both panes of the double casement), on a hinge
	_pivot = Node3D.new(); _pivot.name = "Casement"; add_child(_pivot); _pivot.position = HINGE
	for n in ["Mesh129", "Mesh132"]:
		var mi := flat.find_child(n, true, false) as MeshInstance3D
		if mi:
			mi.reparent(_pivot, true)
			_glass.append(mi)
	# where he stands on the ledge: shuffling, back to the wall
	var area := Area3D.new(); area.collision_mask = 16; area.collision_layer = 0; add_child(area)
	_box(area, Vector3((X0 + X1) * 0.5 + 0.03, 0.8, (Z_WALL + Z_EDGE) * 0.5 - 0.1), Vector3(X1 - X0 - 0.06, 2.0, 0.5))
	area.body_entered.connect(func(b): if b is Kurt: _enter(b))
	area.body_exited.connect(func(b): if b is Kurt: _leave(b))
	_usables()
	_sync(true)

func _box(parent: Node, at: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; cs.shape = b
	cs.position = at; parent.add_child(cs)
	return cs

# ------------------------------------------------------------------------------ the things to do
func _usables() -> void:
	# the balcony's end rail, from the balcony
	var over := Usable.make(self, Transform3D(Basis(), Vector3(3.84, 0.95, -0.75)), Vector3(0.16, 0.5, 0.6), [])
	over.title = "Balcony rail"
	over.desc = "Past the end of it, a ledge runs along the wall, under the bedroom window."
	over.offer = func(_k): return [{"id": "over", "label": "Climb onto the ledge"}]
	over.acted.connect(func(_v, k): _to_ledge(k))
	# and back, from the ledge
	var back := Usable.make(self, Transform3D(Basis(), Vector3(4.1, 0.95, -0.62)), Vector3(0.14, 0.6, 0.36), [])
	back.title = "Balcony rail"
	back.offer = func(_k): return [{"id": "back", "label": "Climb back over"}]
	back.acted.connect(func(_v, k):
		await k.climb([Vector3(3.95, 0.92, -0.72), Vector3(3.4, TOP, -0.95)], 1.0)
		k.yaw = PI * 0.5)
	# the window, from outside
	var out := Usable.make(self, Transform3D(Basis(), Vector3(6.38, 1.5, -0.47)), Vector3(0.74, 1.3, 0.06), [])
	out.title = "Bedroom window"
	out.offer = _outside_verbs
	out.acted.connect(_outside_act)
	out.socko_offer = func(_k): return [{"id": "latch", "label": "Through the fortochka: the latch"}] if state() == "shut" else []
	out.socko_do = _socko_latch
	# and from inside
	var inn := Usable.make(self, Transform3D(Basis(), Vector3(6.38, 1.5, 0.04)), Vector3(0.74, 1.3, 0.06), [])
	inn.title = "Bedroom window"
	inn.offer = _inside_verbs
	inn.acted.connect(_inside_act)

func _outside_verbs(k) -> Array:
	match state():
		"open", "broken": return [{"id": "in", "label": "Climb in"}]
	var v: Array = [{"id": "reach", "label": "Reach in through the fortochka"}, {"id": "elbow", "label": "Break the glass"}]
	if k and k.held: v.push_front({"id": "smash", "label": "Smash it with the " + String(k.held.title).to_lower()})
	return v

func _inside_verbs(_k) -> Array:
	match state():
		"open": return [{"id": "out", "label": "Climb out onto the ledge"}, {"id": "close", "label": "Close the window"}]
		"broken": return [{"id": "out", "label": "Climb out onto the ledge"}]
	return [{"id": "open", "label": "Open the window"}]

func _outside_act(v: String, k) -> void:
	match v:
		"in": await _climb_in(k)
		"elbow":
			_break(k)
			k.hurt(8.0, self)
			Speech.say_id("ledge_elbow")
		"smash":
			_break(k)
		"reach":
			k.frozen = true
			Audio.play("scrape", WIN + Vector3(-0.7, 0.5, 0), -10.0)
			await get_tree().create_timer(2.6 if not Speech.fast else 0.2, false).timeout
			Audio.play("latch", WIN, -8.0)
			k.frozen = false
			set_state("open")
			Speech.say_id("ledge_reach")
			World.emit_event("window", {"how": "reach"})

func _inside_act(v: String, k) -> void:
	match v:
		"open":
			Audio.play("latch", WIN, -6.0); set_state("open")
			World.emit_event("window", {"how": "inside"})
		"close":
			Audio.play("latch", WIN, -6.0); set_state("shut")
		"out": await _climb_out(k)

func _socko_latch(_id, _k, m) -> void:
	await m.bark("cmd_latch", true)
	m.socko.set_pose("up", 0.4)
	m.socko.point_at(WIN + Vector3(-0.7, 0.55, 0))
	await get_tree().create_timer(1.6 if not Speech.fast else 0.1, false).timeout
	Audio.play("latch", WIN, -8.0)
	set_state("open")
	m.socko.point_at(Vector3.INF)
	m.bark("cmd_latch_ok", true)
	World.emit_event("window", {"how": "socko"})

func _break(k) -> void:
	Audio.play("glass", WIN, 2.0)
	Noises.make(WIN, 16.0, "glass", k)
	set_state("broken")
	World.emit_event("window", {"how": "broken"})

func set_state(s: String) -> void:
	World.set_flag("bed_window", s)
	_sync(false)

func _to_ledge(k: Kurt) -> void:
	await k.climb([Vector3(3.84, 0.92, -0.75), Vector3(4.4, TOP, -0.62)], 1.1)
	k.yaw = -PI * 0.5
	if not World.flag("been_on_ledge"):
		World.set_flag("been_on_ledge")
		Speech.say_id("ledge_first")

func _climb_in(k: Kurt) -> void:
	await k.climb([Vector3(6.36, TOP, -0.62), Vector3(6.36, 0.95, -0.3), Vector3(6.36, 0.95, 0.2), Vector3(6.36, 0.0, 0.7)], 1.6, true)
	k.yaw = PI
	World.emit_event("window", {"how": "in"})

func _climb_out(k: Kurt) -> void:
	await k.climb([Vector3(6.36, 0.0, 0.5), Vector3(6.36, 0.95, 0.2), Vector3(6.36, 0.95, -0.3), Vector3(6.3, TOP, -0.62)], 1.6, true)
	k.yaw = PI * 0.5

# --------------------------------------------------------------------------------------- frame
func _sync(instant: bool) -> void:
	var s := state()
	if s == _shown and not instant: return
	_shown = s
	_sash.disabled = s != "shut"
	for g in _glass: g.visible = s != "broken"
	if instant: _open_a = 1.5 if s == "open" else 0.0

func _process(delta: float) -> void:
	_sync(false)
	_open_a = move_toward(_open_a, 1.5 if state() == "open" else 0.0, delta * 2.0)
	_pivot.rotation.y = _open_a
	if _on_ledge and kurt:
		_sway += delta
		kurt.head.rotation.z = sin(_sway * 0.9) * 0.02 + sin(_sway * 2.3) * 0.006
		if kurt.pitch < -0.85 and not _looked_down:
			_looked_down = true
			Speech.say_id("ledge_down")

func _enter(k: Kurt) -> void:
	kurt = k; _on_ledge = true
	k.rail_axis = Vector3.RIGHT
	World.emit_event("ledge", {"on": true})

func _leave(k: Kurt) -> void:
	_on_ledge = false
	k.rail_axis = Vector3.ZERO
	k.head.rotation.z = 0.0
	World.emit_event("ledge", {"on": false})
