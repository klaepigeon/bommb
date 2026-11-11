class_name Flat48Chapter
extends Node
## Socko in Flat 48 (master document §38; the example lines are the owner's, the rest PROPOSED in
## the story bible). He wants the three figures shot. He never says so. He makes distance sound
## sensible, curiosity sound reckless, the names sound like a trick; he approves the moment Kurt
## aims; and when Kurt won't, he changes tack: impatience, then the priorities speech, then
## pretending he never said anything of the kind. What Kurt did with his advice is remembered
## (Game.flags "socko_advice_followed" / "socko_advice_rejected").

signal left

var flat: Flat48
var player: Player
var weapon: Weapon
var hud: Hud
var active := false
var _said := {}
var _queue: Array[String] = []
var _gap := 0.0
var _aim_t := 0.0
var _refuse_t := 0.0
var _refusals := 0

func setup() -> void:
	flat.transformed.connect(_on_transformed)
	flat.entry.tried.connect(func(_d): left.emit())

func say(id: String) -> void:
	if _said.has(id):
		return
	_said[id] = true
	_queue.append(id)

func _on_transformed(what: String, _thing: Node) -> void:
	match what:
		"GUN SAFE": say("f48_safe")
		"OPENED": say("f48_opened")
		"SHOTGUN":
			say("f48_gun"); say("f48_gun2")
		"SHOT":
			Game.flags["socko_advice_followed"] = int(Game.flags.get("socko_advice_followed", 0)) + 1
			var n := 0
			for g in flat.figures:
				if g.down:
					n += 1
			say("f48_shot%d" % clampi(n, 1, 3))
		"DRESSED_MAMA": say("f48_dress_mama")
		"DRESSED_PAPA":
			say("f48_dress_papa"); say("f48_dress_papa2")
		"NOT SONYA": say("f48_not_sonya")
		"REAL":
			# a block made real: he doesn't like the flat explaining itself
			say("f48_real2" if _said.has("f48_real1") else "f48_real1")

## Is he pointing a gun at one of them?
func aiming_at_figure() -> Node:
	if weapon.held not in ["gun", "shotgun"]:
		return null
	var cam := player.camera
	for g in flat.figures:
		if g.down:
			continue
		var to: Vector3 = (g.global_position + Vector3(0, g.tall * 0.6, 0)) - cam.global_position
		if to.length() < 12.0 and (-cam.global_transform.basis.z).angle_to(to.normalized()) < deg_to_rad(6.0):
			return g
	return null

func _process(delta: float) -> void:
	if not active or not player.socko.visible:
		return
	var p := player.global_position
	var near_fig: Node = null
	var near_d := 99.0
	for g in flat.figures:
		if g.down:
			continue
		var d: float = p.distance_to(g.global_position)
		if d < near_d:
			near_d = d; near_fig = g
	say("f48_arrive")
	if near_fig and near_d < 6.0 and player.camera.is_position_in_frustum(near_fig.global_position + Vector3(0, 1.0, 0)):
		say("f48_family")
	if near_fig and near_d < 2.0:
		say("f48_close")
		if near_d < 1.2:
			say("f48_close2")
	var looked := 0
	for id in ["mama", "papa", "child"]:
		if Game.flag("f48_looked_" + id):
			looked += 1
	if looked >= 1:
		say("f48_looked")
	if looked >= 2:
		say("f48_looked2")
	var notes: Array = Game.flags.get("f48_notes_taken", [])
	if notes.size() >= 1:
		say("f48_notes")
	if notes.size() >= 4:
		say("f48_notes2")
	# a gun out, a figure in the sights: he likes that very much
	var target := aiming_at_figure()
	_aim_t = _aim_t + delta if target else 0.0
	if _aim_t > 0.8:
		say("f48_aim")
	# he has the shotgun, he's near them, and he isn't using it: the refusals
	if Game.has_shotgun and near_fig and near_d < 4.0 and target == null:
		_refuse_t += delta
		if _refuse_t > 20.0 and _refusals == 0:
			_refusals = 1; say("f48_refuse1")
		elif _refuse_t > 45.0 and _refusals == 1:
			_refusals = 2; say("f48_refuse2")
		elif _refuse_t > 75.0 and _refusals == 2:
			_refusals = 3; say("f48_refuse3")
		elif _refuse_t > 110.0 and _refusals == 3:
			# and then he never said anything of the sort
			_refusals = 4; say("f48_refuse4")
			Game.flags["socko_advice_rejected"] = int(Game.flags.get("socko_advice_rejected", 0)) + 1
	# he speaks when there's room to
	_gap -= delta
	if _queue.size() > 0 and Speech.speaking == "" and _gap <= 0.0:
		Speech.say_id(_queue.pop_front())
		_gap = 1.4
