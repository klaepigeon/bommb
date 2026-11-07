extends MgKitView
## LAST MAN BREATHING in the Hospital: two glass tanks side by side, each puppet in one, the
## gas colouring the glass (clean blue / foul purple), the pipe on top knocking and the
## gauge twitching just before it turns, the air and the gas on a meter above each.

var tanks: Dictionary = {}    # seat -> {glass, gauge, label}


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	var mg: Dictionary = view.mg
	var k := 0
	for s in mg.seats:
		var x := -2.6 + k * 5.2
		part(func(mb: MB):
			mb.cyl("w", white, 1.7, 1.7, 0.3, 14, MB.T(Vector3(x, 0.15, 0)), Color("c9d1d9"))
			mb.cyl("w", white, 1.7, 1.7, 0.3, 14, MB.T(Vector3(x, 4.2, 0)), Color("c9d1d9"))
			mb.cyl("w", white, 0.2, 0.2, 2.0, 8, MB.T(Vector3(x, 5.2, 0)), Color("8a96a4")))
		var glass := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.6
		cm.bottom_radius = 1.6
		cm.height = 3.8
		glass.mesh = cm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.5, 0.8, 1.0, 0.18)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.material_override = m
		glass.position = Vector3(x, 2.2, 0)
		add_child(glass)
		var gauge := part(func(mb: MB): mb.box("w", white, Vector3(0.1, 0.5, 0.05), MB.T(Vector3(0, 0.25, 0)), Color("ff3b3b")))
		gauge.position = Vector3(x + 1.0, 5.0, 0.3)
		var l := label("", Vector3(x, 6.3, 0), 50, Color("fff4dc"))
		tanks[int(s)] = {"glass": glass, "mat": m, "gauge": gauge, "label": l}
		put(int(s), Vector3(x, 0.3, 0), Vector3(0, 1.5, 6))
		k += 1
	Audio.music("roulette")


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	for s in mg.seats:
		var t: Dictionary = tanks.get(int(s), {})
		if t.is_empty():
			continue
		var foul: bool = mg.foul.get(s, false)
		(t.mat as StandardMaterial3D).albedo_color = Color(0.6, 0.2, 0.8, 0.45) if foul else Color(0.5, 0.8, 1.0, 0.18)
		var knock: bool = mg.knock.get(s, false)
		(t.gauge as Node3D).rotation.z = (sin(Time.get_ticks_msec() * 0.05) * 0.6) if knock else (0.9 if foul else -0.6)
		(t.label as Label3D).text = "%s\nAIR %d  GAS %d%s" % [name_of(int(s)), int(mg.air[s]), int(mg.tox[s]), "\nHOLDING" if mg.holding.get(s, false) else ""]
		var c := fig(int(s))
		if not c.dead and gv.anims.has(int(s)):
			if (mg.under as Array).has(s):
				if not gv.anims[int(s)].playing():
					act(int(s), "collapse")
			elif mg.holding.get(s, false):
				c.human.head.rotation.x = 0.2
			elif foul and not gv.anims[int(s)].playing():
				act(int(s), "cough")


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"foul":
			Audio.sfx("buzz", 0.0, -8.0, 0.6)
		"gasp":
			act(int(e.seat), "panic")
		"under":
			act(int(e.seat), "collapse")
			Audio.sfx("hurt", 0.1, 0.0)


func camera() -> Array:
	return [Vector3(0, 5, 9), Vector3(0, 2.4, 0), 1.0]
