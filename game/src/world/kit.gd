class_name Kit
extends RefCounted
## The environmental asset library: every piece of furniture and fixture in Flat 47, its Backrooms
## and Flat 48 is built here, from boxes and cylinders in the PS1 manner. Static geometry goes into
## the room's merged mesh (one draw call per material per room); moving parts (doors, drawers),
## physical objects (Props) and interactables become their own nodes.
##
## place(level, def) where def = {t: type, room, p: [x, z] world, r: degrees, id, y, ...options}
## Options every piece understands:
##   style        override its main material style
##   scale        [sx, sy, sz] (the Backrooms stretch furniture too)
##   contents     {"drawer0": [item ids], "inside": [...]} what's in it
##   locked/key   for drawers and cupboards
##   pushable     heavy pieces become physical (barricades, the wardrobe in the living room)

class Ctx:
	var level: Node
	var room: String
	var mb: MB                  # the room's static mesh
	var body: StaticBody3D      # the room's static collision
	var xf: Transform3D         # the piece, in world space
	var def: Dictionary
	var parent: Node3D          # where nodes for this piece go (the level)
	var light: Callable         # level.light_at
	var alter: Dictionary

	func at(local: Vector3) -> Vector3:
		return xf * local

	## a static box: drawn into the room mesh and (optionally) collidable
	func box(style: String, c: Vector3, h: Vector3, collide := true, b := Basis.IDENTITY, uvm := -1.0) -> void:
		mb.xf = xf
		mb.box(style, c, h, b, uvm if uvm > 0.0 else Mats.uvm(style))
		mb.xf = Transform3D.IDENTITY
		if collide:
			var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = h * 2.0
			cs.shape = bs
			body.add_child(cs)
			cs.transform = body.global_transform.affine_inverse() * xf * Transform3D(b, c)

	func cyl(style: String, base: Vector3, r: float, h: float, sides := 8) -> void:
		mb.xf = xf
		mb.cyl(style, base, r, h, sides)
		mb.xf = Transform3D.IDENTITY

	## nav: this floor rectangle (local, centre + half extents) can't be walked through
	func block(c: Vector3, h: Vector3) -> void:
		level.block_rect(xf, c, h)

	func light_at(local: Vector3) -> Color:
		return light.call(xf * local, Vector3.UP)

	## a node placed at a local transform within the piece
	func node(n: Node3D, local := Transform3D.IDENTITY) -> Node3D:
		parent.add_child(n)
		n.global_transform = xf * local
		return n


static func place(level: Node, def: Dictionary) -> Node:
	var ctx := Ctx.new()
	ctx.level = level
	ctx.room = String(def.get("room", ""))
	ctx.mb = level.room_mb(ctx.room)
	ctx.body = level.room_body(ctx.room)
	var p: Array = def.get("p", [0, 0])
	var y := float(def.get("y", level.room_floor(ctx.room)))
	var b := Basis(Vector3.UP, deg_to_rad(float(def.get("r", 0.0))))
	if def.has("scale"):
		var s: Array = def.scale
		b = b * Basis.from_scale(Vector3(float(s[0]), float(s[1]), float(s[2])))
	ctx.xf = Transform3D(b, Vector3(float(p[0]), y, float(p[1])))
	ctx.def = def
	ctx.parent = level.dynamic_root()
	ctx.light = level.light_at
	ctx.alter = level.room_alter(ctx.room)
	var t := String(def.get("t", ""))
	var fn := "_" + t
	var k := Kit.new()
	if not k.has_method(fn):
		push_warning("Kit: unknown piece " + t)
		return null
	return k.call(fn, ctx)

# ---------------------------------------------------------------------------------------------
# helpers for interactive parts

static func _drawer(ctx: Ctx, c: Vector3, h: Vector3, style: String, id: String, contents: Array) -> Fixtures.Drawer:
	# carcass hole is implied by the piece; the drawer is a tray with a front
	var d := Fixtures.Drawer.new(); d.name = "Drawer_" + id
	ctx.node(d, Transform3D(Basis.IDENTITY, Vector3(c.x, c.y, c.z)))
	var body := AnimatableBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
	body.sync_to_physics = false
	d.add_child(body)
	var mb := MB.new()
	mb.box(style, Vector3(0, 0, -h.z + 0.01), Vector3(h.x, h.y, 0.012))               # front
	mb.box(style, Vector3(0, -h.y + 0.01, 0), Vector3(h.x - 0.01, 0.008, h.z - 0.02), Basis.IDENTITY, 0.5, 8) # floor (top face)
	mb.box(style, Vector3(-h.x + 0.01, 0, 0), Vector3(0.008, h.y * 0.8, h.z - 0.02), Basis.IDENTITY, 0.5, 2)
	mb.box(style, Vector3(h.x - 0.01, 0, 0), Vector3(0.008, h.y * 0.8, h.z - 0.02), Basis.IDENTITY, 0.5, 1)
	mb.box("chrome", Vector3(0, 0, -h.z - 0.012), Vector3(minf(0.06, h.x * 0.4), 0.01, 0.012))
	var lc := ctx.light_at(c)
	var mats := {style: Mats.flat(style, lc, ctx.alter), "chrome": Mats.flat("chrome", lc, ctx.alter)}
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit(mats); body.add_child(mi)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(h.x * 2.0, h.y * 2.0, 0.03)
	cs.shape = bs; cs.position = Vector3(0, 0, -h.z + 0.01); body.add_child(cs)
	d.setup(body, h.z * 2.0, id)
	if ctx.def.get("locked", {}).has(id):
		d.locked = true
		d.key_tag = String(ctx.def.locked[id])
	# contents ride in the drawer, frozen until picked up
	var i := 0
	for item in contents:
		var p := PropKit.item(String(item), ctx.light)
		p.freeze = true
		p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.add_child(p)
		p.position = Vector3(-h.x * 0.5 + (i % 3) * h.x * 0.5, -h.y + 0.05, (i / 3) * 0.1 - 0.05)
		p.relight()
		i += 1
	return d

