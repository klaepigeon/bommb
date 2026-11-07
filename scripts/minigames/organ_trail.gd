extends Minigame
## ORGAN TRAIL (special event, 2v2, FULL_CHARACTER). Two operating tables. On each, one of
## you is the SURGEON and one is the PATIENT (strapped down, awake, and very much a player).
## The Caller names an organ; the first team to extract it properly (the right organ,
## still in one piece, in the right jar) wins. Never in the ordinary rotation: a surgical
## square, the Caller, or an event calls it.
##
## The surgeon works in stages (assets/data/organs.json says which, per organ), each with
## its own hands: LOCATE (pick the right one out of the look-alikes), INCISE (trace the cut
## line), SEPARATE (aim at a connection, then cut it; some of them are nerves), CLAMP (the
## right clamp, on the beat of the pulse), DISCONNECT (in the order on the chart), EXTRACT
## (hold to pull, keep the force in the window), PRESENT (the right jar). Each stage needs
## its instrument picked first. SYRINGE tops up the anaesthetic, CAUTERY stops bleeding.
##
## The patient feels things the surgeon can't see: which connection is a nerve, the order
## on the chart taped above them, a complication coming. No talking in LAST CALL 3: they
## have CALLOUTS (STOP!, KEEP GOING!, NEXT: 3...) and their own body to manage: BREATHE on
## the beat (panic), HOLD STILL (movement), STAY AWAKE. Pain, panic, bleeding, anaesthetic,
## consciousness all feed each other; mistakes can be recovered from. Anyone can sabotage
## the other table (for Teeth, with a cooldown); the Caller can add modifiers, announced.

const LIMIT := 150.0
const COMPLICATIONS := ["bleeding", "slippery", "malfunction", "anatomy", "movement", "false_alarm", "contaminated", "anaesthetic_failure"]
const WARN_PATIENT := 1.6
const WARN_SURGEON := 0.6

var data: Dictionary = {}
var organ_id := "kidney"
var organ: Dictionary = {}
var ts: Array = []              # team state, one per table
var modifiers: Array = []
var sab_cd: Dictionary = {}     # seat -> seconds
var sab_used: Dictionary = {}   # "seat:id" -> true
var callouts: Array = []        # [{seat, id, t, team}] (everyone sees them)
var finish_t := -1.0
var awards: Array = []
var _swapped := false
var _changed := false
var _end_t := 0.0
var force_organ := ""


func id() -> String:
	return "organ_trail"


func title() -> String:
	return "ORGAN TRAIL"


func instructions() -> Array:
	return ["TWO TABLES. One SURGEON and one PATIENT each. First clean extraction wins.",
		"SURGEON: pick the instrument for each stage, then do the stage. SYRINGE and CAUTERY whenever you need them.",
		"PATIENT: BREATHE on the beat, HOLD STILL, stay awake. You can feel what they can't: use your CALLOUTS.",
		"Wrong organ, broken organ, wrong jar: it doesn't count.", "You can sabotage the other table. It costs Teeth."]


func setup() -> void:
	data = Assets.load_json("res://assets/data/organs.json")
	var ids: Array = data.organs.keys()
	ids.sort()
	organ_id = force_organ if force_organ != "" else ids[rng.randi_range(0, ids.size() - 1)]
	organ = data.organs[organ_id]
	make_teams([2, 2])
	# modifiers: none to two, always announced
	var mods: Array = data.modifiers.keys()
	mods.sort()
	var n := rng.randi_range(0, 2)
	for i in n:
		var m: String = mods[rng.randi_range(0, mods.size() - 1)]
		if not modifiers.has(m) and m != "change_organ":
			modifiers.append(m)
	for i in 2:
		var tm: Array = teams[i]
		var st := {"surgeon": int(tm[0]), "patient": int(tm[1]), "stage": 0, "tool": "", "mistakes": 0, "integrity": 100.0,
			"pain": 0.0, "consciousness": 100.0, "panic": 10.0, "anaesthetic": 100.0, "bleed": 0.0, "movement": 0.0, "still": false,
			"busy": 0.0, "done_t": -1.0, "valid": false, "comp": {}, "warn": {}, "next_comp": rng.randf_range(9.0, 14.0), "slippery": 0.0,
			"stolen": 0.0, "jam": 0.0, "contaminated": false, "unconscious": 0.0, "dead": false, "coop": 0, "recovered": 0, "complications": 0,
			"aim": -1, "cut": [], "nerves": [], "clamped": 0, "order": [], "order_i": 0, "force": 0.0, "pulled": 0.0, "pulling": false,
			"lobe": 0, "trace_ok": false, "jars": [], "anaes_rate": 2.0, "tool_delay": 0.0, "candidates": [], "pain_sum": 0.0, "breath_t": 0.0}
		ts.append(st)
	if modifiers.has("hard_anaesthesia"):
		ts[rng.randi_range(0, 1)].anaes_rate = 4.5
	if modifiers.has("inferior_tools"):
		ts[rng.randi_range(0, 1)].tool_delay = 1.2
	for i in 2:
		_prepare(ts[i])
		notes.append("TABLE %d: %s operates on %s." % [i + 1, core.p(ts[i].surgeon).name, core.p(ts[i].patient).name])


