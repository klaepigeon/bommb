class_name SockoMind
extends Node
## What Socko wants, and how he goes about it. He's the HUD: he says what to do next (SOCKO), he
## looks at what's worth looking at, he flinches at what's coming before you can see it, he shows
## what Kurt's body is doing, he teaches. And everything he steers toward is the bad ending. He
## wants Kurt violent, obedient and incurious: every suggestion is the loud, cruel option, and he
## leaves out the kind ones. He gets worse the more he's ignored, through seven stages:
##   1 friendly suggestions · 2 mild confusion · 3 insistence · 4 passive-aggression ·
##   5 irritation · 6 emotional manipulation · 7 open hostility
## (and warmer, in a way that should feel worse, when he's obeyed). Nothing essential depends on
## him: the USE button always says what it does, the pause menu always tells the truth.

var socko: Socko
var kurt: Kurt
var level: Level
var defiance := 0.0
var obeyed := 0.0
var said := {}                     ## line id -> times
var _quiet_t := 0.0                ## seconds since anyone spoke
var _random_left := ["a", "b", "c"]
var _glance_t := 40.0
var _warned := {}
var _cool := {}
var _hurt_t := 0.0
var _busy := false
var visited := {}                  ## maze cells he's seen (for his map)

func setup(s: Socko, k: Kurt, l: Level) -> void:
	socko = s; kurt = k; level = l
	World.event.connect(_on_event)
	Controls.pressed.connect(_on_pressed)
	Progress.changed.connect(func(): pass)
	World.register("socko", _save, _load)

func stage() -> int:
	return clampi(1 + int(floor(maxf(defiance - obeyed * 0.5, 0.0) / 1.5)), 1, 7)

func defy(amount: float, why := "") -> void:
	var before := stage()
	defiance += amount
	Log.mark("socko defied %.1f (%s) stage %d" % [amount, why, stage()])
	World.set_flag("socko_stage", stage())
	if stage() > before: _stage_bark(stage())

func obey(amount: float, why := "") -> void:
	obeyed += amount
	Log.mark("socko obeyed %.1f (%s) stage %d" % [amount, why, stage()])
	World.set_flag("socko_stage", stage())

func _stage_bark(s: int) -> void:
	if s >= 2: bark("stage%d" % s, true)

## A line of his, if nobody's talking (or `force`: waits its turn).
func bark(id: String, force := false) -> void:
	if not World.flag("socko_on") or _busy: return
	if Speech.speaking != "" and not force: return
	if _cool.get(id, 0.0) > 0.0: return
	_cool[id] = 20.0
	said[id] = int(said.get(id, 0)) + 1
	if Speech.speaking != "":
		await Speech.line_finished
	Speech.say_id(id)

func once(id: String) -> void:
	if said.has(id): return
	said[id] = 0
	bark(id, true)

# ------------------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if socko == null or not World.flag("socko_on"): return
	for k in _cool.keys(): _cool[k] = float(_cool[k]) - delta
	_quiet_t = 0.0 if Speech.speaking != "" else _quiet_t + delta
	var s := stage()
	# his resting self: how far gone he is
	socko.idle_clip = "Idle_Default" if s < 4 else ("Idle_Restless" if SockoClips.has("Idle_Restless") and s < 6 else "Idle_Default")
	socko.stillness = move_toward(socko.stillness, 0.5 if s >= 7 else 0.0, delta * 0.2)
	if Speech.speaking == "" and socko.expression == "neutral" and s >= 5:
		socko.expression = "irritation" if s < 7 else "unnatural_stillness"
	# what Kurt's looking at, he looks at (the HUD's "prompt": he notices with you)
	var t = kurt.target
	socko.look_target = null
	if t and t is Node3D and kurt.target_verbs.size() > 0:
		socko.look_target = (t as Node3D).global_position + Vector3(0, 0.3, 0)
	elif t and t is Usable:
		socko.look_target = (t as Usable).global_position
	# threats: he feels them before you see them (and later, sometimes, keeps it to himself)
	var near: Monster = null; var nd := 9.0
	for m in get_tree().get_nodes_in_group("monsters"):
		var mm := m as Monster
		if mm.state in [Monster.S.DEAD, Monster.S.SIT, Monster.S.CALM]: continue
		var d := mm.global_position.distance_to(kurt.global_position)
		if d < nd: nd = d; near = mm
	var hides := s >= 5 and near is Marta and near.state != Monster.S.HUNT
	var want_fear := 0.0 if near == null or hides else clampf(1.0 - nd / 9.0, 0.0, 1.0)
	socko.fear = move_toward(socko.fear, want_fear, delta * 0.8)
	if near and not hides and nd < 7.0:
		if Speech.speaking == "": socko.look_target = near.global_position + Vector3(0, 1.2, 0)
		if not _warned.has(near.id) or float(_warned[near.id]) < Time.get_ticks_msec() / 1000.0 - 60.0:
			_warned[near.id] = Time.get_ticks_msec() / 1000.0
			bark("warn_super" if near is Super else "warn_marta")
	# his body: Kurt's
	_hurt_t -= delta
	if kurt.hp < 45.0 and _hurt_t <= 0.0:
		_hurt_t = 80.0; bark("hurt")
	# a look straight out at you, now and then, once he's far enough gone
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance_t = randf_range(70.0, 140.0)
		if s >= 4 and _quiet_t > 6.0: _look_at_you()
	# the random conversations, when it's been quiet a long while and nothing's near
	if _quiet_t > 75.0 and near == null and not _random_left.is_empty() and not _busy and not kurt.frozen:
		_quiet_t = 0.0
		var r: String = _random_left.pop_at(randi() % _random_left.size())
		_random(r)
	# his map: the cells of the walls Kurt has stood in
	if level.maze.zone_of(kurt.global_position) >= 0:
		visited[level.maze.cell_of(kurt.global_position)] = true

