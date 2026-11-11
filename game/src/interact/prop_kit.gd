class_name PropKit
## Makes props: household objects (for both apartments) and the physical form of inventory items.
## Each definition: shape, size (m), style, mass (kg), sound, noise_k, fragile, hp, tags, item,
## doc, and an optional behaviour (radio, alarm clock, music box).

const DEFS := {
	# household
	"bottle":    {"name": "Bottle", "shape": "cyl", "size": Vector3(0.035, 0.28, 0), "style": "glass", "mass": 0.6, "sound": "glass", "fragile": true, "break_speed": 3.0, "tags": ["throwable"]},
	"jar":       {"name": "Jar", "shape": "cyl", "size": Vector3(0.05, 0.16, 0), "style": "glass", "mass": 0.7, "sound": "glass", "fragile": true, "break_speed": 3.0, "tags": ["throwable"]},
	"plate":     {"name": "Plate", "shape": "cyl", "size": Vector3(0.12, 0.02, 0), "style": "enamel", "mass": 0.4, "sound": "glass", "fragile": true, "break_speed": 2.5},
	"cup":       {"name": "Cup", "shape": "cyl", "size": Vector3(0.04, 0.08, 0), "style": "enamel", "mass": 0.25, "sound": "glass", "fragile": true, "break_speed": 2.5},
	"pot":       {"name": "Saucepan", "shape": "cyl", "size": Vector3(0.1, 0.12, 0), "style": "metal", "mass": 1.2, "sound": "metal", "noise_k": 1.6, "tags": ["throwable"]},
	"book":      {"name": "Book", "shape": "box", "size": Vector3(0.15, 0.04, 0.22), "style": "wood_dark", "mass": 0.6, "sound": "soft", "noise_k": 0.6},
	"box_small": {"name": "Box", "shape": "box", "size": Vector3(0.35, 0.25, 0.3), "style": "cardboard", "mass": 2.5, "sound": "soft", "noise_k": 0.5, "hp": 15.0, "tags": ["breakable", "stack"]},
	"box_big":   {"name": "Box", "shape": "box", "size": Vector3(0.55, 0.45, 0.45), "style": "cardboard", "mass": 9.0, "sound": "soft", "noise_k": 0.6, "hp": 20.0, "tags": ["stack", "climb"]},
	"chair":     {"name": "Chair", "shape": "chair", "size": Vector3(0.42, 0.9, 0.42), "style": "wood_dark", "mass": 6.0, "sound": "wood", "noise_k": 1.3, "hp": 50.0, "tags": ["throwable", "barricade", "climb"]},
	"stool":     {"name": "Stool", "shape": "stool", "size": Vector3(0.32, 0.5, 0.32), "style": "wood_light", "mass": 3.0, "sound": "wood", "noise_k": 1.2, "tags": ["throwable", "climb"]},
	"cushion":   {"name": "Cushion", "shape": "box", "size": Vector3(0.4, 0.1, 0.4), "style": "fabric_green", "mass": 0.5, "sound": "soft", "noise_k": 0.15},
	"bucket":    {"name": "Bucket", "shape": "cyl", "size": Vector3(0.14, 0.28, 0), "style": "metal", "mass": 1.0, "sound": "metal", "noise_k": 1.8, "tags": ["throwable"]},
	"brick":     {"name": "Brick", "shape": "box", "size": Vector3(0.2, 0.065, 0.1), "style": "concrete", "mass": 2.4, "sound": "thud", "noise_k": 1.4, "tags": ["throwable"]},
	"plank":     {"name": "Plank", "shape": "box", "size": Vector3(0.22, 0.04, 2.3), "style": "wood_raw", "mass": 9.0, "sound": "wood", "noise_k": 1.0, "hp": 80.0, "tags": ["plank", "barricade"]},
	"radio":     {"name": "Radio", "shape": "box", "size": Vector3(0.3, 0.18, 0.12), "style": "wood_dark", "mass": 2.2, "sound": "wood", "noise_k": 1.0, "behaviour": "radio"},
	"tv":        {"name": "Television", "shape": "box", "size": Vector3(0.5, 0.42, 0.42), "style": "wood_dark", "mass": 16.0, "sound": "glass", "noise_k": 1.5, "hp": 40.0, "tags": ["barricade"]},
	"suitcase":  {"name": "Suitcase", "shape": "box", "size": Vector3(0.6, 0.18, 0.4), "style": "door_padded", "mass": 7.0, "sound": "soft", "noise_k": 0.8, "tags": ["barricade"]},
	"crate":     {"name": "Crate", "shape": "box", "size": Vector3(0.6, 0.5, 0.5), "style": "wood_raw", "mass": 22.0, "sound": "wood", "noise_k": 1.0, "hp": 60.0, "tags": ["barricade", "climb", "breakable"]},
	"sideboard": {"name": "Cabinet", "shape": "box", "size": Vector3(1.0, 0.8, 0.45), "style": "wood_dark", "mass": 45.0, "sound": "wood", "tags": ["barricade"]},
	# items (their physical form)
	"torch":         {"name": "Torch", "shape": "cyl_x", "size": Vector3(0.025, 0.22, 0), "style": "rubber", "mass": 0.5, "sound": "metal", "item": "torch"},
	"battery":       {"name": "Batteries", "shape": "box", "size": Vector3(0.06, 0.06, 0.04), "style": "paper", "mass": 0.2, "item": "battery"},
	"lighter":       {"name": "Lighter", "shape": "box", "size": Vector3(0.03, 0.05, 0.015), "style": "brass", "mass": 0.1, "sound": "metal", "item": "lighter"},
	"screwdriver":   {"name": "Screwdriver", "shape": "cyl_x", "size": Vector3(0.012, 0.2, 0), "style": "metal", "mass": 0.2, "sound": "metal", "item": "screwdriver"},
	"hairpin":       {"name": "Hairpins", "shape": "box", "size": Vector3(0.04, 0.005, 0.06), "style": "paper", "mass": 0.02, "item": "hairpin"},
	"hammer":        {"name": "Hammer", "shape": "box", "size": Vector3(0.04, 0.04, 0.3), "style": "metal", "mass": 0.8, "sound": "metal", "item": "hammer"},
	"crowbar":       {"name": "Crowbar", "shape": "box", "size": Vector3(0.03, 0.03, 0.42), "style": "metal", "mass": 1.6, "sound": "metal", "noise_k": 1.6, "item": "crowbar"},
	"bolt_cutters":  {"name": "Bolt cutters", "shape": "box", "size": Vector3(0.08, 0.03, 0.6), "style": "metal", "mass": 2.5, "sound": "metal", "item": "bolt_cutters"},
	"pills":         {"name": "Pills", "shape": "cyl", "size": Vector3(0.025, 0.08, 0), "style": "wood_dark", "mass": 0.1, "item": "pills"},
	"bandage":       {"name": "Bandage", "shape": "cyl", "size": Vector3(0.03, 0.06, 0), "style": "white", "mass": 0.05, "item": "bandage"},
	"fuse":          {"name": "Fuse", "shape": "cyl", "size": Vector3(0.015, 0.04, 0), "style": "white", "mass": 0.05, "item": "fuse"},
	"key_flat47":    {"name": "Keys", "shape": "box", "size": Vector3(0.05, 0.01, 0.08), "style": "brass", "mass": 0.05, "sound": "metal", "item": "key_flat47"},
	"key_padlock":   {"name": "Small key", "shape": "box", "size": Vector3(0.025, 0.006, 0.05), "style": "brass", "mass": 0.02, "sound": "metal", "item": "key_padlock"},
	"key_apt13":     {"name": "Key", "shape": "box", "size": Vector3(0.03, 0.008, 0.07), "style": "brass", "mass": 0.03, "sound": "metal", "item": "key_apt13"},
	"key_storage":   {"name": "Key", "shape": "box", "size": Vector3(0.03, 0.008, 0.07), "style": "chrome", "mass": 0.03, "sound": "metal", "item": "key_storage"},
	"revolver":      {"name": "Revolver", "shape": "gun", "size": Vector3(0.04, 0.12, 0.25), "style": "metal", "mass": 0.8, "sound": "metal", "item": "revolver"},
	"ammo":          {"name": "Rounds", "shape": "box", "size": Vector3(0.04, 0.02, 0.04), "style": "brass", "mass": 0.05, "sound": "metal", "item": "ammo"},
	"music_box":     {"name": "Music box", "shape": "box", "size": Vector3(0.14, 0.09, 0.1), "style": "metal", "mass": 0.6, "sound": "metal", "item": "music_box", "behaviour": "music_box"},
	"alarm_clock":   {"name": "Alarm clock", "shape": "cyl_z", "size": Vector3(0.06, 0.05, 0), "style": "chrome", "mass": 0.4, "sound": "metal", "noise_k": 1.4, "item": "alarm_clock", "behaviour": "alarm_clock"},
	"telegram":      {"name": "Telegram", "shape": "box", "size": Vector3(0.15, 0.004, 0.1), "style": "paper", "mass": 0.01, "item": "telegram", "doc": "telegram"},
	"photo_cut":     {"name": "Photograph", "shape": "box", "size": Vector3(0.13, 0.004, 0.09), "style": "paper", "mass": 0.01, "item": "photo_cut", "doc": "photo_cut"},
	"clipping":      {"name": "Clipping", "shape": "box", "size": Vector3(0.08, 0.004, 0.06), "style": "paper", "mass": 0.01, "item": "clipping", "doc": "clipping"},
	"drawing":       {"name": "Drawing", "shape": "box", "size": Vector3(0.21, 0.004, 0.15), "style": "paper", "mass": 0.01, "item": "drawing", "doc": "drawing"},
	"diary_page":    {"name": "Torn page", "shape": "box", "size": Vector3(0.15, 0.004, 0.2), "style": "paper", "mass": 0.01, "item": "diary_page", "doc": "diary_page"},
	"letter_returned": {"name": "Letter", "shape": "box", "size": Vector3(0.16, 0.006, 0.1), "style": "paper", "mass": 0.02, "item": "letter_returned", "doc": "letter_returned"},
}

