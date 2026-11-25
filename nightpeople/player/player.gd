class_name Player
extends CharacterBody3D
## The player's character: third-person, moves relative to the camera, interacts with whatever
## Interactable its focus settles on, carries an inventory. Input comes only through
## `controls` (touch/keys/pad, ui/controls.gd), so a network peer or a test can drive it.

signal focus_changed(target: Interactable)
signal inventory_changed

const WALK := 1.6
const RUN := 4.2
const FOCUS_RANGE := 2.4

var controls: Controls
var puppet: Puppet
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var focus: Interactable
var inventory: Array[Dictionary] = []
var cash := 0
var yaw := 0.0
var pitch := -12.0
var autopilot := false            ## tests: move toward `autopilot_target`
var autopilot_target := Vector3.ZERO

var _focus_t := 0.0
var alt_offset := 0                 ## which of several second actions is offered (cycled with »)
var _stride := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8       # world, npcs, doors
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	puppet = Puppet.new()
	add_child(puppet)
	puppet.setup({"model": "Casual3_Male", "height": 1.78,
		"colors": {"Skin": "#d9d4cf", "Shirt": "#2a2a30", "Pants": "#24242a", "Hair": "#151515"}})
	pivot = Node3D.new()
	pivot.position.y = 1.55
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 3.0
	arm.collision_mask = 1
	arm.margin = 0.2
	arm.position.x = 0.45
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.08
	camera.far = 90.0
	arm.add_child(camera)
	camera.current = true
	World.players.append(self)

func npc_id() -> String:
	return ""                       # doors: players are never residents by id here

func _physics_process(delta: float) -> void:
	var look := controls.consume_look() if controls else Vector2.ZERO
	yaw -= look.x * Settings.look_sensitivity
	pitch = clampf(pitch - look.y * Settings.look_sensitivity, -60.0, 35.0)
	pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	var mv := controls.move if controls else Vector2.ZERO
	if autopilot:
		var to := autopilot_target - global_position
		to.y = 0
		mv = Vector2.ZERO
		if to.length() > 0.3:
			var local := to.normalized().rotated(Vector3.UP, -deg_to_rad(yaw))
			mv = Vector2(local.x, local.z)
	var speed := RUN if (controls and controls.sprinting()) or mv.length() > 0.95 else WALK * 1.4
	var dir := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, deg_to_rad(yaw))
	var target := dir * speed * minf(mv.length(), 1.0)
	velocity.x = move_toward(velocity.x, target.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 20.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.2:
		puppet.rotation.y = lerp_angle(puppet.rotation.y, atan2(flat.x, flat.y), 12.0 * delta)
	puppet.locomote(flat.length())
	_stride += flat.length() * delta
	if _stride > (0.85 if flat.length() > 3.0 else 0.62) and is_on_floor():
		_stride = 0.0
		Sfx.play_at("step_" + Sfx.surface_at(global_position), global_position, 2.0 if flat.length() > 3.0 else 0.0)
	_focus_t -= delta
	if _focus_t <= 0.0:
		_focus_t = 0.1
		_update_focus()

func _update_focus() -> void:
	var best: Interactable = null
	var best_score := INF
	var fwd := -camera.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var chest := global_position + Vector3.UP * 1.1
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or it == self or not it.is_visible_in_tree():
			continue
		var to := it.focus_point() - chest
		var d := to.length()
		if d > FOCUS_RANGE:
			continue
		var flat := Vector3(to.x, 0, to.z).normalized()
		var facing := flat.dot(fwd)
		if facing < 0.2 and d > 0.9:
			continue
		var score := d - facing * 1.2
		if score < best_score and it.verbs(self).size() > 0:
			best_score = score
			best = it
	if best != focus:
		focus = best
		alt_offset = 0
		focus_changed.emit(focus)

## The focused thing's verbs as offered: the primary first, then the others rotated by `alt_offset`.
func offered_verbs() -> Array[String]:
	if focus == null or not is_instance_valid(focus):
		return []
	var v := focus.verbs(self)
	if v.size() <= 2:
		return v
	var rest := v.slice(1)
	var k := alt_offset % rest.size()
	var out: Array[String] = [v[0]]
	out.append_array(rest.slice(k) + rest.slice(0, k))
	return out

func cycle_alt() -> void:
	alt_offset += 1
	focus_changed.emit(focus)

## Do the offered verb number `index` (0 = primary, 1 = the second action shown).
func act(index := 0) -> void:
	if focus == null or not is_instance_valid(focus):
		return
	var v := offered_verbs()
	if index < v.size():
		if v[index] in ["Take", "Pick lock"]:
			puppet.gesture("PickUp")
		focus.perform(self, v[index])
		_focus_t = 0.0

func give_item(item: Dictionary) -> void:
	var name: String = item.get("name", "")
	if item.get("cash", false):
		cash += int(item.get("value", 0))
	inventory.append(item)
	Events.notice.emit("Took: " + name)
	inventory_changed.emit()

func has_item(id: String) -> bool:
	for i in inventory:
		if i.id == id:
			return true
	return false
