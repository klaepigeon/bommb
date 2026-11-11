class_name FuseBox
extends Usable
## A box of breakers and fuses. Each circuit: flip the breaker; take the fuse out (and carry it to
## a circuit that has none); put one in. Clunky and loud enough to be heard close by.

var circuits: Array = []

static func place(parent: Node, at: Vector3, facing: Vector3, p_circuits: Array, p_title: String, zone := -1) -> FuseBox:
	var f := FuseBox.new()
	f.circuits = p_circuits; f.title = p_title
	f.collision_layer = 1
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.4, 0.5, 0.14); cs.shape = b
	f.add_child(cs)
	parent.add_child(f)
	f.global_position = at
	f.look_at(at + facing, Vector3.UP)
	var kit := Kit.new()
	kit.box(Mats.tex(Tex.get_tex("metal"), zone), Vector3.ZERO, Vector3(0.4, 0.5, 0.1))
	for i in p_circuits.size():
		kit.box(Mats.flat(Color(0.15, 0.15, 0.15), zone), Vector3(-0.12 + i * 0.12, 0.05, -0.06), Vector3(0.05, 0.1, 0.03))
	kit.commit(f, "Box")
	return f

func get_verbs(k) -> Array:
	var v: Array = []
	for c in circuits:
		var cc: Dictionary = Power.circuits.get(c, {})
		if cc.is_empty(): continue
		if not cc.fuse:
			if k.has_item("fuse"): v.push_front({"id": "in_" + c, "label": "Fuse into %s" % cc.label})
			continue
		v.append({"id": "flip_" + c, "label": ("Switch off: " if cc.breaker else "Switch on: ") + cc.label})
	for c in circuits:
		var cc: Dictionary = Power.circuits.get(c, {})
		if not cc.is_empty() and cc.fuse: v.append({"id": "out_" + c, "label": "Take the fuse: " + cc.label})
	return v

func act(verb: String, k) -> void:
	Audio.play("breaker", global_position, -2.0)
	Noises.make(global_position, 4.0, "breaker", k)
	var c := verb.split("_", true, 1)[1]
	if verb.begins_with("flip_"):
		Power.set_breaker(c, not Power.circuits[c].breaker)
	elif verb.begins_with("out_"):
		Power.set_fuse(c, false); k.give_item("fuse", "Fuse", "A ceramic fuse, 16 A.")
	elif verb.begins_with("in_"):
		k.take_item("fuse"); Power.set_fuse(c, true)
	World.emit_event("fusebox", {"verb": verb, "box": title})
