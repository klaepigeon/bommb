extends Minigame
## HOOK, LINE AND SINKER (FFA). A vat of offal, a crane each. Your hook swings back and
## forth over the vat on its own; HOLD to let the line down (deeper the longer you hold),
## LET GO to reel it up. Snag something on the way down and reel it to the top to bank it:
## Teeth (1), gold teeth (3), a jar (5, heavy: reels slowly). Don't snag the JAWS (they
## bite back) and keep your line out when the vat SPARKS (the cable in there is live: the
## surface flickers first). JERK the next crane's line to make them drop their catch.

const DURATION := 40.0
const VAT_W := 8.0
const DEPTH := 4.0
const SPARK_WARN := 1.2

var hook: Dictionary = {}       # seat -> {x, depth, phase, speed, holding, catch (-1|obj index), stun}
var objs: Array = []            # [{x, d, kind, v, alive, vx}]
var score: Dictionary = {}
var spark := {"warn": 0.0, "on": 0.0, "next": 6.0}
var jerk_cd: Dictionary = {}
var _spawn := 0.0


func id() -> String:
	return "hook_line_sinker"


func title() -> String:
	return "HOOK, LINE AND SINKER"


func instructions() -> Array:
	return ["Your hook swings over the vat by itself.", "HOLD to drop the line. LET GO to reel it in.",
		"Snag Teeth, gold, jars. Reel them out to bank them.", "Not the JAWS. And pull your line out when the vat flickers: it's live.",
		"JERK someone's line to make them drop theirs."]


func controls(_seat: int) -> Array:
	return [{"kind": "hold", "do": "drop", "label": "HOLD: DROP THE LINE"}, {"kind": "tap", "do": "jerk", "label": "JERK A LINE"}]


func setup() -> void:
	for k in seats.size():
		var s: int = seats[k]
		hook[s] = {"x": -VAT_W / 2.0 + VAT_W * (k + 0.5) / seats.size(), "depth": 0.0, "phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.7, 1.0), "holding": false, "catch": -1, "stun": 0.0}
		score[s] = 0
		jerk_cd[s] = 0.0
	for i in 9:
		_spawn_obj()


func _spawn_obj() -> void:
	var r := rng.randf()
	var kind := "tooth" if r < 0.55 else ("gold" if r < 0.75 else ("jar" if r < 0.85 else "jaws"))
	if level >= 1 and rng.randf() < 0.1:
		kind = "jaws"
	objs.append({"x": rng.randf_range(-VAT_W / 2.0 + 0.3, VAT_W / 2.0 - 0.3), "d": rng.randf_range(0.8, DEPTH - 0.2), "kind": kind,
		"v": {"tooth": 1, "gold": 3, "jar": 5, "jaws": 0}[kind], "alive": true, "vx": rng.randf_range(-0.25, 0.25)})


func hook_x(s: int) -> float:
	var h: Dictionary = hook[s]
	var sp := float(h.speed) * (0.6 if is_chilled(s) else 1.0)
	return clampf(float(h.x) + sin(t * sp * 1.6 + float(h.phase)) * 2.2, -VAT_W / 2.0, VAT_W / 2.0)


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat):
		return
	var h: Dictionary = hook[seat]
	match str(a.get("do", "")):
		"drop":
			h.holding = bool(a.get("on", true))
		"jerk":
			if float(jerk_cd[seat]) > 0.0:
				return
			jerk_cd[seat] = 5.0
			var victim := -1
			var bd := INF
			for o in living():
				if o != seat and float(hook[o].depth) > 0.2:
					var d := absf(hook_x(o) - hook_x(seat))
					if d < bd:
						bd = d
						victim = o
			if victim >= 0:
				_drop_catch(victim)
				hook[victim].stun = 1.0
				core.emit({"e": "mg", "k": "jerk", "seat": seat, "target": victim})
				core.brains[victim].wronged_by(seat, 0.05)


func _drop_catch(s: int) -> void:
	var h: Dictionary = hook[s]
	if int(h.catch) >= 0:
		objs[int(h.catch)].alive = true
		objs[int(h.catch)].d = float(h.depth)
		h.catch = -1


