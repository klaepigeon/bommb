class_name HideSpot
extends Wardrobe
## A wardrobe he can get into (docs/SYSTEMS.md). Inside, he looks out through the gap between the
## doors; she can't see him. But:
##   if she saw him get in, she comes straight to it and has him out
##   if she's hunting nearby, she may stop at the doors and listen; then it's his nerve: hold
##   his breath and stay calm and she moves on, or she hears him
## Getting in and out makes a noise (the doors), so not with her right there.

signal entered(s: HideSpot)
signal left(s: HideSpot)

var occupant: Player = null
var _since := 0.0

const GAP := 0.035      # between the doors: what he sees her through

## Not the plain wardrobe's solid block: a carcass of panels he can be inside (seen from both
## sides), and two doors with a gap between them.
func _ready() -> void:
	sync_to_physics = false
	add_to_group("hide_spot")
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; cs.position.y = size.y * 0.5
	add_child(cs)
	var wood := Tex.mat("wood", 2.0, {"double": true})
	var inner := Tex.mat("wood", 3.0, {"double": true, "tint": Color(0.45, 0.38, 0.32)})
	var t := 0.02
	var hx := size.x * 0.5; var hz := size.z * 0.5
	_panel(Vector3(0, size.y * 0.5, -hz + t * 0.5), Vector3(size.x, size.y, t), inner)      # back
	_panel(Vector3(-hx + t * 0.5, size.y * 0.5, 0), Vector3(t, size.y, size.z), wood)        # sides
	_panel(Vector3(hx - t * 0.5, size.y * 0.5, 0), Vector3(t, size.y, size.z), wood)
	_panel(Vector3(0, t * 0.5 + 0.08, 0), Vector3(size.x, t, size.z), inner)                # floor, on its feet
	_panel(Vector3(0, size.y - t * 0.5, 0), Vector3(size.x, t, size.z), wood)               # top
	_panel(Vector3(0, size.y + 0.04, 0), Vector3(size.x + 0.06, 0.08, size.z + 0.06), wood)  # cornice
	_panel(Vector3(0, 0.04, 0), Vector3(size.x - 0.04, 0.08, size.z - 0.04), wood)         # plinth
	# a rail with a few coats on it, just over his head: inside reads as inside
	_panel(Vector3(0, 1.75, -0.05), Vector3(size.x - 0.06, 0.02, 0.02), Tex.mat("metal"))
	var coat := Tex.mat("fabric", 2.0, {"double": true, "tint": Color(0.45, 0.4, 0.36)})
	for x in [-0.42, 0.38]:
		_panel(Vector3(x, 1.3, -0.08), Vector3(0.36, 0.9, 0.08), coat)
	# the doors, a gap between them
	var dw := (size.x - GAP) * 0.5
	var door := Tex.mat("wood_light", 2.0, {"double": true})
	for sx in [-1, 1]:
		_panel(Vector3(sx * (GAP * 0.5 + dw * 0.5), size.y * 0.5 + 0.04, hz - 0.01), Vector3(dw, size.y - 0.1, 0.02), door)
		_panel(Vector3(sx * (GAP * 0.5 + 0.035), size.y * 0.5, hz + 0.02), Vector3(0.025, 0.12, 0.03), Tex.mat("metal"))
	_panel(Vector3(size.x * 0.25, size.y * 0.5, hz + 0.005), Vector3(size.x * 0.3, size.y * 0.5, 0.01), Tex.mat("metal", 1.0, {"tint": Color(0.7, 0.75, 0.8), "rough": 0.1}))

func _panel(at: Vector3, sz: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(sz); mi.material_override = m; mi.position = at
	add_child(mi)

func get_prompt() -> String:
	return "Get out" if occupant else "Hide in the wardrobe"

func interact(p = null) -> void:
	var pl := p as Player
	if not pl: return
	if occupant:
		var out := front()
		pl.leave_hiding(out, global_basis.z)
		occupant = null
		_doors()
		left.emit(self)
	else:
		occupant = pl
		pl.hide_in(self, eye())
		_doors()
		_since = 0.0
		Game.run.hid += 1
		entered.emit(self)

## Where he stands when he gets out (in front, on the floor).
func front() -> Vector3:
	return global_position + global_basis.z * (size.z * 0.5 + 0.45)

## His eyes inside: just behind the doors, looking out through the gap (-Z of the result is out).
func eye() -> Transform3D:
	var at := global_position + Vector3(0, 1.55, 0) + global_basis.z * (size.z * 0.5 - 0.14)
	return Transform3D(global_basis.rotated(Vector3.UP, PI), at)

func _doors() -> void:
	Sfx.play_at("door_creak", global_position + Vector3(0, 1.2, 0), -10.0, 1.4)
	Sfx.play_at("door_shut", global_position + Vector3(0, 1.2, 0), -8.0, 1.2)
	Game.make_noise(global_position, 0.22)

func _process(delta: float) -> void:
	if occupant: _since += delta

## (Marta) how long he's been in.
func time_inside() -> float:
	return _since if occupant else -1.0

## She has him out.
func drag_out() -> void:
	if not occupant: return
	var p := occupant
	occupant = null
	Sfx.play_at("door_slam", global_position + Vector3(0, 1.2, 0), 0.0, 1.1)
	p.leave_hiding(front(), global_basis.z)
	left.emit(self)