static func _cab_door(ctx: Ctx, hinge_local: Vector3, w: float, hgt: float, style: String, id: String, flip := false, swing := 1.0) -> Door:
	var d := Door.new(); d.name = "Cab_" + id
	d.width = w; d.height = hgt; d.thickness = 0.02; d.style = style; d.cabinet = true; d.max_angle = 110.0
	d.swing = swing; d.door_id = id
	var basis := Basis(Vector3.UP, PI) if flip else Basis.IDENTITY
	# origin of a Door is the bottom centre of its opening
	ctx.node(d, Transform3D(basis, hinge_local))
	d.build(ctx.light_at(hinge_local), ctx.alter)
	if ctx.def.get("locked", {}).has(id):
		d.locked = true; d.key_tag = String(ctx.def.locked[id]); d.pickable = true
	return d

static func _contents_on(ctx: Ctx, items: Array, c: Vector3, spread: Vector3) -> void:
	var i := 0
	for item in items:
		var p := PropKit.item(String(item), ctx.light) if PropKit.DEFS.has(String(item)) else null
		if not p:
			continue
		ctx.parent.add_child(p)
		var n := maxi(1, items.size())
		p.global_position = ctx.at(c + Vector3(spread.x * (float(i) / n - 0.5) * 2.0, 0.05, spread.z * (0.5 - randf())))
		p.relight()
		i += 1

static func _style(ctx: Ctx, d: String) -> String:
	return String(ctx.def.get("style", d))

# ---------------------------------------------------------------------------------------------
# furniture

func _table(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.4)); var dpt := float(ctx.def.get("d", 0.85)); var h := 0.75
	var s := _style(ctx, "wood_dark")
	ctx.box(s, Vector3(0, h - 0.02, 0), Vector3(w * 0.5, 0.025, dpt * 0.5))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			ctx.box(s, Vector3(sx * (w * 0.5 - 0.06), h * 0.5, sz * (dpt * 0.5 - 0.06)), Vector3(0.03, h * 0.5, 0.03))
	if ctx.def.get("cloth", false):
		ctx.box("fabric_bed", Vector3(0, h + 0.005, 0), Vector3(w * 0.5 + 0.04, 0.004, dpt * 0.5 + 0.04), false)
		ctx.box("fabric_bed", Vector3(0, h - 0.12, -dpt * 0.5 - 0.04), Vector3(w * 0.5 + 0.04, 0.12, 0.004), false)
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, dpt * 0.5))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, h + 0.03, 0), Vector3(w * 0.35, 0, dpt * 0.25))
	return null

func _sofa(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.9)); var s := _style(ctx, "fabric_green")
	ctx.box(s, Vector3(0, 0.22, 0), Vector3(w * 0.5, 0.2, 0.42))
	ctx.box(s, Vector3(0, 0.45, 0.33), Vector3(w * 0.5, 0.3, 0.1))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.08), 0.35, 0), Vector3(0.08, 0.17, 0.42))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, 0.45))
	return null

func _armchair(ctx: Ctx) -> Node:
	# physical: heavy, can be shoved in front of a door
	var p := Prop.new(); p.name = "Armchair"; p.display_name = "Armchair"; p.mass = 24.0; p.sound = "soft"; p.noise_k = 0.8
	p.tags = ["barricade"]
	p.persist_id = String(ctx.def.get("id", ""))
	var mb := MB.new(); var s := _style(ctx, "fabric_green")
	mb.box(s, Vector3(0, 0.22, 0), Vector3(0.42, 0.2, 0.4))
	mb.box(s, Vector3(0, 0.5, 0.32), Vector3(0.42, 0.3, 0.09))
	for sx in [-1.0, 1.0]:
		mb.box(s, Vector3(sx * 0.36, 0.38, 0), Vector3(0.07, 0.16, 0.4))
	var mats := {s: Mats.flat(s, ctx.light_at(Vector3(0, 0.5, 0)), ctx.alter)}
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit(mats); p.add_child(mi)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.84, 0.8, 0.82); cs.shape = bs; cs.position = Vector3(0, 0.4, 0)
	p.add_child(cs)
	p.set_materials(mats.values()); p.light_fn = ctx.light
	ctx.node(p)
	return p

