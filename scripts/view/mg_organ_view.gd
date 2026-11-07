extends MgKitView
## ORGAN TRAIL, played in person (FULL_CHARACTER): the Hospital arena, two operating
## tables, and the players themselves, full-sized (the same people who sit at the table,
## built from the same persistent body: what's missing is missing). Each patient strapped
## down, awake, reacting (pain, panic, struggling against the straps, holding still, going
## under); each surgeon bent over them, working (selecting, cutting, clamping, pulling).
## The organ comes out in the surgeon's hands at the end. When it's over GameView brings
## the meat puppets back, carrying whatever the operation did.

var full: Node3D            # in metres
var people: Dictionary = {} # seat -> {human, anim, role}
var tables: Array = []
var organ_nodes: Array = []
var lamps: Array = []
var _roles := {}


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	full = Node3D.new()
	full.scale = Vector3.ONE / GameView.TABLE_SCALE
	add_child(full)
	# hide the puppets: this one's in person
	for s in g.contestants:
		(g.contestants[s] as Node3D).visible = false
	var mg: Dictionary = view.mg
	for i in 2:
		var x := -1.25 + i * 2.5
		var tb := Node3D.new()
		tb.position = Vector3(x, 0, 0)
		full.add_child(tb)
		var mb := MB.new()
		mb.box("w", white, Vector3(0.75, 0.08, 2.0), MB.T(Vector3(0, 0.82, 0)), Color("c9d1d9"))
		mb.cyl("w", white, 0.08, 0.1, 0.8, 8, MB.T(Vector3(0, 0.4, 0)), Color("6a7480"))
		mb.box("w", white, Vector3(0.6, 0.03, 0.4), MB.T(Vector3(0.65, 1.0, -0.4)), Color("e8eef2"))
		for k in 3:
			mb.box("w", white, Vector3(0.8, 0.03, 0.08), MB.T(Vector3(0, 0.98, -0.5 + k * 0.5)), Color("5a3a2a"))
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build()
		tb.add_child(mi)
		tables.append(tb)
		var lamp := SpotLight3D.new()
		lamp.light_color = Color("f8fff8")
		lamp.light_energy = 4.0
		lamp.spot_range = 5.0
		lamp.spot_angle = 28.0
		lamp.position = Vector3(x, 2.6, 0)
		lamp.rotation.x = -PI / 2
		full.add_child(lamp)
		lamps.append(lamp)
		var st: Dictionary = mg.tables[i]
		_person(int(st.patient), tb, "patient", view)
		_person(int(st.surgeon), tb, "surgeon", view)
		var l := Label3D.new()
		l.text = "TABLE %d" % (i + 1)
		l.font = _font
		l.font_size = 60
		l.pixel_size = 0.004
		l.modulate = Color("ffd23f")
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0, 2.0, -1.2)
		tb.add_child(l)
	Audio.music("roulette")


func _person(s: int, tb: Node3D, role: String, view: Dictionary) -> void:
	var seat_d: Dictionary = Seats.seats[s] if s < Seats.seats.size() else {"face": s, "color": Color.WHITE}
	var c: Color = seat_d.get("color", Color.WHITE)
	var spec := {"face": int(seat_d.get("face", s)), "shirt": Color("e8fff4") if role == "surgeon" else c.darkened(0.2),
		"trousers": Color(0.16, 0.15, 0.18), "face_gain": 1.3,
		"hair": [Color("3a2414"), Color("8a6a3a"), Color("1a1410"), Color("b8a070")][s % 4], "long_hair": s % 2 == 1, "bald": s == 3,
		"skin": [Color(0.86, 0.68, 0.58), Color(0.72, 0.52, 0.4), Color(0.9, 0.74, 0.64), Color(0.55, 0.38, 0.28)][s % 4]}
	if role == "surgeon":
		spec.coat = Color("8fd9c0")
	var h := Ps1Human.make(spec)
	if role == "patient":
		# strapped down on the table, face up
		h.position = Vector3(0, 0.95, 0.9)
		h.rotation = Vector3(-PI / 2, 0, 0)
	else:
		h.position = Vector3(-0.75, 0, 0)
		h.rotation.y = PI / 2
	tb.add_child(h)
	var a := BodyAnimator.new()
	h.add_child(a)
	a.setup(h, "full", s)
	var p: Dictionary = view.players[s]
	a.set_state(p.body, p.statuses)
	_losses(h, p.body)
	people[s] = {"human": h, "anim": a, "role": role}
	if role == "patient":
		a.play("struggle")


