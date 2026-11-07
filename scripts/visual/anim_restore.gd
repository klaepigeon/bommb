extends Node
## BodyAnimator's other half: runs before everything else each frame and takes last frame's
## offsets off the joints, so the figure poses itself from clean.

var anim: Node


func _process(_delta: float) -> void:
	if anim and is_instance_valid(anim):
		anim.restore()
