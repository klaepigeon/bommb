class_name Building
extends Node3D
## Building 14's stairwell: a switchback stair from the lobby (floor 1) to floor 5, beside Flat 47's
## front door. Green gloss paint to shoulder height, whitewash above, one bulb a landing. Two flat
## doors on every landing: most nailed shut since the evacuation (knock, and once in a while
## something knocks back); 48, 51 and 44 open into what's left of them. The lobby's street door has
## four bolts, one for every flat the building wants you to see, and it lets you go when you have.
## The Super walks these stairs.
##
## Floor f's landing is at y = (f - 4) * STOREY (47's is y = 0). Stairwell: x 10.42..14.0, z 0..8.

const STOREY := 3.0
const X0 := 10.42
const X1 := 14.0
const XM := 12.21
const ZL := 3.45            ## the landing's north edge
const ZH := 1.4             ## the half-landing's south edge
const Z1 := 8.0
const DOOR_Z := Vector2(4.145, 4.975)
const FLOORS := [1, 2, 3, 4, 5]
## [west, east] on each floor: "" = nailed shut, "47" etc. = a flat that opens, "street" the way out
const DOORS := {1: ["street", "mail"], 2: ["41", "42"], 3: ["43", "44"], 4: ["47", "48"], 5: ["51", "52"]}
const BOLTS := ["47", "48", "51", "44"]

var level
var nav: Nav
var travel: Callable           ## func(flat_id, from_landing: bool): the story moves Kurt in or out
var doors := {}                ## "4:east" -> Usable
var street: Usable
var bolts := {}                ## "47" -> bool (slid back)
var _kit_wall: Material
var _kit_paint: Material
var _kit_floor: Material
var _kit_step: Material
var _knocks := 0

static func Y(f: int) -> float:
	return (f - 4) * STOREY

func build(p_level, p_nav: Nav) -> void:
	level = p_level; nav = p_nav
	for b in BOLTS: bolts[b] = false
	_kit_wall = Mats.tex(Tex.get_tex("plaster"), -1, Color(1.1, 1.08, 1.0))
	_kit_paint = Mats.tex(Tex.get_tex("paint_green"), -1)
	_kit_floor = Mats.tex(Tex.get_tex("concrete"), -1)
	_kit_step = Mats.tex(Tex.get_tex("concrete"), -1, Color(1.15, 1.12, 1.05))
	for f in FLOORS: _floor(f)
	_lobby()
	_top()
	_nav()
	World.register("building", func(): return {"bolts": bolts, "knocks": _knocks}, func(d):
		bolts = d.get("bolts", bolts); _knocks = int(d.get("knocks", 0)))
	Log.mark("building built")

static func floor_of(p: Vector3) -> int:
	return clampi(floori((p.y - Y(1)) / STOREY + 0.25) + 1, 1, 5)

func contains(p: Vector3) -> bool:
	return p.x > X0 - 0.02 and p.x < X1 + 0.02 and p.z > -0.05 and p.z < Z1 + 0.05 and p.y > Y(1) - 1.0 and p.y < Y(5) + 3.5

func zone_of(p: Vector3) -> int:
	return 60 + floor_of(p) if contains(p) else -1