func _look_at_you() -> void:
	var tw := create_tween()
	tw.tween_property(socko, "at_player", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.4)
	tw.tween_property(socko, "at_player", 0.0, 0.25)
	World.set_flag("socko_looked_out", true)

func _random(which: String) -> void:
	_busy = true
	match which:
		"a":
			for id in ["ra_1", "ra_2", "ra_3", "ra_4", "ra_5"]: await Speech.say_id(id)
		"b":
			for id in ["rb_1", "rb_2", "rb_3", "rb_4", "rb_5"]: await Speech.say_id(id)
		"c":
			var rem := Progress.memory_spent >= 1
			await Speech.say_id("rc_1")
			await Speech.say_id("rc_2b" if rem else "rc_2a")
			await Speech.say_id("rc_3")
			await Speech.say_id("rc_4b" if rem else "rc_4a")
			await Speech.say_id("rc_5")
			await Speech.say_id("rc_6")
			await Speech.say_id("rc_7")
	_busy = false
	World.emit_event("random_talk", {"which": which})

## Forces one (tests, and the story when it wants one).
func random_now(which: String) -> void:
	_random_left.erase(which)
	await _random(which)

# ------------------------------------------------------------------------------ SOCKO: what now?
func _on_pressed(a: String) -> void:
	if a == "torch":
		if World.flag("socko_on"):
			socko.torch_on = not socko.torch_on
			Audio.play("pop", null, -12.0, 1.6)
		return
	if a != "socko" or not World.flag("socko_on") or Speech.speaking != "": return
	var t = kurt.target
	if t and t.has_method("socko_verbs"):
		var v: Array = t.socko_verbs(kurt)
		if v.size() > 0:
			command(t, String(v[0].id)); return
	suggest()

func command(t, id: String) -> void:
	if stage() >= 6 and randf() < 0.5:
		bark("cmd_refuse", true); defy(0.2, "commanded"); return
	t.socko_act(id, kurt, self)

func band() -> String:
	var s := stage()
	return "a" if s <= 2 else ("b" if s <= 4 else ("c" if s <= 6 else "d"))

func _pick(base: String) -> String:
	for b in [band(), "c", "b", "a"]:
		if Speech.has_line("%s_%s" % [base, b]): return "%s_%s" % [base, b]
	return "sug_none_a"

## His idea of what to do next. Always the loud one. Never the kind one.
func suggest() -> void:
	var line := ""
	var point := Vector3.INF
	var marta: Monster = get_tree().get_first_node_in_group("marta")
	if not World.flag("wardrobe_moved"):
		line = _pick("sug_wardrobe"); point = Flat47.WARDROBE_AT + Vector3(0, 1.0, 0)
	elif not kurt.has_item("revolver") and not World.flag("gun_taken"):
		line = _pick("sug_gun"); point = _toward_gun()
	elif marta and marta.state not in [Monster.S.DEAD]:
		line = _pick("sug_marta"); point = marta.global_position + Vector3(0, 1, 0)
	elif level.flat.doors.has("dEntry") and level.flat.doors["dEntry"].padlock:
		line = _pick("sug_padlock"); point = level.flat.doors["dEntry"].handle_pos()
	else:
		line = _pick("sug_exit") if band() == "a" else _pick("sug_none")
	World.emit_event("socko_suggested", {"line": line})
	if point != Vector3.INF:
		socko.point_at(point)
		get_tree().create_timer(2.8, false).timeout.connect(func(): socko.point_at(Vector3.INF))
	await Speech.say_id(line)