## Lay out this table's version of the organ (look-alikes, nerves, the chart, the jars).
func _prepare(st: Dictionary) -> void:
	var cands := [{"name": organ.name, "look": organ.look, "side": organ.side, "real": true}]
	for d in organ.decoys:
		cands.append({"name": str(d[0]).to_upper(), "look": str(d[1]), "side": str(d[2]), "real": false})
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = cands[i]
		cands[i] = cands[j]
		cands[j] = x
	st.candidates = cands
	var nconn := int(organ.connections)
	var nerves := []
	while nerves.size() < int(organ.nerves) and nerves.size() < nconn - 1:
		var k := rng.randi_range(0, nconn - 1)
		if not nerves.has(k):
			nerves.append(k)
	st.nerves = nerves
	var order := []
	for i in int(organ.order):
		order.append(i + 1)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = order[i]
		order[i] = order[j]
		order[j] = x
	st.order = order
	var jars := [organ_id.to_upper()]
	for k in data.organs.keys():
		if k != organ_id and jars.size() < 4:
			jars.append(str(k).to_upper())
	jars.shuffle()
	st.jars = jars


func stages() -> Array:
	return organ.stages


func stage_of(st: Dictionary) -> String:
	return str(stages()[int(st.stage)]) if int(st.stage) < stages().size() else "done"


func team_of_seat(s: int) -> int:
	for i in 2:
		if ts[i].surgeon == s or ts[i].patient == s:
			return i
	return -1


func role_of(s: int) -> String:
	var i := team_of_seat(s)
	if i < 0:
		return ""
	return "surgeon" if ts[i].surgeon == s else "patient"


func controls(seat: int) -> Array:
	var i := team_of_seat(seat)
	if i < 0:
		return []
	var st: Dictionary = ts[i]
	if role_of(seat) == "patient":
		var out: Array = [{"kind": "timing", "do": "breathe", "label": "BREATHE", "period": 2.0, "window": 0.35},
			{"kind": "hold", "do": "still", "label": "HOLD STILL"}, {"kind": "tap", "do": "awake", "label": "STAY AWAKE"}]
		var calls := ["stop", "keep_going", "hurts", "wrong", "wrong_tool", "fine", "numb", "fading"]
		if stage_of(st) == "disconnect":
			for k in st.order.size():
				calls.append("next_%d" % (k + 1))
		out.append({"kind": "pick", "do": "call", "label": "CALL OUT", "options": calls})
		return out
	var c: Array = [{"kind": "pick", "do": "tool", "label": "INSTRUMENT", "options": data.tray, "selected": st.tool}]
	match stage_of(st):
		"locate":
			c.append({"kind": "pick", "do": "locate", "label": "WHICH ONE", "options": range(st.candidates.size()).map(func(k): return "ABCD"[k])})
		"incise":
			c.append({"kind": "trace", "do": "trace", "label": "TRACE THE CUT"})
		"separate":
			c.append({"kind": "pick", "do": "aim", "label": "AIM", "options": range(int(organ.connections)).filter(func(k): return not st.cut.has(k)).map(func(k): return str(k + 1))})
			c.append({"kind": "tap", "do": "cut", "label": "CUT"})
		"clamp":
			c.append({"kind": "timing", "do": "clamp", "label": "CLAMP", "period": float(organ.pulse), "window": 0.22, "options": ["SMALL", "LARGE"]})
		"disconnect":
			c.append({"kind": "pick", "do": "snip", "label": "CUT NUMBER", "options": range(st.order.size()).map(func(k): return str(k + 1))})
		"extract":
			c.append({"kind": "hold", "do": "pull", "label": "PULL"})
		"present":
			c.append({"kind": "pick", "do": "present", "label": "JAR", "options": st.jars})
	c.append({"kind": "tap", "do": "syringe", "label": "SYRINGE"})
	c.append({"kind": "tap", "do": "cautery", "label": "CAUTERY"})
	return c


func actions_for(seat: int) -> Array:
	var out := []
	for k in data.sabotage.keys():
		var d: Dictionary = data.sabotage[k]
		if d.get("once", false) and sab_used.has("%d:%s" % [seat, k]):
			continue
		out.append({"do": "sabotage", "id": k, "name": "%s (%d TEETH)" % [d.name, int(d.cost)]})
	return out


# --- actions --------------------------------------------------------------------------

