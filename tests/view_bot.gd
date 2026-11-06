class_name ViewBot
extends RefCounted
## Plays a seat from the view alone, the way a remote human's screen would: used by the
## network tests to stand in for people on other machines (it only ever sends actions
## through Net, exactly like the touch buttons do).

var seat := 0
var _t := 0.0
var rng := RandomNumberGenerator.new()


func step(view: Dictionary, dt: float) -> void:
	_t += dt
	if view.is_empty() or _t < 0.4:
		return
	var me: Dictionary = view.players[seat]
	if not me.alive:
		return
	match str(view.phase):
		"intro", "mg_intro", "mg_results":
			Net.send_action(seat, {"t": "ready"})
			_t = 0.0
		"turn":
			var turn: Dictionary = view.turn
			if int(turn.seat) != seat:
				return
			_t = 0.0
			if turn.sub == "pre":
				Net.send_action(seat, {"t": "roll"})
			elif turn.sub == "prompt":
				var pr: Dictionary = turn.prompt
				if pr.kind == "door_stop":
					Net.send_action(seat, {"t": "answer", "yes": false})
				else:
					Net.send_action(seat, {"t": "answer", "target": pr.options[0]})
		"door":
			Net.send_action(seat, {"t": "push"})
		"mg_play":
			var mg: Dictionary = view.mg
			match str(mg.get("id", "")):
				"roulette":
					if mg.sub == "turn" and int(mg.turn) == seat:
						_t = 0.0
						Net.send_action(seat, {"t": "mg", "do": "pull"})
				"hot_potato":
					if int(mg.holder) == seat and mg.flight.is_empty() and _t > 0.8:
						_t = 0.0
						var others := []
						for p in view.players:
							if p.alive and p.seat != seat:
								others.append(p.seat)
						if not others.is_empty():
							Net.send_action(seat, {"t": "mg", "do": "pass", "target": others[rng.randi_range(0, others.size() - 1)]})
				"musical_chairs":
					var pos: Vector2 = mg.pos.get(seat, Vector2.ZERO)
					var want := Vector2.ZERO
					if mg.sub == "music":
						var a := atan2(pos.x, pos.y) + 0.5
						want = (Vector2(sin(a), cos(a)) * 3.6 - pos).limit_length(1.0)
					elif mg.sub == "scramble" and not mg.seated.has(seat):
						var best := INF
						for c in mg.chairs:
							if int(c.taken) == -1 and pos.distance_to(c.pos) < best:
								best = pos.distance_to(c.pos)
								want = ((c.pos as Vector2) - pos).normalized()
					Net.send_move(seat, want)
