class_name Minis
extends RefCounted
## Builds painted tabletop miniatures from a small description:
##   {body, color, accent, skin, head, weapon, offhand, h, hunch, wings, number}
## Bodies share one modelling language (boxes, 6-sided cylinders, 4x6 spheres) so heroes,
## monsters and bosses look like they came out of the same box, but each body type has its
## own silhouette. Units: 1.0 = a standing figure's height; the board scales it down.

const CLASS_LOOK := {
	"fighter": {"body": "humanoid", "head": "helm", "weapon": "sword", "offhand": "shield"},
	"rogue": {"body": "humanoid", "head": "hood", "weapon": "knife", "offhand": "knife"},
	"cleric": {"body": "robed", "head": "round", "weapon": "mace", "offhand": "symbol"},
	"wizard": {"body": "robed", "head": "pointy", "weapon": "staff"},
	"ranger": {"body": "humanoid", "head": "hood", "weapon": "bow"},
	"barbarian": {"body": "hulk", "head": "horns", "weapon": "axe"},
	"bard": {"body": "humanoid", "head": "feather", "weapon": "lute"},
	"warlock": {"body": "robed", "head": "hood", "weapon": "tome"},
}

static func hero_spec(db: ContentDB, h: Dictionary) -> Dictionary:
	var c := db.get_def("classes", h.get("class", "fighter"))
	var a := db.get_def("ancestries", h.get("ancestry", "human"))
	var spec: Dictionary = CLASS_LOOK.get(h.get("class", "fighter"), c.get("look", CLASS_LOOK["fighter"])).duplicate()
	var pal: Array = c.get("palette", ["#7a6a58", "#9c2a1e"])
	spec["color"] = pal[0]
	spec["accent"] = pal[1]
	var look: Dictionary = a.get("look", {})
	spec["skin"] = look.get("skin", "#c89a78")
	spec["h"] = float(look.get("scale", 1.0))
	match look.get("head", "round"):
		"ball":
			spec["head"] = "ball"
			spec["number"] = int(h.get("number", 7))
		"skull":
			spec["head_under"] = "skull"
		"beard":
			spec["beard"] = true
		"ears":
			spec["ears"] = true
	if h.get("fallen", false):
		spec["ghost"] = true
	return spec

