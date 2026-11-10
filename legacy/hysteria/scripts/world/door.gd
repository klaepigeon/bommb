extends Node3D
## A hinged door. The node is the hinge (as exported); its yaw is psi0 + sign * angle.
## An AnimatableBody3D on the leaf pushes the player and props aside as it swings.

var psi0 := 0.0
var sign_ := 1.0
var angle := 0.0
var target := 0.0
var max_angle := 1.5
var locked := ""         # "", "chain" (front door), "bolt" (box room)
var leaf_w := 0.8
var body: AnimatableBody3D
var chain_handler: Node = null   # the front door's chain: FlatEscape decides what using it does

func setup(ex: Dictionary) -> void:
	set_physics_process(true)
	psi0 = ex.get("psi0", 0.0); sign_ = ex.get("sign", 1.0); max_angle = ex.get("max", 1.5)
	angle = ex.get("open", 0.0); target = angle; leaf_w = ex.get("w", 0.8)
	var lk = ex.get("locked", null)
	locked = lk if lk is String else ""
	# not sync_to_physics: in that mode the body only follows its own local transform, and here
	# it is the parent (the hinge) that turns. Off, it follows its global transform every frame.
	body = AnimatableBody3D.new(); body.sync_to_physics = false
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(leaf_w, ex.get("h", 2.0), 0.06); cs.shape = b
	cs.position = Vector3(leaf_w * 0.5, ex.get("h", 2.0) * 0.5, 0)
	body.add_child(cs); add_child(body)
	_apply()

func _apply() -> void:
	rotation.y = psi0 + sign_ * angle

func _physics_process(delta: float) -> void:
	if absf(target - angle) > 0.001:
		angle = move_toward(angle, target, delta * maxf(0.6, absf(target - angle) * 3.0))
		_apply()

func prompt() -> String:
	if locked == "chain" and chain_handler:
		return chain_handler.call("chain_prompt", self)
	if locked == "bolt":
		return "Slide the bolt"
	return "Close" if target > 0.15 else "Open"

## Using what's in the hand on the door (the axe on the chain); "" if it does nothing here.
func use_with_prompt(item: Node) -> String:
	if locked == "chain" and chain_handler: return chain_handler.call("use_with_prompt", item)
	return ""

func use_with(_player: Node, item: Node) -> bool:
	if locked == "chain" and chain_handler: return chain_handler.call("use_with", item)
	return false

func interact(_player: Node) -> void:
	if locked == "chain" and chain_handler and chain_handler.call("chain_use", self, _player):
		return
	match locked:
		"bolt":
			locked = ""; Game.say("You slide the bolt back.")
			return
		"chain":
			if target > 0.05:
				target = 0.0
			else:
				target = 0.11
				Game.say("The chain is padlocked on this side.")
			return
	target = 0.0 if target > 0.15 else max_angle
