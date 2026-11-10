class_name Building
extends Node3D
## Building 14's stairwell: the halls outside the flats. A switchback stair between landings, two
## padded doors a floor (47 and 48 on the fourth, where y = 0), green gloss to shoulder height,
## whitewash above, one bulb a landing. Built here in the town's kit (the exported flat has no
## building round it). Floors LOW..HIGH are there; below and above, the stair is gone into rubble.
##
## Per storey: the east flight climbs north from the landing to a half-landing; the west flight
## climbs back south from it to the next landing. So the whole building is one line you can walk,
## and `chain` is that line (the Super follows it).

const STOREY := 3.1
const HALF := 1.55
const LOW := 2
const HIGH := 6
const X0 := 10.42
const X1 := 14.0
const Z_STAIR := 3.45          # the landing's north edge, where the flights start
const Z_MID := 1.0             # the half-landing's south edge
const Z_END := 0.0             # the stairwell's north wall
const Z1 := 8.0                # the landing's south wall
const DIV0 := 12.04            # the wall between the flights
const DIV1 := 12.38
const DOOR_Z0 := 4.12
const DOOR_Z1 := 5.0
const CEIL := 2.75

var door48: Node3D
var door48_spot: Hotspot
var chain: Array[Vector3] = []     ## the walkable line, bottom to top (local = world: the flat is at the origin)
var lights := {}                   ## floor -> OmniLight3D
var the_super: Super
var shadows := true
var _body: StaticBody3D
var _kit: TownKit

static func floor_y(f: int) -> float:
	return (f - 4) * STOREY

## Which floor a height is on (nearest landing).
static func floor_of(y: float) -> int:
	return clampi(roundi(y / STOREY) + 4, LOW, HIGH)

func build() -> void:
	name = "Building"
	_body = StaticBody3D.new(); _body.name = "Solid"; add_child(_body)
	_kit = TownKit.new(self)
	for f in range(LOW, HIGH + 1):
		_landing(f)
		if f < HIGH:
			_flights(f)
	_shaft()
	_ends()
	_kit.finish()
	_shell()
	for mi in find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta("bulb"):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	_door48()
	_chain()

func _solid(c: Vector3, half: Vector3, basis := Basis()) -> void:
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0
	cs.shape = b; cs.transform = Transform3D(basis, c)
	_body.add_child(cs)

# --- a landing ----------------------------------------------------------------------------------