func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat) or done or finish_t >= 0.0:
		return
	var i := team_of_seat(seat)
	if i < 0:
		return
	var st: Dictionary = ts[i]
	var d := str(a.get("do", ""))
	if d == "sabotage":
		_sabotage(seat, str(a.get("id", "")))
		return
	if role_of(seat) == "patient":
		_patient(st, i, seat, d, a)
		return
	if float(st.busy) > 0.0:
		return
	match d:
		"tool":
			var t := str(a.get("pick", ""))
			if (data.tray as Array).has(t):
				if t == str(data.instruments.get(stage_of(st), "")) and float(st.stolen) > 0.0:
					core.toast("Your %s's gone. Someone took it." % t.to_lower(), seat)
					return
				st.tool = t
				st.busy = float(st.tool_delay)
		"syringe":
			st.anaesthetic = minf(100.0, float(st.anaesthetic) + 45.0)
			st.busy = 2.5
			core.emit({"e": "mg", "k": "syringe", "seat": seat, "team": i})
		"cautery":
			st.bleed = maxf(0.0, float(st.bleed) - 45.0)
			st.pain = float(st.pain) + _hurt(st, 8.0)
			st.busy = 2.0
			if int(st.complications) > 0:
				st.recovered = int(st.recovered) + 1
			core.emit({"e": "mg", "k": "cautery", "seat": seat, "team": i})
		"spare":
			st.stolen = 0.0
			st.busy = 3.0
		_:
			_stage_action(st, i, seat, d, a)


func _need_tool(st: Dictionary, seat: int) -> bool:
	var want := str(data.instruments.get(stage_of(st), ""))
	if float(st.jam) > 0.0:
		core.toast("The instrument's jammed.", seat)
		return false
	if st.tool != want:
		_mistake(st, "the wrong instrument", 10.0)
		return false
	return true


## Patient's pain from something: the anaesthetic takes most of it.
func _hurt(st: Dictionary, raw: float) -> float:
	return raw * (1.0 - 0.8 * float(st.anaesthetic) / 100.0)


func _mistake(st: Dictionary, what: String, pain: float, bleed := 0.0, integrity := 0.0) -> void:
	st.mistakes = int(st.mistakes) + 1
	st.pain = float(st.pain) + _hurt(st, pain)
	st.bleed = float(st.bleed) + bleed
	st.integrity = maxf(0.0, float(st.integrity) - integrity)
	core.emit({"e": "mg", "k": "mistake", "team": ts.find(st), "what": what})


func _advance(st: Dictionary, i: int) -> void:
	st.stage = int(st.stage) + 1
	st.aim = -1
	st.pulled = 0.0
	st.force = 0.0
	core.emit({"e": "mg", "k": "stage", "team": i, "stage": stage_of(st)})
	if stage_of(st) == "done":
		st.valid = float(st.integrity) > 0.0
		st.done_t = t
		core.emit({"e": "mg", "k": "extracted", "team": i, "valid": st.valid})


func _stage_action(st: Dictionary, i: int, seat: int, d: String, a: Dictionary) -> void:
	var stage := stage_of(st)
	match d:
		"locate":
			if stage != "locate":
				return
			var k := "ABCD".find(str(a.get("pick", "")))
			if k < 0 or k >= (st.candidates as Array).size():
				return
			if st.candidates[k].real:
				_advance(st, i)
			else:
				_mistake(st, "the wrong organ", 12.0, 5.0)
		"trace":
			if stage != "incise" or not _need_tool(st, seat):
				return
			var r := score_trace(a.get("pts", []), float(st.movement))
			if r.hit_protected:
				_mistake(st, "cut something it shouldn't", 15.0, 30.0)
			if r.ok:
				st.pain = float(st.pain) + _hurt(st, 18.0)
				_advance(st, i)
			else:
				_mistake(st, "a ragged cut", 12.0, 8.0)
		"aim":
			if stage != "separate":
				return
			st.aim = int(a.get("pick", "0")) - 1
			core.emit({"e": "mg", "k": "aim", "team": i, "at": st.aim})
		"cut":
			if stage != "separate" or int(st.aim) < 0 or not _need_tool(st, seat):
				return
			var k2 := int(st.aim)
			st.aim = -1
			if st.cut.has(k2):
				return
			st.cut.append(k2)
			if (st.nerves as Array).has(k2):
				_mistake(st, "a nerve", 30.0, 10.0)
			else:
				st.pain = float(st.pain) + _hurt(st, 6.0)
			var left := 0
			for kk in int(organ.connections):
				if not st.cut.has(kk) and not (st.nerves as Array).has(kk):
					left += 1
			if left == 0:
				_advance(st, i)
		"clamp":
			if stage != "clamp" or not _need_tool(st, seat):
				return
			var need: String = organ.vessels[int(st.clamped)]
			var size := str(a.get("pick", a.get("size", "")))
			var ph := fmod(t, float(organ.pulse)) / float(organ.pulse)
			var on_beat := ph < 0.22 or ph > 0.78 or bool(a.get("ai_timing", false))
			if size != need:
				_mistake(st, "the wrong clamp", 8.0, 12.0)
			elif not on_beat:
				_mistake(st, "clamped between beats", 6.0, 8.0)
			else:
				st.clamped = int(st.clamped) + 1
				core.emit({"e": "mg", "k": "clamp", "team": i})
				if int(st.clamped) >= (organ.vessels as Array).size():
					_advance(st, i)
		"snip":
			if stage != "disconnect" or not _need_tool(st, seat):
				return
			var n := int(a.get("pick", "0"))
			if (st.order as Array).is_empty():
				_advance(st, i)
				return
			if n == int(st.order[int(st.order_i)]):
				st.order_i = int(st.order_i) + 1
				st.pain = float(st.pain) + _hurt(st, 5.0)
				if int(st.order_i) >= (st.order as Array).size():
					_advance(st, i)
			else:
				_mistake(st, "out of order", 10.0, 15.0, 10.0)
		"pull":
			if stage != "extract":
				return
			if bool(a.get("on", true)) and not _need_tool(st, seat):
				return
			st.pulling = bool(a.get("on", true))
		"present":
			if stage != "present":
				return
			var jar := str(a.get("pick", ""))
			if jar == organ_id.to_upper():
				_advance(st, i)
			else:
				_mistake(st, "the wrong jar", 0.0)
				st.busy = 2.0


