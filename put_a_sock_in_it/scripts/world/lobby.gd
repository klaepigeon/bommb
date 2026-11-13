class_name Lobby
## The building's lobby, where outside was (47's balcony, once LOBBY is stuck on "outside"): the
## ground-floor entrance hall of a block like this one. Metlakh tiles; the walls green to shoulder
## height and whitewashed above; a run of tin mailboxes; a radiator under a small window; the
## double doors out, reeded glass in them; the stair going up; one bare bulb, steady.
## Built north of the balcony, its floor level with the balcony's, its south wall open to it.

const W0 := -2.6      # x extent
const W1 := 7.4
const Z0 := -1.82     # the balcony's edge (open)
const Z1 := -10.5     # the far wall, with the doors
const H := 3.3

static func build(parent: Node3D, floor_y: float) -> Node3D:
	var root := Node3D.new(); root.name = "Lobby"; parent.add_child(root)
	root.position = Vector3(0, floor_y, 0)
	var tiles := Tex.mat("metlakh", 0.8)
	var paint := Tex.mat("stairwell", 0.25)
	var white := Tex.mat("plaster", 0.6, {"tint": Color(1.05, 1.05, 1.0)})
	var conc := Tex.mat("concrete", 1.0)
	var cx := (W0 + W1) * 0.5; var cz := (Z0 + Z1) * 0.5
	var w := W1 - W0; var d := Z0 - Z1
	_box(root, Vector3(cx, -0.05, cz), Vector3(w, 0.1, d), tiles, true)                 # floor
	_box(root, Vector3(cx, H + 0.05, cz), Vector3(w, 0.1, d), white, true)              # ceiling
	# walls: green paint below 1.5 m, whitewash above, and the far wall with the doors in it
	for side in [[Vector3(W0 - 0.05, 0, cz), Vector3(0.1, 0, d)], [Vector3(W1 + 0.05, 0, cz), Vector3(0.1, 0, d)]]:
		_box(root, side[0] + Vector3(0, 0.75, 0), side[1] + Vector3(0, 1.5, 0), paint, true)
		_box(root, side[0] + Vector3(0, 1.5 + (H - 1.5) * 0.5, 0), side[1] + Vector3(0, H - 1.5, 0), white, true)
	var door_x := 1.5; var door_w := 1.6
	for seg in [[W0, door_x - door_w * 0.5], [door_x + door_w * 0.5, W1]]:
		var sx: float = (seg[0] + seg[1]) * 0.5; var sw: float = seg[1] - seg[0]
		_box(root, Vector3(sx, 0.75, Z1 - 0.05), Vector3(sw, 1.5, 0.1), paint, true)
		_box(root, Vector3(sx, 1.5 + (H - 1.5) * 0.5, Z1 - 0.05), Vector3(sw, H - 1.5, 0.1), white, true)
	_box(root, Vector3(door_x, 2.35 + (H - 2.35) * 0.5, Z1 - 0.05), Vector3(door_w, H - 2.35, 0.1), white, true)
	# a dark line of paint along the top of the green, as they always have
	for z in [Z1 + 0.003]:
		_box(root, Vector3(cx, 1.5, z), Vector3(w, 0.03, 0.006), Tex.mat("black"), false)
	# the doors out: two leaves, reeded glass in the top half, shut
	var frame := Tex.mat("paint_door", 1.0, {"tint": Color(0.5, 0.42, 0.32)})
	for s in [-1, 1]:
		var lx: float = door_x + s * door_w * 0.25
		_box(root, Vector3(lx, 1.17, Z1 + 0.02), Vector3(door_w * 0.5 - 0.02, 2.34, 0.05), frame, false)
		_box(root, Vector3(lx, 1.6, Z1 + 0.05), Vector3(door_w * 0.5 - 0.2, 0.9, 0.01), Tex.mat("glass_reeded", 2.0, {"emission": Vector3(0.35, 0.37, 0.4)}), false)
		_box(root, Vector3(door_x + s * 0.12, 1.05, Z1 + 0.07), Vector3(0.025, 0.25, 0.03), Tex.mat("brass"), false)
	var shut := StaticBody3D.new(); root.add_child(shut)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(door_w, 2.35, 0.1); cs.shape = sh; shut.add_child(cs)
	shut.position = Vector3(door_x, 1.17, Z1 + 0.02)
	# the mailboxes: three rows of tin boxes on the west wall
	var tin := Tex.mat("metal", 3.0, {"tint": Color(0.55, 0.6, 0.55)})
	for row in 3:
		for col in 9:
			var bx := _box(root, Vector3(W0 + 0.12, 1.25 + row * 0.24, -4.2 - col * 0.3), Vector3(0.16, 0.22, 0.28), tin, false)
			_box(bx, Vector3(0.081, 0.05, 0), Vector3(0.004, 0.02, 0.18), Tex.mat("black"), false)
	_box(root, Vector3(W0 + 0.12, 1.5, -5.4), Vector3(0.18, 0.8, 2.75), Tex.mat("black"), true).visible = false   # (their collision)
	# a radiator under a small high window on the east wall
	_box(root, Vector3(W1 - 0.08, 0.55, -6.5), Vector3(0.1, 0.6, 1.0), Tex.mat("enamel", 3.0, {"tint": Color(0.75, 0.72, 0.65)}), true)
	_box(root, Vector3(W1 - 0.02, 2.4, -6.5), Vector3(0.02, 0.6, 0.9), Tex.mat("glass_reeded", 2.0, {"emission": Vector3(0.25, 0.27, 0.32)}), false)
	# the stair going up, along the east wall, toward the back
	for i in 10:
		var hgt := (i + 1) * 0.16
		_box(root, Vector3(W1 - 0.65, hgt * 0.5, -2.6 - i * 0.28), Vector3(1.2, hgt, 0.28), conc, true)
	# the rail, on posts, rising with the steps
	var rail := _box(root, Vector3(W1 - 1.25, 0.8 + 0.9, -3.86), Vector3(0.04, 0.04, 3.3), Tex.mat("wood", 6.0, {"tint": Color(0.5, 0.33, 0.22)}), false)
	rail.rotation.x = 0.52
	for i in [0, 4, 8]:
		var top: float = (i + 1) * 0.16
		_box(root, Vector3(W1 - 1.25, top + 0.45, -2.6 - i * 0.28), Vector3(0.025, 0.9, 0.025), Tex.mat("gunmetal"), false)
	# a landing at the top, and the way on up: dark
	_box(root, Vector3(W1 - 0.65, 0.8, -5.9), Vector3(1.2, 1.6, 1.3), conc, true)
	_box(root, Vector3(W1 - 0.012, 1.6 + 1.0, -5.9), Vector3(0.02, 2.0, 1.0), Tex.mat("black"), false)
	# one bulb, steady, and the cold coming through the glass
	var bulb := OmniLight3D.new(); bulb.light_color = Color("ffd9a0"); bulb.light_energy = 1.4; bulb.omni_range = 9.0
	bulb.shadow_enabled = false; root.add_child(bulb); bulb.position = Vector3(cx, H - 0.4, cz)
	_box(root, Vector3(cx, H - 0.3, cz), Vector3(0.05, 0.07, 0.05), Tex.mat("enamel", 1.0, {"emission": Vector3(1.4, 1.2, 0.8)}), false)
	_box(root, Vector3(cx, H - 0.12, cz), Vector3(0.01, 0.24, 0.01), Tex.mat("black"), false)
	var cold := OmniLight3D.new(); cold.light_color = Color("aab8d0"); cold.light_energy = 0.5; cold.omni_range = 4.0
	cold.shadow_enabled = false; root.add_child(cold); cold.position = Vector3(door_x, 1.6, Z1 + 1.0)
	return root

static func _box(parent: Node3D, at: Vector3, size: Vector3, m: Material, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size); mi.material_override = m; mi.position = at
	parent.add_child(mi)
	if solid:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
		sb.add_child(cs); mi.add_child(sb)
		sb.set_meta("surface", "tile")
	return mi
