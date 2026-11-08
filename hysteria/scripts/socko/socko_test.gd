extends Node3D
## Socko test bench (scenes/socko_test.tscn): Kurt's arm and Socko alone in a lit room, to look
## at the hand and the sock closely without playing through the flat.
##
## The panel on the left (Tab hides it) does everything: play any clip in the library, hold any
## expression, switch the emotional state (and push it with obeyed / defied), aim each eye by hand
## or run any of the eye behaviours (the sympathetic listening glance among them), test the
## pupils' inertia, deform the head by hand (squash, stretch, twist, jaw, curl, the mouth's
## corners), preview the transitions and performed dialogue, jump the camera round the head, and
## inspect the contamination layers under several lights.
##
## Keys (as before):
##   V            view: first person / close-up on the head / the whole arm from the side
##   drag, wheel  orbit and zoom (close-up and side views)
##   WASD, mouse  in first person: walk and look (right mouse held), to test lag and wobble
##   1-0, -, =    emotion: neutral happy curious nervous impatient distracted disappointed
##                angry furious lying uncanny sleeping
##   Q E R T Y U I O P G H   gesture: nod shake point recoil wave cover lean_in beckon wince
##                bounce look_round  (point and lean_in go to the red marker)
##   Space        say a line (cycles through the intro lines)
##   J / K        hold: open the jaw by hand / curl into a fist (the puppeteer's hand only)
##   F            face Kurt (turn the hand back)        L  lights: cycle the light presets
##   B            skeleton overlay                       M  move the marker somewhere else
##   N            attend: watch the marker on his own (layer D), even as you turn away
##   X            uncanny stillness on/off               Z  beyond: let him turn past the wrist
##   C            resist: the hand drags behind the arm  ,  .  playback speed down / up
##   Tab          hide / show the panel                  ;  divided attention (to the marker)
## Command line (after --): shots=<dir> renders a fixed set of views to PNGs and quits.

var cam: Camera3D
var orbit: Camera3D
var socko: Socko
var marker: MeshInstance3D
var door_marker: MeshInstance3D
var lamp: OmniLight3D
var torch: SpotLight3D
var fill: DirectionalLight3D
var env: Environment
var ui: Label
var panel: PanelContainer
var lines_mesh: MeshInstance3D
var view := 0
var preset := ""                       # head-relative camera: front, three_quarter, side, top, back, low
var yaw := 0.0; var pitch := -0.1
var orbit_yaw := 2.4; var orbit_pitch := 0.25; var orbit_dist := 0.38
var show_bones := false
var light_mode := 0
var line_i := 0
var held_jaw := false; var held_curl := false
# manual controls from the panel
var manual_pose := false
var pose := {"squash": 0.0, "stretch": 0.0, "twist": 0.0, "jaw": 0.0, "curl": 0.0, "smile_l": 0.0, "smile_r": 0.0, "wide": 0.0, "pucker": 0.0}
var manual_eyes := false
var eye_aim := [Vector2.ZERO, Vector2.ZERO]       # yaw, pitch (rad) per eye, relative to the head
var stains := {"amount": 1.0, "blood": 1.0, "mould": 1.0, "urine": 1.0}
const LINES := ["…Hi.", "Oof. Okay. You took a knock. Don't sit up fast.", "Or do. Sure. You do you.",
	"It's me. Socko. Your hand? We're close.", "Physically.", "She's gone. Don't look at the chair, bud. Look at me.",
	"Door's that way. Let's get you out before she comes back for seconds."]
