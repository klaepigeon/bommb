extends StaticBody3D
## The inner door in the nursery, СОНЯ scratched into it at a child's height. It won't open.
## (Where Sonya is, is the game's to tell, later.)
func prompt() -> String:
	return "Open the door"
func interact(_player: Node) -> void:
	Game.say("It won't open. There's no lock and no keyhole. It just won't.", 4.0)
	Game.flags["tried_sonya_door"] = true
