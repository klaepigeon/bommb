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
		"liv_bal": Vector3(3.5, 0, 0.35), "hall_w": Vector3(4.9, 0, 4.5), "hall_m": Vector3(6.6, 0, 4.5), "hall_e": Vector3(8.8, 0, 4.5),
		"bed": Vector3(6.4, 0, 2.6), "kit": Vector3(8.7, 0, 2.5), "child_n": Vector3(5.2, 0, 5.8), "child_s": Vector3(5.6, 0, 7.4),
		"bath_n": Vector3(8.5, 0, 5.9), "bath_s": Vector3(8.5, 0, 7.55), "bal": Vector3(2.3, -0.12, -1.0),
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
	J.call("hall_w", "hall_m"); J.call("hall_m", "hall_e")
	J.call("hall_m", "bed", d.get("dBed")); J.call("hall_e", "kit")
	J.call("hall_w", "child_n", d.get("dChild")); J.call("child_n", "child_s")
	J.call("hall_e", "bath_n", d.get("dBath")); J.call("bath_n", "bath_s")
	# the holes, into the maze's row 0
	nav.join(I["box_a"], nav.tags["maze_9_0"])
	nav.join(I["child_s"], nav.tags["maze_12_0"])
	nav.join(I["bath_s"], nav.tags["maze_14_0"])

func point(tag: String) -> Vector3:
	return nav.pts[nav.tags[tag]] if nav.tags.has(tag) else Vector3.ZERO
