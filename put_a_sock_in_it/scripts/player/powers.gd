class_name Powers
extends Node
## What the infection lets him do (the Infection tree, docs/SKILLS.md), on one button, "power"
## (T / D-pad down / touch POWER), which does the first of these that applies:
##   Telekinetic Shove  she's under the crosshair, within 8 m: half her poise and thrown back
##   Telekinesis        a loose thing (up to 6 kg) under the crosshair, within 8 m: it flies to
##                      his hand
##   Telepathy          nothing in reach: for three seconds he sees her through the walls
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

## Do whatever applies. Returns what it did ("shove", "pull", "listen", "tired", "").
func use() -> String:
	var m = _marta_in_sights()
	if m and Skills.has("s_shove"):
		if not _spend("shove"): return "tired"
		var dir: Vector3 = (m.global_position - player.global_position) * Vector3(1, 0, 1)
		m.melee_hit(MartaHunter.POISE_MAX * 0.5, player.global_position, 4.0, self)
		Sfx.play("whoosh", 0.0, 0.5); Sfx.play_at("bone_crack", m.head(), 0.0, 0.7)
		Fx.kick("fringe", 1.4, 0.6); player.shake(0.02, 0.3)
		return "shove"
	var thing := _thing_in_sights()
	if thing and Skills.has("s_tk") and not player.held:
		if not _spend("pull"): return "tired"
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

func _marta_in_sights():
	var m = level.get("marta")
	if not m or not (m is MartaHunter) or not m.is_inside_tree(): return null
	var to: Vector3 = m.head() - player.cam.global_position
	if to.length() > RANGE: return null
	if (-player.cam.global_transform.basis.z).dot(to.normalized()) < 0.94: return null
	var q := PhysicsRayQueryParameters3D.create(player.cam.global_position, m.head(), 1, [player.get_rid()])
	return m if player.get_world_3d().direct_space_state.intersect_ray(q).is_empty() else null

func _thing_in_sights() -> RigidBody3D:
	var from := player.cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - player.cam.global_transform.basis.z * RANGE, 1 | 16 | 32, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return null
	var rb := hit.collider as RigidBody3D
	if rb and rb.get("liftable") and rb.mass <= 6.0 and rb != player.held: return rb
	return null

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
	# telepathy: her shape through the walls
	var m = level.get("marta")
	if m and m is MartaHunter and is_instance_valid(m.body):
		var on := _seen_t > 0.0
		_seen_t = maxf(0.0, _seen_t - delta)
		for mi in m.body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _overlay if on else null
		if on: _overlay.albedo_color.a = 0.35 * minf(1.0, _seen_t)
