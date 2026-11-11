class_name Marta
extends Node3D
## Marta Sokolova at her dinner table: the first build's model (MartaModel: rotted, coral grown
## through her and the chair into the floor, flies), and what the scenes ask of her: lift her
## head to whoever's there, talk (the jaw), take hold of him, be gone. She faces -Z; the origin
## is the floor under her chair.

var model: MartaModel
var head: Node3D                  ## the head joint (scenes look at it)
var chair: Array[Node3D] = []     ## what isn't her: the chair, the roots, the puddle
var spot: Hotspot
var breathing := true
var head_lift := 0.0              ## 0 = hanging toward her plate, 1 = looking at look_target
var look_target := Vector3.ZERO

var _t := 0.0
var _breath: AudioStreamPlayer3D
var _reach := 0.0

func build() -> void:
	model = MartaModel.new()
	model.name = "Model"
	add_child(model)
	head = model.joints.head
	for c in model.get_children():
		if c is MeshInstance3D or c is CPUParticles3D:
			chair.append(c)
	spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(0, 0.95, -0.1)), Vector3(0.6, 0.9, 0.6), "Examine")
	spot.enabled = false
	_breath = Sfx.loop_at("breath", global_transform * Vector3(0, 1.1, -0.1), -12.0, 0.95)

func _process(delta: float) -> void:
	if model == null:
		return
	_t += delta
	var j: Dictionary = model.joints
	# her head: hanging, or lifted to look at him (the model's own face() gives the angles)
	var rest := MartaModel.HEAD_REST
	var lifted := rest
	if look_target != Vector3.ZERO:
		var saved: Vector3 = j.head.rotation
		var jaw: float = j.jaw.rotation.x
		model.face(look_target)
		lifted = j.head.rotation
		j.head.rotation = saved
		j.jaw.rotation.x = jaw
	var tremor := Vector3(sin(_t * 13.0), sin(_t * 9.0), 0) * 0.008 * head_lift
	j.head.rotation = rest.lerp(lifted, head_lift) + tremor
	# the jaw: slack; dropped when she looks at him; working when she speaks
	var m := Speech.mouth("marta")
	j.jaw.rotation.x = -(lerpf(MartaModel.JAW_REST, MartaModel.JAW_OPEN, head_lift) + m * 0.18)
	# breathing, if you can call it that
	if breathing:
		j.hips.position.y = MartaModel.J.hips.y + sin(_t * TAU / 4.2) * 0.004

## She takes hold of him: the right arm comes up off the table and out at him, fast.
func grab(target: Vector3, seconds := 0.22) -> void:
	var j: Dictionary = model.joints
	var sh: Node3D = j.shR
	var el: Node3D = j.elR
	var upper := (MartaModel.J.elR - MartaModel.J.shR).normalized()
	var fore := (MartaModel.J.wrR - MartaModel.J.elR).normalized()
	var to := (sh.get_parent() as Node3D).global_transform.affine_inverse() * target - sh.position
	var q := Quaternion(upper, to.normalized())
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sh, "quaternion", q, seconds)
	tw.tween_property(el, "quaternion", Quaternion(fore, upper), seconds)
	tw.tween_property(self, "head_lift", 1.0, seconds * 0.5)

## Gone. What she grew into stays: the chair, the coral in the floor, the puddle.
func vanish() -> void:
	breathing = false
	model.joints.hips.visible = false
	if model.flies:
		model.flies.emitting = false
		model.flies.visible = false
	spot.enabled = false
	if is_instance_valid(_breath):
		_breath.queue_free()
