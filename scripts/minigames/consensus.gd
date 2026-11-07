extends ChoiceGame
## THE CONSENSUS (FFA). Three doors. Everyone votes for one. If you all agree, everyone is
## rewarded (and that's a draw, everyone equal: you know what a draw does). Every round you
## don't agree costs more: a bruise each, then Teeth and a break, then the minority
## lose something for good. Negotiate. Promise. Break the promise.

const DOORS := ["THE RED DOOR", "THE BLUE DOOR", "THE GREEN DOOR"]
var agreed := false


func id() -> String:
	return "consensus"


func title() -> String:
	return "THE CONSENSUS"


func instructions() -> Array:
	return ["Vote for a door.", "All the same: everyone is rewarded.", "Not all the same: everyone pays, more every round.",
		"SAY what you'll vote. Mean it, or don't."]


func setup() -> void:
	rounds = 3
	options = DOORS.duplicate()


func begin_round() -> void:
	prompt = ["Choose a door. Agree, and nobody gets hurt.", "Again. It'll cost more this time.", "Last chance. The ones who don't agree lose something."][mini(round_i, 2)]


func resolve(revealed: Dictionary) -> bool:
	var count := {}
	for s in revealed.keys():
		count[revealed[s]] = count.get(revealed[s], 0) + 1
	if count.size() == 1:
		agreed = true
		core.say("consensus_yes")
		for s in revealed.keys():
			teeth[s] += 4
		finish(revealed.keys(), true)
		return true
	core.say("consensus_no")
	var top_n := 0
	for k in count.keys():
		top_n = maxi(top_n, count[k])
	for s in revealed.keys():
		if not alive(s):
			continue
		match round_i:
			0:
				var part := Body.random_severable(body(s), rng)
				if part != "":
					core.injure(s, part, "bruised", "disagreement")
			1:
				core.economy.take(s, 2, "disagreement")
				var part := Body.random_severable(body(s), rng)
				if part != "":
					core.injure(s, part, "broken", "disagreement")
			_:
				if count[revealed[s]] < top_n:
					var part := Body.random_severable(body(s), rng)
					if part != "":
						core.injure(s, part, "lost", "the minority")
	return false


func conclude() -> void:
	if done:
		return
	# no agreement: the biggest bloc wins (a tie is a draw)
	var count := {}
	for s in last_reveal.keys():
		count[last_reveal[s]] = count.get(last_reveal[s], 0) + 1
	var top_n := 0
	var tops := []
	for k in count.keys():
		if count[k] > top_n:
			top_n = count[k]
			tops = [k]
		elif count[k] == top_n:
			tops.append(k)
	if tops.size() != 1:
		finish([], true)
		return
	finish(last_reveal.keys().filter(func(s): return last_reveal[s] == tops[0] and alive(s)), false)


func cheat_options(seat: int) -> Array:
	var out := super.cheat_options(seat)
	if sub == "choose" and choices.has(seat):
		for o in choices.keys():
			if o != seat and choices[o] != choices[seat]:
				out.append({"id": "rig:%d" % o, "name": "change %s's vote to yours" % core.p(o).name})
	return out


func apply_cheat(seat: int, cid: String) -> void:
	if cid.begins_with("rig:"):
		var o := int(cid.substr(4))
		if choices.has(o) and choices.has(seat):
			choices[o] = choices[seat]
			core.toast("%s's slip now says %s." % [core.p(o).name, choices[seat]], seat)
		return
	super.apply_cheat(seat, cid)


func ai_choice(seat: int, brain: AiBrain):
	# follow what most people said they'd do (the cooperative ones), or go your own way
	var count := {}
	for o in claims.keys():
		count[claims[o]] = count.get(claims[o], 0) + 1
	var best = null
	var bn := 0
	for k in count.keys():
		if count[k] > bn:
			bn = count[k]
			best = k
	if best != null and brain.coop >= 0.3:
		return best
	return DOORS[brain.rng.randi_range(0, 2)] if brain.coop < 0.5 else DOORS[0]
