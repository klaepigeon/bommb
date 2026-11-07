class_name ArenaGame
extends Minigame
## The shared floor for every game where people move about (THE LAST SEAT, MEAT GRINDER,
## DEAD WEIGHT, RUN FOR YOUR LIFE, BETTER TOGETHER, HUMAN SHIELD): positions on a rectangle,
## joystick movement at a speed set by your legs (Body.speed), bodies that bump, a PUSH
## (shove whoever's in front of you), carrying something (slower), ghosts' cold spots
## (slow you to a crawl), and a stun. Subclasses add the objects and the rules.

var bounds := Rect2(-6, -4.5, 12, 9)      # x, z
var pos: Dictionary = {}                   # seat -> Vector2
var move: Dictionary = {}                  # seat -> wanted direction
var facing: Dictionary = {}                # seat -> last direction
var stun: Dictionary = {}                  # seat -> seconds
var carry: Dictionary = {}                 # seat -> what they're holding ("" for nothing)
var cold: Array = []                       # [{pos, r, t}]
var objects: Array = []                    # drawn by the arena view: [{kind, pos, size, ...}]
var walk := 2.8
var push_cd: Dictionary = {}


func place_start(points: Array) -> void:
	for k in seats.size():
		var s: int = seats[k]
		pos[s] = points[k % points.size()]
		move[s] = Vector2.ZERO
		facing[s] = Vector2.RIGHT
		carry[s] = ""


func speed_of(s: int) -> float:
	var sp := walk * Body.speed(body(s), core.p(s).pk())
	if carry.get(s, "") != "":
		sp *= 0.7
	for c in cold:
		if (pos[s] as Vector2).distance_to(c.pos) < c.r:
			sp *= 0.35
	if tampered(s):
		sp *= 1.15
	if handicapped.has(s):
		sp *= 0.75
	if is_chilled(s):
		sp *= 0.5
	return sp


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat):
		return
	if a.has("move"):
		var v: Vector2 = a.move if a.move is Vector2 else Vector2(a.move[0], a.move[1])
		move[seat] = v.limit_length(1.0)
		if v.length() > 0.2:
			facing[seat] = v.normalized()
	if str(a.get("do", "")) == "push":
		push(seat)
	arena_action(seat, a)


## Subclasses: their own buttons.
func arena_action(_seat: int, _a: Dictionary) -> void:
	pass


func push(seat: int) -> void:
	if push_cd.get(seat, 0.0) > 0.0 or stun.get(seat, 0.0) > 0.0:
		return
	push_cd[seat] = 1.2
	var hands := Body.hands(body(seat))
	var me: Vector2 = pos[seat]
	for o in living():
		if o == seat:
			continue
		var d: Vector2 = pos[o] - me
		if d.length() < 1.1 and d.normalized().dot(facing[seat]) > 0.2:
			var force := 1.4 * clampf(hands / 2.0, 0.4, 1.0) * (1.2 - 0.4 * Body.balance(body(o)))
			pos[o] = clamp_in(pos[o] + d.normalized() * force)
			stun[o] = 0.6
			carry_drop(o)
			core.emit({"e": "mg", "k": "push", "seat": seat, "target": o})
			on_pushed(o, seat)


func on_pushed(_victim: int, _by: int) -> void:
	pass


func carry_drop(_s: int) -> void:
	pass


func clamp_in(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, bounds.position.x, bounds.end.x), clampf(p.y, bounds.position.y, bounds.end.y))


## Move everyone this frame (call from tick). Things that hold people still (seated, in
## a chain) can override can_move().
func walk_all(dt: float) -> void:
	tick_chill(dt)
	for s in seats:
		if not alive(s):
			continue
		push_cd[s] = maxf(0.0, push_cd.get(s, 0.0) - dt)
		if stun.get(s, 0.0) > 0.0:
			stun[s] -= dt
			continue
		if not can_move(s):
			continue
		var p: Vector2 = pos[s] + (move[s] as Vector2) * speed_of(s) * dt + drift(s) * dt
		pos[s] = clamp_in(p)
	# bodies bump
	var l := living()
	for i in l.size():
		for j in range(i + 1, l.size()):
			var a: int = l[i]
			var b: int = l[j]
			var d: Vector2 = pos[b] - pos[a]
			if d.length() < 0.5 and d.length() > 0.001:
				var push_v := d.normalized() * (0.5 - d.length()) * 0.5
				pos[a] -= push_v
				pos[b] += push_v
	for c in cold:
		c.t -= dt
	cold = cold.filter(func(c): return c.t > 0.0)


func can_move(_s: int) -> bool:
	return true


## Things that move you without asking (conveyors, current): per second.
func drift(_s: int) -> Vector2:
	return Vector2.ZERO


func ghost_action(seat: int, a: Dictionary) -> void:
	if str(a.get("do", "")) == "cold":
		var at: Vector2 = a.get("at", Vector2.ZERO) if a.get("at") is Vector2 else Vector2.ZERO
		cold.append({"pos": clamp_in(at), "r": 1.2, "t": 4.0})
		core.emit({"e": "mg", "k": "cold", "seat": seat})
		return
	super.ghost_action(seat, a)


func controls(_seat: int) -> Array:
	var out: Array = [{"kind": "stick"}]
	for a in actions_for(_seat):
		out.append({"kind": "tap", "do": a.do, "label": a.name})
	return out


func ghost_ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	brain.wait += dt
	if brain.wait < 5.0:
		return
	brain.wait = 0.0
	# a cold spot on whoever's winning (or, a kind ghost, behind whoever's losing)
	var l := living()
	if l.is_empty():
		return
	var t: int = l[brain.rng.randi_range(0, l.size() - 1)]
	ghost_action(seat, {"do": "cold", "at": pos[t] + facing.get(t, Vector2.RIGHT) * 0.8})


## AI: head for a point.
func steer(seat: int, target: Vector2) -> void:
	var d: Vector2 = target - pos[seat]
	move[seat] = d.limit_length(1.0) if d.length() > 0.15 else Vector2.ZERO
	if d.length() > 0.2:
		facing[seat] = d.normalized()


func nearest_other(seat: int) -> int:
	var best := -1
	var bd := INF
	for o in living():
		if o != seat and (pos[o] as Vector2).distance_to(pos[seat]) < bd:
			bd = (pos[o] as Vector2).distance_to(pos[seat])
			best = o
	return best


func arena_view() -> Dictionary:
	var cv := []
	for c in cold:
		cv.append({"pos": c.pos, "r": c.r})
	return {"pos": pos.duplicate(), "objects": objects.duplicate(true), "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"carry": carry.duplicate(), "stun": stun.duplicate(), "cold": cv, "arena": true}
