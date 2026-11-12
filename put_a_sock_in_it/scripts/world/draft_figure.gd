class_name DraftFigure
extends CharacterBody3D
## Flat 48: one of the three that stand in it, white, wrong in proportion (the neck too long, the
## head too small, the arms too long), a paper tag where a heart would be: MAMA, PAPA, CHILD.
## They only move when he isn't looking: they turn to him, and come a little nearer, never
## closer than about a metre. Shot (or beaten down) they're down for good.
## A name stuck on one (`identity`) makes it a mannequin dressed as that person; the wrong name,
## or one that won't take (SONYA), falls off.

signal named(f: DraftFigure, word: String)
signal downed(f: DraftFigure)

const CREEP := 0.35           # m/s, unseen
const NEAREST := 1.1
var id := "mama"              # mama, papa, child
var tag := "MAMA"
var identity := ""            # the name that dresses it; "" = none takes
var tall := 1.72
var player: Player
var down := false
var dressed := ""
var _body: Node3D
var _moved := 0.0             # how far it went while unseen (for the moment he looks back)
var _hp := 30.0
var _seen := true

func _ready() -> void:
	add_to_group("draft_figure")
	# 8: shots and blows find it (as they find her); 4: the hand finds it (a name to stick on);
	# 32: solid to him, like furniture
	collision_layer = 8 | 4 | 32; collision_mask = 1 | 32
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.22; cap.height = tall
	cs.shape = cap; cs.position.y = tall * 0.5; add_child(cs)
	_figure()

func _mat() -> Material:
	return Tex.mat("plaster", 1.5, {"tint": Color(1.25, 1.24, 1.2)})

func _box(parent: Node3D, at: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size); mi.material_override = m
	mi.position = at; mi.rotation = rot; parent.add_child(mi); return mi

