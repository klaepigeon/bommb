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
		if me.get("ghost", false) and str(view.phase) == "turn" and int(view.turn.seat) == seat and view.turn.sub == "ghost":
			_t = 0.0
			Net.send_action(seat, {"t": "ghost", "do": "rise" if int(me.rats) >= int(view.get("resurrect_cost", 1)) else "scavenge"})
		return
	match str(view.phase):
		"intro", "mg_intro", "mg_results", "finale":
			Net.send_action(seat, {"t": "ready"})
			_t = 0.0
		"turn":
			var turn: Dictionary = view.turn
			if int(turn.seat) != seat:
				return
			_t = 0.0
			if turn.sub == "pre":
				Net.send_action(seat, {"t": "roll"})
			elif turn.sub == "room":
				Net.send_action(seat, {"t": "sit"})
			elif turn.sub == "prompt":
				var pr: Dictionary = turn.prompt
				if pr.is_empty():
					return
				match str(pr.kind):
					"door_stop", "hidden", "poison":
						Net.send_action(seat, {"t": "answer", "yes": false})
					"rat":
						Net.send_action(seat, {"t": "answer", "yes": true})
					"path":
						var opts: Array = pr.options.filter(func(o): return o.can)
						Net.send_action(seat, {"t": "answer", "to": int(opts[rng.randi_range(0, opts.size() - 1)].to)})
					"shop", "gamble", "gavel", "veto", "lever":
						Net.send_action(seat, {"t": "answer", "done": true, "wager": 0})
					"duel":
						Net.send_action(seat, {"t": "answer", "target": pr.options[0], "wager": 0})
					_:
						Net.send_action(seat, {"t": "answer", "target": pr.options[0]})
		"door":
			Net.send_action(seat, {"t": "push"})
		"mg_play":
			var mg: Dictionary = view.mg
			if not mg.get("seats", []).has(seat):
				return
			# the game's own controls: press what it offers, now and then
			var ctl: Array = mg.get("controls", [])
			if not ctl.is_empty() and str(ctl[0].kind) != "stick" and not mg.get("choice", false) and str(mg.get("id", "")) not in ["roulette", "hot_potato", "musical_chairs"]:
				if _t > 0.35:
					_t = 0.0
					var c: Dictionary = ctl[rng.randi_range(0, ctl.size() - 1)]
					match str(c.kind):
						"hold":
							Net.send_action(seat, {"t": "mg", "do": c.do, "on": rng.randf() < 0.6})
						"swipe":
							var d: Array = [[1, 0], [-1, 0], [0, 1], [0, -1]][rng.randi_range(0, 3)]
							Net.send_action(seat, {"t": "mg", "do": c.do, "dir": d})
						"pick":
							var o: Array = c.get("options", [])
							if not o.is_empty():
								Net.send_action(seat, {"t": "mg", "do": c.do, "pick": str(o[rng.randi_range(0, o.size() - 1)])})
						"trace":
							var pts := []
							for k in 12:
								pts.append([0.3 + k * 0.03, 0.4 + rng.randf() * 0.05])
							Net.send_action(seat, {"t": "mg", "do": c.do, "pts": pts})
						_:
							Net.send_action(seat, {"t": "mg", "do": c.do})
				return
			if mg.get("arena", false):
				var a := Time.get_ticks_msec() / 900.0 + seat
				Net.send_move(seat, Vector2(cos(a), sin(a) * 0.3 + 0.5).limit_length(1.0))
				return
			if mg.get("choice", false):
				var acts: Array = mg.get("actions", []).filter(func(x): return x.do == "choose")
				if not acts.is_empty() and _t > 1.5 and not mg.get("mine", {}).has(seat):
					_t = 0.0
					var pick: Dictionary = acts[rng.randi_range(0, acts.size() - 1)]
					Net.send_action(seat, {"t": "mg", "do": "choose", "choice": pick.choice})
				return
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