## The wardrobe. Static with doors and room to hide; or (pushable) one heavy physical body that
## can be shoved along the wall — what the living room's does, uncovering what's behind it.
func _wardrobe(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.1)); var h := float(ctx.def.get("h", 1.95)); var d := 0.58
	var s := _style(ctx, "wood_dark")
	if ctx.def.get("pushable", false):
		var p := Prop.new(); p.name = "Wardrobe"; p.display_name = "Wardrobe"; p.mass = 70.0; p.sound = "wood"
		p.persist_id = String(ctx.def.get("id", "wardrobe"))
		p.tags = ["barricade"]
		var mb := MB.new()
		mb.box(s, Vector3(0, h * 0.5, 0), Vector3(w * 0.5, h * 0.5, d * 0.5))
		mb.box("chrome", Vector3(-0.04, h * 0.52, -d * 0.5 - 0.01), Vector3(0.01, 0.06, 0.01))
		mb.box("chrome", Vector3(0.04, h * 0.52, -d * 0.5 - 0.01), Vector3(0.01, 0.06, 0.01))
		var lc := ctx.light_at(Vector3(0, 1, 0))
		var mats := {s: Mats.flat(s, lc, ctx.alter), "chrome": Mats.flat("chrome", lc, ctx.alter)}
		var mi := MeshInstance3D.new(); mi.mesh = mb.commit(mats); p.add_child(mi)
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(w, h, d); cs.shape = bs; cs.position = Vector3(0, h * 0.5, 0)
		p.add_child(cs)
		p.set_materials(mats.values()); p.light_fn = ctx.light
		p.axis_lock_angular_x = true; p.axis_lock_angular_z = true     # it slides, it doesn't topple
		ctx.node(p)
		return p
	# static carcass, open front (faces -Z local), two doors, a hiding place inside
	ctx.box(s, Vector3(0, h * 0.5, d * 0.5 - 0.01), Vector3(w * 0.5, h * 0.5, 0.012))        # back
	ctx.box(s, Vector3(-w * 0.5 + 0.012, h * 0.5, 0), Vector3(0.012, h * 0.5, d * 0.5))
	ctx.box(s, Vector3(w * 0.5 - 0.012, h * 0.5, 0), Vector3(0.012, h * 0.5, d * 0.5))
	ctx.box(s, Vector3(0, h - 0.012, 0), Vector3(w * 0.5, 0.012, d * 0.5))
	ctx.box(s, Vector3(0, 0.05, 0), Vector3(w * 0.5, 0.05, d * 0.5))
	ctx.box("chrome", Vector3(0, h - 0.12, 0), Vector3(w * 0.48, 0.008, 0.008), false)     # rail
	var dl := _cab_door(ctx, Vector3(-w * 0.25, 0.1, -d * 0.5), w * 0.5 - 0.01, h - 0.12, s, String(ctx.def.get("id", "wr")) + "_l", true, 1.0)
	var dr := _cab_door(ctx, Vector3(w * 0.25, 0.1, -d * 0.5), w * 0.5 - 0.01, h - 0.12, s, String(ctx.def.get("id", "wr")) + "_r", false, -1.0)
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, d * 0.5))
	if ctx.def.get("hide", true):
		var hs := Fixtures.HideSpot.new(); hs.kind = "wardrobe"; hs.spot_id = String(ctx.def.get("id", "wardrobe"))
		hs.door = dl
		dl.hide_spot = hs
		dr.hide_spot = hs
		ctx.node(hs, Transform3D(Basis.IDENTITY, Vector3(0, 1.55, 0.05)))
		hs.exit_pos = hs.global_transform.affine_inverse() * ctx.at(Vector3(0, 0, -0.95))
		var hb := StaticBody3D.new(); hb.collision_layer = 32       # interact-only layer
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(w * 0.8, 1.6, 0.3); cs.shape = bs
		hb.add_child(cs); hs.add_child(hb); hb.position = Vector3(0, -0.6, 0.0)
		Hook.attach(hb, hs, "Wardrobe")
		ctx.level.register_hide(hs)
	_contents_on(ctx, ctx.def.get("contents", {}).get("inside", []), Vector3(0, 0.12, 0), Vector3(w * 0.3, 0, 0.1))
	return null

func _sideboard(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.6)); var h := 0.85; var d := 0.45
	var s := _style(ctx, "wood_dark")
	var cont: Dictionary = ctx.def.get("contents", {})
	ctx.box(s, Vector3(0, h - 0.015, 0), Vector3(w * 0.5, 0.015, d * 0.5))
	ctx.box(s, Vector3(0, 0.04, 0), Vector3(w * 0.5, 0.04, d * 0.5))
	ctx.box(s, Vector3(0, h * 0.5, d * 0.5 - 0.01), Vector3(w * 0.5, h * 0.5, 0.01))
	for sx in [-1.0, 0.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.012), h * 0.5, 0), Vector3(0.012, h * 0.5, d * 0.5))
	ctx.box(s, Vector3(0, h * 0.62, 0), Vector3(w * 0.5, 0.01, d * 0.5), false)
	var id := String(ctx.def.get("id", "sb"))
	_drawer(ctx, Vector3(-w * 0.25, h * 0.74, -0.01), Vector3(w * 0.25 - 0.02, 0.08, d * 0.5 - 0.02), s, id + "_d0", cont.get("drawer0", []))
	_drawer(ctx, Vector3(w * 0.25, h * 0.74, -0.01), Vector3(w * 0.25 - 0.02, 0.08, d * 0.5 - 0.02), s, id + "_d1", cont.get("drawer1", []))
	_cab_door(ctx, Vector3(-w * 0.25, 0.08, -d * 0.5), w * 0.5 - 0.03, h * 0.53, s, id + "_c0", true, 1.0)
	_cab_door(ctx, Vector3(w * 0.25, 0.08, -d * 0.5), w * 0.5 - 0.03, h * 0.53, s, id + "_c1", false, -1.0)
	_contents_on(ctx, cont.get("inside", []), Vector3(0, 0.09, 0.0), Vector3(w * 0.3, 0, 0.05))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, h + 0.02, 0), Vector3(w * 0.35, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, d * 0.5))
	return null

func _dresser(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 0.9)); var h := 0.9; var d := 0.45; var s := _style(ctx, "wood_dark")
	var cont: Dictionary = ctx.def.get("contents", {})
	ctx.box(s, Vector3(0, h - 0.015, 0), Vector3(w * 0.5, 0.015, d * 0.5))
	ctx.box(s, Vector3(0, h * 0.5, d * 0.5 - 0.01), Vector3(w * 0.5, h * 0.5, 0.01))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.012), h * 0.5, 0), Vector3(0.012, h * 0.5, d * 0.5))
	ctx.box(s, Vector3(0, 0.04, 0), Vector3(w * 0.5, 0.04, d * 0.5))
	var id := String(ctx.def.get("id", "dr"))
	for i in 3:
		_drawer(ctx, Vector3(0, 0.2 + i * 0.25, -0.01), Vector3(w * 0.5 - 0.03, 0.1, d * 0.5 - 0.02), s, id + "_d%d" % i, cont.get("drawer%d" % i, []))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, h + 0.02, 0), Vector3(w * 0.3, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, d * 0.5))
	return null

