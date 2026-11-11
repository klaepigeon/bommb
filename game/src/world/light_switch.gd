class_name LightSwitch
extends Node3D
## A wall switch for a room's ceiling light.

var room := ""
var level: Node

func build(ctx) -> void:
	level = ctx.level
	ctx.box("white", Vector3(0, 1.3, 0.005), Vector3(0.04, 0.05, 0.008), false)
	var b := StaticBody3D.new(); b.collision_layer = 32
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.2, 0.2, 0.1); cs.shape = bs
	b.add_child(cs); add_child(b)
	Hook.attach(b, self, "Light switch")

func iverbs(_p: Node) -> Array:
	var on: bool = level.power.room_switch.get(room, true)
	return [Interactable.v("switch", "Switch the light off" if on else "Switch the light on", {"noise": 1.5})]

func iverb(_id: String, _p: Node) -> void:
	level.power.toggle_switch(room)
	Story.record("power.switch", {"room": room})
