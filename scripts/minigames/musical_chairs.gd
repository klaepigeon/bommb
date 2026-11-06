extends Minigame
## MINIGAME 01: MUSICAL CHAIRS, persistent and escalating.
##
## A ring of chairs (one more than there are players, and it never goes down). Music
## plays; walk. The music stops; you have three seconds to sit. Then the chairs do what
## they do. Some are rigged, each its own way, and every sub-round more of them are.
## Each rigged chair gives itself away, subtly, by sight and by sound (the tell): learn
## them. Standing is rude, and punished, but it's never lethal. Sitting on a safe chair
## pays.

const HAZARDS := {
	# id: [tell (seen), tell (heard), lethal from severity]
	"live_wire": ["spark", "hum", 2],
	"spring": ["bulge", "creak", 2],
	"trapdoor": ["seam", "draught", 1],
	"jaws": ["teeth", "chatter", 3],
	"clapper": ["glint", "tick", 3],
}
const ARENA_R := 5.6
const RING_R := 2.4
const SIT_R := 0.8
const WALK := 3.2
const SCRAMBLE := 3.0
const REVEAL := 3.0
const BETWEEN := 2.0

var sub := "ready"         # ready | music | scramble | reveal | between | over
var sub_t := 0.0
var music_len := 8.0
var round_i := 0
var rounds := 3
var chairs: Array = []     # {pos: Vector2, facing: float, hazard: String, taken: int}
var pos: Dictionary = {}   # seat -> Vector2
var move: Dictionary = {}  # seat -> Vector2 (wanted direction, length <= 1)
var seated: Dictionary = {}   # seat -> chair index
var revealed: Array = []   # [chair, hazard, seat] this sub-round


func id() -> String:
	return "musical_chairs"


func title() -> String:
	return "MUSICAL CHAIRS"


func instructions() -> Array:
	return ["Walk while the music plays.", "When it stops, SIT. You have three seconds.",
		"Some chairs are not nice chairs.", "Standing is rude."]


func setup() -> void:
	var n := maxi(seats.size() + 1, 3)
	for i in n:
		var a := TAU * i / n
		chairs.append({"pos": Vector2(sin(a), cos(a)) * RING_R, "facing": a, "hazard": "", "taken": -1})
	for k in seats.size():
		var a := TAU * (k + 0.5) / seats.size()
		pos[seats[k]] = Vector2(sin(a), cos(a)) * 4.0
		move[seats[k]] = Vector2.ZERO
	rounds = 3


func start() -> void:
	_begin_round()


func _begin_round() -> void:
	sub = "music"
	sub_t = 0.0
	seated.clear()
	revealed.clear()
	for c in chairs:
		c.taken = -1
	# Persistent: a rigged chair stays rigged (it keeps its tell), and one more joins it
	# every round. The chair count never drops.
	var n_bad := mini(chairs.size() - 2, 1 + level + round_i)
	var clean := []
	var used := []
	for i in chairs.size():
		if chairs[i].hazard == "":
			clean.append(i)
		else:
			used.append(chairs[i].hazard)
	_shuffle(clean)
	var kinds := HAZARDS.keys().filter(func(k): return not used.has(k))
	_shuffle(kinds)
	var have := chairs.size() - clean.size()
	for k in maxi(0, n_bad - have):
		chairs[clean[k]].hazard = kinds[k % kinds.size()] if not kinds.is_empty() else HAZARDS.keys()[rng.randi_range(0, 4)]
	# The ring is turned between rounds: the bad chairs move, their tells go with them.
	var turn := rng.randi_range(1, chairs.size() - 1)
	var hz := chairs.map(func(c): return c.hazard)
	for i in chairs.size():
		chairs[i].hazard = hz[(i + turn) % chairs.size()]
	music_len = rng.randf_range(5.0, 11.0)
	core.say("mc_music")
	core.emit({"e": "mg", "k": "music", "round": round_i})


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = a[i]
		a[i] = a[j]
		a[j] = x


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat):
		return
	if a.has("move"):
		var v: Vector2 = a.move if a.move is Vector2 else Vector2(a.move[0], a.move[1])
		move[seat] = v.limit_length(1.0)