## How good is a traced cut? Points (0..1 field coords) against the line.
func score_trace(pts_in: Variant, movement := 0.0) -> Dictionary:
	var line: Array = organ.path
	var pts := []
	if pts_in is Array:
		for q in pts_in:
			pts.append(Vector2(float(q[0]), float(q[1])))
	if line.size() < 2:
		return {"ok": true, "err": 0.0, "coverage": 1.0, "hit_protected": false}
	if pts.size() < 3:
		return {"ok": false, "err": 1.0, "coverage": 0.0, "hit_protected": false}
	var seg := []
	for k in line.size() - 1:
		seg.append([Vector2(line[k][0], line[k][1]), Vector2(line[k + 1][0], line[k + 1][1])])
	var err := 0.0
	var hit := false
	for q in pts:
		var jitter := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * movement * 0.0006
		var p: Vector2 = q + jitter
		var best := INF
		for s in seg:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, s[0], s[1])))
		err += best
		for pr in organ.protected:
			if p.distance_to(Vector2(pr[0], pr[1])) < float(pr[2]):
				hit = true
	err /= pts.size()
	# coverage: how much of the line had a point near it
	var samples := 20
	var covered := 0
	var total_len := 0.0
	for s in seg:
		total_len += (s[0] as Vector2).distance_to(s[1])
	for k in samples:
		var f := (k + 0.5) / samples * total_len
		var acc := 0.0
		var at := Vector2.ZERO
		for s in seg:
			var l: float = (s[0] as Vector2).distance_to(s[1])
			if f <= acc + l:
				at = (s[0] as Vector2).lerp(s[1], (f - acc) / maxf(0.0001, l))
				break
			acc += l
		for q in pts:
			if (q as Vector2).distance_to(at) < float(organ.tolerance) * 1.6:
				covered += 1
				break
	var cov := float(covered) / samples
	return {"ok": err <= float(organ.tolerance) and cov >= 0.75, "err": err, "coverage": cov, "hit_protected": hit}


func _patient(st: Dictionary, i: int, seat: int, d: String, a: Dictionary) -> void:
	if float(st.unconscious) > 0.0 and d != "awake":
		return
	match d:
		"breathe":
			var ph := fmod(t, 2.0) / 2.0
			if ph < 0.18 or ph > 0.82 or bool(a.get("ai_timing", false)):
				st.panic = maxf(0.0, float(st.panic) - 14.0)
				st.breath_t = t
			else:
				st.panic = minf(100.0, float(st.panic) + 4.0)
		"still":
			st.still = bool(a.get("on", true))
		"awake":
			st.consciousness = minf(100.0, float(st.consciousness) + 7.0)
			if float(st.unconscious) > 0.0:
				st.unconscious = maxf(0.0, float(st.unconscious) - 1.0)
		"call":
			var cid := str(a.get("pick", a.get("id", "")))
			if not data.callouts.has(cid):
				return
			callouts.append({"seat": seat, "id": cid, "text": data.callouts[cid], "t": t, "team": i})
			if callouts.size() > 12:
				callouts.pop_front()
			if _useful(st, cid):
				st.coop = int(st.coop) + 1
			core.emit({"e": "mg", "k": "callout", "seat": seat, "id": cid, "team": i})


## Was that worth saying? (the cooperation award)
func _useful(st: Dictionary, cid: String) -> bool:
	match cid:
		"stop":
			return int(st.aim) >= 0 and (st.nerves as Array).has(int(st.aim)) or not (st.warn as Dictionary).is_empty()
		"keep_going":
			return int(st.aim) >= 0 and not (st.nerves as Array).has(int(st.aim))
		"hurts":
			return float(st.anaesthetic) < 40.0
		"wrong", "fading":
			return not (st.warn as Dictionary).is_empty() or float(st.consciousness) < 40.0
		"wrong_tool":
			return st.tool != str(data.instruments.get(stage_of(st), ""))
	if cid.begins_with("next_") and stage_of(st) == "disconnect" and int(st.order_i) < (st.order as Array).size():
		return int(cid.substr(5)) == int(st.order[int(st.order_i)])
	return false


