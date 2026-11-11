extends SceneTree
## Socko as the health bar: Kurt's health, the four states, the flinch, the perk, the blood, and
## what Marta's hands cost. With `pics` it saves a picture of each state to user://vitals/.
##   godot --path hysteria -s tools/vitals_test.gd [-- pics]

var bad := 0
func step(what: String, ok: bool) -> void:
	if not ok: bad += 1
	print(("  ok  " if ok else " FAIL ") + what)

func wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end: await process_frame

func _initialize() -> void:
	var shots := "pics" in OS.get_cmdline_user_args()
	load("res://scripts/core/save_game.gd").wipe()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5: await process_frame
	var main: Node = current_scene; var p: Node = main.player; var s: Node = main.socko
	main.encounter.skip(); main.socko_intro.skip(); root.get_node("Game").flags["socko_intro_done"] = true
	await wait(1.0)
	p.global_position = Vector3(5.0, 0.02, 3.2); p.yaw = 2.2; p.pitch = -0.25
	s.pose_face = 0.6          # held up where it can be seen
	step("Kurt starts whole, Socko fine", p.health == 1.0 and s.vitals.tier == 0)
	var V = load("res://scripts/socko/socko_vitals.gd")
	step("the four states by health", V.tier_of(0.9) == 0 and V.tier_of(0.6) == 1 and V.tier_of(0.3) == 2 and V.tier_of(0.1) == 3)
	if shots: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://vitals"))
	var rest: Dictionary = {}
	for h in [1.0, 0.6, 0.35, 0.1]:
		p.health = h; p._unhurt = -100.0
		await wait(2.5)
		var vt: Dictionary = s._vt
		if h == 1.0: rest = vt.duplicate()
		print("    health %.2f: tier %d  d %.2f  wound %.2f  squash %.2f  curl %.2f  tremble %.2f  lazy %.2f  lift %.3f" % [h, s.vitals.tier, s.vitals.d, s.vitals.wound, vt.squash, vt.curl, vt.tremble, vt.lazy, vt.lift])
		if shots: root.get_texture().get_image().save_png("user://vitals/state_%d.png" % s.vitals.tier)
	step("dying: slumped, curled, shaking, bleeding, one eye slow", s.vitals.tier == 3 and s._vt.curl > rest.curl + 0.25 and s._vt.tremble > 0.6 and s.vitals.wound > 0.8 and s._vt.lazy > 0.8 and s._vt.lift < -0.015)
	# the heartbeat shows up while dying
	var peak := 0.0
	var end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < end:
		peak = maxf(peak, float(s._vt.beat)); await process_frame
	step("dying: a hard heartbeat through the cloth (%.2f)" % peak, peak > 0.2)
	# a hit: flinch, and he says so
	p.health = 1.0; s.vitals.wound = 0.0; await wait(3.0)
	var before: float = s._vt.stretch
	p.hurt(0.3)
	await process_frame; await process_frame
	step("a hit: he flinches (stretch %.2f -> %.2f) and Kurt's at %.2f" % [before, s._vt.stretch, p.health], s._vt.stretch < -0.3 and absf(p.health - 0.7) < 0.01)
	step("and he says so", s.talking)
	# it comes back on its own, slowly; the blood stays longer than the hurt
	p._unhurt = 100.0
	var h0: float = p.health
	await wait(2.0)
	step("left alone, his strength comes back (%.2f -> %.2f)" % [h0, p.health], p.health > h0)
	p.health = 1.0; await wait(4.0)
	step("the blood dries slower than he heals (wound %.2f, damage shown %.2f)" % [s.vitals.wound, s.vitals.d], s.vitals.wound > s.vitals.d + 0.1)
	# saved and loaded
	p.health = 0.45; main.save_game.save(); p.health = 1.0; main.save_game.load_game()
	step("health is saved with the game (%.2f)" % p.health, absf(p.health - 0.45) < 0.01)
	# no NaN, ever
	var ok := true
	for k in s._vt: if not is_finite(float(s._vt[k])): ok = false
	step("no bad numbers in his pose", ok)
	load("res://scripts/core/save_game.gd").wipe()
	print("VITALS ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