func _ball(parent: Node3D, at: Vector3, r: float, m: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = r; sp.height = r * 2.0; sp.radial_segments = 10; sp.rings = 6
	mi.mesh = sp; mi.material_override = m; mi.position = at; mi.scale = squash; parent.add_child(mi); return mi

## The white one: proportions a little wrong in every direction.
func _figure() -> void:
	if _body: _body.queue_free()
	_body = Node3D.new(); add_child(_body)
	var m := _mat()
	var k := tall / 1.72
	var leg := 0.82 * k; var torso := 0.5 * k; var neck := 0.26 * k
	for sx in [-0.08, 0.08]:
		_box(_body, Vector3(sx * k, leg * 0.5, 0), Vector3(0.09, leg, 0.1) * Vector3(k, 1, k), m)
		# the arms hang to the knee
		_box(_body, Vector3(sx * 2.6 * k, leg + torso - 0.42 * k, 0), Vector3(0.055 * k, 0.86 * k, 0.06 * k), m, Vector3(0, 0, sx * 0.25))
	_box(_body, Vector3(0, leg + torso * 0.5, 0), Vector3(0.3, torso, 0.16) * k, m)
	_box(_body, Vector3(0, leg + torso + neck * 0.5, 0), Vector3(0.05, neck, 0.05) * k, m)
	_ball(_body, Vector3(0, leg + torso + neck + 0.06 * k, 0.01), 0.07 * k, m, Vector3(0.9, 1.15, 1.0))
	# the tag, where a heart would be
	var card := _box(_body, Vector3(-0.06 * k, leg + torso * 0.72, 0.085 * k), Vector3(0.09, 0.06, 0.003), Tex.mat("paper_boxes", 6.0, {"tint": Color(1.1, 1.08, 1.0)}))
	var lb := Label3D.new(); lb.text = tag; lb.font_size = 26; lb.pixel_size = 0.0011; lb.modulate = Color(0.12, 0.12, 0.16)
	lb.outline_size = 0; lb.shaded = true; lb.position = Vector3(0, 0, 0.003); card.add_child(lb)

## A shop mannequin, its stand under it, dressed as `who` ("MARTA" or "KURT").
func _mannequin(who: String) -> void:
	_body.queue_free()
	_body = Node3D.new(); add_child(_body)
	var shell := Tex.mat("plaster", 1.0, {"tint": Color(1.15, 1.05, 0.95)})
	var h := 1.72 if who == "MARTA" else 1.78
	var leg := 0.84 * h / 1.72; var torso := 0.52 * h / 1.72
	_box(_body, Vector3(0, 0.02, 0), Vector3(0.36, 0.03, 0.36), Tex.mat("gunmetal"))             # the stand
	_box(_body, Vector3(0, 0.15, -0.02), Vector3(0.025, 0.28, 0.025), Tex.mat("gunmetal"))
	var lower: Material; var upper: Material
	if who == "MARTA":
		lower = Tex.mat("fabric", 3.0, {"tint": Color(0.18, 0.17, 0.2)})       # a dark skirt
		upper = Tex.mat("fabric", 3.0, {"tint": Color(0.32, 0.45, 0.85)})      # the blue cardigan
		for sx in [-0.075, 0.075]: _box(_body, Vector3(sx, leg * 0.3, 0), Vector3(0.08, leg * 0.6, 0.09), shell)
		_box(_body, Vector3(0, leg * 0.78, 0), Vector3(0.34, leg * 0.48, 0.2), lower)
	else:
		lower = Tex.mat("fabric", 3.0, {"tint": Color(0.16, 0.16, 0.17)})      # dark trousers
		upper = Tex.mat("fabric", 3.0, {"tint": Color(0.14, 0.14, 0.16)})      # the dark jacket
		for sx in [-0.08, 0.08]: _box(_body, Vector3(sx, leg * 0.5, 0), Vector3(0.11, leg, 0.12), lower)
	_box(_body, Vector3(0, leg + torso * 0.5, 0), Vector3(0.36, torso, 0.2), upper)
	for sx in [-0.21, 0.21]:
		_box(_body, Vector3(sx, leg + torso - 0.27, 0), Vector3(0.08, 0.56, 0.09), upper, Vector3(0, 0, signf(sx) * 0.08))
		_box(_body, Vector3(sx * 1.08, leg + torso - 0.6, 0), Vector3(0.06, 0.12, 0.05), shell)
	_box(_body, Vector3(0, leg + torso + 0.05, 0), Vector3(0.08, 0.1, 0.08), shell)
	var head := _ball(_body, Vector3(0, leg + torso + 0.2, 0.0), 0.1, shell, Vector3(0.85, 1.1, 0.95))   # no face
	if who == "MARTA":
		for i in 4: _box(_body, Vector3(0, leg + torso - 0.06 - i * 0.1, 0.101), Vector3(0.015, 0.015, 0.006), Tex.mat("enamel"))   # buttons
		_ball(_body, head.position + Vector3(0, 0.07, -0.03), 0.105, Tex.mat("fabric", 4.0, {"tint": Color(0.12, 0.09, 0.08)}), Vector3(1.0, 0.7, 1.05))   # hair
		_ball(_body, head.position + Vector3(0, 0.12, -0.08), 0.05, Tex.mat("fabric", 4.0, {"tint": Color(0.12, 0.09, 0.08)}))                         # up
		_box(_body, head.position + Vector3(0, -0.045, 0.092), Vector3(0.04, 0.012, 0.004), Tex.mat("cloth_red", 1.0, {"emission": Vector3(0.1, 0, 0)}))   # the mouth, painted
	else:
		_box(_body, head.position + Vector3(0, 0.02, 0.092), Vector3(0.15, 0.035, 0.01), Tex.mat("black"))     # a domino mask
		# a bow across the back, a quiver over the shoulder
		# (a bow slung across the back, string out: a curved stave, tip to tip about 1.1 m)
		var bow := Node3D.new(); _body.add_child(bow); bow.position = Vector3(0, leg + torso * 0.5, -0.15); bow.rotation.z = 0.75
		for i in 7:
			var a := (i - 3) * 0.24
			_box(bow, Vector3(0.12 * (1.0 - cos(a)) * 3.0 - 0.04, sin(a) * 0.55, 0), Vector3(0.022, 0.17, 0.022), Tex.mat("wood", 6.0), Vector3(0, 0, -a * 0.9))
		_box(bow, Vector3(-0.04, 0, 0.0), Vector3(0.004, 1.06, 0.004), Tex.mat("black"))
		_box(_body, Vector3(0.1, leg + torso * 0.65, -0.14), Vector3(0.09, 0.42, 0.09), Tex.mat("cloth_red", 4.0, {"tint": Color(0.4, 0.28, 0.2)}), Vector3(0, 0, -0.35))
	# the note, still on it
	var nt := _box(_body, Vector3(-0.07, leg + torso * 0.72, 0.105), Vector3(0.076, 0.076, 0.002), Tex.mat("enamel", 1.0, {"tint": Color(1.0, 0.92, 0.4)}))
	var lb := Label3D.new(); lb.text = who; lb.font_size = 24; lb.pixel_size = 0.001; lb.modulate = Color(0.12, 0.12, 0.16)
	lb.outline_size = 0; lb.shaded = true; lb.position = Vector3(0, 0, 0.002); nt.add_child(lb)

func get_prompt() -> String:
	if down: return ""
	if player and player.held and player.held.has_meta("word"):
		return "Stick \"%s\" on it" % String(player.held.get_meta("word"))
	return ""

func interact(p = null) -> void:
	if down or not (p and p.held and p.held.has_meta("word")): return
	var lv = get_tree().get_first_node_in_group("level")
	if lv and lv.has_method("name_figure"): lv.name_figure(self, p)

func dress(word: String) -> void:
	dressed = word
	_mannequin(word)
	named.emit(self, word)

# ------------------------------------------------------------------ hurt
func shot(_point: Vector3, dir: Vector3) -> void:
	_fall(dir)

func melee_hit(dmg: float, from: Vector3, _knock: float, _by = null) -> void:
	if down: return
	_hp -= dmg
	Sfx.play_at("bone_crack", global_position + Vector3(0, tall * 0.8, 0), -6.0, 1.3)
	if _hp <= 0.0: _fall((global_position - from) * Vector3(1, 0, 1))
	else:
		var tw := create_tween(); tw.tween_property(_body, "rotation:x", -0.12, 0.06); tw.tween_property(_body, "rotation:x", 0.0, 0.3)

func _fall(dir: Vector3) -> void:
	if down: return
	down = true
	collision_layer = 0
	Sfx.play_at("thud", global_position + Vector3(0, 0.5, 0), 0.0, 0.8)
	Sfx.play_at("bone_crack", global_position + Vector3(0, 1.0, 0), -2.0, 0.7)
	var away := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	var axis := Vector3.UP.cross(away).normalized()
	if axis.length() < 0.1: axis = Vector3.RIGHT
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(k): _body.transform = Transform3D(Basis(axis, k * PI * 0.49), Vector3.ZERO), 0.0, 1.0, 0.55)
	tw.tween_callback(func(): Sfx.play_at("thud", global_position, -2.0, 0.6))
	downed.emit(self)

