extends Node
## Plays the game through its real systems and checks it. Kurt is driven the way a player drives
## him: he's pointed at things (the real raycast decides what he's looking at) and the verbs on
## them are used; where he walks, he's moved along the Nav graph a step at a time. Each route ends
## AUTOTEST PASS or AUTOTEST FAIL <why>; the process exits 0 / 1.
##   --route=scene_a | poke | kick | maze | shoes | axe | shoot | service | systems | save | monsters | touch | all

var main
var k: Kurt
var level: Level
var story: Story
var fails: Array[String] = []
var checks := 0

func run(m) -> void:
	main = m; k = m.kurt; level = m.level; story = m.story
	Speech.fast = true
	await get_tree().create_timer(0.5).timeout
	var route := String(main.args.get("route", "scene_a"))
	var routes: Array = [route]
	if route == "all":
		routes = ["scene_a"]
	print("AUTOTEST route ", route)
	for r in routes:
		await call("r_" + r)
	if fails.is_empty():
		print("AUTOTEST PASS %s (%d checks)" % [route, checks])
		get_tree().quit(0)
	else:
		for f in fails: print("AUTOTEST FAIL ", f)
		get_tree().quit(1)

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok: print("AUTOTEST ok   ", what)
	else: print("AUTOTEST FAIL ", what); fails.append(what)

func wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout

func until(cond: Callable, timeout: float, what := "") -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t > timeout:
			if what != "": check(false, "timed out: " + what)
			return false
	return true

## Turns Kurt's head to a point.
func look(p: Vector3) -> void:
	var d := p - k.cam.global_position
	k.yaw = atan2(-d.x, -d.z)
	k.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	k.rotation.y = k.yaw
	k.head.rotation.x = k.pitch
	await get_tree().physics_frame
	await get_tree().physics_frame

## Looks at a thing and uses the verb with that id on whatever the raycast finds there.
func use(p: Vector3, verb: String) -> bool:
	await look(p)
	k._aim()
	for i in k.target_verbs.size():
		if String(k.target_verbs[i].id) == verb:
			k.use_verb(i)
			await get_tree().physics_frame
			return true
	check(false, "no verb '%s' at %s (got %s on %s)" % [verb, str(p), str(k.target_verbs.map(func(v): return v.id)), str(k.target)])
	return false

## Walks along the Nav graph the way a player could: through open doors (opening unlocked ones),
## never through locked ones, crouching through the crawl hole.
func walk_to(p: Vector3, speed := 3.0) -> void:
	var a := level.nav.nearest(k.global_position, 4.0)
	var b := level.nav.nearest(p, 4.0)
	var pass_ok := func(d):
		if d is Flat47: return 0.0 if World.flag("wardrobe_moved") else -1.0
		if d is Door: return 0.0 if (d.is_open() or d.broken or not d.locked()) else -1.0
		return 0.0
	var path := level.nav.path(a, b, pass_ok)
	if path.is_empty():
		check(false, "no way from %s to %s" % [str(k.global_position), str(p)]); return
	for i in path.size():
		if i > 0:
			var d = level.nav.door_between(path[i - 1], path[i])
			if d is Door and not d.is_open() and not d.broken:
				d.swing(d.max_angle, 0.3)
				await wait(0.5)
		var q: Vector3 = level.nav.pts[path[i]]
		k.crouching = q.z > 7.0 and q.z < 9.0 and q.x > 5.0 and q.x < 6.2
		await _step_to(q, speed)
	await _step_to(p, speed)
	k.crouching = false

func _step_to(p: Vector3, speed: float) -> void:
	var guard := 0
	while Vector2(k.global_position.x - p.x, k.global_position.z - p.z).length() > 0.15 and guard < 400:
		guard += 1
		var to := (p - k.global_position) * Vector3(1, 0, 1)
		var st := minf(speed * get_physics_process_delta_time(), to.length())
		k.global_position += to.normalized() * st
		k.velocity = Vector3.ZERO
		await get_tree().physics_frame

