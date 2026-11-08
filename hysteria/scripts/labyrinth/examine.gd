extends StaticBody3D
## Something to look at: its prompt, and what Kurt sees when he does. Records that he looked
## (Game.flags "looked_<title>"), for Socko and for the memories.

var title := "it"
var desc := ""

func prompt() -> String:
	return "Look at the " + title.to_lower()

func interact(_player: Node) -> void:
	Game.say(desc, 7.0)
	Game.flags["looked_" + title.to_lower()] = true