func tick(dt: float) -> void:
	t += dt
	sub_t += dt
	match sub:
		"music":
			_walk(dt)
			if sub_t >= music_len:
				sub = "scramble"
				sub_t = 0.0
				core.say("mc_stop")
				core.emit({"e": "mg", "k": "stop"})
		"scramble":
			_walk(dt)
			_claim()
			if sub_t >= SCRAMBLE:
				_reveal()
		"reveal":
			if sub_t >= REVEAL:
				sub = "between"
				sub_t = 0.0
		"between":
			if sub_t >= BETWEEN:
				round_i += 1
				if round_i >= rounds or living().size() <= 1:
					sub = "over"
					done = true
				else:
					_begin_round()


func _walk(dt: float) -> void:
	for s in seats:
		if not alive(s) or seated.has(s):
			continue
		var sp := WALK * Body.speed(body(s), core.p(s).pk())
		var p: Vector2 = pos[s] + (move[s] as Vector2) * sp * dt
		if p.length() > ARENA_R:
			p = p.normalized() * ARENA_R
		# chairs are solid until the music stops
		for c in chairs:
			var d: Vector2 = p - c.pos
			var min_d := 0.55 if sub == "music" else 0.0
			if d.length() < min_d:
				p = c.pos + d.normalized() * min_d
		pos[s] = p


func _claim() -> void:
	for s in seats:
		if not alive(s) or seated.has(s):
			continue
		var best := -1
		var bd := SIT_R
		for i in chairs.size():
			if chairs[i].taken != -1:
				continue
			var d := (pos[s] as Vector2).distance_to(chairs[i].pos)
			if d < bd:
				bd = d
				best = i
		if best >= 0:
			chairs[best].taken = s
			seated[s] = best
			pos[s] = chairs[best].pos
			core.emit({"e": "mg", "k": "sit", "seat": s, "chair": best})


func _reveal() -> void:
	sub = "reveal"
	sub_t = 0.0
	# severity: how nasty the chairs are allowed to be (the last round is worse)
	var sev := level + (1 if round_i >= rounds - 1 else 0)
	var any_bad := false
	for s in seats:
		if not alive(s):
			continue
		if not seated.has(s):
			core.say("mc_standing", {"name": core.p(s).name})
			var part: String = ["leg_l", "leg_r", "arm_l", "arm_r"][rng.randi_range(0, 3)]
			core.injure(s, part, "bruised" if sev < 2 else "burned", "standing")
			tickets[s] -= 1
			notes.append("%s stood." % core.p(s).name)
			continue
		var ci: int = seated[s]
		var hz: String = chairs[ci].hazard
		if hz == "":
			tickets[s] += 2
			continue
		any_bad = true
		revealed.append([ci, hz, s])
		core.emit({"e": "mg", "k": "hazard", "seat": s, "chair": ci, "hazard": hz})
		core.say("mc_hazard_" + hz, {"name": core.p(s).name})
		_spring_hazard(s, hz, sev)
	# every rigged chair shows itself once it's over, sat on or not
	var all := []
	for i in chairs.size():
		if chairs[i].hazard != "":
			all.append([i, chairs[i].hazard])
	core.emit({"e": "mg", "k": "reveal_all", "chairs": all})
	if not any_bad:
		core.say("mc_safe")