func said(id: String) -> bool:
	return Speech.history.has(id)

func lines_in_order(ids: Array) -> bool:
	var at := -1
	for id in ids:
		var i := Speech.history.find(id, at + 1)
		if i < 0: return false
		at = i
	return true

# ---------------------------------------------------------------------------------- routes
func r_scene_a() -> void:
	await until(func(): return story.phase == "inside", 30.0, "the door opens")
	check(lines_in_order(["door_1", "door_2"]), "the knocks: both lines, in order")
	await walk_to(Vector3(8.4, 0, 4.5))
	await until(func(): return said("see_flat"), 5.0, "Christ...")
	await walk_to(Flat47.POINTS.living_in)
	await look(Flat47.MARTA_SEAT + Vector3(0, 1.0, 0))
	await until(func(): return said("see_marta"), 5.0, "Oh... oh no.")
	await walk_to(Flat47.POINTS.near_marta)
	await use(Flat47.MARTA_SEAT + Vector3(0, 1.0, 0), "examine")
	await until(func(): return World.flag("socko_on") and not k.frozen, 60.0, "waking, and Socko")
	check(lines_in_order(["door_1", "door_2", "see_flat", "see_marta", "examine", "boxes", "marta_q", "little_bird", "gasp", "smarts", "hey_buddy", "wtf", "who_me", "who_are_you", "im_socko", "kurt_sounds", "dont_know", "got_nothing", "too_fast"]), "Scene A: every line, in the owner's order")
	check(level.flat.doors["dLiving"].locked(), "the living room door is locked after the blackout")
	check(level.flat.doors["dEntry"].padlock, "the front door is padlocked")
	check(socko.visible, "Socko is on the hand")
	await walk_to(Flat47.POINTS.by_door)
	await use(level.flat.doors["dLiving"].handle_pos(), "open")
	await until(func(): return said("like_helping"), 20.0, "the door lines")
	check(lines_in_order(["wont_open", "locked", "thanks", "welcome", "like_helping"]), "the door: every line, in order")

var socko: Socko:
	get: return story.socko

func _woken() -> void:
	await until(func(): return World.flag("socko_on") and not k.frozen, 20.0, "awake")

func r_poke() -> void:
	await _woken()
	var mag: Prop = level.flat.props["prop_37_Magazine"]
	await walk_to(mag.global_position + Vector3(0.4, 0, 0.4))
	await use(mag.global_position, "pocket")
	check(k.has_item("magazine"), "took the magazine")
	await walk_to(Flat47.POINTS.by_door)
	k.hold_from_pocket("magazine")
	var d: Door = level.flat.doors["dLiving"]
	await use(d.handle_pos() + Vector3(0, -0.6, 0), "slide_under")
	check(d.under_door == "magazine", "the magazine is under the door")
	await look(d.handle_pos())
	k._aim()
	check(k.target != null and k.target.has_method("socko_verbs") and k.target.socko_verbs(k).size() > 0, "Socko can be asked to poke the key out")
	story.mind.command(k.target, "poke")
	await until(func(): return d.key_in == "", 10.0, "the key poked out")
	await use(d.handle_pos(), "pull_under")
	check(k.has_item("living_key"), "the key came under the door on the magazine")
	await use(d.handle_pos(), "unlock")
	await use(d.handle_pos(), "open")
	await wait(1.2)
	check(d.is_open(), "the living room door is open")
	await walk_to(Vector3(6.5, 0, 4.5))
	check(k.zone == 4, "Kurt's in the hall")

func r_kick() -> void:
	await _woken()
	var d: Door = level.flat.doors["dLiving"]
	await walk_to(Flat47.POINTS.by_door)
	var heard := [false]
	Noises.made.connect(func(n): if n.kind == "bang": heard[0] = true)
	for i in 5:
		if d.broken: break
		await use(d.handle_pos(), "kick")
		await wait(0.4)
	check(d.broken, "four kicks and it gives")
	check(heard[0], "kicking is loud")
	await wait(1.0)
	check(d.is_open(), "it's open")

