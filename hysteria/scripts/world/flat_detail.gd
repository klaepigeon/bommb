class_name FlatDetail
## Flat 47's joinery and plaster, modelled: what the exported rooms didn't have, where walls meet
## the floor and the ceiling. Skirting boards along every wall (stopping at every doorway and
## opening), a moulded coving under every ceiling, a ceiling rose over every hanging lamp, a
## picture rail in the living room. Built the way the town is (TownKit: merged by 8 m chunk and
## material, the small mouldings only drawn near), and parented to the apartment so it hides and
## shows with it.
##
## Where the walls are is found, not assumed: rays along each room's edges at skirting height and
## at coving height hit the room's wall or go through an opening. Door leaves and loose things
## don't count.

const SKIRT_H := 0.12
const STEP := 0.05

static func build(world: Node3D, rooms: Dictionary, lights: Array) -> int:
	var apt: Node3D = world.get_node("Apartment")
	var kit := TownKit.new(apt)
	var space := world.get_world_3d().direct_space_state
	var n := 0
	for id in rooms:
		var r: Dictionary = rooms[id]
		var ceil_y := _ceiling(space, Vector3((r.x0 + r.x1) * 0.5, 1.2, (r.z0 + r.z1) * 0.5))
		# each edge: its inward normal and the line it runs along
		var edges := [
			[Vector3(r.x0, 0, r.z0), Vector3(r.x1, 0, r.z0), Vector3(0, 0, 1)],
			[Vector3(r.x1, 0, r.z1), Vector3(r.x0, 0, r.z1), Vector3(0, 0, -1)],
			[Vector3(r.x0, 0, r.z1), Vector3(r.x0, 0, r.z0), Vector3(1, 0, 0)],
			[Vector3(r.x1, 0, r.z0), Vector3(r.x1, 0, r.z1), Vector3(-1, 0, 0)],
		]
		for e in edges:
			var a: Vector3 = e[0]; var b: Vector3 = e[1]; var inward: Vector3 = e[2]
			for seg in _runs(space, a, b, inward, 0.06):
				_skirting(kit, seg[0], seg[1], inward)
				n += 1
			for seg in _runs(space, a, b, inward, ceil_y - 0.06):
				_coving(kit, seg[0], seg[1], inward, ceil_y)
				if id == "living":
					_rail(kit, seg[0], seg[1], inward, ceil_y - 0.42)
				n += 1
	# ceiling roses over the hanging lamps
	for L in lights:
		var p: Array = L.get("pos", [0, 0, 0])
		if String(L.get("type", "")) == "PointLight" and float(p[1]) > 1.9:
			var at := Vector3(p[0], 0, p[2])
			var cy := _ceiling(space, Vector3(at.x, 1.2, at.z))
			if cy - float(p[1]) < 1.2:
				_rose(kit, Vector3(at.x, cy, at.z))
	kit.finish()
	return n

## Height of the ceiling over a point (a ray straight up).
static func _ceiling(space: PhysicsDirectSpaceState3D, from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 4, 0))
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else 2.7

## Stretches of an edge where there's wall: sample every STEP from inside the room toward the
## edge, at height y; a hit on a static wall within a few cm of the edge is wall.
static func _runs(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, inward: Vector3, y: float) -> Array:
	var out := []
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var start := -1.0
	var t := 0.04
	while t <= len - 0.04 + 0.0001:
		var p := a + dir * t + Vector3(0, y, 0)
		var wall := _is_wall(space, p + inward * 0.35, p - inward * 0.12)
		if wall and start < 0.0: start = t
		if not wall and start >= 0.0:
			if t - start > 0.12: out.append([a + dir * start, a + dir * (t - STEP * 0.5)])
			start = -1.0
		t += STEP
	if start >= 0.0 and len - start > 0.12: out.append([a + dir * start, b - dir * 0.0])
	# each run's ends pulled onto the wall's face: the ray told us where it is
	var faced := []
	for sg in out:
		var f0 := _face(space, sg[0], inward, y); var f1 := _face(space, sg[1], inward, y)
		faced.append([f0, f1])
	return faced

