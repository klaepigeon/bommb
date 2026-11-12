class_name AoMap
## Ambient occlusion for rooms built at run time, which can't be lightmapped: a top-down map of
## where solid things meet the floor (red) and the ceiling (green), blurred, which the world
## shader reads by world XZ. Floors darken toward walls and under furniture, wall bases and the
## tops of walls darken into the corners, all without a texture per wall (docs/VISUALS.md).
##
## bake() probes the physics world on a grid (a thin box at ankle height, another just under the
## ceiling) then blurs. The levels are the same every time (the maze has a fixed seed), so
## tools/bake_ao.gd saves the maps to assets/ao/<level>.png and the game loads those; with no file
## it bakes on the spot.

const CELL := 0.1
const BLUR := 4          # cells, twice: about 0.4 m of falloff
const PATH := "res://assets/ao/%s.png"

## rect: the level's XZ extent (x, z, w, d). floor_y and ceil_y: world heights.
static func bake(world: World3D, rect: Rect2, floor_y: float, ceil_y: float) -> Image:
	var w := int(ceil(rect.size.x / CELL)); var h := int(ceil(rect.size.y / CELL))
	var space := world.direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new(); bx.size = Vector3(CELL, 0.3, CELL)
	q.shape = bx; q.collision_mask = 1 | 32
	var low := PackedFloat32Array(); low.resize(w * h)
	var high := PackedFloat32Array(); high.resize(w * h)
	for j in h:
		for i in w:
			var x := rect.position.x + (i + 0.5) * CELL; var z := rect.position.y + (j + 0.5) * CELL
			q.transform = Transform3D(Basis.IDENTITY, Vector3(x, floor_y + 0.22, z))
			low[j * w + i] = 1.0 if not space.intersect_shape(q, 1).is_empty() else 0.0
			q.transform = Transform3D(Basis.IDENTITY, Vector3(x, ceil_y - 0.22, z))
			high[j * w + i] = 1.0 if not space.intersect_shape(q, 1).is_empty() else 0.0
	for k in 2:
		low = _blur(low, w, h); high = _blur(high, w, h)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for j in h:
		for i in w:
			# occlusion as brightness: 1 open .. dark next to things. Exponential, so a thin wall (a
			# sixth of the blur window) still shades its corner properly and a thick one saturates
			var l := 1.0 - (1.0 - exp(-low[j * w + i] * 7.0)) * 0.72
			var u := 1.0 - (1.0 - exp(-high[j * w + i] * 7.0)) * 0.55
			img.set_pixel(i, j, Color(l, u, 1.0))
	return img

static func _blur(src: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array(); tmp.resize(w * h)
	var out := PackedFloat32Array(); out.resize(w * h)
	var n := float(BLUR * 2 + 1)
	for j in h:
		var acc := 0.0
		for i in range(-BLUR, BLUR + 1): acc += src[j * w + clampi(i, 0, w - 1)]
		for i in w:
			tmp[j * w + i] = acc / n
			acc += src[j * w + clampi(i + BLUR + 1, 0, w - 1)] - src[j * w + clampi(i - BLUR, 0, w - 1)]
	for i in w:
		var acc := 0.0
		for j in range(-BLUR, BLUR + 1): acc += tmp[clampi(j, 0, h - 1) * w + i]
		for j in h:
			out[j * w + i] = acc / n
			acc += tmp[clampi(j + BLUR + 1, 0, h - 1) * w + i] - tmp[clampi(j - BLUR, 0, h - 1) * w + i]
	return out

## Load the level's map (or bake it), and point every world material in `root` at it.
static func apply(root: Node, level_name: String, rect: Rect2, floor_y: float, ceil_y: float) -> Image:
	var img: Image = null
	var path := PATH % level_name
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D: img = (t as Texture2D).get_image()
	if img == null or img.get_width() != int(ceil(rect.size.x / CELL)) or img.get_height() != int(ceil(rect.size.y / CELL)):
		img = bake(root.get_world_3d(), rect, floor_y, ceil_y)
	var tex := ImageTexture.create_from_image(img)
	var seen := {}
	for mi in root.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array = []
		var gi := mi as GeometryInstance3D
		if gi.material_override: mats.append(gi.material_override)
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh:
			var m: Mesh = (mi as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var sm = (mi as MeshInstance3D).get_surface_override_material(s)
				if sm == null: sm = m.surface_get_material(s)
				if sm: mats.append(sm)
		for mat in mats:
			if seen.has(mat) or not (mat is ShaderMaterial): continue
			seen[mat] = true
			var sh := (mat as ShaderMaterial).shader
			if not sh or not ("ao_map" in sh.code): continue
			mat.set_shader_parameter("ao_map", tex)
			mat.set_shader_parameter("ao_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
			mat.set_shader_parameter("ao_floor", floor_y)
			mat.set_shader_parameter("ao_ceil", ceil_y)
			mat.set_shader_parameter("ao_on", true)
	return img

## Off again (a level without a map; materials are shared between levels).
static func clear(root: Node) -> void:
	for mi in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := mi as GeometryInstance3D
		if gi.material_override is ShaderMaterial and "ao_map" in (gi.material_override as ShaderMaterial).shader.code:
			gi.material_override.set_shader_parameter("ao_on", false)