func r_maze() -> void:
	await _woken()
	await walk_to(Flat47.POINTS.by_wardrobe)
	for i in 3:
		await use(level.flat.wardrobe.global_position + Vector3(0, 1.0, -0.3), "push")
		await wait(0.8)
	check(World.flag("wardrobe_moved"), "the wardrobe's out of the doorway")
	await until(func(): return said("smell"), 20.0, "the wardrobe lines")
	check(lines_in_order(["what_is_that", "dunno", "know_anything", "can_do_this", "smell"]), "the wardrobe: every line, in order")
	await walk_to(level.maze.center(9, 1))
	check(level.zone_of(k.global_position) == 20, "into the walls")
	# the gun's hanging out of reach. Power the hanging room's circuit and everything falls.
	var br: AABB = level.maze.chambers["B"]
	await walk_to(level.maze.chamber_center("B"))
	await use(Vector3(br.end.x - 0.08, 1.5, br.get_center().z), "flip_M3")
	check(Power.live("M3"), "the hanging room's circuit is live")
	await wait(2.5)
	var gun: Prop = get_tree().get_first_node_in_group("gun")
	check(gun.global_position.y < 0.6, "the revolver fell (%.2f)" % gun.global_position.y)
	await walk_to(gun.global_position + Vector3(0.5, 0, 0))
	await use(gun.global_position, "pocket")
	check(k.has_item("revolver") and k.gun_out and k.rounds == 4, "the revolver, four rounds")
	check(story.mind.obeyed >= 1.0, "Socko liked that")

func r_shoes() -> void:
	await _woken()
	# the left shoe's in the hall, the right one in the bath: through the walls to Sonya's room
	level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe()
	await wait(0.8)
	await walk_to(level.maze.center(12, 0))
	await walk_to(Vector3(5.6, 0, 7.2))
	check(k.zone == 6, "through the crawl hole into Sonya's room")
	await walk_to(Vector3(7.5, 0, 6.85))
	await use(Vector3(6.75, 0.62, 7.6), "reach")
	check(k.has_item("padlock_key") and k.has_item("shoe_right"), "the bath: the key and her other shoe")
	check(Progress.shards >= 1, "the black water got in (a shard)")
	var shoe: Prop = level.flat.props["prop_40_Child_s_shoe"]
	await walk_to(Vector3(9.2, 0, 4.5))
	await use(shoe.global_position, "pocket")
	check(k.has_item("shoe_left"), "the left shoe")
	# Marta
	var m: Marta = story.marta
	m.met = true
	m.global_position = k.global_position + Vector3(-2.5, 0, 0)
	m.set_state(Monster.S.HUNT)
	k.hold_from_pocket("shoe_left")
	await until(func(): return m.state == Monster.S.CALM, 10.0, "she takes the shoe")
	m.calm_for = 0.0
	await wait(0.3)
	m.global_position = k.global_position + Vector3(-2.0, 0, 0)
	m.set_state(Monster.S.HUNT)
	k.hold_from_pocket("shoe_right")
	await until(func(): return m.state == Monster.S.SIT, 10.0, "both shoes: she's calm for good")
	check(World.flag("marta_calmed"), "Marta calmed")
	check(story.mind.defiance >= 3.0, "Socko didn't like it (defiance %.1f)" % story.mind.defiance)
	# out the front door with the small key
	var fd: Door = level.flat.doors["dEntry"]
	await use(fd.handle_pos(), "unpadlock")
	check(not fd.padlock and not fd.chained, "padlock off with the key")
	await use(fd.handle_pos(), "open")
	await wait(1.0)
	await walk_to(Vector3(12.4, 0, 5.4))
	await until(func(): return World.flag("ended", false) != false, 15.0, "out to the landing")
	check(said("end_out_calm"), "Socko: 'Shoes. You gave her shoes.'")