## Performed dialogue (cues inline): what the bench previews.
const PERFORMED := [
	["Sympathetic (divided attention)", "Hey. Hey. I know. {divided:door} It's a lot. I'm listening, bud. {g:Head_Nod} I'm right here.", "lying", 0.8, "Talking_Sympathetic"],
	["Presenter", "Okay! Big day! {clip:Head_Tilt_Left} First lesson: {expr:wide_smile} walking!", "happy", 1.1, ""],
	["Manipulator", "You could leave it. {pause:0.9} {eyes:kurt:2.0} {expr:uncomfortable_smile:2.5} Or you could finish it.", "lying", 0.85, "Talking_Threatening"],
	["Frustrated (self-interrupt)", "No, no, the other — {interrupt}", "impatient", 1.0, "Talking_Interrupting"],
	["Angry leak", "That's fine. {expr:anger:0.6} {clip:Face_Unnatural_Stillness} {pause:1.2} {expr:forced_happiness:2.0} That's totally fine!", "angry", 1.0, ""],
	["Explaining", "Gun goes bang. {eye:L:marker:1.0} Bang is good. {clip:Head_Tilt_Right} Bang is very good.", "curious", 1.0, "Talking_Explaining"],
	["Whisper", "Don't tell her I said that.", "nervous", 0.5, ""],
	["Laughing", "Ha! Ha ha. Oh, that's good.", "happy", 1.2, "Talking_Laughing"],
]
const EMO_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const EMOS := ["neutral", "happy", "curious", "nervous", "impatient", "distracted", "disappointed", "angry", "furious", "lying", "uncanny", "sleeping"]
const G_KEYS := [KEY_Q, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_G, KEY_H]
const LIGHTS := ["lamp (warm)", "torch in his mouth", "dark", "cold strip light", "harsh daylight"]

func _ready() -> void:
	_room()
	var head := Node3D.new(); head.position = Vector3(0, 1.62, 1.2); add_child(head); head.name = "Head"
	cam = Camera3D.new(); cam.fov = 72.0; cam.near = 0.04; head.add_child(cam); cam.current = true
	orbit = Camera3D.new(); orbit.fov = 50.0; orbit.near = 0.01; add_child(orbit)
	socko = Socko.new(); socko.setup(cam, null); add_child(socko)
	socko.process_priority = -10            # he moves first; the bench's hand-held overrides come after
	socko.take_torch(torch)
	marker = _ball(Color(0.8, 0.1, 0.1), Vector3(-1.2, 0.9, -0.6))
	door_marker = _ball(Color(0.1, 0.4, 0.9), Vector3(1.6, 1.1, -1.4))
	socko.director.register_target("marker", marker)
	socko.director.register_target("door", door_marker)
	socko.director.set_agenda(door_marker)
	lines_mesh = MeshInstance3D.new(); lines_mesh.mesh = ImmediateMesh.new(); add_child(lines_mesh)
	var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.no_depth_test = true; lm.albedo_color = Color(0.2, 1, 0.4); lm.vertex_color_use_as_albedo = true
	lines_mesh.material_override = lm
	var layer := CanvasLayer.new(); add_child(layer)
	ui = Label.new(); ui.add_theme_font_size_override("font_size", 13)
	ui.add_theme_color_override("font_shadow_color", Color.BLACK)
	ui.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); ui.position = Vector2(300, 8)
	layer.add_child(ui)
	_panel(layer)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("shots"):
		_shots(args.shots)

