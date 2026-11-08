extends Node3D
## Socko test bench (scenes/socko_test.tscn): Kurt's arm and Socko alone in a lit room, to look
## at the hand and the sock closely without playing through the flat.
##
##   V            view: first person / close-up on the head / the whole arm from the side
##   drag, wheel  orbit and zoom (close-up and side views)
##   WASD, mouse  in first person: walk and look (right mouse held), to test lag and wobble
##   1-0, -, =    emotion: neutral happy curious nervous impatient distracted disappointed
##                angry furious lying uncanny sleeping
##   Q E R T Y U I O P G H   gesture: nod shake point recoil wave cover lean_in beckon wince
##                bounce look_round  (point and lean_in go to the red marker)
##   Space        say a line (cycles through the intro lines)
##   J / K        hold: open the jaw by hand / curl into a fist (the puppeteer's hand only)
##   F            face Kurt (turn the hand back)        L  lights: lamp / torch / dark
##   B            skeleton overlay                       M  move the marker somewhere else
##   N            attend: watch the marker on his own (layer D), even as you turn away
##   X            uncanny stillness on/off               Z  beyond: let him turn past the wrist
##   C            resist: the hand drags behind the arm  ,  .  playback speed down / up
## Command line (after --): shots=<dir> renders a fixed set of views to PNGs and quits.

var cam: Camera3D
var orbit: Camera3D
var socko: Socko
var marker: MeshInstance3D
var lamp: OmniLight3D
var torch: SpotLight3D
var ui: Label
var lines_mesh: MeshInstance3D
var view := 0
var yaw := 0.0; var pitch := -0.1
var orbit_yaw := 2.4; var orbit_pitch := 0.25; var orbit_dist := 0.38
var show_bones := false
var light_mode := 0
var line_i := 0
var held_jaw := false; var held_curl := false
const LINES := ["…Hi.", "Oof. Okay. You took a knock. Don't sit up fast.", "Or do. Sure. You do you.",
	"It's me. Socko. Your hand? We're close.", "Physically.", "She's gone. Don't look at the chair, bud. Look at me.",
	"Door's that way. Let's get you out before she comes back for seconds."]
const EMO_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const EMOS := ["neutral", "happy", "curious", "nervous", "impatient", "distracted", "disappointed", "angry", "furious", "lying", "uncanny", "sleeping"]
const G_KEYS := [KEY_Q, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_G, KEY_H]

func _ready() -> void:
	_room()
	var head := Node3D.new(); head.position = Vector3(0, 1.62, 1.2); add_child(head); head.name = "Head"
	cam = Camera3D.new(); cam.fov = 72.0; cam.near = 0.04; head.add_child(cam); cam.current = true
	orbit = Camera3D.new(); orbit.fov = 50.0; orbit.near = 0.01; add_child(orbit)
	socko = Socko.new(); socko.setup(cam, null); add_child(socko)
	marker = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.08; marker.mesh = sm
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.8, 0.1, 0.1); mm.emission_enabled = true; mm.emission = Color(0.5, 0, 0)
	marker.material_override = mm; marker.position = Vector3(-1.2, 0.9, -0.6); add_child(marker)
	lines_mesh = MeshInstance3D.new(); lines_mesh.mesh = ImmediateMesh.new(); add_child(lines_mesh)
	var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.no_depth_test = true; lm.albedo_color = Color(0.2, 1, 0.4); lm.vertex_color_use_as_albedo = true
	lines_mesh.material_override = lm
	var layer := CanvasLayer.new(); add_child(layer)
	ui = Label.new(); ui.position = Vector2(12, 8); ui.add_theme_font_size_override("font_size", 14)
	ui.add_theme_color_override("font_shadow_color", Color.BLACK); layer.add_child(ui)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("shots"):
		_shots(args.shots)

