class_name SockoLabyrinth
extends Node
## Socko's agenda behind the wardrobe (story bible §2c, owner's direction; the lines are new and
## PROPOSED). He wants Marta dead and the tutorial rushed: no reading, no looking. He steers Kurt
## straight to the revolver, cheers the nuggets, pushes Headshot, wants the shot taken. He waves
## every clue away; in the nursery he goes still and quiet, and then lies. He never says why.
## Lines once each (unless marked), never over himself, never over Marta.

var socko: Socko
var player: Node
var main: Node
var hud: SockoHud
var said := {}
var _queue: Array = []
var _gap := 0.0
var _nudge_t := 14.0
var _last_cell := Vector2i(-99, -99)
var _hunter: MartaHunter
var _skills: SkillMenu
var _woke_marta := false
var _in_nursery := 0.0

func setup(p_socko: Socko, p_player: Node, p_main: Node, p_hud: SockoHud, p_hunter: MartaHunter, p_skills: SkillMenu) -> void:
	socko = p_socko; player = p_player; main = p_main; hud = p_hud; _hunter = p_hunter; _skills = p_skills
	_hunter.seen_kurt.connect(func(): _say("seen", "There she is. Don't think. Aim for the head.", "angry", 1.1, 0.0, false, true))
	_hunter.hurt.connect(func(head: bool): _say("hurt%d" % Time.get_ticks_msec(), "Again! Again!" if not head else "Oh, that's it. That's it!", "furious" if head else "angry", 1.2, 0.0, true))
	_hunter.died.connect(func():
		_say("dead", "Trickshot's still got it!", "happy", 1.2, 0.0, false, true)
		_say("dead2", "What? It's a… word. Come on.", "lying", 0.9, 1.2))
	# he gave her the shoe. Socko hates this.
	_hunter.calmed.connect(func(for_good: bool):
		if for_good:
			_say("peace", "…", "uncanny", 0.5, 0.5, false, true)
			_say("peace2", "She's still in there, you know. In case you were wondering. Gun works fine on sad people.", "angry", 0.9, 4.0)
		else:
			_say("calm1", "No. No no no. What are you doing? She was RIGHT THERE. Shoot her!", "furious", 1.2, 0.2, false, true)
			_say("calm2", "…Fine. Your way. Your slow, slow way.", "disappointed", 0.8, 2.0))
	_hunter.held_kurt.connect(func(): _say("held%d" % Time.get_ticks_msec(), "Up. Up. She's had her go. Now we have ours.", "angry", 1.0, 4.5, true))
	_skills.bought.connect(func(id: String):
		if id == "headshot": _say("bought_hs", "There we go. Now we're friends.", "happy", 1.0, 0.3)
		elif Skills.tree_of(id) == "memory": _say("bought_mem%s" % id, "…Really? That? Okay. Your nuggets.", "disappointed", 0.8, 0.3, true))

## Queue a line. Reactions go stale (a cheer three lines late is worse than none); the big
## moments (`urgent`) cut in: they clear what's waiting and are said next.
func _say(key: String, text: String, emo := "neutral", vol := 1.0, delay := 0.0, repeat := false, urgent := false) -> void:
	if said.has(key) and not repeat: return
	said[key] = true
	var at := Time.get_ticks_msec() + int(delay * 1000.0)
	var entry := [text, emo, vol, at, at + (4000 if repeat else 40000), repeat]
	if urgent:
		# cut in: throwaway reactions waiting are dropped; the rest wait their turn behind it
		_queue = _queue.filter(func(e): return not e[5])
		_queue.push_front(entry)
	else:
		_queue.append(entry)

