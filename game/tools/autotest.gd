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
	check(false, "no verb '%s' at %s, kurt at %s (got %s on %s)" % [verb, str(p), str(k.global_position.snapped(Vector3.ONE * 0.01)), str(k.target_verbs.map(func(v): return v.id)), str(k.target)])
	return false

## Walks along the Nav graph the way a player could: through open doors (opening unlocked ones),
## never through locked ones, crouching through the crawl hole.
func walk_to(p: Vector3, speed := 9.0) -> void:
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
			if d is Door and not d.broken and (not d.is_open() or (absf(d.angle) < d.max_angle * 0.7 and not d.chained)):
				d.swing(d.max_angle, 0.3)
				await wait(0.5)
		var q: Vector3 = level.nav.pts[path[i]]
		k.crouching = q.z > 7.0 and q.z < 9.3 and q.x > 5.0 and q.x < 9.2
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

## A screenshot (only with --shots=DIR, and a display).
func snap(name: String) -> void:
	if not main.args.has("shots") or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var dir := String(main.args.shots)
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

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
	k.hold_from_pocket("shoe_left")
	await wait(0.2)
	m.set_state(Monster.S.HUNT)
	await until(func(): return m.state == Monster.S.CALM, 10.0, "she takes the shoe")
	m.calm_for = 0.0
	k.hold_from_pocket("shoe_right")
	await wait(0.3)
	m.global_position = k.global_position + Vector3(-2.0, 0, 0)
	m.set_state(Monster.S.HUNT)
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
	await until(func(): return level.building.bolts["47"], 15.0, "out to the landing: 47's bolt goes back")
	check(not World.flags.has("ended"), "and it isn't over: there's the rest of the building")

func r_axe() -> void:
	await _woken()
	level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe()
	await wait(0.8)
	var axe: Prop = level.flat.props["prop_120_Axe"]
	await walk_to(Vector3(1.85, 0, 5.6))
	var axe_c: Vector3 = (axe.get_child(0) as Node3D).global_position
	await use(axe_c, "lift")
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
	k.global_position = Vector3(9.3, 0, 4.4)       # (already in the hall)
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
	await until(func(): return World.flags.has("service_open"), 5.0, "the service door opens")
	await _step_to(level.maze.center(20, 1) + Vector3(0.6, 0, -0.35), 2.0)
	await until(func(): return level.building.bolts["47"], 10.0, "out by the service door, onto the landing")
	check(level.place_of(k.global_position) == "stairs", "on 47's landing")

func r_systems() -> void:
	await _woken()
	# light: never more than eight lamps in the shader, and nothing reaches through a wall
	var used := 0
	for s in Lights.slots: if s != null: used += 1
	check(used <= Lights.SLOTS, "the light engine holds %d lamps (max %d)" % [used, Lights.SLOTS])
	# power: a fuse out kills its lamps
	var a_lamps: Array = Lights.lamps.filter(func(l): return l.circuit == "A" and l.on)
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
	check(d.angle < 0.5, "a pile against a door stops it at a crack (%.2f rad)" % d.angle)
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
	check(Vector2(k.global_position.x - 2.0, k.global_position.z - 3.0).length() < 0.15, "Kurt back where he was (%s)" % str(k.global_position))
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
	m.rotation.y = -PI * 0.5          # facing him
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
	await snap("phone_1_stick")
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
	await snap("phone_2_use_open")
	var b: Control = Controls._buttons["use"]
	check(b.visible and b.size.x > 20.0, "the USE button is on screen")
	var c := b.get_global_rect().get_center()
	_touch(2, c, true); await get_tree().physics_frame; _touch(2, c, false)
	await until(func(): return said("wont_open"), 10.0, "tapping USE tries the door")
	await wait(0.3)
	await snap("phone_3_subtitle")
	# pause
	var pb: Control = Controls._buttons["pause"]
	_touch(3, pb.get_global_rect().get_center(), true); await get_tree().process_frame; _touch(3, pb.get_global_rect().get_center(), false)
	await get_tree().process_frame
	check(get_tree().paused, "the pause button pauses")
	await snap("phone_4_pause")
	main.hud.toggle_menu("")
	check(not get_tree().paused, "and back")

