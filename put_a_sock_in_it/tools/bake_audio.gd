extends SceneTree
## Synthesises every sound once and saves it to assets/audio/<name>.wav, so the game loads them
## instead of making them at start-up. Run after changing a generator in scripts/core/sfx.gd:
##   godot --headless --path . -s tools/bake_audio.gd [-- only=<prefix>] [-- voices]
func _initialize() -> void:
	await process_frame
	var sfx = root.get_node_or_null("Sfx")
	if sfx == null or not "GEN" in sfx: print("Sfx failed to load"); quit(1); return
	var t0 := Time.get_ticks_msec()
	var n := 0
	var only := ""
	var voices := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="): only = a.substr(5)
		if a == "voices": voices = true
	for name in sfx.GEN:
		if only != "" and not name.begins_with(only): continue
		# the voices (and Marta's, and Kurt's breathing) are kept exactly as they are: their
		# generators share one random stream, so rebaking them would change them. "voices" to force.
		if not voices and (name.begins_with("v_") or name.begins_with("marta_") or name in ["gasp", "breath", "pant", "whisper", "click", "sniff"]): continue
		var t1 := Time.get_ticks_msec()
		var s: AudioStreamWAV = sfx.synth(name)
		print("  ", name, " ", Time.get_ticks_msec() - t1, " ms")
		s.save_to_wav("res://assets/audio/%s.wav" % name)
		n += 1
	print("BAKED %d sounds in %d ms" % [n, Time.get_ticks_msec() - t0])
	quit()
