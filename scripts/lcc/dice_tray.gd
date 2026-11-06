class_name DiceTray
extends Node3D
## The felt tray on the right of the table. Every roll the simulation makes is thrown here
## and lands on exactly the number that was rolled. The last throw stays until the next.

var dice: Array = []
var skin := {"body": Color("e8dcc0"), "ink": Color("8a1a12")}
var speed := 1.0

func set_skin(id: String) -> void:
	match id:
		"dice_bone": skin = {"body": Color("d8c898"), "ink": Color("1a1410")}
		"dice_brass": skin = {"body": Color("b08a3a"), "ink": Color("2a1a0a")}
		"dice_blood": skin = {"body": Color("6a1410"), "ink": Color("e8dcc0")}
		_: skin = {"body": Color("e8dcc0"), "ink": Color("8a1a12")}

func clear() -> void:
	for d in dice:
		if is_instance_valid(d):
			d.queue_free()
	dice.clear()

## Throw dice: rolls is Array of [sides, value]. Awaitable.
func throw(rolls: Array, small := false) -> void:
	clear()
	if rolls.is_empty():
		return
	var n := mini(rolls.size(), 6)
	var tweens: Array = []
	for i in range(n):
		var d := Dice3D.new()
		var sides: int = int(rolls[i][0])
		var body: Color = skin["body"]
		if sides != 20:
			body = body.darkened(0.08)
		d.setup(sides, body, skin["ink"], 0.02 if small else 0.028)
		add_child(d)
		dice.append(d)
		var col := i % 3
		var row := i / 3
		var to := Vector3(-0.1 + col * 0.1, 0.03 if not small else 0.022, -0.04 + row * 0.09 + (0.04 if n == 1 else 0.0))
		if n == 1:
			to.x = 0.0
		var from := to + Vector3(0.25, 0.25, 0.15)
		tweens.append(d.roll_to(int(rolls[i][1]), from, to, maxf(0.15, 0.85 / speed)))
	Sfx.play("dice", -2.0)
	if not tweens.is_empty():
		await tweens[tweens.size() - 1].finished
	Sfx.play("dice_settle", -6.0)
