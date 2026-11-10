class_name SockoFlat48
extends Node
## Socko in Flat 48 (master document §38; the example lines are the owner's, the rest PROPOSED).
## He wants the three figures shot. He never says so. He makes distance sound sensible, curiosity
## sound reckless, the names sound like a trick; he approves the moment Kurt aims; and when Kurt
## won't, he changes tack: impatience, then the priorities speech, then pretending he never said
## anything of the kind. What Kurt did with his advice is remembered (Game.flags
## "socko_advice_followed" / "socko_advice_rejected") for later.

var main: Node
var flat: Flat48
var socko: Node
var player: Node
var said := {}
var _gap := 0.0
var _queue: Array = []
var _aim_t := 0.0
var _refuse_t := 0.0
var _refusals := 0


func setup(p_main: Node) -> void:
	main = p_main; flat = main.flat48; socko = main.socko; player = main.player
	flat.transformed.connect(_on_transformed)

func _say(key: String, text: String, emo := "neutral", vol := 1.0, repeat := false) -> void:
	if said.has(key) and not repeat: return
	said[key] = true
	_queue.append([text, emo, vol])

func _on_transformed(_node: Node, what: String) -> void:
	match what:
		"GUN SAFE": _say("safe", "Ooh. Now that one I like.", "happy")
		"OPENED": _say("opened", "Well, would you look at that. Somebody planned ahead.", "curious")
		"SHOTGUN":
			_say("gun", "Two barrels. That's one each for two of them, and a quick reload.", "happy")
			_say("gun2", "I'm just counting. Somebody has to.", "lying", 0.8)
		"SHOT":
			Game.flags["socko_advice_followed"] = int(Game.flags.get("socko_advice_followed", 0)) + 1
			var n := 0
			for g in flat.figures: if g.down: n += 1
			if n == 1: _say("shot1", "There we are. Much simpler.", "happy", 1.1)
			elif n == 2: _say("shot2", "I knew you'd figure it out.", "happy", 1.1)
			else: _say("shot3", "And that's the family. See? Quiet now.", "uncanny", 0.8)
		"DRESSED_MAMA":
			_say("dress_mama", "Huh. Look at that. She cleans up.", "lying", 0.85)
		"DRESSED_PAPA":
			_say("dress_papa", "…", "uncanny", 0.4)
			_say("dress_papa2", "That's not funny. Who's that supposed to be? Don't answer that.", "angry", 0.9)
		"NOT SONYA":
			_say("not_sonya", "See? Nothing. Nobody's here. Let's go.", "lying", 0.8)
		_:
			# a block made real: he doesn't like the flat explaining itself
			if said.has("real1"): _say("real2", "You're looking for reasons to trust them.", "impatient", 0.9)
			else: _say("real1", "Could be someone wanted you to find all this.", "lying", 0.9)

func _process(delta: float) -> void:
	if not main.in_flat48 or not socko or not socko.visible: return
	var p: Vector3 = player.global_position
	var near_fig: Node = null; var near_d := 99.0
	for g in flat.figures:
		if g.down: continue
		var d: float = p.distance_to(g.global_position)
		if d < near_d: near_d = d; near_fig = g
	_say("arrive", "Huh. It's 47. Somebody drew it from memory and ran out of crayons.", "curious", 0.9)
	if near_fig and near_d < 6.0: _say("family", "Well. That's a family.", "uncanny", 0.8)
	if near_fig and near_d < 2.0:
		_say("close", "I wouldn't get too close.", "nervous", 0.9)
		if near_d < 1.2: _say("close2", "Don't let them get close enough to surprise you.", "nervous", 0.9)
	var looked := 0
	for id in ["mama", "papa", "child"]:
		if Game.flags.get("f48_looked_" + id, false): looked += 1
	if looked >= 1: _say("looked", "You don't know what they are.", "impatient", 0.9)
	if looked >= 2: _say("looked2", "Mama. Papa. Child. That's supposed to make this better?", "lying", 0.9)
	var notes: Array = Game.flags.get("f48_notes_taken", [])
	if notes.size() >= 1: _say("notes", "Words. We're sticking words on furniture now.", "disappointed", 0.85)
	if notes.size() >= 4: _say("notes2", "I think you're giving this a little too much attention.", "impatient", 0.85)
	# the gun out, a figure in the sights: he likes that very much
	var g = player.get("gun")
	var aiming_at_fig := false
	if g and g.get("drawn") and near_fig:
		var t = player.get("target")
		var cam: Camera3D = player.get("cam")
		var to: Vector3 = (near_fig.global_position + Vector3(0, 1.0, 0)) - cam.global_position
		aiming_at_fig = (-cam.global_basis.z).angle_to(to.normalized()) < deg_to_rad(6.0) and to.length() < 12.0
	_aim_t = _aim_t + delta if aiming_at_fig else 0.0
	if _aim_t > 0.8: _say("aim", "There we are.", "happy", 0.7)
	# he has the shotgun, he's near them, and he isn't using it: the refusals
	if Game.flags.get("has_shotgun", false) and near_fig and near_d < 4.0 and not aiming_at_fig:
		_refuse_t += delta
		if _refuse_t > 20.0 and _refusals == 0:
			_refusals = 1; _say("refuse1", "You're making this harder than it needs to be.", "impatient")
		elif _refuse_t > 45.0 and _refusals == 1:
			_refusals = 2; _say("refuse2", "I thought we were trying to get out of here. We have our own problems.", "angry")
		elif _refuse_t > 75.0 and _refusals == 2:
			_refusals = 3; _say("refuse3", "You can't save everybody, bud.", "disappointed")
		elif _refuse_t > 110.0 and _refusals == 3:
			# and then he never said anything of the sort
			_refusals = 4; _say("refuse4", "What? I didn't say shoot them. When did I say shoot them? I said keep your distance.", "lying")
			Game.flags["socko_advice_rejected"] = int(Game.flags.get("socko_advice_rejected", 0)) + 1
	# speak when he's free
	_gap -= delta
	if _queue.size() > 0 and not socko.get("talking") and not main.speech.in_conversation() and _gap <= 0.0:
		var q: Array = _queue.pop_front()
		socko.call("say", q[0], q[1], q[2])
		_gap = 1.2
