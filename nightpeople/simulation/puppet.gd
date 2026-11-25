class_name Puppet
extends Node3D
## A character's body on screen: one Quaternius model (shared 32-bone rig, 11 animations),
## scaled to a height in metres, recoloured per person by material name, and animated from
## what its owner is doing (moving, or holding a pose at a place). Player and NPCs both use it.

const POSES := {
	"stand": "Idle", "work": "Idle", "sit": "SitDown", "sleep": "Defeat", "dance": "Victory",
}

var anim: AnimationPlayer
var model: Node3D
var _pose := ""
var _clip := ""

## `look`: {model: String, height: float, colors: {MaterialName: "#hex"}}
func setup(look: Dictionary) -> void:
	model = Assets.character(look.get("model", "Casual_Male"))
	add_child(model)
	_recolor(look.get("colors", {}))
	var box := Assets.bounds(model, self)
	var h := float(look.get("height", 1.75))
	if box.size.y > 0.01:
		model.scale *= h / box.size.y
		model.position.y -= box.position.y * h / box.size.y
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for n in ["Idle", "Walk", "Walk_Carry", "Victory"]:
			var a := anim.get_animation(_full(n))
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
		_play("Idle")

func _recolor(colors: Dictionary) -> void:
	if colors.is_empty():
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src and colors.has(src.resource_name):
				var mat := (m.get_surface_override_material(i) as ShaderMaterial).duplicate() as ShaderMaterial
				mat.set_shader_parameter("albedo", Color(colors[src.resource_name]))
				m.set_surface_override_material(i, mat)

func _full(n: String) -> String:
	return "CharacterArmature|" + n

func _play(n: String, speed := 1.0, blend := 0.2) -> void:
	if anim == null:
		return
	if n != _clip:
		_clip = n
		anim.play(_full(n), blend)
	anim.speed_scale = speed

## Moving at `speed` m/s (0 = standing). Clears any held pose.
func locomote(speed: float) -> void:
	_pose = ""
	if speed > 0.1:
		_play("Walk", clampf(speed / 1.3, 0.6, 2.2))
	else:
		_play("Idle")

## Hold a pose (see POSES). Sitting and lying play once and stay on their last frame.
func hold(pose: String) -> void:
	if pose == _pose:
		return
	_pose = pose
	_play(POSES.get(pose, "Idle"))

## A one-off gesture (PickUp, Punch, RecieveHit...), then back to what it was doing.
func gesture(n: String) -> void:
	if anim == null:
		return
	var back := _clip
	_clip = ""
	_play(n)
	await anim.animation_finished
	if _clip == n:
		_clip = ""
		_play(back if back != "" else "Idle")

func set_animating(on: bool) -> void:
	if anim:
		anim.active = on
