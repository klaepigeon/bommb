class_name DraftBlock
extends StaticBody3D
## Flat 48: a piece of Flat 47's furniture as reality only sketched it: a white block exactly
## where the thing stands in 47, a paper tag on it. Under it, hidden, the thing itself (the
## export's own meshes, and the loose things on it). The right word stuck on it (`identity`)
## and the block is gone and the thing is there, solid, the note still on it. Any other word
## won't stay on. Blocks with no identity stay white.
## (A hotspot on layer 4, a little proud of the furniture's own collider, so the hand finds it.)

signal realised(b: DraftBlock)

var identity := ""            # the word that makes it real ("" = never)
var tag := ""                 # what's written on its tag (shown when read)
var half := Vector3.ONE * 0.5
var real_nodes: Array = []    # the furniture and the things on it, hidden till it's real
var is_real := false
var _mesh: MeshInstance3D

func build(mat: Material) -> void:
	collision_layer = 4; collision_mask = 0
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = half * 2.0 + Vector3(0.04, 0.04, 0.04)
	cs.shape = sh; add_child(cs)
	_mesh = MeshInstance3D.new(); _mesh.mesh = Build.box_mesh(half * 2.0); _mesh.material_override = mat
	add_child(_mesh)
	# the tag: a card tied on at the front corner, a few lines of pencil on it
	var card := MeshInstance3D.new(); card.mesh = Build.box_mesh(Vector3(0.07, 0.045, 0.002))
	card.material_override = Tex.mat("paper_boxes", 6.0, {"tint": Color(1.1, 1.08, 1.0)})
	add_child(card)
	card.position = Vector3(half.x * 0.55, half.y - 0.03, half.z + 0.004); card.rotation.z = 0.12
	for i in 3:
		var ln := MeshInstance3D.new(); ln.mesh = Build.box_mesh(Vector3(0.05 - i * 0.01, 0.0025, 0.001))
		ln.material_override = Tex.mat("black"); card.add_child(ln); ln.position = Vector3(-0.004 * i, 0.012 - i * 0.011, 0.0015)

## Hide what it stands for (called once the flat is built): `nodes` are 47's own.
func hide_real(nodes: Array) -> void:
	real_nodes = nodes
	for n in nodes:
		(n as Node3D).visible = false
		if n is CollisionObject3D: n.set_meta("layer", (n as CollisionObject3D).collision_layer); (n as CollisionObject3D).collision_layer = 0
		if n is RigidBody3D: (n as RigidBody3D).freeze = true

func holding_word(p) -> String:
	if p and p.held and p.held.has_meta("word"): return String(p.held.get_meta("word"))
	return ""

func get_prompt() -> String:
	if is_real: return ""
	var p = get_tree().get_first_node_in_group("player")
	var w := holding_word(p)
	if w != "": return "Stick \"%s\" on it" % w
	if tag == "" or (Game.hides_placeholders() and Game.is_placeholder(tag)): return ""
	return "Read the tag"

func interact(p = null) -> void:
	if is_real: return
	var w := holding_word(p)
	var lv = get_tree().get_first_node_in_group("level")
	if w == "":
		if lv and lv.get("hud"): lv.hud.hint(tag, 5.0)
		Sfx.play("paper", -10.0, 1.2)
		return
	if lv and lv.has_method("stick_note"): lv.stick_note(self, p)

## The word was right: the white goes, the thing is there.
func make_real() -> void:
	is_real = true
	collision_layer = 0
	for n in real_nodes:
		if not is_instance_valid(n): continue
		(n as Node3D).visible = true
		if n is CollisionObject3D: (n as CollisionObject3D).collision_layer = int(n.get_meta("layer", 32))
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.04, 1.04, 1.04), 0.08)
	tw.tween_property(_mesh, "scale", Vector3(0.001, 0.001, 0.001), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _mesh.visible = false)
	for c in get_children():
		if c is MeshInstance3D and c != _mesh: (c as MeshInstance3D).visible = false
	realised.emit(self)