func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	# the live cable
	spark.next -= dt
	if spark.next <= 0.0 and spark.warn <= 0.0 and spark.on <= 0.0:
		spark.warn = SPARK_WARN - level * 0.15
		core.emit({"e": "mg", "k": "spark_warn"})
	if spark.warn > 0.0:
		spark.warn -= dt
		if spark.warn <= 0.0:
			spark.on = 0.6
			spark.next = rng.randf_range(4.0, 7.0) - level * 0.5
			core.emit({"e": "mg", "k": "spark"})
	if spark.on > 0.0:
		spark.on -= dt
		for s in living():
			if float(hook[s].depth) > 0.3:
				hook[s].depth = 0.0
				_drop_catch(s)
				hook[s].stun = 1.5
				core.injure(s, ["hand_l", "hand_r", "arm_l", "arm_r"][rng.randi_range(0, 3)], "burned" if level < 2 and not tip(s) else "broken", "machinery")
				core.emit({"e": "mg", "k": "shock", "seat": s})
	for o in objs:
		if o.alive:
			o.x = clampf(float(o.x) + float(o.vx) * dt, -VAT_W / 2.0 + 0.2, VAT_W / 2.0 - 0.2)
			if absf(float(o.x)) >= VAT_W / 2.0 - 0.21:
				o.vx = -float(o.vx)
	for s in seats:
		jerk_cd[s] = maxf(0.0, float(jerk_cd[s]) - dt)
		if not alive(s):
			continue
		var h: Dictionary = hook[s]
		if float(h.stun) > 0.0:
			h.stun = float(h.stun) - dt
			h.holding = false
		var hands := clampf(Body.hands(body(s)) / 2.0, 0.35, 1.0)
		var heavy: bool = int(h.catch) >= 0 and objs[int(h.catch)].kind == "jar"
		if h.holding and int(h.catch) < 0:
			h.depth = minf(DEPTH, float(h.depth) + 2.2 * dt)
		else:
			var reel := 2.6 * hands * (0.45 if heavy else 1.0) * (0.7 if handicapped.has(s) else 1.0)
			h.depth = maxf(0.0, float(h.depth) - reel * dt)
		# snagging
		if int(h.catch) < 0 and float(h.depth) > 0.2:
			var hx := hook_x(s)
			for i in objs.size():
				var o: Dictionary = objs[i]
				if o.alive and absf(float(o.x) - hx) < 0.35 and absf(float(o.d) - float(h.depth)) < 0.3:
					if o.kind == "jaws":
						o.alive = false
						h.depth = 0.0
						h.stun = 1.2
						core.injure(s, ["hand_l", "hand_r"][rng.randi_range(0, 1)], "lost" if (level >= 2 or tip(s)) else "broken", "the jaws")
						core.emit({"e": "mg", "k": "jaws", "seat": s})
					else:
						o.alive = false
						h.catch = i
						core.emit({"e": "mg", "k": "snag", "seat": s, "kind": o.kind})
					break
		# banked
		if int(h.catch) >= 0 and float(h.depth) <= 0.0:
			var o: Dictionary = objs[int(h.catch)]
			score[s] += int(o.v)
			h.catch = -1
			core.emit({"e": "mg", "k": "bank", "seat": s, "kind": o.kind, "v": o.v})
	_spawn -= dt
	if _spawn <= 0.0:
		_spawn = 1.6
		if objs.filter(func(o): return o.alive).size() < 10:
			_spawn_obj()
	if t >= DURATION or living().is_empty():
		_end()


func _end() -> void:
	for s in seats:
		teeth[s] += int(score[s])
	rank_by(score)
	var best := -1
	var top := []
	for s in living():
		if int(score[s]) > best:
			best = int(score[s])
			top = [s]
		elif int(score[s]) == best:
			top.append(s)
	if top.size() == 1:
		finish(top)
	else:
		finish([], true)


func cheat_options(seat: int) -> Array:
	return [{"id": "magnet", "name": "slip a magnet on your hook"}] if alive(seat) else []


func apply_cheat(seat: int, _cid: String) -> void:
	hook[seat].speed = 0.35   # a slow swing is easy to aim


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var hv := {}
	for s in seats:
		var h: Dictionary = hook[s]
		hv[s] = {"x": hook_x(s), "depth": h.depth, "holding": h.holding, "catch": objs[int(h.catch)].kind if int(h.catch) >= 0 else "", "stun": h.stun}
	var ov := []
	for o in objs:
		if o.alive:
			ov.append({"x": o.x, "d": o.d, "kind": o.kind})
	v.merge({"hooks": hv, "objs": ov, "score": score.duplicate(), "spark_warn": spark.warn > 0.0, "spark": spark.on > 0.0,
		"vat": [VAT_W, DEPTH], "time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	var h: Dictionary = hook[seat]
	# the cable: get out
	if spark.warn > 0.0 and brain.rng.randf() < brain.perception + 0.2:
		action(seat, {"do": "drop", "on": false})
		return
	if int(h.catch) >= 0:
		action(seat, {"do": "drop", "on": false})
		return
	var hx := hook_x(seat)
	var want := false
	for o in objs:
		if o.alive and o.kind != "jaws" and absf(float(o.x) - hx) < 0.5:
			if float(o.d) > float(h.depth) - 0.1:
				want = true
		if o.alive and o.kind == "jaws" and absf(float(o.x) - hx) < 0.4 and absf(float(o.d) - float(h.depth)) < 0.8:
			want = false
			break
	action(seat, {"do": "drop", "on": want})
	brain.wait += dt
	if brain.wait > 3.0 and brain.coop < 0.4:
		brain.wait = 0.0
		action(seat, {"do": "jerk"})
