class_name SockoTutorial
extends Node
## Socko teaching (story bible §6, "Socko — tutorial"): each line once, the first time it's
## relevant, never over another line, with a short control hint under the objective. The lines are
## the bible's, unchanged; so are their seeds (impatience with looking; the violent aside; the
## knowing "you've done this before").
##
##   walk     after the introduction, once he's walked a few steps
##   crouch   prompted if he hasn't crouched a while after that; praised the first time he does
##   pickup   the first thing he picks up
##   inspect  turning something over for a few seconds
##   noise    the first loud thing he drops or throws (Socko turns to it)
## Not yet: pistol, reloading, bath, bolt, sparing/killing her. Those need the systems.

var socko: Socko
var player: Node
var hud: SockoHud
var said := {}
var _walked := 0.0
var _last_pos := Vector3.ZERO
var _since_walk := -1.0
var _inspect_t := 0.0
var _queue: Array = []            # [key, text, emotion, volume, hint, gesture, target]
var _gap := 0.0
var touch := false

func setup(p_socko: Socko, p_player: Node, p_hud: SockoHud) -> void:
	socko = p_socko; player = p_player; hud = p_hud
	add_to_group("listener")

func _key(k: String, pad: String, tap: String) -> String:
	if player.get("touch_ui"): return tap
	if Input.get_connected_joypads().size() > 0: return pad
	return k

func _say(key: String, text: String, emo := "neutral", vol := 1.0, hint := "", g := "", target = null) -> void:
	if said.has(key):
		return
	said[key] = true
	_queue.append([key, text, emo, vol, hint, g, target])

func _process(delta: float) -> void:
	if not Game.flags.get("socko_intro_done", false):
		_last_pos = player.global_position
		return
	if not said.has("_objective"):
		said["_objective"] = true
		hud.set_objective("Find a way out of Flat 47.", true)
	# walking
	var p: Vector3 = player.global_position
	_walked += Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	if _walked > 2.0:
		_say("walk", "Walk it off. Slow. Your knee's making noises I don't like.", "nervous", 0.9, _key("[Shift] hurry  ·  [C] crouch", "[L3] hurry  ·  [Y] crouch", "Push the stick to the rim to hurry"))
		if _since_walk < 0.0: _since_walk = 0.0
	if _since_walk >= 0.0:
		_since_walk += delta
	# crouching: prompted, then the knowing praise
	if player.get("crouched"):
		_say("crouch_done", "There you go — you've done this before, huh?", "curious", 0.9)
		said["crouch_ask"] = true
	elif _since_walk > 25.0:
		_say("crouch_ask", "Get low. Lower.", "neutral", 0.8, _key("[C] crouch", "[Y] crouch", "CROUCH"))
	# picking up, turning over
	var held = player.get("held")
	if held != null:
		_say("pickup", "Heavy end first. Throw it like you mean it. Or — you know where it'd really land? On her.", "happy", 1.0,
			_key("[LMB] throw  ·  [RMB] turn it over  ·  [E] put it down", "[RT] throw  ·  [LT] turn it over  ·  [A] put it down", "THROW  ·  USE to put it down"))
		if player.get("inspecting"):
			_inspect_t += delta
			if _inspect_t > 2.5:
				_say("inspect", "Turn it over. Yeah. Fascinating. Can we go?", "impatient", 0.85)
		else:
			_inspect_t = 0.0
	# speak when he's free
	_gap -= delta
	if _queue.size() > 0 and not socko.talking and _gap <= 0.0:
		var q: Array = _queue.pop_front()
		if q[5] != "": socko.gesture(q[5], q[6])
		socko.say(q[1], q[2], q[3])
		if q[4] != "": hud.show_hint(q[4])
		_gap = 1.2

## Noise (Noises.make): the first loud thing he drops or throws gets the lesson.
func hear(pos: Vector3, loud: float, what: String, source: Node) -> void:
	if not Game.flags.get("socko_intro_done", false):
		return
	if what == "impact" and loud > 0.3 and source == player:
		socko.notice(pos, 2.0)
		_say("noise", "Hear that? She hears it too. Everything you drop, she hears.", "nervous", 0.75)
