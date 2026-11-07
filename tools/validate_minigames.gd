extends Node
## The minigame validation tool: every registered game's registration checked (complete data,
## player counts, instructions, controls/bindings, arena, gameplay, completion, results,
## rewards, return to the board). A game that fails isn't finished.
##   godot --headless res://tools/validate_minigames.tscn [-- --play]
## --play also runs each one, AI only, through the real presentation controller to the end.

func _ready() -> void:
	var play := OS.get_cmdline_user_args().has("--play")
	var bad := 0
	for id in MinigameRegistry.GAMES.keys():
		if MinigameRegistry.GAMES[id].get("retired", false):
			continue
		var r := MinigameValidation.check(id, play)
		if r.problems.is_empty():
			print("OK    %-20s %-13s %d-%d  arena %-10s  %d instructions, controls %s" % [id, r.reg.category, r.reg.players.min, r.reg.players.max, r.reg.arena, r.reg.instructions.size(), str(r.reg.controls)])
		else:
			bad += 1
			print("FAIL  %-20s %s" % [id, "; ".join(r.problems)])
	print("%d incomplete" % bad)
	get_tree().quit(1 if bad > 0 else 0)
