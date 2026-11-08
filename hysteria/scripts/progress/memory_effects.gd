class_name MemoryEffects
extends Node
## What the Memory tree gives back, once bought (story bible §2c; the wording is PROPOSED). None of
## it is a number. It's Kurt knowing things he shouldn't:
##
##   Her Handwriting   letters and notes say more (Examine reads `more` when it's owned)
##   How She Moves     near Marta, a pressure in the ears that's louder the closer she is, from
##                     where she is; the first time, he says which way
##   These Streets     the chalk circle on the cobbles where the main street comes round on itself,
##                     and the first time he walks through the seam, he notices
##   Counting          now and then, a girl's voice counting, from the direction of the nursery
##
## Socko doesn't like any of it.

var main: Node
var _sense: AudioStreamPlayer3D
var _chalk: Array[Node3D] = []
var _last_x := 0.0
var _count_t := 40.0
var _sensed := false
var _wrapped := false

const COUNTS := ["…один, два, три…", "…четыре, пять, шесть…", "…семь, восемь, девять, десять. Я иду искать.", "…раз, два, три, четыре…"]
const COUNTS_EN := ["one, two, three", "four, five, six", "seven, eight, nine, ten. Ready or not", "one, two, three, four"]

func setup(p_main: Node) -> void:
	main = p_main
	_sense_audio()
	_chalk_marks()

func _process(delta: float) -> void:
	var inside: bool = main.in_labyrinth
	_how_she_moves(inside)
	_these_streets(inside)
	_counting(inside, delta)

# ---------------------------------------------------------------- How She Moves
func _sense_audio() -> void:
	_sense = AudioStreamPlayer3D.new(); _sense.name = "Sense"
	_sense.stream = _pressure(); _sense.unit_size = 6.0; _sense.max_distance = 22.0
	_sense.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_sense.volume_db = -80.0
	main.hunter.add_child(_sense); _sense.position = Vector3(0, 1.4, 0)

func _how_she_moves(inside: bool) -> void:
	var h: Node3D = main.hunter
	var on: bool = inside and Skills.owned("how_she_moves") and bool(h.get("awake")) and h.state != MartaHunter.S.DEAD
	if not on:
		if _sense.playing: _sense.stop()
		return
	if not _sense.playing: _sense.play()
	var d: float = main.player.global_position.distance_to(h.global_position)
	_sense.volume_db = lerpf(-40.0, -2.0, clampf(1.0 - (d - 2.0) / 18.0, 0.0, 1.0))
	if not _sensed and d < 16.0:
		_sensed = true
		Game.say("You know where she is. Not how. %s, the way you know where your own hand is." % _cap(_which_way(h.global_position)), 5.5)

## A low pressure, like the ears before a storm: two close sine tones beating, slow.
static func _pressure() -> AudioStreamWAV:
	const R := 22050
	var n := R * 4; var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / R
		s[i] = (sin(TAU * 46.0 * t) + sin(TAU * 46.5 * t) * 0.8 + sin(TAU * 92.25 * t) * 0.15) * 0.3
	var w := FlatEscape._wav(s, R)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
	return w

# ---------------------------------------------------------------- These Streets
## A chalk circle with a cross through it, on the cobbles of the first house of the main street,
## and on each of the copies the street is made of: it's the same mark every time you pass it.
func _chalk_marks() -> void:
	var lab: Labyrinth = main.labyrinth
	var row := -1
	for r in range(3, 7):
		if lab.is_street(1, r): row = r; break
	if row < 0: return
	var mat := StandardMaterial3D.new(); mat.albedo_texture = _chalk_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; mat.alpha_scissor_threshold = 0.4
	mat.albedo_color = Color(0.92, 0.9, 0.85); mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for off in [-Labyrinth.PERIOD * Labyrinth.CELL, 0.0, Labyrinth.PERIOD * Labyrinth.CELL]:
		var m := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.85, 0.85); m.mesh = q
		m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.name = "Chalk"
		lab.add_child(m)
		m.position = lab.center(1, row) + Vector3(off + 0.6, 0.012, 0.7)
		m.rotation = Vector3(-PI * 0.5, 0.4, 0)
		m.visible = false
		_chalk.append(m)

static func _chalk_texture() -> ImageTexture:
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = 13
	var dab := func(p: Vector2) -> void:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
				if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S and rng.randf() < 0.75:
					img.set_pixelv(q, Color(1, 1, 1, rng.randf_range(0.6, 1.0)))
	# the circle, a hand's wobble in it, not quite closed
	for i in 220:
		var a := float(i) / 220.0 * TAU * 0.96 + 0.3
		var r := 24.0 + sin(a * 3.0) * 1.2
		dab.call(Vector2(32, 32) + Vector2(cos(a), sin(a)) * r)
	# the cross, one stroke longer than the other
	for i in 60:
		var t := float(i) / 60.0
		dab.call(Vector2(14, 16).lerp(Vector2(50, 50), t))
		dab.call(Vector2(48, 13).lerp(Vector2(17, 46), t))
	return ImageTexture.create_from_image(img)

func _these_streets(inside: bool) -> void:
	var owned := Skills.owned("these_streets")
	for c in _chalk: c.visible = owned
	if not inside: return
	var x: float = main.labyrinth.to_local(main.player.global_position).x
	# the wrap moves him a whole period in a frame: that's the seam
	if owned and not _wrapped and absf(x - _last_x) > Labyrinth.PERIOD * Labyrinth.CELL * 0.5:
		_wrapped = true
		Game.say("The same chalk circle on the same cobbles. You've come round. The street goes on for ever, and it's thirteen houses long.", 6.0)
		var s = main.get("socko")
		if s and s.visible: s.call("say", "Streets are like that. Keep walking.", "lying", 0.8)
	_last_x = x

# ---------------------------------------------------------------- Counting
func _counting(inside: bool, delta: float) -> void:
	if not inside or not Skills.owned("sonya"): return
	_count_t -= delta
	if _count_t > 0.0: return
	_count_t = randf_range(45.0, 75.0)
	var r: Dictionary = Interiors.NURSERY
	var lab: Labyrinth = main.labyrinth
	var nursery := lab.to_global(Vector3((r.x0 + r.x1) * 0.5, 1.0, (r.z0 + r.z1) * 0.5))
	var p: Vector3 = lab.to_local(main.player.global_position)
	if p.x > r.x0 and p.x < r.x1 and p.z > r.z0 and p.z < r.z1:
		return      # in the room itself: nothing. She isn't there.
	var i := randi() % COUNTS.size()
	Game.say("%s, a girl's voice, counting: «%s» (%s.) It stops when you listen for it." % [_cap(_which_way(nursery)), COUNTS[i], COUNTS_EN[i]], 6.5)
	var s = main.get("socko")
	if s and s.visible:
		s.set("stillness", 1.0)
		get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(s): s.set("stillness", 0.0))

# ---------------------------------------------------------------- which way
func _which_way(at: Vector3) -> String:
	var cam: Node3D = main.player.cam
	var to := at - cam.global_position; to.y = 0.0
	var fwd := -cam.global_basis.z; fwd.y = 0.0
	var a := rad_to_deg(fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP))
	if absf(a) < 40.0: return "ahead of you"
	if absf(a) > 140.0: return "behind you"
	return "to your left" if a > 0.0 else "to your right"

static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)