## Which way the gun is from here, along the walls (he can smell it).
func _toward_gun() -> Vector3:
	var g: Node3D = get_tree().get_first_node_in_group("gun")
	if g == null: return Vector3.INF
	var a := level.nav.nearest(kurt.global_position, 4.0)
	var b := level.nav.nearest(g.global_position, 4.0)
	var p := level.nav.path(a, b)
	if p.size() > 2: return level.nav.pts[p[2]] + Vector3(0, 1.0, 0)
	return g.global_position

# ------------------------------------------------------------------------------ what happens
func _on_event(name: String, d: Dictionary) -> void:
	if not World.flag("socko_on"): return
	match name:
		"read":
			if not said.has("read_once"): said["read_once"] = 1; bark("read_a" if band() == "a" else "read_c")
			defy(0.3, "read")
		"pocketed":
			if d.item == "revolver":
				World.set_flag("gun_taken"); obey(1.0, "gun"); bark("gun_taken", true)
		"skill":
			if d.tree == "memory": defy(1.0, "memory skill"); bark("memory_skill", true)
			elif d.id == "headshot": obey(1.5, "headshot"); bark("headshot_skill", true)
			else: obey(1.0, "infection skill"); bark("infection_skill", true)
		"killed":
			obey(2.0, "kill " + String(d.id))
			if d.id == "marta":
				_busy = true
				await Speech.say_id("kill_marta"); await Speech.say_id("kill_marta_2")
				_busy = false
			else: bark("kill_other", true)
		"marta_calmed":
			if d.get("known", false): defy(2.5, "knew her"); bark("known", true)
			elif d.for_good: defy(2.0, "both shoes"); bark("calm_forever", true)
			else:
				defy(1.5, "a shoe")
				_busy = true
				await Speech.say_id("calm_one"); await Speech.say_id("calm_two")
				_busy = false
		"porter_calmed", "lamplighter_calmed": defy(1.0, "talked down"); bark("talked_down", true)
		"porter_alarm": bark("porter_alarm", true)
		"marta_shocked": bark("marta_shocked", true)
		"hurt":
			if str(d.by) == "current": bark("shocked")
		"tv": pass
		"bath_reach": if d.black: bark("bath_black", true)
		"fell_into_white": bark("fell_white", true)
		"mantled": once("tut_mantle")
		"lifted": once("tut_carry")
		"thrown": once("tut_noise")
		"door_unlocked":
			if d.door == "dEntry": defy(0.5, "quiet key")
		"padlock_off":
			if d.how == "key": defy(0.5, "quiet key")
			else: obey(0.5, "broke it")
		"monster_state":
			if d.id.begins_with("figure") and d.state == "hunt": once("figures")
		"marta_first_sight":
			_marta_talk(d.m)
		"shot":
			pass

## Marta and Socko: a whole conversation, and Kurt's not in it.
func _marta_talk(m: Monster) -> void:
	_busy = true
	kurt.frozen = true
	Speech.stop()
	socko.set_pose("talk", 0.6)
	socko.face_kurt = 0.0
	socko.look_target = m.global_position + Vector3(0, 1.2, 0)
	for id in ["mx_1", "mx_2", "mx_3", "mx_4", "mx_5", "mx_6"]:
		socko.look_target = m.global_position + Vector3(0, 1.2, 0)
		if id.begins_with("mx_2") or id in ["mx_4", "mx_6"]: socko.gesture("nod")
		await Speech.say_id(id)
	m.set_state(Monster.S.AWAY)
	(m as Marta).away_for = 18.0
	m.go_to((m as Marta)._far_haunt())
	socko.set_pose("up", 0.6)
	socko.face_kurt = 0.8
	for id in ["mx_k1", "mx_s1", "mx_k2", "mx_s2"]:
		await Speech.say_id(id)
	socko.face_kurt = 0.0
	kurt.frozen = false
	_busy = false
	World.set_flag("heard_socko_marta")

func _save() -> Dictionary:
	return {"def": defiance, "ob": obeyed, "said": said, "rl": _random_left}

func _load(d: Dictionary) -> void:
	defiance = float(d.get("def", 0.0)); obeyed = float(d.get("ob", 0.0)); said = d.get("said", {})
	_random_left.assign(d.get("rl", ["a", "b", "c"]))
