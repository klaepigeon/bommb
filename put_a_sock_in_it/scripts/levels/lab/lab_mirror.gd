extends Level
## The Lab: MIRROR (docs/LAB.md). An experiment: a small bathroom with a mirror over the sink.
## The mirror is a second camera, reflected across the glass, rendered into a texture the glass
## shows. Render layers decide who's where:
##   layer 1   the room (both cameras)
##   layer 2   the mirror and the wall it hangs on (the main camera only: the reflected camera
##             stands behind that wall and looks through it)
##   layer 3   the one in the mirror (the reflected camera only: not in the room)
##   layer 4   Kurt and what's on him (the main camera only: he has no reflection)
## Each time he looks away from the glass, the one in the mirror comes a step nearer to where
## he's standing. When it's right behind him and he looks, a breath at his neck; the next time
## he looks away, it's back by the far wall. No flash, no sting: it's just nearer.

const W := 3.2
const D := 4.4
const H := 2.6
const MZ := -2.2                # the glass's plane (z)
const L_MIRROR := 2
const L_GHOST := 4
const L_KURT := 8
var mirror_cam: Camera3D
var _vp: SubViewport
var _glass: MeshInstance3D
var ghost: FleshBody
var steps := 0                  # how many times it's come nearer (the test reads this)
var _was_looking := false
var _close_seen := false
const START := Vector3(0.9, 0, 1.8)

func build() -> void:
	add_to_group("level")
	var e := env.environment
	e.ambient_light_color = Color("3c4040"); e.ambient_light_energy = 0.6
	e.fog_density = 0.02
	var tiles := Tex.mat("tiles", 2.5)
	var floor_m := Tex.mat("metlakh", 1.5)
	Build.box(world, Vector3(0, -0.05, 0), Vector3(W, 0.1, D), floor_m)
	Build.box(world, Vector3(0, H + 0.05, 0), Vector3(W, 0.1, D), Tex.mat("plaster", 1.0, {"tint": Color(0.7, 0.7, 0.66)}))
	for s in [-1, 1]: Build.box(world, Vector3(s * (W * 0.5 + 0.1), H * 0.5, 0), Vector3(0.2, H, D + 0.4), tiles)
	Build.box(world, Vector3(0, H * 0.5, D * 0.5 + 0.1), Vector3(W + 0.4, H, 0.2), tiles)
	# the wall with the glass on it: only he sees it (the reflection sees through it)
	var back := Build.box(world, Vector3(0, H * 0.5, MZ - 0.1), Vector3(W + 0.4, H, 0.2), tiles)
	back.layers = L_MIRROR
	# a sink under it, a bath along the side, a door that goes back
	Build.box(world, Vector3(0, 0.82, MZ + 0.28), Vector3(0.6, 0.12, 0.45), Tex.mat("enamel", 1.0))
	Build.box(world, Vector3(0, 0.4, MZ + 0.2), Vector3(0.14, 0.8, 0.14), Tex.mat("enamel", 1.0))
	Build.box(world, Vector3(-W * 0.5 + 0.38, 0.28, 0.2), Vector3(0.72, 0.56, 1.6), Tex.mat("enamel", 1.0))
	Build.box(world, Vector3(0, 2.0, MZ + 0.07), Vector3(1.2, 0.1, 0.12), Tex.mat("metal", 1.0), false)
	LabKit.lamp(world, Vector3(0, H - 0.2, 0.2), Color("e8ecd8"), 1.1, 6.0)
	LabKit.portal(world, Vector3(0.6, 0, D * 0.5 - 0.02), PI, "LAB", "lab")
	_mirror()
	_ghost()
	player.position = Vector3(0, 0, 0.4)
	player.set_view(0.0, -0.05)
	socko.visible = true
	_hide_kurt.call_deferred()