func r_axe() -> void:
	await _woken()
	level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe()
	await wait(0.8)
	var axe: Prop = level.flat.props["prop_120_Axe"]
	await walk_to(Flat47.POINTS.boxroom)
	await use(axe.global_position + Vector3(0, 0.25, 0), "lift")
	check(k.held == axe, "the axe in hand")
	# through the walls, Sonya's room, the hall
	await walk_to(level.maze.center(12, 0))
	await walk_to(Vector3(5.6, 0, 7.2))
	await walk_to(Vector3(9.4, 0, 4.4))
	var fd: Door = level.flat.doors["dEntry"]
	for i in 3:
		await use(fd.get_meta("lock_at"), "smash")
		await wait(0.3)
	check(not fd.padlock, "three blows with the axe")
	await use(fd.handle_pos(), "open")
	await wait(1.0)
	check(fd.is_open(), "the front door opens")

func r_shoot() -> void:
	await _woken()
	k.give_item("revolver", "Revolver"); k.rounds = 4; k.draw_gun()
	await walk_to(Vector3(9.4, 0, 4.4))
	k.global_position = Vector3(9.3, 0, 4.4)
	var fd: Door = level.flat.doors["dEntry"]
	await look(fd.get_meta("lock_at"))
	k.aiming = true
	await wait(0.3)
	for i in 3:
		if not fd.padlock: break
		await look(fd.get_meta("lock_at"))
		k.fire()
		await wait(0.6)
	check(not fd.padlock, "the padlock shot off")
	check(k.rounds <= 2, "it cost bullets")

func r_service() -> void:
	await _woken()
	level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe()
	await wait(0.8)
	story._dormant(story.super_, true)
	# a fuse: out of the flat's dead circuit C (it's tripped anyway), into the walls' M2
	await walk_to(level.maze.center(12, 0))
	await walk_to(Vector3(5.6, 0, 7.2))
	await walk_to(Vector3(8.95, 0, 4.4))
	await use(Vector3(9.05, 1.62, 3.9), "out_C")
	check(k.has_item("fuse"), "a fuse from the flat's box")
	await walk_to(level.maze.chamber_center("B"))
	var br: AABB = level.maze.chambers["B"]
	await use(Vector3(br.end.x - 0.08, 1.5, br.get_center().z), "in_M2")
	check(Power.live("M2"), "the service side is live")
	await walk_to(level.maze.center(20, 1))
	await use(level.maze.center(20, 1) + Vector3(0.6, 1.0, -0.55), "release")
	await until(func(): return World.flag("service_open", false) != false, 5.0, "the service door opens")
	await _step_to(level.maze.center(20, 1) + Vector3(0.6, 0, -0.35), 2.0)
	await until(func(): return World.flag("ended", false) != false, 10.0, "out by the service door")