func _nightstand(ctx: Ctx) -> Node:
	var s := _style(ctx, "wood_dark")
	ctx.box(s, Vector3(0, 0.29, 0.0), Vector3(0.22, 0.015, 0.2))
	ctx.box(s, Vector3(0, 0.15, 0.19), Vector3(0.22, 0.15, 0.01))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * 0.21, 0.15, 0), Vector3(0.01, 0.15, 0.2))
	ctx.box(s, Vector3(0, 0.02, 0), Vector3(0.22, 0.02, 0.2))
	_drawer(ctx, Vector3(0, 0.2, -0.01), Vector3(0.19, 0.06, 0.18), s, String(ctx.def.get("id", "ns")) + "_d0", ctx.def.get("contents", {}).get("drawer0", []))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, 0.32, 0), Vector3(0.1, 0, 0.05))
	return null

func _bed(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.4)); var l := float(ctx.def.get("l", 2.0)); var s := _style(ctx, "wood_dark")
	var low := 0.34
	ctx.box(s, Vector3(0, 0.25, 0), Vector3(w * 0.5, 0.05, l * 0.5))                       # frame (high enough to crawl under)
	ctx.box("fabric_bed", Vector3(0, low, 0), Vector3(w * 0.5 - 0.03, 0.08, l * 0.5 - 0.03))
	ctx.box("fabric_bed", Vector3(0, low + 0.1, l * 0.5 - 0.25), Vector3(w * 0.4, 0.05, 0.15), false)   # pillow
	ctx.box(s, Vector3(0, 0.5, l * 0.5 - 0.02), Vector3(w * 0.5, 0.5, 0.025))                # headboard (+Z)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			ctx.box(s, Vector3(sx * (w * 0.5 - 0.04), 0.1, sz * (l * 0.5 - 0.04)), Vector3(0.03, 0.1, 0.03))
	if ctx.def.get("unmade", false):
		ctx.box("fabric_bed", Vector3(-0.1, low + 0.1, -0.2), Vector3(w * 0.45, 0.04, l * 0.3), false, Basis(Vector3.UP, 0.15))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, l * 0.5))
	if ctx.def.get("hide", true):
		var hs := Fixtures.HideSpot.new(); hs.kind = "bed"; hs.crouched = true; hs.spot_id = String(ctx.def.get("id", "bed"))
		ctx.node(hs, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0.14, 0)))
		hs.exit_pos = hs.global_transform.affine_inverse() * ctx.at(Vector3(w * 0.5 + 0.45, 0, 0))
		var hb := StaticBody3D.new(); hb.collision_layer = 32
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.4, 0.25, l * 0.8); cs.shape = bs
		hb.add_child(cs); hs.add_child(hb)
		hb.global_position = ctx.at(Vector3(w * 0.5, 0.12, 0))
		Hook.attach(hb, hs, "Bed")
		ctx.level.register_hide(hs)
	return null

func _counter(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.2))
	ctx.box("wood_light", Vector3(0, 0.44, 0.0), Vector3(w * 0.5, 0.44, 0.3))
	ctx.box("enamel", Vector3(0, 0.9, 0), Vector3(w * 0.5 + 0.01, 0.02, 0.31))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, 0.94, 0), Vector3(w * 0.4, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, 0.3))
	return null

func _kitchen_unit(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 0.8)); var s := _style(ctx, "wood_light"); var d := 0.6
	var cont: Dictionary = ctx.def.get("contents", {})
	var id := String(ctx.def.get("id", "ku"))
	ctx.box(s, Vector3(0, 0.45, d * 0.5 - 0.01), Vector3(w * 0.5, 0.45, 0.01))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.01), 0.45, 0), Vector3(0.01, 0.45, d * 0.5))
	ctx.box(s, Vector3(0, 0.04, 0), Vector3(w * 0.5, 0.04, d * 0.5))
	ctx.box("enamel", Vector3(0, 0.9, 0), Vector3(w * 0.5, 0.02, d * 0.5 + 0.01))
	if ctx.def.get("sink", false):
		ctx.box("chrome", Vector3(0, 0.915, -0.02), Vector3(w * 0.32, 0.01, d * 0.3), false)
		ctx.cyl("chrome", Vector3(0, 0.92, d * 0.3), 0.015, 0.25)
	_drawer(ctx, Vector3(0, 0.78, -0.01), Vector3(w * 0.5 - 0.02, 0.07, d * 0.5 - 0.02), s, id + "_d0", cont.get("drawer0", []))
	_cab_door(ctx, Vector3(0, 0.08, -d * 0.5), w - 0.03, 0.6, s, id + "_c0", false, -1.0)
	_contents_on(ctx, cont.get("inside", []), Vector3(0, 0.1, 0), Vector3(w * 0.3, 0, 0.1))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, 0.94, 0), Vector3(w * 0.35, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, d * 0.5))
	return null

func _stove(ctx: Ctx) -> Node:
	ctx.box("enamel", Vector3(0, 0.45, 0), Vector3(0.3, 0.45, 0.3))
	for i in 4:
		ctx.cyl("rubber", Vector3(-0.12 + (i % 2) * 0.24, 0.9, -0.12 + (i / 2) * 0.24), 0.08, 0.012)
	ctx.box("glass", Vector3(0, 0.42, -0.305), Vector3(0.22, 0.15, 0.005), false)
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, 0.95, 0), Vector3(0.1, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(0.3, 0, 0.3))
	return null

