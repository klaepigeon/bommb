class_name SkillEffects
## What a skill does once it's bought. Some act once (more rounds), some set a property on Kurt
## or his revolver, some are read by the world when it needs them (Skills.owned()).

static func apply(id: String, player: Node) -> void:
	var gun = player.get("gun")
	match id:
		"headshot":
			if gun: gun.set("headshot_kills", true)
		"quick_reload":
			if gun: gun.set("reload_each", 0.2)
		"steady":
			if gun: gun.set("kick_scale", 0.55)
		"deep_pockets":
			if gun: gun.set("spare", int(gun.get("spare")) + 7)
			else: Game.flags["pocket_rounds"] = 7
		"the_bow":
			player.set("throw_power", 1.35)
	Game.flags["skill_" + id] = true

## a revolver picked up after skills were bought gets them
static func apply_to_gun(gun: Node) -> void:
	if Skills.owned("headshot"): gun.set("headshot_kills", true)
	if Skills.owned("quick_reload"): gun.set("reload_each", 0.2)
	if Skills.owned("steady"): gun.set("kick_scale", 0.55)
	if Game.flags.get("pocket_rounds", 0) > 0:
		gun.set("spare", int(gun.get("spare")) + int(Game.flags.pocket_rounds)); Game.flags.pocket_rounds = 0