func r_systems() -> void:
	await _woken()
	# light: never more than eight lamps in the shader, and nothing reaches through a wall
	var used := 0
	for s in Lights.slots: if s != null: used += 1
	check(used <= Lights.SLOTS, "the light engine holds %d lamps (max %d)" % [used, Lights.SLOTS])
	# power: a fuse out kills its lamps
	var a_lamps: Array = Lights.lamps.filter(func(l): return l.circuit == "A")
	Power.set_fuse("A", false)
	check(not a_lamps[0].powered(), "no fuse, no light")
	Power.set_fuse("A", true)
	check(a_lamps[0].powered(), "fuse back, light back")
	# water: the bath drains; overflow runs onto the floor; the floor's live circuit trips
	var bath := level.flat.bath
	var lvl := bath.level
	bath.outflow = 0.05
	await wait(1.0)
	check(bath.level < lvl, "the bath drains (%.3f -> %.3f)" % [lvl, bath.level])
	bath.outflow = 0.0; bath.inflow = 0.4
	await wait(1.5)
	var floor_w: WaterBody = level.flat.get_node("BathFloor")
	check(floor_w.level > 0.0, "the bath overflows onto the floor")
	bath.inflow = 0.0
	k.global_position = Vector3(8.5, 0, 6.2)
	var hp := k.hp
	await wait(3.5)
	check(k.hp < hp, "standing in live water hurts (%d -> %d)" % [hp, k.hp])
	check(not Power.live("A"), "and it trips the breaker")
	Power.set_breaker("A", true)
	floor_w.level = 0.0; floor_w._place()
	# gravity: the hanging room drops everything when its circuit's live
	var g: AABB = level.maze.chambers["G"]
	var floating := 0
	for p in get_tree().get_nodes_in_group("gun"): if (p as Node3D).global_position.y > 2.0: floating += 1
	check(floating == 1, "the revolver hangs in the air")
	Power.set_breaker("M3", true)
	await wait(2.5)
	check((get_tree().get_first_node_in_group("gun") as Node3D).global_position.y < 0.6, "and falls when the circuit's live")
	# a barricade: a chair's no good, a pile is
	var d: Door = level.flat.doors["dBed"]
	d.set_angle(0.0)
	var pile: Array = []
	for i in 7:
		var p := Prop.make(level, d.global_transform * Transform3D(Basis(), Vector3(0.4, 0.3 + i * 0.3, -0.35 * d.sgn)), Vector3(0.4, 0.28, 0.4), 6.0)
		pile.append(p)
	await wait(0.6)
	d.try_open(k)
	await wait(1.2)
	check(not d.is_open(), "a pile against a door stops it (%.2f)" % d.angle)
	for p in pile: p.queue_free()

func r_save() -> void:
	await _woken()
	k.global_position = Vector3(2.0, 0, 3.0)
	k.give_item("fuse", "Fuse")
	Power.set_breaker("B", false)
	level.flat.doors["dLiving"].damage(40.0, k)
	World.set_flag("test_flag", 7)
	Progress.gain_shards("x", 3)
	check(World.save_game(), "saved")
	var snap := World.read_save()
	check(not snap.is_empty(), "the save reads back")
	# change everything, then restore
	k.global_position = Vector3(8, 0, 2); k.take_item("fuse"); Power.set_breaker("B", true); World.set_flag("test_flag", 0); Progress.shards = 0
	World.restore(snap)
	await wait(0.2)
	check(k.global_position.distance_to(Vector3(2.0, 0, 3.0)) < 0.1, "Kurt back where he was")
	check(k.has_item("fuse"), "his pockets back")
	check(not Power.live("B"), "the kitchen's breaker still off")
	check(level.flat.doors["dLiving"].hp < 100.0, "the door still damaged")
	check(int(World.flag("test_flag")) == 7, "the flags")
	check(Progress.shards == 3, "the shards")
	World.wipe()