static func _is_wall(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var ex: Array[RID] = []
	for i in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to); q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit: return false
		var c: Object = hit.collider
		if c is StaticBody3D and not c is AnimatableBody3D and not (c as Node).has_method("interact") and not (c as Node).has_method("prompt"):
			return true
		ex.append(hit.rid)
	return false

## where the wall's face actually is, along the inward normal, near an edge point
static func _face(space: PhysicsDirectSpaceState3D, p: Vector3, inward: Vector3, y: float) -> Vector3:
	var at := Vector3(p.x, y, p.z)
	var q := PhysicsRayQueryParameters3D.create(at + inward * 0.35, at - inward * 0.12)
	var hit := space.intersect_ray(q)
	var face: Vector3 = hit.position if hit and hit.collider is StaticBody3D else at
	return Vector3(face.x, 0.0, face.z) + inward * 0.001

## a run of skirting: a plinth board with a rounded top (a stepped ovolo) and a shadow line
static func _skirting(kit: TownKit, a: Vector3, b: Vector3, inward: Vector3) -> void:
	var along := (b - a).normalized()
	var f := Facades.Frame.new(a, along, inward)
	var l := a.distance_to(b)
	Facades.bx(kit, f, "skirting", 0.0, l, 0.0, SKIRT_H - 0.03, 0.0, 0.018, 4 | 16 | 1 | 2)
	Facades.bx(kit, f, "skirting", 0.0, l, SKIRT_H - 0.03, SKIRT_H - 0.012, 0.0, 0.013, 4 | 16 | 1 | 2)
	kit.fine = true
	Facades.bx(kit, f, "skirting", 0.0, l, SKIRT_H - 0.012, SKIRT_H, 0.0, 0.007, 4 | 16 | 1 | 2)
	kit.fine = false

## a coving under the ceiling: three steps out from the wall and up to the ceiling, the
## Stalin-era plaster cornice, painted over and over
static func _coving(kit: TownKit, a: Vector3, b: Vector3, inward: Vector3, cy: float) -> void:
	var along := (b - a).normalized()
	var f := Facades.Frame.new(a, along, inward)
	var l := a.distance_to(b)
	Facades.bx(kit, f, "coving", 0.0, l, cy - 0.11, cy - 0.085, 0.0, 0.02, 4 | 8 | 16 | 1 | 2)
	Facades.bx(kit, f, "coving", 0.0, l, cy - 0.085, cy - 0.045, 0.0, 0.045, 8 | 16 | 1 | 2)
	Facades.bx(kit, f, "coving", 0.0, l, cy - 0.045, cy, 0.0, 0.085, 8 | 16 | 1 | 2)
	kit.fine = true
	Facades.bx(kit, f, "coving", 0.0, l, cy - 0.06, cy - 0.05, 0.045, 0.055, 8 | 16 | 1 | 2)
	kit.fine = false

## the living room's picture rail, where the photographs hang from
static func _rail(kit: TownKit, a: Vector3, b: Vector3, inward: Vector3, y: float) -> void:
	var f := Facades.Frame.new(a, (b - a).normalized(), inward)
	kit.fine = true
	Facades.bx(kit, f, "skirting", 0.0, a.distance_to(b), y - 0.02, y + 0.02, 0.0, 0.022, 4 | 8 | 16 | 1 | 2)
	kit.fine = false

## a ceiling rose: concentric plaster rings with a boss in the middle
static func _rose(kit: TownKit, at: Vector3) -> void:
	kit.cyl("coving", at - Vector3(0, 0.02, 0), 0.24, 0.02, 14)
	kit.cyl("coving", at - Vector3(0, 0.045, 0), 0.17, 0.025, 12)
	kit.fine = true
	for i in 12:
		var a := TAU * i / 12.0
		kit.box("coving", at + Vector3(cos(a) * 0.205, -0.03, sin(a) * 0.205), Vector3(0.025, 0.01, 0.025), Basis(Vector3.UP, -a))
	kit.fine = false
	kit.cyl("coving", at - Vector3(0, 0.08, 0), 0.06, 0.035, 8, 0.04)