func _process(delta: float) -> void:
	if not socko or not socko.visible: return
	var f: Dictionary = Game.flags
	# the shortcut
	if f.get("wardrobe_pushed", false):
		_say("gap", "Huh. Would you look at that. A shortcut.", "happy", 0.9)
	var inside: bool = main.get("in_labyrinth")
	if inside:
		_say("arrive", "Don't stop. Don't look. Something of yours is down here. This way.", "happy", 1.0, 0.8)
		_guide(delta)
		# the clues: waved away
		var waves := {"looked_photograph": ["Old photo. Dead people. Come on.", "lying"], "looked_note": ["Don't read other people's mail, bud.", "impatient"],
			"looked_newspaper": ["Old news. Literally.", "impatient"], "looked_poster": ["Huh. Some fella. Gun's that way.", "lying"],
			"looked_mask": ["Nope. Not your colour. Put it down.", "lying"], "looked_quiver": ["Arrows? We're past arrows. We've got a gun.", "impatient"],
			"looked_photo strip": ["…Anyway.", "uncanny"], "looked_glasses": ["Somebody had a nice night. Come on.", "impatient"],
			"looked_register": ["Paperwork. Boring.", "lying"], "looked_letters": ["Nobody's reading those, bud.", "lying"], "tried_sonya_door": ["Leave it.", "uncanny"]}
		for k in waves:
			if f.get(k, false): _say(k, waves[k][0], waves[k][1], 0.85, 0.6)
		# the nursery: he goes quiet, dead still, eyes on nothing; then the lie
		var lab: Labyrinth = main.get("labyrinth")
		var p: Vector3 = lab.to_local(player.global_position)
		var r: Dictionary = Interiors.NURSERY
		if p.x > r.x0 and p.x < r.x1 and p.z > r.z0 and p.z < r.z1:
			_in_nursery += delta
			socko.stillness = 1.0; socko.set_emotion("uncanny")
			if f.get("looked_drawing", false): _say("drawing", "Nothing in here. Let's go.", "lying", 0.7, 2.5)
			if _in_nursery > 9.0: _say("nursery", "Nothing in here. Let's go.", "lying", 0.7)
		elif _in_nursery > 0.0:
			_in_nursery = 0.0; socko.stillness = 0.0; socko.set_emotion("neutral")
	# the revolver
	if f.get("has_revolver", false):
		_say("gun", "Ooh. Now we're talking. You know what that's for.", "happy", 1.0, 0.4, false, true)
		if not _woke_marta:
			_woke_marta = true
			get_tree().create_timer(5.0).timeout.connect(func(): if not Game.flags.get("marta_dead", false): _hunter.wake())
		var g = player.get("gun")
		if g and bool(g.get("reloading")):
			_say("reload", "Look at you go. Did you see your hands? I didn't teach you that.", "curious", 0.9, 0.5)
	# the nuggets and the tree
	if Skills.nuggets() > 0:
		_say("nugget", "Ooh, shiny. Grab those. Grab all of those.", "happy", 1.0)
	if Skills.nuggets() >= 8 and not Skills.owned("headshot"):
		if not said.has("enough"):
			hud.show_hint("[K] skills" if not player.get("touch_ui") else "Pause → Skills", 7.0)
		_say("enough", "You've got enough. Headshot. Trust me.", "lying", 0.9)
	# speak when he's free
	_gap -= delta
	var now := Time.get_ticks_msec()
	while _queue.size() > 0 and now > int(_queue[0][4]):
		_queue.pop_front()                 # gone stale
	if _queue.size() > 0 and not socko.talking and _gap <= 0.0 and now >= int(_queue[0][3]):
		var q: Array = _queue.pop_front()
		socko.say(q[0], q[1], q[2])
		_gap = 0.9

## Steering: to the revolver, by the shortest way through the town. At turns, and when Kurt
## dawdles, he points down the way and says so.
func _guide(delta: float) -> void:
	if Game.flags.get("has_revolver", false): return
	var lab: Labyrinth = main.get("labyrinth")
	var here := lab.to_local(player.global_position)
	var cell := Vector2i(floori(here.x / Labyrinth.CELL), floori(here.z / Labyrinth.CELL))
	var goal := lab.fight.gun_at.origin
	var next := _next_cell(lab, cell, Vector2i(floori(goal.x / Labyrinth.CELL), floori(goal.z / Labyrinth.CELL)))
	var aim := lab.to_global(lab.center(next.x, next.y) + Vector3(0, 1.0, 0)) if next != cell else lab.to_global(goal)
	if cell != _last_cell:
		_last_cell = cell; _nudge_t = minf(_nudge_t, 10.0)
		socko.attend(aim, 2.0)
	_nudge_t -= delta
	if _nudge_t <= 0.0 and not socko.talking:
		_nudge_t = randf_range(16.0, 24.0)
		socko.gesture("point", aim)
		var lines := ["This way, bud.", "Keep going. Don't read the signs.", "You don't need to see that. Gun first.", "Left, right, whatever. Come on."]
		socko.say(lines[randi() % lines.size()], "impatient", 0.9)

func _next_cell(lab: Labyrinth, from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to: return from
	var prev := {from: from}
	var q := [from]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		if c == to: break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + d
			if prev.has(nc) or nc.x < 0 or nc.x > 15 or not lab.is_street(nc.x, nc.y): continue
			prev[nc] = c; q.append(nc)
	if not prev.has(to): return from
	var c2 := to
	while prev[c2] != from: c2 = prev[c2]
	return c2