func _fridge(ctx: Ctx) -> Node:
	var h := 1.5
	ctx.box("enamel", Vector3(0, h * 0.5, 0.29), Vector3(0.3, h * 0.5, 0.01))
	for sx in [-1.0, 1.0]:
		ctx.box("enamel", Vector3(sx * 0.29, h * 0.5, 0), Vector3(0.01, h * 0.5, 0.3))
	ctx.box("enamel", Vector3(0, h - 0.01, 0), Vector3(0.3, 0.01, 0.3))
	ctx.box("enamel", Vector3(0, 0.04, 0), Vector3(0.3, 0.04, 0.3))
	ctx.box("metal", Vector3(0, 0.75, 0), Vector3(0.28, 0.01, 0.28), false)
	var d := _cab_door(ctx, Vector3(0, 0.08, -0.3), 0.58, h - 0.1, "enamel", String(ctx.def.get("id", "fridge")) + "_door", true, 1.0)
	d.display_name = "Fridge"
	_contents_on(ctx, ctx.def.get("contents", {}).get("inside", []), Vector3(0, 0.8, 0), Vector3(0.15, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(0.3, 0, 0.3))
	if ctx.def.has("note"):
		_note_at(ctx, Vector3(0.315, 1.2, 0.0), String(ctx.def.note), "paper", Basis(Vector3.UP, -PI * 0.5))
	return null

func _wall_cupboard(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 0.8)); var s := _style(ctx, "wood_light"); var y := 1.5
	ctx.box(s, Vector3(0, y + 0.3, 0.15), Vector3(w * 0.5, 0.3, 0.01), false)
	ctx.box(s, Vector3(0, y, 0), Vector3(w * 0.5, 0.01, 0.16))
	ctx.box(s, Vector3(0, y + 0.6, 0), Vector3(w * 0.5, 0.01, 0.16))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.01), y + 0.3, 0), Vector3(0.01, 0.3, 0.16), false)
	_cab_door(ctx, Vector3(0, y + 0.01, -0.16), w - 0.03, 0.58, s, String(ctx.def.get("id", "wc")) + "_c0", true, 1.0)
	_contents_on(ctx, ctx.def.get("contents", {}).get("inside", []), Vector3(0, y + 0.03, 0), Vector3(w * 0.3, 0, 0.05))
	return null

func _sink(ctx: Ctx) -> Node:
	ctx.cyl("enamel", Vector3(0, 0, 0), 0.08, 0.7)
	ctx.box("enamel", Vector3(0, 0.78, 0), Vector3(0.28, 0.08, 0.22))
	ctx.cyl("chrome", Vector3(0, 0.86, 0.15), 0.012, 0.15)
	return null

func _toilet(ctx: Ctx) -> Node:
	ctx.box("enamel", Vector3(0, 0.2, 0), Vector3(0.18, 0.2, 0.28))
	ctx.box("enamel", Vector3(0, 0.6, 0.27), Vector3(0.2, 0.2, 0.08))
	ctx.block(Vector3.ZERO, Vector3(0.2, 0, 0.3))
	return null

func _bath(ctx: Ctx) -> Node:
	var l := 1.7; var w := 0.75
	ctx.box("enamel", Vector3(0, 0.05, 0), Vector3(w * 0.5, 0.05, l * 0.5))
	for sx in [-1.0, 1.0]:
		ctx.box("enamel", Vector3(sx * (w * 0.5 - 0.04), 0.3, 0), Vector3(0.04, 0.3, l * 0.5))
	for sz in [-1.0, 1.0]:
		ctx.box("enamel", Vector3(0, 0.3, sz * (l * 0.5 - 0.04)), Vector3(w * 0.5, 0.3, 0.04))
	if ctx.def.get("water", false):
		ctx.box("water", Vector3(0, 0.45, 0), Vector3(w * 0.5 - 0.08, 0.005, l * 0.5 - 0.08), false)
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, l * 0.5))
	if ctx.def.get("hide", true):
		var hs := Fixtures.HideSpot.new(); hs.kind = "bath"; hs.crouched = true; hs.spot_id = String(ctx.def.get("id", "bath"))
		ctx.node(hs, Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, 0.35, -0.3)))
		hs.exit_pos = hs.global_transform.affine_inverse() * ctx.at(Vector3(w * 0.5 + 0.45, 0, 0))
		var hb := StaticBody3D.new(); hb.collision_layer = 32
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(w, 0.3, l * 0.8); cs.shape = bs
		hb.add_child(cs); hs.add_child(hb)
		hb.global_position = ctx.at(Vector3(0, 0.55, 0))
		Hook.attach(hb, hs, "Bath")
		ctx.level.register_hide(hs)
	return null

func _washer(ctx: Ctx) -> Node:
	ctx.box("enamel", Vector3(0, 0.42, 0), Vector3(0.3, 0.42, 0.3))
	ctx.cyl("glass", Vector3(0, 0.5, -0.31), 0.15, 0.01, 10)
	ctx.block(Vector3.ZERO, Vector3(0.3, 0, 0.3))
	return null

func _mirror_cabinet(ctx: Ctx) -> Node:
	var y := 1.35
	ctx.box("wood_light", Vector3(0, y + 0.25, 0.06), Vector3(0.25, 0.25, 0.01), false)
	ctx.box("wood_light", Vector3(0, y, 0), Vector3(0.25, 0.01, 0.07))
	ctx.box("wood_light", Vector3(0, y + 0.5, 0), Vector3(0.25, 0.01, 0.07))
	ctx.box("wood_light", Vector3(0, y + 0.25, -0.0), Vector3(0.24, 0.005, 0.06), false)
	var d := _cab_door(ctx, Vector3(0, y + 0.01, -0.07), 0.48, 0.48, "glass", String(ctx.def.get("id", "mc")) + "_door", true, 1.0)
	d.display_name = "Mirror cabinet"
	_contents_on(ctx, ctx.def.get("contents", {}).get("inside", []), Vector3(0, y + 0.03, 0), Vector3(0.15, 0, 0.02))
	return null

