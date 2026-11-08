extends Node3D
## Hand lab: Kurt's right arm on its own, for close inspection (docs/KURT.md).
##   1-0      poses (relaxed, open, flat, fist, grip, hold, point, pinch, reach, stiff_flex)
##   W / S    wrist flexion / extension        A / D   radial / ulnar deviation
##   Z / X    pronation / supination           R       reset wrist and forearm
##   V        next view (back, palm, thumb side, little-finger side, first person, three-quarter)
##   arrows   orbit        + / -   zoom        B   bones        I   idle on/off
##   P        PS1 presentation on/off (low resolution, dithered)
## Command line (after --): shots=<dir> renders every pose from several views and quits.

var arm: KurtArm
var cam: Camera3D
var yaw := 0.6
var pitch := -0.5
var dist := 0.42
var target := Vector3(0, -0.005, -0.075)
var bones_on := false
var bones_mesh: MeshInstance3D
var label: Label
var view_i := 0
const VIEWS := [   # name, yaw, pitch, dist
	["back of the hand", 0.0, -1.2, 0.36],
	["palm", 0.0, 1.25, 0.36],
	["thumb side", -1.5, -0.15, 0.36],
	["little-finger side", 1.5, -0.15, 0.36],
	["three-quarter", 0.7, -0.55, 0.40],
	["first person", 3.14, -0.35, 0.32],
]

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.16, 0.16, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.5, 0.52, 0.56); env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 1.1; key.rotation_degrees = Vector3(-50, 30, 0); key.shadow_enabled = true; add_child(key)
	var fill := DirectionalLight3D.new(); fill.light_energy = 0.35; fill.light_color = Color(0.75, 0.82, 1.0); fill.rotation_degrees = Vector3(30, -140, 0); add_child(fill)
	var rim := DirectionalLight3D.new(); rim.light_energy = 0.5; rim.rotation_degrees = Vector3(-10, 180, 0); add_child(rim)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(3, 3); floor.mesh = pm; floor.position.y = -0.25
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.3, 0.3, 0.31); floor.material_override = fmat; add_child(floor)
	arm = KurtArm.new(); arm.name = "KurtArm"; add_child(arm)
	cam = Camera3D.new(); cam.fov = 50; cam.near = 0.01; add_child(cam); cam.current = true
	bones_mesh = MeshInstance3D.new(); add_child(bones_mesh)
	label = Label.new(); label.position = Vector2(16, 12); label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	var ui := CanvasLayer.new(); ui.add_child(label); add_child(ui)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots(a.get_slice("=", 1)); return
	_view(4)

func _view(i: int) -> void:
	view_i = i % VIEWS.size()
	yaw = VIEWS[view_i][1]; pitch = VIEWS[view_i][2]; dist = VIEWS[view_i][3]

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT): yaw -= delta * 1.5
	if Input.is_key_pressed(KEY_RIGHT): yaw += delta * 1.5
	if Input.is_key_pressed(KEY_UP): pitch = clampf(pitch - delta * 1.2, -1.5, 1.5)
	if Input.is_key_pressed(KEY_DOWN): pitch = clampf(pitch + delta * 1.2, -1.5, 1.5)
	if Input.is_key_pressed(KEY_W): arm.wrist.x += delta * 60.0
	if Input.is_key_pressed(KEY_S): arm.wrist.x -= delta * 60.0
	if Input.is_key_pressed(KEY_A): arm.wrist.y -= delta * 40.0
	if Input.is_key_pressed(KEY_D): arm.wrist.y += delta * 40.0
	if Input.is_key_pressed(KEY_Z): arm.pronation += delta * 70.0
	if Input.is_key_pressed(KEY_X): arm.pronation -= delta * 70.0
	_place_cam()
	if bones_on: _draw_bones()
	label.text = "KURT FEDEROV - right arm   pose: %s   wrist %d/%d   pronation %d   idle %s   view: %s\n1-0 poses  W/S A/D wrist  Z/X pronation  R reset  V view  arrows orbit  +/- zoom  B bones  I idle  P PS1" % [arm.pose_name, arm.wrist.x, arm.wrist.y, arm.pronation, "on" if arm.idle else "off", VIEWS[view_i][0]]

func _place_cam() -> void:
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.position = target + off
	cam.look_at(target, Vector3.UP if absf(pitch) < 1.45 else Vector3.FORWARD)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var keys := KurtArm.POSES.keys()
		if e.keycode >= KEY_1 and e.keycode <= KEY_9:
			arm.pose_name = keys[mini(e.keycode - KEY_1, keys.size() - 1)]
		elif e.keycode == KEY_0:
			arm.pose_name = keys[mini(9, keys.size() - 1)]
		match e.keycode:
			KEY_V: _view(view_i + 1)
			KEY_B: bones_on = not bones_on; bones_mesh.visible = bones_on
			KEY_I: arm.idle = not arm.idle
			KEY_R: arm.wrist = Vector2.ZERO; arm.pronation = 0.0
			KEY_EQUAL, KEY_KP_ADD: dist = maxf(0.12, dist - 0.04)
			KEY_MINUS, KEY_KP_SUBTRACT: dist += 0.04

func _draw_bones() -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true; mat.albedo_color = Color(1.0, 0.85, 0.1); mat.vertex_color_use_as_albedo = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var sk := arm.skeleton
	for i in sk.get_bone_count():
		var g := sk.get_bone_global_pose(i)
		var par := sk.get_bone_parent(i)
		if par >= 0:
			im.surface_set_color(Color(1, 0.85, 0.1)); im.surface_add_vertex(sk.get_bone_global_pose(par).origin)
			im.surface_set_color(Color(1, 0.85, 0.1)); im.surface_add_vertex(g.origin)
		# each bone's axes, short: X red, Y green (along), Z blue (back of hand)
		for ax in [[g.basis.x, Color.RED], [g.basis.y, Color.GREEN], [g.basis.z, Color.BLUE]]:
			im.surface_set_color(ax[1]); im.surface_add_vertex(g.origin)
			im.surface_set_color(ax[1]); im.surface_add_vertex(g.origin + (ax[0] as Vector3) * 0.008)
	im.surface_end()
	bones_mesh.mesh = im

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	arm.idle = false
	var poses := ["relaxed", "open", "fist", "grip", "point", "pinch", "flat", "hold"]
	var views := [0, 1, 2, 4]
	for p in poses:
		arm.pose_name = p
		for k in 40: await get_tree().process_frame
		for v in views:
			_view(v); _place_cam()
			for k in 3: await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%d.png" % [p, v]))
	bones_on = true; bones_mesh.visible = true
	arm.pose_name = "relaxed"
	for k in 30: await get_tree().process_frame
	_view(4); _place_cam(); _draw_bones()
	for k in 3: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("bones.png"))
	print("hand lab shots done")
	get_tree().quit()
