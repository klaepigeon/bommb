extends ChoiceGame
## CONFESSION (FFA). He asks about each other. First everyone answers, privately (a name).
## Then everyone predicts which name came up most. Right: Dead Rats. Wrong: a pin. Say what
## you picked (or don't; or lie about it). Most right predictions wins.

const QUESTIONS := ["Who here would sell you out first?", "Who deserves the next pin?", "Who's lying to you right now?",
	"Who would you leave behind?", "Who will he kill next?", "Who here isn't really your friend?"]

var question := ""
var tally: Dictionary = {}
var correct: Dictionary = {}


func id() -> String:
	return "confession"


func title() -> String:
	return "CONFESSION"


func instructions() -> Array:
	return ["He asks a question about the people at this table. Answer with a name.", "Then guess which name came up most.",
		"Right: Dead Rats. Wrong: a pin.", "Say what you picked. Or lie."]


func setup() -> void:
	rounds = 6
	for s in seats:
		correct[s] = 0


func begin_round() -> void:
	options = living().map(func(s): return int(s))
	if round_i % 2 == 0:
		question = QUESTIONS[rng.randi_range(0, QUESTIONS.size() - 1)]
		prompt = question
	else:
		prompt = "Which name came up most for: \"%s\"" % question


func resolve(revealed: Dictionary) -> bool:
	if round_i % 2 == 0:
		tally.clear()
		for s in revealed.keys():
			tally[revealed[s]] = tally.get(revealed[s], 0) + 1
		return false
	var top := -1
	var tn := -1
	for k in tally.keys():
		if tally[k] > tn:
			tn = tally[k]
			top = k
	core.toast("Most of you said: %s (%d)." % [describe(top), tn])
	for s in revealed.keys():
		if not alive(s):
			continue
		if revealed[s] == top:
			correct[s] += 1
			rats[s] += 2
		else:
			var part := Body.random_severable(body(s), rng)
			if part != "":
				core.injure(s, part, "bruised" if level == 0 else "broken", "a wrong answer")
	return false


func conclude() -> void:
	var best := -1
	var top: Array = []
	for s in living():
		if correct[s] > best:
			best = correct[s]
			top = [s]
		elif correct[s] == best:
			top.append(s)
	finish(top if top.size() == 1 else [], top.size() != 1)


func ai_choice(seat: int, brain: AiBrain):
	if round_i % 2 == 0:
		var r := brain.rival(core, seat)
		return r if r >= 0 and brain.coop < 0.6 else options[brain.rng.randi_range(0, options.size() - 1)]
	# predict: what people said they'd pick
	var count := {}
	for o in claims.keys():
		count[claims[o]] = count.get(claims[o], 0) + 1
	var best = options[0]
	var bn := -1
	for k in count.keys():
		if count[k] > bn and options.has(k):
			bn = count[k]
			best = k
	return best