func _landing(f: int) -> void:
	var y := floor_y(f)
	var k := _kit
	# the slab: floor above, ceiling below
	k.box("stone", Vector3((X0 + X1) * 0.5, y - 0.1, (Z_STAIR + Z1) * 0.5), Vector3((X1 - X0) * 0.5, 0.1, (Z1 - Z_STAIR) * 0.5))
	# (its north edge exactly where the flights end: a lip there stops anything without knees)
	_solid(Vector3((X0 + X1) * 0.5, y - 0.1, (Z_STAIR + Z1 + 0.2) * 0.5), Vector3((X1 - X0) * 0.5 + 0.2, 0.1, (Z1 + 0.2 - Z_STAIR) * 0.5))
	k.quad("hall_ceiling", Vector3(X0, y + CEIL, Z1), Vector3(X1, y + CEIL, Z1), Vector3(X1, y + CEIL, Z_STAIR), Vector3(X0, y + CEIL, Z_STAIR), Vector3.DOWN, Vector3(X0, y, Z_STAIR))
	# the walls: west (the odd flat's door), east (the even one's), south (blind)
	var fw := Facades.Frame.new(Vector3(X0, y, Z_STAIR), Vector3(0, 0, 1), Vector3(1, 0, 0))
	_two_tone(fw, Z1 - Z_STAIR, [4.145 - Z_STAIR, 4.975 - Z_STAIR, 2.07])
	var fe := Facades.Frame.new(Vector3(X1, y, Z1), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	_two_tone(fe, Z1 - Z_STAIR, [Z1 - DOOR_Z1, Z1 - DOOR_Z0, 2.07])
	var fs := Facades.Frame.new(Vector3(X0, y, Z1), Vector3(1, 0, 0), Vector3(0, 0, -1))
	_two_tone(fs, X1 - X0, [])
	_solid(Vector3(X0 - 0.2, y + 1.45, (Z_STAIR + Z1) * 0.5), Vector3(0.2, 1.45, (Z1 - Z_STAIR) * 0.5)) if f != 4 else null
	_solid(Vector3(X1 + 0.2, y + 1.45, (Z_STAIR + Z1) * 0.5), Vector3(0.2, 1.45, (Z1 - Z_STAIR) * 0.5)) if f != 4 else null
	_solid(Vector3((X0 + X1) * 0.5, y + 1.45, Z1 + 0.2), Vector3((X1 - X0) * 0.5, 1.45, 0.2))
	# the flat numbers, stencilled; the doors of the other floors (shut, and staying shut)
	var odd := 47 + (f - 4) * 4
	for spec in [[str(odd), Vector3(X0 + 0.012, y + 2.25, 4.56), PI * 0.5], [str(odd + 1), Vector3(X1 - 0.012, y + 2.25, 4.56), -PI * 0.5]]:
		var l := Label3D.new(); l.text = spec[0]; l.font_size = 64; l.pixel_size = 0.0022
		l.modulate = Color(0.12, 0.12, 0.12); l.outline_size = 0; l.shaded = true
		add_child(l); l.position = spec[1]; l.rotation.y = spec[2]
	if f != 4:
		_shut_door(Vector3(X0 - 0.06, y, 4.145), 1.0, 4.975 - 4.145)
		_shut_door(Vector3(X1 + 0.06, y, DOOR_Z1), -1.0, DOOR_Z1 - DOOR_Z0)
	# one bare bulb a landing, on its flex: a pool under it, and the corners left to the dark.
	# Every other floor's is failing (dimmer, browner). Only the one on his floor throws shadows.
	var l := OmniLight3D.new()
	var weak := f % 2 == 1 and f != 4
	l.light_color = Color(1.0, 0.74, 0.46) if weak else Color(1.0, 0.86, 0.64)
	l.light_energy = 0.6 if weak else 1.35
	l.omni_range = 6.5; l.omni_attenuation = 2.1; l.light_specular = 0.3
	l.shadow_enabled = false; l.shadow_bias = 0.06
	add_child(l); l.position = Vector3(12.0, y + 2.18, 6.3)
	l.set_meta("base", l.light_energy)
	lights[f] = l
	k.cyl("iron", Vector3(12.0, y + 2.26, 6.3), 0.004, CEIL - 2.26, 4)
	var bulb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.035; sm.height = 0.09
	sm.radial_segments = 6; sm.rings = 3; bulb.mesh = sm
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = l.light_color * (1.1 if weak else 1.9); bm.disable_fog = true
	bulb.material_override = bm; bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.set_meta("bulb", true)
	add_child(bulb); bulb.position = Vector3(12.0, y + 2.2, 6.3)

func _two_tone(f: Facades.Frame, length: float, door: Array) -> void:
	var k := _kit
	if door.is_empty():
		Facades.wall(k, f, "hall_green", 0, length, 0, 1.5)
		Facades.wall(k, f, "hall_plaster", 0, length, 1.5, CEIL)
		return
	var d0: float = door[0]; var d1: float = door[1]; var dh: float = door[2]
	for seg in [[0.0, d0], [d1, length]]:
		Facades.wall(k, f, "hall_green", seg[0], seg[1], 0, 1.5)
		Facades.wall(k, f, "hall_plaster", seg[0], seg[1], 1.5, CEIL)
	Facades.wall(k, f, "hall_plaster", d0, d1, dh, CEIL)
	const DEPTH := 0.22
	k.quad("wood", f.p(d0, 0, 0), f.p(d0, 0, -DEPTH), f.p(d0, dh, -DEPTH), f.p(d0, dh, 0), f.x, f.o)
	k.quad("wood", f.p(d1, 0, -DEPTH), f.p(d1, 0, 0), f.p(d1, dh, 0), f.p(d1, dh, -DEPTH), -f.x, f.o)
	k.quad("wood", f.p(d0, dh, 0), f.p(d1, dh, 0), f.p(d1, dh, -DEPTH), f.p(d0, dh, -DEPTH), -f.y, f.o)

## A padded door that doesn't open: the leaf, its studs, and something to rattle.
func _shut_door(hinge: Vector3, side: float, w: float) -> void:
	var k := _kit
	var c := hinge + Vector3(side * 0.03, 1.035, side * w * 0.5 if side > 0 else -w * 0.5)
	k.box("velvet", c, Vector3(0.035, 1.035, w * 0.5 - 0.01))
	for i in 5:
		for j in 3:
			k.box("gold", c + Vector3(side * 0.038, -0.685 + i * 0.36, -0.24 + j * 0.24), Vector3(0.004, 0.012, 0.012))
	_solid(c, Vector3(0.06, 1.035, w * 0.5))
	var spot := Hotspot.make(self, Transform3D(Basis(), c + Vector3(side * 0.12, 0, 0)), Vector3(0.2, 2.0, w), "Open")
	spot.used.connect(func(): Sfx.play_at("rattle", c, -4.0, 0.95))

# --- the stairs -----------------------------------------------------------------------------------

func _flights(f: int) -> void:
	var y := floor_y(f)
	var k := _kit
	const STEPS := 9
	var run := (Z_STAIR - Z_MID) / STEPS
	var rise := HALF / STEPS
	for i in STEPS:
		# east: up, going north.  west: up, going south (from the half-landing).
		k.box("stone", Vector3((DIV1 + X1) * 0.5, y + rise * (i + 0.5), Z_STAIR - run * (i + 0.5)), Vector3((X1 - DIV1) * 0.5, rise * 0.5, run * 0.5))
		k.box("stone", Vector3((X0 + DIV0) * 0.5, y + HALF + rise * (i + 0.5), Z_MID + run * (i + 0.5)), Vector3((DIV0 - X0) * 0.5, rise * 0.5, run * 0.5))
	# what you walk on: a ramp under each flight (steps are for looking at)
	var ang := atan2(HALF, Z_STAIR - Z_MID)
	var length := Vector2(HALF, Z_STAIR - Z_MID).length()
	_solid(Vector3((DIV1 + X1) * 0.5, y + HALF * 0.5 - 0.1 * cos(ang), (Z_STAIR + Z_MID) * 0.5 - 0.1 * sin(ang)), Vector3((X1 - DIV1) * 0.5, 0.1, length * 0.5), Basis(Vector3.RIGHT, ang))
	_solid(Vector3((X0 + DIV0) * 0.5, y + HALF * 1.5 - 0.1 * cos(ang), (Z_STAIR + Z_MID) * 0.5 + 0.1 * sin(ang)), Vector3((DIV0 - X0) * 0.5, 0.1, length * 0.5), Basis(Vector3.RIGHT, -ang))
	# the half-landing
	k.box("stone", Vector3((X0 + X1) * 0.5, y + HALF - 0.1, (Z_END + Z_MID) * 0.5), Vector3((X1 - X0) * 0.5, 0.1, (Z_MID - Z_END) * 0.5))
	_solid(Vector3((X0 + X1) * 0.5, y + HALF - 0.1, (Z_END + Z_MID) * 0.5), Vector3((X1 - X0) * 0.5, 0.1, (Z_MID - Z_END) * 0.5))
	# handrails on the wall between the flights
	k.cyl_axis("iron", Vector3(DIV1 + 0.05, y + 0.95, Z_STAIR), Vector3(DIV1 + 0.05, y + HALF + 0.95, Z_MID), 0.02, 6)
	k.cyl_axis("iron", Vector3(DIV0 - 0.05, y + HALF + 0.95, Z_MID), Vector3(DIV0 - 0.05, y + STOREY + 0.95, Z_STAIR), 0.02, 6)

## The shaft's own walls, bottom to top: west, east, north, and the wall between the flights.
func _shaft() -> void:
	var k := _kit
	var y0 := floor_y(LOW) - 0.2
	var y1 := floor_y(HIGH) + CEIL
	var h := y1 - y0
	for wall in [[Vector3(X0, y0, Z_END), Vector3(0, 0, 1), Vector3(1, 0, 0), Z_STAIR - Z_END],
			[Vector3(X1, y0, Z_STAIR), Vector3(0, 0, -1), Vector3(-1, 0, 0), Z_STAIR - Z_END],
			[Vector3(X1, y0, Z_END), Vector3(-1, 0, 0), Vector3(0, 0, 1), X1 - X0]]:
		var fr := Facades.Frame.new(wall[0], wall[1], wall[2])
		# green to shoulder height above each tread line would need the stair's slope; one tone here
		var yy := 0.0
		while yy < h:
			Facades.wall(k, fr, "hall_green" if int(yy / HALF) % 2 == 0 else "hall_plaster", 0, wall[3], yy, minf(yy + HALF, h))
			yy += HALF
	_solid(Vector3(X0 - 0.2, y0 + h * 0.5, (Z_END + Z_STAIR) * 0.5), Vector3(0.2, h * 0.5, (Z_STAIR - Z_END) * 0.5))
	_solid(Vector3(X1 + 0.2, y0 + h * 0.5, (Z_END + Z_STAIR) * 0.5), Vector3(0.2, h * 0.5, (Z_STAIR - Z_END) * 0.5))
	_solid(Vector3((X0 + X1) * 0.5, y0 + h * 0.5, Z_END - 0.2), Vector3((X1 - X0) * 0.5, h * 0.5, 0.2))
	k.box("hall_plaster", Vector3((DIV0 + DIV1) * 0.5, y0 + h * 0.5, (Z_MID + Z_STAIR) * 0.5), Vector3((DIV1 - DIV0) * 0.5, h * 0.5, (Z_STAIR - Z_MID) * 0.5))
	_solid(Vector3((DIV0 + DIV1) * 0.5, y0 + h * 0.5, (Z_MID + Z_STAIR) * 0.5), Vector3((DIV1 - DIV0) * 0.5, h * 0.5, (Z_STAIR - Z_MID) * 0.5))
	k.quad("hall_ceiling", Vector3(X0, y1, Z_STAIR), Vector3(X1, y1, Z_STAIR), Vector3(X1, y1, Z_END), Vector3(X0, y1, Z_END), Vector3.DOWN, Vector3(X0, y1, Z_END))

## Below the lowest landing and above the highest, the stair has come down: rubble, and no way.
func _ends() -> void:
	var k := _kit
	var rng := RandomNumberGenerator.new(); rng.seed = 14
	for spec in [[floor_y(LOW), X0, DIV0], [floor_y(HIGH), DIV1, X1]]:
		var y: float = spec[0]
		var cx: float = (spec[1] + spec[2]) * 0.5
		for i in 22:
			var s := rng.randf_range(0.08, 0.3)
			k.box("stone" if i % 3 else "brick", Vector3(cx + rng.randf_range(-0.7, 0.7), y + rng.randf_range(0.0, 0.9), Z_STAIR - rng.randf_range(0.1, 1.4)), Vector3(s, s * 0.6, s * 0.8), Basis.from_euler(Vector3(rng.randf(), rng.randf() * 3.0, rng.randf())))
		_solid(Vector3(cx, y + 1.0, Z_STAIR - 0.25), Vector3((spec[2] - spec[1]) * 0.5, 1.1, 0.25))    # (kept under the flight that passes over it)
	# nothing under the lowest west flight's well, nothing over the top east one: floors there too
	_solid(Vector3((X0 + X1) * 0.5, floor_y(LOW) - 0.3, (Z_END + Z_STAIR) * 0.5), Vector3((X1 - X0) * 0.5, 0.1, (Z_STAIR - Z_END) * 0.5))

## Black behind everything. The world outside the flat is a flat white, and the old-console vertex
## snapping opens hairline cracks where walls meet: without this they sparkle white.
func _shell() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3):
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	const G := 0.14
	var y0 := floor_y(LOW) - 0.4
	var y1 := floor_y(HIGH) + CEIL + 0.1
	var za := Z_END - G; var zb := Z1 + G
	for side in [[X0 - G, 4.145, 4.975], [X1 + G, DOOR_Z0, DOOR_Z1]]:
		var x: float = side[0]
		q.call(Vector3(x, y0, za), Vector3(x, y0, zb), Vector3(x, 0.0, zb), Vector3(x, 0.0, za))
		q.call(Vector3(x, 0.0, za), Vector3(x, 0.0, side[1]), Vector3(x, 2.07, side[1]), Vector3(x, 2.07, za))
		q.call(Vector3(x, 0.0, side[2]), Vector3(x, 0.0, zb), Vector3(x, 2.07, zb), Vector3(x, 2.07, side[2]))
		q.call(Vector3(x, 2.07, za), Vector3(x, 2.07, zb), Vector3(x, y1, zb), Vector3(x, y1, za))
	for z in [za, zb]:
		q.call(Vector3(X0 - G, y0, z), Vector3(X1 + G, y0, z), Vector3(X1 + G, y1, z), Vector3(X0 - G, y1, z))
	for y in [y0, y1]:
		q.call(Vector3(X0 - G, y, za), Vector3(X1 + G, y, za), Vector3(X1 + G, y, zb), Vector3(X0 - G, y, zb))
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.name = "Shell"
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.disable_fog = true
	mi.material_override = m; mi.set_meta("bulb", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# --- 48's door ------------------------------------------------------------------------------------

func _door48() -> void:
	door48 = Node3D.new(); door48.name = "Door48"; add_child(door48)
	door48.position = Vector3(X1 + 0.06, 0, DOOR_Z1)
	var kd := TownKit.new(door48)
	var w := DOOR_Z1 - DOOR_Z0
	kd.box("velvet", Vector3(-0.03, 1.035, -w * 0.5), Vector3(0.035, 1.035, w * 0.5 - 0.01))
	for i in 5:
		for j in 3:
			kd.box("gold", Vector3(-0.068, 0.35 + i * 0.36, -0.2 - j * 0.24), Vector3(0.004, 0.012, 0.012))
	kd.box("gold", Vector3(-0.075, 1.02, -w + 0.1), Vector3(0.02, 0.012, 0.05))
	kd.finish()
	var body := AnimatableBody3D.new(); body.sync_to_physics = false
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.08, 2.07, w)
	cs.shape = b; cs.position = Vector3(-0.03, 1.035, -w * 0.5)
	body.add_child(cs); door48.add_child(body)
	var peep := MeshInstance3D.new(); var pm := SphereMesh.new(); pm.radius = 0.012; pm.height = 0.024
	peep.mesh = pm; peep.name = "Peephole"
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.02, 0.02, 0.02)
	pmat.emission_enabled = true; pmat.emission = Color(0, 0, 0)
	peep.material_override = pmat
	door48.add_child(peep); peep.position = Vector3(-0.07, 1.5, -w * 0.5)
	var white := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(w, 2.07); white.mesh = qm
	var wm := StandardMaterial3D.new(); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = Color(1.3, 1.3, 1.35); wm.disable_fog = true
	white.material_override = wm; white.name = "White48"
	add_child(white); white.position = Vector3(X1 + 0.3, 1.035, (DOOR_Z0 + DOOR_Z1) * 0.5); white.rotation.y = -PI * 0.5
	door48_spot = Hotspot.make(self, Transform3D(Basis(), Vector3(X1 - 0.1, 1.1, (DOOR_Z0 + DOOR_Z1) * 0.5)), Vector3(0.5, 2.0, w), "Go in")
	door48_spot.enabled = false