func _sabotage(seat: int, sid: String) -> void:
	if not data.sabotage.has(sid) or float(sab_cd.get(seat, 0.0)) > 0.0:
		return
	var d: Dictionary = data.sabotage[sid]
	var key := "%d:%s" % [seat, sid]
	if d.get("once", false) and sab_used.has(key):
		return
	if not core.economy.charge(seat, int(d.cost), "sabotage"):
		core.toast("That costs %d Teeth." % int(d.cost), seat)
		return
	sab_used[key] = true
	sab_cd[seat] = float(d.get("cd", 30))
	var other: Dictionary = ts[1 - team_of_seat(seat)]
	match sid:
		"steal":
			other.stolen = 8.0
			if other.tool == str(data.instruments.get(stage_of(other), "")):
				other.tool = ""
		"distract":
			other.busy = maxf(float(other.busy), 2.0)
		"swap_jars":
			(other.jars as Array).reverse()
		"malfunction":
			other.jam = 4.0
	core.emit({"e": "mg", "k": "sabotage", "seat": seat, "id": sid})
	core.toast("%s sabotages the other table: %s." % [core.p(seat).name, str(d.name).to_lower()])


# --- the clock ------------------------------------------------------------------------

func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	for s in sab_cd.keys():
		sab_cd[s] = maxf(0.0, float(sab_cd[s]) - dt)
	if finish_t >= 0.0:
		_end_t += dt
		if _end_t > 2.5 and not done:
			_results()
		return
	var shared := ""
	for i in 2:
		var st: Dictionary = ts[i]
		if st.dead and float(st.done_t) < 0.0 and not modifiers.has("survival_required"):
			pass
		_tick_team(st, i, dt, shared)
		if st.get("_shared", "") != "":
			shared = str(st._shared)
			st._shared = ""
	if modifiers.has("swap_roles") and not _swapped and int(ts[0].stage) + int(ts[1].stage) >= stages().size():
		_swapped = true
		for st in ts:
			var x: int = st.surgeon
			st.surgeon = st.patient
			st.patient = x
			st.tool = ""
		core.emit({"e": "mg", "k": "swap_roles"})
		core.toast("THE CALLER: \"Swap!\" Surgeons on the table, patients on their feet.")
	var finished := ts.filter(func(x): return float(x.done_t) >= 0.0 and x.valid)
	var limit := 90.0 if modifiers.has("time_limit") else LIMIT
	if not finished.is_empty() or t >= limit or ts.all(func(x): return float(x.done_t) >= 0.0 or x.dead and false):
		finish_t = t


func _tick_team(st: Dictionary, i: int, dt: float, shared: String) -> void:
	if float(st.done_t) >= 0.0:
		return
	st.busy = maxf(0.0, float(st.busy) - dt)
	st.stolen = maxf(0.0, float(st.stolen) - dt)
	st.jam = maxf(0.0, float(st.jam) - dt)
	st.slippery = maxf(0.0, float(st.slippery) - dt)
	if not st.dead:
		st.anaesthetic = maxf(0.0, float(st.anaesthetic) - float(st.anaes_rate) * dt)
		st.pain = maxf(0.0, float(st.pain) - 4.0 * dt)
		st.pain_sum = float(st.pain_sum) + float(st.pain) * dt
		st.panic = clampf(float(st.panic) + (5.0 if float(st.pain) > 55.0 else -1.5) * dt, 0.0, 100.0)
		if float(st.bleed) > 0.0:
			st.bleed = float(st.bleed) + (1.2 if not organ.get("messy", false) else 1.8) * dt
		st.consciousness = clampf(float(st.consciousness) - ((6.0 if float(st.pain) > 80.0 else 0.0) + float(st.bleed) * 0.05) * dt + 1.5 * dt, 0.0, 100.0)
		if float(st.consciousness) <= 0.0 and float(st.unconscious) <= 0.0:
			st.unconscious = 6.0
			core.emit({"e": "mg", "k": "unconscious", "team": i})
		if float(st.unconscious) > 0.0:
			st.unconscious = maxf(0.0, float(st.unconscious) - dt)
			if float(st.unconscious) <= 0.0:
				st.consciousness = 30.0
				core.emit({"e": "mg", "k": "wakes", "team": i})
		# involuntary movement: panic does it, holding still stops most of it
		var mv := float(st.panic) / 100.0 * (0.25 if st.still else 1.0)
		st.movement = lerpf(float(st.movement), mv * 100.0, minf(1.0, dt * 2.0))
		if float(st.bleed) >= 100.0 and not st.dead:
			st.dead = true
			core.emit({"e": "mg", "k": "patient_dies", "team": i})
			notes.append("%s bled out on the table." % core.p(st.patient).name)
	# complications: warned to the patient first, then the surgeon, then they happen
	st.next_comp = float(st.next_comp) - dt
	if (st.warn as Dictionary).is_empty() and (float(st.next_comp) <= 0.0 or shared != ""):
		var c: String = shared if shared != "" else COMPLICATIONS[rng.randi_range(0, COMPLICATIONS.size() - 1)]
		st.warn = {"kind": c, "t": WARN_PATIENT}
		st.next_comp = rng.randf_range(9.0, 15.0) + level * -1.0
		if modifiers.has("shared_complication") and shared == "":
			st._shared = c
		core.emit({"e": "mg", "k": "warn", "team": i, "kind": c})
	if not (st.warn as Dictionary).is_empty():
		st.warn.t = float(st.warn.t) - dt
		if float(st.warn.t) <= 0.0:
			_complication(st, i, str(st.warn.kind))
			st.warn = {}
	# extraction
	if stage_of(st) == "extract":
		var band: Array = organ.band
		var lo := float(band[0])
		var hi := float(band[1])
		if float(st.slippery) > 0.0:
			lo += (hi - lo) * 0.25
			hi -= (hi - lo) * 0.25
		if st.pulling and float(st.jam) <= 0.0:
			st.force = minf(100.0, float(st.force) + 38.0 * dt)
		else:
			st.force = maxf(0.0, float(st.force) - 55.0 * dt)
		var f := float(st.force) + float(st.movement) * 0.15 * sin(t * 9.0)
		var breathing_out: bool = not organ.get("breath", false) or fmod(t, 3.0) < 1.6
		if f >= lo and f <= hi and breathing_out:
			st.pulled = float(st.pulled) + dt
			if float(st.pulled) >= float(organ.pull):
				st.pulled = 0.0
				st.lobe = int(st.lobe) + 1
				_advance(st, i)
		elif f > hi:
			st.integrity = maxf(0.0, float(st.integrity) - 22.0 * dt)
			st.pain = float(st.pain) + _hurt(st, 25.0 * dt)
			if float(st.integrity) <= 0.0:
				core.emit({"e": "mg", "k": "torn", "team": i})


