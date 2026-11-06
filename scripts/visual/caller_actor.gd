class_name CallerActor
extends Node3D
## THE CALLER on stage: the LAST CALL figure (LcCallerFigure: plaid jacket, a bundle of
## other people's legs, a brass bingo cage of dice for a head) with MEAT PARTY's additions:
## a party hat, the hatch in his chest (from RATFORMER's hall), and a library of stiff,
## readable animations, played by name from the dialogue data (caller_lines.json).
##
## Moods (calm, pleased, displeased, intense, glitch) set his idle: how his dice watch,
## how red the eyes burn, how often he twitches. `unrest` (0..3) is how far the contestants
## have got under his skin: the more of it, the more he stutters, freezes and loses parts.

signal gesture_done(name: String)

const ANIMS := ["talk", "point", "point_up", "spread", "reach", "tap", "slam", "wag", "spin", "lean", "bow", "clap",
	"applaud", "shrug", "laugh", "dance", "glitch", "freeze", "nervous", "panic", "present_left", "present_right",
	"beckon", "conduct", "salute", "wave", "thumbs_up", "cover_eyes", "facepalm", "shush", "head_spin", "hatch",
	"countdown", "scuttle", "sob", "malfunction", "drum", "tip_hat", "look_door", "stare"]

var fig: LcCallerFigure
var hatch: Node3D
var piston: Node3D
var hat: Node3D
var mood := "calm"
var unrest := 0.0
var head_extra := Vector3.ZERO     # added on top of where the figure points his head
var body_extra := Vector3.ZERO
var _tw: Tween
var _t := 0.0
var _scuttle := 0.0
var _walk_phase := 0.0
var current := ""


func _ready() -> void:
	process_priority = 10   # after the figure has posed its head this frame
	fig = LcCallerFigure.new()
	add_child(fig)
	_build_extras()
	set_mood("calm")