## The persistent body, on the full-sized person: lost parts aren't there.
func _losses(h: Ps1Human, b: Dictionary) -> void:
	var joints := {"hand_l": h.hand_l, "hand_r": h.hand_r, "arm_l": h.fore_l, "arm_r": h.fore_r, "leg_l": h.shin_l, "leg_r": h.shin_r}
	for part in joints.keys():
		if b.has(part) and str(b[part].s) == "lost":
			(joints[part] as Node3D).scale = Vector3.ONE * 0.02


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	for i in 2:
		var st: Dictionary = mg.tables[i]
		# roles can swap (a Caller's modifier)
		for s in [int(st.patient), int(st.surgeon)]:
			var role := "patient" if s == int(st.patient) else "surgeon"
			if people.has(s) and people[s].role != role:
				(people[s].human as Node3D).queue_free()
				people.erase(s)
				_person(s, tables[i], role, view)
		var pt: Dictionary = people.get(int(st.patient), {})
		if not pt.is_empty():
			var an: BodyAnimator = pt.anim
			var h: Ps1Human = pt.human
			h.head.rotation.y = sin(Time.get_ticks_msec() * 0.004 * (1.0 + float(st.panic) / 30.0)) * (0.1 + float(st.panic) / 200.0)
			if st.dead or st.unconscious:
				h.head.rotation = Vector3(0, 0.6, 0)
			elif not an.playing():
				if float(st.pain) > 55.0:
					an.play("struggle")
				elif st.still:
					an.play("relief")
				elif float(st.panic) > 50.0:
					an.play("panic")
		var sg: Dictionary = people.get(int(st.surgeon), {})
		if not sg.is_empty():
			var sa: BodyAnimator = sg.anim
			if not sa.playing():
				match str(st.stage):
					"incise", "separate", "disconnect":
						sa.play("surgeon_cut")
					"extract":
						sa.play("surgeon_pull")
					"clamp":
						sa.play("pickup")
					"done":
						sa.play("victory")
					_:
						sa.play("look_around")
		(lamps[i] as SpotLight3D).light_color = Color("ffb0b0") if float(st.bleed) > 40.0 else Color("f8fff8")


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	var mg: Dictionary = gv.view.get("mg", {})
	match str(e.k):
		"mistake", "complication":
			Audio.sfx("hurt", 0.1, -4.0)
			var st: Dictionary = mg.tables[int(e.team)] if mg.has("tables") else {}
			if not st.is_empty() and people.has(int(st.patient)):
				people[int(st.patient)].anim.play("flinch")
		"callout":
			Audio.sfx("whisper", 0.0, -4.0)
		"extracted":
			var st2: Dictionary = mg.tables[int(e.team)] if mg.has("tables") else {}
			if not st2.is_empty() and people.has(int(st2.surgeon)):
				people[int(st2.surgeon)].anim.play("victory_arrogant")
				var h: Ps1Human = people[int(st2.surgeon)].human
				var organ := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.08
				sm.height = 0.14
				organ.mesh = sm
				var m := StandardMaterial3D.new()
				m.albedo_color = Color("8a1a24")
				organ.material_override = m
				h.hand_r.add_child(organ)
				organ.position = Vector3(0, -0.12, 0.04)
				Audio.sfx("bell", 0.0, -2.0, 1.2)
		"patient_dies":
			gv.stage.flash(0.4)
			Audio.sfx("death", 0.0, 0.0)
		"sabotage":
			Audio.sfx("kick", 0.05, -4.0)


func _exit_tree() -> void:
	if gv:
		for s in gv.contestants:
			if is_instance_valid(gv.contestants[s]):
				(gv.contestants[s] as Node3D).visible = true


func camera() -> Array:
	return [Vector3(0, 30, 30), Vector3(0, 12, 0), 2.6]
