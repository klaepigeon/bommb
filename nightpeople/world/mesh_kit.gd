class_name MeshKit
extends RefCounted
## Accumulates boxes and quads, grouped by material, into one ArrayMesh (one draw call per
## material per building: cheap on phones). UVs are in metres in the kit's own space, so
## textures run on continuously across pieces; the material's uv_scale sets texture size.
## Faces are cut into cells no bigger than CELL so per-vertex lighting has vertices to light.

const CELL := 1.6

## Face indices for `box(..., mats)`: one material per face, or one for all.
enum { PX, NX, PY, NY, PZ, NZ }

var _tools: Dictionary = {}     ## Material → SurfaceTool
var boxes: Array = []           ## [center: Vector3, size: Vector3] for collision

## A box. `mats` is a Material or an Array of six (PX, NX, PY, NY, PZ, NZ; null = no face).
func box(center: Vector3, size: Vector3, mats, collide := true) -> void:
	var h := size * 0.5
	var m: Array = mats if mats is Array else [mats, mats, mats, mats, mats, mats]
	var c := center
	_face(m[PX], c + Vector3(h.x, -h.y, h.z), Vector3(0, 0, -size.z), Vector3(0, size.y, 0))
	_face(m[NX], c + Vector3(-h.x, -h.y, -h.z), Vector3(0, 0, size.z), Vector3(0, size.y, 0))
	_face(m[PY], c + Vector3(-h.x, h.y, h.z), Vector3(size.x, 0, 0), Vector3(0, 0, -size.z))
	_face(m[NY], c + Vector3(-h.x, -h.y, -h.z), Vector3(size.x, 0, 0), Vector3(0, 0, size.z))
	_face(m[PZ], c + Vector3(-h.x, -h.y, h.z), Vector3(size.x, 0, 0), Vector3(0, size.y, 0))
	_face(m[NZ], c + Vector3(h.x, -h.y, -h.z), Vector3(-size.x, 0, 0), Vector3(0, size.y, 0))
	if collide:
		boxes.append([center, size])

## A single quad from `origin` spanning u and v; it faces u × v.
func quad(mat: Material, origin: Vector3, u: Vector3, v: Vector3) -> void:
	_face(mat, origin, u, v)

func _face(mat, origin: Vector3, u: Vector3, v: Vector3) -> void:
	if mat == null or u.length() < 0.001 or v.length() < 0.001:
		return
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	var st: SurfaceTool = _tools[mat]
	var n := u.cross(v).normalized()
	var nu := maxi(1, ceili(u.length() / CELL))
	var nv := maxi(1, ceili(v.length() / CELL))
	for i in nu:
		for j in nv:
			var p0 := origin + u * (float(i) / nu) + v * (float(j) / nv)
			var p1 := p0 + u / nu
			var p2 := p1 + v / nv
			var p3 := p0 + v / nv
			# Godot's front faces wind clockwise seen from the front.
			for p in [p0, p2, p1, p0, p3, p2]:
				st.set_normal(n)
				st.set_uv(_uv(p, n))
				st.add_vertex(p)

static func _uv(p: Vector3, n: Vector3) -> Vector2:
	if absf(n.y) > 0.5:
		return Vector2(p.x, p.z)
	if absf(n.x) > 0.5:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, -p.y)

## The finished mesh instance (null if nothing was added).
func build(name := "Geometry") -> MeshInstance3D:
	if _tools.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for mat in _tools:
		var st: SurfaceTool = _tools[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A StaticBody3D on the world layer with a box shape per collidable box.
func build_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	for b in boxes:
		var s := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b[1]
		s.shape = shape
		s.position = b[0]
		body.add_child(s)
	return body
