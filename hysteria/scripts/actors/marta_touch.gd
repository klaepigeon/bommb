extends StaticBody3D
## Marta's body as something you can aim at and use: touch her (and she wakes), or once she's
## looking at you, answer her by looking back.

var encounter: Node

func prompt() -> String:
	match encounter.state:
		MartaEncounter.S.STILL: return "Touch her face"
		MartaEncounter.S.STARE: return "Look at her" if encounter.asked >= 1 and not encounter.answered else ""
	return ""

func interact(_player: Node) -> void:
	encounter.answer()