func r_monsters() -> void:
	await _woken()
	var m: Marta = story.marta
	m.met = true
	level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe()
	# she hears a thrown thing land, and goes to it
	m.global_position = level.maze.center(5, 5); m.set_state(Monster.S.IDLE)
	Noises.make(level.maze.center(5, 7), 10.0, "impact", null)
	await wait(0.2)
	check(m.state == Monster.S.INVESTIGATE, "Marta goes to a noise")
	# she can't see him in the dark at range
	k.global_position = level.maze.center(1, 1)
	m.global_position = level.maze.center(5, 1)
	check(not m.can_see_kurt() or Lights.light_at(k.global_position + Vector3.UP) > 0.3, "dark and crouched far off, unseen")
	# shot without Headshot: she breaks off
	m.set_state(Monster.S.HUNT)
	m.shot("body", k, m.global_position)
	await wait(1.2)
	check(m.state in [Monster.S.STAGGER, Monster.S.AWAY], "shot, she breaks off")
	check(m.state != Monster.S.DEAD, "and isn't dead")
	# with Headshot, a head shot ends her
	Progress.owned["headshot"] = true
	m.shot("head", k, m.global_position)
	check(m.state == Monster.S.DEAD, "Headshot: dead")
	check(Progress.kills == 1 and Progress.shards >= 3, "the god pays for it")
	# the Super can't be killed, and takes him back to the box room
	var s: Super = story.super_
	s.shot("head", k, s.global_position)
	check(s.state == Monster.S.STAGGER, "the Super staggers")
	k.global_position = s.global_position + Vector3(0, 0, 1.0)
	s.set_state(Monster.S.HUNT)
	await until(func(): return k.zone == 5, 15.0, "the Super's caught him: he wakes in the box room")
	check(k.hp <= 40.0, "hurt")
	# the porter: a noise in his lodge has him up and shouting
	var p: Porter = story.porter
	Noises.make(level.maze.chamber_center("P") + Vector3(0, 0.5, 0), 6.0, "impact", null)
	await wait(0.2)
	check(p.state == Monster.S.HUNT, "the porter, startled")
	# the lamplighter stops under a dead bulb
	var l: Lamplighter = story.lamplighter
	Power.set_fuse("M1", false)
	await until(func(): return l.state == Monster.S.IDLE, 30.0, "the lamplighter stands under a dead bulb")
	Power.set_fuse("M1", true)
	# the figures only move unseen
	var f: Figure = story.figures[0]
	k.global_position = level.maze.chamber_center("F") + Vector3(0, 0, 1.2)
	await look(f.global_position + Vector3(0, 1.0, 0))
	var before := f.global_position
	await wait(1.0)
	check(f.global_position.distance_to(before) < 0.05, "looked at, it doesn't move")
	await look(f.global_position + Vector3(0, 1.0, 0) + (k.global_position - f.global_position) * 3.0)
	await wait(0.6)
	check(f.global_position.distance_to(before) > 0.2 or k.hp < 100.0, "unseen, it comes")

func r_talk() -> void:
	await _woken()
	var m: Marta = story.marta
	m.met = true
	Progress.owned["old_name"] = true
	Progress.found["drawing"] = true
	m.global_position = k.global_position + Vector3(-1.5, 0, 0)
	m.set_state(Monster.S.IDLE)
	await use(m.global_position + Vector3(0, 0.9, 0), "talk")
	await until(func(): return World.flag("marta_known"), 10.0, "she knows him")
	check(m.state == Monster.S.SIT, "known: calm for good")

func r_meet() -> void:
	await _woken()
	var m: Marta = story.marta
	m.global_position = k.global_position + Vector3(-2.5, 0, 0)
	m.set_state(Monster.S.IDLE)
	await look(m.global_position + Vector3(0, 1.2, 0))
	await until(func(): return World.flag("heard_socko_marta"), 30.0, "Socko and Marta talk")
	check(lines_in_order(["mx_1", "mx_2", "mx_3", "mx_4", "mx_5", "mx_6", "mx_k1", "mx_s1"]), "their conversation, and Kurt left out of it")
	check(m.state == Monster.S.AWAY, "then she goes")

func r_random() -> void:
	await _woken()
	await story.mind.random_now("a")
	await story.mind.random_now("b")
	await story.mind.random_now("c")
	check(lines_in_order(["ra_1", "ra_2", "ra_3", "ra_4", "ra_5"]), "random conversation A")
	check(lines_in_order(["rb_1", "rb_2", "rb_3", "rb_4", "rb_5"]), "random conversation B")
	check(lines_in_order(["rc_1", "rc_2a", "rc_3", "rc_4a", "rc_5", "rc_6", "rc_7"]), "random conversation C, no memories")
	Progress.memories = 1; Progress.buy("faces")
	story.mind._random_left.append("c")
	await story.mind.random_now("c")
	check(lines_in_order(["rc_1", "rc_2b", "rc_3", "rc_4b", "rc_5", "rc_6", "rc_7"]), "random conversation C, one memory point in")
	# the balcony
	await walk_to(Flat47.POINTS.balcony)
	await until(func(): return said("bal_4"), 20.0, "the balcony lines")
	check(lines_in_order(["bal_1", "bal_2", "bal_3", "bal_4"]), "the balcony: every line, in order")

