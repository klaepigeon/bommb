extends SceneTree
## Socko's animation, eyes and materials, checked by measurement on the test bench (no story):
##   the eyes (separation front / three-quarter / side, at extreme tilts and every deformation; no
##   eye inside the cloth, no cloth through an eye; independent gaze; divided attention; pupil
##   inertia), every clip in the library (plays, stays sane, leaves him as it found him), the
##   expressions (the mouth's corners actually move), the emotional states (obeyed / defied move
##   him through them and back), dialogue cues (tags stripped, fired on their word, pause,
##   interrupt), talking styles, entrances and exits, cutscene interruption, and the stain layers.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/socko_anim_test.gd

var ok := true
var bench: Node3D
var s
var rig: SockRig
var cam: Camera3D

func _initialize() -> void:
	bench = load("res://scenes/socko_test.tscn").instantiate()
	root.add_child(bench)
	await _frames(20)
	s = bench.socko; rig = s.rig; cam = bench.cam
	print("== construction")
	await _construction()
	print("== eyes: separation and clipping, every pose")
	await _eyes_everywhere()
	print("== eyes: independent")
	await _independent_eyes()
	print("== pupils")
	await _pupils()
	print("== expressions")
	await _expressions()
	print("== the library: every clip")
	await _every_clip()
	print("== emotional states")
	await _states()
	print("== dialogue")
	await _dialogue()
	print("== entrances, exits, interruption")
	await _entrances()
	print("== materials")
	_materials()
	print("SOCKO ANIM ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

# ---------------------------------------------------------------- construction
func _construction() -> void:
	var spheres := true
	for e in rig.eyes:
		var bm: SphereMesh = (e.ball as MeshInstance3D).mesh
		spheres = spheres and bm != null and not bm.is_hemisphere and absf(bm.height - bm.radius * 2.0) < 1e-6
		spheres = spheres and (e.disc as Node3D).get_child_count() >= 4 and (e.disc as Node3D).get_parent() == e.root
	_check(rig.eyes.size() == 2 and spheres, "two eyes: each a whole sphere (ping-pong ball) with its own googly assembly (card, rim, dome, pupil)")
	var r0: float = rig.eyes[0].radius; var r1: float = rig.eyes[1].radius
	_check(r0 > 0.016 and r1 > 0.016, "the balls are not shrunk to hide anything (r %.1f / %.1f mm; the old discs were 24 / 23 mm)" % [r0 * 1000.0, r1 * 1000.0])
	_check(rig.eye_gap() > SockRig.EYE_GAP_MIN, "at rest the balls stand %.1f mm apart (the old eyes overlapped by ~22 mm)" % (rig.eye_gap() * 1000.0))
	_check(rig.skel.find_bone("corner_l") >= 0 and rig.skel.find_bone("corner_r") >= 0, "the rig has mouth-corner bones for smiles and frowns")

# ---------------------------------------------------------------- eye geometry
var _sock_v: PackedVector3Array; var _sock_w: Array = []
func _sock_points() -> PackedVector3Array:
	if _sock_v.is_empty():
		var arr := rig.sock.mesh.surface_get_arrays(0)
		_sock_v = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]; var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in _sock_v.size():
			var w := {}
			for k in 4:
				if wts[i * 4 + k] > 0.0: w[bones[i * 4 + k]] = wts[i * 4 + k]
			_sock_w.append(w)
	var out := PackedVector3Array()
	for i in _sock_v.size():
		out.append(rig.skin_point(_sock_v[i], _sock_w[i]))
	return out