static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Mini"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var col := Color(spec.get("color", "#6a6a6a"))
	var acc := Color(spec.get("accent", "#3a3a3a"))
	var skin := Color(spec.get("skin", "#c89a78"))
	if spec.get("ghost", false):
		col = col.lerp(Color("b8c8c0"), 0.6)
		acc = acc.lerp(Color("d8e0d8"), 0.6)
		skin = skin.lerp(Color("d8e8e0"), 0.7)
	var paint := MB.mat(Tex.grime(Color(0.82, 0.82, 0.82), Color(1, 1, 1), 16, 40, 0.35))
	var mb := MB.new()
	var arm := MB.new()
	var b: String = spec.get("body", "humanoid")
	var hunch := float(spec.get("hunch", 0.0))
	var head_at := Vector3(0, 0.88, 0)
	var hand_at := Vector3(0.22, 0.5, 0.06)
	var off_at := Vector3(-0.22, 0.5, 0.06)
	var head_size := 0.13
	match b:
		"humanoid", "knight", "tall":
			var s := 1.15 if b == "knight" else 1.0
			var tall := 1.25 if b == "tall" else 1.0
			mb.box("p", paint, Vector3(0.11, 0.42 * tall, 0.12) * Vector3(s, 1, s), MB.T(Vector3(-0.08 * s, 0.21 * tall, 0)), acc.darkened(0.2))
			mb.box("p", paint, Vector3(0.11, 0.42 * tall, 0.12) * Vector3(s, 1, s), MB.T(Vector3(0.08 * s, 0.21 * tall, 0)), acc.darkened(0.2))
			mb.box("p", paint, Vector3(0.32, 0.36, 0.18) * Vector3(s, tall, s), MB.T(Vector3(0, 0.6 * tall, -hunch * 0.1), Vector3(hunch, 0, 0)), col)
			mb.box("p", paint, Vector3(0.34, 0.06, 0.2) * Vector3(s, 1, s), MB.T(Vector3(0, 0.44 * tall, 0)), acc)
			if b == "knight":
				mb.box("p", paint, Vector3(0.16, 0.08, 0.2), MB.T(Vector3(-0.22, 0.78, 0), Vector3(0, 0, 0.3)), acc)
				mb.box("p", paint, Vector3(0.16, 0.08, 0.2), MB.T(Vector3(0.22, 0.78, 0), Vector3(0, 0, -0.3)), acc)
			mb.box("p", paint, Vector3(0.08, 0.34 * tall, 0.09), MB.T(Vector3(-0.2 * s, 0.6 * tall, 0.02), Vector3(0.2, 0, 0.12)), col.darkened(0.1))
			arm.box("p", paint, Vector3(0.08, 0.34 * tall, 0.09), MB.T(Vector3(0.2 * s, 0.6 * tall, 0.02), Vector3(0.3, 0, -0.12)), col.darkened(0.1))
			head_at = Vector3(0, (0.82 + 0.08) * tall * (1.0 if b != "knight" else 1.02), -hunch * 0.2)
			hand_at = Vector3(0.23 * s, 0.44 * tall, 0.08)
			off_at = Vector3(-0.23 * s, 0.44 * tall, 0.08)
		"robed":
			mb.cyl("p", paint, 0.24, 0.13, 0.62, 6, MB.T(), col)
			mb.box("p", paint, Vector3(0.28, 0.24, 0.17), MB.T(Vector3(0, 0.7, 0)), col)
			mb.box("p", paint, Vector3(0.05, 0.6, 0.02), MB.T(Vector3(0, 0.38, 0.17), Vector3(-0.3, 0, 0)), acc)
			mb.box("p", paint, Vector3(0.08, 0.32, 0.09), MB.T(Vector3(-0.19, 0.6, 0.03), Vector3(0.3, 0, 0.15)), col.darkened(0.15))
			arm.box("p", paint, Vector3(0.08, 0.32, 0.09), MB.T(Vector3(0.19, 0.6, 0.03), Vector3(0.4, 0, -0.15)), col.darkened(0.15))
			head_at = Vector3(0, 0.92, 0)
			hand_at = Vector3(0.22, 0.46, 0.1)
			off_at = Vector3(-0.22, 0.46, 0.1)
		"hulk":
			mb.box("p", paint, Vector3(0.14, 0.34, 0.15), MB.T(Vector3(-0.11, 0.17, 0)), acc.darkened(0.2))
			mb.box("p", paint, Vector3(0.14, 0.34, 0.15), MB.T(Vector3(0.11, 0.17, 0)), acc.darkened(0.2))
			mb.box("p", paint, Vector3(0.46, 0.42, 0.28), MB.T(Vector3(0, 0.56, -0.02), Vector3(0.15, 0, 0)), col)
			mb.box("p", paint, Vector3(0.13, 0.42, 0.14), MB.T(Vector3(-0.31, 0.5, 0.04), Vector3(0.2, 0, 0.1)), col.darkened(0.1))
			arm.box("p", paint, Vector3(0.13, 0.42, 0.14), MB.T(Vector3(0.31, 0.5, 0.04), Vector3(0.3, 0, -0.1)), col.darkened(0.1))
			head_at = Vector3(0, 0.84, 0.04)
			head_size = 0.12
			hand_at = Vector3(0.33, 0.3, 0.1)
			off_at = Vector3(-0.33, 0.3, 0.1)
		"crawler":
			mb.sphere("p", paint, 0.22, 3, 6, MB.T(Vector3(0, 0.22, 0)), col, Vector3(1.3, 0.6, 1.0))
			for i in range(6):
				var side := -1 if i < 3 else 1
				var zz := -0.12 + (i % 3) * 0.12
				mb.box("p", paint, Vector3(0.28, 0.035, 0.035), MB.T(Vector3(side * 0.22, 0.16, zz), Vector3(0, 0, side * -0.6)), acc)
			head_at = Vector3(0, 0.24, 0.24)
			head_size = 0.1
			hand_at = Vector3(0.12, 0.2, 0.3)
		"quadruped":
			mb.box("p", paint, Vector3(0.2, 0.18, 0.5), MB.T(Vector3(0, 0.34, 0)), col)
			for p in [Vector3(-0.07, 0.13, -0.18), Vector3(0.07, 0.13, -0.18), Vector3(-0.07, 0.13, 0.18), Vector3(0.07, 0.13, 0.18)]:
				mb.box("p", paint, Vector3(0.06, 0.26, 0.06), MB.T(p), acc)
			mb.box("p", paint, Vector3(0.04, 0.04, 0.2), MB.T(Vector3(0, 0.42, -0.32), Vector3(0.6, 0, 0)), col)
			head_at = Vector3(0, 0.46, 0.3)
			head_size = 0.11
			hand_at = Vector3(0, 0.4, 0.4)
		"blob":
			mb.sphere("p", paint, 0.36, 4, 7, MB.T(Vector3(0, 0.34, 0)), col, Vector3(1.0, 0.9, 0.9))
			mb.sphere("p", paint, 0.16, 3, 6, MB.T(Vector3(0.12, 0.42, 0.22)), acc)
			mb.box("p", paint, Vector3(0.08, 0.22, 0.08), MB.T(Vector3(-0.34, 0.36, 0.05), Vector3(0, 0, 0.6)), col.darkened(0.15))
			arm.box("p", paint, Vector3(0.08, 0.22, 0.08), MB.T(Vector3(0.34, 0.36, 0.05), Vector3(0, 0, -0.6)), col.darkened(0.15))
			head_at = Vector3(0, 0.7, 0.05)
			head_size = 0.12
			hand_at = Vector3(0.42, 0.28, 0.1)
		"worm":
			for i in range(5):
				var t := i / 4.0
				mb.sphere("p", paint, 0.16 - t * 0.04, 3, 6, MB.T(Vector3(sin(t * 3.0) * 0.1, 0.12 + t * 0.55, -0.1 + t * 0.15)), col if i % 2 == 0 else col.darkened(0.15))
			head_at = Vector3(sin(3.0) * 0.1, 0.78, 0.07)
			head_size = 0.12
			spec["head"] = spec.get("head", "maw")
		"floating":
			mb.sphere("p", paint, 0.2, 3, 6, MB.T(Vector3(0, 0.55, 0)), col, Vector3(1, 1.3, 1))
			mb.cyl("p", paint, 0.12, 0.0, 0.3, 5, MB.T(Vector3(0, 0.38, 0), Vector3(PI, 0, 0)), col.darkened(0.2))
			head_at = Vector3(0, 0.85, 0.02)
			hand_at = Vector3(0.2, 0.55, 0.1)
		"construct":
			mb.box("p", paint, Vector3(0.12, 0.3, 0.14), MB.T(Vector3(-0.1, 0.15, 0)), acc)
			mb.box("p", paint, Vector3(0.12, 0.3, 0.14), MB.T(Vector3(0.1, 0.15, 0)), acc)
			mb.box("p", paint, Vector3(0.4, 0.38, 0.3), MB.T(Vector3(0, 0.5, 0)), col)
			mb.cyl("p", paint, 0.04, 0.04, 0.3, 5, MB.T(Vector3(-0.12, 0.65, -0.14)), acc.darkened(0.3))
			mb.cyl("p", paint, 0.04, 0.04, 0.24, 5, MB.T(Vector3(0.1, 0.65, -0.14)), acc.darkened(0.3))
			mb.box("p", paint, Vector3(0.1, 0.32, 0.1), MB.T(Vector3(-0.26, 0.5, 0.02)), acc)
			arm.box("p", paint, Vector3(0.1, 0.32, 0.1), MB.T(Vector3(0.26, 0.5, 0.02)), acc)
			head_at = Vector3(0, 0.8, 0)
			hand_at = Vector3(0.27, 0.3, 0.1)
			off_at = Vector3(-0.27, 0.3, 0.1)
		"swarm":
			var rr := RandomNumberGenerator.new()
			rr.seed = 5
			for i in range(9):
				mb.sphere("p", paint, rr.randf_range(0.05, 0.09), 2, 5, MB.T(Vector3(rr.randf_range(-0.25, 0.25), rr.randf_range(0.08, 0.5), rr.randf_range(-0.25, 0.25))), col if i % 3 else acc)
			spec["head"] = "none"
		"die":
			mb.box("p", paint, Vector3(0.5, 0.5, 0.5), MB.T(Vector3(0, 0.3, 0), Vector3(0.0, 0.4, 0.0)), col)
			for p in [Vector3(-0.1, 0.4, 0.26), Vector3(0.1, 0.2, 0.26), Vector3(0, 0.3, 0.26)]:
				mb.box("p", paint, Vector3(0.07, 0.07, 0.02), MB.T(Basis(Vector3.UP, 0.4) * p), acc)
			head_at = Vector3(0, 0.62, 0.05)
			spec["head"] = spec.get("head", "eye")
			head_size = 0.08
		"paper":
			mb.box("p", paint, Vector3(0.36, 0.95, 0.02), MB.T(Vector3(0, 0.5, 0)), col)
			mb.box("p", paint, Vector3(0.4, 0.04, 0.12), MB.T(Vector3(0, 0.02, 0)), acc)
			mb.box("p", paint, Vector3(0.3, 0.2, 0.025), MB.T(Vector3(0, 0.7, 0.002)), acc)
			head_at = Vector3(0, 1.02, 0)
			hand_at = Vector3(0.24, 0.55, 0.02)
		"mound":
			mb.cyl("p", paint, 0.36, 0.12, 0.42, 7, MB.T(), col)
			mb.sphere("p", paint, 0.14, 3, 6, MB.T(Vector3(0, 0.44, 0)), acc)
			head_at = Vector3(0, 0.5, 0.12)
			head_size = 0.1
		_:
			mb.box("p", paint, Vector3(0.3, 0.8, 0.2), MB.T(Vector3(0, 0.4, 0)), col)
	_head(mb, paint, String(spec.get("head", "round")), head_at, head_size, skin, col, acc, spec)
	if spec.get("wings", false):
		for sx in [-1, 1]:
			mb.box("p", paint, Vector3(0.32, 0.2, 0.02), MB.T(head_at + Vector3(0.22 * sx, -0.25, -0.12), Vector3(0, 0.4 * sx, 0.5 * sx)), acc)
	_weapon(arm, paint, String(spec.get("weapon", "")), hand_at, acc)
	_weapon(mb, paint, String(spec.get("offhand", "")), off_at, acc)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.build()
	body.add_child(mi)
	var arm_node := Node3D.new()
	arm_node.name = "Arm"
	# pivot at the shoulder so attacks swing the weapon arm
	var shoulder := Vector3(hand_at.x, head_at.y - 0.15, 0)
	arm_node.position = shoulder
	body.add_child(arm_node)
	if not arm.surfaces.is_empty():
		var ami := MeshInstance3D.new()
		ami.mesh = arm.build()
		ami.position = -shoulder
		arm_node.add_child(ami)
	var sc := float(spec.get("h", 1.0))
	body.scale = Vector3.ONE * sc
	root.set_meta("height", head_at.y * sc + head_size * 2 * sc)
	return root