## 48's peephole lights; the door comes off its latch and stands ajar.
func open_door48() -> void:
	var peep: MeshInstance3D = door48.get_node("Peephole")
	(peep.material_override as StandardMaterial3D).emission = Color(1.6, 1.5, 1.2)
	await get_tree().create_timer(1.6, false).timeout
	Sfx.play_at("click", door48.global_position + Vector3(0, 1, -0.4), 4.0, 0.7)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(door48, "rotation:y", deg_to_rad(-28.0), 1.8)
	Sfx.play_at("creak", door48.global_position + Vector3(0, 1, -0.4), -6.0, 1.1)
	door48_spot.enabled = true

# --- the line through it ----------------------------------------------------------------------------

func _chain() -> void:
	chain.clear()
	for f in range(LOW, HIGH + 1):
		var y := floor_y(f)
		if f > LOW:
			chain.append(Vector3(11.2, y, Z_STAIR + 0.35))        # off the west flight
		chain.append(Vector3(12.2, y, 5.6))                      # the landing
		if f < HIGH:
			chain.append(Vector3(13.2, y, Z_STAIR + 0.35))        # the foot of the east flight
			chain.append(Vector3(13.2, y + HALF, 0.55))           # the half-landing, east
			chain.append(Vector3(11.2, y + HALF, 0.55))           # the half-landing, west

