extends Level
## The Lab: THROUGH (docs/LAB.md). An experiment in impossible rooms: a small room with a doorway
## in the north wall and one in the south, and both open onto this room. Through the north one
## you see the room again, from the south door, and walking through it you come in by the south
## door. The same the other way. It's seamless: each doorway is a camera, his own moved one room
## along, drawn into the doorway (no flip: it's a window, not a mirror).
##
## And in the room through the doorway, someone is standing where he stands, doing what he did
## a second and a half ago. He never meets them: they're always one room along.
## Layers: 1 room, 2 the north wall, 3 the south wall, 4 north doorway, 5 south doorway,
## 6 the one through the door (the doorway cameras only), 7 Kurt (his own camera only).

const W := 5.0
const D := 6.0
const H := 2.7
const DW := 1.2                 # doorway width, height
const DH := 2.2
const L_N := 2
const L_S := 4
const L_QN := 8
const L_QS := 16
const L_GHOST := 32
const L_KURT := 64
var cam_n: Camera3D             # looks through the north doorway (stands one room south of him)
var cam_s: Camera3D
var _vp_n: SubViewport
var _vp_s: SubViewport
var ghost: FleshBody
var _trail: Array = []          # [time, Transform3D] of him
var crossings := 0              # (the test reads it)
const LAG := 1.5

func build() -> void:
	add_to_group("level")
	var e := env.environment
	e.ambient_light_color = Color("3a3630"); e.ambient_light_energy = 0.6
	e.fog_density = 0.035
	var wall := Tex.mat("wallpaper", 0.8)
	Build.box(world, Vector3(0, -0.05, 0), Vector3(W, 0.1, D + 2.0), Tex.mat("parquet", 2.0))     # (a little floor past each doorway, for the step through)
	Build.box(world, Vector3(0, H + 0.05, 0), Vector3(W, 0.1, D + 2.0), Tex.mat("plaster", 1.0, {"tint": Color(0.65, 0.63, 0.6)}))
	for s in [-1, 1]: Build.box(world, Vector3(s * (W * 0.5 + 0.1), H * 0.5, 0), Vector3(0.2, H, D + 2.4), wall)
	_door_wall(-D * 0.5, L_N, wall)
	_door_wall(D * 0.5, L_S, wall)
	# what makes it this room: a table, a chair, a coat on a hook, a rug
	Build.box(world, Vector3(1.2, 0.72, -0.8), Vector3(1.0, 0.06, 0.7), Tex.mat("wood", 1.0))
	for c in [Vector3(0.75, 0, -1.1), Vector3(1.65, 0, -1.1), Vector3(0.75, 0, -0.5), Vector3(1.65, 0, -0.5)]:
		Build.box(world, c + Vector3(0, 0.35, 0), Vector3(0.06, 0.7, 0.06), Tex.mat("wood", 1.0))
	Build.box(world, Vector3(-1.4, 0.45, 1.0), Vector3(0.45, 0.06, 0.45), Tex.mat("wood_light", 1.0))
	Build.box(world, Vector3(-1.4, 0.75, 1.21), Vector3(0.45, 0.6, 0.05), Tex.mat("wood_light", 1.0))
	Build.box(world, Vector3(-W * 0.5 + 0.12, 1.4, -1.6), Vector3(0.18, 1.0, 0.5), Tex.mat("fabric", 1.0), false)
	Build.box(world, Vector3(0, 0.005, 0.3), Vector3(2.2, 0.01, 1.6), Tex.mat("rug", 1.0), false)
	LabKit.lamp(world, Vector3(0, H - 0.25, 0), Color("ffd7a0"), 1.2, 7.0)
	LabKit.portal(world, Vector3(W * 0.5 - 0.02, 0, 1.6), -PI * 0.5, "LAB", "lab")
	var vs := _window(-D * 0.5, L_QN, D)
	_vp_n = vs[0]; cam_n = vs[1]
	cam_n.cull_mask = 0xFFFFF & ~L_S & ~L_QN & ~L_QS & ~L_KURT
	vs = _window(D * 0.5, L_QS, -D)
	_vp_s = vs[0]; cam_s = vs[1]
	cam_s.cull_mask = 0xFFFFF & ~L_N & ~L_QN & ~L_QS & ~L_KURT
	player.cam.cull_mask = player.cam.cull_mask & ~L_GHOST
	ghost = FleshBody.new({"model": "caretaker", "height": 1.8})
	world.add_child(ghost)
	for v in ghost.find_children("*", "VisualInstance3D", true, false): (v as VisualInstance3D).layers = L_GHOST
	RenderingServer.frame_pre_draw.connect(_cams)
	player.position = Vector3(0, 0, 1.5)
	player.set_view(0.0, 0.0)
	socko.visible = true
	_hide_kurt.call_deferred()