# ------------------------------------------------------------------------------------ a floor
func _floor(f: int) -> void:
	var y := Y(f)
	var z := 60 + f
	var kit := Kit.new()
	var floor_m := Mats.tex(Tex.get_tex("concrete"), z)
	var wall_m := Mats.tex(Tex.get_tex("plaster"), z, Color(1.1, 1.08, 1.0))
	var paint_m := Mats.tex(Tex.get_tex("paint_green"), z)
	var step_m := Mats.tex(Tex.get_tex("concrete"), z, Color(1.15, 1.12, 1.05))
	var body := StaticBody3D.new(); body.name = "Stair%d" % f; add_child(body)
	# the landing slab (47's floor already carries floor 4's)
	kit.box(floor_m, Vector3((X0 + X1) * 0.5, y - 0.1, (ZL + Z1) * 0.5), Vector3(X1 - X0, 0.2, Z1 - ZL), Basis(), 63)
	_solid(body, Vector3((X0 + X1) * 0.5, y - 0.1, (ZL + Z1) * 0.5), Vector3(X1 - X0, 0.2, Z1 - ZL))
	# walls: the landing's three sides and the half-landing's, paint below, whitewash above
	var top := y + STOREY
	for seg in [[Vector3(X0, y, ZL), Vector3(X0, y, Z1), "w"], [Vector3(X1, y, Z1), Vector3(X1, y, ZL), "e"], [Vector3(X0, y, Z1), Vector3(X1, y, Z1), "s"],
			[Vector3(X0, y, 0.0), Vector3(X0, y, ZL), "w2"], [Vector3(X1, y, ZL), Vector3(X1, y, 0.0), "e2"], [Vector3(X1, y, 0.0), Vector3(X0, y, 0.0), "n"]]:
		_wall(kit, seg[0], seg[1], y, top, paint_m, wall_m, String(seg[2]) in ["w", "e"])
		var a: Vector3 = seg[0]; var b: Vector3 = seg[1]
		var c := (a + b) * 0.5
		var len := a.distance_to(b)
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		if String(seg[2]) in ["w", "e"]:
			# solid either side of the door
			var x := a.x + (-0.15 if String(seg[2]) == "w" else 0.15)
			_solid(body, Vector3(x, y + 1.5, (ZL + DOOR_Z.x) * 0.5), Vector3(0.3, STOREY, DOOR_Z.x - ZL))
			_solid(body, Vector3(x, y + 1.5, (DOOR_Z.y + Z1) * 0.5), Vector3(0.3, STOREY, Z1 - DOOR_Z.y))
			_solid(body, Vector3(x, y + 2.6, (DOOR_Z.x + DOOR_Z.y) * 0.5), Vector3(0.3, 0.8, DOOR_Z.y - DOOR_Z.x))
		else:
			# behind the wall, outside the stairwell
			var n := Vector3(0, 0, -0.15 if String(seg[2]) == "n" else 0.15) if along_x else Vector3(-0.15 if String(seg[2]) == "w2" else 0.15, 0, 0)
			_solid(body, c + n + Vector3(0, 1.5, 0), Vector3(len if along_x else 0.3, STOREY + 0.2, 0.3 if along_x else len))
	# the flights up to the next floor: east, up to the half-landing; west, on up
	if f < 5:
		_flight(kit, body, step_m, Vector3(XM, y, ZL), Vector3(X1, y + STOREY * 0.5, ZH), z)
		kit.box(floor_m, Vector3((X0 + X1) * 0.5, y + STOREY * 0.5 - 0.1, ZH * 0.5), Vector3(X1 - X0, 0.2, ZH), Basis(), 63)
		_solid(body, Vector3((X0 + X1) * 0.5, y + STOREY * 0.5 - 0.1, ZH * 0.5), Vector3(X1 - X0, 0.2, ZH))
		_flight(kit, body, step_m, Vector3(X0, y + STOREY * 0.5, ZH), Vector3(XM, y + STOREY, ZL), z)
		# the banister down the middle
		kit.box(Mats.tex(Tex.get_tex("floorboards"), z, Color(0.6, 0.35, 0.25)), Vector3(XM, y + STOREY * 0.5 + 0.95, (ZH + ZL) * 0.5), Vector3(0.06, 0.06, ZL - ZH + 0.3), Basis(Vector3.RIGHT, atan2(STOREY * 0.5, ZL - ZH)))
		_solid(body, Vector3(XM, y + 1.6, (ZH + ZL) * 0.5), Vector3(0.05, STOREY + 0.4, ZL - ZH - 0.1))
	# a number, stencilled big on the landing wall
	var lbl := Label3D.new(); lbl.text = str(f); lbl.font_size = 220; lbl.pixel_size = 0.004
	lbl.modulate = Color(0.85, 0.82, 0.72); lbl.shaded = false; lbl.outline_size = 0
	add_child(lbl); lbl.position = Vector3((X0 + X1) * 0.5, y + 1.9, Z1 - 0.03); lbl.rotation.y = PI
	# the bulb (two of them are dead)
	var dead := f == 2
	var l := Lamp.make(self, Vector3(12.2, y + STOREY - 0.45, 6.2), Color(1.0, 0.88, 0.68), 0.85, 6.5, PackedInt32Array([z]), "", "dying" if f == 3 else "")
	l.on = not dead
	l.name = "StairBulb%d" % f
	kit.box(Mats.flat(Color(1, 0.92, 0.75) if not dead else Color(0.3, 0.3, 0.3), -1, 1.0 if not dead else 0.0), l.global_position + Vector3(0, 0.05, 0), Vector3(0.07, 0.1, 0.07))
	var hl := Lamp.make(self, Vector3(12.2, y + STOREY * 0.5 + 2.3, 0.6), Color(0.8, 0.85, 0.95), 0.35, 4.5, PackedInt32Array([z, 60 + mini(f + 1, 5)]))
	hl.name = "HalfLamp%d" % f
	kit.commit(self, "Floor%d" % f)
	# the two doors
	var pair: Array = DOORS[f]
	for side in 2:
		var what := String(pair[side])
		if what == "47": continue          # 47's own door is the real one
		_landing_door(f, side, what)

