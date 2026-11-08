class_name Revolver
extends Node3D
## The revolver from the square: a Nagant M1895, the Tsar's army's sidearm, seven rounds in a
## fluted cylinder, loaded one at a time through a gate on the right. It belongs to the
## labyrinth's era; Kurt's hands know it anyway.
##
## Modelled to its real proportions (0.235 m long). Its origin is the middle of the grip, where
## Kurt's right hand holds it (KurtArm reaches for `grip_global()`); the barrel points along -Z.
## In the hand it sits low and right in view and swings a little behind the head; it fires
## where the crosshair is.
##
## Fire: [LMB] / RT / FIRE. Reload: [R] / LB / RELOAD (a round at a time, quick: his hands
## remember). Draw / put away: [Q] / D-pad up / GUN.

signal fired(hit: Dictionary)
signal emptied

const CAPACITY := 7
const RELOAD_EACH := 0.3            # seconds a round; he's fast (bible: "I didn't teach you that")
const RANGE := 40.0
const HIP := Vector3(0.15, -0.165, -0.38)

var kind := "revolver"
var capacity := CAPACITY
var loaded := CAPACITY
var spare := 7
var drawn := false
var player: Node
var cam: Camera3D
var reloading := false
var headshot_kills := false         # the skill tree's Headshot
var reload_each := RELOAD_EACH      # Quick Reload makes it quicker
var kick_scale := 1.0               # Steady Hand makes it smaller

var _kick := 0.0
var _flash: OmniLight3D
var _flash_q: MeshInstance3D
var _flash_t := 0.0
var _reload_tilt := 0.0
var _holes: Array = []

func _ready() -> void:
	_model()
	_flash = OmniLight3D.new(); _flash.light_color = Color(1.0, 0.75, 0.45); _flash.omni_range = 5.0; _flash.light_energy = 0.0
	_flash.position = Vector3(0, 0.048, -0.2); add_child(_flash)
	_flash_q = MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.09, 0.09); _flash_q.mesh = qm
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color(1.0, 0.82, 0.5)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_texture = _star(); _flash_q.material_override = fm; _flash_q.visible = false
	_flash_q.position = Vector3(0, 0.048, -0.205); add_child(_flash_q)
	ensure_inputs()

static func ensure_inputs() -> void:
	var acts := {"weapon": [KEY_Q], "reload": [KEY_R]}
	for a in acts:
		if InputMap.has_action(a): continue
		InputMap.add_action(a)
		for k in acts[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k; InputMap.action_add_event(a, ev)
	var pad := {"weapon": JOY_BUTTON_DPAD_UP, "reload": JOY_BUTTON_LEFT_SHOULDER}
	for a in pad:
		var jb := InputEventJoypadButton.new(); jb.button_index = pad[a]; InputMap.action_add_event(a, jb)

func equip(p_player: Node) -> void:
	player = p_player; cam = player.get("cam")
	if get_parent(): get_parent().remove_child(self)
	player.get_parent().add_child(self)
	top_level = true
	drawn = true
	player.set("gun", self)
	var arm = player.get("armory")
	if arm: arm.call("add", self)
	SkillEffects.apply_to_gun(self)

# ---------------------------------------------------------------- the model
func _model() -> void:
	var k := TownKit.new(self)
	# the grip: walnut cheeks either side of the frame's grip strap, raked back
	var gb := Basis(Vector3.RIGHT, 0.32)
	k.box("walnut", Vector3(0, -0.012, 0.012), Vector3(0.0145, 0.052, 0.0165), gb)
	k.box("blued", Vector3(0, -0.012, 0.012), Vector3(0.0105, 0.054, 0.0175), gb, 4 | 8 | 16 | 32)
	k.cyl_axis("blued", Vector3(-0.002, -0.064, 0.03), Vector3(0.002, -0.064, 0.03), 0.006, 8)      # lanyard ring boss
	# frame and top strap
	k.box("blued", Vector3(0, 0.038, -0.008), Vector3(0.0125, 0.018, 0.03))
	k.box("blued", Vector3(0, 0.066, -0.05), Vector3(0.007, 0.004, 0.032))
	# the cylinder: seven chambers, fluted
	var cy0 := Vector3(0, 0.045, -0.026); var cy1 := Vector3(0, 0.045, -0.066)
	k.cyl_axis("blued", cy0, cy1, 0.0195, 14)
	for i in 7:
		var a := TAU * i / 7.0
		var o := Vector3(cos(a), sin(a), 0) * 0.0195
		k.box("iron", (cy0 + cy1) * 0.5 + o * 1.01, Vector3(0.0025, 0.0025, 0.014), Basis(Vector3.BACK, a))    # flutes
	# the barrel, the front sight, the ejector rod beneath, the loading gate on the right
	k.cyl_axis("blued", Vector3(0, 0.048, -0.066), Vector3(0, 0.048, -0.18), 0.0078, 10)
	k.cyl_axis("iron", Vector3(0, 0.048, -0.179), Vector3(0, 0.048, -0.181), 0.0035, 8)                 # the bore, dark
	k.box("blued", Vector3(0, 0.0585, -0.174), Vector3(0.0012, 0.003, 0.004))
	k.cyl_axis("blued", Vector3(0, 0.035, -0.07), Vector3(0, 0.035, -0.165), 0.0028, 6)
	k.box("blued", Vector3(0.012, 0.042, -0.022), Vector3(0.002, 0.012, 0.007))
	# the hammer, cocked back a little; the trigger and its guard
	k.box("blued", Vector3(0, 0.062, 0.012), Vector3(0.004, 0.012, 0.004), Basis(Vector3.RIGHT, -0.5))
	k.box("blued", Vector3(0, 0.016, -0.006), Vector3(0.0025, 0.01, 0.0025), Basis(Vector3.RIGHT, 0.3))
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		k.box("blued", Vector3(0, 0.022 - sin(a) * 0.017, -0.006 - cos(a) * 0.018), Vector3(0.003, 0.0025, 0.004), Basis(Vector3.RIGHT, a))
	k.finish()
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).layers = 1 | 2

