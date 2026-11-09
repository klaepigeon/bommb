extends Node3D
## The infected bench (scenes/infected_lab.tscn): a lineup of generated people to look at, one at
## a time up close, and a hunt mode to test them against a stand-in Kurt.
##
##   R            a new lineup (new seeds)            Tab   the panel
##   ← →          select one                          V     lineup / close-up / hunt
##   1-6          mode: idle, move, attack, hurt, dead, (6) sever a limb
##   drag, wheel  orbit and zoom                       WASD  in hunt: walk the stand-in Kurt
##   Space        in hunt: make a noise (they hear it)
## Command line (after --): shots=<dir> renders a review tour and quits; seed=<n> starts the
## lineup at that seed.

const COUNT := 8
var lineup: Array = []            # InfectedBody
var genomes: Array = []
var seed0 := 4700
var sel := 0
var mode := "idle"
var view := 0                     # 0 lineup, 1 close-up, 2 hunt
var cam: Camera3D
var orbit_yaw := 0.4; var orbit_pitch := 0.15; var orbit_dist := 3.0
var ui: Label
var panel: PanelContainer
var hunters: Array = []
var kurt: CharacterBody3D
var solo := false                 # only the selected one shows (close-up reviews)

func _ready() -> void:
	_room()
	cam = Camera3D.new(); cam.fov = 55.0; cam.near = 0.05; add_child(cam); cam.current = true
	var layer := CanvasLayer.new(); add_child(layer)
	ui = Label.new(); ui.position = Vector2(300, 8); ui.add_theme_font_size_override("font_size", 13)
	ui.add_theme_color_override("font_shadow_color", Color.BLACK); layer.add_child(ui)
	_panel(layer)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("seed"): seed0 = int(args.seed)
	make_lineup(seed0)
	if args.has("shots"): _shots(args.shots)

func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("15161a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("5a6070"); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var floor_m := StandardMaterial3D.new(); floor_m.albedo_color = Color("3a3229")
	var wall_m := StandardMaterial3D.new(); wall_m.albedo_color = Color("5d574b")
	for spec in [[Vector3(0, -0.05, 0), Vector3(30, 0.1, 30), floor_m], [Vector3(0, 1.5, -6), Vector3(30, 3, 0.2), wall_m],
			[Vector3(-8, 1.5, 0), Vector3(0.2, 3, 30), wall_m], [Vector3(6, 0.5, 6), Vector3(1.2, 1.0, 0.5), wall_m]]:
		var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = spec[1]; cs.shape = bs; b.add_child(cs)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = spec[1]; mi.mesh = bm; mi.material_override = spec[2]; b.add_child(mi)
		b.position = spec[0]; add_child(b)
	var key := DirectionalLight3D.new(); key.rotation = Vector3(-0.8, 0.5, 0); key.light_energy = 1.1; key.light_color = Color("ffe2b8"); add_child(key)
	var rim := OmniLight3D.new(); rim.position = Vector3(-2, 2.5, -3); rim.light_color = Color("9ab0d0"); rim.light_energy = 1.2; rim.omni_range = 10; add_child(rim)

func make_lineup(first: int) -> void:
	for b in lineup: b.queue_free()
	lineup.clear(); genomes.clear()
	seed0 = first
	for i in COUNT:
		var g := InfectedGenome.generate(first + i)
		var b := InfectedBody.new(); b.name = "Person%d" % i
		add_child(b)
		b.build(g)
		b.position = Vector3((i - (COUNT - 1) * 0.5) * 1.3, 0, 0)
		b.rotation.y = PI            # facing the camera
		lineup.append(b); genomes.append(g)
	sel = clampi(sel, 0, COUNT - 1)

func _panel(layer: CanvasLayer) -> void:
	panel = PanelContainer.new(); panel.position = Vector2(4, 4)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.05, 0.06, 0.82); panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var v := VBoxContainer.new(); panel.add_child(v)
	var rows := [["new lineup (R)", func(): make_lineup(randi() % 100000)], ["◀ select", func(): sel = (sel + COUNT - 1) % COUNT], ["select ▶", func(): sel = (sel + 1) % COUNT],
		["lineup", func(): view = 0], ["close-up", func(): view = 1], ["hunt", func(): _hunt()],
		["idle", func(): mode = "idle"], ["move", func(): mode = "move"], ["attack", func(): mode = "attack"],
		["hurt", func(): _hurt()], ["dead", func(): mode = "dead"], ["sever a limb", func(): _sever()], ["revive all", func(): make_lineup(seed0)]]
	var g := GridContainer.new(); g.columns = 3; v.add_child(g)
	for r in rows:
		var b := Button.new(); b.text = r[0]; b.add_theme_font_size_override("font_size", 11); b.pressed.connect(r[1]); g.add_child(b)

func _hurt() -> void:
	(lineup[sel] as InfectedBody).flinch(Vector3(randf_range(-1, 1), 0, -1).normalized(), 1.5)

func _sever() -> void:
	var b: InfectedBody = lineup[sel]
	var ids := []
	for l in b.genome.limbs:
		if not b.severed.has(l.id) and String(l.state) != "missing": ids.append(l.id)
	if ids.size() > 0: b.sever(ids[randi() % ids.size()])