## Worst numbers over the current pose: 3D gap, on-screen gap from the given cameras, how deep any
## cloth goes into a ball, whether a googly eye has gone into the cloth.
func _measure(views: Array) -> Dictionary:
	var m := {"gap": rig.eye_gap(), "screen": INF, "apart34": INF, "engulf": 0.0, "googly_in": false}
	var c0 := rig.eye_center(0); var c1 := rig.eye_center(1)
	var r0: float = rig.eyes[0].radius; var r1: float = rig.eyes[1].radius
	for i in views.size():
		var vc: Camera3D = views[i]
		var p0 := vc.unproject_position(c0); var p1 := vc.unproject_position(c1)
		var d := vc.global_position.distance_to(c0)
		var px := vc.get_viewport().get_visible_rect().size.y / (2.0 * tan(deg_to_rad(vc.fov) * 0.5))
		var rsum := (r0 / d + r1 / vc.global_position.distance_to(c1)) * px
		if i == 0 or i == 3:
			m.screen = minf(m.screen, p0.distance_to(p1) - rsum)      # front: two whole circles, clear of each other
		else:
			m.apart34 = minf(m.apart34, p0.distance_to(p1) / rsum)    # three-quarter: one in front of the other, both read
	# cloth inside a ball: the ball is glued into the felt (a shallow nest), but no cloth may reach
	# its middle (that would come out through the other side)
	for p in _sock_points():
		m.engulf = maxf(m.engulf, maxf(1.0 - p.distance_to(c0) / r0, 1.0 - p.distance_to(c1) / r1))
	for i in 2:
		var st := rig.eye_seat(i)
		var disc: Node3D = rig.eyes[i].disc
		# the googly eye's rim must stay outside the felt's plane at the seat
		var ra: float = rig.eyes[i].ra
		var lowest := (disc.global_position - st.origin).dot(st.basis.y) - ra * sqrt(maxf(0.0, 1.0 - pow(disc.global_transform.basis.y.normalized().dot(st.basis.y), 2.0)))
		if lowest < -0.001: m.googly_in = true
	return m

func _views() -> Array:
	# front, three-quarter (both sides) and side cameras around the head, as the bench's presets
	var out := []
	var hg := rig.head_global(); var b := hg.basis.orthonormalized()
	for dir in [-b.z, (-b.z + b.x).normalized(), (-b.z - b.x).normalized(), (-b.z + b.y * 0.5).normalized()]:
		var c := Camera3D.new(); c.fov = 50.0; root.add_child(c)
		c.global_position = hg.origin + dir * 0.32
		c.look_at(hg.origin, b.y)
		out.append(c)
	return out

func _eyes_everywhere() -> void:
	s.set_process(false)
	var worst := {"gap": INF, "screen": INF, "apart34": INF, "engulf": 0.0, "googly_in": false}
	var where := {}
	var poses := []
	for sq in [-1.0, 0.0, 1.0]:
		for st in [-1.0, 0.0, 1.0]:
			for tw in [-1.0, 0.0, 1.0]:
				poses.append({"squash": sq, "stretch": st, "twist": tw})
	for j in [0.0, 0.7, 1.4]:
		for cu in [-1.0, 1.0]:
			poses.append({"jaw": j, "curl": cu})
	for wr in [Vector3(0.9, 0, 0), Vector3(-1.0, 0, 0), Vector3(0, 0.85, 0), Vector3(0, -0.85, 0), Vector3(0, 0, 0.9), Vector3(0, 0, -0.9), Vector3(0.6, 0.6, 0.6)]:
		poses.append({"wrist": wr, "squash": 1.0, "jaw": 1.0})
	for sm in [-1.0, 1.0]:
		poses.append({"smile_l": sm, "smile_r": -sm, "wide": 1.0, "jaw": 0.5})
	for p in poses:
		for k in ["squash", "stretch", "twist", "jaw", "curl", "smile_l", "smile_r", "wide", "pucker"]: rig.set(k, 0.0)
		rig.wrist = Vector3.ZERO
		for k in p: rig.set(k, p[k])
		rig.apply_pose()
		var views := _views()
		var m := _measure(views)
		for v in views: v.queue_free()
		for k in ["gap", "screen", "apart34"]:
			if m[k] < worst[k]: worst[k] = m[k]; where[k] = p
		if m.engulf > worst.engulf: worst.engulf = m.engulf; where.engulf = p
		worst.googly_in = worst.googly_in or m.googly_in
	for k in ["squash", "stretch", "twist", "jaw", "curl", "smile_l", "smile_r", "wide", "pucker"]: rig.set(k, 0.0)
	rig.wrist = Vector3.ZERO; rig.apply_pose()
	s.set_process(true)
	_check(worst.gap > 0.004, "the balls never touch over %d poses: max squash, stretch, twist, jaw, curl, extreme tilts (least gap %.1f mm at %s)" % [poses.size(), worst.gap * 1000.0, where.get("gap")])
	_check(worst.screen > 0.0, "front on, the two balls never overlap on screen (least gap %.1f px at %s)" % [worst.screen, where.get("screen")])
	_check(worst.apart34 > 0.55, "from three-quarter both still read as two eyes (centres %.0f%% of the radii apart, at %s)" % [worst.apart34 * 100.0, where.get("apart34")])
	_check(worst.engulf < 0.45, "no cloth reaches into the middle of a ball (deepest %.0f%% of a radius: the glue nest; at %s)" % [worst.engulf * 100.0, where.get("engulf")])
	_check(not worst.googly_in, "the googly eyes never turn into the felt")

# ---------------------------------------------------------------- independent eyes
func _look_err(i: int, at: Vector3) -> float:
	var disc: Node3D = rig.eyes[i].disc
	return rad_to_deg(disc.global_transform.basis.y.normalized().angle_to((at - rig.eye_center(i)).normalized()))

func _independent_eyes() -> void:
	var d: SockoDirector = s.director
	s.pose_face = 1.0
	d.eyes_reset()
	await _secs(1.5)
	var kurt := cam.global_position
	var door: Vector3 = bench.door_marker.global_position
	# a thing beside Kurt, within a googly eye's turn (the door is behind Socko's head now)
	var cb := cam.global_transform.basis
	var near: Vector3 = cam.global_position + cb.x * 0.22 - cb.y * 0.08
	bench.marker.global_position = near
	# both on Kurt to begin with
	d.eye_track([{"at": 0.0, "eye": 2, "look": "kurt", "rate": 30.0, "hold": 1.0}])
	await _secs(0.6)
	var together := maxf(_look_err(0, kurt), _look_err(1, kurt))
	_check(together < 12.0, "both eyes can look together at Kurt (worst %.1f°)" % together)
	# the signature: divided attention
	var head0: Vector3 = s.gaze_point
	var head_dir0 := -rig.head_global().basis.z.normalized()
	d.divided_attention("marker", 0.9)
	var e: int = d._eye_side(near)
	var mid_on_door := 180.0; var other_on_kurt := 180.0; var head_moved := 0.0
	var t := 0.0; _dt()
	while t < 1.2:
		await process_frame; t += _dt()
		if t > 0.65 and t < 1.15:
			mid_on_door = minf(mid_on_door, _look_err(e, near))
			other_on_kurt = minf(other_on_kurt, _look_err(1 - e, kurt))
		head_moved = maxf(head_moved, rad_to_deg(head_dir0.angle_to(-rig.head_global().basis.z.normalized())))
	await _secs(1.8)
	var back := maxf(_look_err(0, kurt), _look_err(1, kurt))
	_check(mid_on_door < 12.0 and other_on_kurt < 12.0, "divided attention: one eye goes to the thing beside Kurt (%.1f° off it) while the other stays on Kurt (%.1f°)" % [mid_on_door, other_on_kurt])
	_check(head_moved < 8.0, "…and the head doesn't move for it (%.1f°)" % head_moved)
	_check(back < 15.0 and d.behaviour == "", "…then both are back on Kurt as if nothing happened (%.1f°)" % back)
	# out of reach (the door, behind his head): the eye goes as far round as a googly eye can
	d.divided_attention("door", 0.9)
	var split := 0.0
	t = 0.0; _dt()
	while t < 1.2:
		await process_frame; t += _dt()
		split = maxf(split, rad_to_deg((rig.eyes[0].disc as Node3D).global_transform.basis.y.angle_to((rig.eyes[1].disc as Node3D).global_transform.basis.y)))
	await _secs(2.0)
	_check(split > 25.0, "…and toward something out of reach the glancing eye still turns well away from the other (%.0f° apart)" % split)
	# the variations run and end
	var all_ran := true
	for b in [["examine", ["marker", 1.0]], ["sound_glance", [bench.marker.global_position, 0.5]], ["staggered_return", ["marker", 0.6, 0.4]],
			["upward_glance", [0, 0.4]], ["fixed_while_turning", [1.0]], ["converge", ["marker", 1.2]], ["track_and_distracted", [1.6]], ["sync_snap", ["door", 0.8]]]:
		d.callv(b[0], b[1])
		await _frames(8)
		var started: bool = d.behaviour == b[0]
		await _secs(2.4)
		all_ran = all_ran and started and d.behaviour == ""
		if not (started and d.behaviour == ""): print("    eye behaviour %s: started %s, ended %s" % [b[0], started, d.behaviour == ""])
	_check(all_ran, "every eye behaviour starts and hands the eyes back (examine, sound, staggered return, upward glance, fixed while turning, converge, distracted, sync snap)")
	# staggered: one returns first
	d.staggered_return("door", 0.8, 0.5)
	await _secs(1.05)
	var e0 := _look_err(0, kurt); var e1 := _look_err(1, kurt)
	_check(absf(e0 - e1) > 10.0, "one eye returns to Kurt before the other (%.0f° vs %.0f°)" % [e0, e1])
	await _secs(1.5)
	# fixed while the head turns: the googly eye counter-turns on its ball
	d.eye_track([{"at": 0.0, "eye": 2, "look": near, "rate": 40.0, "hold": 3.0}])
	await _secs(0.5)
	var before := _look_err(0, near)
	var hd0 := -rig.head_global().basis.z.normalized()
	d.play("Head_Snap", {"amp": 0.8})
	await _secs(0.35)
	var turned := rad_to_deg(hd0.angle_to(-rig.head_global().basis.z.normalized()))
	var during := _look_err(0, near)
	_check(during < 10.0 and turned > 10.0, "a googly eye stays on its point while the head turns %.0f° under it (%.1f° → %.1f° off)" % [turned, before, during])
	d.eyes_reset()
	s.pose_face = 0.0
	await _secs(1.0)

# ---------------------------------------------------------------- pupils
func _pupils() -> void:
	await _secs(1.5)
	var p0: Vector2 = rig.eyes[0].p; var p1: Vector2 = rig.eyes[1].p
	var moved := [0.0, 0.0]
	s.director.play("Head_Snap")
	var t := 0.0; _dt()
	while t < 0.5:
		await process_frame; t += _dt()
		moved[0] = maxf(moved[0], (rig.eyes[0].p as Vector2).distance_to(p0) / float(rig.eyes[0].r))
		moved[1] = maxf(moved[1], (rig.eyes[1].p as Vector2).distance_to(p1) / float(rig.eyes[1].r))
	_check(moved[0] > 0.2 and moved[1] > 0.2, "a head snap throws both pupils (%.0f%% / %.0f%% of their travel)" % [moved[0] * 100.0, moved[1] * 100.0])
	# they settle, and not in lockstep
	var settled := [-1.0, -1.0]
	t = 0.0; _dt()
	while t < 4.0 and (settled[0] < 0.0 or settled[1] < 0.0):
		await process_frame; t += _dt()
		for i in 2:
			if settled[i] < 0.0 and t > 0.2 and (rig.eyes[i].v as Vector2).length() < 0.004: settled[i] = t
	_check(settled[0] >= 0.0 and settled[1] >= 0.0, "…and settle again (at %.2f s and %.2f s)" % [settled[0], settled[1]])
	# no constant random movement: his ordinary idle sway doesn't keep them rattling
	await _secs(1.5)
	var moving := 0; var frames := 0
	var tt := 0.0; _dt()
	while tt < 2.0:
		await process_frame; tt += _dt(); frames += 1
		if (rig.eyes[0].v as Vector2).length() > 0.004 or (rig.eyes[1].v as Vector2).length() > 0.004: moving += 1
	_check(moving < frames * 0.1, "idling, the pupils rest (moving in %d of %d frames): no constant random movement" % [moving, frames])

# ---------------------------------------------------------------- expressions
func _expressions() -> void:
	var d: SockoDirector = s.director
	var moved_all := true
	for e in SockoClips.EXPRESSIONS:
		if e == "neutral": continue
		d.set_expression(e, 1.0, -1.0)
		await _secs(0.7)
		var face := absf(rig.smile_l) + absf(rig.smile_r) + absf(rig.wide) + absf(rig.pucker) + rig.jaw + absf(rig.squash) + absf(rig.stretch)
		if face < 0.15:
			moved_all = false; print("    expression %s hardly moves the face (%.2f)" % [e, face])
	d.set_expression("smile", 1.0, -1.0); await _secs(0.8)
	var smile_y := _corner_y()
	d.set_expression("frown", 1.0, -1.0); await _secs(0.8)
	var frown_y := _corner_y()
	d.clear_expression(); await _secs(0.5)
	_check(moved_all, "every expression moves the geometry (corners, jaw, squash/stretch), not just the eyes")
	_check(smile_y - frown_y > 0.012, "smile lifts the corners of the mouth, frown pulls them down (%.1f mm apart)" % ((smile_y - frown_y) * 1000.0))

func _corner_y() -> float:
	var h := rig.bone_global(SockRig.B.HAND)
	return (h.affine_inverse() * rig.bone_global(SockRig.B.CORNER_L).origin).y

# ---------------------------------------------------------------- every clip
func _rig_snapshot() -> Dictionary:
	return {"squash": rig.squash, "stretch": rig.stretch, "twist": rig.twist, "curl": rig.curl}

func _every_clip() -> void:
	var d: SockoDirector = s.director
	d.idle_lock = "Idle_Default"; d.set_state("companion")
	await _secs(2.0)
	var base := _rig_snapshot()
	var bad := []
	var gap_min := INF
	var n := 0
	for clip in SockoClips.INFO:
		var cat: String = SockoClips.INFO[clip][4]
		if cat == "talk":
			s.say("Testing, testing, one two three, okay.", "neutral", 1.0, clip)
		elif cat == "idle":
			d.idle_lock = clip
		else:
			d.play(clip)
		var len := SockoClips.length(clip)
		var t := 0.0; _dt()
		var sane := true
		var played := false
		while t < minf(len, 3.0) + 0.1:
			await process_frame; t += _dt()
			played = played or d.playing(clip)
			var vals := [rig.squash, rig.stretch, rig.twist, rig.jaw, rig.curl, rig.wrist.x, rig.wrist.y, rig.wrist.z]
			for v in vals:
				if not is_finite(v): sane = false
			gap_min = minf(gap_min, rig.eye_gap())
		if cat == "talk": s.interrupt()
		if cat == "idle": d.idle_lock = "Idle_Default"
		if cat == "exit":
			sane = sane and d.hidden()
			d.play("Enter_Pop")
		await _secs(1.6)
		var after := _rig_snapshot()
		var left := 0.0
		for k in base: left = maxf(left, absf(after[k] - base[k]))
		if not played or not sane or left > 0.12 or d.hidden():
			bad.append("%s (played %s, sane %s, left %.2f, hidden %s)" % [clip, played, sane, left, d.hidden()])
		n += 1
	d.idle_lock = ""; d.set_state("")
	for b in bad: print("    ", b)
	_check(bad.is_empty(), "all %d clips play, stay finite, and leave him in his own shape afterwards (exits held, then undone)" % n)
	_check(gap_min > 0.004, "…and through all of them the eyes keep apart (least gap %.1f mm)" % (gap_min * 1000.0))

# ---------------------------------------------------------------- states
func _states() -> void:
	var d: SockoDirector = s.director
	d.set_stage("companion"); d.defiance = 0.0; d.set_state("")
	await _secs(0.5)
	var seen := [d.state]
	for i in 6:
		d.defied(1.0)
		await _secs(0.4)
		if seen.back() != d.state: seen.append(d.state)
	_check(seen == ["companion", "frustrated", "angry"], "defying him: companion → frustrated → angry (%s)" % [seen])
	for i in 8:
		d.obeyed(1.0)
		await _secs(0.3)
		if seen.back() != d.state: seen.append(d.state)
	_check(d.state == "companion", "doing what he says brings him back round (%s)" % d.state)
	d.set_stage("manipulator"); await _secs(0.5)
	var ok_state := d.state == "manipulator"
	for st in SockoDirector.STATE_ORDER:
		d.set_state(st); await _secs(0.8)
		ok_state = ok_state and d.state == st and is_finite(rig.squash)
	d.set_state("")
	_check(ok_state, "every state can be set by script (presenter, companion, manipulator, frustrated, angry)")
	# the angry leak: dead still, then cheerful
	d.set_state("angry"); d._leak_t = 0.0
	await _secs(0.5)
	var still := float(d.channels.get("still", 0.0))
	await _secs(1.6)
	var cheer: String = d.expr
	_check(still > 0.6 and cheer == "forced_happiness", "angry: he goes dead still (still %.2f), then straight back to cheerful (%s)" % [still, cheer])
	d.set_state(""); d.set_stage("presenter"); d.defiance = 0.0
	for seq in SockoDirector.SEQUENCES:
		d.sequence(seq)
		await _secs(0.4)
	await _secs(4.0)
	_check(not d.performing(), "all six transitions play through")

# ---------------------------------------------------------------- dialogue
func _dialogue() -> void:
	var d: SockoDirector = s.director
	d.clear_expression()
	s.say("Hey. I hear you. {expr:uncomfortable_smile:3.0} I do. {eye:R:door:1.0} Really.", "lying", 0.8)
	_check(not s.history.back().contains("{") and s.history.back() == "Hey. I hear you. I do. Really.", "inline cues are stripped from the line (\"%s\")" % s.history.back())
	var fired_at := -1.0
	var t := 0.0; _dt()
	while s.talking and t < 6.0:
		await process_frame; t += _dt()
		if fired_at < 0.0 and d.expr == "uncomfortable_smile": fired_at = s._speech_t
	var word_t: float = s._segs[s._word_starts[4][1]].t
	_check(fired_at >= 0.0 and absf(fired_at - word_t) < 0.15, "a cue fires on its word (%.2f s, word at %.2f s)" % [fired_at, word_t])
	await _secs(0.5)
	# the line's talking style
	s.say("Look at me. Look. At me.", "", 0.8, "Talking_Sympathetic")
	await _frames(3)
	_check(d.playing("Talking_Sympathetic"), "a line can ask for its talking style (Talking_Sympathetic)")
	s.interrupt()
	_check(not s.talking and not d.playing("Talking_Sympathetic"), "interrupt cuts the line and its talking clip")
	# pause
	s.say("Wait. {pause:1.0} Okay.", "", 1.0)
	var paused_max := 0.0
	var last := -1.0; var held := 0.0
	t = 0.0; _dt()
	while s.talking and t < 5.0:
		await process_frame; t += _dt()
		if absf(s._speech_t - last) < 1e-6: held += 1.0 / 60.0
		last = s._speech_t
	_check(held > 0.8, "{pause} holds the line (%.2f s)" % held)
	# divided attention from dialogue
	s.pose_face = 1.0
	s.say("I'm listening. {divided:door} Go on.", "lying", 0.8)
	var divided := false
	t = 0.0; _dt()
	while t < 3.0:
		await process_frame; t += _dt()
		divided = divided or d.behaviour == "divided_attention"
	_check(divided, "dialogue can trigger divided attention ({divided:door})")
	s.pose_face = 0.0
	await _secs(2.0)
	# mouth shapes vary with the vowels (not one flap)
	s.say("Ooh, you, too. Eee, tea, please.", "", 1.0)
	var pk_max := 0.0; var wd_max := 0.0
	t = 0.0; _dt()
	while s.talking and t < 5.0:
		await process_frame; t += _dt()
		pk_max = maxf(pk_max, rig.pucker); wd_max = maxf(wd_max, rig.wide)
	_check(pk_max > 0.15 and wd_max > 0.1, "the mouth changes shape with the vowels: purses on o/u (%.2f), widens on e/i (%.2f)" % [pk_max, wd_max])

# ---------------------------------------------------------------- entrances
func _entrances() -> void:
	var d: SockoDirector = s.director
	var hand0 := rig.bone_global(SockRig.B.HAND).origin
	d.play("Exit_Drop")
	await _secs(1.2)
	var gone := rig.bone_global(SockRig.B.HAND).origin
	var path := 0.0; var last := gone; var jumps := 0.0
	d.play("Enter_Rise", {"fade": 0.0})
	var t := 0.0; _dt()
	while t < 3.3:
		await process_frame; t += _dt()
		var h := rig.bone_global(SockRig.B.HAND).origin
		jumps = maxf(jumps, h.distance_to(last)); path += h.distance_to(last); last = h
	_check(gone.distance_to(hand0) > 0.2 and last.distance_to(hand0) < 0.05, "exit drops him out of view (%.2f m) and an entrance brings him back (%.3f m off)" % [gone.distance_to(hand0), last.distance_to(hand0)])
	_check(jumps < 0.05, "…moving through space, not teleporting (largest step per frame %.3f m)" % jumps)
	# between cuts: gone during a fast turn
	d.exit_between_cuts(5.0)
	await _frames(10)
	var still_there := not d.hidden()
	for i in 6:
		bench.yaw += 0.25; await process_frame
	await _frames(3)
	_check(still_there and d.hidden(), "he disappears between camera movements (only once the camera whips round)")
	d.appear_when_turned(6.0)
	for i in 20:
		bench.yaw += 0.2; await process_frame
	await _secs(0.3)
	_check(not d.hidden() and d.playing("Enter_Already_There"), "and he's already there when you turn round (%s)" % d.describe())
	await _secs(2.0)
	bench.yaw = 0.0
	# a cutscene interrupts: its clip takes the body from a running reaction at once
	d.play("Laughing")
	await _secs(0.3)
	d.play("Head_Drop", {"layer": SockoClips.L.CUTSCENE, "fade": 0.05, "amp": 1.0})
	await _secs(0.25)
	var laugh_w := 0.0
	for tr in d.layers[SockoClips.L.REACTION]:
		if tr.clip == "Laughing": laugh_w = tr.w
	var cut_ok: bool = d.playing("Head_Drop") and d.channels.get("head", Vector3.ZERO).x < -0.2
	_check(cut_ok, "a cutscene clip interrupts a reaction and takes the body (head pitch %.2f)" % d.channels.get("head", Vector3.ZERO).x)
	await _secs(3.0)

# ---------------------------------------------------------------- materials
func _materials() -> void:
	var m: ShaderMaterial = rig.sock_mat
	_check(m != null and float(m.get_shader_parameter("stain_amount")) > 0.0 and m.get_shader_parameter("stain_tex") != null, "the sock carries the stain layers (blood, mould, urine)")
	var arr := rig.sock.mesh.surface_get_arrays(0)
	_check(arr[Mesh.ARRAY_TEX_UV2] != null and (arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size() == (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "the stains are mapped on the skinned mesh itself (UV2 + vertex hints), so they deform with it")
	var img: Image = (m.get_shader_parameter("stain_tex") as Texture2D).get_image()
	var cov := Vector3.ZERO
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			cov += Vector3(1.0 if c.r > 0.2 else 0.0, 1.0 if c.g > 0.2 else 0.0, 1.0 if c.b > 0.2 else 0.0)
	cov /= float(img.get_width() * img.get_height())
	_check(cov.x > 0.03 and cov.x < 0.3 and cov.y > 0.05 and cov.y < 0.45 and cov.z > 0.05 and cov.z < 0.4,
		"each layer is there and none dominates (cover: blood %.0f%%, mould %.0f%%, urine %.0f%%)" % [cov.x * 100.0, cov.y * 100.0, cov.z * 100.0])

# ---------------------------------------------------------------- helpers
var _last_tick := 0
## Real seconds since the last call (the loops measure time as the game does, not by frame count).
func _dt() -> float:
	var now := Time.get_ticks_msec()
	var d := (now - _last_tick) / 1000.0 if _last_tick > 0 else 0.0
	_last_tick = now
	return minf(d, 0.2)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _check(c: bool, what: String) -> void:
	print(("  ok  " if c else "  FAIL ") + what)
	ok = ok and c