## The Super starts his rounds (once; from the bottom of the building).
func spawn_super(player: Player) -> Super:
	if the_super:
		return the_super
	the_super = Super.new(); the_super.name = "TheSuper"
	the_super.building = self
	add_child(the_super)
	the_super.setup("super", {}, player, landing_point(LOW), 1414)
	the_super.rotation.y = PI
	return the_super

func landing_point(f: int) -> Vector3:
	return Vector3(12.2, floor_y(f), 5.6)

func nearest(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in chain.size():
		var c := chain[i]
		var d := Vector2(p.x - c.x, p.z - c.z).length() + absf(p.y - c.y) * 3.0
		if d < bd:
			bd = d; best = i
	return best

## The next point to walk to, going from `from` toward `to` along the stair.
func next_step(from: Vector3, to: Vector3) -> Vector3:
	var i := nearest(from)
	var j := nearest(to)
	if i == j:
		return to
	var dir := 1 if j > i else -1
	var here := chain[i]
	var nxt := chain[i + dir]
	# past this point already (between it and the next)? then on to the next
	var along := (from - here).dot((nxt - here).normalized())
	if Vector2(from.x - here.x, from.z - here.z).length() < 0.45 or along > 0.2:
		return nxt if i + dir != j else (to if Vector2(to.x - nxt.x, to.z - nxt.z).length() < 3.0 and absf(to.y - nxt.y) < 0.8 else nxt)
	return here

## Only the landings near him are lit, and only his own throws shadows (one shadow light at once:
## what a phone can afford). The floors beyond are black: you hear what's on them before you see it.
func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_visible_in_tree():
		return
	var fy := cam.global_position.y - 1.5
	var f := floor_of(fy)
	for k in lights:
		var l: OmniLight3D = lights[k]
		var want := 1.0 if absf(floor_y(int(k)) - fy) < STOREY * 1.3 else 0.0
		var e: float = move_toward(l.light_energy / float(l.get_meta("base")), want, delta * 1.5)
		l.light_energy = float(l.get_meta("base")) * e
		l.visible = e > 0.01
		l.shadow_enabled = int(k) == f and shadows
