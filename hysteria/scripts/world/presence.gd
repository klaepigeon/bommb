class_name Presence
extends Node3D
## Marks Marta: fused to her chair at the table, and later loose in the flat. Being in the same
## room as an active Presence feeds Dread (scripts/fx/dread.gd). Attach it to whatever the thing
## is; when the thing moves, the Presence moves with it.

@export var active := true
## How strongly this presence drains colour (1 = the full effect over Dread.SECONDS_TO_GREY).
@export var weight := 1.0

func _ready() -> void:
	add_to_group("presence")