func grip_global() -> Transform3D:
	return global_transform

# ---------------------------------------------------------------- in the hand
func _process(delta: float) -> void:
	if not player or not cam:
		return
	visible = drawn
	if not drawn:
		return
	var want := cam.global_transform * Transform3D(Basis(), HIP)
	# a beat behind the head, as a held weight is; the kick, then back; tilted out to load
	var target := want.origin
	var pos := global_position.lerp(target, 1.0 - exp(-delta * 22.0)) if global_position.distance_to(target) < 0.5 else target
	_kick = move_toward(_kick, 0.0, delta * 4.0)
	_reload_tilt = move_toward(_reload_tilt, 1.0 if reloading else 0.0, delta * 6.0)
	# point it down the line of sight, converging on it some way off (the shot itself goes where
	# the crosshair is; the hand keeps a steady hold rather than chasing every near surface)
	var aim_at := cam.global_position - cam.global_transform.basis.z * 9.0
	var b := Basis.looking_at((aim_at - pos).normalized(), cam.global_transform.basis.y)
	b = b * Basis(Vector3.UP, 0.16) * Basis(Vector3.BACK, -0.1)      # turned so you see its length, canted a touch
	b = b * Basis(Vector3.RIGHT, _kick * 0.35) * Basis(Vector3.BACK, _reload_tilt * 0.9) * Basis(Vector3.RIGHT, _reload_tilt * 0.4)
	global_transform = Transform3D(b, pos - b.z * (-_kick * 0.03) + b.y * _reload_tilt * 0.03)
	_flash_t -= delta
	_flash.light_energy = maxf(0.0, _flash_t) * 60.0
	_flash_q.visible = _flash_t > 0.0

func _unhandled_input(e: InputEvent) -> void:
	if not player or player.get("locked"): return
	if player.get("gun") != self: return
	if e.is_action_pressed("weapon"):
		if not player.get("armory"): toggle()     # the armoury handles it when there is one
	elif drawn and e.is_action_pressed("reload"):
		reload()
	elif drawn and e.is_action_pressed("throw") and player.get("held") == null:
		fire(); get_viewport().set_input_as_handled()

func toggle() -> void:
	if reloading: return
	drawn = not drawn
	_sfx(_click(0.6))