# ------------------------------------------------------------------ watching him
## On his screen with nothing in the way: the head or the middle of it.
func is_seen() -> bool:
	if not player: return true
	var cam := player.cam
	for at in [global_position + Vector3(0, tall * 0.92, 0), global_position + Vector3(0, tall * 0.5, 0)]:
		var d: Vector3 = at - cam.global_position
		if (-cam.global_transform.basis.z).dot(d.normalized()) < 0.55: continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, at, 1, [player.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty(): return true
	return false

func _physics_process(delta: float) -> void:
	if down or not player or player.hidden_in: return
	var seen := is_seen()
	if seen and not _seen and _moved > 0.15:
		# he looks back and it's nearer than it was
		Sfx.play_at("creak", global_position + Vector3(0, tall * 0.6, 0), -10.0, 1.5)
		var nv = get_tree().get_first_node_in_group("level")
		if nv and nv.get("nerve"): nv.nerve.spike(0.12 + 0.1 * clampf(_moved, 0.0, 1.0))
		_moved = 0.0
	_seen = seen
	if seen:
		velocity = Vector3.ZERO
		return
	var to := player.global_position - global_position; to.y = 0.0
	if to.length() < 0.05: return
	# turn to him, at once (it's never caught turning)
	rotation.y = atan2(to.x, to.z)
	# and nearer, if there's a clear way and it isn't already close
	if to.length() > NEAREST:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), player.global_position + Vector3(0, 0.5, 0), 1 | 32, [get_rid(), player.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			velocity = to.normalized() * CREEP
			velocity.y = -1.0
			var before := global_position
			move_and_slide()
			_moved += before.distance_to(global_position)
