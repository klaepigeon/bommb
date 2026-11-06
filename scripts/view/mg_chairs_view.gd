extends MgView
## MUSICAL CHAIRS, drawn. Folding chairs in a ring; the rigged ones give themselves away
## if you look (and listen) closely: a spark at the legs and a hum, a cushion sitting
## proud and a creak, a square seam in the floor and a draught, a zigzag of teeth on the
## cushion's edge and a chatter, a glint on the armrests and a tick. How plainly you see
## and hear them depends on your own eyes and ears.

var chairs: Array[Node3D] = []
var tells: Array = []          # per chair: {node, kind, sound: AudioStreamPlayer3D}
var seats_cushion: Array = []
var _t := 0.0
var _sub := ""
var _sight := 1.0
var _hearing := 1.0


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	var mg: Dictionary = view.mg
	for i in mg.chairs.size():
		var c: Dictionary = mg.chairs[i]
		var n := _chair()
		n.position = Vector3(c.pos.x, 0.0, c.pos.y) + center
		n.rotation.y = float(c.facing)
		add_child(n)
		chairs.append(n)
		tells.append({})
	Audio.music("chairs")


func _chair() -> Node3D:
	var root := Node3D.new()
	var mb := LcMB.new()
	var metal := LcMB.mat(LcTex.grime(Color("7a7a82"), Color("a8a8b0"), 16, 21, 0.3))
	var wood := LcMB.mat(LcTex.wood(Color("c87a3a"), 4, 16, 2))
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			mb.box("m", metal, Vector3(0.04, 0.48, 0.04), LcMB.T(Vector3(x, 0.24, z)), Color(1, 1, 1))
		mb.box("m", metal, Vector3(0.04, 0.5, 0.04), LcMB.T(Vector3(x, 0.72, -0.2)), Color(1, 1, 1))
		mb.box("a", metal, Vector3(0.05, 0.05, 0.38), LcMB.T(Vector3(x * 1.15, 0.66, 0.0)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(0.46, 0.05, 0.46), LcMB.T(Vector3(0, 0.48, 0)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(0.46, 0.22, 0.04), LcMB.T(Vector3(0, 0.86, -0.21)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	root.add_child(mi)
	var cushion := LcMB.new()
	cushion.box("c", LcMB.mat(LcTex.grime(Color("c83a5a"), Color("e86a8a"), 16, 22, 0.3)), Vector3(0.4, 0.06, 0.4), LcMB.T(), Color(1, 1, 1))
	var cm := MeshInstance3D.new()
	cm.name = "Cushion"
	cm.mesh = cushion.build()
	cm.position.y = 0.53
	root.add_child(cm)
	return root


func _make_tell(i: int, kind: String, sound: String) -> void:
	var c := chairs[i]
	for k in tells[i].keys():
		if tells[i][k] is Node:
			tells[i][k].queue_free()
	tells[i] = {"kind": kind}
	if kind == "":
		(c.get_node("Cushion") as Node3D).position.y = 0.53
		return
	var mb := LcMB.new()
	var n := MeshInstance3D.new()
	match kind:
		"spark":
			mb.box("s", LcMB.mat(LcTex.solid(Color("a0d0ff")), Color("a0d0ff"), Vector2.ONE, true), Vector3(0.06, 0.06, 0.06), LcMB.T(Vector3(0.2, 0.06, 0.2)), Color(1, 1, 1))
		"bulge":
			(c.get_node("Cushion") as Node3D).position.y = 0.57
			mb.box("s", LcMB.mat(LcTex.solid(Color("909090"))), Vector3(0.03, 0.05, 0.03), LcMB.T(Vector3(0.12, 0.51, 0.12)), Color(1, 1, 1))
		"seam":
			var dark := LcMB.mat(LcTex.solid(Color("2a1018")))
			for s in [[Vector3(0, 0.012, -0.42), Vector3(0.84, 0.01, 0.025)], [Vector3(0, 0.012, 0.42), Vector3(0.84, 0.01, 0.025)],
					[Vector3(-0.42, 0.012, 0), Vector3(0.025, 0.01, 0.84)], [Vector3(0.42, 0.012, 0), Vector3(0.025, 0.01, 0.84)]]:
				mb.box("s", dark, s[1], LcMB.T(s[0]), Color(1, 1, 1))
		"teeth":
			var bone := LcMB.mat(LcTex.solid(Color("f0ead8")))
			for k in 6:
				var x := -0.17 + k * 0.068
				mb.tri("t", bone, Vector3(x - 0.03, 0.5, 0.21), Vector3(x + 0.03, 0.5, 0.21), Vector3(x, 0.55, 0.215), Color(1, 1, 1))
		"glint":
			mb.box("s", LcMB.mat(LcTex.solid(Color("ffffff")), Color("ffffff"), Vector2.ONE, true), Vector3(0.05, 0.02, 0.02), LcMB.T(Vector3(0.23, 0.7, 0.1)), Color(1, 1, 1))
	n.mesh = mb.build()
	c.add_child(n)
	tells[i]["node"] = n
	var snd := {"hum": "caller_hum", "creak": "chair_creak", "draught": "whoosh", "chatter": "dice_clack", "tick": "tick"}
	if snd.has(sound) and not Audio.muted:
		var p := AudioStreamPlayer3D.new()
		p.stream = Assets.stream("sfx", snd[sound])
		p.bus = "SFX"
		p.unit_size = 1.2
		p.max_distance = 9.0
		p.volume_db = -14.0 + 10.0 * _hearing - (30.0 if _hearing < 0.2 else 0.0)
		p.pitch_scale = 0.6 if sound == "hum" else 1.0
		c.add_child(p)
		tells[i]["sound"] = p
		tells[i]["sound_gap"] = randf_range(0.4, 1.4)


func update_view(view: Dictionary, dt: float) -> void:
	_t += dt
	var mg: Dictionary = view.mg
	var me: Dictionary = gv.viewer_body()
	_sight = Body.sight(me) if not me.is_empty() else 1.0
	_hearing = Body.hearing(me) if not me.is_empty() else 1.0
	if mg.sub != _sub:
		if mg.sub == "music":
			Audio.music_halt(false)
			for i in chairs.size():
				_make_tell(i, str(mg.chairs[i].tell), str(mg.chairs[i].sound))
				(chairs[i] as Node3D).position = Vector3(mg.chairs[i].pos.x, 0.0, mg.chairs[i].pos.y) + center
				(chairs[i] as Node3D).rotation.y = float(mg.chairs[i].facing)
				for s in gv.contestants:
					gv.contestants[s].sit(false)
		elif mg.sub == "scramble":
			Audio.music_halt(true)
			Audio.sfx("bell", 0.0, -2.0)
		_sub = mg.sub
	# tells flicker (as well as you can see them)
	for i in tells.size():
		var tl: Dictionary = tells[i]
		if tl.has("node"):
			var vis := 1.0
			match str(tl.kind):
				"spark":
					vis = float(randf() < 0.25)
				"glint":
					vis = float(fmod(_t + i, 1.6) < 0.15)
			(tl.node as Node3D).visible = vis > 0.0 and randf() < 0.35 + 0.65 * _sight
		if tl.has("sound") and mg.sub == "music":
			tl.sound_gap -= dt
			if tl.sound_gap <= 0.0:
				tl.sound_gap = randf_range(0.6, 1.8)
				(tl.sound as AudioStreamPlayer3D).play()
	for s in mg.seats:
		var c: Contestant = fig(int(s))
		if c.dead:
			continue
		var p: Vector2 = mg.pos.get(s, Vector2.ZERO)
		var w := Vector3(p.x, 0.0, p.y) + center
		if mg.seated.has(s):
			var ch: Node3D = chairs[int(mg.seated[s])]
			c.position = ch.position + Vector3(0, 0.0, 0)
			c.target = c.position
			c.face_dir = ch.rotation.y
			c.sit(true)
		else:
			c.walk_to(w)


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"hazard":
			var ch: Node3D = chairs[int(e.chair)]
			match str(e.hazard):
				"live_wire":
					Audio.sfx("zap", 0.05, 0.0)
				"spring":
					var cu := ch.get_node("Cushion") as Node3D
					var tw := create_tween()
					tw.tween_property(cu, "position:y", 1.6, 0.12)
					tw.tween_property(cu, "position:y", 0.57, 0.5).set_trans(Tween.TRANS_BOUNCE)
				"trapdoor":
					var tw := create_tween()
					tw.tween_property(ch, "position:y", -2.0, 0.4).set_delay(0.3)
				"jaws":
					Audio.sfx("squish", 0.05, 0.0)
				"clapper":
					Audio.sfx("snap", 0.05, 2.0)
			var c: Contestant = fig(int(e.seat))
			if not c.dead:
				Audio.sfx("hurt", 0.1, 0.0)
				var tw2 := c.create_tween()
				tw2.tween_property(c, "rotation:z", 0.3, 0.08)
				tw2.tween_property(c, "rotation:z", 0.0, 0.25)
		"reveal_all":
			# every rigged chair shows itself (they're remembered: they stay rigged)
			for pair in e.chairs:
				var ch: Node3D = chairs[int(pair[0])]
				var l := Label3D.new()
				l.text = str(pair[1]).replace("_", " ").to_upper()
				l.font_size = 40
				l.pixel_size = 0.006
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.modulate = Color("ff5050")
				l.position = Vector3(0, 1.4, 0)
				ch.add_child(l)
				get_tree().create_timer(2.8).timeout.connect(l.queue_free)


func camera() -> Array:
	return [center + Vector3(0, 9.5, 8.5), center + Vector3(0, 0, 0.4)]


func _exit_tree() -> void:
	Audio.music_halt(false)