## One round: a shot down the crosshair. Things that can be shot have `shot(point, normal,
## headshot_kills)` and return true if they took it; loose props get knocked; walls get a hole.
func fire() -> void:
	if not drawn or reloading: return
	if loaded <= 0:
		_sfx(_click(1.0)); emptied.emit(); return
	loaded -= 1
	_kick = kick_scale; _flash_t = 0.06
	player.set("shake", 0.6 * kick_scale)
	player.set("pitch", float(player.get("pitch")) + 0.025 * kick_scale)
	_sfx(_bang())
	Noises.make(get_tree(), global_position, 1.0, "gunshot", player)
	var from := cam.global_position; var to := from - cam.global_transform.basis.z * RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to); q.exclude = [player.get_rid()]; q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var c: Object = hit.collider
		var n: Node = c as Node
		var took := false
		while n:
			if n.has_method("shot"):
				took = n.call("shot", hit.position, hit.normal, headshot_kills, hit.get("shape", 0)); break
			n = n.get_parent()
		if not took:
			if c is RigidBody3D:
				(c as RigidBody3D).apply_impulse(-cam.global_transform.basis.z * 6.0, hit.position - (c as RigidBody3D).global_position)
			else:
				_hole(hit.position, hit.normal)
	fired.emit(hit)

func reload() -> void:
	if reloading or loaded >= CAPACITY or spare <= 0: return
	reloading = true
	_sfx(_click(0.7))
	await get_tree().create_timer(0.25).timeout
	while loaded < CAPACITY and spare > 0 and reloading:
		await get_tree().create_timer(reload_each).timeout
		loaded += 1; spare -= 1
		_sfx(_click(1.3))
	await get_tree().create_timer(0.2).timeout
	_sfx(_click(0.5))
	reloading = false

func _hole(at: Vector3, n: Vector3) -> void:
	var m := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.035, 0.035); m.mesh = qm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.05, 0.04, 0.04); mat.roughness = 1.0
	mat.albedo_texture = _star(); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.material_override = mat
	player.get_parent().add_child(m)
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	m.global_transform = Transform3D(Basis.looking_at(-n, up), at + n * 0.004)
	_holes.append(m)
	if _holes.size() > 40: (_holes.pop_front() as Node).queue_free()

# ---------------------------------------------------------------- sound (synthesised)
func _sfx(w: AudioStreamWAV) -> void:
	var ap := AudioStreamPlayer.new(); ap.stream = w; ap.volume_db = -2.0
	add_child(ap); ap.play(); ap.finished.connect(ap.queue_free)

static var _bang_cache: AudioStreamWAV
static func _bang() -> AudioStreamWAV:
	if _bang_cache: return _bang_cache
	const RATE := 22050
	var n := int(RATE * 1.4)
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 1895
	var lp := 0.0; var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var crack := rng.randf_range(-1, 1) * exp(-t * 60.0)
		lp += (rng.randf_range(-1, 1) - lp) * 0.12
		lp2 += (lp - lp2) * 0.05
		var body := sin(TAU * 70.0 * t * (1.0 - t * 0.6)) * exp(-t * 18.0) * 0.8
		var tail := lp2 * 3.0 * exp(-t * 3.2)            # the street throwing it back
		bytes.encode_s16(i * 2, int(clampf(crack * 0.9 + body + tail, -1.0, 1.0) * 30000.0))
	_bang_cache = AudioStreamWAV.new(); _bang_cache.format = AudioStreamWAV.FORMAT_16_BITS; _bang_cache.mix_rate = RATE; _bang_cache.data = bytes
	return _bang_cache

static func _click(pitch: float) -> AudioStreamWAV:
	const RATE := 22050
	var n := int(RATE * 0.06)
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * 2400.0 * pitch * t) * exp(-t * 140.0) + sin(TAU * 900.0 * pitch * t) * exp(-t * 80.0) * 0.5
		bytes.encode_s16(i * 2, int(s * 0.5 * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = bytes
	return w

static var _star_tex: Texture2D
static func _star() -> Texture2D:
	if _star_tex: return _star_tex
	const S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := Vector2(x - S * 0.5 + 0.5, y - S * 0.5 + 0.5)
			var a := atan2(d.y, d.x)
			var r := d.length() / (S * 0.5)
			var spike := 0.35 + 0.65 * pow(absf(cos(a * 3.0)), 6.0)
			var alpha := clampf(1.0 - r / spike, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex
