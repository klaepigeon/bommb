extends SceneTree
## The infected: the generator (deterministic, varied, sane distributions), the bodies (a real
## skeleton per person, a skinned mesh whose weights are sound, every way of moving animates and
## stays finite, the gait follows the legs they have), losing limbs (the gait changes, the piece
## falls), and the hunter (hears, sees, chases, grabs, dies to a headshot, loses a limb to shots).
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/infected_test.gd

var ok := true

func _initialize() -> void:
	print("== the generator")
	_generator()
	print("== bodies")
	await _bodies()
	print("== losing limbs")
	await _severing()
	print("== the hunter")
	await _hunter()
	print("INFECTED ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _generator() -> void:
	var a := InfectedGenome.generate(1234); var b := InfectedGenome.generate(1234)
	_check(JSON.stringify(a) == JSON.stringify(b), "the same seed is the same person")
	var N := 2000
	var loco := {}; var skins := {}; var growths := {}; var clothes := {}; var quirks := {}; var heads := {}
	var extra := 0; var lost := 0; var odd := 0; var consistent := true; var extra_n := {}
	for i in N:
		var g := InfectedGenome.generate(i)
		loco[g.locomotion] = loco.get(g.locomotion, 0) + 1
		skins[g.skin] = true; growths[g.growth] = true; clothes[g.clothes] = true; quirks[g.quirk] = true; heads[g.head.state] = true
		var e := 0; var l := false
		for x in g.limbs:
			if x.extra: e += 1
			if String(x.state) in ["missing", "stump"]: l = true
		extra_n[e] = extra_n.get(e, 0) + 1
		if e > 0: extra += 1
		if l: lost += 1
		if g.locomotion != "walk": odd += 1
		consistent = consistent and g.locomotion == InfectedGenome.locomotion_of(g.limbs)
	print("    locomotion: %s" % [loco])
	print("    extra limbs: %s   with an extra limb %.0f%%, missing one %.0f%%, not walking normally %.0f%%" % [extra_n, 100.0 * extra / N, 100.0 * lost / N, 100.0 * odd / N])
	_check(loco.size() == 7, "all seven ways of moving occur (walk, limp, skitter, hop, lurch, crawl, drag)")
	_check(skins.size() == 4 and growths.size() == 4 and clothes.size() == 5 and quirks.size() == 6 and heads.size() == 4, "every skin, growth, clothing, habit and head occurs")
	_check(float(extra) / N > 0.35 and float(extra) / N < 0.65 and float(lost) / N > 0.2 and float(lost) / N < 0.6, "about half have an extra limb (%.0f%%), a good share have lost one (%.0f%%)" % [100.0 * extra / N, 100.0 * lost / N])
	var upright := float(loco.get("walk", 0) + loco.get("limp", 0)) / N
	_check(upright > 0.5, "but most people still walk on two legs, if badly (walking or limping: %.0f%%)" % (100.0 * upright))
	_check(consistent, "every person's gait follows from the limbs they have")

func _bodies() -> void:
	var weights_ok := true; var bones_ok := true; var sizes_ok := true; var anim_ok := true; var moves := true
	var t_build := 0.0
	var seen_loco := {}
	var sd := 0
	var built := 0
	while built < 40 or seen_loco.size() < 7:
		var g := InfectedGenome.generate(sd); sd += 1
		if built >= 40 and seen_loco.has(g.locomotion): continue
		seen_loco[g.locomotion] = true
		var t0 := Time.get_ticks_usec()
		var b := InfectedBody.new()
		root.add_child(b)
		b.build(g)
		t_build += (Time.get_ticks_usec() - t0) / 1000.0
		await process_frame
		built += 1
		# the skeleton: trunk + jaw + every limb's chain
		var want := 6
		for l in g.limbs: want += (b.limb_bones[l.id] as Array).size()
		bones_ok = bones_ok and b.skel.get_bone_count() == want
		# the skin: weights sum to 1, bones exist
		var m: ArrayMesh = b.mesh_inst.mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]; var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			for v in range(0, w.size(), 4):
				var sum := w[v] + w[v + 1] + w[v + 2] + w[v + 3]
				if absf(sum - 1.0) > 0.01: weights_ok = false
				for k in 4:
					if bi[v + k] >= b.skel.get_bone_count(): weights_ok = false
		var aabb := m.get_aabb()
		if aabb.size.y < 0.4 or aabb.size.y > 2.7 or aabb.size.x > 2.5: sizes_ok = false; print("    odd size %s for %s" % [aabb.size, InfectedGenome.describe(g)])
		# animate: moving for a second: the body moves and nothing goes to NaN
		var first := {}
		for i in b.skel.get_bone_count(): first[i] = b.skel.get_bone_global_pose(i).origin
		var changed := 0.0
		for f in 60:
			b.animate(1.0 / 60.0, {"speed": 1.0, "mode": "move"})
		b.skel.force_update_all_bone_transforms()
		for i in b.skel.get_bone_count():
			var p := b.skel.get_bone_global_pose(i).origin
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): anim_ok = false
			changed = maxf(changed, p.distance_to(first[i]))
		if changed < 0.02: moves = false; print("    didn't move: %s" % InfectedGenome.describe(g))
		for mode in ["idle", "attack", "dead"]:
			for f in 40: b.animate(1.0 / 60.0, {"speed": 0.0, "mode": mode, "attack": 1.0 if mode == "attack" else 0.0, "look": Vector3(0, 1.6, -2)})
			b.skel.force_update_all_bone_transforms()
			for i in b.skel.get_bone_count():
				var p := b.skel.get_bone_global_pose(i).origin
				if not is_finite(p.x + p.y + p.z): anim_ok = false
		# crawlers are down on the floor, walkers aren't
		var head_y := b.skel.get_bone_global_pose(b.bones.head).origin.y
		b.dead_k = 0.0
		for f in 30: b.animate(1.0 / 60.0, {"speed": 0.5, "mode": "move"})
		b.skel.force_update_all_bone_transforms()
		head_y = b.skel.get_bone_global_pose(b.bones.head).origin.y
		if g.locomotion in ["crawl", "drag"] and head_y > 0.75: sizes_ok = false; print("    crawler with its head at %.2f m" % head_y)
		if g.locomotion in ["walk", "limp"] and head_y < 1.0: sizes_ok = false; print("    walker with its head at %.2f m: %s" % [head_y, InfectedGenome.describe(g)])
		b.queue_free()
		await process_frame
	_check(bones_ok, "every body has a real skeleton: trunk, head, jaw and a bone chain for each limb (%d bodies)" % built)
	_check(weights_ok, "every vertex of skin, clothes and growth is weighted to real bones, weights summing to 1")
	_check(sizes_ok, "bodies are body-sized; crawlers' heads are near the floor, walkers' up")
	_check(anim_ok and moves, "every way of moving animates (%s) and stays finite through moving, idle, grabbing and dying" % [seen_loco.keys()])
	_check(t_build / built < 250.0, "a person builds in %.0f ms on average" % (t_build / built))

func _severing() -> void:
	# find someone who walks on two whole legs and has two arms
	var g: Dictionary
	for sd in 500:
		var x := InfectedGenome.generate(sd)
		if x.locomotion == "walk" and InfectedGenome.working(x.limbs, "arm") >= 2: g = x; break
	var b := InfectedBody.new(); root.add_child(b); b.build(g)
	var legs := []
	for l in g.limbs:
		if l.kind == "leg" and String(l.state) != "missing": legs.append(l.id)
	var p1 = b.sever(legs[0])
	_check(p1 is RigidBody3D and b.locomotion in ["hop", "lurch"], "shoot a leg off: it falls away, and they go on one leg (%s)" % b.locomotion)
	b.sever(legs[1])
	_check(b.locomotion == "crawl", "both: they crawl on their arms (%s)" % b.locomotion)
	var arms := []
	for l in g.limbs:
		if l.kind == "arm" and String(l.state) != "missing": arms.append(l.id)
	for a in arms: b.sever(a)
	_check(b.locomotion == "drag", "and with nothing left they drag themselves (%s)" % b.locomotion)
	for f in 60: b.animate(1.0 / 60.0, {"speed": 0.4, "mode": "move"})
	b.skel.force_update_all_bone_transforms()
	var fin := true
	for i in b.skel.get_bone_count():
		var p := b.skel.get_bone_global_pose(i).origin
		fin = fin and is_finite(p.x + p.y + p.z)
	_check(fin, "and still animate")
	b.queue_free()

func _hunter() -> void:
	var world := Node3D.new(); root.add_child(world)
	var floor_b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(40, 0.2, 40); cs.shape = bs; floor_b.add_child(cs)
	world.add_child(floor_b); floor_b.position.y = -0.1
	var kurt := CharacterBody3D.new()
	var kc := CollisionShape3D.new(); var kcap := CapsuleShape3D.new(); kcap.radius = 0.3; kcap.height = 1.75; kc.shape = kcap; kc.position.y = 0.875; kurt.add_child(kc)
	var cam := Camera3D.new(); cam.position.y = 1.65; kurt.add_child(cam)
	kurt.set_meta("x", 1)
	world.add_child(kurt); kurt.position = Vector3(0, 0, 8)
	kurt.set("cam", cam)   # (CharacterBody3D has no cam property: the hunter falls back to its head height)
	var g: Dictionary
	for sd in 500:
		var x := InfectedGenome.generate(sd)
		if x.locomotion == "walk" and int(x.head.eyes) == 2: g = x; break
	var inf = load("res://scripts/infected/infected.gd").new()
	inf.setup(g, kurt)
	var caught := [false]
	inf.on_caught = func(_who): caught[0] = true; await create_timer(0.1).timeout
	world.add_child(inf)
	inf.global_position = Vector3(0, 0.05, 0)
	# they face -Z; Kurt is at +Z: behind them
	await _secs(0.5)
	_check(inf.state != inf.S.CHASE, "facing away, they don't see him")
	Noises.make(self, Vector3(0, 0, 6), 0.9, "impact", kurt)
	await _secs(0.3)
	_check(inf.state in [inf.S.LISTEN, inf.S.CHASE], "a loud noise behind them: they go to it (%s)" % ["IDLE", "WANDER", "LISTEN", "SEARCH", "CHASE", "GRAB", "DEAD"][inf.state])
	var chased := false
	var t := 0.0
	while t < 20.0 and not caught[0]:
		await process_frame; t += 1.0 / 60.0
		chased = chased or inf.state == inf.S.CHASE
	_check(chased, "they see him and come for him")
	_check(caught[0], "and take hold of him when they reach him")
	await _secs(1.0)
	# shot: a limb, three times, comes off
	var arm_id := ""
	for l in g.limbs:
		if l.kind == "arm" and String(l.state) in ["whole", "long", "short"]: arm_id = l.id; break
	var lost := [""]
	inf.lost_limb.connect(func(id): lost[0] = id)
	var hp_i := -1
	for i in inf.body.hit_parts.size():
		if inf.body.hit_parts[i].part == arm_id: hp_i = i; break
	if hp_i >= 0:
		var where: Vector3 = (inf._hits.get_child(hp_i) as Node3D).global_position
		for i in 3: inf.shot(where, Vector3.UP, false, -1); await process_frame
	_check(arm_id == "" or lost[0] == arm_id, "three shots to an arm take it off (%s)" % lost[0])
	# headshot with the skill: down for good
	var hx: Transform3D = inf.body.skel.global_transform * inf.body.skel.get_bone_global_pose(inf.body.bones.head)
	inf.shot(hx * Vector3(0, 0.1 * inf.body.s, 0), Vector3.UP, true, -1)
	await _secs(1.5)
	_check(inf.state == inf.S.DEAD and inf.body.dead_k > 0.5, "a headshot (with Headshot) puts them down for good")
	world.queue_free()

func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _check(c: bool, what: String) -> void:
	print(("  ok  " if c else "  FAIL ") + what)
	ok = ok and c
