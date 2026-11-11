class_name Flat47
extends Node3D
## Flat 47: the first build's painted flat (assets/flat47/flat47.glb + level.json), made a place
## that works. Every surface on the game's own lighting, by room. Doors, drawers and ~140 loose
## things are physical; the papers can be read; the fuse box, the TV, the radio, the bath and the
## front door's chain are systems. Behind the wardrobe the box room has gone through into the walls.
## Metres; floor at y=0; the flat runs x 0..10, z 0..8; the landing is east of the front door.
##   living (x0-4.4, z0-5.2)   bedroom (4.4-7.6, 0-3.8)   kitchen (7.6-10, 0-3.8)
##   hall (4.4-10, 3.8-5.2) ── front door x=10.06 ── landing (x 10.4-14)
##   box room (0-2.8, 5.2-8)   Sonya's room (2.8-6.4)    bathroom (6.4-10)    balcony (z<0)

const H := 2.75
const KEEP := AABB(Vector3(-0.6, -0.8, -1.95), Vector3(14.6, 4.3, 10.45))
const ROOMS := {"living": 1, "bedroom": 2, "kitchen": 3, "hall": 4, "storage": 5, "child": 6, "bath": 7}
const BALCONY := 8
const LANDING := 64            ## the stairwell's floor 4 (Building: 60 + floor)
const MARTA_SEAT := Vector3(3.02, 0.0, 1.45)
const TABLE := Vector3(2.4, 0.78, 1.35)
const WARDROBE_AT := Vector3(1.95, 0.005, 4.84)
const WARDROBE_END := Vector3(2.92, 0.005, 4.84)
## Holes knocked through into the walls (the maze): [min, max] boxes through the wall.
const HOLES := {
	"boxroom": [Vector3(1.28, -0.1, 7.9), Vector3(2.38, 2.05, 8.5)],
	"child": [Vector3(5.25, -0.1, 7.9), Vector3(5.95, 1.22, 8.5)],
	"bath": [Vector3(8.22, -0.1, 7.9), Vector3(8.92, 1.4, 8.5)],
}
const POINTS := {
	"landing": Vector3(11.4, 0, 4.55), "door_out": Vector3(10.06, 1.35, 4.55), "hall": Vector3(8.6, 0, 4.5),
	"hall_west": Vector3(5.1, 0, 4.55), "living_in": Vector3(3.9, 0, 4.4), "near_marta": Vector3(3.55, 0, 1.9),
	"wake": Vector3(3.5, 0, 1.2), "by_door": Vector3(3.95, 0, 4.4), "by_wardrobe": Vector3(2.0, 0, 4.2),
	"boxroom": Vector3(1.8, 0, 6.6), "balcony": Vector3(2.2, -0.12, -1.0), "fusebox": Vector3(8.95, 0, 4.3),
	"bath": Vector3(7.4, 0, 6.8), "child": Vector3(4.6, 0, 6.4),
}

var level: Dictionary
var docs: Dictionary
var doors := {}                ## id -> Door
var props := {}                ## key -> Prop
var lamps := {}                ## name -> Lamp
var wardrobe: Node3D
var wardrobe_body: AnimatableBody3D
var wardrobe_shoves := 0
var wardrobe_toppled := false
var bath: WaterBody
var marta_chair: Node3D
var tv_on := false
var radio_on := false
var _tv_lamp: Lamp
var _tv_snd: AudioStreamPlayer3D
var _radio_snd: AudioStreamPlayer3D
var _lure_t := 0.0
var _hole_mats := {}           ## hole name -> [materials cut]

func build() -> void:
	level = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flat47/level.json"))
	docs = JSON.parse_string(FileAccess.get_file_as_string("res://content/docs.json"))
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Model"
	add_child(flat)
	_surfaces(flat)
	_behaviours(flat)
	_collision()
	_lamps()
	_outside()
	_systems()
	_wardrobe()
	_holes()
	World.register("flat47", _save, _load)
	Log.mark("flat47 built: %d props, %d doors" % [props.size(), doors.size()])