func _build_extras() -> void:
	var plaid := LcMB.mat(LcTex.plaid(), Color.WHITE, Vector2(2, 2))
	var brass := LcMB.mat(LcTex.brass())
	var dark := LcMB.mat(LcTex.grime(Color("1a1612"), Color("2e2620"), 16, 4, 0.3))
	var steel := LcMB.mat(LcTex.grime(Color("6a6a62"), Color("9a9a90"), 16, 6, 0.3))
	var red := LcMB.mat(LcTex.solid(Color("a8221a")))
	# the hatch in his chest, and the mechanism behind it (RATFORMER's hall)
	var inside := LcMB.new()
	inside.box("d", dark, Vector3(0.24, 0.26, 0.01), LcMB.T(Vector3(-0.15, 0.42, 0.183)), Color(1, 1, 1))
	for k in 4:
		inside.cyl("b", brass, 0.012, 0.012, 0.2, 6, LcMB.T(Vector3(-0.23 + k * 0.05, 0.32, 0.17)), Color(1, 1, 1))
	_mesh(inside.build(), fig.torso)
	hatch = Node3D.new()
	hatch.position = Vector3(-0.27, 0.42, 0.19)
	fig.torso.add_child(hatch)
	var hb := LcMB.new()
	hb.box("p", plaid, Vector3(0.24, 0.26, 0.02), LcMB.T(Vector3(0.12, 0, 0.0)), Color(1, 1, 1))
	hb.box("b", brass, Vector3(0.02, 0.05, 0.03), LcMB.T(Vector3(0.0, 0.08, 0.0)), Color(1, 1, 1))
	hb.box("b", brass, Vector3(0.02, 0.05, 0.03), LcMB.T(Vector3(0.0, -0.08, 0.0)), Color(1, 1, 1))
	_mesh(hb.build(), hatch)
	piston = Node3D.new()
	piston.position = Vector3(-0.15, 0.42, 0.16)
	fig.torso.add_child(piston)
	var pb := LcMB.new()
	pb.cyl("s", steel, 0.025, 0.025, 0.12, 6, LcMB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	pb.box("r", red, Vector3(0.09, 0.09, 0.04), LcMB.T(Vector3(0, 0, 0.13)), Color(1, 1, 1))
	_mesh(pb.build(), piston)
	piston.scale = Vector3(1, 1, 0.2)
	# a party hat, strapped to the top of the cage at a jaunty angle
	hat = Node3D.new()
	hat.position = Vector3(0.08, 0.38, 0.02)
	hat.rotation = Vector3(0.0, 0.0, -0.35)
	fig.head.add_child(hat)
	var hm := LcMB.new()
	var stripes := LcMB.mat(_hat_tex())
	hm.cyl("h", stripes, 0.11, 0.0, 0.3, 8, LcMB.T(), Color(1, 1, 1), true, 2.0)
	hm.sphere("p", LcMB.mat(LcTex.solid(Color("f0c020"))), 0.035, 3, 6, LcMB.T(Vector3(0, 0.31, 0)), Color(1, 1, 1))
	_mesh(hm.build(), hat)


func _hat_tex() -> Texture2D:
	return LcTex.cached("partyhat", func():
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var band := ((x + y) / 4) % 3
				img.set_pixel(x, y, [Color("e8402a"), Color("f0e0c0"), Color("2a8ae8")][band])
		return img)


func _mesh(m: Mesh, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	parent.add_child(mi)


func set_mood(m: String) -> void:
	mood = m
	match m:
		"pleased":
			fig.set_attention(true)
			fig.set_suspicion(0.0)
		"calm":
			fig.set_attention(true)
			fig.set_suspicion(0.15)
		"displeased":
			fig.set_attention(true)
			fig.set_suspicion(0.55)
		"intense":
			fig.set_attention(true)
			fig.set_suspicion(0.9)
			fig.tell()
		"glitch":
			fig.set_attention(false, ["clock", "exit", "ceiling", "floor"][randi() % 4])
			fig.set_suspicion(1.0)
			fig.cage.whirl(0.8)


func set_unrest(u: float) -> void:
	unrest = u


## Look somewhere ("you", "board", "exit", "ceiling", ...) or at a world point.
func look(target: Variant) -> void:
	if target is String:
		fig.set_attention(target == "you", target)
	elif target is Vector3:
		var local := to_local(target)
		fig.look_yaw = atan2(local.x, local.z)
		fig.look_pitch = -atan2(local.y - 2.2, Vector2(local.x, local.z).length()) * 0.5


func speak(seconds: float) -> void:
	fig.speak(seconds)


# --- the animation library ---------------------------------------------------------------

const AR := LcCallerFigure.ARM_REST
const FR := LcCallerFigure.FORE_REST


func play(anim: String) -> void:
	if not ANIMS.has(anim):
		anim = "talk"
	current = anim
	if _tw and _tw.is_valid():
		_tw.kill()
	if fig.gesture_tween and fig.gesture_tween.is_valid():
		fig.gesture_tween.kill()
	_tw = create_tween()
	fig.gesture_tween = _tw
	var tw := _tw
	var L := fig.arm_l
	var R := fig.arm_r
	var fl := fig.fore_l
	var fr := fig.fore_r
	var T := fig.torso
	match anim:
		"talk":
			_p(tw, [R, Vector3(-1.0, 0, 0.3), fr, Vector3(-0.9, 0, 0)], 0.3)
			tw.tween_property(fr, "rotation", Vector3(-0.6, 0.3, 0), 0.25)
			tw.tween_property(fr, "rotation", Vector3(-1.0, -0.2, 0), 0.25)
			tw.tween_interval(0.4)
		"point":
			_p(tw, [R, Vector3(-1.45, 0, 0.1), fr, Vector3(-0.1, 0, 0)], 0.3)
			tw.tween_property(R, "position:z", 0.06, 0.08)
			tw.tween_property(R, "position:z", 0.0, 0.12)
			tw.tween_interval(0.8)
		"point_up":
			_p(tw, [R, Vector3(-2.9, 0, 0.15), fr, Vector3(-0.05, 0, 0)], 0.3)
			_h(tw, Vector3(0.45, 0, 0), 0.3)
			tw.tween_interval(1.0)
		"spread":
			_p(tw, [L, Vector3(-0.9, 0, -0.9), R, Vector3(-0.9, 0, 0.9), fl, Vector3(-0.2, 0, 0), fr, Vector3(-0.2, 0, 0)], 0.4)
			_h(tw, Vector3(0.15, 0, 0), 0.2)
			tw.tween_interval(1.0)
		"reach":
			_p(tw, [R, Vector3(-2.6, 0, 0.5), fr, Vector3(-0.8, 0, 0)], 0.5)
			tw.tween_callback(func(): fig.cage.jostle(0.8))
			tw.tween_interval(0.7)
		"tap":
			_p(tw, [L, Vector3(-1.0, 0, -0.1)], 0.25)
			for i in 3:
				tw.tween_property(fl, "rotation", Vector3(-0.5, 0, 0), 0.1)
				tw.tween_property(fl, "rotation", Vector3(-1.1, 0, 0), 0.1)
		"slam":
			_p(tw, [R, Vector3(-2.5, 0, 0.3), fr, Vector3(-0.4, 0, 0), T, Vector3(0.18, 0, 0)], 0.18)
			_p(tw, [R, Vector3(-1.2, 0, 0.15), fr, Vector3(-0.15, 0, 0), T, Vector3(0.32, 0, 0)], 0.08)
			tw.tween_callback(func():
				fig.cage.shudder(2.0)
				Audio.sfx("slam", 0.05, -6.0))
			tw.tween_interval(0.7)
		"wag":
			_p(tw, [L, Vector3(-1.9, 0, -0.1), fl, Vector3(-0.6, 0, 0)], 0.3)
			for i in 3:
				tw.tween_property(fl, "rotation", Vector3(-0.6, 0, 0.35), 0.16)
				tw.tween_property(fl, "rotation", Vector3(-0.6, 0, -0.35), 0.16)
		"spin":
			tw.tween_callback(func():
				fig.cage.whirl(1.2)
				Audio.sfx("cage_spin", 0.05, -6.0))
			_p(tw, [R, Vector3(-1.2, 0, 0.9), fr, Vector3(-1.4, 0, 0)], 0.2)
			for i in 4:
				tw.tween_property(fr, "rotation", Vector3(-1.4, 1.2, 0), 0.15)
				tw.tween_property(fr, "rotation", Vector3(-1.4, -1.2, 0), 0.15)
		"lean":
			_p(tw, [T, Vector3(0.3, 0, 0)], 0.6)
			_h(tw, Vector3(0.15, 0, 0), 0.3)
			tw.tween_interval(1.0)
		"bow":
			_p(tw, [T, Vector3(0.75, 0, 0), R, Vector3(-0.5, 0, 0.6), fr, Vector3(-1.6, 0, 0), L, Vector3(0.4, 0, -0.2)], 0.5)
			tw.tween_interval(0.6)
		"clap":
			for i in 4:
				_p(tw, [L, Vector3(-1.3, 0, 0.35), R, Vector3(-1.3, 0, -0.35), fl, Vector3(-0.9, 0, 0), fr, Vector3(-0.9, 0, 0)], 0.1)
				tw.tween_callback(func(): Audio.sfx("snap", 0.2, -12.0, 1.4))
				_p(tw, [L, Vector3(-1.2, 0, -0.3), R, Vector3(-1.2, 0, 0.3)], 0.1)
		"applaud":
			_p(tw, [L, Vector3(-2.2, 0, 0.3), R, Vector3(-2.2, 0, -0.3)], 0.25)
			for i in 6:
				tw.tween_property(fl, "rotation", Vector3(-0.3, 0, 0.3), 0.07)
				tw.tween_property(fl, "rotation", Vector3(-0.3, 0, -0.1), 0.07)
		"shrug":
			_p(tw, [L, Vector3(-0.5, 0, -0.5), R, Vector3(-0.5, 0, 0.5), fl, Vector3(-1.5, -0.6, 0), fr, Vector3(-1.5, 0.6, 0), T, Vector3(0, 0, 0)], 0.3)
			tw.parallel().tween_property(T, "position:y", 0.93, 0.3)
			_h(tw, Vector3(0, 0, 0.3), 0.25)
			tw.tween_interval(0.6)
			tw.tween_property(T, "position:y", 0.85, 0.3)
		"laugh":
			tw.tween_callback(func():
				fig.cage.whirl(1.0)
				Audio.sfx("laugh", 0.1, -8.0))
			for i in 6:
				_p(tw, [T, Vector3(-0.12, 0, 0.05)], 0.09)
				_p(tw, [T, Vector3(0.05, 0, -0.05)], 0.09)
			_h(tw, Vector3(-0.4, 0, 0), 0.2)
			tw.tween_interval(0.3)
		"dance":
			for i in 4:
				var s := 1.0 if i % 2 == 0 else -1.0
				_p(tw, [T, Vector3(0, 0.4 * s, 0.15 * s), L, Vector3(-2.4, 0, -0.4), R, Vector3(-0.4, 0, 0.6), fl, Vector3(-0.6, 0, 0)], 0.22)
				tw.tween_callback(func(): _scuttle = 0.5)
				_p(tw, [T, Vector3(0, -0.4 * s, -0.15 * s), L, Vector3(-0.4, 0, -0.6), R, Vector3(-2.4, 0, 0.4), fr, Vector3(-0.6, 0, 0)], 0.22)
		"glitch":
			for i in 7:
				var r := Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.6), randf_range(-0.4, 0.4))
				_p(tw, [T, r * 0.4, R, AR + r * 2.0, L, Vector3(AR.x, 0, -AR.z) - r * 2.0], 0.03)
				_h(tw, r, 0.03)
				tw.tween_interval(randf_range(0.04, 0.18))
			tw.tween_callback(func():
				fig.cage.shudder(2.0)
				Audio.sfx("cage_shudder", 0.1, -4.0))
		"freeze":
			tw.tween_callback(func(): fig.freeze(1.6))
			tw.tween_interval(1.8)
		"nervous":
			_p(tw, [L, Vector3(-1.1, 0, 0.45), R, Vector3(-1.1, 0, -0.45), fl, Vector3(-1.2, 0, 0), fr, Vector3(-1.2, 0, 0)], 0.3)
			for i in 5:
				tw.tween_property(fl, "rotation", Vector3(-1.2, 0.5, 0), 0.12)
				tw.parallel().tween_property(fr, "rotation", Vector3(-1.2, -0.5, 0), 0.12)
				tw.tween_property(fl, "rotation", Vector3(-1.2, -0.3, 0), 0.12)
				tw.parallel().tween_property(fr, "rotation", Vector3(-1.2, 0.3, 0), 0.12)
			_h(tw, Vector3(0, -0.5, 0), 0.15)
			_h(tw, Vector3(0, 0.5, 0), 0.15)
		"panic":
			tw.tween_callback(func():
				fig.cage.whirl(2.0)
				fig.tell()
				Audio.sfx("alarm", 0.05, -10.0))
			for i in 5:
				_p(tw, [L, Vector3(-2.8, 0, -0.5), R, Vector3(-2.8, 0, 0.5), fl, Vector3(-0.4, 0.8, 0), fr, Vector3(-0.4, -0.8, 0)], 0.1)
				tw.tween_callback(func(): _scuttle = 1.0)
				_p(tw, [L, Vector3(-2.2, 0, -0.9), R, Vector3(-2.2, 0, 0.9), fl, Vector3(-0.9, -0.8, 0), fr, Vector3(-0.9, 0.8, 0)], 0.1)
		"present_left":
			_p(tw, [L, Vector3(-1.0, 0, -1.0), fl, Vector3(-0.2, 0, 0), T, Vector3(0, 0.35, 0)], 0.4)
			_h(tw, Vector3(0, 0.5, 0), 0.3)
			tw.tween_interval(1.0)
		"present_right":
			_p(tw, [R, Vector3(-1.0, 0, 1.0), fr, Vector3(-0.2, 0, 0), T, Vector3(0, -0.35, 0)], 0.4)
			_h(tw, Vector3(0, -0.5, 0), 0.3)
			tw.tween_interval(1.0)
		"beckon":
			_p(tw, [R, Vector3(-1.5, 0, 0.2), fr, Vector3(-0.3, 0, 0)], 0.3)
			for i in 3:
				tw.tween_property(fr, "rotation", Vector3(-1.6, 0, 0), 0.18)
				tw.tween_property(fr, "rotation", Vector3(-0.3, 0, 0), 0.18)
		"conduct":
			_p(tw, [R, Vector3(-1.8, 0, 0.4), L, Vector3(-1.6, 0, -0.4)], 0.25)
			for i in 4:
				tw.tween_property(R, "rotation", Vector3(-2.3, 0, 0.6), 0.16)
				tw.parallel().tween_property(L, "rotation", Vector3(-1.2, 0, -0.6), 0.16)
				tw.tween_property(R, "rotation", Vector3(-1.4, 0, 0.2), 0.16)
				tw.parallel().tween_property(L, "rotation", Vector3(-2.0, 0, -0.2), 0.16)
		"salute":
			_p(tw, [R, Vector3(-2.3, 0, 1.1), fr, Vector3(-2.2, 0, 0)], 0.25)
			_p(tw, [T, Vector3(-0.08, 0, 0)], 0.15)
			tw.tween_interval(0.9)
		"wave":
			_p(tw, [R, Vector3(-2.6, 0, 0.6), fr, Vector3(-0.3, 0, 0)], 0.3)
			for i in 4:
				tw.tween_property(fr, "rotation", Vector3(-0.3, 0, 0.5), 0.15)
				tw.tween_property(fr, "rotation", Vector3(-0.3, 0, -0.4), 0.15)
		"thumbs_up":
			_p(tw, [R, Vector3(-1.2, 0, 0.3), fr, Vector3(-1.3, 0, 0)], 0.3)
			tw.tween_property(R, "position:y", R.position.y + 0.05, 0.1)
			tw.tween_property(R, "position:y", R.position.y, 0.1)
			tw.tween_interval(0.8)
		"cover_eyes":
			_p(tw, [L, Vector3(-2.0, 0, 0.5), R, Vector3(-2.0, 0, -0.5), fl, Vector3(-1.7, 0, 0), fr, Vector3(-1.7, 0, 0)], 0.3)
			tw.tween_callback(func(): fig.set_attention(false, "floor"))
			tw.tween_interval(1.0)
			tw.tween_property(fl, "rotation", Vector3(-1.0, 0, 0), 0.15)
			tw.tween_callback(func(): fig.set_attention(true))
			tw.tween_interval(0.4)
		"facepalm":
			_p(tw, [R, Vector3(-2.1, 0, -0.3), fr, Vector3(-1.9, 0, 0), T, Vector3(0.2, 0, 0)], 0.25)
			tw.tween_callback(func(): fig.cage.jostle(1.2))
			_h(tw, Vector3(0.3, 0, 0), 0.2)
			tw.tween_interval(1.0)
		"shush":
			_p(tw, [R, Vector3(-2.0, 0, -0.2), fr, Vector3(-1.9, 0, 0), T, Vector3(0.15, 0, 0)], 0.25)
			tw.tween_callback(func(): Audio.sfx("whisper", 0.05, -8.0))
			tw.tween_interval(1.0)
		"head_spin":
			tw.tween_callback(func(): Audio.sfx("caller_turn", 0.05, -4.0))
			tw.tween_property(self, "head_extra", Vector3(0, TAU, 0), 0.9).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func(): head_extra = Vector3.ZERO)
			tw.tween_interval(0.4)
		"hatch":
			tw.tween_property(hatch, "rotation:y", -1.9, 0.8)
			tw.tween_interval(0.3)
			tw.tween_property(piston, "scale:z", 7.0, 0.12).set_trans(Tween.TRANS_EXPO)
			tw.tween_callback(func():
				Audio.sfx("slam", 0.05, 0.0)
				fig.cage.shudder(1.5))
			tw.tween_interval(0.4)
			tw.tween_property(piston, "scale:z", 0.2, 0.8)
			tw.tween_property(hatch, "rotation:y", 0.0, 0.6)
		"countdown":
			_p(tw, [R, Vector3(-2.2, 0, 0.3), fr, Vector3(-0.2, 0, 0)], 0.25)
			for i in 3:
				tw.tween_callback(func(): Audio.sfx("tick", 0.0, -6.0, 1.0 + i * 0.2))
				tw.tween_property(R, "rotation", Vector3(-2.0, 0, 0.3), 0.15)
				tw.tween_property(R, "rotation", Vector3(-2.2, 0, 0.3), 0.15)
				tw.tween_interval(0.4)
		"scuttle":
			tw.tween_method(func(v: float): _scuttle = 1.0, 0.0, 1.0, 1.5)
		"sob":
			_p(tw, [T, Vector3(0.35, 0, 0), L, Vector3(-1.9, 0, 0.4), R, Vector3(-1.9, 0, -0.4), fl, Vector3(-1.8, 0, 0), fr, Vector3(-1.8, 0, 0)], 0.4)
			for i in 5:
				tw.tween_property(T, "position:y", 0.83, 0.12)
				tw.tween_property(T, "position:y", 0.87, 0.12)
		"malfunction":
			tw.tween_callback(func():
				Audio.sfx("zap", 0.1, -8.0)
				fig.cage.shudder(2.5))
			tw.tween_property(R, "rotation", Vector3(0.3, 0, 0.05), 0.15).set_trans(Tween.TRANS_BOUNCE)
			tw.tween_property(fr, "rotation", Vector3(0.0, 0, 0), 0.1)
			tw.tween_interval(0.8)
			_h(tw, Vector3(0.0, 0.0, 0.7), 0.1)
			tw.tween_interval(0.6)
			_h(tw, Vector3.ZERO, 0.4)
		"drum":
			_p(tw, [L, Vector3(-1.0, 0, -0.1), R, Vector3(-1.0, 0, 0.1)], 0.2)
			for i in 6:
				tw.tween_property(fl, "rotation", Vector3(-0.4, 0, 0), 0.06)
				tw.tween_property(fl, "rotation", Vector3(-0.9, 0, 0), 0.06)
				tw.tween_property(fr, "rotation", Vector3(-0.4, 0, 0), 0.06)
				tw.tween_property(fr, "rotation", Vector3(-0.9, 0, 0), 0.06)
		"tip_hat":
			_p(tw, [R, Vector3(-2.7, 0, -0.2), fr, Vector3(-1.0, 0, 0)], 0.3)
			tw.tween_property(hat, "position:y", 0.55, 0.2)
			tw.tween_property(hat, "position:y", 0.38, 0.2)
			_p(tw, [T, Vector3(0.25, 0, 0)], 0.25)
		"look_door":
			tw.tween_callback(func(): fig.set_attention(false, "exit"))
			tw.tween_interval(1.4)
			tw.tween_callback(func():
				fig.tell()
				fig.set_attention(true))
			tw.tween_interval(0.3)
		"stare":
			tw.tween_callback(func():
				fig.set_attention(true)
				fig.set_suspicion(1.0))
			_p(tw, [T, Vector3(0.2, 0, 0)], 0.8)
			tw.tween_interval(1.5)
	# back to rest
	tw.tween_property(L, "rotation", Vector3(AR.x, 0, -AR.z), 0.45)
	tw.parallel().tween_property(R, "rotation", Vector3(AR.x, 0, AR.z), 0.45)
	tw.parallel().tween_property(fl, "rotation", FR, 0.45)
	tw.parallel().tween_property(fr, "rotation", FR, 0.45)
	tw.parallel().tween_property(T, "rotation", Vector3.ZERO, 0.45)
	tw.parallel().tween_property(self, "head_extra", Vector3.ZERO, 0.45)
	tw.tween_callback(func(): gesture_done.emit(anim))


## Pose several joints at once: [node, rotation, node, rotation, ...].
func _p(tw: Tween, pairs: Array, dur: float) -> void:
	for i in range(0, pairs.size(), 2):
		var t := tw.parallel() if i > 0 else tw
		t.tween_property(pairs[i], "rotation", pairs[i + 1], dur).set_trans(Tween.TRANS_QUAD)


func _h(tw: Tween, r: Vector3, dur: float) -> void:
	tw.tween_property(self, "head_extra", r, dur)


func _process(delta: float) -> void:
	_t += delta
	fig.head.rotation += head_extra
	# unrest: little stutters and a lean that wasn't there before
	if unrest > 0.0 and randf() < delta * unrest * 0.6:
		fig.head.rotation.z += randf_range(-0.25, 0.25) * unrest * 0.3
	if unrest >= 2.0:
		fig.cage.set_suspicion(1.0)
	_scuttle = maxf(0.0, _scuttle - delta)
	if _scuttle > 0.0:
		_walk_phase += delta * 2.5
		fig.walk(_walk_phase, 1.0)
	else:
		fig.walk(_walk_phase, 0.0)