## Touches arrive in window pixels (as a phone's do); the test thinks in the game's canvas units.
func _win(p: Vector2) -> Vector2:
	return p * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size

func _touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = i; e.position = _win(p); e.pressed = down
	Input.parse_input_event(e)

func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = i; e.position = _win(p)
	Input.parse_input_event(e)



func _steps(pts: Array) -> void:
	for p in pts: await _step_to(p, 9.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

func _held_item(id: String) -> void:
	if k.held and k.held.item == id: return
	k.hold_from_pocket(id)
	await get_tree().physics_frame

func r_building() -> void:
	await _woken()
	var b: Building = level.building
	for f in story.figures: story._dormant(f, true)
	story._dormant(story.marta, true)
	story._dormant(story.super_, true)
	# out of 47 (the other routes do it properly): the landing slides the first bolt
	k.global_position = level.point("stair_4")
	await until(func(): return b.bolts["47"], 5.0, "47's bolt goes back when he's out on the landing")
	# down the stairs to the street door, which won't
	await walk_to(level.point("stair_1"))
	check(Building.floor_of(k.global_position) == 1 and k.global_position.y < -8.0, "down four flights (y %.1f)" % k.global_position.y)
	var st: Vector3 = b.door_pos(1, 0) + Vector3(0.05, 1.0, 0)
	await walk_to(b.door_pos(1, 0) + Vector3(0.8, 0, 0))
	await look(st); k._aim()
	check(not k.target_verbs.any(func(v): return v.id == "out"), "the street door won't open yet")
	await use(st, "bolts")
	# up to 4, into 48
	await walk_to(level.point("stair_4_e"))
	await use(b.door_pos(4, 1) + Vector3(-0.05, 1.0, 0), "in")
	await until(func(): return level.place_of(k.global_position) == "48" and not k.frozen, 5.0, "into 48")
	var f48: Flat48 = level.flat48
	var A := Flat48.AT
	# the note wall: find GUN SAFE, take it, stick it on the cold tall block
	await _steps([A + Vector3(7.2, 0, 4.5), A + Vector3(5.5, 0, 4.5)])
	var wall_at := A + Vector3(5.5, 1.45, 3.9)
	for i in 30:
		if String(f48.wall_words[f48.wall_i % f48.wall_words.size()]) == "GUN SAFE": break
		await use(wall_at, "next")
	await use(wall_at, "take")
	check(k.held and k.held.item == "note:GUN SAFE", "a note in hand: GUN SAFE")
	await _steps([A + Vector3(4.9, 0, 4.5), A + Vector3(4.3, 0, 4.6), A + Vector3(3.5, 0, 4.4), A + Vector3(1.85, 0, 4.2), A + Vector3(1.82, 0, 5.6), A + Vector3(1.6, 0, 6.6)])
	await use(A + Flat48.SAFE_AT + Vector3(0, 1.0, -0.2), "stick")
	check(f48.safe_real, "it's a gun safe: it always was")
	await use(A + Flat48.SAFE_AT + Vector3(0, 1.0, -0.2), "open")
	check(k.has_item("shotgun") and k.shells == 10, "the sawn-off and ten shells")
	# the red notes, one in each room
	var routes := {"storage": [A + Vector3(1.0, 0, 6.6)], "child": [A + Vector3(1.82, 0, 5.6), A + Vector3(1.85, 0, 4.4), A + Vector3(4.6, 0, 4.6), A + Vector3(5.68, 0, 4.6), A + Vector3(5.68, 0, 5.9), A + Vector3(4.0, 0, 6.6)],
		"living": [A + Vector3(5.68, 0, 5.9), A + Vector3(5.68, 0, 4.6), A + Vector3(4.3, 0, 4.6), A + Vector3(3.3, 0, 3.3), A + Vector3(1.6, 0, 2.6)],
		"bedroom": [A + Vector3(3.3, 0, 3.3), A + Vector3(4.3, 0, 4.6), A + Vector3(6.93, 0, 4.5), A + Vector3(6.93, 0, 2.9), A + Vector3(5.6, 0, 2.6)],
		"kitchen": [A + Vector3(6.93, 0, 2.9), A + Vector3(6.93, 0, 4.5), A + Vector3(8.5, 0, 4.5), A + Vector3(8.5, 0, 2.9), A + Vector3(9.1, 0, 2.6)],
		"hall": [A + Vector3(8.5, 0, 2.9), A + Vector3(8.5, 0, 4.5), A + Vector3(9.2, 0, 4.6)]}
	for r in ["storage", "child", "living", "bedroom", "kitchen", "hall"]:
		await _steps(routes[r])
		await use(A + Flat48.RED[r][0], "pocket")
	check(Flat48.RED.keys().all(func(r): return k.has_item("rednote:" + r)), "all six red notes")
	# the plan: each in the box of its room
	await _steps([A + Vector3(9.45, 0, 4.6)])
	var boxes := {"living": Vector2(-0.33, 0.14), "bedroom": Vector2(0.0, 0.14), "kitchen": Vector2(0.3, 0.14), "hall": Vector2(0.12, -0.04), "storage": Vector2(-0.33, -0.2), "child": Vector2(0.0, -0.2)}
	for r in Flat48.PLAN_ORDER:
		await _held_item("rednote:" + r)
		await use(A + Flat48.PLAN + Vector3(boxes[r].x, boxes[r].y, 0.03), "place")
	await until(func(): return World.flag("48_plan"), 15.0, "the plan read right")
	check(Speech.history.has("kurt: Sometimes it's easier to make the choice that makes no sense, when your back is against the wall"), "the monologue, word for word")
	await until(func(): return b.bolts["48"], 10.0, "48's bolt goes back")
	# the seventh note, and the pointless door
	var n51: Prop = null
	for p in f48.get_children(): if p is Prop and p.key == "note51": n51 = p
	await wait(1.0)
	await use(n51.global_position, "pocket")
	check(k.has_item("note:51"), "the seventh red note: 51")
	await _steps([A + Vector3(8.5, 0, 4.6), A + Vector3(8.05, 0, 4.6)])
	var pd := A + Flat48.POINTLESS + Vector3(0, 1.0, -0.02)
	await use(pd, "peel")
	await _held_item("note:51")
	await use(pd, "label")
	check(f48.pointless_label == "51", "the door's a 51 now")
	await use(pd, "open")
	await until(func(): return level.place_of(k.global_position) == "51" and not k.frozen, 5.0, "through the pointless door into 51")
	# 51: follow the prints out to their end
	var B := Flat51.AT
	await _steps([B + Vector3(4.6, 0, 4.6), B + Vector3(3.6, 0, 3.8), B + Vector3(3.0, 0, 0.2), B + Vector3(2.0, 0, -22.0), B + Vector3(1.4, 0, -63.0)])
	await until(func(): return b.bolts["51"], 8.0, "the end of the prints: 51's bolt")
	await until(func(): return not k.frozen, 6.0, "he comes round in 47")
	check(level.place_of(k.global_position) == "47", "and he's in 47's hall")
	check(level.flat.tv_on, "and the television's come on")
	# the CHILD's tag, then 44
	k.global_position = level.point("stair_4")
	await walk_to(level.point("stair_4_e"))
	await use(b.door_pos(4, 1) + Vector3(-0.05, 1.0, 0), "in")
	await until(func(): return level.place_of(k.global_position) == "48" and not k.frozen, 5.0, "back into 48")
	var child: Figure = story.figures[2]
	child.process_mode = Node.PROCESS_MODE_INHERIT; child.visible = true
	await _steps([A + Vector3(4.3, 0, 4.6), A + Vector3(5.68, 0, 4.6), A + Vector3(5.68, 0, 5.9), A + Vector3(3.6, 0, 5.9)])
	await use(child.global_position + Vector3(0, 0.8, 0), "look")
	check(k.has_item("note:CHILD'S CELL"), "on the CHILD's back: CHILD'S CELL — 44")
	story._dormant(child, true)
	await _steps([A + Vector3(5.68, 0, 5.9), A + Vector3(5.68, 0, 4.6), A + Vector3(9.5, 0, 4.56)])
	await use(A + Vector3(10.0, 1.04, 4.56), "leave")
	await until(func(): return level.place_of(k.global_position) == "stairs" and not k.frozen, 5.0, "out of 48")
	await walk_to(level.point("stair_3_e"))
	await use(b.door_pos(3, 1) + Vector3(-0.05, 1.0, 0), "in")
	await until(func(): return level.place_of(k.global_position) == "44" and not k.frozen, 5.0, "into 44")
	var C := Flat44.AT
	var f44: Flat44 = level.flat44
	await _steps([C + Vector3(3.0, 0, 4.75), C + Vector3(f44.cx(3), 0, 4.75)])
	await _held_item("note:CHILD'S CELL")
	await use(C + Vector3(f44.cx(3), 1.0, 4.18), "label")
	check(f44.child_cell == 3, "the note makes it the child's cell")
	await _steps([C + Vector3(f44.cx(3), 0, 3.2)])
	await until(func(): return b.bolts["44"], 8.0, "in the child's cell: 44's bolt")
	# out: the last of them gone back, the street door opens
	await _steps([C + Vector3(f44.cx(3), 0, 4.75), C + Vector3(0.9, 0, 4.75)])
	await use(C + Vector3(0.05, 1.04, 4.75), "leave")
	await until(func(): return level.place_of(k.global_position) == "stairs" and not k.frozen, 5.0, "out of 44")
	await walk_to(b.door_pos(1, 0) + Vector3(0.8, 0, 0))
	check(b.all_bolts(), "all four bolts back")
	await use(st, "out")
	await until(func(): return World.flags.has("ended"), 20.0, "out of Building 14")

func r_kick51() -> void:
	await _woken()
	var b: Building = level.building
	for f in story.figures: story._dormant(f, true)
	story._dormant(story.super_, true)
	k.global_position = level.point("stair_4")
	await walk_to(level.point("stair_5_w"))
	var d := b.door_pos(5, 0) + Vector3(0.05, 1.0, 0)
	for i in 4:
		if World.flag("51_open"): break
		await use(d, "kick")
	check(World.flags.has("51_open"), "four kicks and 51's chain gives")
	await use(d, "in")
	await until(func(): return level.place_of(k.global_position) == "51" and not k.frozen, 5.0, "into 51 the hard way")

## The air: each place has its own bed and fog, events happen around Kurt, a hunter raises the
## tension and hushes the rest, the phone in the hall can be hung up and rings.
func r_atmosphere() -> void:
	await _woken()
	var amb: Ambience = story.ambience
	for f in story.figures: story._dormant(f, true)
	story._dormant(story.super_, true)
	k.global_position = Vector3(8.6, 0, 4.5)
	await wait(0.5)
	check(amb.profile_id == "47", "47 sounds like 47 (%s)" % amb.profile_id)
	k.global_position = level.point("stair_4")
	await wait(3.0)
	check(amb.profile_id == "stairs", "the stairwell sounds like the stairwell (%s)" % amb.profile_id)
	var p48: Place = level.places["48"]
	k.global_position = p48.arrive()[0]
	await wait(3.0)
	check(amb.profile_id == "draft", "48 has its own air (%s)" % amb.profile_id)
	check(Lights.fog_color.r > 0.4, "48's fog is white (%.2f)" % Lights.fog_color.r)
	var heard := []
	var on_ev := func(n, d): if n == "ambience": heard.append(d.sound)
	World.event.connect(on_ev)
	amb.fire({"sound": "steps_above", "where": "above", "db": -20}, k.global_position)
	check(heard.size() == 1 and amb.where({"where": "above"}, k.global_position).y > k.global_position.y + 3.0, "someone walking upstairs")
	World.event.disconnect(on_ev)
	# a hunter makes the building hold its breath
	story._dormant(story.super_, false)
	story.super_.global_position = k.global_position + Vector3(-3, 0, 0)
	story.super_.set_state(Monster.S.HUNT)
	await wait(1.0)
	check(amb.tension > 0.3 and amb.quiet(), "being hunted: tension up, the building quiet (%.2f)" % amb.tension)
	story._dormant(story.super_, true)
	# the phone
	k.global_position = Vector3(9.0, 0, 4.4)
	await wait(0.3)
	check(await use(Vector3(9.55, 1.0, 5.1), "hang"), "the receiver goes back on its hook")
	check(World.flag("phone47_hung"), "hung up")

## Round the outside: over the balcony's end rail, along the ledge (really walking: the stick),
## in at the bedroom window three ways (reach through the fortochka, Socko, the glass), and out.
func r_ledge() -> void:
	await _woken()
	var lw: WindowLedge = level.flat.ledge_route
	check(level.flat.doors["dLiving"].locked(), "the living room's locked from outside")
	k.global_position = Vector3(3.2, -0.12, -1.0); await wait(0.3)
	check(await use(Vector3(3.84, 0.95, -0.75), "over"), "over the end rail")
	await until(func(): return not k.climbing, 4.0, "climbing over")
	await wait(0.3)
	check(k.rail_axis != Vector3.ZERO, "on the ledge, back to the wall")
	# the stick: forward along it; then hard toward the white (he mustn't go)
	Input.action_press("left"); await wait(1.0); Input.action_release("left")
	check(k.global_position.z > -0.85 and k.global_position.y > -0.5, "pushing toward the edge doesn't put him off it (%s)" % str(k.global_position))
	Input.action_press("forward")
	await until(func(): return k.global_position.x > 6.1, 8.0, "shuffling along the ledge")
	Input.action_release("forward")
	await wait(0.3)
	check(lw.state() == "shut", "the window's shut")
	check(await use(Vector3(6.38, 1.4, -0.5), "reach"), "reach in through the fortochka")
	await until(func(): return lw.state() == "open", 6.0, "the latch")
	check(await use(Vector3(6.38, 1.4, -0.5), "in"), "climb in")
	await until(func(): return not k.climbing, 4.0, "climbing in")
	check(k.global_position.z > 0.3 and level.flat.zone_of(k.global_position + Vector3(0, 0.5, 0)) == level.flat.zone_of(Vector3(6, 0.5, 2)), "in the bedroom (%s)" % str(k.global_position))
	# out again, and Socko does the latch
	check(await use(Vector3(6.38, 1.4, 0.06), "out"), "out onto the ledge")
	await until(func(): return not k.climbing, 4.0, "climbing out")
	await wait(0.3)
	lw.set_state("shut")
	await look(Vector3(6.38, 1.4, -0.5)); k._aim()
	var u: Usable = k.target as Usable
	check(u != null and u.socko_verbs(k).size() > 0, "Socko offers the fortochka")
	if u: await u.socko_act("latch", k, story.mind)
	await until(func(): return lw.state() == "open", 6.0, "Socko's latch")
	# and the loud way
	lw.set_state("shut")
	var hp0 := k.hp
	check(await use(Vector3(6.38, 1.4, -0.5), "elbow"), "through the glass")
	check(lw.state() == "broken" and k.hp < hp0, "broken, and it cut")
	check(await use(Vector3(6.38, 1.4, -0.5), "in"), "in through the broken pane")
	await until(func(): return not k.climbing, 4.0, "climbing in")
	await walk_to(Flat47.POINTS.hall)
	check(level.place_of(k.global_position) == "47" and k.global_position.x > 7.5 and k.global_position.z > 3.8, "out of the locked living room the long way round (%s)" % str(k.global_position))

## Screenshots of the free arm (run with a display and --shots): reaching, carrying, on the ledge.
func r_arm() -> void:
	await _woken()
	var d: Door = level.flat.doors["dLiving"]
	k.global_position = Vector3(4.0, 0, 4.0); await wait(0.3)
	await look(d.handle_pos())
	k._aim()
	k.reached.emit(d.handle_pos(), "open")
	await wait(0.22); await snap("arm_reach")
	check(k.arm.visible, "the arm comes up to the door")
	await wait(0.6)
	var mag: Prop = level.flat.props["prop_37_Magazine"]
	k.global_position = mag.global_position + Vector3(0.6, 0, 0.6); await wait(0.2)
	k.lift(mag); await wait(0.8); await snap("arm_hold")
	check(k.arm.visible, "the arm holds what he carries")
	k.drop(false); await wait(0.8)
	check(not k.arm.visible, "and goes down again")
	k.global_position = Vector3(3.2, -0.12, -1.0); await wait(0.3)
	await use(Vector3(3.84, 0.95, -0.75), "over")
	await wait(0.5); await snap("arm_climb")
	await until(func(): return not k.climbing, 4.0, "climbing over")
	await wait(0.6); await look(k.global_position + Vector3(2, 1.4, 0)); await wait(0.3); await snap("arm_ledge")
	check(k.arm.visible, "a hand on the wall on the ledge")