func _complication(st: Dictionary, i: int, c: String) -> void:
	st.complications = int(st.complications) + 1
	core.emit({"e": "mg", "k": "complication", "team": i, "kind": c})
	match c:
		"bleeding":
			st.bleed = float(st.bleed) + 25.0
		"slippery":
			st.slippery = 8.0
		"malfunction":
			st.jam = 4.0
		"anatomy":
			# an extra connection to deal with, if they're not past it
			if stage_of(st) in ["locate", "incise", "separate"]:
				organ = organ.duplicate(true)
				organ.connections = int(organ.connections) + 0
		"movement":
			if not st.still:
				st.pain = float(st.pain) + _hurt(st, 10.0)
				st.integrity = maxf(0.0, float(st.integrity) - 6.0)
				st.panic = float(st.panic) + 10.0
		"false_alarm":
			pass
		"contaminated":
			st.contaminated = true
		"anaesthetic_failure":
			st.anaesthetic = 0.0


func _results() -> void:
	var finishers := []
	for i in 2:
		if float(ts[i].done_t) >= 0.0 and ts[i].valid:
			finishers.append(i)
	finishers.sort_custom(func(a, b): return float(ts[a].done_t) < float(ts[b].done_t))
	var win_teams := []
	if not finishers.is_empty():
		win_teams.append(finishers[0])
		if finishers.size() > 1 and absf(float(ts[finishers[0]].done_t) - float(ts[finishers[1]].done_t)) < 0.05:
			win_teams.append(finishers[1])     # simultaneous: both
	# the operations' consequences
	for i in 2:
		var st: Dictionary = ts[i]
		var pt: int = st.patient
		if st.dead:
			core.kill(pt, "blood_loss", [["torso", "broken"]], true)
			continue
		if st.contaminated:
			core.status.apply(st.surgeon, core.status.random_poison(st.surgeon), "a dirty instrument")
		if float(st.done_t) >= 0.0:
			var conseq := str(organ.get("consequence", "torso"))
			if conseq == "kill_unless_won" and not win_teams.has(i):
				core.kill(pt, "organ", [], true)
			elif conseq == "lose_eye":
				core.injure(pt, "eye_l", "lost", "surgery", false)
			elif conseq.begins_with("poison:"):
				core.injure(pt, "torso", "broken", "surgery", false)
				core.status.apply(pt, conseq.substr(7), "surgery")
			else:
				core.injure(pt, "torso", "broken", "surgery", false)
			if conseq == "kill_unless_won" and win_teams.has(i):
				notes.append("The Caller screws a brass %s into %s's chest. It ticks." % [organ_id, core.p(pt).name])
		else:
			core.injure(pt, "torso", "burned", "surgery", false)
	# the extra awards (Teeth)
	_award("FASTEST TEAM", func(st): return -float(st.done_t) if float(st.done_t) >= 0.0 else -INF, 4)
	_award("BEST PATIENT", func(st): return float(st.coop), 4, true)
	_award("FEWEST MISTAKES", func(st): return -float(st.mistakes), 2)
	_award("LOWEST PAIN", func(st): return -float(st.pain_sum), 2, true)
	_award("CLEANEST EXTRACTION", func(st): return float(st.integrity) if float(st.done_t) >= 0.0 else -INF, 3)
	_award("BEST RECOVERY", func(st): return float(st.recovered), 2)
	if win_teams.size() < 2:
		var loser: int = 1 - (win_teams[0] if not win_teams.is_empty() else 0)
		if int(ts[loser].mistakes) >= 3 or ts[loser].dead:
			awards.append({"name": "MOST DRAMATIC FAILURE", "team": loser})
			for s in teams[loser]:
				teeth[s] = int(teeth.get(s, 0)) + 1
	for i in 2:
		var st: Dictionary = ts[i]
		if modifiers.has("reward_survival") and not st.dead:
			teeth[st.patient] = int(teeth.get(st.patient, 0)) + 5
		if modifiers.has("reward_clean") and float(st.integrity) >= 90.0 and float(st.done_t) >= 0.0:
			teeth[st.surgeon] = int(teeth.get(st.surgeon, 0)) + 5
	var win := []
	for i in win_teams:
		win.append_array(teams[i])
	if modifiers.has("secret_patient") and win_teams.size() == 1:
		var lp: int = ts[1 - win_teams[0]].patient
		teeth[lp] = int(teeth.get(lp, 0)) + 6
	ranking = []
	if win_teams.size() == 2:
		finish(win, true)
	elif win.is_empty():
		finish([], true)
	else:
		finish(win)


