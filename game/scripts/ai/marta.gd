class_name Marta
extends Monster
## Marta in the walls. She floats, still seated in a chair that isn't there, a cold light about
## her, the coral standing out of her back. She hunts by sound (and sees a little, if he's lit). The
## colour goes out of the world near her. She murmurs. What can be done about her:
##   evade her (quiet, dark, doors between); lure her (a noise somewhere else: a thrown thing, the
##   TV, the radio); hurt her (she breaks off, for a while); shock her (live water); calm her (one
##   of Sonya's red shoes, held out: for a while. Both: for good); know her (Old Name, and having
##   understood who she was: she stops); or, with the infection's Headshot, kill her.

const FRAGMENTS := ["...the boxes...", "Have you seen...", "Sonya, shoes.", "...little bird...", "...made of boxes..."]
var glow: Lamp
var shoes_given := 0
var calm_for := 0.0
var away_for := 0.0
var _murmur_t := 6.0
var _pressure: AudioStreamPlayer3D
var _wander_t := 0.0
var haunts: Array[Vector3] = []
var met := false

func _init() -> void:
	radius = 0.32; height = 1.25
	walk_speed = 0.9; hunt_speed = 1.85
	hearing = 1.4; sight = 6.0
	killable = false
	reach = 1.05
	can_break_doors = true

static func design_spec() -> Dictionary:
	return {"name": "marta", "height": 1.62, "neck": 0.17, "head": 0.1, "arm": 1.22, "hands": 1.45, "girth": 0.82,
		"skin": "skin_grey", "skin_tint": Color(0.82, 0.9, 0.8), "cloth": Color(0.24, 0.3, 0.48), "cloth_to": "knee",
		"face": "grin", "eyes": Color(0.85, 0.88, 0.86), "hair": Color(0.11, 0.09, 0.08), "face_flat": 0.8,
		"growths": [["chest", 6, 0.07, "coral"], ["arm_r", 4, 0.05, "coral"], ["neck", 3, 0.04, "coral"], ["head", 3, 0.05, "coral"], ["spine", 5, 0.08, "coral"], ["thigh_l", 3, 0.05, "coral"], ["forearm_l", 2, 0.04, "coral"]]}

func design() -> Dictionary:
	return design_spec()

func after_setup() -> void:
	glow = Lamp.make(self, global_position + Vector3(0, 1.3, 0.3), Color(0.62, 0.78, 0.86), 0.45, 2.8)
	glow.flicker = "glow"
	_pressure = Audio.loop("pressure", self, -80.0, 5.0)
	set_state(S.IDLE)

func float_above_floor() -> bool:
	return true