func _ball(c: Color, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.08; m.mesh = sm
	var mm := StandardMaterial3D.new(); mm.albedo_color = c; mm.emission_enabled = true; mm.emission = c * 0.6
	m.material_override = mm; m.position = at; add_child(m)
	return m

func _room() -> void:
	env = Environment.new()
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
	fill = DirectionalLight3D.new(); fill.rotation = Vector3(-0.9, 0.6, 0); fill.visible = false; add_child(fill)

func set_light(i: int) -> void:
	light_mode = i % LIGHTS.size()
	lamp.visible = light_mode == 0
	socko.torch_on = light_mode == 1
	fill.visible = light_mode >= 3
	env.ambient_light_energy = 0.35
	match light_mode:
		2: env.ambient_light_energy = 0.12
		3: fill.light_color = Color("cfe4ff"); fill.light_energy = 1.1; env.ambient_light_color = Color("6a7a8c"); fill.rotation = Vector3(-1.3, 0.2, 0)
		4: fill.light_color = Color("fff6e0"); fill.light_energy = 2.4; env.ambient_light_color = Color("8a8070"); fill.rotation = Vector3(-0.7, 2.2, 0)
		_: env.ambient_light_color = Color("5a6070")

# ---------------------------------------------------------------- the panel
func _panel(layer: CanvasLayer) -> void:
	panel = PanelContainer.new(); panel.position = Vector2(4, 4); panel.size = Vector2(286, 0)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.05, 0.06, 0.82); panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(282, 700); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(v)
	_head(v, "ANIMATION LIBRARY (%d clips)" % SockoClips.INFO.size())
	for cat in [["idle", "Idles"], ["face", "Faces"], ["head", "Head"], ["talk", "Talking (while a line plays)"], ["comedy", "Physical comedy"], ["enter", "Entrances"], ["exit", "Exits"]]:
		var row := HBoxContainer.new(); v.add_child(row)
		var ob := OptionButton.new(); ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ob.add_theme_font_size_override("font_size", 11)
		for n in SockoClips.names(cat[0]): ob.add_item(n)
		row.add_child(ob)
		var b := Button.new(); b.text = "▶"; row.add_child(b)
		var category: String = cat[0]
		b.pressed.connect(func():
			var clip := ob.get_item_text(ob.selected)
			if category == "talk" and not socko.talking: socko.say(LINES[line_i % LINES.size()], "", 1.0, clip); line_i += 1
			elif category == "idle": socko.director.idle_lock = clip
			else: socko.director.play(clip))
	_buttons(v, [["idle: auto", func(): socko.director.idle_lock = ""], ["stop all", _stop_all]])
	_head(v, "EXPRESSION")
	var ex := []
	for e in SockoClips.EXPRESSIONS: ex.append([e.replace("_", " "), func(): socko.director.set_expression(e, 1.0, -1.0)])
	ex.append(["(state's own)", func(): socko.director.clear_expression()])
	_buttons(v, ex, 3)
	_head(v, "EMOTIONAL STATE")
	var st := []
	for s in SockoDirector.STATE_ORDER: st.append([s, func(): socko.director.set_state(s)])
	st.append(["player-driven", func(): socko.director.set_state("")])
	st.append(["obeyed +1", func(): socko.director.obeyed(1.0)]); st.append(["defied +1", func(): socko.director.defied(1.0)])
	_buttons(v, st, 3)
	_head(v, "EYES")
	_buttons(v, [["DIVIDED ATTENTION (sympathetic listening)", func(): _sympathetic_listen()]], 1)
	_buttons(v, [["divided → door", func(): socko.director.divided_attention("door")], ["examine marker", func(): socko.director.examine("marker", 3.0)],
		["sound glance", func(): socko.director.sound_glance(marker.global_position)], ["one returns first", func(): socko.director.staggered_return("marker")],
		["upward glance", func(): socko.director.upward_glance()], ["fixed, head turns", func(): socko.director.fixed_while_turning(2.0); socko.director.play("Looking_Around")],
		["converge", func(): socko.director.converge("marker", 3.0)], ["one distracted", func(): socko.director.track_and_distracted(4.0)],
		["sync snap", func(): socko.director.sync_snap("door", 1.5)], ["reset", func(): socko.director.eyes_reset()]], 2)
	var me := CheckBox.new(); me.text = "aim each eye by hand"; me.toggled.connect(func(on): manual_eyes = on); v.add_child(me)
	for i in 2:
		for axis in [["yaw", 0], ["pitch", 1]]:
			_slider(v, "%s eye %s" % [["L", "R"][i], axis[0]], -1.0, 1.0, 0.0, func(x):
				var a: Vector2 = eye_aim[i]
				if axis[1] == 0: a.x = x
				else: a.y = x
				eye_aim[i] = a)
	_slider(v, "pupil inertia", 0.0, 3.0, 1.0, func(x): socko.rig.pupil_gain = x)
	_buttons(v, [["whip head (inertia)", func(): socko.director.play("Head_Snap"); socko.director.play("Head_Shake")], ["jolt", func(): socko.director.play("Sudden_Surprise")]], 2)
	_head(v, "DEFORMATION (hand-held)")
	var mp := CheckBox.new(); mp.text = "hold pose by hand"; mp.toggled.connect(func(on): manual_pose = on); v.add_child(mp)
	for k in ["squash", "stretch", "twist", "jaw", "curl", "smile_l", "smile_r", "wide", "pucker"]:
		_slider(v, k, -1.0 if k != "jaw" else 0.0, 1.0 if k != "jaw" else 1.4, 0.0, func(x): pose[k] = x)
	_head(v, "TRANSITIONS")
	var tr := []
	for s in SockoDirector.SEQUENCES: tr.append([s.replace("_", " "), func(): socko.director.sequence(s)])
	_buttons(v, tr, 2)
	_head(v, "DIALOGUE (performed)")
	var dl := []
	for p in PERFORMED: dl.append([p[0], func(): socko.say(p[1], p[2], p[3], p[4])])
	_buttons(v, dl, 2)
	_head(v, "CAMERA")
	var cm := []
	for p in ["first person", "front", "three_quarter", "side", "top", "back", "low", "free orbit", "whole arm"]:
		cm.append([p.replace("_", " "), func(): _camera(p)])
	_buttons(v, cm, 3)
	_head(v, "MATERIAL / LIGHT")
	for k in ["amount", "blood", "mould", "urine"]:
		_slider(v, "stain " + k, 0.0, 2.0, 1.0, func(x): stains[k] = x; socko.rig.set_stains(stains.amount, stains.blood, stains.mould, stains.urine))
	var lt := []
	for i in LIGHTS.size(): lt.append([LIGHTS[i], func(): set_light(i)])
	_buttons(v, lt, 2)