func _award(name: String, score: Callable, n: int, patient := false) -> void:
	var a: float = score.call(ts[0])
	var b: float = score.call(ts[1])
	if a == b or (a == -INF and b == -INF):
		return
	var i := 0 if a > b else 1
	awards.append({"name": name, "team": i})
	var who: int = ts[i].patient if patient else ts[i].surgeon
	teeth[who] = int(teeth.get(who, 0)) + n


func cheat_options(seat: int) -> Array:
	return [{"id": "peek_chart", "name": "peek at the other table's chart"}] if alive(seat) else []


func apply_cheat(seat: int, _cid: String) -> void:
	var i := team_of_seat(seat)
	if i >= 0:
		core.p(seat).known["organ_chart"] = ts[i].order.duplicate()


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var me := int(viewers[0]) if not viewers.is_empty() else -1
	var my_team := team_of_seat(me)
	var tv := []
	for i in 2:
		var st: Dictionary = ts[i]
		var is_patient := me == int(st.patient)
		var mine := my_team == i
		tv.append({"surgeon": st.surgeon, "patient": st.patient, "stage": stage_of(st), "stage_i": st.stage, "tool": st.tool,
			"mistakes": st.mistakes, "integrity": st.integrity, "pain": st.pain, "consciousness": st.consciousness, "panic": st.panic,
			"anaesthetic": st.anaesthetic, "bleed": st.bleed, "movement": st.movement, "still": st.still, "busy": st.busy,
			"done": float(st.done_t) >= 0.0, "valid": st.valid, "dead": st.dead, "unconscious": float(st.unconscious) > 0.0,
			"candidates": st.candidates.map(func(c): return {"name": "?" if not mine else c.name, "look": c.look, "side": c.side}),
			"cut": st.cut.duplicate(), "aim": st.aim, "clamped": st.clamped, "order_len": (st.order as Array).size(), "order_i": st.order_i,
			# what only the patient knows: the nerves, the chart, what's coming
			"nerves": st.nerves.duplicate() if is_patient else [], "order": st.order.duplicate() if is_patient else [],
			"warn": str(st.warn.get("kind", "")) if (is_patient or (mine and float(st.warn.get("t", 9.0)) <= WARN_SURGEON)) and not (st.warn as Dictionary).is_empty() else "",
			"force": st.force, "pulled": st.pulled, "jars": st.jars.duplicate(), "stolen": float(st.stolen) > 0.0, "jam": float(st.jam) > 0.0,
			"slippery": float(st.slippery) > 0.0})
	v.merge({"organ": organ_id, "organ_name": organ.name, "organ_look": organ.look, "organ_side": organ.side, "stages": stages(), "path": organ.path,
		"protected": organ.protected, "tolerance": organ.tolerance, "connections": organ.connections, "vessels": organ.vessels, "pulse": organ.pulse,
		"band": organ.band, "pull": organ.pull, "breath": organ.get("breath", false), "tables": tv, "modifiers": modifiers.duplicate(),
		"modifier_text": modifiers.map(func(m): return data.modifiers[m]), "callouts": callouts.duplicate(true), "awards": awards.duplicate(true),
		"my_team": my_team, "my_role": role_of(me), "presentation": "FULL_CHARACTER", "time_left": maxf(0.0, (90.0 if modifiers.has("time_limit") else LIMIT) - t),
		"sab_cd": float(sab_cd.get(me, 0.0))})
	return view_with_actions(v, viewers)


# --- AI: surgeons operate, patients cooperate -----------------------------------------

func ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	var i := team_of_seat(seat)
	if i < 0 or finish_t >= 0.0:
		return
	var st: Dictionary = ts[i]
	brain.wait += dt
	if role_of(seat) == "patient":
		if brain.wait < 0.5:
			return
		brain.wait = 0.0
		if float(st.panic) > 30.0 and brain.rng.randf() < 0.6:
			action(seat, {"do": "breathe", "ai_timing": brain.rng.randf() < 0.5 + brain.perception * 0.5})
		st.still = float(st.panic) > 40.0 or stage_of(st) in ["incise", "extract"]
		if float(st.consciousness) < 50.0:
			action(seat, {"do": "awake"})
		var honest := not modifiers.has("secret_patient") or brain.coop > 0.5
		if int(st.aim) >= 0 and stage_of(st) == "separate":
			var nerve := (st.nerves as Array).has(int(st.aim))
			action(seat, {"do": "call", "pick": ("stop" if nerve else "keep_going") if honest else ("keep_going" if nerve else "stop")})
		elif stage_of(st) == "disconnect" and int(st.order_i) < (st.order as Array).size() and brain.rng.randf() < 0.7:
			action(seat, {"do": "call", "pick": "next_%d" % int(st.order[int(st.order_i)])})
		elif not (st.warn as Dictionary).is_empty():
			action(seat, {"do": "call", "pick": "wrong"})
		elif float(st.anaesthetic) < 30.0:
			action(seat, {"do": "call", "pick": "hurts"})
		return
	# surgeon
	var think := 0.9 - brain.skill * 0.4
	if brain.wait < think or float(st.busy) > 0.0:
		return
	brain.wait = 0.0
	var good := brain.rng.randf() < 0.55 + brain.skill * 0.4
	if float(st.bleed) > 45.0:
		action(seat, {"do": "cautery"})
		return
	if float(st.anaesthetic) < 25.0 or _recent_call(i, "hurts"):
		action(seat, {"do": "syringe"})
		return
	if float(st.stolen) > 0.0:
		action(seat, {"do": "spare"})
		return
	var stage := stage_of(st)
	var want := str(data.instruments.get(stage, ""))
	if st.tool != want:
		action(seat, {"do": "tool", "pick": want if good else data.tray[brain.rng.randi_range(0, data.tray.size() - 1)]})
		return
	match stage:
		"locate":
			var k := 0
			for c in st.candidates.size():
				if st.candidates[c].real and good:
					k = c
				elif not good and brain.rng.randf() < 0.5:
					k = c
			action(seat, {"do": "locate", "pick": "ABCD"[k]})
		"incise":
			var pts := []
			var line: Array = organ.path
			for kk in 24:
				var f := kk / 23.0 * (line.size() - 1)
				var a0: Array = line[int(floor(f))]
				var a1: Array = line[mini(line.size() - 1, int(floor(f)) + 1)]
				var fr: float = f - floor(f)
				var noise := float(organ.tolerance) * (0.4 if good else 1.6)
				pts.append([lerpf(a0[0], a1[0], fr) + brain.rng.randf_range(-noise, noise), lerpf(a0[1], a1[1], fr) + brain.rng.randf_range(-noise, noise)])
			action(seat, {"do": "trace", "pts": pts})
		"separate":
			if int(st.aim) < 0:
				var opts := []
				for kk in int(organ.connections):
					if not st.cut.has(kk):
						opts.append(kk)
				if opts.is_empty():
					return
				action(seat, {"do": "aim", "pick": str(opts[brain.rng.randi_range(0, opts.size() - 1)] + 1)})
			else:
				# listen to the patient
				if _recent_call(i, "stop"):
					st.aim = -1
					var remaining := 0
					for kk in int(organ.connections):
						if not st.cut.has(kk) and not (st.nerves as Array).has(kk):
							remaining += 1
					return
				if _recent_call(i, "keep_going") or not good or brain.rng.randf() < 0.3:
					action(seat, {"do": "cut"})
		"clamp":
			var need: String = organ.vessels[int(st.clamped)]
			action(seat, {"do": "clamp", "pick": need if good else ["SMALL", "LARGE"][brain.rng.randi_range(0, 1)], "ai_timing": good})
		"disconnect":
			var said := _last_number(i)
			var n := said if said > 0 and (good or brain.coop > 0.3) else brain.rng.randi_range(1, maxi(1, (st.order as Array).size()))
			action(seat, {"do": "snip", "pick": str(n)})
		"extract":
			var band: Array = organ.band
			var mid := (float(band[0]) + float(band[1])) * 0.5
			action(seat, {"do": "pull", "on": float(st.force) < mid + (0.0 if good else 15.0)})
		"present":
			action(seat, {"do": "present", "pick": organ_id.to_upper() if good else st.jars[brain.rng.randi_range(0, st.jars.size() - 1)]})


func _recent_call(team: int, cid: String) -> bool:
	for c in callouts:
		if int(c.team) == team and c.id == cid and t - float(c.t) < 3.0:
			return true
	return false


func _last_number(team: int) -> int:
	for k in range(callouts.size() - 1, -1, -1):
		var c: Dictionary = callouts[k]
		if int(c.team) == team and str(c.id).begins_with("next_") and t - float(c.t) < 6.0:
			return int(str(c.id).substr(5))
	return 0