func _wall(kit: Kit, a: Vector3, b: Vector3, y0: float, y1: float, paint: Material, white: Material, door: bool) -> void:
	var band := y0 + 1.5
	# (two-sided quads: the corridor's side faces in; the door's hole is left in walls with doors)
	if door:
		var za: float = minf(a.z, b.z); var zb: float = maxf(a.z, b.z)
		for span in [[za, DOOR_Z.x], [DOOR_Z.y, zb]]:
			kit.quad(paint, Vector3(a.x, y0, span[0]), Vector3(a.x, y0, span[1]), Vector3(a.x, band, span[1]), Vector3(a.x, band, span[0]))
			kit.quad(white, Vector3(a.x, band, span[0]), Vector3(a.x, band, span[1]), Vector3(a.x, y1, span[1]), Vector3(a.x, y1, span[0]))
		kit.quad(white, Vector3(a.x, y0 + 2.08, DOOR_Z.x), Vector3(a.x, y0 + 2.08, DOOR_Z.y), Vector3(a.x, y1, DOOR_Z.y), Vector3(a.x, y1, DOOR_Z.x))
		return
	kit.quad(paint, Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, band, b.z), Vector3(a.x, band, a.z))
	kit.quad(white, Vector3(a.x, band, a.z), Vector3(b.x, band, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z))

func _solid(body: StaticBody3D, c: Vector3, size: Vector3, b := Basis()) -> void:
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = size; cs.shape = bx
	cs.transform = Transform3D(b, c)
	body.add_child(cs)

## A flight of ten steps from (a.x, a.y, a.z) to (b.x, b.y, b.z): the steps to look at, a ramp to walk.
func _flight(kit: Kit, body: StaticBody3D, m: Material, a: Vector3, b: Vector3, _z: int) -> void:
	var x0 := minf(a.x, b.x); var x1 := maxf(a.x, b.x)
	const N := 10
	for i in N:
		var t0 := float(i) / N; var t1 := float(i + 1) / N
		var za := lerpf(a.z, b.z, t0); var zb := lerpf(a.z, b.z, t1)
		var yt := lerpf(a.y, b.y, t1)
		var h := yt - minf(a.y, b.y) + 0.05
		kit.box(m, Vector3((x0 + x1) * 0.5, yt - h * 0.5, (za + zb) * 0.5), Vector3(x1 - x0, h, absf(zb - za)))
	var run := absf(b.z - a.z); var rise := b.y - a.y
	var ang := atan2(rise, run) * (1.0 if b.z < a.z else -1.0)
	var len := sqrt(run * run + rise * rise)
	_solid(body, Vector3((x0 + x1) * 0.5, (a.y + b.y) * 0.5 - 0.08, (a.z + b.z) * 0.5), Vector3(x1 - x0, 0.16, len), Basis(Vector3.RIGHT, ang))