func r_touch() -> void:
	await _woken()
	Controls.touch_mode = true
	var vp := get_viewport().get_visible_rect().size
	var p0 := k.global_position
	var y0 := k.yaw
	# a thumb on the left: the stick
	_touch(0, Vector2(vp.x * 0.2, vp.y * 0.7), true)
	for i in 30:
		_drag(0, Vector2(vp.x * 0.2, vp.y * 0.7 - i * 4.0))
		await get_tree().physics_frame
	await wait(0.5)
	check(k.global_position.distance_to(p0) > 0.3, "the stick walks him (%.2f m)" % k.global_position.distance_to(p0))
	_touch(0, Vector2(vp.x * 0.2, vp.y * 0.6), false)
	# a finger on the right: look
	_touch(1, Vector2(vp.x * 0.6, vp.y * 0.4), true)
	for i in 20:
		_drag(1, Vector2(vp.x * 0.6 + i * 10.0, vp.y * 0.4))
		await get_tree().physics_frame
	_touch(1, Vector2(vp.x * 0.6 + 200.0, vp.y * 0.4), false)
	check(absf(k.yaw - y0) > 0.1, "dragging turns his head")
	# the USE button says what it does, and does it
	await walk_to(Flat47.POINTS.by_door)
	await look(level.flat.doors["dLiving"].handle_pos())
	await get_tree().process_frame
	check(Controls.labels.use == "Open", "the USE button says Open")
	var b: Control = Controls._buttons["use"]
	check(b.visible and b.size.x > 20.0, "the USE button is on screen")
	var c := b.get_global_rect().get_center()
	_touch(2, c, true); await get_tree().physics_frame; _touch(2, c, false)
	await until(func(): return said("wont_open"), 10.0, "tapping USE tries the door")
	# pause
	var pb: Control = Controls._buttons["pause"]
	_touch(3, pb.get_global_rect().get_center(), true); await get_tree().process_frame; _touch(3, pb.get_global_rect().get_center(), false)
	await get_tree().process_frame
	check(get_tree().paused, "the pause button pauses")
	main.hud.toggle_menu("")
	check(not get_tree().paused, "and back")

func _touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = i; e.position = p; e.pressed = down
	Input.parse_input_event(e)

func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = i; e.position = p
	Input.parse_input_event(e)

func r_dbg() -> void:
	await _woken()
	level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe()
	await wait(0.8)
	await walk_to(level.maze.chamber_center("B"))
	var br: AABB = level.maze.chambers["B"]
	var p := Vector3(br.end.x - 0.08, 1.5, br.get_center().z)
	await look(p)
	print("DBG kurt ", k.global_position, " cam ", k.cam.global_position, " target point ", p)
	var q := PhysicsRayQueryParameters3D.create(k.cam.global_position, k.cam.global_position - k.cam.global_transform.basis.z * 3.0, 1 | 2 | 8)
	q.exclude = [k.get_rid()]
	var hit := k.get_world_3d().direct_space_state.intersect_ray(q)
	print("DBG hit ", hit.get("collider"), " at ", hit.get("position"))
	for f in get_tree().get_nodes_in_group("x"): pass
	for n in level.find_children("*", "FuseBox", true, false): print("DBG fusebox ", n.name, " ", n.global_position, " layer ", n.collision_layer)
	check(true, "dbg")