# ------------------------------------------------------------------------------- where is what
func zone_of(p: Vector3) -> int:
	if p.z < -0.05 and p.x > 0.3 and p.x < 4.3 and p.z > -2.0: return BALCONY
	if p.y > 2.9 or p.y < -1.2: return -1
	if p.x > 10.3 and p.x < 14.5 and p.z > 3.3 and p.z < 8.3: return LANDING
	for k in level.rooms:
		var r: Dictionary = level.rooms[k]
		if p.x >= r.x0 and p.x < r.x1 and p.z >= r.z0 and p.z < r.z1:
			return int(ROOMS.get(k, -1))
	return -1

func room_name(p: Vector3) -> String:
	for k in level.rooms:
		var r: Dictionary = level.rooms[k]
		if p.x >= r.x0 and p.x < r.x1 and p.z >= r.z0 and p.z < r.z1:
			return k
	return ""

func surface_of(p: Vector3) -> String:
	match zone_of(p):
		3, 7: return "step_tile"
		8, 9: return "step_tile"
	return "step_wood"

# ------------------------------------------------------------------------------- the model
func _surfaces(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = m.global_transform * m.get_aabb()
		var c := a.get_center()
		if not KEEP.has_point(c) or a.size.length() > 40.0 or c.x > 14.2:
			m.queue_free(); continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var z := -2
		var n: Node = m
		while n and n != root:
			var nm := String(n.name)
			var room := nm.split("-")[0] if "-" in nm else ""
			if ROOMS.has(room): z = ROOMS[room]; break
			n = n.get_parent()
		if z == -2:
			z = zone_of(c)
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			if src: m.set_surface_override_material(i, Mats.convert(src, z))
		m.set_meta("zone", z)

func _behaviours(root: Node) -> void:
	var nodes := root.find_children("*", "Node3D", true, false)
	for n in nodes:
		if not n.has_meta("extras"): continue
		var ex: Dictionary = n.get_meta("extras")
		match String(ex.get("kind", "")):
			"door": _door(n, ex)
			"drawer": _drawer(n, ex)
	for n in nodes:
		if not is_instance_valid(n) or not n.has_meta("extras") or not n.is_inside_tree(): continue
		var ex: Dictionary = n.get_meta("extras")
		match String(ex.get("kind", "")):
			"prop", "pick": _prop(n, ex)

func _door(n: Node3D, ex: Dictionary) -> void:
	var id := String(ex.get("id", n.name))
	if id == "dStore":
		# torn off its hinges: the doorway behind the wardrobe goes into the walls
		n.position = Vector3(0.35, 0.03, 6.9)
		n.rotation = Vector3(-PI * 0.5, 0.4, 0.0)
		return
	var d := Door.new(); d.name = "Door_" + id
	var xf := n.global_transform
	n.get_parent().add_child(d)
	d.global_transform = xf
	n.reparent(d, true)
	n.transform = Transform3D.IDENTITY
	d.setup(id, ex)
	var shut := Transform3D(Basis(Vector3.UP, d.psi0), d.position)
	d.zone_a = zone_of(shut * Vector3(d.w * 0.5, 1.0, 0.5))
	d.zone_b = zone_of(shut * Vector3(d.w * 0.5, 1.0, -0.5))
	d.set_angle(d.angle)
	doors[id] = d
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		Mats.own_zone(mi, -1)

func _drawer(n: Node3D, ex: Dictionary) -> void:
	var dr := Drawer.new()
	n.get_parent().add_child(dr)
	dr.global_transform = n.global_transform
	n.reparent(dr, true)
	dr.setup(float(ex.get("max", 0.3)))

func _prop(n: Node3D, ex: Dictionary) -> void:
	var key := String(n.name)
	var mass := float(ex.get("mass", 1.0))
	var d: Dictionary = docs.get(key, {})
	var title := String(ex.get("name", "")).replace("_", " ")
	var desc := String(d.get("desc", ex.get("desc", "")))
	if key == "prop_34_Wardrobe":
		return
	var size := Vector3.ZERO; var centre := Vector3.ZERO
	if ex.has("size") and (ex.size as Array).size() == 3:
		size = Vector3(ex.size[0], ex.size[1], ex.size[2]); centre = Vector3(ex.centre[0], ex.centre[1], ex.centre[2]) if ex.has("centre") else Vector3(0, size.y * 0.5, 0)
	else:
		var aabb := AABB(); var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
			var a: AABB = (n.global_transform.affine_inverse() * (m as Node3D).global_transform) * (m as MeshInstance3D).get_aabb()
			aabb = a if first else aabb.merge(a); first = false
		size = aabb.size; centre = aabb.get_center()
	if key == "prop_8_Chair":
		marta_chair = n          # hers: it's grown into the floor
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = size; cs.shape = b; cs.position = centre; sb.add_child(cs); n.add_child(sb)
		return
	if mass >= 30.0:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = size; cs.shape = b; cs.position = centre; sb.add_child(cs); n.add_child(sb)
		return
	var p := Prop.new()
	p.mass = maxf(mass, 0.05)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = size.max(Vector3(0.04, 0.04, 0.04)); cs.shape = b; cs.position = centre
	p.add_child(cs)
	var xf := n.global_transform.orthonormalized()
	n.get_parent().add_child(p)
	p.global_transform = xf
	n.reparent(p, true)
	p.key = key; p.title = title; p.desc = desc
	p.stuff = _stuff(title)
	if d.has("text"): p.doc = key; p.title = String(d.get("title", title))
	if String(ex.get("kind", "")) == "pick" and ex.get("read", false): p.doc = key
	match key:
		"prop_37_Magazine": p.item = "magazine"
		"prop_40_Child_s_shoe": p.item = "shoe_left"
		"pick_127_Matches": p.item = "matches"
	if title.begins_with("Three litre jar") and desc.begins_with("Water"): p.contents = "water"
	if p.stuff in ["cloth", "paper", "plastic"] or (mass < 0.4 and p.stuff == "wood"): p.floats = true
	props[key] = p

static func _stuff(t: String) -> String:
	var l := t.to_lower()
	for w in ["glass", "jar", "bottle", "shade"]:
		if w in l: return "glass"
	for w in ["cup", "tureen", "ashtray", "plate"]:
		if w in l: return "china"
	for w in ["tin", "saucepan", "kettle", "hammer", "axe", "bucket", "stove", "battery", "canister", "razor", "knife"]:
		if w in l: return "metal"
	for w in ["pillow", "doll", "bear", "slipper", "socks", "sock", "teddy"]:
		if w in l: return "cloth"
	for w in ["book", "magazine", "newspaper", "notice", "note", "letters", "papers", "drawing", "calendar", "photo", "album"]:
		if w in l: return "paper"
	return "wood"

func _collision() -> void:
	var walls := StaticBody3D.new(); walls.name = "Walls"; add_child(walls)
	for c in level.colliders:
		if float(c.x) > 14.2: continue
		var h: float = c.y1 - c.y0
		var box := AABB(Vector3(c.x - c.hx, c.y0, c.z - c.hz), Vector3(c.hx * 2.0, h, c.hz * 2.0))
		var pieces: Array = [box]
		if absf(float(c.rot)) < 0.01:
			for hk in HOLES:
				var hb := AABB(HOLES[hk][0], HOLES[hk][1] - HOLES[hk][0])
				var next: Array = []
				for pc in pieces: next.append_array(_carve(pc, hb))
				pieces = next
		for pc in pieces:
			var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
			b.size = pc.size; sh.shape = b
			sh.transform = Transform3D(Basis(Vector3.UP, c.rot), pc.get_center())
			walls.add_child(sh)
	for f in level.floors:
		if float(f.x0) > 14.0: continue
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = Vector3(f.x1 - f.x0, 0.4, f.z1 - f.z0); sh.shape = b
		sh.position = Vector3((f.x0 + f.x1) * 0.5, f.y - 0.2, (f.z0 + f.z1) * 0.5)
		walls.add_child(sh)
	var ceil := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(10.9, 0.4, 9.0)
	ceil.shape = cb; ceil.position = Vector3(4.95, H + 0.2, 4.0)
	walls.add_child(ceil)
	# the balcony rail
	var rail := CollisionShape3D.new(); var rb := BoxShape3D.new(); rb.size = Vector3(3.6, 1.2, 0.08)
	rail.shape = rb; rail.position = Vector3(2.25, 0.5, -1.78); walls.add_child(rail)

## A box with a hole box taken out of it, as up to six boxes.
static func _carve(b: AABB, h: AABB) -> Array:
	if not b.intersects(h): return [b]
	var out: Array = []
	var i := b.intersection(h)
	if i.position.x > b.position.x: out.append(AABB(b.position, Vector3(i.position.x - b.position.x, b.size.y, b.size.z)))
	if i.end.x < b.end.x: out.append(AABB(Vector3(i.end.x, b.position.y, b.position.z), Vector3(b.end.x - i.end.x, b.size.y, b.size.z)))
	var mid := AABB(Vector3(i.position.x, b.position.y, b.position.z), Vector3(i.size.x, b.size.y, b.size.z))
	if i.position.y > mid.position.y: out.append(AABB(mid.position, Vector3(mid.size.x, i.position.y - mid.position.y, mid.size.z)))
	if i.end.y < mid.end.y: out.append(AABB(Vector3(mid.position.x, i.end.y, mid.position.z), Vector3(mid.size.x, mid.end.y - i.end.y, mid.size.z)))
	var mid2 := AABB(Vector3(i.position.x, i.position.y, b.position.z), Vector3(i.size.x, i.size.y, b.size.z))
	if i.position.z > mid2.position.z: out.append(AABB(mid2.position, Vector3(mid2.size.x, mid2.size.y, i.position.z - mid2.position.z)))
	if i.end.z < mid2.end.z: out.append(AABB(Vector3(mid2.position.x, mid2.position.y, i.end.z), Vector3(mid2.size.x, mid2.size.y, mid2.end.z - i.end.z)))
	return out

# ------------------------------------------------------------------------------- light
const LAMP_SCALE := 0.15

func _lamps() -> void:
	var i := 0
	for L in level.lights:
		i += 1
		var pos := Vector3(L.pos[0], L.pos[1], L.pos[2])
		var name := String(L.name)
		if name.begins_with("stair") or not KEEP.has_point(pos) or name == "street": continue
		var col := Color(String(L.color))
		var circ = L.get("circuit")
		var circuit := String(circ) if circ is String else ""
		var z := zone_of(pos)
		var l: Lamp
		if String(L.type) == "RectAreaLight":
			# a window: the white outside, coming in flat and cold
			var inside := pos + Vector3(L.dir[0], 0, L.dir[2]) * 0.9
			l = Lamp.make(self, inside, Color(0.82, 0.86, 0.92), float(L.intensity) * 0.09, 5.0, PackedInt32Array([zone_of(inside)]))
		else:
			var fl = L.get("flicker")
			var flick := String(fl) if fl is String else ""
			if flick == "bulb": flick = ""
			l = Lamp.make(self, pos, col, float(L.intensity) * LAMP_SCALE, float(L.range) * 0.8, PackedInt32Array([z]), circuit, flick)
			l.on = bool(L.on)
		lamps[name + str(i)] = l
		l.name = "Lamp_" + name
		if name == "tv":
			_tv_lamp = l; l.on = false
	# a lamp still on by the table (her lamp): she's seen by it
	lamps["table"] = Lamp.make(self, Vector3(2.55, 1.05, 2.0), Color(1.0, 0.72, 0.45), 0.55, 3.2, PackedInt32Array([1]), "A", "candle")
	# the den's camping lantern, still going, low (the box room: lived in)
	lamps["den"] = Lamp.make(self, Vector3(2.25, 0.5, 7.15), Color(1.0, 0.7, 0.42), 0.5, 3.6, PackedInt32Array([5, 20]), "", "candle")
	# the landing's bulb
	lamps["landing"] = Lamp.make(self, Vector3(11.6, 2.4, 5.0), Color(1.0, 0.9, 0.75), 0.7, 6.0, PackedInt32Array([LANDING, 4]))
	Power.add("A", "Living room · hall", true)
	Power.add("B", "Kitchen", true)
	Power.add("C", "Bedroom · Sonya's room", false)

# ------------------------------------------------------------------------------- outside
func _outside() -> void:
	# There's no outside. Just white, and a note.
	var void_mat := Mats.flat(Color(0.93, 0.94, 0.95), -1, 1.0)
	var k := Kit.new()
	k.box(void_mat, Vector3(5, -2, -26), Vector3(60, 80, 0.2), Basis(), 16)
	k.box(void_mat, Vector3(5, -40, -16), Vector3(60, 0.2, 20), Basis(), 4)
	k.commit(self, "White")
	_sticky_note(Vector3(3.0, 3.0, -13.7), 0.0, 7.5, -0.035, "“outside”")
	# the balcony's ledge out over nothing
	var ledge := StaticBody3D.new(); add_child(ledge)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(3.6, 0.2, 0.4); cs.shape = b
	cs.position = Vector3(2.25, -0.22, -1.6); ledge.add_child(cs)
	# fall out into the white and it hands you back
	var catch := Area3D.new(); catch.collision_mask = 16; add_child(catch)
	var cc := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(14, 2, 24); cc.shape = cb
	cc.position = Vector3(2, -5, -14); catch.add_child(cc)          # under the balcony only (not the stairwell)
	catch.body_entered.connect(func(body): if body is Kurt: World.emit_event("fell_into_white", {}))

func _sticky_note(at: Vector3, yaw: float, size: float, tilt: float, word: String) -> void:
	var note := Node3D.new(); note.name = "Note"
	add_child(note)
	note.position = at; note.rotation = Vector3(0, yaw, tilt)
	var mi := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(size, size); mi.mesh = qm
	mi.material_override = Mats.flat(Color("f2df67"), -1, 1.0)
	note.add_child(mi)
	var lbl := Label3D.new(); lbl.text = word; lbl.font_size = 160; lbl.pixel_size = size / 900.0
	lbl.modulate = Color("1d2333"); lbl.shaded = false; lbl.outline_size = 0; lbl.position = Vector3(0, 0, 0.01)
	note.add_child(lbl)

# ------------------------------------------------------------------------------- systems
func _systems() -> void:
	# the front door: chained, and a padlock through the chain, from inside
	var fd: Door = doors.get("dEntry")
	if fd:
		fd.max_angle = 1.45; fd.inside = fd.side_of(Vector3(8.5, 0, 4.5)); fd.chained = true; fd.padlock = true; fd.set_angle(0.0)
		fd.set_meta("lock_at", fd.global_transform * Vector3(fd.w - 0.12, 1.35, 0.05))
	var ld: Door = doors.get("dLiving")
	if ld:
		ld.key_id = "living_key"
	for id in ["dBed", "dChild", "dBath"]:
		if doors.has(id): doors[id].key_id = ""
	# the fuse box, by the front door
	FuseBox.place(self, Vector3(9.05, 1.62, 3.9), Vector3(0, 0, 1), ["A", "B", "C"], "Fuse box", 4)
	# the TV (circuit A): noise and light; something to make noise with
	var tv := Usable.make(self, Transform3D(Basis(), Vector3(1.62, 0.75, 2.6)), Vector3(0.5, 0.45, 0.5), [])
	tv.title = "Television"
	tv.offer = func(_k): return [{"id": "tv", "label": "Turn off" if tv_on else "Turn on"}]
	tv.acted.connect(func(_v, _k): set_tv(not tv_on))
	_tv_snd = Audio.loop("static", tv, -80.0, 3.0)
	# the radio in the kitchen (circuit B)
	var radio := Usable.make(self, Transform3D(Basis(), Vector3(9.7, 1.0, 1.35)), Vector3(0.3, 0.2, 0.2), [])
	radio.title = "Radio"
	radio.offer = func(_k): return [{"id": "radio", "label": "Turn off" if radio_on else "Turn on"}]
	radio.acted.connect(func(_v, _k): set_radio(not radio_on))
	_radio_snd = Audio.loop("radio", radio, -80.0, 3.0)
	Power.changed.connect(func(_c): _appliances())
	# the bath: full of black water. The key and her other shoe are down in it.
	bath = WaterBody.new(); bath.name = "Bath"; add_child(bath)
	bath.setup("bath", Rect2(6.62, 7.3, 1.5, 0.62), 0.12, 0.52, 0.36, 7)
	bath.gurgle = true
	var plug := Usable.make(self, Transform3D(Basis(), Vector3(6.75, 0.62, 7.6)), Vector3(0.24, 0.16, 0.34), [])
	plug.title = "Bath"
	plug.offer = func(k): return _bath_verbs(k)
	plug.acted.connect(_bath)
	plug.socko_offer = func(_k): return [{"id": "socko_bath", "label": "Feel around in there"}] if not World.flag("bath_searched") else []
	plug.socko_do = func(_id, k, m):
		await m.bark("cmd_bath", true)
		m.socko.set_pose("low", 0.6)
		m.socko.rig.set_stains(1.0, 1.0, 1.6, 1.0)
		Audio.play("splash", Vector3(7.3, 0.4, 7.6), -6.0)
		await get_tree().create_timer(2.0, false).timeout
		m.socko.set_pose("up", 0.6)
		World.set_flag("bath_searched")
		k.give_item("padlock_key", "Small key", "A small brass key on a loop of string. Padlock size.")
		k.give_item("shoe_right", "Red shoe (right)", "A girl's red buckle shoe, right foot. Silt in it.")
		m.defy(-0.3, "used")
		m.bark("cmd_bath_ok", true)
	var tap := Usable.make(self, Transform3D(Basis(), Vector3(6.55, 0.75, 7.62)), Vector3(0.14, 0.2, 0.2), [])
	tap.title = "Bath tap"
	tap.offer = func(_k): return [{"id": "tap", "label": "Turn the tap off" if bath.inflow > 0.0 else "Turn the tap on"}]
	tap.acted.connect(func(_v, _k):
		bath.inflow = 0.0 if bath.inflow > 0.0 else (0.004 if World.flag("mains_on", false) else 0.0)
		Audio.play("latch", tap.global_position, -6.0)
		if bath.inflow == 0.0 and not World.flag("mains_on", false): World.emit_event("tap_dry", {}))
	# the bath overflows onto the bathroom floor, and that floor runs under the door into the hall
	var floor_water := WaterBody.new(); floor_water.name = "BathFloor"; add_child(floor_water)
	floor_water.setup("bathfloor", Rect2(6.45, 5.25, 3.5, 2.7), 0.0, 0.06, 0.0, 7)
	floor_water.colour = Color(0.05, 0.05, 0.04, 0.6)
	floor_water.live_circuit = "A"     # the extension lead on the bathroom floor (the washing machine)
	bath.overflow_to = floor_water
	# the hall's switch for her lamp, etc: kept simple. Ends: the landing.
	var out := Area3D.new(); out.collision_mask = 16; add_child(out)
	var oc := CollisionShape3D.new(); var ob := BoxShape3D.new(); ob.size = Vector3(2.6, 2.5, 4.0); oc.shape = ob
	oc.position = Vector3(12.4, 1.2, 5.6); out.add_child(oc)
	out.body_entered.connect(func(b): if b is Kurt: World.emit_event("reached_landing", {"via": "front_door"}))

func set_tv(on: bool) -> void:
	tv_on = on
	_appliances()

func set_radio(on: bool) -> void:
	radio_on = on
	_appliances()

func _appliances() -> void:
	var tv := tv_on and Power.live("A")
	if _tv_lamp: _tv_lamp.on = tv
	_tv_snd.volume_db = -6.0 if tv else -80.0
	var r := radio_on and Power.live("B")
	_radio_snd.volume_db = -8.0 if r else -80.0

func _process(delta: float) -> void:
	# a set left on is a lure: it keeps making noise anything can come to
	_lure_t -= delta
	if _lure_t <= 0.0:
		_lure_t = 1.2
		if tv_on and Power.live("A"): Noises.make(Vector3(1.62, 0.9, 2.6), 14.0, "tv", self)
		if radio_on and Power.live("B"): Noises.make(Vector3(9.7, 1.0, 1.35), 12.0, "radio", self)

func _bath_verbs(k) -> Array:
	var v: Array = []
	v.append({"id": "plug", "label": "Put the plug in" if bath.outflow == 0.0 and World.flag("bath_drained_once") else ("Pull the plug" if bath.outflow == 0.0 else "Put the plug back")})
	if not World.flag("bath_searched"):
		v.append({"id": "reach", "label": "Reach into the water" if bath.level > 0.08 else "Feel through the silt"})
	return v

func _bath(verb: String, k) -> void:
	match verb:
		"plug":
			if bath.outflow == 0.0:
				bath.outflow = 0.011
				World.set_flag("bath_drained_once")
				Audio.play("gurgle", bath.global_position + Vector3(6.75, 0.3, 7.6), 0.0)
				Noises.make(Vector3(7.3, 0.3, 7.6), 9.0, "gurgle", self)
			else:
				bath.outflow = 0.0
		"reach":
			World.set_flag("bath_searched")
			var black := bath.level > 0.08
			World.emit_event("bath_reach", {"black": black})
			if black:
				# the water is the infection's: it gets into the hand
				World.count("infected_touch")
				Progress.gain_shards("bath_water", 1)
			k.give_item("padlock_key", "Small key", "A small brass key on a loop of string. Padlock size.")
			k.give_item("shoe_right", "Red shoe (right)", "A girl's red buckle shoe, right foot. Silt in it.")
			Audio.play("splash", Vector3(7.3, 0.4, 7.6), -4.0)

# ------------------------------------------------------------------------------- the wardrobe
func _wardrobe() -> void:
	wardrobe = Node3D.new(); wardrobe.name = "Wardrobe"
	add_child(wardrobe)
	wardrobe.global_position = WARDROBE_AT
	var model: Node3D = find_child("prop_34_Wardrobe", true, false)
	if model:
		var b := model.global_basis
		model.reparent(wardrobe, false)
		model.transform = Transform3D(b, Vector3.ZERO)
	wardrobe_body = AnimatableBody3D.new(); wardrobe_body.sync_to_physics = false
	wardrobe_body.collision_layer = 1
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(1.0, 1.9, 0.55)
	cs.shape = bx; cs.position = Vector3(0, 0.95, 0)
	wardrobe_body.add_child(cs)
	wardrobe_body.set_meta("actor", self)
	wardrobe.add_child(wardrobe_body)

## The wardrobe is the flat's own Usable (its body points here).
func get_verbs(k) -> Array:
	if wardrobe_toppled or wardrobe_shoves >= 3: return []
	var v: Array = [{"id": "push", "label": "Push"}]
	v.append({"id": "topple", "label": "Pull it over"})
	return v

func act(verb: String, k) -> void:
	match verb:
		"push": shove_wardrobe(k)
		"topple": topple_wardrobe(k)

## One shove (three clear the doorway; one, with a grip like that).
func shove_wardrobe(k = null) -> bool:
	wardrobe_shoves = 3 if Progress.has("coral_grip") else wardrobe_shoves + 1
	var to := WARDROBE_AT.lerp(WARDROBE_END, wardrobe_shoves / 3.0)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(wardrobe, "global_position", to, 0.6)
	Audio.play("scrape", wardrobe.global_position + Vector3(0, 0.5, 0), 2.0, randf_range(0.9, 1.05))
	Noises.make(wardrobe.global_position, 10.0, "scrape", k)
	World.emit_event("wardrobe_shoved", {"n": wardrobe_shoves})
	if wardrobe_shoves >= 3:
		World.set_flag("wardrobe_moved")
		return true
	return false

## Over on its face: quicker, and the whole building hears it. Then it's something to climb over.
func topple_wardrobe(k = null) -> void:
	wardrobe_toppled = true
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(wardrobe, "rotation:x", -PI * 0.5, 0.7)
	t.parallel().tween_property(wardrobe, "global_position", WARDROBE_AT + Vector3(0, 0.28, 0.25), 0.7)
	t.tween_callback(func():
		Audio.play("slam", wardrobe.global_position, 4.0)
		Audio.play("splinter", wardrobe.global_position, 0.0)
		Noises.make(wardrobe.global_position, 28.0, "crash", k)
		World.set_flag("wardrobe_moved")
		World.set_flag("wardrobe_toppled")
		World.emit_event("wardrobe_shoved", {"n": 3, "toppled": true}))

# ------------------------------------------------------------------------------- the holes
## Each hole: the flat's wall surfaces inside the box are cut away (cleanly, in the shader), and
## the broken edge is built: the wall's thickness (plaster, brick, lath) and chunks of rubble.
func _holes() -> void:
	for hk in HOLES:
		var a: Vector3 = HOLES[hk][0]; var b: Vector3 = HOLES[hk][1]
		for mi in find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var bb: AABB = m.global_transform * m.get_aabb()
			if not bb.intersects(AABB(a, b - a)) or bb.size.y < 1.0: continue
			for i in m.mesh.get_surface_count():
				var mat := m.get_active_material(i)
				if mat is ShaderMaterial:
					var own := (mat as ShaderMaterial).duplicate() as ShaderMaterial
					own.set_shader_parameter("hole_a", a); own.set_shader_parameter("hole_b", b)
					m.set_surface_override_material(i, own)
		_rim(a, b, hk)

func _rim(a: Vector3, b: Vector3, seed_name: String) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_name.hash()
	var kit := Kit.new()
	var brick := Mats.tex(Tex.get_tex("brick"), -1)
	var plaster := Mats.tex(Tex.get_tex("plaster"), -1)
	var z0 := 7.96; var z1 := 8.44
	var x0 := a.x; var x1 := b.x; var y1 := b.y; var y0 := 0.0
	# the reveal: brick in the thickness of the wall
	kit.quad(brick, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	kit.quad(brick, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0))
	kit.quad(brick, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1))
	kit.quad(plaster, Vector3(x0, 0.002, z1), Vector3(x1, 0.002, z1), Vector3(x1, 0.002, z0), Vector3(x0, 0.002, z0))
	# and something to walk on through the thickness of the wall
	var sb := StaticBody3D.new(); add_child(sb)
	var cs := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(x1 - x0 + 0.3, 0.4, z1 - z0 + 0.3); cs.shape = bb
	cs.position = Vector3((x0 + x1) * 0.5, -0.2, (z0 + z1) * 0.5); sb.add_child(cs)
	# broken plaster round the edge on the room side, sticking out
	var n := int((x1 - x0) * 10.0 + (y1 - y0) * 10.0)
	for i in n:
		var t := rng.randf()
		var p: Vector3
		if t < 0.5: p = Vector3(x0 if t < 0.25 else x1, rng.randf_range(y0, y1), z0 - 0.02)
		else: p = Vector3(rng.randf_range(x0, x1), y1, z0 - 0.02)
		var s := Vector3(rng.randf_range(0.04, 0.14), rng.randf_range(0.04, 0.12), rng.randf_range(0.02, 0.05))
		kit.box(plaster if rng.randf() < 0.6 else brick, p, s, Basis(Vector3.FORWARD, rng.randf_range(-0.6, 0.6)))
	for i in 10:
		var p := Vector3(rng.randf_range(x0 - 0.2, x1 + 0.2), 0.03, rng.randf_range(z0 - 0.5, z0 - 0.05))
		var s := rng.randf_range(0.04, 0.11)
		kit.box(brick if rng.randf() < 0.5 else plaster, p, Vector3(s, s * 0.6, s * 0.8), Basis(Vector3.UP, rng.randf() * TAU))
	kit.commit(self, "Rim_" + seed_name)