# ------------------------------------------------------------------------------ the landing doors
func door_pos(f: int, side: int) -> Vector3:
	return Vector3(X0 if side == 0 else X1, Y(f), (DOOR_Z.x + DOOR_Z.y) * 0.5)

func _landing_door(f: int, side: int, what: String) -> void:
	var p := door_pos(f, side)
	var out := 1.0 if side == 0 else -1.0       # into the stairwell
	var u := Usable.make(self, Transform3D(Basis(), p + Vector3(out * 0.04, 1.04, 0)), Vector3(0.1, 2.08, 0.84), [], true)
	u.title = "Flat " + what if what.is_valid_int() else ("Street door" if what == "street" else "Post room")
	var kit := Kit.new()
	var leaf := Mats.tex(Tex.get_tex("cloth"), 60 + f, Color(0.55, 0.3, 0.28) if what != "street" else Color(0.5, 0.45, 0.38))
	kit.box(leaf, p + Vector3(out * 0.03, 1.04, 0), Vector3(0.06, 2.06, 0.82))
	kit.box(Mats.flat(Color(0.75, 0.7, 0.5), 60 + f), p + Vector3(out * 0.07, 1.0, 0.3 * (1.0 if side == 0 else -1.0)), Vector3(0.03, 0.04, 0.1))
	kit.commit(self, "Door_" + what)
	if what.is_valid_int():
		var plate := Label3D.new(); plate.text = what; plate.font_size = 48; plate.pixel_size = 0.0025
		plate.modulate = Color(0.85, 0.75, 0.45); plate.shaded = false
		add_child(plate); plate.position = p + Vector3(out * 0.08, 1.75, 0); plate.rotation.y = PI * 0.5 * out
	doors["%d:%d" % [f, side]] = u
	match what:
		"48", "44":
			u.offer = func(_k): return [{"id": "in", "label": "Go in"}, {"id": "knock", "label": "Knock"}]
		"51":
			u.offer = func(k): return _door51_verbs(k)
		"street":
			street = u
			u.offer = func(_k): return _street_verbs()
		_:
			u.offer = func(_k): return [{"id": "try", "label": "Try the door"}, {"id": "knock", "label": "Knock"}]
	u.acted.connect(func(v, k): _door_act(what, v, k, u))

func _door51_verbs(_k) -> Array:
	if World.flag("51_open"): return [{"id": "in", "label": "Go in"}]
	var v: Array = [{"id": "try", "label": "Try the door"}, {"id": "kick", "label": "Kick"}]
	if Progress.has("coral_grip"): v.push_front({"id": "snap", "label": "Snap the chain"})
	return v

