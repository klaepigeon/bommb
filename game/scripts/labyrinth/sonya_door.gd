extends StaticBody3D
## Sonya's door in the nursery: it doesn't open. (TownChapter answers it.)

signal used

var enabled := true
var prompt := "Open"

func _ready() -> void:
	add_to_group("sonya_door")
