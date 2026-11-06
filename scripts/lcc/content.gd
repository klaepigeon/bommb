extends Node
## LAST CALL: The Campaign's content database (res://data), as its hall code expects it
## (Content.db). MEAT PARTY uses it for the building: the hall, its rooms and doors.

var db: ContentDB


func _ready() -> void:
	db = ContentDB.new()
	db.load_dir("res://data")