static func _head(mb: MB, paint: Material, kind: String, at: Vector3, s: float, skin: Color, col: Color, acc: Color, spec: Dictionary) -> void:
	var dark := Color("1a1410")
	var under: String = spec.get("head_under", "")
	var face_col := Color("d8d8c8") if under == "skull" else skin
	match kind:
		"none":
			return
		"ball":
			mb.sphere("p", paint, s * 1.15, 4, 7, MB.T(at), Color("e8e0cc"))
			mb.sphere("p", paint, s * 1.17, 2, 7, MB.T(at, Vector3.ZERO, Vector3(1, 0.45, 1)), Color("2a6aa8"))
			mb.box("p", paint, Vector3(s * 0.9, s * 0.6, 0.01), MB.T(at + Vector3(0, -0.01, s * 1.12)), Color("f0ead8"))
			return
		"helm", "greathelm":
			mb.box("p", paint, Vector3(s * 1.7, s * 1.9, s * 1.7) * (1.25 if kind == "greathelm" else 1.0), MB.T(at), Color("8a8a84") if kind == "helm" else acc)
			mb.box("p", paint, Vector3(s * 1.2, s * 0.15, 0.02), MB.T(at + Vector3(0, 0.0, s * 0.86 * (1.25 if kind == "greathelm" else 1.0))), dark)
			if kind == "greathelm":
				mb.box("p", paint, Vector3(0.03, s * 1.2, s * 1.4), MB.T(at + Vector3(0, s * 1.3, 0)), Color("8a2a1a"))
			return
		"hood":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			mb.cyl("p", paint, s * 1.2, s * 0.2, s * 2.4, 5, MB.T(at + Vector3(0, -s * 0.9, -s * 0.2)), col.darkened(0.25))
			mb.box("p", paint, Vector3(s * 1.0, s * 0.5, 0.02), MB.T(at + Vector3(0, s * 0.1, s * 0.76)), dark)
			return
		"pointy":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			mb.cyl("p", paint, s * 1.5, s * 1.5, s * 0.15, 6, MB.T(at + Vector3(0, s * 0.7, 0)), col)
			mb.cyl("p", paint, s * 0.9, 0.0, s * 2.8, 5, MB.T(at + Vector3(0, s * 0.8, 0), Vector3(-0.15, 0, 0)), col)
			mb.box("p", paint, Vector3(s * 0.8, s * 0.6, s * 0.3), MB.T(at + Vector3(0, -s * 0.85, s * 0.5)), Color("c8c8c0"))
			return
		"mitre":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			mb.box("p", paint, Vector3(s * 1.2, s * 2.2, s * 0.8), MB.T(at + Vector3(0, s * 1.6, 0)), acc)
			return
		"shell":
			mb.sphere("p", paint, s * 1.3, 3, 6, MB.T(at), acc, Vector3(1.1, 0.8, 1.1))
			mb.box("p", paint, Vector3(s * 0.8, s * 0.2, 0.02), MB.T(at + Vector3(0, -s * 0.2, s * 1.4)), dark)
			return
		"wig":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			for sx in [-1, 1]:
				mb.sphere("p", paint, s * 0.6, 3, 5, MB.T(at + Vector3(s * 0.85 * sx, -s * 0.4, 0)), Color("e0dcd0"))
			mb.box("p", paint, Vector3(s * 1.7, s * 0.6, s * 1.7), MB.T(at + Vector3(0, s * 0.9, 0)), Color("e0dcd0"))
		"horns":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			for sx in [-1, 1]:
				mb.cyl("p", paint, s * 0.3, 0.0, s * 1.4, 4, MB.T(at + Vector3(s * 0.7 * sx, s * 0.6, 0), Vector3(0, 0, -0.7 * sx)), Color("d8ccb0"))
		"feather":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			mb.cyl("p", paint, s * 1.6, s * 1.4, s * 0.5, 6, MB.T(at + Vector3(0, s * 0.7, 0)), col)
			mb.box("p", paint, Vector3(0.02, s * 1.8, s * 0.5), MB.T(at + Vector3(s * 0.6, s * 1.4, -s * 0.3), Vector3(0.4, 0, -0.3)), acc)
		"skull":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.7, s * 1.5), MB.T(at), Color("d8d0b8"))
			for sx in [-1, 1]:
				mb.box("p", paint, Vector3(s * 0.4, s * 0.4, 0.02), MB.T(at + Vector3(s * 0.35 * sx, s * 0.15, s * 0.76)), dark)
			return
		"maw":
			mb.sphere("p", paint, s * 1.3, 3, 6, MB.T(at), col)
			mb.cyl("p", paint, s * 0.8, s * 0.6, s * 0.3, 6, MB.T(at + Vector3(0, 0, s * 1.1), Vector3(PI / 2, 0, 0)), Color("5a0a0a"))
			return
		"eye":
			mb.sphere("p", paint, s * 1.2, 3, 6, MB.T(at), Color("e8e0d0"))
			mb.cyl("p", paint, s * 0.5, s * 0.5, 0.02, 6, MB.T(at + Vector3(0, 0, s * 1.15), Vector3(PI / 2, 0, 0)), Color("8a1a1a"))
			return
		"halo":
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
			mb.ring("p", paint, s * 1.1, 0.02, 8, MB.T(at + Vector3(0, s * 1.3, 0)), Color("e8c860"))
		"bucket":
			mb.cyl("p", paint, s * 0.9, s * 0.8, s * 2.0, 6, MB.T(at + Vector3(0, -s * 0.9, 0)), Color("6a6a62"))
			mb.box("p", paint, Vector3(s * 1.2, s * 0.15, 0.02), MB.T(at + Vector3(0, s * 0.2, s * 0.9)), Color("ff8a2a"))
			return
		"cage":
			mb.ring("p", paint, s * 1.2, 0.015, 8, MB.T(at), Color("b08a3a"))
			mb.ring("p", paint, s * 1.2, 0.015, 8, MB.T(at, Vector3(PI / 2, 0, 0)), Color("b08a3a"))
			mb.ring("p", paint, s * 1.2, 0.015, 8, MB.T(at, Vector3(PI / 2, PI / 2, 0)), Color("b08a3a"))
			return
		"mask":
			mb.box("p", paint, Vector3(s * 1.6, s * 1.9, s * 0.4), MB.T(at + Vector3(0, 0, s * 0.3)), Color("e8dcc0"))
			for sx in [-1, 1]:
				mb.box("p", paint, Vector3(s * 0.35, s * 0.2, 0.02), MB.T(at + Vector3(s * 0.35 * sx, s * 0.2, s * 0.52)), dark)
			mb.box("p", paint, Vector3(s * 0.6, s * 0.12, 0.02), MB.T(at + Vector3(0, -s * 0.45, s * 0.52)), Color("8a2a2a"))
			return
		_:
			mb.box("p", paint, Vector3(s * 1.5, s * 1.6, s * 1.5), MB.T(at), face_col)
	# a face on the plain heads: two dots and a line, painted with a shaky hand
	for sx in [-1, 1]:
		mb.box("p", paint, Vector3(s * 0.22, s * 0.22, 0.01), MB.T(at + Vector3(s * 0.32 * sx, s * 0.15, s * 0.76)), dark)
	if spec.get("beard", false):
		mb.box("p", paint, Vector3(s * 1.3, s * 1.0, s * 0.4), MB.T(at + Vector3(0, -s * 0.8, s * 0.6)), Color("8a5a2a"))
	if spec.get("ears", false):
		for sx in [-1, 1]:
			mb.box("p", paint, Vector3(s * 0.7, s * 0.25, 0.03), MB.T(at + Vector3(s * 1.0 * sx, s * 0.2, 0), Vector3(0, 0, 0.5 * sx)), skin)

