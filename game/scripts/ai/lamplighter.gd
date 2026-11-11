class_name Lamplighter
extends Monster
## The lamplighter. Long, thin, a lamp where his face should be, a pole in his hand. He walks the
## west passages from bulb to bulb, counting them: "Thirteen... thirteen..." Where one's out he
## stops under it and waits for it to come back on, saying the number he got to. He can't abide
## anyone in his light: seen lit, Kurt's shoved out of it, hard, and he shouts. Pull the west fuse
## and he stands in the dark under the first dead bulb for as long as it stays dead. Somebody who
## knows walls (and has had the lights all on) can tell him it's thirteen, and he can stop.

var route: Array[Vector3] = []
var route_i := 0
var count := 0
var _say_t := 2.0
var light: Lamp

func _init() -> void:
	radius = 0.28; height = 2.05
	walk_speed = 0.75; hunt_speed = 1.6
	hearing = 0.6; sight = 7.0; fov = 0.5
	reach = 1.3
	head_hp = 2.0; body_hp = 4.0
	can_break_doors = false

func design() -> Dictionary:
	return {"name": "lamplighter", "height": 2.15, "neck": 0.22, "head": 0.08, "arm": 1.4, "hands": 1.3, "girth": 0.7,
		"skin": "skin_grey", "cloth": Color(0.12, 0.11, 0.1), "cloth_to": "foot", "hem": "floor", "shoes": true, "face": "lamp",
		"eyes": Color(1.0, 0.85, 0.5), "stoop": 0.25}

## One of the infected (InfectedBody, ported): a person the building took, built from a genome,
## with who they were written into it.
func make_body() -> Node3D:
	var g := InfectedGenome.generate(13)
	var over := {"height": 2.02, "hunch": 0.15, "build": 0.05, "clothes": "coat", "skin": "char", "growth": "bone", "growth_amount": 0.35, "quirk": "searching"}
	for k in over: g[k] = over[k]
	g.head.state = "whole" if g.head.state == "overgrown" else g.head.state
	var b := CreatureBody.InfectedFlesh.new()
	add_child(b)
	b.build(g)
	return b

func after_setup() -> void:
	light = Lamp.make(self, global_position + Vector3(0, 2.0, 0), Color(1.0, 0.8, 0.45), 0.5, 3.0)
	light.flicker = "candle"
	for b in get_tree().get_nodes_in_group("maze_bulbs"):
		if (b as Lamp).circuit == "M1": route.append((b as Lamp).global_position * Vector3(1, 0, 1))
	route.sort_custom(func(a, b): return a.z * 10.0 + a.x < b.z * 10.0 + b.x)
	set_state(S.PATROL)
	if route.size() > 0: go_to(route[0])

func animate(delta: float) -> void:
	body.pose(pose_ctx(delta))
	light.global_position = body.head_pos + Vector3(0, 0.05, 0)

func _bulb_live() -> bool:
	return Power.live("M1")

func think(delta: float) -> void:
	_say_t -= delta
	match state:
		S.SIT, S.DEAD: velocity = Vector3.ZERO; return
		S.PATROL:
			if follow(walk_speed, delta):
				if _bulb_live():
					count = route_i + 1
					route_i = (route_i + 1) % maxi(route.size(), 1)
					go_to(route[route_i])
				else:
					set_state(S.IDLE)
			if _say_t <= 0.0 and dist_to_kurt() < 8.0 and Speech.speaking == "":
				_say_t = randf_range(6.0, 9.0)
				Speech.say("lamplighter", "Thirteen... thirteen...", {"style": "quiet"})
		S.IDLE:
			velocity = Vector3.ZERO
			if _bulb_live(): set_state(S.PATROL); go_to(route[route_i])
			elif _say_t <= 0.0 and dist_to_kurt() < 8.0 and Speech.speaking == "":
				_say_t = 8.0; Speech.say("lamplighter", "...%s..." % ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen"][clampi(count, 0, 12)], {"style": "quiet"})
		S.HUNT:
			go_to(kurt.global_position)
			follow(hunt_speed, delta)
			if dist_to_kurt() < reach:
				kurt.hurt(12.0, self)
				kurt.velocity += (kurt.global_position - global_position).normalized() * 7.0
				Audio.play("snarl", global_position + Vector3(0, 1.8, 0), 3.0, 1.6)
				Noises.make(global_position, 22.0, "shout", self)
				set_state(S.PATROL); go_to(route[route_i])
			elif state_t > 6.0: set_state(S.PATROL); go_to(route[route_i])
		S.STAGGER:
			velocity = Vector3.ZERO
			if state_t > float(get_meta("stagger_for", 1.0)): set_state(S.HUNT)
	# someone in his light
	if state in [S.PATROL, S.IDLE] and sees and Lights.light_at(kurt.global_position + Vector3(0, 1, 0)) > 0.25 and dist_to_kurt() < 5.0:
		set_state(S.HUNT)

func heard(_n: Dictionary, _k: float) -> void:
	pass

func get_verbs(_k) -> Array:
	if state in [S.DEAD, S.SIT]: return []
	return [{"id": "talk", "label": "Talk to him"}]

func act(v: String, _k) -> void:
	if v != "talk": return
	if Progress.has("these_walls") and _bulb_live():
		set_state(S.SIT)
		await Speech.say("kurt", "It's thirteen. That's all of them. They're lit. You can stop now.")
		await Speech.say("lamplighter", "...Thirteen.")
		World.set_flag("lamplighter_calmed")
		World.emit_event("lamplighter_calmed", {})
		Progress.remember("lamplighter", 1)
		kurt.give_item("rounds", "Rounds", "Seven revolver rounds, wrapped in a page of a ledger.")
		kurt.spare += 7
	else:
		await Speech.say("kurt", "Hey. Can you hear me?")
		set_state(S.HUNT)
