class_name Pacing
extends RefCounted
## Every presentation duration in the game, in one place, in three presets. Nothing else
## hard-codes a delay: the turn loop, the round, and every minigame's presentation read this.
##   STANDARD: readable (the default).  RELAXED: more time to take things in.
##   FAST: quicker, still readable; it never drops a mandatory stage (instructions included).
## A minigame can override a timing (its registration's "pacing"), never remove a stage.
## Durations are seconds; "step" is per board square. Stages that wait for something
## (READY, an animation, a choice) treat their duration as a minimum.

const PRESETS := {
	"standard": {
		"round_start": 2.4, "turn_announce": 2.0, "dice": 0.0, "step": 0.42, "landing": 1.6, "event": 2.0,
		"turn_end": 1.4, "round_end": 2.6,
		"mg_freeze": 1.0, "mg_select": 2.6, "mg_title": 2.6, "mg_arena_preview": 3.0, "mg_teams": 2.6,
		"mg_instructions": 6.0, "mg_instructions_max": 120.0, "mg_arena_intro": 3.0, "mg_positioning": 2.0,
		"mg_countdown": 4.0, "mg_play_freeze": 1.6, "mg_results": 5.0, "mg_rewards": 3.5, "mg_return": 2.4,
		"intro": 8.0, "finale": 14.0, "ai_think": 1.3,
	},
	"relaxed": {
		"round_start": 3.2, "turn_announce": 2.8, "dice": 0.0, "step": 0.55, "landing": 2.2, "event": 2.8,
		"turn_end": 2.0, "round_end": 3.4,
		"mg_freeze": 1.4, "mg_select": 3.4, "mg_title": 3.4, "mg_arena_preview": 4.0, "mg_teams": 3.4,
		"mg_instructions": 9.0, "mg_instructions_max": 180.0, "mg_arena_intro": 4.0, "mg_positioning": 2.6,
		"mg_countdown": 4.0, "mg_play_freeze": 2.2, "mg_results": 7.0, "mg_rewards": 4.5, "mg_return": 3.0,
		"intro": 11.0, "finale": 18.0, "ai_think": 1.8,
	},
	"fast": {
		"round_start": 1.4, "turn_announce": 1.2, "dice": 0.0, "step": 0.3, "landing": 1.0, "event": 1.3,
		"turn_end": 0.8, "round_end": 1.6,
		"mg_freeze": 0.6, "mg_select": 1.6, "mg_title": 1.6, "mg_arena_preview": 1.8, "mg_teams": 1.6,
		"mg_instructions": 4.0, "mg_instructions_max": 90.0, "mg_arena_intro": 1.8, "mg_positioning": 1.2,
		"mg_countdown": 4.0, "mg_play_freeze": 1.0, "mg_results": 3.5, "mg_rewards": 2.4, "mg_return": 1.6,
		"intro": 5.0, "finale": 10.0, "ai_think": 0.8,
	},
}

var preset := "standard"
var overrides: Dictionary = {}     # a minigame's own timings, while it's on


func _init(p := "standard") -> void:
	preset = p if PRESETS.has(p) else "standard"


func get_t(key: String) -> float:
	if overrides.has(key):
		return float(overrides[key])
	return float(PRESETS[preset].get(key, PRESETS.standard.get(key, 1.0)))


func view() -> Dictionary:
	var d: Dictionary = PRESETS[preset].duplicate()
	d.merge(overrides, true)
	d["preset"] = preset
	return d