func _stop_all() -> void:
	for li in 5: socko.director.stop_layer(li, 0.2)

func _head(v: VBoxContainer, t: String) -> void:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 12); l.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	v.add_child(l)

func _buttons(v: VBoxContainer, items: Array, cols := 2) -> void:
	var g := GridContainer.new(); g.columns = cols; v.add_child(g)
	for it in items:
		var b := Button.new(); b.text = it[0]; b.add_theme_font_size_override("font_size", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.clip_text = true
		b.pressed.connect(it[1]); g.add_child(b)

func _slider(v: VBoxContainer, label: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	var row := HBoxContainer.new(); v.add_child(row)
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(92, 0); l.add_theme_font_size_override("font_size", 11); row.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 0.01; s.value = val; s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb); row.add_child(s)

func _camera(p: String) -> void:
	match p:
		"first person": view = 0; preset = ""
		"free orbit": view = 1; preset = ""
		"whole arm": view = 2; preset = ""
		_: view = 1; preset = p

## The sympathetic listening: he turns to Kurt, warm, nodding, listening; one eye goes to the
## door (what he wants you to notice) and comes back. The head doesn't move for it.
func _sympathetic_listen() -> void:
	socko.pose_face = 1.0
	socko.director.perform([{"t": 0.0, "do": "clip", "name": "Talking_Sympathetic", "opts": {"layer": 2}},
		{"t": 0.0, "do": "expr", "name": "smile", "k": 0.5, "hold": 5.0}, {"t": 0.0, "do": "eye", "eye": 2, "look": "kurt", "rate": 18.0, "hold": 1.4},
		{"t": 1.3, "do": "divided", "look": "door", "hold": 0.8}, {"t": 3.6, "do": "clip", "name": "Head_Nod", "opts": {"amp": 0.5}},
		{"t": 5.0, "do": "clip", "name": "Idle_Default", "opts": {"layer": 2, "fade": 0.6}}])
	get_tree().create_timer(5.5).timeout.connect(func(): socko.director.stop_layer(2, 0.6))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and view == 0:
		yaw -= e.relative.x * 0.004; pitch = clampf(pitch - e.relative.y * 0.004, -1.4, 1.4)
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and view > 0:
		orbit_yaw -= e.relative.x * 0.01; orbit_pitch = clampf(orbit_pitch + e.relative.y * 0.01, -1.3, 1.3); preset = ""
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		orbit_dist = clampf(orbit_dist * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.12, 2.0)
	elif e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k in EMO_KEYS: socko.set_emotion(EMOS[EMO_KEYS.find(k)])
		elif k in G_KEYS: socko.gesture(Socko.GESTURES[G_KEYS.find(k)], marker.global_position)
		match k:
			KEY_V: view = (view + 1) % 3; preset = ""
			KEY_TAB: panel.visible = not panel.visible
			KEY_SEMICOLON: socko.director.divided_attention(marker)
			KEY_SPACE: socko.say(LINES[line_i % LINES.size()]); line_i += 1
			KEY_F: socko.pose_face = 1.0 - socko.pose_face
			KEY_B: show_bones = not show_bones
			KEY_L: set_light(light_mode + 1)
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
	var rig := socko.rig
	if manual_pose:
		for k in pose: rig.set(k, pose[k])
	if held_jaw: rig.jaw = 1.0
	if held_curl: rig.curl = 1.0
	if manual_pose or held_jaw or held_curl: rig.apply_pose()
	var hg := rig.head_global()
	var hp := hg.origin
	if manual_eyes:
		for i in 2:
			var a: Vector2 = eye_aim[i]
			var d := hg.basis.orthonormalized() * (Basis.from_euler(Vector3(a.y, -a.x, 0)) * Vector3(0, 0.25, -1).normalized())
			socko.director.eye_track([{"at": 0.0, "eye": i, "look": rig.eye_center(i) + d, "rate": 30.0, "hold": 0.1}])
	if preset != "":
		var b := hg.basis.orthonormalized()
		var dir: Vector3 = {"front": -b.z, "three_quarter": (-b.z + b.x).normalized(), "side": b.x, "top": (b.y * 1.0 - b.z * 0.25).normalized(),
			"back": (b.z + b.y * 0.4).normalized(), "low": (-b.z - b.y * 0.7).normalized()}[preset]
		orbit.global_position = hp + dir * orbit_dist
		orbit.look_at(hp, b.y if preset != "top" else -b.z)
	else:
		orbit.global_position = hp + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * (orbit_dist if view == 1 else orbit_dist * 3.2)
		orbit.look_at(hp if view == 1 else rig.bone_global(SockRig.B.HAND).origin.lerp(cam.global_position, 0.3))
	cam.current = view == 0; orbit.current = view != 0
	_draw_bones()
	ui.text = "SOCKO TEST   view %s%s   emotion %s   gesture %s   %s\n%s\njaw %.2f  curl %.2f  squash %.2f  stretch %.2f  twist %.2f  smile %.2f/%.2f  eye gap %.1f mm\nstill %.0f  beyond %.0f  resist %.0f  speed x%.2f  light %s   [Tab panel  V B L F N X Z C ; , .  1-0 - =  QERTYUIOPGH  Space  J K]" % [
		["first person", "close-up", "arm"][view], " (" + preset + ")" if preset != "" else "", socko.emotion, socko._gesture if socko._gesture != "" else "-", "talking" if socko.talking else "",
		socko.director.describe(), rig.jaw, rig.curl, rig.squash, rig.stretch, rig.twist, rig.smile_l, rig.smile_r, rig.eye_gap() * 1000.0,
		socko.stillness, socko.beyond, socko.resist, Engine.time_scale, LIGHTS[light_mode]]

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
	ui.visible = false; panel.visible = false
	await _wait(30)
	await _shot(dir, "fp_neutral")
	socko.set_emotion("happy"); socko.say(LINES[3]); await _wait(25); await _shot(dir, "fp_happy_talking")
	socko.pose_face = 1.0; await _wait(50); await _shot(dir, "fp_face_kurt")
	socko.pose_face = 0.0; socko.interrupt()
	view = 1
	for spec in [["close_side_shut", 1.75, 0.15, 0.0], ["close_side_open", 1.75, 0.15, 1.0], ["close_front_open", 3.3, 0.2, 1.0], ["close_top", 2.6, 1.0, 0.3], ["close_threequarter", 2.5, 0.3, 0.55]]:
		orbit_yaw = spec[1]; orbit_pitch = spec[2]; socko.set_emotion("neutral"); await _wait(25)
		held_jaw = false; socko.rig.jaw = spec[3]; socko.rig.apply_pose(); socko.set_process(false)
		await _shot(dir, spec[0]); socko.set_process(true)
	# the eyes from every side (head-relative)
	for p in ["front", "three_quarter", "side", "top", "back", "low"]:
		_camera(p); orbit_dist = 0.3; await _wait(20); await _shot(dir, "eyes_" + p)
	# deformation extremes, by hand
	manual_pose = true
	for spec in [["max_squash", {"squash": 1.0}], ["max_stretch", {"stretch": 1.0}], ["twist", {"twist": 1.0}], ["mouth_wide", {"jaw": 1.3, "wide": 1.0}],
			["smile", {"smile_l": 1.0, "smile_r": 1.0, "wide": 0.4}], ["frown", {"smile_l": -1.0, "smile_r": -1.0}], ["lopsided", {"smile_l": 1.0, "smile_r": -0.4, "pucker": 0.3}]]:
		for k in pose: pose[k] = 0.0
		for k in spec[1]: pose[k] = spec[1][k]
		_camera("three_quarter"); orbit_dist = 0.32; await _wait(6); await _shot(dir, "deform_" + spec[0])
	for k in pose: pose[k] = 0.0
	manual_pose = false
	# expressions (the director's faces, front three-quarter)
	_camera("three_quarter"); orbit_dist = 0.34
	for e in ["smile", "wide_smile", "uncomfortable_smile", "frown", "surprise", "anger", "forced_happiness", "suspicion", "panic"]:
		socko.director.set_expression(e, 1.0, -1.0); await _wait(30); await _shot(dir, "expr_" + e)
	socko.director.clear_expression()
	# independent eyes: divided attention, mid-glance
	socko.pose_face = 1.0; _camera("front"); orbit_dist = 0.3; await _wait(40)
	socko.director.divided_attention("door", 1.2)
	await _wait(35); await _shot(dir, "eyes_divided_attention")
	await _wait(80); await _shot(dir, "eyes_back_together")
	socko.pose_face = 0.0
	# contamination under each light
	_camera("low"); orbit_dist = 0.42
	for i in LIGHTS.size():
		set_light(i); await _wait(20); await _shot(dir, "stains_light%d" % i)
	set_light(0)
	socko.rig.set_stains(0.0); await _wait(4); await _shot(dir, "stains_off"); socko.rig.set_stains(1.0)
	view = 2; preset = ""; orbit_yaw = 1.9; orbit_pitch = 0.2
	await _wait(20); await _shot(dir, "arm_side")
	show_bones = true; await _wait(2); await _shot(dir, "arm_bones"); show_bones = false
	view = 1; orbit_yaw = 2.5; orbit_pitch = 0.3
	for e in ["happy", "nervous", "disappointed", "angry", "lying", "sleeping"]:
		socko.set_emotion(e); await _wait(45); await _shot(dir, "emo_" + e)
	socko.set_emotion("neutral")
	view = 0; lamp.visible = false; socko.torch_on = true; await _wait(40); await _shot(dir, "fp_mouth_torch")
	socko.say(LINES[6]); await _wait(20); await _shot(dir, "fp_mouth_torch_talking")
	socko.torch_on = false; lamp.visible = true; socko.interrupt(); view = 1
	for g in ["point", "cover", "recoil"]:
		socko.gesture(g, marker.global_position); await _wait(22); await _shot(dir, "g_" + g)
		await _wait(80)
	get_tree().quit()
