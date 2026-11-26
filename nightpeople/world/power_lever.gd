extends Interactable
## The station's power. On: the platform, tracks, hall and pump room light up (people see further,
## both ways) and the third rail goes live. It's loud.

func verbs(_actor: Node) -> Array[String]:
	return ["Throw the lever (power %s)" % ("off" if World.power else "on")]

func perform(actor: Node, _verb: String) -> void:
	World.set_power(not World.power)
	Sfx.play_at("switch", global_position, 6.0)
	Sfx.play_at("radio_static", global_position, 4.0)
	Events.notice.emit("Somewhere a generator coughs and catches. Lights stutter on down the tunnel." if World.power else "The generator winds down. Dark.")
	Events.world_event.emit({"kind": "lever", "actor": actor, "position": global_position, "place": "", "loudness": 18.0})