func animate(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var hunting := state == S.HUNT
	var look := Vector2.ZERO
	if state in [S.HUNT, S.TALK, S.GRAB] or (sees and state != S.DEAD):
		var to := global_transform.affine_inverse() * kurt.cam.global_position
		look = Vector2(clampf(atan2(-to.x, -to.z), -1.0, 1.0), clampf(atan2(to.y - 1.0, Vector2(to.x, to.z).length()), -0.6, 0.6))
	var calm := state in [S.CALM, S.SIT]
	body.pose({"sit": 1.0, "float_y": 0.38 + sin(t * 0.9) * 0.04, "reach": 0.9 if hunting and dist_to_kurt() < 2.6 else (0.35 if state == S.TALK else 0.0),
		"stoop": 0.55 if calm else (0.25 if state == S.IDLE else 0.05), "look": look if not calm else Vector2(0, -0.5),
		"twitch": 0.6 if hunting else 0.25, "tilt": sin(t * 0.37) * 0.2})
	glow.global_position = global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.3
	glow.color = Color(1.0, 0.75, 0.55) if calm else Color(0.62, 0.78, 0.86)
	# near her the colour goes out of things
	var d := dist_to_kurt()
	var want := clampf((d - 2.0) / 8.0, 0.15, 1.0) if state not in [S.DEAD, S.SIT] else 1.0
	Lights.tint.a = move_toward(Lights.tint.a, want, delta * 0.15)
	var feel := Progress.has("how_she_moves")
	_pressure.volume_db = linear_to_db(clampf(1.0 - d / (14.0 if feel else 7.0), 0.0001, 1.0)) - (2.0 if feel else 10.0)

func think(delta: float) -> void:
	_murmur(delta)
	match state:
		S.DEAD: return
		S.SIT:
			go_to(level.maze.chamber_center("N")); follow(walk_speed * 0.6, delta); return
		S.CALM:
			calm_for -= delta
			if calm_for <= 0.0: set_state(S.IDLE); return
			go_to(level.maze.chamber_center("N")); follow(walk_speed * 0.6, delta); return
		S.STAGGER:
			velocity = Vector3.ZERO
			if state_t > float(get_meta("stagger_for", 1.0)):
				away_for = 25.0; set_state(S.AWAY); go_to(_far_haunt())
			return
		S.STUNNED:
			velocity = Vector3.ZERO
			if state_t > 2.5: away_for = 30.0; set_state(S.AWAY); go_to(_far_haunt())
			return
		S.AWAY:
			away_for -= delta
			follow(walk_speed * 1.3, delta)
			if away_for <= 0.0: set_state(S.IDLE)
			return
		S.TALK:
			velocity = Vector3.ZERO; face_kurt(delta)
			if state_t > 30.0: set_state(S.AWAY); away_for = 12.0
			return
		S.GRAB:
			velocity = Vector3.ZERO
			return
	# meeting him the first time, with Socko on his hand: she stops. They talk. He doesn't understand.
	if sees and not met and World.flag("socko_on") and dist_to_kurt() < 7.0:
		met = true
		World.set_flag("marta_met")
		set_state(S.TALK)
		World.emit_event("marta_first_sight", {"m": self})
		return
	if sees and seen_t > (0.35 / Progress.aggression()):
		if state != S.HUNT: World.emit_event("hunted", {"id": id, "m": self})
		set_state(S.HUNT)
	match state:
		S.IDLE:
			velocity = Vector3.ZERO
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = randf_range(18.0, 34.0) / Progress.aggression()
				go_to(haunts[randi() % haunts.size()] if haunts.size() > 0 else home)
				set_state(S.PATROL)
		S.PATROL:
			if follow(walk_speed, delta): set_state(S.IDLE)
		S.INVESTIGATE:
			if follow(walk_speed * 1.35 * Progress.aggression(), delta):
				set_state(S.SEARCH)
		S.SEARCH:
			velocity = Vector3.ZERO
			rotation.y += sin(state_t * 1.3) * delta * 0.8
			if state_t > 10.0: set_state(S.IDLE)
		S.HUNT:
			if sees or state_t < 0.2:
				if _repath_t <= 0.0 or goal.distance_to(kurt.global_position) > 1.0:
					go_to(kurt.global_position); _repath_t = 0.6
			_repath_t -= delta
			follow(hunt_speed * Progress.aggression(), delta)
			if dist_to_kurt() < reach and absf(kurt.global_position.y - global_position.y) < 1.2:
				_reach_him()
			elif not sees and global_position.distance_to(last_known) < 0.8:
				set_state(S.SEARCH)
			elif not sees and state_t > 14.0:
				set_state(S.SEARCH)

func heard(n: Dictionary, k: float) -> void:
	if state == S.HUNT:
		if not sees and k > 0.3: go_to(heard_at)
		return
	if state in [S.IDLE, S.PATROL, S.SEARCH, S.INVESTIGATE] and k > 0.12:
		go_to(heard_at); set_state(S.INVESTIGATE)
		World.emit_event("marta_heard", {"kind": n.kind, "k": k})

func _far_haunt() -> Vector3:
	var best := home; var bd := 0.0
	for h in haunts:
		var d := h.distance_to(kurt.global_position)
		if d > bd: bd = d; best = h
	return best

## Within reach: a red shoe in his hand, and she takes that instead.
func _reach_him() -> void:
	if kurt.held and kurt.held.item.begins_with("shoe"):
		take_shoe(kurt.held)
		return
	grab()

func take_shoe(p: Prop) -> void:
	shoes_given += 1
	World.set_flag("gave_" + p.item)
	kurt.held = null
	p.queue_free()
	Audio.play("step_soft", global_position + Vector3(0, 1, 0), -4.0)
	if shoes_given >= 2 or (World.flag("gave_shoe_left") and World.flag("gave_shoe_right")):
		set_state(S.SIT)
		World.set_flag("marta_calmed")
		World.emit_event("marta_calmed", {"for_good": true})
		_say("...Sonya's.")
	else:
		calm_for = 120.0
		set_state(S.CALM)
		World.emit_event("marta_calmed", {"for_good": false})
		_say("...Sonya's. ...The other one.")

func _say(t: String) -> void:
	if Speech.speaking == "": Speech.say("marta", t, {"style": "quiet"})

func _murmur(delta: float) -> void:
	_murmur_t -= delta
	if _murmur_t > 0.0 or state in [S.DEAD, S.TALK, S.GRAB, S.SIT]: return
	_murmur_t = randf_range(7.0, 12.0)
	if dist_to_kurt() < 9.0 and Speech.speaking == "":
		Audio.play("snarl", global_position + Vector3(0, 1.2, 0), -8.0, randf_range(0.6, 0.8))
		if dist_to_kurt() < 5.0: _say(FRAGMENTS[randi() % FRAGMENTS.size()])

func get_verbs(k) -> Array:
	if state in [S.DEAD]: return []
	var v: Array = []
	if k.held and k.held.item.begins_with("shoe"):
		v.append({"id": "shoe", "label": "Hold out the shoe", "held": true})
	if state != S.SIT:
		v.append({"id": "talk", "label": "Talk to her"})
	return v

func hold_verbs(k, held) -> Array:
	if held.item.begins_with("shoe"): return [{"id": "shoe", "label": "Hold out the shoe", "held": true}]
	return []

func act(v: String, k) -> void:
	match v:
		"shoe":
			if k.held: take_shoe(k.held)
		"talk": _talk(k)

## What Kurt says depends on what he remembers.
func _talk(k) -> void:
	var knows: bool = Progress.has("old_name") and (Progress.found.has("drawing") or Progress.found.has("fridge_note") or World.flag("saw_poster"))
	set_state(S.TALK)
	if knows:
		await Speech.say("kurt", "Marta. It's me. It's Kurt.")
		await Speech.say("marta", "...You came back. You said far.")
		set_state(S.SIT)
		World.set_flag("marta_known")
		World.emit_event("marta_calmed", {"for_good": true, "known": true})
		Progress.remember("marta_known", 2)
	elif Progress.has("faces"):
		await Speech.say("kurt", "Marta? Marta, it's... it's me. I think it's me.")
		await Speech.say("marta", "...Have you seen...")
		calm_for = 20.0; set_state(S.CALM)
	else:
		await Speech.say("kurt", "Hey. Hey, easy...")
		set_state(S.HUNT)

func shot(part: String, by, at: Vector3) -> void:
	if part == "head" and Progress.has("headshot"):
		Audio.play("hit", at, 0.0)
		World.emit_event("monster_shot", {"id": id, "part": part, "m": self})
		glow.on = false
		Lights.tint.a = 1.0
		_pressure.volume_db = -80.0
		die(by)
		return
	super(part, by, at)

func struck_by(p: Prop, speed: float) -> void:
	if speed > 3.0:
		set_state(S.HUNT); last_known = kurt.global_position
		super(p, speed)

func shocked() -> void:
	Audio.play("snarl", global_position + Vector3(0, 1, 0), 2.0, 1.3)
	set_state(S.STUNNED)
	World.emit_event("marta_shocked", {})

func _save() -> Dictionary:
	var d := super()
	d["shoes"] = shoes_given; d["met"] = met; d["calm"] = calm_for
	return d

func _load(d: Dictionary) -> void:
	super(d)
	shoes_given = int(d.get("shoes", 0)); met = bool(d.get("met", false)); calm_for = float(d.get("calm", 0.0))