static func _weapon(mb: MB, paint: Material, kind: String, at: Vector3, acc: Color) -> void:
	var steel := Color("b8b8b0")
	var wood := Color("6a4a2a")
	match kind:
		"sword":
			mb.box("p", paint, Vector3(0.035, 0.42, 0.015), MB.T(at + Vector3(0, 0.2, 0.04)), steel)
			mb.box("p", paint, Vector3(0.12, 0.025, 0.03), MB.T(at + Vector3(0, 0.0, 0.04)), Color("b08a3a"))
		"knife":
			mb.box("p", paint, Vector3(0.03, 0.18, 0.012), MB.T(at + Vector3(0, 0.08, 0.04)), steel)
		"spear", "lance":
			var l := 1.1 if kind == "lance" else 0.85
			mb.box("p", paint, Vector3(0.025, l, 0.025), MB.T(at + Vector3(0, l * 0.35, 0.05), Vector3(0.25 if kind == "lance" else 0.0, 0, 0)), wood)
			mb.cyl("p", paint, 0.035, 0.0, 0.14, 4, MB.T(at + Vector3(0, l * 0.8, 0.05 + (0.22 if kind == "lance" else 0.0)), Vector3(0.25 if kind == "lance" else 0.0, 0, 0)), steel)
		"staff":
			mb.box("p", paint, Vector3(0.03, 0.95, 0.03), MB.T(at + Vector3(0, 0.25, 0.04)), wood)
			mb.sphere("p", paint, 0.05, 2, 5, MB.T(at + Vector3(0, 0.74, 0.04)), acc.lightened(0.3))
		"bow":
			for i in range(5):
				var a := -0.9 + i * 0.45
				mb.box("p", paint, Vector3(0.02, 0.15, 0.02), MB.T(at + Vector3(0, sin(a) * 0.32, 0.06 + cos(a) * 0.1), Vector3(-a, 0, 0)), wood)
		"crossbow":
			mb.box("p", paint, Vector3(0.04, 0.04, 0.26), MB.T(at + Vector3(0, 0.05, 0.1)), wood)
			mb.box("p", paint, Vector3(0.26, 0.03, 0.03), MB.T(at + Vector3(0, 0.05, 0.2)), steel)
		"shield":
			mb.box("p", paint, Vector3(0.04, 0.3, 0.24), MB.T(at + Vector3(-0.03, 0.06, 0.04)), acc)
			mb.box("p", paint, Vector3(0.045, 0.06, 0.06), MB.T(at + Vector3(-0.04, 0.06, 0.04)), Color("b08a3a"))
		"axe":
			mb.box("p", paint, Vector3(0.03, 0.62, 0.03), MB.T(at + Vector3(0, 0.22, 0.05)), wood)
			mb.box("p", paint, Vector3(0.02, 0.16, 0.16), MB.T(at + Vector3(0, 0.46, 0.13)), steel)
		"mace":
			mb.box("p", paint, Vector3(0.03, 0.36, 0.03), MB.T(at + Vector3(0, 0.15, 0.04)), wood)
			mb.sphere("p", paint, 0.06, 2, 5, MB.T(at + Vector3(0, 0.34, 0.04)), steel)
		"lute":
			mb.sphere("p", paint, 0.1, 2, 6, MB.T(at + Vector3(-0.08, 0.05, 0.12), Vector3.ZERO, Vector3(1, 1.3, 0.5)), wood)
			mb.box("p", paint, Vector3(0.025, 0.25, 0.02), MB.T(at + Vector3(-0.02, 0.25, 0.12), Vector3(0, 0, -0.4)), wood.darkened(0.3))
		"tome":
			mb.box("p", paint, Vector3(0.14, 0.18, 0.05), MB.T(at + Vector3(-0.02, 0.08, 0.08)), Color("2a4a2a"))
		"symbol":
			mb.box("p", paint, Vector3(0.025, 0.14, 0.02), MB.T(at + Vector3(0, 0.1, 0.08)), Color("e8c860"))
			mb.box("p", paint, Vector3(0.09, 0.025, 0.02), MB.T(at + Vector3(0, 0.13, 0.08)), Color("e8c860"))
		"hook":
			mb.box("p", paint, Vector3(0.025, 0.3, 0.025), MB.T(at + Vector3(0, 0.12, 0.05)), wood)
			mb.box("p", paint, Vector3(0.025, 0.025, 0.1), MB.T(at + Vector3(0, 0.28, 0.09)), steel)
		"gun":
			mb.box("p", paint, Vector3(0.05, 0.06, 0.3), MB.T(at + Vector3(0, 0.05, 0.14)), Color("3a3a36"))
			mb.cyl("p", paint, 0.025, 0.025, 0.14, 5, MB.T(at + Vector3(0, 0.05, 0.3), Vector3(PI / 2, 0, 0)), steel)
		"hammer", "wrench":
			mb.box("p", paint, Vector3(0.03, 0.4, 0.03), MB.T(at + Vector3(0, 0.16, 0.05)), wood if kind == "hammer" else steel)
			mb.box("p", paint, Vector3(0.14, 0.07, 0.07), MB.T(at + Vector3(0, 0.36, 0.05)), steel)
		"scythe":
			mb.box("p", paint, Vector3(0.025, 0.9, 0.025), MB.T(at + Vector3(0, 0.3, 0.05)), wood)
			mb.box("p", paint, Vector3(0.02, 0.05, 0.3), MB.T(at + Vector3(0, 0.74, 0.18), Vector3(-0.3, 0, 0)), steel)
		"pencil":
			mb.cyl("p", paint, 0.035, 0.035, 0.6, 6, MB.T(at + Vector3(0, -0.05, 0.05)), Color("e8b830"))
			mb.cyl("p", paint, 0.035, 0.0, 0.1, 6, MB.T(at + Vector3(0, 0.55, 0.05)), Color("2a2a2a"))
