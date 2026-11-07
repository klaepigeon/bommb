extends ChoiceGame
## PICK YOUR POISON (FFA). A row of bottles, one more than there are of you. Each one is
## something: a poison off his shelf, a stimulant, THE CURE. Pick one (no two the same),
## then everyone drinks. What you drink stays with you on the board. If he isn't looking:
## read a label, or swap your bottle with someone else's after they've picked.

var contents: Dictionary = {}   # bottle -> poison id
var labels := ["A", "B", "C", "D", "E", "F"]


func id() -> String:
	return "pick_your_poison"


func title() -> String:
	return "PICK YOUR POISON"


func instructions() -> Array:
	return ["Pick a bottle. Nobody else can have the same one.", "Then everybody drinks.",
		"Whatever's in it stays in you, on the board, for a while.", "Read a label or swap bottles, if he's not looking."]


func setup() -> void:
	rounds = 1
	var n := seats.size() + 1
	options = labels.slice(0, n)
	var pool: Array = core.status.catalogue.keys()
	pool.erase("cure")
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = pool[i]
		pool[i] = pool[j]
		pool[j] = x
	contents[options[0]] = "cure"
	for k in range(1, n):
		contents[options[k]] = pool[(k - 1) % pool.size()]
	# shuffle which bottle the cure is in
	var keys := options.duplicate()
	var vals := keys.map(func(k): return contents[k])
	for i in range(vals.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = vals[i]
		vals[i] = vals[j]
		vals[j] = x
	for i in keys.size():
		contents[keys[i]] = vals[i]


func begin_round() -> void:
	prompt = "Pick a bottle."


func can_choose(seat: int, c) -> bool:
	for o in choices.keys():
		if o != seat and choices[o] == c:
			return false
	return true


func resolve(revealed: Dictionary) -> bool:
	var fine: Array = []
	for s in revealed.keys():
		if not alive(s):
			continue
		var what: String = contents[revealed[s]]
		var harm: bool = core.status.catalogue.get(what, {}).get("harm", false)
		if not harm and tip(s, "poison"):
			# he swapped it while you weren't looking
			var bad := core.status.harmful_ids()
			what = bad[rng.randi_range(0, bad.size() - 1)]
			harm = true
		core.status.apply(s, what, "drank bottle " + str(revealed[s]))
		notes.append("%s drank %s." % [core.p(s).name, core.status.name_of(what)])
		if not harm:
			fine.append(s)
			rats[s] += 3
	finish(fine, fine.is_empty() or fine.size() == revealed.size())
	return true


func conclude() -> void:
	if not done:
		finish([], true)


func cheat_options(seat: int) -> Array:
	if sub != "choose":
		return []
	var out := []
	for o in options:
		out.append({"id": "read:" + str(o), "name": "read bottle %s's label" % o})
	if choices.has(seat):
		for o in choices.keys():
			if o != seat:
				out.append({"id": "swap:%d" % o, "name": "swap bottles with %s" % core.p(o).name})
	return out


func apply_cheat(seat: int, cid: String) -> void:
	if cid.begins_with("read:"):
		var b := cid.substr(5)
		core.toast("Bottle %s: %s." % [b, core.status.name_of(contents[b])], seat)
		if not peeked.has(seat):
			peeked[seat] = {}
		peeked[seat]["bottle_" + b] = contents[b]
	elif cid.begins_with("swap:"):
		var o := int(cid.substr(5))
		if choices.has(o) and choices.has(seat):
			var x = choices[o]
			choices[o] = choices[seat]
			choices[seat] = x
			core.toast("You swap your bottle for %s's." % core.p(o).name, seat)


func ai_choice(seat: int, brain: AiBrain):
	# a peeked-at cure first; otherwise anything free
	for k in peeked.get(seat, {}).keys():
		if str(k).begins_with("bottle_") and peeked[seat][k] == "cure":
			var b := str(k).substr(7)
			if can_choose(seat, b):
				return b
	return super.ai_choice(seat, brain)


func ai(seat: int, brain: AiBrain, view: Dictionary, dt: float) -> void:
	if view.sub == "choose" and not choices.has(seat) and brain.coop < 0.35 and brain.rng.randf() < dt * 0.4:
		core.action(seat, {"t": "mg_cheat", "id": "read:" + str(options[brain.rng.randi_range(0, options.size() - 1)])})
	super.ai(seat, brain, view, dt)
