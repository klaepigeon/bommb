class_name SockoIntro
extends Node
## Story bible §5 beats 9–10: the hand, then Socko. Runs once, after Marta's encounter has put
## the protagonist on the floor and he's come to (MartaEncounter's AWAKE). Socko doesn't exist
## before this: hidden, no voice, no spill light.
##
##   9   Still on his back. His left hand rises into view on its own, slowly. There's a sock on
##       it. Googly eyes. The mouth opens a little, closes. It looks at him.
##   10  1 "…Hi."  2 leans in, looks him over: "Oof. Okay. You took a knock. Don't sit up fast."
##       He sits up anyway (we let him go); Socko winces. 3 "Or do. Sure. You do you."
##       4 when the player looks down at him (or after a while): "It's me. Socko. Your hand? We're
##       close." [beat] "Physically."  5 when the player looks round the room: "She's gone. Don't
##       look at the chair, bud. Look at me."  6 turns toward the hall, points: "Door's that way.
##       Let's get you out before she comes back for seconds."
## Lines are the bible's §6 first draft, unchanged. ~60 s, not rushed: each beat waits for the
## line before it and for the player.

enum S { WAIT, RISE, HI, OOF, SIT, YOU_DO, LOOK_AT_ME, ITS_ME, PHYS, ROOM, GONE, DOOR, DONE }

var socko: Socko
var player: Node
var encounter: Node
var state := S.WAIT
var t := 0.0
var _yaw0 := 0.0
var hall_point := Vector3(8.6, 1.0, 4.5)     # toward the hall and the front door
var chair_point := Vector3(3.0, 0.6, 1.42)

func setup(p_socko: Socko, p_player: Node, p_encounter: Node) -> void:
	socko = p_socko; player = p_player; encounter = p_encounter
	socko.visible = false; socko.set_process(false)
	socko.shown = 0.0

func _go(s: S) -> void:
	state = s; t = 0.0

func _process(delta: float) -> void:
	t += delta
	match state:
		S.WAIT:
			if Game.flags.get("woke_in_47", false) and (encounter == null or encounter.call("state_name") == "AWAKE"):
				# hold him on the floor a little longer: the hand comes first
				player.set("locked", true)
				player.set("eye_override", 0.25)
				player.head.position.y = 0.25
				player.set("pitch", 1.25)
				socko.visible = true; socko.set_process(true)
				# from now on the light comes out of his mouth; nobody says why
				socko.take_torch(player.torch); player.set("torch_holder", socko)
				socko.shown = 0.0; socko.pose_face = 1.0; socko.set_emotion("uncanny")
				_go(S.RISE)
		S.RISE:
			socko.shown = smoothstep(0.0, 3.2, t)
			if t > 3.6 and t < 3.9:
				socko.rig.jaw = 0.0
			if t > 3.8:
				socko.set_emotion("curious", 0.6)
			if t > 4.6:
				socko.say("…Hi.", "curious", 0.55); _go(S.HI)
		S.HI:
			if not socko.talking and t > 2.4:
				socko.gesture("lean_in"); socko.say("Oof. Okay. You took a knock. Don't sit up fast.", "nervous", 0.85)
				_go(S.OOF)
		S.OOF:
			if not socko.talking and t > 1.0:
				# he sits up anyway (the shoulder); Socko winces
				player.set("eye_override", -1.0)
				player.set("locked", false)
				socko.pose_face = 0.0; socko.look_at_kurt(2.5)
				socko.gesture("wince")
				_go(S.SIT)
		S.SIT:
			if t > 1.1:
				socko.say("Or do. Sure. You do you.", "disappointed", 0.8); _go(S.YOU_DO)
		S.YOU_DO:
			if not socko.talking:
				socko.set_emotion("neutral"); _go(S.LOOK_AT_ME)
		S.LOOK_AT_ME:
			if (_looking_at_socko() and t > 1.0) or t > 7.0:
				socko.look_at_kurt(4.0); socko.gesture("bounce")
				socko.say("It's me. Socko. Your hand? We're close.", "happy"); _go(S.ITS_ME)
		S.ITS_ME:
			if not socko.talking:
				_go(S.PHYS)
		S.PHYS:
			if t > 0.9:
				socko.gesture("nod", null, 0.7); socko.say("Physically.", "lying", 0.8)
				_yaw0 = player.get("yaw"); _go(S.ROOM)
		S.ROOM:
			var turned := absf(wrapf(float(player.get("yaw")) - _yaw0, -PI, PI))
			if (not socko.talking and turned > 0.9) or t > 9.0:
				# he keeps his eyes on Kurt, not on the chair
				socko.look_at_kurt(4.5); socko.set_emotion("lying")
				socko.say("She's gone. Don't look at the chair, bud. Look at me.", "lying", 0.8)
				_go(S.GONE)
		S.GONE:
			if not socko.talking and t > 1.5:
				socko.set_emotion("happy")
				socko.gesture("point", hall_point)
				socko.say("Door's that way. Let's get you out before she comes back for seconds.", "happy")
				_go(S.DOOR)
		S.DOOR:
			if not socko.talking and t > 1.0:
				Game.flags["socko_intro_done"] = true
				socko.set_emotion("neutral")
				_go(S.DONE)

## Loading a save from after the introduction: he's on the hand, the light's in his mouth.
func skip() -> void:
	socko.visible = true; socko.set_process(true)
	socko.take_torch(player.torch); player.set("torch_holder", socko)
	socko.shown = 1.0; socko.pose_face = 0.0; socko.set_emotion("neutral")
	player.set("eye_override", -1.0); player.set("locked", false)
	_go(S.DONE)

## Is the player looking at the sock? The hand moves with the view, so you can't centre him on
## screen: looking at him is looking down at your hand.
func _looking_at_socko() -> bool:
	return float(player.get("pitch")) < -0.3
