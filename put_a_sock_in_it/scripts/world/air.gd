class_name Air
## The air of a room: dust that only shows in light, and visible beams (the torch, a lamp's cone,
## light coming through a gap).

## A cloud of drifting motes filling a box.
static func dust(parent: Node, centre: Vector3, extent: Vector3, count: int, color := Color(1, 0.95, 0.85)) -> MultiMeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = q
	var n := count
	if OS.has_feature("mobile"): n = count / 2
	mm.instance_count = n
	var r := RandomNumberGenerator.new(); r.seed = int(centre.x * 100 + centre.z * 7)
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(r.randf_range(-1, 1) * extent.x, r.randf_range(-1, 1) * extent.y, r.randf_range(-1, 1) * extent.z)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/dust.gdshader")
	m.set_shader_parameter("color", color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(-extent - Vector3.ONE * 0.5, extent * 2.0 + Vector3.ONE)
	parent.add_child(mi); mi.position = centre
	return mi

## A cone of light, apex at the origin pointing down -Z, `length` long, `radius` wide at the end.
static func beam(parent: Node3D, length: float, radius: float, color: Color, strength := 0.08) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 16; const RINGS := 6
	for r in RINGS:
		for s in SIDES:
			var a0 := TAU * s / SIDES; var a1 := TAU * (s + 1) / SIDES
			var k0 := float(r) / RINGS; var k1 := float(r + 1) / RINGS
			var p := [Vector3(cos(a0) * radius * k0, sin(a0) * radius * k0, -length * k0), Vector3(cos(a1) * radius * k0, sin(a1) * radius * k0, -length * k0),
				Vector3(cos(a1) * radius * k1, sin(a1) * radius * k1, -length * k1), Vector3(cos(a0) * radius * k1, sin(a0) * radius * k1, -length * k1)]
			var uv := [Vector2(float(s) / SIDES, k0), Vector2(float(s + 1) / SIDES, k0), Vector2(float(s + 1) / SIDES, k1), Vector2(float(s) / SIDES, k1)]
			var nrm := [Vector3(cos(a0), sin(a0), radius / length).normalized(), Vector3(cos(a1), sin(a1), radius / length).normalized()]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(nrm[0] if idx == 0 or idx == 3 else nrm[1]); st.set_uv(uv[idx]); st.add_vertex(p[idx])
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("color", color); m.set_shader_parameter("strength", strength)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