func _shelf(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 0.9)); var h := float(ctx.def.get("h", 1.9)); var s := _style(ctx, "wood_light"); var d := 0.32
	var n := int(ctx.def.get("n", 4))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.012), h * 0.5, 0), Vector3(0.012, h * 0.5, d * 0.5))
	ctx.box(s, Vector3(0, h * 0.5, d * 0.5 - 0.005), Vector3(w * 0.5, h * 0.5, 0.005), false)
	var rows: Array = ctx.def.get("rows", [])
	for i in n + 1:
		var y := 0.04 + i * (h - 0.06) / n
		ctx.box(s, Vector3(0, y, 0), Vector3(w * 0.5, 0.012, d * 0.5))
		if i < rows.size():
			var r = rows[i]
			if r is String and r == "books":
				for b in int(w / 0.05):
					if randf() < 0.85:
						var bh := randf_range(0.18, 0.26)
						ctx.box(["wood_dark", "fabric_green", "door_padded", "cardboard"][b % 4], Vector3(-w * 0.5 + 0.04 + b * 0.05, y + bh * 0.5, 0), Vector3(0.02, bh * 0.5, 0.1), false)
			elif r is Array:
				_contents_on(ctx, r, Vector3(0, y + 0.03, 0), Vector3(w * 0.35, 0, 0.04))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, d * 0.5))
	return null

func _rug(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 2.0)); var l := float(ctx.def.get("l", 1.4))
	ctx.mb.xf = ctx.xf
	ctx.mb.plane("carpet", Vector3(-w * 0.5, 0.006, l * 0.5), Vector3(w, 0, 0), Vector3(0, 0, -l), Vector3.UP, w, 0.7)
	ctx.mb.xf = Transform3D.IDENTITY
	return null

func _radiator(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 0.8))
	for i in int(w / 0.08):
		ctx.box("metal", Vector3(-w * 0.5 + 0.04 + i * 0.08, 0.45, 0), Vector3(0.025, 0.3, 0.05), false)
	ctx.box("metal", Vector3(0, 0.45, 0), Vector3(w * 0.5, 0.3, 0.05))
	return null

func _coat_rack(ctx: Ctx) -> Node:
	ctx.box("wood_dark", Vector3(0, 1.7, 0.02), Vector3(0.45, 0.04, 0.015), false)
	for i in 4:
		ctx.box("brass", Vector3(-0.3 + i * 0.2, 1.68, -0.03), Vector3(0.01, 0.01, 0.04), false)
	if ctx.def.get("coat", true):
		ctx.box("door_padded", Vector3(-0.1, 1.25, -0.06), Vector3(0.22, 0.45, 0.06), false)
	return null

func _fuse_box(ctx: Ctx) -> Node:
	var fb := FuseBox.new(); fb.name = "FuseBox"
	ctx.node(fb)
	fb.build(ctx)
	ctx.level.power.fuse_box = fb
	return fb

func _phone_table(ctx: Ctx) -> Node:
	ctx.box("wood_dark", Vector3(0, 0.7, 0), Vector3(0.25, 0.015, 0.18))
	ctx.box("wood_dark", Vector3(0, 0.35, 0), Vector3(0.02, 0.35, 0.02))
	ctx.box("rubber", Vector3(0, 0.77, 0), Vector3(0.1, 0.055, 0.09))
	ctx.box("rubber", Vector3(0.05, 0.73, -0.15), Vector3(0.09, 0.02, 0.025), false, Basis(Vector3.UP, 0.4))   # off the hook
	return null

func _desk(ctx: Ctx) -> Node:
	var s := _style(ctx, "wood_light"); var w := float(ctx.def.get("w", 1.0))
	ctx.box(s, Vector3(0, 0.62, 0), Vector3(w * 0.5, 0.015, 0.28))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * (w * 0.5 - 0.02), 0.31, 0), Vector3(0.02, 0.31, 0.27))
	_drawer(ctx, Vector3(w * 0.25, 0.54, -0.01), Vector3(w * 0.2, 0.05, 0.25), s, String(ctx.def.get("id", "desk")) + "_d0", ctx.def.get("contents", {}).get("drawer0", []))
	_contents_on(ctx, ctx.def.get("on", []), Vector3(0, 0.66, 0), Vector3(w * 0.3, 0, 0.1))
	ctx.block(Vector3.ZERO, Vector3(w * 0.5, 0, 0.28))
	return null

func _toy_chest(ctx: Ctx) -> Node:
	var s := _style(ctx, "wood_light")
	ctx.box(s, Vector3(0, 0.02, 0), Vector3(0.4, 0.02, 0.25))
	for sx in [-1.0, 1.0]:
		ctx.box(s, Vector3(sx * 0.39, 0.22, 0), Vector3(0.01, 0.22, 0.25))
	for sz in [-1.0, 1.0]:
		ctx.box(s, Vector3(0, 0.22, sz * 0.24), Vector3(0.4, 0.22, 0.01))
	# the lid: a cabinet door hinged at the back, lying flat
	var lid := Door.new(); lid.name = "ChestLid"; lid.width = 0.8; lid.height = 0.5; lid.thickness = 0.02; lid.style = s
	lid.cabinet = true; lid.max_angle = 100.0; lid.door_id = String(ctx.def.get("id", "chest")) + "_lid"
	ctx.node(lid, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.45, 0.25)))
	lid.build(ctx.light_at(Vector3(0, 0.5, 0)), ctx.alter)
	lid.display_name = "Toy chest"
	_contents_on(ctx, ctx.def.get("contents", {}).get("inside", []), Vector3(0, 0.06, 0), Vector3(0.2, 0, 0.05))
	ctx.block(Vector3.ZERO, Vector3(0.4, 0, 0.25))
	return null

