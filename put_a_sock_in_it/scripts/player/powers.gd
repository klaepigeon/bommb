class_name Powers
extends Node
## What the infection lets him do (the Infection tree, docs/SKILLS.md), on one button, "power"
## (T / D-pad down / touch POWER), which does the first of these that applies:
##   Throw Voice        crouched: a sound where he's looking (up to 20 m), for whatever listens
##   Telekinetic Shove  she (or anything in the building that's after him) is under the crosshair,
##                      within 8 m: its stance broken, thrown back
##   Telekinesis        a loose thing (up to 6 kg) under the crosshair, within 8 m: it flies to
##                      his hand
##   Telepathy          nothing in reach: for three seconds he sees what's alive near him (her,
##                      the building's people) through the walls
## Each costs strain (Game.strain 0..1, refilling at 0.08 a second); with too little left, nothing
## happens but a headache.

const RANGE := 8.0
const REFILL := 0.08

var player: Player
var level: Node
var _pulling: RigidBody3D = null
var _pull_t := 0.0
var _seen_t := 0.0
var _overlay: StandardMaterial3D
var _lit_up: Array = []

func attach(p: Player, lv: Node) -> void:
	player = p; level = lv
	name = "Powers"
	lv.add_child(self)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.no_depth_test = true
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(0.55, 0.8, 1.0, 0.35)
	_overlay.render_priority = 10

func _unhandled_input(e: InputEvent) -> void:
	if not player or not player.controls: return
	if e.is_action_pressed("power"): use()

## Do whatever applies. Returns what it did ("voice", "shove", "pull", "listen", "tired", "").
func use() -> String:
	# Throw Voice: crouched, a sound where he's looking, for whatever listens
	if player.crouching and Skills.has("s_voice"):
		var at := _aim_point(20.0)
		if at != Vector3.INF:
			if not _spend("voice"): return "tired"
			Game.make_noise(at, 0.8)
			Sfx.play_at("whisper", at, 0.0, 0.7, 24.0); Sfx.play_at("knock", at, -2.0, 0.9, 24.0)
			Fx.kick("fringe", 0.6, 0.4)
			return "voice"
	var m = _foe_in_sights()
	if m and Skills.has("s_shove"):
		if not _spend("shove"): return "tired"
		if m is MartaHunter:
			m.melee_hit(MartaHunter.POISE_MAX * 0.5, player.global_position, 4.0, self)
			Sfx.play_at("bone_crack", m.head(), 0.0, 0.7)
		else:
			m.shove(player.global_position)
			Sfx.play_at("bone_crack", m.eye(), 0.0, 0.7)
		Sfx.play("whoosh", 0.0, 0.5)
		Fx.kick("fringe", 1.4, 0.6); player.shake(0.02, 0.3)
		return "shove"
	var thing := _thing_in_sights()
	if thing and Skills.has("s_tk") and not player.held:
		if not _spend("pull"): return "tired"
		if thing.has_method("wake"): thing.wake()
		_pulling = thing; _pull_t = 0.0
		thing.gravity_scale = 0.0; thing.sleeping = false
		thing.set_meta("tk_mask", thing.collision_mask); thing.collision_mask = 0     # out of the shelf, through the clutter
		Sfx.play("whoosh", -6.0, 0.7)
		Fx.kick("fringe", 0.8, 0.4)
		return "pull"
	if Skills.has("s_telepathy"):
		if not _spend("listen"): return "tired"
		_seen_t = 3.0
		Sfx.play("whisper", -6.0, 0.6); Fx.kick("fringe", 1.0, 1.0)
		return "listen"
	return ""

func _spend(what: String) -> bool:
	var c: float = Skills.STRAIN_COST[what]
	if Game.strain + c > 1.0:
		Sfx.play("tinnitus", -18.0, 1.4); player.shake(0.01, 0.2)
		return false
	Game.strain += c
	return true

