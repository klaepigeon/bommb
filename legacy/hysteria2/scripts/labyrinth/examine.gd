extends StaticBody3D
## Something in the town to look at (the old build's labyrinth code makes these). In the rebuild
## it's a prompt like any other: the crosshair finds it, USE reads it (TownChapter opens the
## reader with its text, and with Her Handwriting, `more`).

signal used

var title := "it"
var desc := ""
var more := ""
var enabled := true
var prompt := "Look"

func _ready() -> void:
	add_to_group("examine")
	collision_layer = 8