# ------------------------------------------------------------------------------- saving
func _save() -> Dictionary:
	var d := {"doors": {}, "props": {}, "ward": wardrobe_shoves, "topple": wardrobe_toppled, "tv": tv_on, "radio": radio_on}
	for id in doors: d.doors[id] = doors[id].save()
	for k in props:
		var p: Prop = props[k]
		if is_instance_valid(p) and p.awake: d.props[k] = p.save()
		elif not is_instance_valid(p): d.props[k] = {"gone": true}
	return d

func _load(d: Dictionary) -> void:
	for id in d.get("doors", {}):
		if doors.has(id): doors[id].load_state(d.doors[id])
	for k in d.get("props", {}):
		var p: Prop = props.get(k)
		if p == null or not is_instance_valid(p): continue
		if d.props[k].get("gone", false): p.queue_free()
		else: p.load_state(d.props[k])
	wardrobe_shoves = int(d.get("ward", 0))
	if wardrobe_shoves > 0: wardrobe.global_position = WARDROBE_AT.lerp(WARDROBE_END, wardrobe_shoves / 3.0)
	if bool(d.get("topple", false)):
		wardrobe_toppled = true; wardrobe.rotation.x = -PI * 0.5; wardrobe.global_position = WARDROBE_AT + Vector3(0, 0.28, 0.25)
	tv_on = bool(d.get("tv", false)); radio_on = bool(d.get("radio", false))
	_appliances()