func _door_act(what: String, v: String, k, u: Usable) -> void:
	match v:
		"in": travel.call(what, true)
		"knock":
			Audio.play("knock", u.global_position, 0.0)
			Noises.make(u.global_position, 9.0, "knock", k)
			_knocks += 1
			if _knocks % 3 == 0:
				await get_tree().create_timer(1.8, false).timeout
				Audio.play("knock", u.global_position + Vector3(0, 0, 0.3), -10.0, 0.9)
				await get_tree().create_timer(0.35, false).timeout
				Audio.play("knock", u.global_position + Vector3(0, 0, 0.3), -10.0, 0.9)
		"try":
			Audio.play("rattle", u.global_position, -2.0)
			Noises.make(u.global_position, 5.0, "rattle", k)
			if what == "51":
				Audio.play("chain", u.global_position, -4.0)
				World.emit_event("looked", {"title": "Flat 51", "desc": "It opens a hand's width on a chain, from the inside. Dust on the floor in there, and one set of footprints going in.", "key": "door51"})
			elif what == "mail":
				World.emit_event("looked", {"title": "Post room", "desc": "Locked. Through the grille: the boxes, and 47's stuffed full of post dated after the evacuation.", "key": "mail"})
			else:
				World.emit_event("looked", {"title": u.title, "desc": "Nailed shut, from the outside. A notice on it: EVACUATED 15.X. DO NOT ENTER.", "key": "sealed"})
		"kick", "snap":
			var hp := float(u.get_meta("hp", 100.0)) - (100.0 if v == "snap" else (45.0 if Progress.has("coral_grip") else 25.0))
			u.set_meta("hp", hp)
			Audio.play("kick", u.global_position, 0.0)
			Noises.make(u.global_position, 18.0, "bang", k)
			if hp <= 0.0:
				Audio.play("splinter", u.global_position, 2.0)
				World.set_flag("51_open", "forced")
				World.emit_event("door_broken", {"door": "51"})
		"bolts":
			_street_look()
		"out":
			World.emit_event("escaped", {})

# ------------------------------------------------------------------------------ the street door
func slide_bolt(flat: String) -> void:
	if bolts.get(flat, true): return
	bolts[flat] = true
	World.set_flag("bolt_" + flat)
	# heard from anywhere in the building: a bolt going back, a long way down
	Audio.play("latch", null, -6.0, 0.7)
	World.emit_event("bolt", {"flat": flat, "left": BOLTS.filter(func(b): return not bolts[b]).size()})

func all_bolts() -> bool:
	for b in BOLTS:
		if not bolts[b]: return false
	return true

func _street_verbs() -> Array:
	if all_bolts(): return [{"id": "out", "label": "Go out"}]
	return [{"id": "bolts", "label": "Look at the bolts"}, {"id": "try", "label": "Try the door"}]

func _street_look() -> void:
	var t := "Four bolts, top to bottom, painted over so often they've grown into the frame. A number scratched beside each: "
	var parts: Array = []
	for b in BOLTS: parts.append("%s (%s)" % [b, "drawn back" if bolts[b] else "shot"])
	World.emit_event("looked", {"title": "Street door", "desc": t + ", ".join(parts) + ".", "key": "bolts"})

func shot(_at: Vector3, _by) -> void:
	pass

# ------------------------------------------------------------------------------ the lobby, the top
func _lobby() -> void:
	var y := Y(1)
	var kit := Kit.new()
	var tin := Mats.tex(Tex.get_tex("metal"), 61, Color(0.8, 0.85, 0.7))
	for i in 12:
		var c := i % 6; var r := i / 6
		kit.box(tin, Vector3(X0 + 0.6 + c * 0.42, y + 1.2 + r * 0.32, Z1 - 0.12), Vector3(0.38, 0.28, 0.2))
	kit.commit(self, "Mailboxes")
	var mb := Usable.make(self, Transform3D(Basis(), Vector3(11.9, y + 1.35, Z1 - 0.2)), Vector3(2.6, 0.7, 0.3), [{"id": "look", "label": "Look"}])
	mb.title = "Post boxes"
	mb.acted.connect(func(_v, _k): World.emit_event("looked", {"title": "Post boxes", "desc": "Twelve tin boxes. 47's is stuffed so full the flap won't shut: bills, a postcard from Kursk, all of it postmarked after the 15th.", "key": "post"}))
	# the basement door, under the first flight: chained, warm water under it
	var bd := Usable.make(self, Transform3D(Basis(), Vector3(X0 + 0.06, y + 1.0, 2.4)), Vector3(0.1, 2.0, 0.8), [{"id": "knock", "label": "Knock"}, {"id": "look", "label": "Look"}], true)
	var bk := Kit.new()
	bk.box(Mats.tex(Tex.get_tex("metal"), 61, Color(0.5, 0.45, 0.4)), Vector3(X0 + 0.04, y + 1.0, 2.4), Vector3(0.05, 2.0, 0.8))
	bk.commit(self, "BasementDoor")
	bd.title = "Basement door"
	bd.acted.connect(func(v, k):
		if v == "knock":
			Audio.play("knock", bd.global_position, 0.0)
			await get_tree().create_timer(1.5, false).timeout
			for i in 3: Audio.play("knock", bd.global_position, -8.0, 0.85); await get_tree().create_timer(0.35, false).timeout
			await get_tree().create_timer(0.8, false).timeout
			for i in 3: Audio.play("knock", bd.global_position, -8.0, 0.85); await get_tree().create_timer(0.35, false).timeout
		else:
			World.emit_event("looked", {"title": "Basement door", "desc": "Chained, and the chain padlocked. Warm water is seeping out under it, the colour of tea.", "key": "basement"}))
	Puddle.spill(self, Vector3(X0 + 0.5, y + 0.05, 2.4), 1.5)