func _spring_hazard(s: int, hz: String, sev: int) -> void:
	var lethal: bool = sev >= int(HAZARDS[hz][2])
	var nm := core.p(s).name
	match hz:
		"trapdoor":
			if lethal and core.kill(s, "trapdoor", [["leg_l", "broken"], ["leg_r", "broken"]]):
				notes.append("%s went through the floor." % nm)
			elif core.p(s).alive:
				# not deep enough yet: a drop to the cellar and back up the ladder
				core.injure(s, "leg_l", "broken", "trapdoor")
				notes.append("%s fell through the floor (not far)." % nm)
		"live_wire":
			if lethal and core.kill(s, "zap", [["hand_l", "burned"], ["hand_r", "burned"], ["ears", "broken"]]):
				notes.append("%s was electrocuted." % nm)
			elif core.p(s).alive:
				core.injure(s, "hand_l", "burned", "live wire")
				core.injure(s, "hand_r", "burned", "live wire")
				core.injure(s, "ears", "bruised" if sev < 1 else "broken", "live wire")
		"spring":
			if lethal and core.kill(s, "launch", [["leg_l", "broken"], ["leg_r", "broken"], ["eye_l", "broken"]]):
				notes.append("%s hit the ceiling." % nm)
			elif core.p(s).alive:
				core.injure(s, "leg_l", "broken", "spring")
				core.injure(s, "leg_r", "bruised" if sev < 2 else "broken", "spring")
		"jaws":
			if lethal and core.kill(s, "jaws", [["leg_l", "lost"]]):
				notes.append("%s was eaten by a cushion." % nm)
			elif core.p(s).alive:
				var leg := "leg_l" if core.p(s).body.leg_l.s != "lost" else "leg_r"
				core.injure(s, leg, "lost", "jaws")
				notes.append("%s lost a leg to the cushion." % nm)
		"clapper":
			if lethal and core.kill(s, "clapper", [["hand_l", "lost"]]):
				notes.append("%s was clapped." % nm)
			elif core.p(s).alive:
				var hand := "hand_r" if core.p(s).body.hand_r.s != "lost" else "hand_l"
				core.injure(s, hand, "lost", "clapper")
				notes.append("%s lost a hand to the armrests." % nm)


func view_for(_viewers: Array) -> Dictionary:
	var v := base_view()
	var cv := []
	for c in chairs:
		var tell := ""
		var heard := ""
		if c.hazard != "":
			tell = HAZARDS[c.hazard][0]
			heard = HAZARDS[c.hazard][1]
		# what a rigged chair IS stays hidden until it goes off; how it gives itself away doesn't
		cv.append({"pos": c.pos, "facing": c.facing, "tell": tell, "sound": heard, "taken": c.taken})
	var rv := []
	if sub in ["reveal", "between"]:
		rv = revealed.duplicate()
	v.merge({"sub": sub, "sub_t": sub_t, "round": round_i, "rounds": rounds, "chairs": cv, "pos": pos.duplicate(),
		"seated": seated.duplicate(), "revealed": rv, "scramble": SCRAMBLE})
	return v


# --- AI -----------------------------------------------------------------------------

var _ai: Dictionary = {}   # seat -> {target, believe: {chair: bool}, ang}


func ai(seat: int, brain: AiBrain, view: Dictionary, dt: float) -> void:
	var me: Vector2 = view.pos[seat]
	var st: Dictionary = _ai.get(seat, {"target": -1, "believe": {}, "ang": atan2(me.x, me.y), "round": -1, "sub": ""})
	_ai[seat] = st
	if view.seated.has(seat):
		action(seat, {"move": Vector2.ZERO})
		return
	if view.sub == "music":
		st.target = -1
		if st.round != view.round:
			st.round = view.round
			st.believe = {}
			# Looking the chairs over as they pass: a tell is noticed or not, by how well
			# this contestant sees and hears (the same tells a human sees and hears).
			var b := body(seat)
			for i in view.chairs.size():
				var c: Dictionary = view.chairs[i]
				if c.tell == "":
					st.believe[i] = false
				else:
					var p := brain.perception * (0.55 * Body.sight(b) + 0.45 * Body.hearing(b))
					st.believe[i] = brain.rng.randf() < 0.15 + 0.7 * p
		# circle the ring
		st.ang += 0.6 * dt
		var want := Vector2(sin(st.ang), cos(st.ang)) * 3.6
		action(seat, {"move": (want - me).limit_length(1.0) * 1.5})
		return
	if view.sub == "scramble":
		var tgt: int = st.target
		if tgt == -1 or view.chairs[tgt].taken != -1:
			tgt = -1
			var bd := INF
			for i in view.chairs.size():
				var c: Dictionary = view.chairs[i]
				if c.taken != -1 or st.believe.get(i, false):
					continue
				var d := me.distance_to(c.pos)
				if d < bd:
					bd = d
					tgt = i
			if tgt == -1 and brain.greed > 0.7:
				# all the free ones look wrong; a greedy one gambles anyway
				for i in view.chairs.size():
					if view.chairs[i].taken == -1:
						tgt = i
						break
			st.target = tgt
		if tgt == -1:
			action(seat, {"move": Vector2.ZERO})
		else:
			action(seat, {"move": ((view.chairs[tgt].pos as Vector2) - me).normalized()})
		return
	action(seat, {"move": Vector2.ZERO})
