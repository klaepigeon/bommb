class_name Dread
extends Node
## The longer you stay in a room with it (the body, or what the body becomes), the more the
## colour goes out of the world, until it's black and white. It comes back slowly once you leave.
## Drives the `bw` uniform of the screen shader.

const SECONDS_TO_GREY := 75.0    # in the same room, from full colour to none
const SECONDS_TO_RECOVER := 25.0 # out of the room, from none back to full

var level := 0.0                  # 0 colour .. 1 black and white (before easing)
var together := false
var player: Node3D
var rooms: Dictionary
var screen: ShaderMaterial

func setup(p_player: Node3D, p_rooms: Dictionary, p_screen: ShaderMaterial) -> void:
	player = p_player; rooms = p_rooms; screen = p_screen

## Which room a point is in, by the flat's floor plan ("" if none: the balcony, a doorway gap).
func room_at(p: Vector3) -> String:
	for k in rooms:
		var r: Dictionary = rooms[k]
		if p.x >= r.x0 and p.x < r.x1 and p.z >= r.z0 and p.z < r.z1:
			return k
	return ""

func _process(delta: float) -> void:
	if not player:
		return
	var here := room_at(player.global_position)
	var w := 0.0
	if here != "":
		for n in get_tree().get_nodes_in_group("presence"):
			var pr := n as Presence
			if pr and pr.active and pr.is_visible_in_tree() and room_at(pr.global_position) == here:
				w = maxf(w, pr.weight)
	together = w > 0.0
	if together:
		level = minf(1.0, level + delta * w / SECONDS_TO_GREY)
	else:
		level = maxf(0.0, level - delta / SECONDS_TO_RECOVER)
	if screen:
		# slow to start, so the first seconds go unnoticed; the last of the colour goes quickly
		screen.set_shader_parameter("bw", smoothstep(0.0, 1.0, level))