## The glass: a quad that shows the reflected camera's picture, sampled where on screen the
## glass is (and flipped left for right, which is what a mirror does).
func _mirror() -> void:
	_vp = SubViewport.new(); _vp.own_world_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = _screen_size()
	add_child(_vp)
	mirror_cam = Camera3D.new(); mirror_cam.near = 0.05; mirror_cam.far = 30.0
	mirror_cam.cull_mask = 0xFFFFF & ~L_MIRROR & ~L_KURT
	mirror_cam.environment = env.environment
	_vp.add_child(mirror_cam); mirror_cam.current = true
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D view : source_color, filter_nearest;
void fragment() {
	vec3 c = texture(view, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)).rgb;
	ALBEDO = c * vec3(0.86, 0.9, 0.88);
}"""
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("view", _vp.get_texture())
	_glass = MeshInstance3D.new(); _glass.name = "Glass"
	var q := QuadMesh.new(); q.size = Vector2(1.1, 0.85); _glass.mesh = q
	_glass.material_override = m
	_glass.layers = L_MIRROR
	world.add_child(_glass); _glass.position = Vector3(0, 1.5, MZ + 0.005)
	Build.box(world, Vector3(0, 1.5, MZ - 0.004), Vector3(1.2, 0.95, 0.01), Tex.mat("metal", 1.0), false).layers = L_MIRROR
	player.cam.cull_mask = player.cam.cull_mask & ~L_GHOST
	RenderingServer.frame_pre_draw.connect(_reflect)

func _screen_size() -> Vector2i:
	var s := get_viewport().get_visible_rect().size
	return Vector2i(maxi(64, int(s.x)), maxi(64, int(s.y)))

## The reflected camera: his camera mirrored across the glass's plane. A reflection turns the
## basis inside out (det -1), so its x is flipped back here, and the glass flips the picture.
func _reflect() -> void:
	if not is_instance_valid(player) or not is_inside_tree(): return
	var c := player.cam.global_transform
	var mz := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	var b := mz * c.basis
	b.x = -b.x
	var o := c.origin; o.z = 2.0 * MZ - o.z
	mirror_cam.global_transform = Transform3D(b, o)
	mirror_cam.fov = player.cam.fov
	var want := _screen_size()
	if _vp.size != want: _vp.size = want

## Kurt and what's on him on a layer the reflected camera doesn't draw: he isn't in it.
func _hide_kurt() -> void:
	for root in [player, socko]:
		for v in (root as Node).find_children("*", "VisualInstance3D", true, false):
			if v is Light3D: continue
			(v as VisualInstance3D).layers = L_KURT

func _ghost() -> void:
	ghost = FleshBody.new({"model": "laundress", "height": 1.9, "speaker": "mirror"})
	world.add_child(ghost)
	ghost.position = START
	ghost.snap = 2.0
	for v in ghost.find_children("*", "VisualInstance3D", true, false): (v as VisualInstance3D).layers = L_GHOST
	ghost.pose = {"head": Vector3(-0.25, 0, 0.2), "neck": Vector3(-0.15, 0, 0), "sh_l": Vector3(0, 0, -0.15), "sh_r": Vector3(0, 0, 0.15)}

func looking_at_glass() -> bool:
	var to := _glass.global_position - player.cam.global_position
	return (-player.cam.global_transform.basis.z).dot(to.normalized()) > 0.75

## He looked away: it comes nearer (to just behind where he stands, never through him).
func step_nearer() -> void:
	if _close_seen:
		_close_seen = false; steps = 0
		ghost.position = START
		return
	var me := Vector3(player.global_position.x, 0, player.global_position.z)
	var behind := me + (me - Vector3(0, 0, MZ)).normalized() * 0.45
	behind.x = clampf(behind.x, -W * 0.5 + 0.3, W * 0.5 - 0.3); behind.z = clampf(behind.z, MZ + 0.4, D * 0.5 - 0.3)
	ghost.position = ghost.position.lerp(behind, 0.45) if ghost.position.distance_to(behind) > 0.4 else behind
	var face := me - ghost.position
	if face.length() > 0.05: ghost.rotation.y = atan2(-face.x, -face.z)
	steps += 1

var _hide_t := 0.0
func _process(delta: float) -> void:
	super._process(delta)
	if cutscene: return
	_hide_t -= delta
	if _hide_t <= 0.0: _hide_t = 1.0; _hide_kurt()     # (what he draws, picks up, holds: not in it either)
	var looking := looking_at_glass()
	if _was_looking and not looking: step_nearer()
	if looking and not _was_looking:
		var me := Vector3(player.global_position.x, 0, player.global_position.z)
		if ghost.position.distance_to(me) < 0.6 and not _close_seen:
			_close_seen = true
			Sfx.play("whisper", -8.0, 0.8)
			Game.fear = minf(1.0, Game.fear + 0.25)
	_was_looking = looking

func _exit_tree() -> void:
	super._exit_tree()
	if RenderingServer.frame_pre_draw.is_connected(_reflect): RenderingServer.frame_pre_draw.disconnect(_reflect)

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.6)
	hud.hint("A bathroom. Look in the mirror. Look away. Look again.", 6.0)
