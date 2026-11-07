class_name ResurrectionManager
extends RefCounted
## The dead don't leave. They become ghosts, and there are three ways back:
##   Collective Sacrifice: any free-for-all game that ends in a draw brings EVERY ghost
##     back, and every living player gives up one body part, chosen at random. A draw
##     you set up on purpose counts.
##   The resurrection square: land on it and one ghost (chosen at random) comes back.
##   Dead Rats: a ghost who has saved up enough buys their own way back.
## (And a living player can give a ghost a Lazarus Rat.)

var core: MatchCore


func _init(c: MatchCore) -> void:
	core = c


func ghosts() -> Array[int]:
	var out: Array[int] = []
	for p in core.players:
		if p.ghost:
			out.append(p.seat)
	return out


func revive(seat: int, how: String) -> void:
	var p := core.p(seat)
	if not p.ghost:
		return
	p.ghost = false
	p.alive = true
	p.location = "table"
	p.death = ""
	# the part that killed them is mended, barely: whatever else they lost stays lost
	for part in ["head", "torso"]:
		if p.body[part].s in ["broken", "lost"]:
			p.body[part].s = "bruised"
			p.body[part].t = Body.TEMP_ROUNDS
	p.suspicion = mini(p.suspicion, 60)
	core.emit({"e": "revive", "seat": seat, "how": how})
	core.say("revive_" + how, {"name": p.name})
	core.log_lines.append("REVIVED: %s (%s)" % [p.name, how])


## An FFA game ended in a draw.
func collective() -> void:
	var gs := ghosts()
	core.emit({"e": "sacrifice", "ghosts": gs})
	core.say("sacrifice", {"n": gs.size()})
	for s in core.living():
		var part := Body.random_severable(core.p(s).body, core.rng)
		if part != "":
			core.injure(s, part, "lost", "the sacrifice")
	for s in gs:
		revive(s, "sacrifice")


func square(lander: int) -> void:
	var gs := ghosts()
	if gs.is_empty():
		core.toast("The resurrection square. Nobody's waiting. %s gets a Dead Rat for trying." % core.p(lander).name)
		core.economy.award(lander, 1, "resurrection square")
		return
	var s: int = gs[core.rng.randi_range(0, gs.size() - 1)]
	revive(s, "square")


func buy(seat: int) -> bool:
	if not core.p(seat).ghost:
		return false
	if not core.economy.charge(seat, core.economy.resurrect_cost(), "resurrection"):
		core.toast("Not enough Dead Rats (%d)." % core.economy.resurrect_cost(), seat)
		return false
	revive(seat, "rats")
	return true
