class_name Ladder
extends Node3D
## A way up or down that the navmesh can't walk: an iron ladder, the Vesper's hatch. One end is
## an Interactable each; a NavigationLink3D (navigation layer 2) lets people with the right
## layers path through it (they climb: npc.gd hops the vertical step). A bolted ladder can only
## be opened from its `bolt_side`, and while bolted nobody (and no path) goes through.

signal climbed(who: Node3D, to_top: bool)

var id := ""
var label := "Ladder"
var top := Vector3.ZERO
var bottom := Vector3.ZERO
var bolted := false
var bolt_side := "bottom"
var link: NavigationLink3D

func setup(def: Dictionary) -> void:
	id = def.id
	label = def.get("label", "Ladder")
	top = Vector3(def.top[0], def.top[1], def.top[2])
	bottom = Vector3(def.bottom[0], def.bottom[1], def.bottom[2])
	bolted = def.get("bolted", false)
	bolt_side = def.get("bolt_side", "bottom")
	link = NavigationLink3D.new()
	link.bidirectional = true
	link.navigation_layers = 2
	link.start_position = top
	link.end_position = bottom
	link.enabled = not bolted
	add_child(link)
	for end in ["top", "bottom"]:
		var e := LadderEnd.new()
		e.ladder = self
		e.end = end
		e.label = label
		add_child(e)
		e.global_position = top if end == "top" else bottom
	_visuals()

func _visuals() -> void:
	var kit := MeshKit.new()
	var iron := Assets.surface("metal_worn", 1.0, Color(0.5, 0.45, 0.4))
	var x := bottom + Vector3(0, 0, -0.35)
	var h := top.y - bottom.y
	kit.box(x + Vector3(-0.25, h * 0.5, 0), Vector3(0.06, h, 0.06), iron, false)
	kit.box(x + Vector3(0.25, h * 0.5, 0), Vector3(0.06, h, 0.06), iron, false)
	var y := 0.3
	while y < h:
		kit.box(x + Vector3(0, y, 0), Vector3(0.5, 0.04, 0.04), iron, false)
		y += 0.35
	kit.box(top + Vector3(0, 0.02, 0), Vector3(1.1, 0.04, 1.1), Assets.surface("diamond_plate", 1.0, Color(0.55, 0.5, 0.45)), false)
	var mi := kit.build("LadderMesh")
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY

func climb(who: Node3D, to_top: bool) -> void:
	who.global_position = (top if to_top else bottom) + Vector3(0, 0.05, 0.6 if to_top else 0.4)
	Sfx.play_at("door_close", top if to_top else bottom, -6.0)
	climbed.emit(who, to_top)

func unbolt() -> void:
	bolted = false
	link.enabled = true
	Sfx.play_at("lockpick", bottom + Vector3.UP * 3.0)
	Events.world_event.emit({"kind": "lever", "actor": null, "position": bottom, "place": "", "loudness": 8.0})


class LadderEnd extends Interactable:
	var ladder: Ladder
	var end := "top"

	func verbs(_actor: Node) -> Array[String]:
		if ladder.bolted:
			if end == ladder.bolt_side:
				return ["Slide the bolt back"]
			return ["Try the hatch", "Listen at the hatch"]
		return ["Climb down" if end == "top" else "Climb up"]

	func perform(actor: Node, verb: String) -> void:
		match verb:
			"Slide the bolt back":
				ladder.unbolt()
				Events.notice.emit("The bolt grinds back. The way up is open now, from both sides.")
			"Try the hatch":
				Sfx.play_at("knock", global_position, -6.0)
				Events.notice.emit("It doesn't move. It's bolted from the other side.")
			"Listen at the hatch":
				Events.notice.emit("Cold air through the boards. Far below, something like a train that isn't a train.")
			_:
				ladder.climb(actor, end == "bottom")

	func focus_point() -> Vector3:
		return global_position + Vector3.UP * 0.6