func _mirror(ctx: Ctx) -> Node:
	ctx.box("wood_dark", Vector3(0, 1.5, 0.02), Vector3(0.3, 0.42, 0.012), false)
	ctx.box("glass", Vector3(0, 1.5, 0.0), Vector3(0.26, 0.38, 0.01), false)
	return null

func _picture(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 0.35)); var h := float(ctx.def.get("h", 0.45)); var y := float(ctx.def.get("y0", 1.55))
	ctx.box("wood_dark", Vector3(0, y, 0.01), Vector3(w * 0.5, h * 0.5, 0.01), false)
	ctx.box(String(ctx.def.get("inner", "paper")), Vector3(0, y, 0.0), Vector3(w * 0.42, h * 0.42, 0.012), false)
	return null

static func _note_at(ctx: Ctx, local: Vector3, doc: String, style: String, b: Basis) -> void:
	var r := Fixtures.Readable.new(); r.doc_id = doc; r.name = "Doc_" + doc
	ctx.node(r, Transform3D(b, local))
	var body := StaticBody3D.new(); body.collision_layer = 32
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.22, 0.28, 0.04); cs.shape = bs
	body.add_child(cs); r.add_child(body)
	var mb := MB.new()
	mb.box(style, Vector3.ZERO, Vector3(0.1, 0.13, 0.003), Basis.IDENTITY, 0.25)
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit({style: Mats.flat(style, ctx.light_at(local), ctx.alter)})
	r.add_child(mi)
	Hook.attach(body, r, "Note")

func _paper(ctx: Ctx) -> Node:
	_note_at(ctx, Vector3(0, float(ctx.def.get("h", 1.45)), 0), String(ctx.def.doc), "paper", Basis.IDENTITY)
	return null

func _sticky(ctx: Ctx) -> Node:
	var r := Fixtures.Readable.new(); r.doc_id = String(ctx.def.get("doc", "sticky_outside")); r.name = "Sticky"
	ctx.node(r, Transform3D(Basis.IDENTITY, Vector3(0, float(ctx.def.get("h", 1.5)), 0)))
	var body := StaticBody3D.new(); body.collision_layer = 32
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.3, 0.3, 0.1); cs.shape = bs
	body.add_child(cs); r.add_child(body)
	var mb := MB.new()
	mb.box("sticky", Vector3.ZERO, Vector3(0.0381, 0.0381, 0.002), Basis.IDENTITY, 0.08)
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit({"sticky": Mats.flat("sticky", Color(0.7, 0.7, 0.6))}); r.add_child(mi)
	# its word, written on it
	var lbl := Label3D.new(); lbl.text = String(ctx.def.get("text", "OUTSIDE")); lbl.font_size = 12; lbl.pixel_size = 0.0012
	lbl.modulate = Color(0.1, 0.1, 0.25); lbl.position = Vector3(0, 0, -0.003); lbl.rotation.y = PI
	lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	lbl.double_sided = false
	r.add_child(lbl)
	Hook.attach(body, r, "Sticky note")
	return r

func _switch(ctx: Ctx) -> Node:
	var sw := LightSwitch.new(); sw.room = String(ctx.def.get("controls", ctx.room)); sw.name = "Switch_" + sw.room
	ctx.node(sw, Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0)))
	sw.build(ctx)
	return sw

## A hole in a wall, boarded / panelled over (or open). Breakable; `leads` names where it goes.
func _hole(ctx: Ctx) -> Node:
	var b := Fixtures.Breakable.new(); b.name = "Hole_" + String(ctx.def.get("id", "hole"))
	b.break_id = String(ctx.def.get("id", "hole")); b.hp = float(ctx.def.get("hp", 60.0))
	b.unscrew = ctx.def.get("unscrew", false); b.label = String(ctx.def.get("label", "Smash through"))
	var w := float(ctx.def.get("w", 0.7)); var h := float(ctx.def.get("hh", 0.8)); var y := float(ctx.def.get("y0", 0.45))
	ctx.node(b, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	var body := StaticBody3D.new(); body.collision_layer = 1
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(w, h, 0.08); cs.shape = bs
	body.add_child(cs); b.add_child(body); b.body = body
	var st := String(ctx.def.get("cover", "wood_raw"))
	var mb := MB.new()
	if st == "wood_raw":
		for i in 4:
			mb.box(st, Vector3(0, -h * 0.4 + i * h * 0.27, 0), Vector3(w * 0.55, h * 0.11, 0.015), Basis(Vector3.FORWARD, randf_range(-0.1, 0.1)))
	else:
		mb.box(st, Vector3.ZERO, Vector3(w * 0.5, h * 0.5, 0.01))
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				mb.box("chrome", Vector3(sx * w * 0.44, sy * h * 0.44, -0.012), Vector3(0.008, 0.008, 0.004))
	var lc := ctx.light_at(Vector3(0, y, 0))
	var mats := {st: Mats.flat(st, lc, ctx.alter), "chrome": Mats.flat("chrome", lc, ctx.alter)}
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit(mats); b.add_child(mi)
	Hook.attach(body, b, "Boarded hole" if st == "wood_raw" else "Panel")
	ctx.level.register_breakable(b)
	return b

## the growth: coral reaching out of a surface (both apartments; more of it in the Backrooms)
func _coral(ctx: Ctx) -> Node:
	var n := int(ctx.def.get("n", 6)); var size := float(ctx.def.get("size", 0.5))
	var rng := RandomNumberGenerator.new(); rng.seed = hash(ctx.def.get("p", [0, 0]))
	for i in n:
		var base := Vector3(rng.randf_range(-size, size), 0, rng.randf_range(-size, size) * 0.5)
		var h := rng.randf_range(0.2, 0.7) * size * 2.0
		var r := rng.randf_range(0.02, 0.05)
		ctx.mb.xf = ctx.xf * Transform3D(Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.1, 0.5)), base)
		ctx.mb.cyl("coral", Vector3.ZERO, r, h, 5, r * 0.4)
		ctx.mb.cyl("coral", Vector3(0, h * 0.6, 0), r * 0.6, h * 0.4, 5, 0.005)
	ctx.mb.xf = Transform3D.IDENTITY
	return null

