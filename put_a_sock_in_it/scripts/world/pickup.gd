class_name Pickup
extends StaticBody3D
## An item that goes into Kurt's pockets: the pistol, a box of rounds, a key. Its look is built
## by the level (children); this handles taking it.

signal taken(p: Pickup)
var item := ""
var amount := 1
var label := ""

func _ready() -> void:
	collision_layer = 4; collision_mask = 0

func get_prompt() -> String:
	return "Take " + label

func interact(_p = null) -> void:
	match item:
		"pistol":
			Game.pistol.have = true; Game.pistol.drawn = true
			Game.pistol.mag = maxi(Game.pistol.mag, amount)
		"shotgun":
			Game.shotgun.have = true; Game.shotgun.loaded = maxi(int(Game.shotgun.loaded), amount)
			Game.shotgun.drawn = true; Game.pistol.drawn = false
		"battery":
			Game.torch_charge = 1.0
		_:
			var extra := 1 if item == "ammo" and Skills.has("m_resource") and randf() < 0.5 else 0
			Game.add_item(item, amount + extra)
	Sfx.play("pickup", -4.0)
	taken.emit(self)
	queue_free()