func _top() -> void:
	# above 5 the stair has come down: a heap of steps and plaster on the half-landing
	var y := Y(5)
	var body := StaticBody3D.new(); add_child(body)
	_solid(body, Vector3((X0 + X1) * 0.5, y + 2.95, (ZL + Z1) * 0.5), Vector3(X1 - X0, 0.2, Z1 - ZL))
	_solid(body, Vector3((X0 + X1) * 0.5, y + 2.3, 0.7), Vector3(X1 - X0, 1.6, 1.4))      # where the next half-landing was
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	kit.box(Mats.tex(Tex.get_tex("plaster"), 65), Vector3((X0 + X1) * 0.5, y + 2.95, (ZL + Z1) * 0.5), Vector3(X1 - X0, 0.2, Z1 - ZL))
	for i in 24:
		var p := Vector3(rng.randf_range(X0 + 0.2, X1 - 0.2), y + rng.randf_range(1.6, 2.9), rng.randf_range(0.1, 1.3))
		kit.box(Mats.tex(Tex.get_tex("concrete"), 65), p, Vector3(rng.randf_range(0.3, 1.1), rng.randf_range(0.15, 0.5), rng.randf_range(0.3, 0.8)), Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf()))
	kit.commit(self, "Collapse")

# ------------------------------------------------------------------------------ where things walk
func _nav() -> void:
	var prev := -1
	for f in FLOORS:
		var y := Y(f)
		var land := nav.add(Vector3(12.2, y, 5.6), "stair_%d" % f)
		nav.add(Vector3(11.0, y, (DOOR_Z.x + DOOR_Z.y) * 0.5), "stair_%d_w" % f)
		nav.join(land, land + 1)
		nav.add(Vector3(13.4, y, (DOOR_Z.x + DOOR_Z.y) * 0.5), "stair_%d_e" % f)
		nav.join(land, land + 2)
		if prev >= 0: nav.join(prev, land)
		if f < 5:
			# along the flights (the ramps), not across them
			var a0 := nav.add(Vector3(13.1, y + 0.02, ZL + 0.15), "stair_%d_up0" % f)
			var a1 := nav.add(Vector3(13.1, y + STOREY * 0.5 + 0.02, ZH - 0.15), "stair_%d_up0t" % f)
			var h := nav.add(Vector3(12.2, y + STOREY * 0.5 + 0.02, 0.7), "stair_%d_half" % f)
			var b0 := nav.add(Vector3(11.3, y + STOREY * 0.5 + 0.02, ZH - 0.15), "stair_%d_up1" % f)
			var b1 := nav.add(Vector3(11.3, y + STOREY + 0.02, ZL + 0.15), "stair_%d_up1t" % f)
			nav.join(land, a0); nav.join(a0, a1); nav.join(a1, h); nav.join(h, b0); nav.join(b0, b1)
			prev = b1
	# 47's landing is floor 4's
	if nav.tags.has("flat_landing"): nav.join(nav.tags["flat_landing"], nav.tags["stair_4"])