func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("1c1e22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("5a6070"); env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.15
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var wall := StandardMaterial3D.new(); wall.albedo_color = Color("6d6656"); wall.roughness = 1.0
	var floor_m := StandardMaterial3D.new(); floor_m.albedo_color = Color("4a3a2c")
	for spec in [[Vector3(0, -0.05, 0), Vector3(6, 0.1, 6), floor_m], [Vector3(0, 1.4, -1.6), Vector3(6, 2.8, 0.1), wall], [Vector3(-2.2, 1.4, 0), Vector3(0.1, 2.8, 6), wall]]:
		var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = spec[1]; cs.shape = bs; b.add_child(cs)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = spec[1]; mi.mesh = bm; mi.material_override = spec[2]; b.add_child(mi)
		b.position = spec[0]; add_child(b)
	var table := MeshInstance3D.new(); var tm := BoxMesh.new(); tm.size = Vector3(1.0, 0.05, 0.7); table.mesh = tm; table.position = Vector3(-0.6, 0.75, -0.4)
	table.material_override = floor_m; add_child(table)
	lamp = OmniLight3D.new(); lamp.position = Vector3(0.4, 2.3, 0.4); lamp.light_color = Color("ffd29a"); lamp.light_energy = 2.2; lamp.omni_range = 6.0; lamp.shadow_enabled = true
	add_child(lamp)
	torch = SpotLight3D.new(); torch.light_energy = 2.4; torch.spot_range = 14.0; torch.spot_angle = 33.0; torch.light_color = Color(1, 0.886, 0.722); torch.visible = false
	add_child(torch)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and view == 0:
		yaw -= e.relative.x * 0.004; pitch = clampf(pitch - e.relative.y * 0.004, -1.4, 1.4)
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and view > 0:
		orbit_yaw -= e.relative.x * 0.01; orbit_pitch = clampf(orbit_pitch + e.relative.y * 0.01, -1.3, 1.3)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		orbit_dist = clampf(orbit_dist * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.12, 2.0)
	elif e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k in EMO_KEYS: socko.set_emotion(EMOS[EMO_KEYS.find(k)])
		elif k in G_KEYS: socko.gesture(Socko.GESTURES[G_KEYS.find(k)], marker.global_position)
		match k:
			KEY_V: view = (view + 1) % 3
			KEY_SPACE: socko.say(LINES[line_i % LINES.size()]); line_i += 1
			KEY_F: socko.pose_face = 1.0 - socko.pose_face
			KEY_B: show_bones = not show_bones
			KEY_L: light_mode = (light_mode + 1) % 3; lamp.visible = light_mode == 0; torch.visible = light_mode == 1
			KEY_M: marker.position = Vector3(randf_range(-1.8, 1.8), randf_range(0.3, 2.0), randf_range(-1.4, 1.6))
			KEY_N: socko.attend(marker.global_position, 6.0)
			KEY_X: socko.stillness = 1.0 - socko.stillness
			KEY_Z: socko.beyond = 1.0 - socko.beyond
			KEY_C: socko.resist = 1.0 - socko.resist
			KEY_COMMA: Engine.time_scale = maxf(0.1, Engine.time_scale * 0.5)
			KEY_PERIOD: Engine.time_scale = minf(2.0, Engine.time_scale * 2.0)

func _process(delta: float) -> void:
	held_jaw = Input.is_physical_key_pressed(KEY_J); held_curl = Input.is_physical_key_pressed(KEY_K)
	var head: Node3D = cam.get_parent()
	var mv := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if view == 0:
		head.position += Basis(Vector3.UP, yaw) * mv * delta * 1.4
	head.rotation = Vector3(pitch, yaw, 0)
	torch.global_transform = cam.global_transform.translated_local(Vector3(0.16, -0.18, 0.05))
	var hp := socko.rig.head_global().origin
	orbit.global_position = hp + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * (orbit_dist if view == 1 else orbit_dist * 3.2)
	orbit.look_at(hp if view == 1 else socko.rig.bone_global(SockRig.B.HAND).origin.lerp(cam.global_position, 0.3))
	cam.current = view == 0; orbit.current = view != 0
	if held_jaw: socko.rig.jaw = 1.0; socko.rig.apply_pose()
	if held_curl: socko.rig.curl = 1.0; socko.rig.apply_pose()
	_draw_bones()
	ui.text = "SOCKO TEST   view %s   emotion %s   gesture %s   %s\njaw %.2f  curl %.2f  squash %.2f  wrist (%.2f %.2f %.2f)\nstill %.0f  beyond %.0f  resist %.0f  speed x%.2f   [V B L F N X Z C , .  1-0 - =  QERTYUIOPGH  Space  J K]" % [
		["first person", "close-up", "arm"][view], socko.emotion, socko._gesture if socko._gesture != "" else "-", "talking" if socko.talking else "",
		socko.rig.jaw, socko.rig.curl, socko.rig.squash, socko.rig.wrist.x, socko.rig.wrist.y, socko.rig.wrist.z,
		socko.stillness, socko.beyond, socko.resist, Engine.time_scale]

func _draw_bones() -> void:
	var im: ImmediateMesh = lines_mesh.mesh
	im.clear_surfaces()
	if not show_bones:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var sk := socko.rig.skel
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		var a := socko.rig.bone_global(b).origin
		var to := socko.rig.bone_global(p).origin if p >= 0 else socko.rig.global_position
		im.surface_set_color(Color(0.2, 1, 0.4)); im.surface_add_vertex(to); im.surface_add_vertex(a)
		var x := socko.rig.bone_global(b)
		im.surface_set_color(Color(1, 0.3, 0.3)); im.surface_add_vertex(a); im.surface_add_vertex(a + x.basis.x.normalized() * 0.015)
		im.surface_set_color(Color(0.3, 0.5, 1)); im.surface_add_vertex(a); im.surface_add_vertex(a + x.basis.y.normalized() * 0.015)
	im.surface_end()

# ---------------------------------------------------------------- screenshot tour (for review)
func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func _shot(dir: String, name: String) -> void:
	await _wait(2)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	ui.visible = false
	await _wait(30)
	await _shot(dir, "fp_neutral")
	socko.set_emotion("happy"); socko.say(LINES[3]); await _wait(25); await _shot(dir, "fp_happy_talking")
	socko.pose_face = 1.0; await _wait(50); await _shot(dir, "fp_face_kurt")
	socko.pose_face = 0.0; socko.talking = false
	view = 1
	for spec in [["close_side_shut", 1.75, 0.15, 0.0], ["close_side_open", 1.75, 0.15, 1.0], ["close_front_open", 3.3, 0.2, 1.0], ["close_top", 2.6, 1.0, 0.3], ["close_threequarter", 2.5, 0.3, 0.55]]:
		orbit_yaw = spec[1]; orbit_pitch = spec[2]; socko.set_emotion("neutral"); await _wait(25)
		held_jaw = false; socko.rig.jaw = spec[3]; socko.rig.apply_pose(); socko.set_process(false)
		await _shot(dir, spec[0]); socko.set_process(true)
	view = 2; orbit_yaw = 1.9; orbit_pitch = 0.2
	await _wait(20); await _shot(dir, "arm_side")
	show_bones = true; await _wait(2); await _shot(dir, "arm_bones"); show_bones = false
	view = 1; orbit_yaw = 2.5; orbit_pitch = 0.3
	for e in ["happy", "nervous", "disappointed", "angry", "lying", "sleeping"]:
		socko.set_emotion(e); await _wait(45); await _shot(dir, "emo_" + e)
	socko.set_emotion("neutral")
	for g in ["point", "cover", "recoil"]:
		socko.gesture(g, marker.global_position); await _wait(22); await _shot(dir, "g_" + g)
		await _wait(80)
	get_tree().quit()