## Marta, or one of the building's people that wants him dead (or that he's in a fight with),
## in his sights within RANGE with nothing in the way.
func _foe_in_sights():
	var cands := []
	var m = level.get("marta")
	if m and m is MartaHunter and m.is_inside_tree(): cands.append([m, m.head()])
	for n in get_tree().get_nodes_in_group("inhabitant"):
		if n is Inhabitant and not n.dead and n.is_inside_tree(): cands.append([n, n.eye() - Vector3(0, 0.3, 0)])
	var best = null; var bd := INF
	for c in cands:
		var to: Vector3 = (c[1] as Vector3) - player.cam.global_position
		if to.length() > RANGE: continue
		var dot := (-player.cam.global_transform.basis.z).dot(to.normalized())
		if dot < 0.94: continue
		var q := PhysicsRayQueryParameters3D.create(player.cam.global_position, c[1], 1, [player.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty(): continue
		if to.length() < bd: bd = to.length(); best = c[0]
	return best

## Where he's looking: the first solid thing within `reach`, or Vector3.INF.
func _aim_point(reach: float) -> Vector3:
	var from := player.cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - player.cam.global_transform.basis.z * reach, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3.INF if hit.is_empty() else (hit.position as Vector3) + (hit.normal as Vector3) * 0.5

func _thing_in_sights() -> RigidBody3D:
	var from := player.cam.global_position
	var space := player.get_world_3d().direct_space_state
	# loose things only (a book in a bookcase sits inside the case's solid box: look past it)
	# (look through furniture that won't come: the case the book is in, the table the cup is on)
	var ex: Array[RID] = [player.get_rid()]
	var hit := {}
	var rb: RigidBody3D = null
	for tries in 5:
		var q := PhysicsRayQueryParameters3D.create(from, from - player.cam.global_transform.basis.z * RANGE, 16 | 32, ex)
		hit = space.intersect_ray(q)
		if hit.is_empty(): return null
		rb = hit.collider as RigidBody3D
		if rb and rb.get("liftable") and rb.mass <= 6.0 and rb != player.held: break
		rb = null
		ex.append((hit.collider as CollisionObject3D).get_rid())
	if not rb: return null
	# and nothing solid between him and it, bar what it's sitting in
	var p: Vector3 = hit.position
	var q2 := PhysicsRayQueryParameters3D.create(from, p, 1, [player.get_rid()])
	var wall := space.intersect_ray(q2)
	if not wall.is_empty() and (wall.position as Vector3).distance_to(p) > 0.45: return null
	return rb

func _process(delta: float) -> void:
	Game.strain = maxf(0.0, Game.strain - REFILL * delta)
	# a pulled thing flies to his hand, then he has it
	if _pulling:
		if not is_instance_valid(_pulling): _pulling = null
		else:
			_pull_t += delta
			var want := player.cam.global_position - player.cam.global_transform.basis.z * 0.7
			var d := want - _pulling.global_position
			_pulling.sleeping = false
			_pulling.linear_velocity = d.normalized() * minf(14.0, d.length() * 12.0)
			if d.length() < 0.35 or _pull_t > 1.5:
				var b := _pulling; _pulling = null
				b.gravity_scale = 1.0
				b.collision_mask = int(b.get_meta("tk_mask", 1 | 2 | 16 | 32))
				# in reach: he has it; caught on something on the way: it drops where it is
				if not player.held and d.length() < 1.0: player.pick_up(b)
	# telepathy: the shapes of what's alive near him, through the walls
	var on := _seen_t > 0.0
	var was := _seen_t > 0.0 or _lit_up.size() > 0
	_seen_t = maxf(0.0, _seen_t - delta)
	if not was: return
	var bodies := []
	var m = level.get("marta")
	if m and m is MartaHunter and is_instance_valid(m.body): bodies.append(m.body)
	for n in get_tree().get_nodes_in_group("inhabitant"):
		if n is Inhabitant and not n.dead and is_instance_valid(n.body) and n.global_position.distance_to(player.global_position) < 25.0: bodies.append(n.body)
	for mi in _lit_up:
		if is_instance_valid(mi): (mi as MeshInstance3D).material_overlay = null
	_lit_up.clear()
	if on:
		for b in bodies:
			for mi in b.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = _overlay; _lit_up.append(mi)
		_overlay.albedo_color.a = 0.35 * minf(1.0, _seen_t)
