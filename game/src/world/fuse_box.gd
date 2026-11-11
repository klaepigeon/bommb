class_name FuseBox
extends Node3D
## The fuse box by the front door. One breaker per circuit; a circuit with its fuse missing or
## blown needs a fuse (tag "fuse") screwed in. Switching a circuit is loud enough to hear nearby,
## and switching the lights back on in a room Marta is in tells her something changed.

var ctx_level: Node
var body: StaticBody3D

func build(ctx) -> void:
	ctx_level = ctx.level
	ctx.box("metal", Vector3(0, 1.6, 0.03), Vector3(0.2, 0.25, 0.03), false)
	ctx.box("metal", Vector3(0, 1.6, -0.01), Vector3(0.19, 0.24, 0.005), false)
	body = StaticBody3D.new(); body.collision_layer = 32
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.45, 0.55, 0.15); cs.shape = bs
	body.add_child(cs); add_child(body); body.position = Vector3(0, 1.6, 0)
	Hook.attach(body, self, "Fuse box", "fusebox")

func ifocus() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)

func iverbs(p: Node) -> Array:
	var pw: Power = ctx_level.power
	var out := [Interactable.v("card", "Read the card")]
	for c in pw.circuits.keys():
		var st: Dictionary = pw.circuits[c]
		if not st.fuse:
			if p.inv.with_tag("fuse") != "":
				out.push_front(Interactable.v("fuse:" + c, "Fit a fuse in %s" % c))
			else:
				out.append(Interactable.v("nofuse:" + c, "%s: the fuse is missing" % c))
		else:
			out.append(Interactable.v("brk:" + c, ("Switch %s off" if st.live else "Switch %s on") % c, {"noise": 3.0}))
	return out

func iverb(id: String, p: Node) -> void:
	var pw: Power = ctx_level.power
	if id == "card":
		Events.show_document.emit("fuse_card")
		return
	var parts := id.split(":")
	match parts[0]:
		"fuse":
			p.inv.remove(p.inv.with_tag("fuse"))
			pw.set_fuse(parts[1], true)
			Sfx.play_at("fuse", ifocus(), 0.0, 1.0, 3.0)
			Story.record("route.fitted_fuse", {"circuit": parts[1]})
		"nofuse":
			Events.toast.emit("Circuit %s: the fuse holder is empty." % parts[1])
		"brk":
			pw.set_live(parts[1], not pw.circuits[parts[1]].live)
			Sfx.play_at("fuse", ifocus(), -2.0, 1.2, 4.0)
			Story.record("power." + ("on" if pw.circuits[parts[1]].live else "off"), {"circuit": parts[1]})