## kind: a DEFS key; opts: {alter: material alteration, persist: id, contents: [item ids], name}
static func make(kind: String, light_fn: Callable, opts := {}) -> Prop:
	var d: Dictionary = DEFS.get(kind, DEFS["box_small"])
	var p := Prop.new()
	p.name = kind
	p.display_name = String(opts.get("name", d.get("name", kind)))
	p.mass = float(d.get("mass", 1.0))
	p.sound = String(d.get("sound", "thud"))
	p.noise_k = float(d.get("noise_k", 1.0))
	p.fragile = bool(d.get("fragile", false))
	p.break_speed = float(d.get("break_speed", 4.0))
	p.hp = float(d.get("hp", 999.0 if not p.fragile else 5.0))
	p.item_id = String(d.get("item", ""))
	p.doc_id = String(d.get("doc", ""))
	p.tags = d.get("tags", []).duplicate()
	p.contents = opts.get("contents", [])
	p.persist_id = String(opts.get("persist", ""))
	p.inspect_text = String(opts.get("text", ""))
	p.light_fn = light_fn
	var style: String = d.get("style", "white")
	var c := Color(0.45, 0.43, 0.4)
	if light_fn.is_valid() and opts.has("at"):
		c = light_fn.call(opts.at, Vector3.UP)
	var mat := Mats.flat(style, c, opts.get("alter", {}))
	var mats := {style: mat}
	var mb := MB.new()
	var sz: Vector3 = d.size
	var shape: Shape3D
	var shape_xf := Transform3D.IDENTITY
	match String(d.get("shape", "box")):
		"box":
			mb.box(style, Vector3.ZERO, sz * 0.5, Basis.IDENTITY, Mats.uvm(style))
			var bs := BoxShape3D.new(); bs.size = sz; shape = bs
		"cyl":
			mb.cyl(style, Vector3(0, -sz.y * 0.5, 0), sz.x, sz.y, 8)
			var cs := CylinderShape3D.new(); cs.radius = sz.x; cs.height = sz.y; shape = cs
		"cyl_x", "cyl_z":
			var b := Basis(Vector3.FORWARD, PI * 0.5) if d.shape == "cyl_x" else Basis(Vector3.RIGHT, PI * 0.5)
			mb.xf = Transform3D(b, Vector3.ZERO)
			mb.cyl(style, Vector3(0, -sz.y * 0.5, 0), sz.x, sz.y, 8)
			mb.xf = Transform3D.IDENTITY
			var cs := CylinderShape3D.new(); cs.radius = sz.x; cs.height = sz.y; shape = cs
			shape_xf = Transform3D(b, Vector3.ZERO)
		"chair":
			_chair(mb, style, sz)
			var bs := BoxShape3D.new(); bs.size = Vector3(sz.x, sz.y, sz.z); shape = bs
		"stool":
			mb.xf = Transform3D(Basis.IDENTITY, Vector3(0, -sz.y * 0.5, 0))
			mb.box(style, Vector3(0, sz.y * 0.47, 0), Vector3(sz.x * 0.5, 0.025, sz.z * 0.5))
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					mb.box(style, Vector3(sx * sz.x * 0.38, sz.y * 0.22, sz2 * sz.z * 0.38), Vector3(0.02, sz.y * 0.23, 0.02))
			mb.xf = Transform3D.IDENTITY
			var bs := BoxShape3D.new(); bs.size = sz; shape = bs
		"gun":
			mb.box("metal", Vector3(0, 0.02, -0.08), Vector3(0.012, 0.012, 0.09))
			mb.box("metal", Vector3(0, 0.02, 0.02), Vector3(0.02, 0.022, 0.03))
			mb.box("wood_dark", Vector3(0, -0.04, 0.07), Vector3(0.014, 0.05, 0.022), Basis(Vector3.RIGHT, -0.4))
			mats["wood_dark"] = Mats.flat("wood_dark", c)
			var bs := BoxShape3D.new(); bs.size = Vector3(0.05, 0.1, 0.24); shape = bs
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit(mats)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	var col := CollisionShape3D.new(); col.shape = shape; col.transform = shape_xf
	p.add_child(col)
	p.set_materials(mats.values())
	if d.has("behaviour"):
		var bh: Node = load("res://src/interact/behaviours.gd").new_behaviour(String(d.behaviour))
		bh.name = "Behaviour"
		p.add_child(bh)
		p.behaviour = bh
	return p

static func item(item_id: String, light_fn: Callable) -> Prop:
	# item ids and prop kinds coincide for every item with a physical form
	return make(item_id if DEFS.has(item_id) else "box_small", light_fn)

static func _chair(mb: MB, style: String, sz: Vector3) -> void:
	var y0 := -sz.y * 0.5
	var seat := 0.46
	mb.box(style, Vector3(0, y0 + seat, 0), Vector3(sz.x * 0.5, 0.025, sz.z * 0.5))
	for sx in [-1.0, 1.0]:
		for szz in [-1.0, 1.0]:
			mb.box(style, Vector3(sx * sz.x * 0.42, y0 + seat * 0.5, szz * sz.z * 0.42), Vector3(0.022, seat * 0.5, 0.022))
	mb.box(style, Vector3(0, y0 + seat + 0.24, sz.z * 0.45), Vector3(sz.x * 0.5, 0.2, 0.02))
	for sx in [-1.0, 1.0]:
		mb.box(style, Vector3(sx * sz.x * 0.42, y0 + seat + 0.2, sz.z * 0.45), Vector3(0.022, 0.22, 0.022))