## Hunt mode: the selected lineup's people let loose on a stand-in Kurt (a capsule with a camera).
func _hunt() -> void:
	view = 2
	if kurt == null:
		kurt = CharacterBody3D.new(); kurt.name = "StandInKurt"
		var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.75; cs.shape = cap; cs.position.y = 0.875; kurt.add_child(cs)
		var head := Camera3D.new(); head.name = "cam"; head.position.y = 1.65; head.fov = 70.0; kurt.add_child(head)
		kurt.set("cam", head)
		add_child(kurt); kurt.position = Vector3(0, 0, 5)
	for h in hunters: h.queue_free()
	hunters.clear()
	for i in 4:
		var inf := Infected.new()
		inf.setup(genomes[(sel + i) % COUNT], kurt)
		inf.position = Vector3(-4.0 + i * 2.5, 0.05, -3.0)
		add_child(inf)
		hunters.append(inf)
	for b in lineup: b.visible = false

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit_yaw -= e.relative.x * 0.01; orbit_pitch = clampf(orbit_pitch + e.relative.y * 0.01, -0.4, 1.3)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		orbit_dist = clampf(orbit_dist * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.6, 14.0)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_R: make_lineup(randi() % 100000)
			KEY_LEFT: sel = (sel + COUNT - 1) % COUNT
			KEY_RIGHT: sel = (sel + 1) % COUNT
			KEY_V: view = (view + 1) % 3; if view == 2: _hunt()
			KEY_TAB: panel.visible = not panel.visible
			KEY_1: mode = "idle"
			KEY_2: mode = "move"
			KEY_3: mode = "attack"
			KEY_4: _hurt()
			KEY_5: mode = "dead"
			KEY_6: _sever()
			KEY_SPACE: if kurt: Noises.make(get_tree(), kurt.global_position, 0.8, "impact", kurt)

var _atk := 0.0
func _process(delta: float) -> void:
	_atk = move_toward(_atk, 1.0 if mode == "attack" else 0.0, delta * 2.0)
	if view != 2:
		for i in lineup.size():
			var b: InfectedBody = lineup[i]
			b.visible = (not solo) or i == sel
			b.animate(delta, {"speed": 1.0 if mode == "move" else 0.0, "mode": mode if mode != "move" else "move", "attack": _atk,
				"look": b.to_local(cam.global_position) if i == sel else null})
	var target: Vector3
	if view == 0:
		target = Vector3(0, 0.9, 0); orbit_dist = maxf(orbit_dist, 2.0)
		cam.global_position = target + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * (orbit_dist * 2.0)
		cam.look_at(target)
	elif view == 1:
		var b: InfectedBody = lineup[sel]
		target = b.global_position + Vector3(0, 0.9 * b.s, 0)
		cam.global_position = target + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_dist
		cam.look_at(target)
	elif view == 2:
		# hunt: walk the stand-in
		var mv := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if kurt:
			if not kurt.get("locked"):
				kurt.velocity = Basis(Vector3.UP, orbit_yaw) * mv * 2.2
				kurt.move_and_slide()
			var kc: Camera3D = kurt.get_node("cam")
			kc.current = true
			kurt.rotation.y = orbit_yaw; kc.rotation.x = -orbit_pitch * 0.5
	var g: Dictionary = genomes[sel]
	var b2: InfectedBody = lineup[sel]
	ui.text = "INFECTED   seeds %d..%d   selected %d   view %s   mode %s   moves: %s\n%s" % [seed0, seed0 + COUNT - 1, sel, ["lineup", "close-up", "hunt", "fixed"][view], mode, b2.locomotion, InfectedGenome.describe(g)]
	if view == 2 and hunters.size() > 0:
		var st := []
		for h in hunters: st.append("%s:%s" % [h.body.locomotion, ["IDLE", "WANDER", "LISTEN", "SEARCH", "CHASE", "GRAB", "DEAD"][h.state]])
		ui.text += "\n" + "  ".join(st)

# ---------------------------------------------------------------- review tour
func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func _shot(dir: String, name: String) -> void:
	await _wait(2)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	ui.visible = false; panel.visible = false
	for set_i in 3:
		make_lineup(seed0 + set_i * COUNT)
		view = 0; mode = "idle"; orbit_yaw = 0.25; orbit_pitch = 0.12; orbit_dist = 3.4
		await _wait(20); await _shot(dir, "lineup_%d" % set_i)
	# one of each way of moving, up close, moving
	var found := {}
	var sd := 1
	while found.size() < 7 and sd < 4000:
		var g := InfectedGenome.generate(sd)
		if not found.has(g.locomotion): found[g.locomotion] = sd
		sd += 1
	for loc in ["walk", "limp", "skitter", "hop", "lurch", "crawl", "drag"]:
		if not found.has(loc): continue
		make_lineup(found[loc]); sel = 0; view = 1; mode = "move"; orbit_dist = 2.6; orbit_yaw = 0.7; orbit_pitch = 0.1
		solo = true
		await _wait(24); await _shot(dir, "gait_%s_%d" % [loc, found[loc]])
	# close-ups: faces and growths
	make_lineup(seed0); mode = "idle"; solo = true
	for i in 4:
		sel = i; view = 1; orbit_dist = 1.0; orbit_yaw = 0.3; orbit_pitch = 0.05
		await _wait(10)
		var b: InfectedBody = lineup[i]
		view = 3
		var hx := b.skel.global_transform * b.skel.get_bone_global_pose(b.bones.head)
		var hc := hx * Vector3(0, 0.1 * b.s, 0)
		var face_dir := -(hx.basis.z.normalized())
		cam.global_position = hc + face_dir * 0.55 + Vector3(0.18, 0.05, 0); cam.look_at(hc)
		await _wait(2); await _shot(dir, "face_%d" % i)
	# attack, death, a limb off
	solo = false; view = 1; sel = 1; orbit_dist = 2.6; mode = "attack"; await _wait(40); await _shot(dir, "attack")
	mode = "idle"; await _wait(20)
	_sever(); _sever(); mode = "move"; await _wait(60); await _shot(dir, "severed_" + (lineup[1] as InfectedBody).locomotion)
	mode = "dead"; await _wait(80); await _shot(dir, "dead")
	get_tree().quit()
