class_name Level
extends Node3D
## The place: Flat 47 and the walls behind it, as one space. Answers where something is (which
## room, what floor it's walking on) and how to get from one place to another (Nav).

var flat: Flat47
var maze: Maze
var nav := Nav.new()

func build() -> void:
	flat = Flat47.new(); flat.name = "Flat47"; add_child(flat)
	flat.build()
	maze = Maze.new(); maze.name = "Maze"; add_child(maze)
	maze.build(nav)
	_flat_nav()

func zone_of(p: Vector3) -> int:
	var z := flat.zone_of(p)
	if z >= 0: return z
	return maze.zone_of(p)

func surface_of(p: Vector3) -> String:
	if flat.zone_of(p) >= 0: return flat.surface_of(p)
	return maze.surface_of(p)

## The flat's walkable points (a few per room) and how they join: through doors, the holes, and
## the box room doorway (only once the wardrobe's out of it).
func _flat_nav() -> void:
	var P := {
		"box_a": Vector3(1.8, 0, 7.6), "box_b": Vector3(1.6, 0, 6.2), "box_door": Vector3(1.82, 0, 5.4),
		"liv_s": Vector3(1.9, 0, 4.0), "liv_c": Vector3(3.3, 0, 3.3), "liv_n": Vector3(3.7, 0, 1.0), "liv_e": Vector3(3.95, 0, 4.6),
		"liv_bal": Vector3(3.17, 0, 0.45), "hall_w": Vector3(4.9, 0, 4.5), "hall_m": Vector3(6.93, 0, 4.5), "hall_e": Vector3(9.05, 0, 4.5),
		"bed": Vector3(6.93, 0, 2.9), "kit": Vector3(8.7, 0, 2.5), "child_n": Vector3(5.68, 0, 5.9), "child_s": Vector3(5.6, 0, 7.4),
		"bath_n": Vector3(9.05, 0, 5.9), "entry": Vector3(9.65, 0, 4.6), "landing": Vector3(11.3, 0, 4.6), "landing_s": Vector3(12.0, 0, 6.5), "bath_s": Vector3(8.55, 0, 7.6), "bal": Vector3(2.3, -0.12, -1.0),
	}
	var I := {}
	for k in P: I[k] = nav.add(P[k], "flat_" + k)
	var d := flat.doors
	var J := func(a, b, door = null): nav.join(I[a], I[b], door)
	J.call("box_a", "box_b"); J.call("box_b", "box_door")
	J.call("box_door", "liv_s", flat)            # the wardrobe (the flat decides if it's in the way)
	J.call("liv_s", "liv_c"); J.call("liv_c", "liv_n"); J.call("liv_c", "liv_e"); J.call("liv_n", "liv_bal")
	J.call("liv_bal", "bal", d.get("balDoor"))
	J.call("liv_e", "hall_w", d.get("dLiving"))
	var dw := nav.add(Vector3(5.68, 0, 4.5), "flat_hall_child")
	nav.join(I["hall_w"], dw); nav.join(dw, I["hall_m"])
	J.call("hall_m", "hall_e"); J.call("hall_e", "entry")
	J.call("entry", "landing", d.get("dEntry")); J.call("landing", "landing_s")
	J.call("hall_m", "bed", d.get("dBed")); J.call("hall_e", "kit")
	nav.join(dw, I["child_n"], d.get("dChild")); J.call("child_n", "child_s")
	J.call("hall_e", "bath_n", d.get("dBath")); J.call("bath_n", "bath_s")
	# the holes, into the maze's row 0: a point in the middle of each, so nothing cuts the corner
	for h in [["box_a", Vector3(1.83, 0, 8.2), Vector3(1.83, 0, 9.05)], ["child_s", Vector3(5.6, 0, 8.2), Vector3(5.6, 0, 9.0)], ["bath_s", Vector3(8.55, 0, 8.2), Vector3(8.55, 0, 9.0)]]:
		var mid := nav.add(h[1], "hole_" + h[0])
		var out := nav.add(h[2], "hole_out_" + h[0])
		nav.join(I[h[0]], mid); nav.join(mid, out)
		var cell := maze.cell_of(h[2])
		nav.join(out, nav.tags["maze_%d_%d" % [cell.x, cell.y]])

func point(tag: String) -> Vector3:
	return nav.pts[nav.tags[tag]] if nav.tags.has(tag) else Vector3.ZERO