## A wall across the room at z with a doorway in the middle, on its own layer.
func _door_wall(z: float, layer: int, m: Material) -> void:
	var side := (W - DW) * 0.5
	for s in [-1, 1]:
		Build.box(world, Vector3(s * (DW * 0.5 + side * 0.5), H * 0.5, z), Vector3(side, H, 0.2), m).layers = layer
	Build.box(world, Vector3(0, DH + (H - DH) * 0.5, z), Vector3(DW, H - DH, 0.2), m).layers = layer
	# the frame, with its wall (the far doorway camera sees it in the copy; the near one looks past it)
	for s in [-1, 1]:
		Build.box(world, Vector3(s * (DW * 0.5 + 0.04), DH * 0.5, z), Vector3(0.08, DH, 0.26), Tex.mat("wood", 1.0), false).layers = layer
	Build.box(world, Vector3(0, DH + 0.04, z), Vector3(DW + 0.16, 0.08, 0.26), Tex.mat("wood", 1.0), false).layers = layer

## The picture in a doorway: a camera `shift` along z from his, drawn on a quad in the doorway at
## where the doorway is on screen.
func _window(z: float, layer: int, shift: float) -> Array:
	var vp := SubViewport.new(); vp.own_world_3d = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = _screen_size(); add_child(vp)
	var cam := Camera3D.new(); cam.near = 0.05; cam.far = 40.0; cam.environment = env.environment
	vp.add_child(cam); cam.current = true
	cam.set_meta("shift", shift)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D view : source_color, filter_nearest;
void fragment() { ALBEDO = texture(view, SCREEN_UV).rgb; }"""
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("view", vp.get_texture())
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(DW, DH); q.mesh = qm
	q.material_override = m; q.layers = layer
	q.name = "Doorway_N" if shift > 0.0 else "Doorway_S"
	world.add_child(q); q.position = Vector3(0, DH * 0.5, z)
	return [vp, cam]

func _screen_size() -> Vector2i:
	var s := get_viewport().get_visible_rect().size
	return Vector2i(maxi(64, int(s.x)), maxi(64, int(s.y)))

func _cams() -> void:
	if not is_instance_valid(player) or not is_inside_tree(): return
	var t := player.cam.global_transform
	var want := _screen_size()
	for pair in [[cam_n, _vp_n], [cam_s, _vp_s]]:
		var c: Camera3D = pair[0]
		c.global_transform = Transform3D(t.basis, t.origin + Vector3(0, 0, float(c.get_meta("shift"))))
		c.fov = player.cam.fov
		if (pair[1] as SubViewport).size != want: (pair[1] as SubViewport).size = want

func _hide_kurt() -> void:
	for root in [player, socko]:
		for v in (root as Node).find_children("*", "VisualInstance3D", true, false):
			if v is Light3D: continue
			(v as VisualInstance3D).layers = L_KURT

var _hide_t := 0.0
func _process(delta: float) -> void:
	super._process(delta)
	_hide_t -= delta
	if _hide_t <= 0.0: _hide_t = 1.0; _hide_kurt()
	# through a doorway: he's in the next room along, which is this one
	var z := player.global_position.z
	if z < -D * 0.5:
		player.global_position.z += D; crossings += 1; _shift_trail(D)
	elif z > D * 0.5:
		player.global_position.z -= D; crossings += 1; _shift_trail(-D)
	# the one where he was, a moment ago
	var now := Time.get_ticks_msec() * 0.001
	_trail.append([now, Transform3D(Basis(Vector3.UP, player.get_yaw()), player.global_position)])
	while _trail.size() > 2 and float(_trail[1][0]) < now - LAG: _trail.pop_front()
	var then: Transform3D = _trail[0][1]
	var was := ghost.global_position
	ghost.global_transform = then
	var sp := was.distance_to(then.origin) / maxf(delta, 0.001)
	ghost.pose = {"hip_l": Vector3(sin(now * 7.0) * 0.4 * minf(sp, 1.5), 0, 0), "hip_r": Vector3(-sin(now * 7.0) * 0.4 * minf(sp, 1.5), 0, 0),
		"kn_l": Vector3(-maxf(0.0, -sin(now * 7.0)) * 0.6 * minf(sp, 1.5), 0, 0), "kn_r": Vector3(-maxf(0.0, sin(now * 7.0)) * 0.6 * minf(sp, 1.5), 0, 0),
		"head": Vector3(-player.get_pitch() * 0.6, 0, 0)}

## (the trail moves with him, so the one behind doesn't stride across the room when he crosses)
func _shift_trail(dz: float) -> void:
	for e in _trail:
		var t: Transform3D = e[1]; t.origin.z += dz; e[1] = t

func _exit_tree() -> void:
	super._exit_tree()
	if RenderingServer.frame_pre_draw.is_connected(_cams): RenderingServer.frame_pre_draw.disconnect(_cams)

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.6)
	hud.hint("Two doorways. Both open on this room.", 6.0)
