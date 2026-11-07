extends Node
## Plays a match with the real app on screen and saves screenshots as it goes:
##   xvfb-run godot res://tests/shots.tscn -- --out=DIR [--seed=N] [--coop]
## (seat 0 is played by a ViewBot through the same buttons' actions; the rest are AI)

var out := "user://shots"
var bot := ViewBot.new()
var n := 0
var _last_phase := ""
var _t := 0.0
var _mg_shot := 0.0
var app: Node
var _max := 60


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--max="):
			_max = int(a.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	Audio.muted = true
	Engine.time_scale = 2.0
	app = load("res://scripts/ui/app.gd").new()
	add_child(app)
	await get_tree().create_timer(1.5).timeout
	_shot("menu")
	app.settings()
	await get_tree().create_timer(0.5).timeout
	_shot("settings")
	app.single()
	await get_tree().create_timer(0.5).timeout
	_shot("lobby")
	var seed_v := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	Net.launch(seed_v)
	if OS.get_cmdline_user_args().has("--coop"):
		for s in Net.core.brains:
			Net.core.brains[s].coop = 0.95


var _last_key := ""
var _seen := {}


func _process(delta: float) -> void:
	if Net.core == null:
		return
	_t += delta
	var v: Dictionary = Net.last_view
	bot.step(Net.last_view, delta)
	if v.is_empty():
		return
	var ph := str(v.phase)
	# every presentation stage, and the turn's announcement and landing, once each
	var st := str(v.get("presenter", {}).get("stage", ""))
	var fl := str(v.get("flow", {}).get("state", ""))
	var key := st if st != "" else (fl if fl in ["TURN_ANNOUNCEMENT", "LANDING_EVENT", "ROUND_END"] else "")
	if key != "" and key != _last_key:
		_last_key = key
		if not _seen.has(key):
			_seen[key] = true
			get_tree().create_timer(0.9).timeout.connect(func(): _shot("flow_" + key.to_lower()))
	elif key == "":
		_last_key = ""
	if ph != _last_phase:
		_last_phase = ph
		var tag := ph + ("_" + str(v.mg_id) if ph.begins_with("mg") else "")
		get_tree().create_timer(1.2 if ph != "ending" else 4.0).timeout.connect(func(): _shot(tag))
		_mg_shot = 0.0
	if ph == "mg_play":
		_mg_shot += delta
		if _mg_shot > 5.0:
			_mg_shot = 0.0
			_shot("play_" + str(v.mg_id) + "_" + str(v.mg.get("sub", "")))
	if ph == "ending" and _t > 0 and n > 0 and str(v.ending) != "":
		set_process(false)
		get_tree().create_timer(6.0).timeout.connect(func(): get_tree().quit())
	if n > _max:
		get_tree().quit()


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out, n, tag])
	n += 1