## a loose prop (anything in PropKit.DEFS), placed and lit where it lands
func _prop(ctx: Ctx) -> Node:
	var p := PropKit.make(String(ctx.def.kind), ctx.light, {"persist": ctx.def.get("id", ""), "contents": ctx.def.get("contents", []),
		"alter": ctx.alter, "at": ctx.xf.origin, "name": ctx.def.get("name", PropKit.DEFS.get(String(ctx.def.kind), {}).get("name", "Object"))})
	ctx.node(p, Transform3D(Basis.IDENTITY, Vector3(0, float(ctx.def.get("lift", 0.15)), 0)))
	if ctx.def.get("frozen", false):
		p.freeze = true
	if ctx.def.has("on_ready"):
		ctx.level.call_deferred("prop_ready", p, ctx.def.on_ready)
	return p

## a stack of cardboard boxes (the boxes...)
func _boxes(ctx: Ctx) -> Node:
	var n := int(ctx.def.get("n", 4))
	for i in n:
		var big := i % 3 == 0
		var p := PropKit.make("box_big" if big else "box_small", ctx.light, {"alter": ctx.alter, "at": ctx.xf.origin})
		var y := 0.25 + (i / 2) * 0.45
		ctx.node(p, Transform3D(Basis(Vector3.UP, randf_range(-0.3, 0.3)), Vector3((i % 2) * 0.5 - 0.25, y, randf_range(-0.05, 0.05))))
	if ctx.def.has("label"):
		_note_at(ctx, Vector3(0, 0.35, -0.3), String(ctx.def.label), "cardboard", Basis.IDENTITY)
	return null

func _railing(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 3.0))
	ctx.box("metal", Vector3(0, 1.0, 0), Vector3(w * 0.5, 0.025, 0.025))
	ctx.box("metal", Vector3(0, 0.5, 0), Vector3(w * 0.5, 0.5, 0.02), true)      # collision only, mostly
	for i in int(w / 0.15) + 1:
		ctx.box("metal", Vector3(-w * 0.5 + i * 0.15, 0.5, 0), Vector3(0.01, 0.5, 0.01), false)
	return null

## beyond the balcony: nothing. A flat pale nothing, a few metres off, in every direction.
func _balcony_void(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 30.0))
	ctx.mb.xf = ctx.xf
	ctx.mb.plane("void", Vector3(-w * 0.5, -10.0, 0), Vector3(w, 0, 0), Vector3(0, 30, 0), Vector3(0, 0, 1), 4.0, 6.0)
	ctx.mb.plane("void", Vector3(-w * 0.5, -0.05, 0), Vector3(w, 0, 0), Vector3(0, 0, 8), Vector3.UP, 4.0, 6.0)
	ctx.mb.xf = Transform3D.IDENTITY
	return null

func _stairs_down(ctx: Ctx) -> Node:
	for i in 6:
		ctx.box("concrete", Vector3(0, -0.15 * i - 0.075, -0.3 * i), Vector3(0.6, 0.075, 0.15))
	ctx.box("green_paint", Vector3(0, -0.5, -1.8), Vector3(0.8, 1.5, 0.05))
	return null

func _curtain(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 1.2))
	for i in int(w / 0.12):
		ctx.box("fabric_bed", Vector3(-w * 0.5 + i * 0.12 + 0.06, 1.4, sin(i * 1.7) * 0.03), Vector3(0.06, 0.95, 0.01), false)
	return null

func _hiding_closet(ctx: Ctx) -> Node:
	# a built-in closet: a narrow wardrobe set into the wall
	ctx.def["w"] = 0.7
	ctx.def["h"] = 2.1
	return _wardrobe(ctx)

## standing water on the floor (a hazard when its circuit's live)
func _water(ctx: Ctx) -> Node:
	var w := float(ctx.def.get("w", 2.0)); var l := float(ctx.def.get("l", 2.0))
	ctx.mb.xf = ctx.xf
	ctx.mb.plane("water", Vector3(-w * 0.5, 0.012, l * 0.5), Vector3(w, 0, 0), Vector3(0, 0, -l), Vector3.UP, w, 1.0)
	ctx.mb.xf = Transform3D.IDENTITY
	return null

## Flat 48's furniture: a pale block, the size of what should be there
func _draft_block(ctx: Ctx) -> Node:
	var s: Array = ctx.def.get("size", [1.0, 0.8, 0.6])
	ctx.box("draft", Vector3(0, s[1] * 0.5, 0), Vector3(s[0] * 0.5, s[1] * 0.5, s[2] * 0.5))
	ctx.block(Vector3.ZERO, Vector3(s[0] * 0.5, 0, s[2] * 0.5))
	if ctx.def.has("tag"):
		var lbl := Label3D.new(); lbl.text = String(ctx.def.tag); lbl.font_size = 18; lbl.pixel_size = 0.0025
		lbl.modulate = Color(0.25, 0.25, 0.3); lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ctx.node(lbl, Transform3D(Basis.IDENTITY, Vector3(0, s[1] * 0.7, -s[2] * 0.5 - 0.01)))
		lbl.rotation.y = PI
	return null
