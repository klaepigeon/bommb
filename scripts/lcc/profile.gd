extends Node
## The campaign's Profile, cut down to what its hall needs: a little saved state for the
## building (which doors you've opened), in user://hall_profile.json.

const PATH := "user://hall_profile.json"
var data: Dictionary = {}


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if v is Dictionary:
			data = v


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
